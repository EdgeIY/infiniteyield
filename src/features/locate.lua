--[[═══════════════════════════════════════════════════════════════════════════
	features/locate · highlight only the players you asked for
	─────────────────────────────────────────────────────────────────────────
	Legacy source.ref.lua 5885-5975 and 8250-8274. The adornments it drew are
	identical to non-team ESP -- a team-coloured box per body part plus the
	name/health/distance billboard -- the only difference being that locate
	applies to a chosen set of players rather than everyone. So it is the same
	`build`, behind a filter over that set.

	`;nolocate <player>` removes one player, `;nolocate` clears the lot (8267);
	when the set empties the session stops itself, which is what takes the render
	loop and the join/leave connections with it.
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Highlight = IY.import("features/highlight")
local Services  = IY.import("core/services")

local Players = Services.Players

local M = {}

-- Weak keys: a player who has left cannot be kept alive by this table alone.
local selected = setmetatable({}, { __mode = "k" })

local function anySelected()
	return next(selected) ~= nil
end

local session
session = Highlight.create("locate", {
	command  = "locate",
	describe = "locate highlights",
	suffix   = "LC",

	filter = function(player) return selected[player] == true end,

	build = function(bin, target, folder)
		Highlight.boxes(bin, folder, target, Highlight.playerColour(target.player, false))
		return { label = Highlight.nameplate(bin, folder, target) }
	end,

	update = Highlight.refreshNameplate,

	forget = function(player)
		selected[player] = nil
		if not anySelected() then session:stop() end
	end,

	stopped = function()
		for player in pairs(selected) do selected[player] = nil end
	end,
})

M.session = session

--[[ Add targets to the set. Returns how many were added; the local player is
     skipped, as it was in the legacy renderer (5893). ]]
function M.add(targets)
	local added = 0
	for i = 1, #targets do
		local player = targets[i].player
		if player and player ~= Players.LocalPlayer then
			selected[player] = true
			added = added + 1
		end
	end
	if added == 0 then return 0 end
	if session:isRunning() then
		-- refresh() only touches players whose eligibility changed, so the
		-- highlights already on screen are left alone.
		session:refresh()
	else
		session:start()
	end
	return added
end

function M.remove(targets)
	local removed = 0
	for i = 1, #targets do
		local player = targets[i].player
		if player and selected[player] then
			selected[player] = nil
			session:detach(player)
			removed = removed + 1
		end
	end
	if not anySelected() then session:stop() end
	return removed
end

function M.clear() return session:stop() end
function M.isRunning() return session:isRunning() end
function M.count() return session:count() end

return M
