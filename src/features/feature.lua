--[[═══════════════════════════════════════════════════════════════════════════
	features/feature · the base class every stateful feature uses
	─────────────────────────────────────────────────────────────────────────
	A "feature" is anything that stays on until told otherwise: fly, noclip,
	ESP, spectate, autoclick. In the legacy script each one hand-rolled its own
	flag, its own connections and its own cleanup, and the analysis of that code
	found the same four bugs over and over:

	  1. running the on-command twice started a second loop (`float` stacked a
	     part and five connections per invocation)
	  2. the off-command threw when the feature had never been started
	     (`unteleportwalk` called `tpwalking:Disconnect()` on a nil)
	  3. death silently broke the feature but left its connections alive
	     (`cframefly` kept CFraming a destroyed Head forever)
	  4. `;unloadiy` left everything running, because only UI connections were
	     tracked

	This base class makes all four structurally impossible:

	    local Fly = Feature.new("fly", {
	        command = "fly",          -- keeps ;togglefly's state in sync
	        reapply = true,           -- re-arm automatically after a respawn
	        start = function(self, opts)
	            self.bin:connect(RunService.RenderStepped, function() ... end)
	            self.bin:add(Instance.new("BodyVelocity"))
	        end,
	        stop = function(self) end, -- optional; the bin already cleans up
	    })

	    Fly:start{ speed = 2 }   -- restarting is safe: stop runs first
	    Fly:stop()               -- stopping when idle is a no-op, never an error
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Bin       = IY.import("core/bin")
local Guard     = IY.import("core/guard")
local Log       = IY.import("core/log")
local Signal    = IY.import("core/signal")
local Character  = IY.import("core/character")
local Tbl       = IY.import("core/util/tables")

local M = {}

local Feature = {}
Feature.__index = Feature

local registry = {}
M.registry = registry
M.changed = Signal.new("feature.changed")

--[[ Define a feature. `spec.start(self, opts)` is required; everything else is
     optional:
       stop(self)         extra teardown beyond emptying the bin
       reapply            re-run start after a respawn (default false)
       command            command name whose toggle state should track this
       exclusive          list of feature names to stop before starting
       describe           one-liner for the diagnostics panel ]]
function M.new(name, spec)
	if registry[name] then
		-- A module reloaded (plugin dev loop): keep one instance, swap the body.
		local existing = registry[name]
		existing.spec = spec
		return existing
	end

	local self = setmetatable({
		name      = name,
		spec      = spec or {},
		bin       = Bin.new("feature:" .. name),
		running   = false,
		state     = {},
		opts      = nil,
		startedAt = nil,
		starts    = 0,
		log       = Log.scope("feature:" .. name),
	}, Feature)

	registry[name] = self

	-- One respawn subscription per feature, owned by the feature, replaced
	-- never stacked. This single line replaces thirteen bespoke CharacterAdded
	-- handlers in the legacy script.
	if spec and spec.reapply then
		Character.reapply("feature:" .. name, function(character)
			if self.running then self:reapply(character) end
		end)
	end

	IY.onUnload(function()
		if self.running then self:stop() end
		self.bin:destroy()
	end)

	return self
end

function M.get(name)
	return registry[name]
end

function M.isRunning(name)
	local feature = registry[name]
	return feature ~= nil and feature.running == true
end

--[[ Stop every running feature. Used by ;unloadiy and ;panic. ]]
function M.stopAll(except)
	local stopped = {}
	for name, feature in pairs(registry) do
		if feature.running and name ~= except then
			local ok = Guard.call("feature:" .. name, function() feature:stop() end)
			if ok then stopped[#stopped + 1] = name end
		end
	end
	table.sort(stopped)
	return stopped
end

function M.active()
	local out = {}
	for name, feature in pairs(registry) do
		if feature.running then out[#out + 1] = name end
	end
	table.sort(out)
	return out
end

--[[ Diagnostics: what is on, for how long, and how much it is holding. ]]
function M.snapshot()
	local out = {}
	for name, feature in pairs(registry) do
		out[#out + 1] = {
			name    = name,
			running = feature.running,
			starts  = feature.starts,
			holding = feature.bin:count(),
			uptime  = feature.running and ((os.clock and os.clock() or 0) - (feature.startedAt or 0)) or 0,
		}
	end
	return Tbl.sortBy(out, function(entry) return entry.name end)
end

-- ═══ instance methods ═══════════════════════════════════════════════════════

local function syncCommand(self)
	if not self.spec.command then return end
	local ok, Dispatch = pcall(function() return IY.import("cmd/dispatch") end)
	if ok and Dispatch then Dispatch.setActive(self.spec.command, self.running) end
end

--[[ Start (or restart) the feature. Restarting always stops first, so a double
     invocation can never leave two loops running. ]]
function Feature:start(opts)
	if self.running then
		if self.spec.ignoreRestart then return false end
		self:stop({ restarting = true })
	end

	local exclusive = self.spec.exclusive
	if exclusive then
		for i = 1, #exclusive do
			local other = registry[exclusive[i]]
			if other and other.running then other:stop() end
		end
	end

	self.opts = opts or {}
	self.bin:empty()
	self.running = true
	self.starts = self.starts + 1
	self.startedAt = os.clock and os.clock() or 0

	local ok, err, kind = Guard.call("feature:" .. self.name .. ".start", self.spec.start, self, self.opts)
	if not ok then
		-- A failed start must not leave the feature half-on.
		self.running = false
		self.bin:empty()
		syncCommand(self)
		error(err, 0)
	end

	syncCommand(self)
	M.changed:Fire(self.name, true)
	return true
end

--[[ Stop. Safe when it was never started -- that is the whole point. ]]
function Feature:stop(info)
	if not self.running then
		-- Still empty the bin: a failed start may have left scraps.
		self.bin:empty()
		return false
	end
	self.running = false

	if type(self.spec.stop) == "function" then
		Guard.call("feature:" .. self.name .. ".stop", self.spec.stop, self, info)
	end
	self.bin:empty()
	self.state = {}

	syncCommand(self)
	M.changed:Fire(self.name, false)
	return true
end

function Feature:toggle(opts)
	if self.running then
		self:stop()
		return false
	end
	self:start(opts)
	return true
end

function Feature:isRunning()
	return self.running == true
end

--[[ Re-arm after a respawn: drop everything tied to the old character, then
     start again with the options the user originally asked for. ]]
function Feature:reapply(character)
	if not self.running then return false end
	self.bin:empty()
	if type(self.spec.reapplyWith) == "function" then
		return Guard.call("feature:" .. self.name .. ".reapply", self.spec.reapplyWith, self, character)
	end
	local ok, err = Guard.call("feature:" .. self.name .. ".reapply", self.spec.start, self, self.opts or {})
	if not ok then
		self.log.debug("re-apply failed: %s", Guard.describe(err))
		self.running = false
		syncCommand(self)
	end
	return ok
end

--[[ Merge new options into a running feature without restarting it -- for
     `;flyspeed 5` while already flying. ]]
function Feature:configure(patch)
	self.opts = self.opts or {}
	for key, value in pairs(patch) do self.opts[key] = value end
	if self.running and type(self.spec.configure) == "function" then
		Guard.call("feature:" .. self.name .. ".configure", self.spec.configure, self, self.opts)
	end
	return self.opts
end

function Feature:option(key, fallback)
	local value = self.opts and self.opts[key]
	if value == nil then return fallback end
	return value
end

M.class = Feature
return M
