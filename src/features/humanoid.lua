--[[═══════════════════════════════════════════════════════════════════════════
	features/humanoid · loop re-appliers and the WalkSpeed / JumpPower spoofs
	─────────────────────────────────────────────────────────────────────────
	loopspeed / loopjumppower
	    Re-write the value whenever the game writes it. Legacy kept both
	    connections in the shared `HumanModCons` table plus a per-command
	    `speaker.CharacterAdded` handler; `reapply` replaces both. The
	    jump-power version listened on `JumpPower` while writing `JumpHeight`
	    whenever UseJumpPower was false, so on an R15 rig it never re-fired --
	    this one watches the property it actually writes.

	spoofspeed / spoofjumppower
	    Report a chosen value to anything that reads Humanoid.WalkSpeed /
	    JumpPower without changing what the rig really does. Legacy installed a
	    fresh __index *and* __newindex layer on every invocation, captured the
	    character in a closure (so the spoof stopped matching after a respawn
	    while the layers stayed installed forever), had no off-command because
	    the layers were unaddressable, and returned `args[1]` -- the raw string,
	    so game code that read WalkSpeed got "100" rather than 100.

	    Here both live on core/hooks under one fixed id per spoof, so
	    re-running the command replaces the handler instead of stacking a
	    layer, `;unspoofspeed` unregisters it, the character is read on every
	    call, and the value handed back is a number.

	Legacy equivalent: source.ref.lua 10399-10509, 9985-10004.
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Feature   = IY.import("features/feature")
local Character = IY.import("core/character")
local Hooks     = IY.import("core/hooks")
local Guard     = IY.import("core/guard")

local M = {}

-- ── loop re-appliers ────────────────────────────────────────────────────────

--[[ Write `value` to `property`, guarding against the write re-entering us
     through the property-changed signal we are called from. ]]
local function writer(humanoid, pick)
	local busy = false
	return function()
		if busy then return end
		busy = true
		local property, value = pick()
		if property then pcall(function() humanoid[property] = value end) end
		busy = false
	end
end

local loopspeed = Feature.new("loopspeed", {
	command  = "loopspeed",
	reapply  = true,
	describe = "walk speed re-applied",

	start = function(self)
		local humanoid = Character.requireHumanoid()
		local speed = self:option("speed", 16)
		local apply = writer(humanoid, function() return "WalkSpeed", speed end)
		apply()
		self.bin:onChange(humanoid, "WalkSpeed", apply)
	end,
})

--[[ UseJumpPower decides which property is authoritative, and a game can flip
     it mid-round, so all three signals feed the same writer. ]]
local loopjumppower = Feature.new("loopjumppower", {
	command  = "loopjumppower",
	reapply  = true,
	describe = "jump power re-applied",

	start = function(self)
		local humanoid = Character.requireHumanoid()
		local power = self:option("power", 50)
		local apply = writer(humanoid, function()
			local uses = true
			local ok, value = pcall(function() return humanoid.UseJumpPower end)
			if ok then uses = value == true end
			return uses and "JumpPower" or "JumpHeight", power
		end)
		apply()
		self.bin:onChange(humanoid, "JumpPower", apply)
		self.bin:onChange(humanoid, "JumpHeight", apply)
		self.bin:onChange(humanoid, "UseJumpPower", apply)
	end,
})

--[[ What `;unloopjumppower` puts back, matching the legacy off-command. ]]
function M.resetJumpPower(humanoid, power)
	if not humanoid then return false end
	local uses = true
	local ok, value = pcall(function() return humanoid.UseJumpPower end)
	if ok then uses = value == true end
	return pcall(function()
		humanoid[uses and "JumpPower" or "JumpHeight"] = power or 50
	end)
end

-- ── spoofs ──────────────────────────────────────────────────────────────────

--[[ One id per spoof: core/hooks replaces a handler registered under an id that
     already exists, and `unregister` sweeps every metamethod, so the __index and
     __newindex halves share the id and come off together. ]]
local function spoofFeature(name, config)
	return Feature.new(name, {
		command  = config.command,
		describe = "spoofed " .. config.label,

		start = function(self)
			local value = self:option("value", config.fallback)
			local keys, id = config.keys, config.id
			local written   -- the last value the *game* assigned

			--[[ Read the character per call: the legacy closure captured it at
			     invocation time, so one respawn later the spoof matched nothing
			     while still running on every property read in the game. ]]
			local function ours(instance)
				local character = Character.get()
				if not character then return false end
				local ok, matched = pcall(function()
					return instance:IsA("Humanoid") and instance:IsDescendantOf(character)
				end)
				return ok and matched == true
			end

			local ok, reason = Hooks.index(id, function(instance, key)
				if not keys[key] then return end
				if typeof(instance) ~= "Instance" or not ours(instance) then return end
				return true, written or value
			end)
			if not ok then Guard.fail("%s", tostring(reason)) end

			local okWrite, writeReason = Hooks.newindex(id, function(instance, key, assigned)
				if not keys[key] then return end
				if typeof(instance) ~= "Instance" or not ours(instance) then return end
				-- Recorded, not swallowed: the rig still receives the game's value,
				-- and later reads report that rather than the spoof.
				written = tonumber(assigned)
			end)
			if not okWrite then
				self.log.debug("reads are spoofed but writes are not tracked: %s", tostring(writeReason))
			end

			self.bin:add(function() Hooks.unregister(id) end)
		end,
	})
end

--[[ JumpHeight is deliberately left alone: it is on a different scale to
     JumpPower, so reporting the same number for both is a louder tell than not
     spoofing it. This matches the legacy key list. ]]
local spoofspeed = spoofFeature("spoofspeed", {
	command  = "spoofspeed",
	label    = "walk speed",
	id       = "features/humanoid.spoofspeed",
	keys     = { WalkSpeed = true, walkSpeed = true },
	fallback = 16,
})

local spoofjumppower = spoofFeature("spoofjumppower", {
	command  = "spoofjumppower",
	label    = "jump power",
	id       = "features/humanoid.spoofjumppower",
	keys     = { JumpPower = true, jumpPower = true },
	fallback = 50,
})

-- ── exports ─────────────────────────────────────────────────────────────────

M.loopspeed      = loopspeed
M.loopjumppower  = loopjumppower
M.spoofspeed     = spoofspeed
M.spoofjumppower = spoofjumppower

return M
