--[[═══════════════════════════════════════════════════════════════════════════
	features/keepiy · re-run IY after a server teleport
	─────────────────────────────────────────────────────────────────────────
	Replaces source.ref.lua 6506-6514 (the OnTeleport connection) and 6580-6606
	(keepiy / unkeepiy / togglekeepiy).

	  · the legacy connection was made once at load and read the KeepInfYield
	    global, so `;unloadiy` left it connected -- teleporting after an explicit
	    unload quietly brought IY back. It lives in the feature's bin now.
	  · the queued payload follows the channel you are actually running, so a
	    branch under test survives a teleport. The legacy version always queued
	    the release `source`.
	  · the state *is* the saved `keepIY` setting, watched rather than mirrored,
	    so the settings panel and the command cannot disagree.
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Feature  = IY.import("features/feature")
local Env      = IY.import("core/env")
local Guard    = IY.import("core/guard")
local Log      = IY.import("core/log")
local Services = IY.import("core/services")
local Store    = IY.import("core/store")

local Players = Services.Players

local M = {}

local RELEASE_SOURCE = "https://raw.githubusercontent.com/CarlDV/infiniteyield/master/source"

--[[ What to run on the other side of the teleport. ]]
local function payload()
	local config = IY.config or {}
	-- `entry` is "source" for the bundle and "loader.lua" for the remote
	-- loader, so we come back the same way we came in.
	if type(config.base) == "string" and config.base ~= "" then
		return "loadstring(game:HttpGet('" .. config.base .. (config.entry or "source") .. "'))()"
	end
	return "loadstring(game:HttpGet('" .. RELEASE_SOURCE .. "'))()"
end
M.payload = payload

local feature = Feature.new("keepiy", {
	command  = "keepiy",
	describe = "re-running after a teleport",

	start = function(self)
		local player = Players.LocalPlayer
		if not player then Guard.fail("there is no local player yet") end
		self.bin:connect(player.OnTeleport, function()
			-- OnTeleport fires more than once per teleport (Started, InProgress,
			-- Failed); queue exactly once, as the legacy TeleportCheck flag did.
			if self.state.queued then return end
			local queue = Env.fn.queueteleport
			if not queue then return end
			self.state.queued = true
			local ok, err = pcall(queue, payload())
			if not ok then
				self.state.queued = false
				Log.warn("keepiy", "could not queue the loader: %s", tostring(err))
			end
		end)
	end,
})

M.feature = feature

function M.isRunning() return feature:isRunning() end
function M.supported() return Env.usable("queueteleport") end

--[[ The setting is the state: writing it arms or disarms the connection through
     the watcher below, so there is one code path either way. ]]
function M.set(on)
	Store.set("keepIY", on == true)
	return on == true
end

function M.toggle()
	return M.set(not feature:isRunning())
end

local watcher = Store.watch("keepIY", function(value)
	if value == true then
		if not feature:isRunning() then feature:start() end
	else
		feature:stop()
	end
end)

IY.onUnload(function()
	if watcher then watcher:Disconnect() end
end, "features/keepiy")

return M
