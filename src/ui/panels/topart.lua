--[[═══════════════════════════════════════════════════════════════════════════
	ui/panels/topart · the teleport-to-part window and the part picker
	─────────────────────────────────────────────────────────────────────────
	Legacy source.ref.lua 1638-1749 (the window) and 4143-4228 (the two
	SelectionBoxes, `selectPart`, Choose Part and Copy Path).

	It is opened by the "Part" button inside the waypoint panel, which is where
	the legacy `Part.MouseButton1Click` handler lived (4176-4178).

	  · the mouse Move and Button1Down connections were module locals that
	    `selectPart()` overwrote without disconnecting, so opening the picker
	    twice highlighted twice, and `;unloadiy` reached into this file to find
	    them. They are in a bin that is emptied on every open.
	  · the two SelectionBoxes were parented to the host ScreenGui and never
	    destroyed. Same bin.
	  · Copy Path used `getHierarchy`, which walked up with a repeat-until that
	    assumed a service ancestor and produced `nil` indexing for anything
	    else. `Inst.path` is the nil-safe rewrite.
	  · Choose Part wrote straight into the legacy `pWayPoints` array;
	    `Waypoints.addPart` owns that list now. The name-collision suffix is
	    kept, but it is checked against every waypoint rather than only the
	    part ones -- picking a part named like a saved coordinate waypoint used
	    to silently delete the coordinate one.
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Assets    = IY.import("ui/assets")
local Bin       = IY.import("core/bin")
local Chrome    = IY.import("ui/chrome")
local Env       = IY.import("core/env")
local Guard     = IY.import("core/guard")
local Inst      = IY.import("core/util/instances")
local Lib       = IY.import("ui/lib")
local Notify    = IY.import("core/notify")
local Services  = IY.import("core/services")
local Str       = IY.import("core/util/strings")
local Theme     = IY.import("ui/theme")
local Waypoints = IY.import("features/waypoints")

local M = {}

M.frame   = nil
M.mounted = false

local bin    = Bin.new("ui/panels/topart")
local picker = nil          -- branch bin: one picking session
M.bin = bin

local chrome       = nil
local mouse        = nil
local pathLabel    = nil
local hoverBox     = nil    -- follows the pointer
local selectedBox  = nil    -- stays on the part you clicked

local OPEN   = UDim2.new(0.5, -180, 0, 335)
local CLOSED = UDim2.new(0.5, -180, 0, -500)

local function inst(className, owner)
	local instance = Instance.new(className)
	local target = owner or bin
	target:add(instance)
	return instance
end

local function themed(instance, registry, owner)
	Theme.register(instance, registry)
	local target = owner or bin
	target:add(function() Theme.unregister(instance, registry) end)
	return instance
end

-- ═══ construction ═══════════════════════════════════════════════════════════

--[[ Legacy 1656-1682: the two buttons under the directions. ]]
local function makeButton(parent, name, text, x)
	local button = inst("TextButton")
	button.Name = name
	button.Parent = parent
	button.BackgroundColor3 = Color3.fromRGB(46, 46, 47)
	button.BorderSizePixel = 0
	button.Position = UDim2.new(0, x, 0, 55)
	button.Size = UDim2.new(0, 75, 0, 30)
	button.Font = Enum.Font.SourceSans
	button.TextSize = 14
	button.Text = text
	button.TextColor3 = Color3.new(1, 1, 1)
	button.ZIndex = 10
	themed(button, "shade2")
	themed(button, "text1")
	return button
end

--[[ Legacy 1638-1749, plus 2246 (dragging). ]]
local function build()
	local frame = inst("Frame")
	frame.Name = Lib.randomName()
	frame.Parent = chrome.scaled
	frame.Active = true
	frame.BackgroundTransparency = 1
	frame.Position = CLOSED
	frame.Size = UDim2.new(0, 360, 0, 20)
	frame.ZIndex = 10

	local background = inst("Frame")
	background.Name = "background"
	background.Parent = frame
	background.Active = true
	background.BackgroundColor3 = Color3.fromRGB(36, 36, 37)
	background.BorderSizePixel = 0
	background.Position = UDim2.new(0, 0, 0, 20)
	background.Size = UDim2.new(0, 360, 0, 117)
	background.ZIndex = 10
	themed(background, "shade1")

	local choose = makeButton(background, "ChoosePart", "Select Part", 100)
	local copy = makeButton(background, "CopyPath", "Copy Path", 185)

	local directions = inst("TextLabel")
	directions.Name = "Directions"
	directions.Parent = background
	directions.BackgroundTransparency = 1
	directions.BorderSizePixel = 0
	directions.Position = UDim2.new(0, 51, 0, 17)
	directions.Size = UDim2.new(0, 257, 0, 32)
	directions.Font = Enum.Font.SourceSans
	directions.TextSize = 14
	directions.Text = 'Click on a part and then click the "Select Part" button below to set it as a teleport location'
	directions.TextColor3 = Color3.new(1, 1, 1)
	directions.TextWrapped = true
	directions.TextYAlignment = Enum.TextYAlignment.Top
	directions.ZIndex = 10
	themed(directions, "text1")

	local path = inst("TextLabel")
	path.Name = "Path"
	path.Parent = background
	path.BackgroundTransparency = 1
	path.BorderSizePixel = 0
	path.Position = UDim2.new(0, 0, 0, 94)
	path.Size = UDim2.new(0, 360, 0, 16)
	path.Font = Enum.Font.SourceSansItalic
	path.TextSize = 14
	path.Text = ""
	path.TextColor3 = Color3.new(1, 1, 1)
	path.TextScaled = true
	path.TextWrapped = true
	path.TextYAlignment = Enum.TextYAlignment.Top
	path.ZIndex = 10
	themed(path, "text1")

	local shadow = inst("Frame")
	shadow.Name = "shadow"
	shadow.Parent = frame
	shadow.BackgroundColor3 = Color3.fromRGB(46, 46, 47)
	shadow.BorderSizePixel = 0
	shadow.Size = UDim2.new(0, 360, 0, 20)
	shadow.ZIndex = 10
	themed(shadow, "shade2")

	local popup = inst("TextLabel")
	popup.Name = "PopupText"
	popup.Parent = shadow
	popup.BackgroundTransparency = 1
	popup.Size = UDim2.new(1, 0, 0.95, 0)
	popup.ZIndex = 10
	popup.Font = Enum.Font.SourceSans
	popup.TextSize = 14
	popup.Text = "Teleport to Part"
	popup.TextColor3 = Color3.new(1, 1, 1)
	popup.TextWrapped = true
	themed(popup, "text1")

	local exit = inst("TextButton")
	exit.Name = "Exit"
	exit.Parent = shadow
	exit.BackgroundTransparency = 1
	exit.Position = UDim2.new(1, -20, 0, 0)
	exit.Size = UDim2.new(0, 20, 0, 20)
	exit.Text = ""
	exit.ZIndex = 10

	local exitImage = inst("ImageLabel")
	exitImage.Parent = exit
	exitImage.BackgroundColor3 = Color3.new(1, 1, 1)
	exitImage.BackgroundTransparency = 1
	exitImage.Position = UDim2.new(0, 5, 0, 5)
	exitImage.Size = UDim2.new(0, 10, 0, 10)
	exitImage.Image = Assets.get("infiniteyield/assets/close.png")
	exitImage.ZIndex = 10

	bin:add(Lib.drag(frame, frame, chrome.scale))

	M.frame, pathLabel = frame, path

	bin:connect(exit.MouseButton1Click, function() M.close() end)
	bin:connect(copy.MouseButton1Click, function() M.copyPath() end)
	bin:connect(choose.MouseButton1Click, function() M.choosePart() end)
end

--[[ Legacy 4143-4153. Parented to the host gui, as they were: a SelectionBox
     draws on its Adornee, so where it lives only decides when it dies. ]]
local function buildBoxes()
	hoverBox = inst("SelectionBox")
	hoverBox.Name = Lib.randomName()
	hoverBox.Color3 = Color3.new(255, 255, 255)
	hoverBox.Adornee = nil
	hoverBox.Parent = chrome.parent

	selectedBox = inst("SelectionBox")
	selectedBox.Name = Lib.randomName()
	selectedBox.Color3 = Color3.new(0, 166, 0)
	selectedBox.Adornee = nil
	selectedBox.Parent = chrome.parent
end

-- ═══ picking ════════════════════════════════════════════════════════════════

--[[ Legacy selectPart (4157-4174). Opening again replaces the two mouse
     connections instead of stacking a second pair on top of them. ]]
function M.open()
	if not M.frame then return false end
	M.frame:TweenPosition(OPEN, "InOut", "Quart", 0.5, true, nil)
	picker:empty()
	if not mouse then
		Notify.warn("Teleport to Part", "Your executor did not give us a mouse, so parts cannot be picked")
		return false
	end

	picker:connect(mouse.Move, function()
		if selectedBox.Adornee ~= mouse.Target then
			hoverBox.Adornee = mouse.Target
		else
			hoverBox.Adornee = nil
		end
	end)

	picker:connect(mouse.Button1Down, function()
		if mouse.Target ~= nil then
			selectedBox.Adornee = mouse.Target
			pathLabel.Text = Inst.path(mouse.Target)
		end
	end)
	return true
end

--[[ Legacy 4180-4191: closing stops picking and forgets the selection. ]]
function M.close()
	if not M.frame then return false end
	M.frame:TweenPosition(CLOSED, "InOut", "Quart", 0.5, true, nil)
	picker:empty()
	hoverBox.Adornee = nil
	selectedBox.Adornee = nil
	pathLabel.Text = ""
	return true
end

function M.selected()
	return selectedBox and selectedBox.Adornee or nil
end

--[[ Legacy 4193-4199. ]]
function M.copyPath()
	if not pathLabel or pathLabel.Text == "" then
		Notify.send("Copy Path", "Select a part to copy its path")
		return false
	end
	if not Env.usable("setclipboard") then
		Notify.error("Copy Path", "Your executor has no clipboard function")
		return false
	end
	Env.fn.setclipboard(pathLabel.Text)
	Notify.send("Copy Path", "Copied to clipboard")
	return true
end

--[[ Legacy handleWpNames (4204-4222): "Door", then "Door1", "Door2". Recursion
     replaced by a loop, and the collision test covers every waypoint rather
     than only the part ones. ]]
local function uniqueName(base)
	local taken = {}
	local names = Waypoints.names()
	for i = 1, #names do taken[Str.lower(names[i])] = true end
	if not taken[Str.lower(base)] then return base end
	local suffix = 1
	while taken[Str.lower(base .. tostring(suffix))] do suffix = suffix + 1 end
	return base .. tostring(suffix)
end

--[[ Legacy 4201-4228. ]]
function M.choosePart()
	local part = M.selected()
	if not pathLabel or pathLabel.Text == "" or not part then
		Notify.send("Part Selection", "Select a part first")
		return false
	end
	local name = uniqueName(part.Name)
	local ok, err = Guard.call("ui/panels/topart.choosePart", Waypoints.addPart, name, part)
	if not ok then
		Notify.error("Modified Waypoints", Guard.describe(err))
		return false
	end
	-- The waypoint panel redraws itself from Waypoints.changed; legacy called
	-- refreshwaypoints() by hand from here.
	Notify.send("Modified Waypoints", "Created waypoint: " .. name)
	return true
end

--[[ Nothing in this window is a list, so there is nothing to rebuild. ]]
function M.refresh()
	return true
end

-- ═══ mount / unmount ════════════════════════════════════════════════════════

function M.mount(context)
	if M.mounted then return true end
	chrome = context or Chrome
	if not chrome.mounted then chrome.mount() end

	picker = bin:branch("picker")
	mouse = Guard.try(function() return Services.Players.LocalPlayer:GetMouse() end)

	build()
	buildBoxes()

	-- The opener lives in the waypoint panel (legacy 1196-1208 built it there and
	-- 4176 wired it here). Missing when that panel failed to mount, which is not
	-- fatal: `M.open()` still works.
	local list = IY:tryImport("ui/panels/waypoints")
	if list and list.partButton then
		bin:connect(list.partButton.MouseButton1Click, function() M.open() end)
	end

	M.mounted = true
	return true
end

function M.unmount()
	if not M.mounted then return false end
	M.mounted = false
	bin:empty()
	picker = nil
	chrome, mouse, pathLabel = nil, nil, nil
	hoverBox, selectedBox = nil, nil
	M.frame = nil
	return true
end

IY.onUnload(function()
	M.unmount()
	bin:destroy()
end, "ui/panels/topart")

return M
