--[[═══════════════════════════════════════════════════════════════════════════
	features/alignmentkeys · comma and period pan the camera in 45° steps
	─────────────────────────────────────────────────────────────────────────
	Handy for lining a build up with the axes. The Emotes menu is switched off
	while it is on, because `.` opens it and would eat the keypress.

	The legacy pair (12691-12706) got the restore wrong in the way that is
	easiest to miss: `alignmentKeysEmotes` was re-read from
	`GetCoreGuiEnabled` on *every* invocation, so a second `;alignmentkeys`
	recorded the value the first one had already set -- false -- and
	`;unalignmentkeys` then "restored" the Emotes menu to disabled, for the rest
	of the session. It also leaked the first InputBegan connection, and
	`alignmentKeys:Disconnect()` threw when the off-command ran first.

	Snapshot records the original once, whoever asks; the connection lives in
	the bin, so a second start replaces it and `;unloadiy` clears it.

	Legacy equivalent: source.ref.lua 12691-12706.
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Feature  = IY.import("features/feature")
local Services = IY.import("core/services")
local Snapshot = IY.import("core/snapshot")
local Guard    = IY.import("core/guard")

local UserInputService = Services.UserInputService

local M = {}

local TAG = "alignmentkeys"

--[[ CoreGui visibility is a method pair rather than a property, so Snapshot has
     nothing to record. This proxy gives it one: reads go through
     GetCoreGuiEnabled, writes through SetCoreGuiEnabled, and `Parent` answers
     Snapshot's liveness test. It is created once at module scope because the
     snapshot registry keys its records weakly. ]]
local function coreGuiProxy(coreGuiType)
	local starterGui = Services.get("StarterGui")
	if not starterGui then return nil end
	return setmetatable({}, {
		__index = function(_, key)
			if key == "Enabled" then
				return Guard.try(function() return starterGui:GetCoreGuiEnabled(coreGuiType) end)
			end
			if key == "Name" then return "CoreGui." .. tostring(coreGuiType.Name) end
			if key == "Parent" then return starterGui end
			return nil
		end,
		__newindex = function(_, key, value)
			if key ~= "Enabled" then return end
			starterGui:SetCoreGuiEnabled(coreGuiType, value == true)
		end,
	})
end

-- Both are read at load: an old client without the EmotesMenu type must not
-- take the whole command pack down with it.
local emotesType = Guard.try(function() return Enum.CoreGuiType.EmotesMenu end)
local emotesMenu = emotesType and coreGuiProxy(emotesType) or nil

local PAN = {
	[Enum.KeyCode.Comma]  = -1,
	[Enum.KeyCode.Period] = 1,
}

local feature = Feature.new("alignmentkeys", {
	command  = "alignmentkeys",
	describe = "comma/period pan the camera",

	start = function(self)
		if emotesMenu then
			local ok = Snapshot.set(emotesMenu, "Enabled", false, TAG)
			if ok then
				self.bin:add(function() Snapshot.restore(emotesMenu, "Enabled") end)
			end
		end

		self.bin:connect(UserInputService.InputBegan, function(input, processed)
			if processed then return end
			local units = PAN[input.KeyCode]
			if not units then return end
			-- CurrentCamera is nil for a frame after a respawn.
			local camera = workspace.CurrentCamera
			if not camera then return end
			pcall(function() camera:PanUnits(units) end)
		end)
	end,
})

M.feature = feature

function M.start() return feature:start() end
function M.stop() return feature:stop() end
function M.toggle() return feature:toggle() end
function M.isRunning() return feature:isRunning() end

return M
