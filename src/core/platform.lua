--[[═══════════════════════════════════════════════════════════════════════════
	core/platform · what kind of client are we on
	─────────────────────────────────────────────────────────────────────────
	Detected once, at load, with a fallback chain -- `UserInputService:GetPlatform()`
	throws on some clients, and TouchEnabled alone reports true for laptops with
	touchscreens. Kept out of core/env because it needs services, and services
	needs env.
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Services = IY.import("core/services")
local Guard    = IY.import("core/guard")

local UserInputService = Services.UserInputService

local M = {}

M.platform = "Unknown"
do
	local ok, platform = pcall(function() return UserInputService:GetPlatform() end)
	if ok and platform then M.platform = platform.Name or tostring(platform) end

	local mobilePlatforms = { Android = true, IOS = true }
	if ok and platform then
		M.isMobile = mobilePlatforms[platform.Name] == true
	end
	if M.isMobile == nil then
		M.isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	end

	local consolePlatforms = { XBoxOne = true, PS4 = true, PS3 = true, XBox360 = true }
	M.isConsole = (ok and platform and consolePlatforms[platform.Name]) == true
end

M.isDesktop = not M.isMobile and not M.isConsole

--[[ Legacy chat means the old TextChatService-less pipeline; several features
     have to take a completely different code path for it. ]]
M.isLegacyChat = Guard.try(function()
	return Services.TextChatService.ChatVersion == Enum.ChatVersion.LegacyChatService
end) == true

M.placeId = Guard.try(function() return game.PlaceId end) or 0
M.jobId   = Guard.try(function() return game.JobId end) or ""
M.gameId  = Guard.try(function() return game.GameId end) or 0

M.isStudio = Guard.try(function() return Services.RunService:IsStudio() end) == true

function M.snapshot()
	return {
		platform = M.platform,
		mobile   = M.isMobile,
		console  = M.isConsole,
		legacyChat = M.isLegacyChat,
		placeId  = M.placeId,
		jobId    = M.jobId,
		studio   = M.isStudio,
	}
end

IY.isMobile = M.isMobile
IY.platform = M

return M
