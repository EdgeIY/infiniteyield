--[[═══════════════════════════════════════════════════════════════════════════
	features/serverinfo · what this server is
	─────────────────────────────────────────────────────────────────────────
	Replaces the *data* half of source.ref.lua 6611-6937. The other 300 lines
	were a hand-built GUI; the interface is a panel now, and it calls
	`ServerInfo.collect()` for exactly the same numbers. `;serverinfo` itself
	notifies the summary and puts the full report on the clipboard.

	Everything is read defensively: `MarketplaceService:GetProductInfo` yields
	and throws in games that block it, `GetNetworkPing` does not exist on every
	client, and `GetRealPhysicsFPS` is deprecated. The legacy panel called all
	three unguarded and showed "LOADING" forever when any of them failed.
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Guard    = IY.import("core/guard")
local Services = IY.import("core/services")

local Players    = Services.Players
local RunService = Services.RunService

local M = {}

-- GetProductInfo is a web call; ask once per session.
local productInfo = nil

local function place()
	if productInfo then return productInfo end
	local ok, info = pcall(function()
		return Services.MarketplaceService:GetProductInfo(game.PlaceId)
	end)
	if ok and type(info) == "table" then
		productInfo = info
		return info
	end
	return nil
end

local function creator()
	local info = place()
	if info and type(info.Creator) == "table" and info.Creator.Name then
		return tostring(info.Creator.Name)
	end
	local kind = Guard.try(function() return game.CreatorType.Name end) or "User"
	local id = Guard.try(function() return game.CreatorId end) or 0
	return kind .. " " .. tostring(id)
end

--[[ h/m/s, matching the legacy "Run Time" readout. ]]
local function duration(seconds)
	seconds = math.floor(tonumber(seconds) or 0)
	local hours = math.floor(seconds / 3600)
	local minutes = math.floor((seconds % 3600) / 60)
	local rest = seconds % 60
	if hours > 0 then
		return string.format("%d hour(s), %d minute(s), %d second(s)", hours, minutes, rest)
	elseif minutes > 0 then
		return string.format("%d minute(s), %d second(s)", minutes, rest)
	end
	return string.format("%d second(s)", rest)
end
M.duration = duration

local function ping()
	local player = Players.LocalPlayer
	if not player then return nil end
	local ok, value = pcall(function() return player:GetNetworkPing() end)
	if ok and type(value) == "number" then return math.floor(value * 1000 + 0.5) end
	local stats = Services.get("Stats")
	if stats then
		local okStat, item = pcall(function()
			return stats.Network.ServerStatsItem["Data Ping"]:GetValue()
		end)
		if okStat and type(item) == "number" then return math.floor(item + 0.5) end
	end
	return nil
end

--[[ GetRealPhysicsFPS where it exists, otherwise one frame of RenderStepped.
     Waiting a frame is fine: collect() is only ever called from a command. ]]
local function fps()
	local ok, value = pcall(function() return workspace:GetRealPhysicsFPS() end)
	if ok and type(value) == "number" and value > 0 then return math.floor(value + 0.5) end
	local okStep, delta = pcall(function() return RunService.RenderStepped:Wait() end)
	if okStep and type(delta) == "number" and delta > 0 then
		return math.floor(1 / delta + 0.5)
	end
	return nil
end

--[[ Roblox exposes no server region, so this is the region Roblox reports for
     *you*. IY deliberately does not ask a third-party geolocation service. ]]
local function region()
	local player = Players.LocalPlayer
	local service = Services.get("LocalizationService")
	if not player or not service then return nil end
	local ok, value = pcall(function()
		return service:GetCountryRegionForPlayerAsync(player)
	end)
	if ok and type(value) == "string" and value ~= "" then return value end
	return nil
end

-- How long this client has been in the server, as opposed to the server's own
-- uptime (DistributedGameTime).
local joinedAt = os.clock and os.clock() or 0

-- ── public API ──────────────────────────────────────────────────────────────

--[[ Everything the panel and the command both need. May yield briefly. ]]
function M.collect()
	local info = place()
	local player = Players.LocalPlayer
	local uptime = Guard.try(function() return workspace.DistributedGameTime end) or 0
	return {
		place       = info and tostring(info.Name) or "Unknown",
		placeId     = Guard.try(function() return game.PlaceId end) or 0,
		gameId      = Guard.try(function() return game.GameId end) or 0,
		jobId       = Guard.try(function() return game.JobId end) or "",
		creator     = creator(),
		players     = #Players:GetPlayers(),
		maxPlayers  = Guard.try(function() return Players.MaxPlayers end) or 0,
		uptime      = uptime,
		session     = (os.clock and os.clock() or 0) - joinedAt,
		region      = region(),
		fps         = fps(),
		ping        = ping(),
		userId      = player and player.UserId or 0,
		appearanceId = player and Guard.try(function() return player.CharacterAppearanceId end) or 0,
	}
end

--[[ The one-liner the notification shows. ]]
function M.summary(info)
	info = info or M.collect()
	local parts = {
		info.place,
		tostring(info.players) .. "/" .. tostring(info.maxPlayers) .. " players",
		"up " .. duration(info.uptime),
	}
	if info.ping then parts[#parts + 1] = tostring(info.ping) .. "ms" end
	if info.fps then parts[#parts + 1] = tostring(info.fps) .. " fps" end
	return table.concat(parts, "\n")
end

--[[ The full report, which is what lands on the clipboard. ]]
function M.format(info)
	info = info or M.collect()
	local lines = {
		"Place: " .. info.place,
		"Creator: " .. info.creator,
		"Place ID: " .. tostring(info.placeId),
		"Game ID: " .. tostring(info.gameId),
		"Job ID: " .. tostring(info.jobId),
		"Players: " .. tostring(info.players) .. " / " .. tostring(info.maxPlayers),
		"Server age: " .. duration(info.uptime),
		"Your session: " .. duration(info.session),
		"Region: " .. tostring(info.region or "unknown"),
		"FPS: " .. tostring(info.fps or "unknown"),
		"Ping: " .. (info.ping and (tostring(info.ping) .. "ms") or "unknown"),
		"User ID: " .. tostring(info.userId),
		"Appearance ID: " .. tostring(info.appearanceId),
	}
	return table.concat(lines, "\n")
end

--[[ Join link for this exact instance, used by ;jobid. ]]
function M.joinLink()
	return "roblox://placeId=" .. tostring(game.PlaceId)
		.. "&gameInstanceId=" .. tostring(game.JobId)
end

return M
