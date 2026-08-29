--[[═══════════════════════════════════════════════════════════════════════════
	features/antikick · refuse a localscript kick
	─────────────────────────────────────────────────────────────────────────
	Replaces source.ref.lua 7942-7962 (clientantikick), which was three faults
	stacked on each other:

	  · `hookmetamethod(game, "__namecall", ...)` was called directly (7947), so
	    every `;clientantikick` left another permanent layer running on every
	    instance call in the game and no off-command was possible. Both layers
	    here are named registrations on core/hooks, so re-running the command
	    replaces them and `;unclientantikick` takes them off.
	  · line 7949 read
	        if select(1, ...) == LocalPlayer and method == "Kick" or method == "kick"
	    which Lua groups as `(a == b and m == "Kick") or (m == "kick")` -- so a
	    `:kick()` call on *any* object, from any script, was swallowed. Here the
	    method test is parenthesised and the receiver has to be our own player.
	  · line 7955 tested `self ~= lp`, and `lp` is an undefined global. The
	    Player.Kick replacement therefore raised "Expected ':' not '.'" on every
	    call, including IY's own `Players.LocalPlayer:Kick("\nRejoining...")` at
	    7004 -- which is why `;rejoin` did nothing at all while anti-kick was on.
	    Deliberate kicks (our own thread via Hooks' skipSelf, or a rejoin in
	    flight) pass through, and a kick we do block is swallowed, never raised.

	Only a client-side kick can be stopped at all: a kick issued by the server
	arrives as a network event rather than as a call on this client.
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Feature  = IY.import("features/feature")
local Env      = IY.import("core/env")
local Guard    = IY.import("core/guard")
local Hooks    = IY.import("core/hooks")
local Services = IY.import("core/services")
local Rejoin   = IY.import("features/rejoin")

local Players = Services.Players

local NAMECALL_ID = "antikick"
local KICK_ID     = "antikick.kick"

local M = {}

-- cloneref'd references do not compare equal to the ones game scripts hold on
-- some executors, so identity goes through compareinstances (Env falls back to
-- `==` when the executor has no such function).
local same = Env.fn.compareinstances or function(a, b) return a == b end

--[[ A kick IY asked for on purpose. `skipSelf` already covers this wherever
     checkcaller is real; the rejoin flag covers the executors where Env only
     emulates it, and features/rejoin sets it before it kicks. ]]
local function deliberate()
	if Rejoin.isRejoining() then return true end
	local checkcaller = Env.fn.checkcaller
	if not checkcaller then return false end
	local ok, result = pcall(checkcaller)
	return ok and result == true
end

local feature = Feature.new("antikick", {
	command  = "clientantikick",
	describe = "localscript kicks blocked",

	start = function(self)
		local player = Players.LocalPlayer
		if not player then Guard.fail("there is no local player") end

		local ok, reason = Hooks.namecall(NAMECALL_ID, function(instance, method, ...)
			if not (method == "Kick" or method == "kick") then return end
			if not same(instance, player) then return end
			if deliberate() then return end
			return true          -- intercept, hand nothing back: Kick returns nothing
		end)
		if not ok then Guard.fail("%s", tostring(reason)) end
		self.bin:add(function() Hooks.unregister(NAMECALL_ID) end)

		-- Second layer, for `Player.Kick(player, msg)` and for cached references
		-- that never go through __namecall. Optional: the namecall layer above is
		-- what catches the common `player:Kick(...)` form.
		if not Env.usable("hookfunction") then
			self.log.debug("no hookfunction: only `:Kick()` calls are covered")
			return
		end

		local original
		local hooked, hookReason = Hooks.hookFunction(KICK_ID, player.Kick,
			function(instance, message)
				if original and (deliberate() or not same(instance, player)) then
					return original(instance, message)
				end
				return nil
			end)
		if type(hooked) == "function" then
			original = hooked
		else
			-- The patch is live but there is no original to call through, so every
			-- Kick is swallowed while this is on. Still better than legacy, which
			-- raised instead of swallowing, and the reason is worth logging.
			self.log.debug("Player.Kick cannot be restored: %s", tostring(hookReason))
		end
		self.bin:add(function() Hooks.unhookFunction(KICK_ID) end)
	end,
})

M.feature = feature

function M.start(opts) return feature:start(opts or {}) end
function M.stop() return feature:stop() end
function M.toggle(opts) return feature:toggle(opts or {}) end
function M.isRunning() return feature:isRunning() end

return M
