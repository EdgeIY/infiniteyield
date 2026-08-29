--[[═══════════════════════════════════════════════════════════════════════════
	features/chat · saying things, and the two spam loops
	─────────────────────────────────────────────────────────────────────────
	The send primitive plus the two features that repeat it. Replaces
	source.ref.lua 2126-2133 (chatMessage), 10666-10678 (spam / nospam),
	10691-10723 (pmspam / nopmspam) and 10725-10730 (spamspeed). Chat *logging*
	belongs to features/chatlogs; this module only speaks.

	`chatMessage` chose its pipeline from a load-time flag and then indexed
	straight through it:

	    TextChatService.TextChannels.RBXGeneral:SendAsync(str)
	    ReplicatedStorage.DefaultChatSystemChatEvents.SayMessageRequest:FireServer(str, "All")

	Both lines throw in a game that ships its own chat system -- the channel or
	the remote is simply not there -- and the throw surfaced as ";chat does
	nothing". Every lookup here is a FindFirstChild, and the failure is one
	sentence the user can act on.

	The legacy spam loop was

	    spamming = true
	    repeat wait(spamspeed) chatMessage(spamstring) until spamming == false

	on the command thread, which meant:

	  · a second `;spam` started a second loop. `nospam` cleared the single flag
	    both loops read, so the doubling was intermittent and never reproduced.
	  · `;breakloops` and `;unloadiy` could not reach it.
	  · `spamspeed` stored `args[1]` verbatim (10726), so the loop waited on a
	    string.

	`pmspam` kept a global array of names and one thread per victim, so N
	victims meant N times the send rate; `nopmspam` called table.remove on that
	array while the other threads walked it. One Sched loop over one victim set
	here, and both features stop with their bin.
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Feature  = IY.import("features/feature")
local Guard    = IY.import("core/guard")
local Notify   = IY.import("core/notify")
local Platform = IY.import("core/platform")
local Sched    = IY.import("core/scheduler")
local Services = IY.import("core/services")
local Inst     = IY.import("core/util/instances")
local Str      = IY.import("core/util/strings")

local ReplicatedStorage = Services.ReplicatedStorage

local M = {}

local CANNOT = "this game's chat cannot be used"
local DEFAULT_SPEED = 1

-- One shared value, as legacy's single `spamspeed` global was.
local speed = DEFAULT_SPEED

-- pmspam's victims live here rather than in feature state, because the caller
-- fills the set *before* the loop is armed and Feature:start() wipes state.
local victims = {}          -- identityKey -> { target = Target, message = string }

-- ── the send primitive ──────────────────────────────────────────────────────

local function sayRequest()
	local events = ReplicatedStorage:FindFirstChild("DefaultChatSystemChatEvents")
	local request = events and events:FindFirstChild("SayMessageRequest")
	if request then return request end
	return nil
end

--[[ "All" is the channel name the legacy remote takes; under TextChatService
     the equivalent is RBXGeneral. A game that renamed the default channel still
     has exactly one, so fall back to whatever channel exists. ]]
local function textChannel(channel)
	local service = Services.get("TextChatService")
	if not service then return nil end
	local channels = service:FindFirstChild("TextChannels")
	if not channels then return nil end
	local wanted = channel
	if wanted == nil or Str.lower(tostring(wanted)) == "all" then wanted = "RBXGeneral" end
	local found = channels:FindFirstChild(tostring(wanted))
	if found then return found end
	return Inst.ofClass(channels, "TextChannel", false)[1]
end

--[[ True when there is something to send through. The commands check this
     before arming a loop, so an unusable chat reports once instead of per tick. ]]
function M.available()
	if Platform.isLegacyChat then return sayRequest() ~= nil end
	return textChannel(nil) ~= nil
end

--[[ Say `text`, on either pipeline. Raises a user error when the game's chat
     cannot carry it, which is the case legacy indexed straight through. ]]
function M.say(text, channel)
	local message = tostring(text or "")
	if Str.trim(message) == "" then Guard.fail("there is nothing to say") end

	if Platform.isLegacyChat then
		local request = sayRequest()
		if not request then Guard.fail("%s", CANNOT) end
		if not Guard.call("chat.say", function()
			request:FireServer(message, channel or "All")
		end) then
			Guard.fail("%s", CANNOT)
		end
		return true
	end

	local destination = textChannel(channel)
	if not destination then Guard.fail("%s", CANNOT) end
	if not Guard.call("chat.say", function() destination:SendAsync(message) end) then
		Guard.fail("%s", CANNOT)
	end
	return true
end

--[[ Non-raising variant for the loops: false plus one line of why. ]]
function M.trySay(text, channel)
	local ok, err = Guard.call("chat.say", M.say, text, channel)
	if ok then return true end
	return false, Guard.describe(err)
end

--[[ A whisper is an ordinary chat line the server's chat script interprets,
     which is all legacy `whisper` did (10688). ]]
function M.whisper(name, message)
	return M.say("/w " .. tostring(name) .. " " .. tostring(message))
end

-- ── shared loop plumbing ────────────────────────────────────────────────────

--[[ Give up once, with the reason. Deferred because stopping empties the bin
     the loop's own thread lives in. ]]
local function giveUp(feature, title, reason)
	Notify.warn(title, reason or CANNOT)
	task.defer(function() feature:stop() end)
end

--[[ (Re-)arm a feature's interval at the current speed. `Sched.interval`
     replaces a loop of the same label and the handle lives in a branch that is
     emptied first, so neither a re-arm nor a second start can leave two loops
     running -- the exact failure legacy `spam` had. ]]
local function arm(self)
	local branch = self.state.loop
	if not branch then return false end
	branch:empty()
	branch:add(Sched.interval(self.state.label,
		self:option("speed", DEFAULT_SPEED), self.state.tick))
	return true
end

local function clearVictims()
	for key in pairs(victims) do victims[key] = nil end
end

-- ── spam ────────────────────────────────────────────────────────────────────

local spam = Feature.new("spam", {
	command  = "spam",
	describe = "spamming the chat",

	start = function(self, opts)
		local message = Str.trim(tostring(opts.message or ""))
		if message == "" then Guard.fail("spam needs something to say") end
		self.state.label = "chat.spam"
		self.state.loop  = self.bin:branch("loop")
		self.state.tick  = function()
			local ok, reason = M.trySay(message)
			if not ok then giveUp(self, "Spam", reason) end
		end
		arm(self)
	end,

	configure = function(self) arm(self) end,
})

-- ── pmspam ──────────────────────────────────────────────────────────────────

--[[ One whisper per victim per tick. Legacy ran a thread per victim, each with
     its own `wait(spamspeed)`, so five victims meant five times the send rate
     and five chances to trip the server's flood check. ]]
local function tickPmspam(self)
	local sent = 0
	for key, entry in pairs(victims) do
		if not entry.target:exists() then
			victims[key] = nil
		else
			local ok, reason = M.trySay("/w " .. entry.target.name .. " " .. entry.message)
			if not ok then
				giveUp(self, "Pmspam", reason)
				return
			end
			sent = sent + 1
		end
	end
	-- Everybody left: the legacy per-victim loop spun forever in that case.
	if sent == 0 then task.defer(function() self:stop() end) end
end

local pmspam = Feature.new("pmspam", {
	command  = "pmspam",
	describe = "whisper-spamming players",

	start = function(self)
		self.state.label = "chat.pmspam"
		self.state.loop  = self.bin:branch("loop")
		self.state.tick  = function() tickPmspam(self) end
		-- Emptying the victim set is part of stopping, so ;unloadiy and
		-- Feature.stopAll leave nothing behind.
		self.bin:add(clearVictims)
		arm(self)
	end,

	configure = function(self) arm(self) end,
})

-- ── speed ───────────────────────────────────────────────────────────────────

function M.speed() return speed end

--[[ Legacy `spamspeed` wrote a global that the running loop happened to re-read
     each iteration. Here the value is pushed into both features, which re-arm
     their interval, so it still takes effect without a restart. ]]
function M.setSpeed(seconds)
	speed = math.max(tonumber(seconds) or DEFAULT_SPEED, 0)
	if spam:isRunning() then spam:configure({ speed = speed }) end
	if pmspam:isRunning() then pmspam:configure({ speed = speed }) end
	return speed
end

-- ── public API ──────────────────────────────────────────────────────────────

M.spamFeature   = spam
M.pmspamFeature = pmspam

function M.startSpam(message)
	if not M.available() then Guard.fail("%s", CANNOT) end
	return spam:start({ message = message, speed = speed })
end

function M.stopSpam() return spam:stop() end
function M.spamming() return spam:isRunning() end

--[[ Add victims and arm the loop. Returns how many were added and how many
     were already being spammed -- legacy just `return`ed on a duplicate
     (10698), so `;pmspam bob hi` twice looked like it had done nothing. ]]
function M.startPmspam(targets, message)
	if not M.available() then Guard.fail("%s", CANNOT) end
	local text = Str.trim(tostring(message or ""))
	if text == "" then Guard.fail("pmspam needs something to say") end

	local added, already = 0, 0
	for i = 1, #targets do
		local target = targets[i]
		local key = target.identityKey
		if victims[key] then
			already = already + 1
		else
			victims[key] = { target = target, message = text }
			added = added + 1
		end
	end
	if not pmspam:isRunning() then pmspam:start({ speed = speed }) end
	return added, already
end

--[[ Stop spamming `targets`, or everybody when `targets` is nil. Returns how
     many were actually being spammed. ]]
function M.stopPmspam(targets)
	if targets == nil then
		local count = M.pmspamCount()
		pmspam:stop()
		clearVictims()
		return count
	end
	local removed = 0
	for i = 1, #targets do
		local key = targets[i].identityKey
		if victims[key] then
			victims[key] = nil
			removed = removed + 1
		end
	end
	-- A victim who has since left would otherwise keep the loop alive.
	for key, entry in pairs(victims) do
		if not entry.target:exists() then victims[key] = nil end
	end
	if next(victims) == nil then pmspam:stop() end
	return removed
end

function M.pmspamCount()
	local count = 0
	for _ in pairs(victims) do count = count + 1 end
	return count
end

function M.pmspamming() return pmspam:isRunning() end

return M
