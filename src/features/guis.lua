--[[═══════════════════════════════════════════════════════════════════════════
	features/guis · showguis / hideguis / guidelete state
	─────────────────────────────────────────────────────────────────────────
	Replaces source.ref.lua 7804-7868: the `invisGUIS` and `hiddenGUIS` arrays,
	`deleteGuisAtPos`, and the `deleteGuiInput` connection.

	Three fixes:

	  · the un-commands restore through core/snapshot instead of assuming the
	    opposite of what they set. `unshowguis` walked its array writing
	    `v.Visible = false` unguarded, so one destroyed frame threw and every
	    entry after it stayed visible.
	  · `guidelete` is a feature, so re-running it replaces its input connection
	    instead of stacking another. The legacy version overwrote `deleteGuiInput`
	    without disconnecting, so `;guidelete` twice deleted two GUIs per
	    keypress and `unguidelete` could only ever stop the last one.
	  · no pass touches Infinite Yield's own window. With no CoreGui the
	    interface lives in the PlayerGui, where `hideguis` used to hide the
	    command bar and `guidelete` could destroy it outright.

	When both sweeps touch the same frame the *first* one owns the recorded
	original, which is the whole point of the snapshot registry: whichever
	un-command runs puts back the value the game started with, where the two
	legacy arrays fought over it.
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Feature  = IY.import("features/feature")
local Guard    = IY.import("core/guard")
local Services = IY.import("core/services")
local Snapshot = IY.import("core/snapshot")

local Players          = Services.Players
local UserInputService = Services.UserInputService

local M = {}

-- The three classes the legacy scan counted as "a GUI" (7807, 7826).
local function isPanel(instance)
	return instance:IsA("Frame") or instance:IsA("ImageLabel")
		or instance:IsA("ScrollingFrame")
end

local function playerGui()
	local player = Players.LocalPlayer
	local gui = player and player:FindFirstChildWhichIsA("PlayerGui")
	if not gui then Guard.fail("your PlayerGui is not available yet") end
	return gui
end

--[[ ui/lib is consulted only when it is already loaded, so this module still
     works with no interface at all. ]]
local function isOurs(instance)
	if not IY:isLoaded("ui/lib") then return false end
	local Lib = IY.import("ui/lib")
	local host = Lib and Lib.host
	if not host then return false end
	if instance == host then return true end
	local ok, inside = pcall(function() return instance:IsDescendantOf(host) end)
	return ok and inside == true
end

--[[ One pass over the PlayerGui: set `Visible` to `value` on every panel that
     currently holds the opposite, recording the original under `tag`. ]]
local function sweep(value, tag)
	local changed = 0
	local descendants = playerGui():GetDescendants()
	for i = 1, #descendants do
		local item = descendants[i]
		if isPanel(item) and item.Visible ~= value and not isOurs(item) then
			if Snapshot.set(item, "Visible", value, tag) then changed = changed + 1 end
		end
	end
	return changed
end

local shown = Feature.new("guis.shown", {
	command  = "showguis",
	describe = "hidden GUIs forced visible",
	start = function(self)
		-- Registered before the sweep, so a failure part-way through still puts
		-- back everything it had already changed.
		self.bin:add(function() Snapshot.restoreTag("guis.shown") end)
		self.state.count = sweep(true, "guis.shown")
	end,
})

local hiddenGuis = Feature.new("guis.hidden", {
	command  = "hideguis",
	describe = "visible GUIs forced hidden",
	start = function(self)
		self.bin:add(function() Snapshot.restoreTag("guis.hidden") end)
		self.state.count = sweep(false, "guis.hidden")
	end,
})

--[[ Legacy deleteGuisAtPos (7842-7851). Mouse.X/Y rather than
     UserInputService:GetMouseLocation(), because those coordinates exclude the
     topbar inset and GetGuiObjectsAtPosition expects them that way. ]]
function M.deleteUnderCursor()
	local mouse = Guard.try(function() return Players.LocalPlayer:GetMouse() end)
	if not mouse then return 0 end
	local gui = Guard.try(playerGui)
	if not gui then return 0 end
	local objects = Guard.try(function()
		return gui:GetGuiObjectsAtPosition(mouse.X, mouse.Y)
	end)
	if type(objects) ~= "table" then return 0 end

	local removed = 0
	for i = 1, #objects do
		local item = objects[i]
		local visible = Guard.try(function() return item.Visible end)
		if visible == true and not isOurs(item) then
			if Guard.try(function() item:Destroy() return true end) then
				removed = removed + 1
			end
		end
	end
	return removed
end

local deleter = Feature.new("guis.delete", {
	command  = "guidelete",
	describe = "backspace deletes the GUI under the cursor",
	start = function(self)
		self.bin:connect(UserInputService.InputBegan, function(input, gameProcessed)
			if gameProcessed then return end
			if input.KeyCode ~= Enum.KeyCode.Backspace then return end
			M.deleteUnderCursor()
		end)
	end,
})

M.shownFeature  = shown
M.hiddenFeature = hiddenGuis
M.deleteFeature = deleter

--[[ Each returns how many frames it changed, so the command can say so. ]]
function M.show()
	shown:start()
	return shown.state.count or 0
end

function M.unshow()
	return shown:stop()
end

function M.hide()
	hiddenGuis:start()
	return hiddenGuis.state.count or 0
end

function M.unhide()
	return hiddenGuis:stop()
end

function M.startDelete() return deleter:start() end
function M.stopDelete()  return deleter:stop() end
function M.deleting()    return deleter:isRunning() end

return M
