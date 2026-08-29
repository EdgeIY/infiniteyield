--[[═══════════════════════════════════════════════════════════════════════════
	features/rejoin · rejoin, auto-rejoin and server hopping
	─────────────────────────────────────────────────────────────────────────
	Replaces source.ref.lua 6969-7050 (rejoin, autorejoin, serverhop) and
	8017-8025 (allowrejoin, cancelteleport).

	Two real bugs are fixed here:

	  · legacy `rejoin` called `Players.LocalPlayer:Kick()` first. The client
	    anti-kick hook makes that throw, and the error aborted the command
	    *before* the teleport ran -- so `;rejoin` did nothing at all whenever
	    `;clientantikick` was on. The instance teleport is tried first now, and
	    the kick fallback is contained.
	  · legacy `autorejoin` connected a fresh ErrorMessageChanged handler on
	    every invocation and never disconnected any of them, so running it twice
	    fired two rejoins and `;unloadiy` left them connected. It is a feature
	    with an off switch now.
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Feature  = IY.import("features/feature")
local Env      = IY.import("core/env")
local Guard    = IY.import("core/guard")
local Hooks    = IY.import("core/hooks")
local Json     = IY.import("core/json")
local Log      = IY.import("core/log")
local Services = IY.import("core/services")

local Players         = Services.Players
local TeleportService = Services.TeleportService

local M = {}

local SERVER_LIST_URL =
	"https://games.roblox.com/v1/games/%s/servers/Public?sortOrder=Desc&limit=100&excludeFullGames=true"

--[[ Queued for the far side of a rejoin: puts the character back on the spot it
     left from. Verbatim from the legacy teleportRespawnHandler (6969-6988) --
     it runs as its own chunk in the new server, not as part of IY. ]]
local REPOSITION_SCRIPT = [[
local ok, data = pcall(function() return game:GetService("TeleportService"):GetLocalPlayerTeleportData() end)
if ok and typeof(data) == "CFrame" then
	local Players = game:GetService("Players")
	local ME = Players.LocalPlayer
	while not ME do
		Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
		ME = Players.LocalPlayer
	end

	local Character = ME.Character or ME.CharacterAdded:Wait()
	Character:WaitForChild("HumanoidRootPart")

	local t = tick()
	while (tick() - t) <= 0.3 do
		Character:PivotTo(data)
		task.wait()
	end
end
]]
M.repositionScript = REPOSITION_SCRIPT

-- ── anti-teleport co-operation ──────────────────────────────────────────────

--[[ `;clientantiteleport` blocks every localscript teleport; `;allowrejoin`
     carves out an exception for a teleport back into this same place. The flag
     lives here rather than as the legacy `allow_rj` global, and the hook reads
     it with `IY.import("features/rejoin").allowsRejoin()`. ]]
local allowRejoin = false

function M.allowsRejoin() return allowRejoin end

function M.setAllowRejoin(on)
	allowRejoin = on == true
	return allowRejoin
end

function M.toggleAllowRejoin()
	return M.setAllowRejoin(not allowRejoin)
end

-- ── rejoin ──────────────────────────────────────────────────────────────────

local rejoining = false

--[[ True while a rejoin or hop is in flight. An anti-kick hook should let
     `Kick` through while this is set. ]]
function M.isRejoining() return rejoining end

local function markRejoining()
	rejoining = true
	-- Cleared on a timer: if the teleport is refused we are still here, and a
	-- stuck flag would keep anti-kick disarmed forever.
	task.delay(10, function() rejoining = false end)
end

--[[ Leaving a one-player server needs a kick, and `;clientantikick` hooks
     __namecall so the call throws. Hooks.exempt stands every handler down for
     the duration -- that is what it exists for -- and the kick is contained
     anyway, because the teleport afterwards is what actually moves us. ]]
local function leaveServer(player)
	local release = Hooks.exempt("rejoin")
	local ok, err = pcall(function() player:Kick("\nRejoining...") end)
	if not ok then
		Log.debug("rejoin", "Kick was blocked (%s); teleporting anyway", tostring(err))
	end
	release()
end

--[[ Rejoin this server. `opts.reposition` queues the handler above so the
     character comes back to the same spot. ]]
function M.rejoin(opts)
	opts = opts or {}
	local player = Players.LocalPlayer
	if not player then Guard.fail("there is no local player") end

	local placeId, jobId = game.PlaceId, game.JobId
	local data = nil
	if opts.reposition then
		local queue = Env.fn.queueteleport
		if not queue then
			Guard.fail("repositioning needs queue_on_teleport, which your executor does not have")
		end
		local character = player.Character
		if not character then Guard.fail("you have no character to reposition") end
		data = character:GetPivot()
		pcall(queue, REPOSITION_SCRIPT)
	end

	markRejoining()

	-- More than one player: the instance survives our leaving, so go straight
	-- back into it. This path never touches Kick, which is what made the legacy
	-- rejoin incompatible with the anti-kick hook.
	if #Players:GetPlayers() > 1 then
		local ok, err = pcall(function()
			TeleportService:TeleportToPlaceInstance(placeId, jobId, player, nil, data)
		end)
		if ok then return true end
		Log.warn("rejoin", "could not rejoin this instance (%s); asking for a fresh server",
			tostring(err))
	end

	-- Alone in the instance (it shuts down the moment we leave), or the instance
	-- teleport was refused: leave and take whatever server we are given.
	leaveServer(player)
	task.wait(0.3)
	TeleportService:Teleport(placeId, player, data)
	return true
end

function M.cancel()
	TeleportService:TeleportCancel()
	return true
end

-- ── auto rejoin ─────────────────────────────────────────────────────────────

local autoRejoin = Feature.new("autorejoin", {
	command  = "autorejoin",
	describe = "rejoining automatically when disconnected",

	start = function(self)
		self.bin:connect(Services.GuiService.ErrorMessageChanged, function(message)
			-- The error dialog can change several times while it is shown; one
			-- rejoin is enough.
			if self.state.triggered then return end
			self.state.triggered = true
			Log.info("rejoin", "disconnected (%s) -- rejoining", tostring(message))
			Guard.call("autorejoin", M.rejoin, {})
		end)
	end,
})

M.autoRejoin = autoRejoin

function M.startAuto() return autoRejoin:start({}) end
function M.stopAuto() return autoRejoin:stop() end
function M.autoRunning() return autoRejoin:isRunning() end

-- ── server hop ──────────────────────────────────────────────────────────────

--[[ Pick a random public server for this place that is not full and is not the
     one we are in. Returns false, 0 when there is nowhere to go. ]]
function M.serverhop()
	local player = Players.LocalPlayer
	if not player then Guard.fail("there is no local player") end
	local placeId, jobId = game.PlaceId, game.JobId

	local ok, body = pcall(function()
		return game:HttpGet(string.format(SERVER_LIST_URL, tostring(placeId)))
	end)
	if not ok or type(body) ~= "string" then
		Guard.fail("could not reach the Roblox server list (%s)", tostring(body))
	end
	local decoded = Json.decode(body)
	if type(decoded) ~= "table" or type(decoded.data) ~= "table" then
		Guard.fail("the Roblox server list could not be read")
	end

	local servers = {}
	local list = decoded.data
	for i = 1, #list do
		local entry = list[i]
		if type(entry) == "table" and entry.id ~= jobId then
			local playing, capacity = tonumber(entry.playing), tonumber(entry.maxPlayers)
			if playing and capacity and playing < capacity then
				servers[#servers + 1] = entry.id
			end
		end
	end
	if #servers == 0 then return false, 0 end

	markRejoining()
	TeleportService:TeleportToPlaceInstance(placeId, servers[math.random(1, #servers)], player)
	return true, #servers
end

return M
