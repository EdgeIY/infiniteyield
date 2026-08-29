--[[═══════════════════════════════════════════════════════════════════════════
	features/spawnpoint · come back to one spot after every death
	─────────────────────────────────────────────────────────────────────────
	Legacy carried this in three globals -- `spawnpoint` (armed?), `spawnpos`
	(where) and `spDelay` (how long to wait) -- read by a hard-coded block inside
	the one CharacterAdded handler (5061-5066), wrapped in a bare pcall:

	    pcall(function()
	        if spawnpoint and not refreshCmd and spawnpos ~= nil then
	            wait(spDelay)
	            getRoot(Players.LocalPlayer.Character).CFrame = spawnpos
	        end
	    end)

	Three problems came out of that shape:

	  · the wait happened inside the shared handler, so the spawn point delayed
	    every other respawn task behind it, and two fast deaths left two waits
	    racing to place the same character.
	  · `refreshCmd` was a boolean cleared at the end of a task.spawn that
	    indexed `humanoid.RootPart` unguarded first, so one refresh into a rig
	    with no root left it stuck true and silently disabled the spawn point for
	    the rest of the session. core/character exposes `isRefreshing()` -- a
	    deadline, not a flag -- and this feature asks it instead of keeping a
	    second copy.
	  · `;unloadiy` never disarmed it.

	Now it is one feature: `Character.onSpawn` in the bin, one pending restore at
	a time, and disarming (or unloading) cancels whatever was in flight.

	`flashback` needs no state at all -- `Character.lastDeath` is recorded by
	core/character -- so it lives in the command pack.
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Feature   = IY.import("features/feature")
local Character = IY.import("core/character")
local Teleport  = IY.import("features/teleport")
local Sched     = IY.import("core/scheduler")
local Guard     = IY.import("core/guard")

local M = {}

local DEFAULT_DELAY = 0.1   -- legacy spDelay

local feature = Feature.new("spawnpoint", {
	command  = "spawnpoint",
	describe = "spawn point armed",

	start = function(self, opts)
		local point = opts.cframe or Character.cframe()
		if not point then
			Guard.fail("you need a character to take a spawn point from")
		end
		self.state.point = point

		local pending = self.bin:branch("restore")

		--[[ immediate = false: onSpawn otherwise runs straight away for the
		     character you are standing in, and arming a spawn point should not
		     move you. ]]
		local connection = Character.onSpawn(function()
			-- One restore in flight at a time; a death during the delay used to
			-- leave the previous wait running against the new character.
			pending:empty()
			pending:add(Sched.spawn("spawnpoint.restore", function()
				if not self.running then return end
				-- ;refresh puts you back where you were, so stand aside for it.
				if Character.isRefreshing() then return end
				task.wait(self:option("delay", DEFAULT_DELAY))
				if not self.running or not Character.root() then return end
				Teleport.to(self.state.point)
			end))
		end, { immediate = false })
		if connection then self.bin:add(connection) end
	end,
})

M.feature = feature

--[[ opts.cframe  where to return to (defaults to where you are standing)
     opts.delay   seconds to wait after the rig loads before moving you ]]
function M.start(opts) return feature:start(opts or {}) end
function M.stop() return feature:stop() end
function M.toggle(opts) return feature:toggle(opts or {}) end
function M.isRunning() return feature:isRunning() end

--[[ The armed spawn point, or nil when it is off. ]]
function M.point()
	return feature.state and feature.state.point or nil
end

function M.delay()
	return feature:option("delay", DEFAULT_DELAY)
end

return M
