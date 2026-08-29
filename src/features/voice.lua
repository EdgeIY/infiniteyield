--[[═══════════════════════════════════════════════════════════════════════════
	features/voice · pausing voice chat
	─────────────────────────────────────────────────────────────────────────
	Replaces source.ref.lua 12824-12844 (muteallvoices, unmuteallvoices, mutevc,
	unmutevc).

	All four were one unguarded line, e.g.

	    Services.VoiceChatInternal:SubscribePauseAll(true)

	which raises outright in a game without voice chat, on a client whose build
	does not expose the service, and on a client that has the service but not the
	Subscribe* methods. `Services.get` returns nil instead of raising, the method
	is checked before it is called, and the failure is one sentence.

	The bookkeeping is the other half. Legacy `unmuteallvoices` cleared the global
	pause flag and stopped there, so anyone muted individually with `;mutevc`
	stayed muted with nothing left to say so -- the flag was gone, the individual
	pauses were not. Two features hold the two kinds of state, each restoring
	exactly what it applied when its bin empties, so `unmuteallvoices`,
	`Feature.stopAll()` and `;unloadiy` all put voice back the way it was.
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Feature  = IY.import("features/feature")
local Guard    = IY.import("core/guard")
local Services = IY.import("core/services")

local M = {}

local UNAVAILABLE = "this game does not have voice chat"

--[[ Whether this client has voice at all. VoiceChatService is the public
     service, so its absence is the clean "no voice here" signal. ]]
function M.available()
	return Services.get("VoiceChatService") ~= nil
end

--[[ Call one of the pause methods. The API lives on VoiceChatInternal rather
     than on the public service, and both the service and the method may be
     missing, so all three failure modes return `false, reason` instead of
     throwing. Never more than two arguments: SubscribePauseAll(paused) and
     SubscribePause(userId, paused). ]]
local function invoke(method, first, second)
	local service = Services.get("VoiceChatInternal")
	if not service then return false, UNAVAILABLE end
	local fn = Guard.try(function() return service[method] end)
	if type(fn) ~= "function" then
		return false, "your client's voice chat does not support this"
	end
	if not Guard.call("voice." .. method, function()
		return fn(service, first, second)
	end) then
		return false, "the voice chat service refused that"
	end
	return true
end

-- ── every voice at once ─────────────────────────────────────────────────────

local pauseAll = Feature.new("muteallvoices", {
	command  = "muteallvoices",
	describe = "all voice chat paused",

	start = function(self)
		local ok, reason = invoke("SubscribePauseAll", true)
		if not ok then Guard.fail("%s", reason) end
		self.bin:add(function() invoke("SubscribePauseAll", false) end)
	end,
})

-- ── individual voices ───────────────────────────────────────────────────────

local paused = Feature.new("mutevc", {
	describe = "individual voices paused",

	start = function(self)
		self.state.users = {}
		-- Unmuting exactly the set we muted is the point: the bin runs before
		-- Feature:stop clears state, so this sees the full list.
		self.bin:add(function()
			for userId in pairs(self.state.users or {}) do
				invoke("SubscribePause", userId, false)
			end
		end)
	end,
})

M.allFeature = pauseAll
M.mutedFeature = paused

function M.muteAll()
	pauseAll:start()
	return true
end

function M.mutedCount()
	if not paused:isRunning() then return 0 end
	local count = 0
	for _ in pairs(paused.state.users or {}) do count = count + 1 end
	return count
end

function M.mutedNames()
	local out = {}
	if not paused:isRunning() then return out end
	for _, name in pairs(paused.state.users or {}) do out[#out + 1] = name end
	table.sort(out)
	return out
end

--[[ Drop the global pause *and* every individual one, and report how many of
     the latter there were. ]]
function M.unmuteAll()
	local count = M.mutedCount()
	local wasAll = pauseAll:isRunning()
	pauseAll:stop()
	paused:stop()
	return count, wasAll
end

--[[ Starting the feature on demand rather than in the command keeps the muted
     set intact when a second `;mutevc` names somebody new: Feature:start()
     restarts, and restarting would unmute everyone already muted. ]]
function M.mute(target)
	target:requirePlayer()
	local userId = target.userId
	if userId == 0 then Guard.fail("%s has no user id to mute", target.name) end
	if not paused:isRunning() then paused:start() end
	local ok, reason = invoke("SubscribePause", userId, true)
	if not ok then Guard.fail("%s", reason) end
	paused.state.users[userId] = target.name
	return true
end

function M.unmute(target)
	target:requirePlayer()
	local userId = target.userId
	if userId == 0 then Guard.fail("%s has no user id to unmute", target.name) end
	local ok, reason = invoke("SubscribePause", userId, false)
	if not ok then Guard.fail("%s", reason) end
	if paused:isRunning() then
		paused.state.users[userId] = nil
		if next(paused.state.users) == nil then paused:stop() end
	end
	return true
end

return M
