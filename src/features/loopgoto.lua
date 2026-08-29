--[[═══════════════════════════════════════════════════════════════════════════
	features/loopgoto · keep teleporting yourself to a player
	─────────────────────────────────────────────────────────────────────────
	Legacy equivalent: source.ref.lua 9610-9643 (`loopgoto` / `unloopgoto`).

	The legacy version looped over the resolved player list but its inner
	`repeat ... until loopgoto ~= Players[v]` never finished for the first
	entry, so `;loopgoto all` silently followed whichever player happened to be
	first and the rest of the loop body was dead code. It also blocked the
	command thread forever, and its off switch was a module global compared by
	identity, so a player rejoining mid-run could restart it by accident.

	This follows exactly one player -- which is all the legacy command could
	ever do -- from a bin-owned thread that `;unloopgoto`, a respawn and
	`;unloadiy` can all stop.
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Feature   = IY.import("features/feature")
local Character = IY.import("core/character")
local Guard     = IY.import("core/guard")
local Teleport  = IY.import("features/teleport")

local M = {}

local DEFAULT_DISTANCE = 3

local feature = Feature.new("loopgoto", {
	command  = "loopgoto",
	reapply  = true,
	describe = "repeatedly teleporting to a player",

	start = function(self, opts)
		local target = opts.target
		if not target then Guard.fail("there is nobody to go to") end
		target:requireRoot()
		Character.requireRoot()
		Teleport.unseat()

		self.bin:spawn(function()
			while target:exists() do
				local root = Character.root()
				local theirRoot = target.root
				if root and theirRoot then
					root.CFrame = Teleport.beside(theirRoot.CFrame,
						self:option("distance", DEFAULT_DISTANCE))
				end
				task.wait(self:option("delay", 0) or 0)
			end
			-- Deferred: stopping empties the bin this thread lives in.
			task.defer(function() self:stop() end)
		end)
	end,
})

M.feature = feature

function M.start(target, opts)
	opts = opts or {}
	return feature:start({
		target   = target,
		distance = opts.distance or DEFAULT_DISTANCE,
		delay    = opts.delay or 0,
	})
end

function M.stop() return feature:stop() end
function M.isRunning() return feature:isRunning() end

function M.target()
	return feature:option("target", nil)
end

return M
