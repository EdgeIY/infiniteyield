--[[═══════════════════════════════════════════════════════════════════════════
	features/antifling · other players cannot push you
	─────────────────────────────────────────────────────────────────────────
	Legacy source.ref.lua 11950-11973. The technique is unchanged -- clear
	CanCollide on every *other* player's parts each physics step, so a spinning
	fling rig has nothing to hit -- with two changes:

	  · the originals go through core/snapshot (tag "antifling"), so
	    `;unantifling` and `;unloadiy` put back exactly what the game had.
	    Legacy stored nothing and had no restore path at all: once you had run
	    `;antifling`, every player you had been near stayed non-collidable for
	    the rest of the session.
	  · one connection in a bin instead of a module global that the on-path
	    disconnected and reassigned. `;unantifling` before `;antifling` was
	    already safe in legacy, but `;antifling` twice in the same frame was not.

	This deliberately overlaps with `headsize` and `hitbox` (commands/character,
	snapshot tag "hitbox"), which also rewrite other players' parts. core/snapshot
	settles it: whichever ran first owns the recorded original, and each
	off-command restores only its own tag -- so `;unantifling` will not undo a
	hitbox that was applied first, and `;unhitbox` will.
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Feature   = IY.import("features/feature")
local Character = IY.import("core/character")
local Services  = IY.import("core/services")
local Snapshot  = IY.import("core/snapshot")
local Sched     = IY.import("core/scheduler")

local PlayersService = Services.Players

local M = {}

local TAG = "antifling"

local feature = Feature.new("antifling", {
	command  = "antifling",
	describe = "other players cannot collide with you",

	start = function(self)
		local me = Character.player

		-- Registered before the loop so the restore exists even if the first
		-- iteration throws.
		self.bin:add(function() Snapshot.restoreTag(TAG) end)

		self.bin:add(Sched.frameLoop("antifling.step", function()
			local players = PlayersService:GetPlayers()
			for i = 1, #players do
				local player = players[i]
				if player ~= me then
					local character = player.Character
					if character then
						local parts = character:GetDescendants()
						for j = 1, #parts do
							local part = parts[j]
							-- Already false means either the game did it or we
							-- did; either way there is nothing to record and
							-- nothing to write.
							if part:IsA("BasePart") and part.CanCollide then
								Snapshot.set(part, "CanCollide", false, TAG)
							end
						end
					end
				end
			end
		end, "stepped"))
	end,
})

M.feature = feature

function M.start() return feature:start() end
function M.stop() return feature:stop() end
function M.toggle() return feature:toggle() end
function M.isRunning() return feature:isRunning() end

return M
