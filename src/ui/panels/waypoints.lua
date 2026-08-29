--[[═══════════════════════════════════════════════════════════════════════════
	ui/panels/waypoints · the waypoint list
	─────────────────────────────────────────────────────────────────────────
	Legacy source.ref.lua 1158-1277 (the panel), 1623-1636 (the empty-state
	hint), 4132-4141 (the navigation), 6037-6039 (Clear) and 6041-6099
	(refreshwaypoints).

	features/waypoints keeps one list where legacy kept three (`WayPoints`,
	`AllWaypoints`, `pWayPoints`), so the two loops that built this list -- one
	for coordinate waypoints and one for part waypoints, each with its own copy
	of the row code -- are a single pass over `Waypoints.list()`. The row buttons
	run `loadpos` and `dpos` through the dispatcher exactly as the legacy
	`execCmd` calls did, so a waypoint teleport from the panel behaves the same
	as one typed into the command bar.

	The rows are unregistered from the colour registries before they are
	destroyed; legacy left six entries per row behind on every refresh. The hint
	is hidden rather than destroyed, so it comes back when you clear your
	waypoints.

	The "Part" button belongs to this panel (legacy 1196-1208) but opens the
	teleport-to-part window, which is ui/panels/topart -- that panel connects to
	`M.partButton`.
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Assets    = IY.import("ui/assets")
local Bin       = IY.import("core/bin")
local Chrome    = IY.import("ui/chrome")
local Dispatch  = IY.import("cmd/dispatch")
local Sched     = IY.import("core/scheduler")
local Theme     = IY.import("ui/theme")
local Waypoints = IY.import("features/waypoints")

local M = {}

M.frame      = nil
M.row        = nil
M.partButton = nil          -- opens ui/panels/topart
M.mounted    = false

local bin  = Bin.new("ui/panels/waypoints")
local rows = nil
M.bin = bin

local chrome   = nil
local holder   = nil
local template = nil
local hint     = nil

local OPEN   = UDim2.new(0, 0, 0, 0)
local CLOSED = UDim2.new(0, 0, 0, 175)

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

--[[ Legacy 1168-1208: Part, Clear, Close. ]]
local function makeButton(parent, text, x)
	local button = inst("TextButton")
	button.Parent = parent
	button.BackgroundColor3 = Color3.fromRGB(46, 46, 47)
	button.BorderSizePixel = 0
	button.Position = UDim2.new(0, x, 0, 150)
	button.Size = UDim2.new(0, 40, 0, 20)
	button.Font = Enum.Font.SourceSans
	button.TextSize = 14
	button.Text = text
	button.TextColor3 = Color3.new(1, 1, 1)
	button.ZIndex = 10
	themed(button, "shade2")
	themed(button, "text1")
	return button
end

--[[ A row button: Goto at x=155, Delete at x=200. Legacy 1251-1277. ]]
local function makeRowButton(parent, name, text, x)
	local button = inst("TextButton")
	button.Name = name
	button.Parent = parent
	button.BackgroundColor3 = Color3.fromRGB(78, 78, 79)
	button.BorderSizePixel = 0
	button.Position = UDim2.new(0, x, 0, 0)
	button.Size = UDim2.new(0, 40, 0, 20)
	button.Font = Enum.Font.SourceSans
	button.TextSize = 14
	button.Text = text
	button.TextColor3 = Color3.new(0, 0, 0)
	button.ZIndex = 10
	themed(button, "shade3")
	themed(button, "text2")
	return button
end

--[[ Legacy 1158-1277 and 1623-1636. ]]
local function build()
	local frame = inst("Frame")
	frame.Name = "PositionsFrame"
	frame.Parent = chrome.settings
	frame.Active = true
	frame.BackgroundColor3 = Color3.fromRGB(36, 36, 37)
	frame.BorderSizePixel = 0
	frame.Size = UDim2.new(0, 250, 0, 175)
	frame.Position = UDim2.new(0, 0, 0, 175)
	frame.ZIndex = 10
	themed(frame, "shade1")

	local close = makeButton(frame, "Close", 205)
	close.Name = "Close"
	local clear = makeButton(frame, "Clear", 50)
	clear.Name = "Delete"
	local part = makeButton(frame, "Part", 5)
	part.Name = "PartGoto"

	local list = inst("ScrollingFrame")
	list.Name = "Holder"
	list.Parent = frame
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.Position = UDim2.new(0, 0, 0, 0)
	list.Selectable = false
	list.Size = UDim2.new(0, 250, 0, 145)
	list.ScrollBarImageColor3 = Color3.fromRGB(78, 78, 79)
	list.BottomImage = "rbxasset://textures/ui/Scroll/scroll-middle.png"
	list.CanvasSize = UDim2.new(0, 0, 0, 0)
	list.MidImage = "rbxasset://textures/ui/Scroll/scroll-middle.png"
	list.ScrollBarThickness = 0
	list.TopImage = "rbxasset://textures/ui/Scroll/scroll-middle.png"
	list.VerticalScrollBarInset = "Always"
	list.ZIndex = 10

	local row = inst("Frame")
	row.Name = "Example"
	row.Parent = frame
	row.BackgroundColor3 = Color3.fromRGB(46, 46, 47)
	row.BorderSizePixel = 0
	row.Size = UDim2.new(0, 10, 0, 20)
	row.Visible = false
	row.Position = UDim2.new(0, 0, 0, -5)
	row.ZIndex = 10
	themed(row, "shade2")

	local text = inst("TextLabel")
	text.Name = "Text"
	text.Parent = row
	text.BackgroundColor3 = Color3.fromRGB(46, 46, 47)
	text.BorderSizePixel = 0
	text.Position = UDim2.new(0, 10, 0, 0)
	text.Size = UDim2.new(0, 240, 0, 20)
	text.Font = Enum.Font.SourceSans
	text.TextSize = 14
	text.Text = "Position"
	text.TextColor3 = Color3.new(1, 1, 1)
	text.TextXAlignment = Enum.TextXAlignment.Left
	text.ZIndex = 10
	themed(text, "shade2")
	themed(text, "text1")

	makeRowButton(text, "Delete", "Delete", 200)
	makeRowButton(text, "TP", "Goto", 155)

	local label = inst("TextLabel")
	label.Name = "PositionsHint"
	label.Parent = frame
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.Position = UDim2.new(0, 25, 0, 40)
	label.Size = UDim2.new(0, 200, 0, 70)
	label.Font = Enum.Font.SourceSansItalic
	label.TextSize = 16
	label.Text = "Use the 'swp' or 'setwaypoint' command to add a position using your character (NOTE: Part teleports will not save)"
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeColor3 = Color3.new(1, 1, 1)
	label.TextWrapped = true
	label.ZIndex = 10
	themed(label, "text1")

	M.frame, holder, template, hint = frame, list, row, label
	M.partButton = part

	bin:connect(close.MouseButton1Click, function() M.close() end)
	-- Legacy 6037-6039: the same command the Clear button always ran.
	bin:connect(clear.MouseButton1Click, function() Dispatch.run("cpos") end)
end

-- ═══ the list ═══════════════════════════════════════════════════════════════

--[[ Legacy refreshwaypoints (6041-6099), one loop instead of two. ]]
function M.refresh()
	if not M.mounted or not holder then return false end
	rows:empty()
	holder.CanvasSize = UDim2.new(0, 0, 0, 10)

	local list = Waypoints.list()
	hint.Visible = #list == 0

	for i = 1, #list do
		local entry = list[i]
		local name = entry.name
		local position = (i * 25) - 25
		local row = template:Clone()
		rows:add(row)
		row.Visible = true
		row.Position = UDim2.new(0, 0, 0, position + 5)
		row.Text.Text = name
		themed(row, "shade2", rows)
		themed(row.Text, "shade2", rows)
		themed(row.Text, "text1", rows)
		themed(row.Text.Delete, "shade3", rows)
		themed(row.Text.Delete, "text2", rows)
		themed(row.Text.TP, "shade3", rows)
		themed(row.Text.TP, "text2", rows)

		holder.CanvasSize = UDim2.new(0, 0, 0, position + 30)
		rows:connect(row.Text.Delete.MouseButton1Click, function()
			Dispatch.run("dpos " .. name)
		end)
		rows:connect(row.Text.TP.MouseButton1Click, function()
			Dispatch.run("loadpos " .. name)
		end)
		row.Parent = holder
	end
	return true
end

-- ═══ open / close ═══════════════════════════════════════════════════════════

--[[ Legacy 4137-4141. ]]
function M.open()
	if not M.frame then return false end
	M.frame:TweenPosition(OPEN, "InOut", "Quart", 0.5, true, nil)
	Sched.debounce("ui.panels.waypoints.open", 0.5, function()
		if M.mounted and chrome.settingsHolder then
			chrome.settingsHolder.Visible = false
		end
	end)
	return true
end

--[[ Legacy 4132-4135. ]]
function M.close()
	if not M.frame then return false end
	if chrome.settingsHolder then chrome.settingsHolder.Visible = true end
	M.frame:TweenPosition(CLOSED, "InOut", "Quart", 0.5, true, nil)
	return true
end

-- ═══ mount / unmount ════════════════════════════════════════════════════════

function M.mount(context)
	if M.mounted then return true end
	chrome = context or Chrome
	if not chrome.mounted then chrome.mount() end

	rows = bin:branch("rows")
	build()

	local row = chrome.makeSettingsRow("Edit/Goto Waypoints",
		Assets.get("infiniteyield/assets/editwaypoints.png"))
	row.Position = UDim2.new(0, 5, 0, 145)
	row.Size = UDim2.new(1, -10, 0, 25)
	row.Name = "Waypoints"
	row.Parent = chrome.settingsHolder
	-- Chrome's bin holds it too; ours means a panel that unmounts on its own
	-- does not leave a dead row behind.
	bin:add(row)
	M.row = row
	bin:connect(row.MouseButton1Click, function() M.open() end)

	M.mounted = true
	-- Every waypoint command fires this, so the list is never stale.
	bin:connect(Waypoints.changed, function() M.refresh() end)
	M.refresh()
	return true
end

function M.unmount()
	if not M.mounted then return false end
	M.mounted = false
	bin:empty()
	rows = nil
	chrome, holder, template, hint = nil, nil, nil, nil
	M.frame, M.row, M.partButton = nil, nil, nil
	return true
end

IY.onUnload(function()
	M.unmount()
	bin:destroy()
end, "ui/panels/waypoints")

return M
