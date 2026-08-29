--[[═══════════════════════════════════════════════════════════════════════════
	features/antiteleport · refuse a localscript teleport
	─────────────────────────────────────────────────────────────────────────
	Replaces source.ref.lua 7965-8015 (clientantiteleport). The legacy version
	installed a *second* permanent `__namecall` layer (8003) on top of the one
	anti-kick had already added, plus two throwaway `hookfunction` patches whose
	originals were discarded, so nothing it did could be undone. Everything here
	is a named registration on core/hooks with an off-command.

	Three behaviour fixes:

	  · line 8005 read
	        if select(1, ...) == TeleportService and nmc == "teleport"
	           or nmc == "Teleport" or nmc == "TeleportToPlaceInstance" ...
	    which Lua groups as `(a == b and m == "teleport") or (m == "Teleport") or
	    ...`, so *any* object's :Teleport / :TeleportToPlaceInstance /
	    :TeleportAsync call was swallowed -- a game's own vehicle "Teleport"
	    method included. The method test is parenthesised here and the receiver
	    has to be TeleportService.
	  · TeleportAsync was patched with an unconditional `error(...)` (7991-8002),
	    which blocked IY's own teleports as well as the game's. Deliberate calls
	    (our own thread, or a rejoin in flight) are passed straight through.
	  · the legacy Luau interpolation at 7981 and the `placeId ~= true` branch
	    below it are gone; the remaining argument checks reproduce the engine's
	    own messages so a game script sees what it would normally see.

	`;allowrejoin` (commands/server, flag in features/rejoin) carves out an
	exception for a teleport back into this same place. Legacy defaulted that
	flag to on; features/rejoin defaults it to off, so a script cannot rejoin you
	until you allow it.
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Feature  = IY.import("features/feature")
local Env      = IY.import("core/env")
local Guard    = IY.import("core/guard")
local Hooks    = IY.import("core/hooks")
local Services = IY.import("core/services")
local Rejoin   = IY.import("features/rejoin")

local TeleportService = Services.TeleportService

local NAMECALL_ID = "antiteleport"
local TELEPORT_ID = "antiteleport.teleport"
local ASYNC_ID    = "antiteleport.teleportasync"

-- Everything the legacy or-chain meant to cover.
local METHODS = {
	Teleport = true, teleport = true,
	TeleportToPlaceInstance = true,
	TeleportAsync = true,
}

local M = {}

local same = Env.fn.compareinstances or function(a, b) return a == b end

--[[ A teleport IY (or the user, through `;allowrejoin`) asked for. ]]
local function passThrough(placeId)
	if Rejoin.isRejoining() then return true end
	local checkcaller = Env.fn.checkcaller
	if checkcaller then
		local ok, result = pcall(checkcaller)
		if ok and result == true then return true end
	end
	if Rejoin.allowsRejoin() then
		local ok, here = pcall(function() return game.PlaceId end)
		if ok and placeId == here then return true end
	end
	return false
end

--[[ Patch one TeleportService method, keeping the original so the bin can put it
     back. A failure is logged rather than raised: the namecall layer is the one
     that has to work, and these two only add cover for calls that never reach
     __namecall. ]]
local function patch(self, id, name, build)
	local target = TeleportService[name]
	if type(target) ~= "function" then return end
	local original
	local hooked, reason = Hooks.hookFunction(id, target, build(function(...)
		if original then return original(...) end
		return nil
	end))
	if type(hooked) == "function" then
		original = hooked
	else
		self.log.debug("%s cannot be restored: %s", name, tostring(reason))
	end
	self.bin:add(function() Hooks.unhookFunction(id) end)
end

local feature = Feature.new("antiteleport", {
	command  = "clientantiteleport",
	describe = "localscript teleports blocked",

	start = function(self)
		local ok, reason = Hooks.namecall(NAMECALL_ID, function(instance, method, ...)
			if not METHODS[method] then return end
			if not same(instance, TeleportService) then return end
			if passThrough((select(1, ...))) then return end
			return true          -- intercept and hand nothing back
		end)
		if not ok then Guard.fail("%s", tostring(reason)) end
		self.bin:add(function() Hooks.unregister(NAMECALL_ID) end)

		if not Env.usable("hookfunction") then
			self.log.debug("no hookfunction: only `:Teleport()` style calls are covered")
			return
		end

		patch(self, TELEPORT_ID, "Teleport", function(callOriginal)
			return function(instance, placeId, player, teleportData, loadingScreen)
				if passThrough(placeId) then
					return callOriginal(instance, placeId, player, teleportData, loadingScreen)
				end
				if not same(instance, TeleportService) then
					error("Expected ':' not '.' calling member function Teleport", 2)
				end
				if placeId == nil then error("Argument 1 missing or nil", 2) end
				if typeof(placeId) ~= "number" then
					error("Unable to cast " .. typeof(placeId) .. " to int64", 2)
				end
				if loadingScreen ~= nil and typeof(loadingScreen) ~= "Instance" then
					error("Unable to cast value to Object", 2)
				end
				return nil       -- the script believes it teleported; we stay put
			end
		end)

		patch(self, ASYNC_ID, "TeleportAsync", function(callOriginal)
			return function(instance, placeId, players, teleportOptions)
				if passThrough(placeId) then
					return callOriginal(instance, placeId, players, teleportOptions)
				end
				if not same(instance, TeleportService) then
					error("Expected ':' not '.' calling member function TeleportAsync", 2)
				end
				if players == nil then error("Argument 2 missing or nil", 2) end
				if typeof(players) ~= "table" then error("Unable to cast value to Objects", 2) end
				-- Legacy raised this unconditionally; now it is only what a blocked
				-- caller sees, and it mimics the real server-only failure.
				error("TeleportUnknown must be called from a Server", 2)
			end
		end)
	end,
})

M.feature = feature

function M.start(opts) return feature:start(opts or {}) end
function M.stop() return feature:stop() end
function M.toggle(opts) return feature:toggle(opts or {}) end
function M.isRunning() return feature:isRunning() end

return M
