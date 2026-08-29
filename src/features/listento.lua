--[[═══════════════════════════════════════════════════════════════════════════
	features/listento · hear the world from another player's position
	─────────────────────────────────────────────────────────────────────────
	Replaces source.ref.lua 12736-12755 (listento / unlistento).

	Three faults in twenty lines:

	  · `unlistento` called `listentoChar:Disconnect()` (12754) on a global that
	    is nil until the first `;listento`, so running it first -- or twice --
	    threw. `Feature:stop()` is safe when the feature never started.
	  · the respawn handler was connected to `player.CharacterAdded` and then
	    did `repeat task.wait() until Players[player.Name].Character ~= nil`,
	    which never ends if the player leaves instead of respawning, and indexes
	    `Players[...]` by name, which throws once they have gone.
	  · nothing reset the listener when the player you were listening to left, so
	    SoundService stayed pointed at a destroyed part and positional audio
	    stopped working for the rest of the session.

	`reapply = true` because the listener is reset to `Enum.ListenerType.Camera`,
	and the camera is re-created around your own respawn; re-arming keeps the
	subject and the fallback in step.
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Feature  = IY.import("features/feature")
local Guard    = IY.import("core/guard")
local Inst     = IY.import("core/util/instances")
local Services = IY.import("core/services")

local Players      = Services.Players
local SoundService = Services.SoundService

local M = {}

local function pointAt(root)
	return Guard.call("listento.point", function()
		SoundService:SetListener(Enum.ListenerType.ObjectPosition, root)
	end)
end

local function resetListener()
	Guard.call("listento.reset", function()
		SoundService:SetListener(Enum.ListenerType.Camera)
	end)
end

local feature = Feature.new("listento", {
	command = "listento",
	reapply = true,

	start = function(self, opts)
		local target = opts.target
		if not target then Guard.fail("listento needs a player") end
		local root = target.root
		if not root then Guard.fail("%s has no character right now", target.name) end

		-- Queued before the move, so a refused SetListener cannot leave the
		-- listener half-way between the camera and a character.
		self.bin:add(resetListener)
		if not pointAt(root) then
			Guard.fail("this game does not allow the audio listener to be moved")
		end

		local player = target.player
		if not player then return end

		self.bin:connect(player.CharacterAdded, function(character)
			-- Bounded wait, where legacy span until the part appeared.
			Inst.waitFor(character, "HumanoidRootPart", 10)
			if not self:isRunning() then return end
			local respawned = Inst.root(character)
			if respawned then pointAt(respawned) end
		end)

		self.bin:connect(Players.PlayerRemoving, function(leaving)
			if leaving == player then self:stop() end
		end)
	end,
})

M.feature = feature

function M.start(target) return feature:start({ target = target }) end
function M.stop() return feature:stop() end
function M.isRunning() return feature:isRunning() end

--[[ Who is being listened to, for the notification -- nil when idle. ]]
function M.target()
	if not feature:isRunning() then return nil end
	return feature:option("target", nil)
end

return M
