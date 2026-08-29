--[[═══════════════════════════════════════════════════════════════════════════
	features/loopoof · keep every player's head sounds playing
	─────────────────────────────────────────────────────────────────────────
	Legacy was a bare `repeat wait(0.1) ... until oofing == false` driven by a
	global flag (lines 9473-9489). Running `;loopoof` twice started a second
	loop that `;unloopoof` could not stop, because the flag it cleared was
	already false by the time the first loop noticed, and `;unloadiy` left both
	running. A labelled scheduler loop in the feature bin can only ever exist
	once and always stops.

	Legacy equivalent: source.ref.lua 9473-9489.
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Feature  = IY.import("features/feature")
local Services = IY.import("core/services")
local Sched    = IY.import("core/scheduler")

local Players = Services.Players

local M = {}

local function replayHead(character)
	local head = character and character:FindFirstChild("Head")
	if not head then return end
	for _, child in ipairs(head:GetChildren()) do
		if child:IsA("Sound") then
			pcall(function() child.Playing = true end)
		end
	end
end

local feature = Feature.new("loopoof", {
	command  = "loopoof",
	describe = "replaying oof sounds",

	start = function(self)
		self.bin:add(Sched.interval("loopoof.tick", 0.1, function()
			local players = Players:GetPlayers()
			for i = 1, #players do
				replayHead(players[i].Character)
			end
		end, true))
	end,
})

M.feature = feature

function M.start(opts) return feature:start(opts or {}) end
function M.stop() return feature:stop() end
function M.toggle(opts) return feature:toggle(opts) end
function M.isRunning() return feature:isRunning() end

return M
