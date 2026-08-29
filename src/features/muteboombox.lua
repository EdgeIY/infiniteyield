--[[═══════════════════════════════════════════════════════════════════════════
	features/muteboombox · stop (and restart) the sounds a player is playing
	─────────────────────────────────────────────────────────────────────────
	Legacy (lines 9491-9527) walked `Players[v].Character:GetDescendants()` and
	`Players[v]:FindFirstChildOfClass("Backpack"):GetDescendants()` with no nil
	check on either, so the command threw on anyone who was dead or had no
	Backpack -- and because the throw happened inside the per-player task.spawn,
	the failure was silent and the remaining players were skipped.

	The unmute half only walked the character, so a boombox that was muted while
	held and then stowed could never be turned back on. Both halves cover both
	containers here.

	Legacy equivalent: source.ref.lua 9491-9527.
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Services = IY.import("core/services")
local Notify   = IY.import("core/notify")
local Guard    = IY.import("core/guard")

local M = {}

local warned = false

--[[ With RespectFilteringEnabled the server decides who hears what, so the
     mute may only apply on this client. Said once per session. ]]
function M.warnFiltering()
	if warned then return false end
	local ok, respect = pcall(function() return Services.SoundService.RespectFilteringEnabled end)
	if not ok or respect ~= true then return false end
	warned = true
	Notify.send("RespectFilteringEnabled",
		"RespectFilteringEnabled is set to true (the command will still work but may only be clientsided)")
	return true
end

local function containers(target)
	local out = {}
	local character = target.character
	if character then out[#out + 1] = character end
	local backpack = target.backpack
	if backpack then out[#out + 1] = backpack end
	return out
end

local function setPlaying(target, from, to)
	local changed = 0
	local list = containers(target)
	for i = 1, #list do
		local descendants = Guard.try(function() return list[i]:GetDescendants() end) or {}
		for j = 1, #descendants do
			local sound = descendants[j]
			if sound:IsA("Sound") then
				local ok, playing = pcall(function() return sound.Playing end)
				if ok and playing == from and pcall(function() sound.Playing = to end) then
					changed = changed + 1
				end
			end
		end
	end
	return changed
end

function M.mute(target)
	M.warnFiltering()
	return setPlaying(target, true, false)
end

function M.unmute(target)
	M.warnFiltering()
	return setPlaying(target, false, true)
end

return M
