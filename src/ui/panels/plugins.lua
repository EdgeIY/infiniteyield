--[[═══════════════════════════════════════════════════════════════════════════
	ui/panels/plugins · the plugin list and the "Add Plugins" window
	─────────────────────────────────────────────────────────────────────────
	Legacy source.ref.lua 1370-1460 (the panel), 1462-1591 (the editor window),
	1608-1621 (the hint), 6367-6398 (refreshplugins) and 6480-6506 (the add /
	remove / navigation wiring).

	Loading, unloading, the file lookup and the saved list belong to
	features/plugins; this panel calls `add`, `remove` and `list` and shows what
	comes back. `refreshplugins(dontSave)` had a second job -- it wrote the
	settings file -- which is why it took an argument telling it not to; saving is
	the feature's business now, so the argument is gone.

	The rows are unregistered from the colour registries before being destroyed
	(legacy added five entries per row per refresh and removed none), and the
	hint is hidden rather than destroyed so it returns when the last plugin goes.
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Assets  = IY.import("ui/assets")
local Bin     = IY.import("core/bin")
local Chrome  = IY.import("ui/chrome")
local Env     = IY.import("core/env")
local Guard   = IY.import("core/guard")
local Lib     = IY.import("ui/lib")
local Notify  = IY.import("core/notify")
local Plugins = IY.import("features/plugins")
local Sched   = IY.import("core/scheduler")
local Theme   = IY.import("ui/theme")

local M = {}

M.frame   = nil             -- the list panel inside the settings frame
M.editor  = nil             -- the floating "Add Plugins" window
M.row     = nil
M.mounted = false

local bin  = Bin.new("ui/panels/plugins")
local rows = nil
M.bin = bin

local chrome   = nil
local holder   = nil
local template = nil
local hint     = nil
local fileName = nil        -- the file-name box in the editor

local OPEN          = UDim2.new(0, 0, 0, 0)
local CLOSED        = UDim2.new(0, 0, 0, 175)
local EDITOR_OPEN   = UDim2.new(0.5, -180, 0, 310)
local EDITOR_CLOSED = UDim2.new(0.5, -180, 0, -500)
local PLACEHOLDER   = "Plugin File Name"

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

-- ═══ the list panel ═════════════════════════════════════════════════════════

--[[ Legacy 1380-1406. ]]
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

--[[ Legacy 1370-1460 and 1608-1621. ]]
local function buildPanel()
	local frame = inst("Frame")
	frame.Name = "PluginsFrame"
	frame.Parent = chrome.settings
	frame.Active = true
	frame.BackgroundColor3 = Color3.fromRGB(36, 36, 37)
	frame.BorderSizePixel = 0
	frame.Position = UDim2.new(0, 0, 0, 175)
	frame.Size = UDim2.new(0, 250, 0, 175)
	frame.ZIndex = 10
	themed(frame, "shade1")

	local close = makeButton(frame, "Close", 205)
	close.Name = "Close"
	local add = makeButton(frame, "Add", 5)
	add.Name = "Add"

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
	text.Text = "F4 > Toggle Fly"
	text.TextColor3 = Color3.new(1, 1, 1)
	text.TextXAlignment = Enum.TextXAlignment.Left
	text.ZIndex = 10
	themed(text, "shade2")
	themed(text, "text1")

	local remove = inst("TextButton")
	remove.Name = "Delete"
	remove.Parent = text
	remove.BackgroundColor3 = Color3.fromRGB(78, 78, 79)
	remove.BorderSizePixel = 0
	remove.Position = UDim2.new(0, 200, 0, 0)
	remove.Size = UDim2.new(0, 40, 0, 20)
	remove.Font = Enum.Font.SourceSans
	remove.TextSize = 14
	remove.Text = "Delete"
	remove.TextColor3 = Color3.new(0, 0, 0)
	remove.ZIndex = 10
	themed(remove, "shade3")
	themed(remove, "text2")

	local label = inst("TextLabel")
	label.Name = "PluginsHint"
	label.Parent = frame
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.Position = UDim2.new(0, 25, 0, 40)
	label.Size = UDim2.new(0, 200, 0, 50)
	label.Font = Enum.Font.SourceSansItalic
	label.TextSize = 16
	label.Text = "Download plugins from the IY Discord (discord.gg/78ZuWSq)"
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeColor3 = Color3.new(1, 1, 1)
	label.TextWrapped = true
	label.ZIndex = 10
	themed(label, "text1")

	M.frame, holder, template, hint = frame, list, row, label

	bin:connect(close.MouseButton1Click, function() M.close() end)
	bin:connect(add.MouseButton1Click, function() M.openEditor() end)
end

-- ═══ the editor window ══════════════════════════════════════════════════════

--[[ One of the two paragraphs on the left. Legacy 1527-1555. ]]
local function makeParagraph(parent, name, text, y)
	local label = inst("TextLabel")
	label.Name = name
	label.Parent = parent
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.Position = UDim2.new(0, 17, 0, y)
	label.Size = UDim2.new(0, 187, 0, 49)
	label.Font = Enum.Font.SourceSans
	label.TextSize = 14
	label.Text = text
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextWrapped = true
	label.TextYAlignment = Enum.TextYAlignment.Top
	label.ZIndex = 10
	themed(label, "text1")
	return label
end

--[[ Legacy 1462-1591, plus 2245 (dragging). ]]
local function buildEditor()
	local editor = inst("Frame")
	editor.Name = Lib.randomName()
	editor.Parent = chrome.scaled
	editor.BorderSizePixel = 0
	editor.Active = true
	editor.BackgroundTransparency = 1
	editor.Position = EDITOR_CLOSED
	editor.Size = UDim2.new(0, 360, 0, 20)
	editor.ZIndex = 10

	local background = inst("Frame")
	background.Name = "background"
	background.Parent = editor
	background.Active = true
	background.BackgroundColor3 = Color3.fromRGB(36, 36, 37)
	background.BorderSizePixel = 0
	background.Position = UDim2.new(0, 0, 0, 20)
	background.Size = UDim2.new(0, 360, 0, 160)
	background.ZIndex = 10
	themed(background, "shade1")

	local divider = inst("Frame")
	divider.Name = "Dark"
	divider.Parent = background
	divider.Active = true
	divider.BackgroundColor3 = Color3.fromRGB(46, 46, 47)
	divider.BorderSizePixel = 0
	divider.Position = UDim2.new(0, 222, 0, 0)
	divider.Size = UDim2.new(0, 2, 0, 160)
	divider.ZIndex = 10
	themed(divider, "shade2")

	local image = inst("ImageButton")
	image.Name = "Img"
	image.Parent = background
	image.BackgroundTransparency = 1
	image.Position = UDim2.new(0, 242, 0, 3)
	image.Size = UDim2.new(0, 100, 0, 95)
	image.Image = Assets.get("infiniteyield/assets/imgstudiopluginlogo.png")
	image.ZIndex = 10

	local addPlugin = inst("TextButton")
	addPlugin.Name = "AddPlugin"
	addPlugin.Parent = background
	addPlugin.BackgroundColor3 = Color3.fromRGB(46, 46, 47)
	addPlugin.BorderSizePixel = 0
	addPlugin.Position = UDim2.new(0, 235, 0, 100)
	addPlugin.Size = UDim2.new(0, 115, 0, 50)
	addPlugin.Font = Enum.Font.SourceSans
	addPlugin.TextSize = 14
	addPlugin.Text = "Add Plugin"
	addPlugin.TextColor3 = Color3.new(1, 1, 1)
	addPlugin.ZIndex = 10
	themed(addPlugin, "shade2")
	themed(addPlugin, "text1")

	-- Not a PlaceholderText: legacy put the prompt in the box's Text and reset it
	-- there on close, and features/plugins refuses that exact name as a file.
	local box = inst("TextBox")
	box.Name = "FileName"
	box.Parent = background
	box.BackgroundColor3 = Color3.fromRGB(46, 46, 47)
	box.BorderSizePixel = 0
	box.Position = UDim2.new(0.028, 0, 0.625, 0)
	box.Size = UDim2.new(0, 200, 0, 50)
	box.Font = Enum.Font.SourceSans
	box.TextSize = 14
	box.Text = PLACEHOLDER
	box.TextColor3 = Color3.new(1, 1, 1)
	box.ZIndex = 10
	themed(box, "shade2")
	themed(box, "text1")

	makeParagraph(background, "About",
		"Plugins are .iy files and should be located in the 'workspace' folder of your exploit.", 10)
	makeParagraph(background, "Directions",
		"Type the name of the plugin file you want to add below.", 60)

	local shadow = inst("Frame")
	shadow.Name = "shadow"
	shadow.Parent = editor
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
	popup.Text = "Add Plugins"
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

	bin:add(Lib.drag(editor, editor, chrome.scale))

	M.editor, fileName = editor, box

	bin:connect(exit.MouseButton1Click, function() M.closeEditor() end)
	bin:connect(addPlugin.MouseButton1Click, function() M.add(box.Text) end)
end

-- ═══ add / remove ═══════════════════════════════════════════════════════════

--[[ Legacy 6480-6482 -> addPlugin (6314-6338). Every failure mode of the loader
     raises a user-facing message, which the legacy version only ever showed for
     one of them. ]]
function M.add(name)
	local ok, info = Guard.call("ui/panels/plugins.add", Plugins.add, name)
	if not ok then
		Notify.error("Plugin Error", Guard.describe(info))
		return false
	end
	Notify.send("Loaded Plugin", "Name: " .. info.name .. "\nDescription: " .. info.description)
	M.refresh()
	return true
end

--[[ Legacy deletePlugin (6340-6365). ]]
function M.remove(file)
	local ok, removed = Guard.call("ui/panels/plugins.remove", Plugins.remove, file)
	if not ok then
		Notify.error("Plugin Error", Guard.describe(removed))
		return false
	end
	if removed then Notify.send("Removed Plugin", file .. " was removed") end
	M.refresh()
	return true
end

-- ═══ the list ═══════════════════════════════════════════════════════════════

--[[ Legacy refreshplugins (6367-6397). ]]
function M.refresh()
	if not M.mounted or not holder then return false end
	rows:empty()
	holder.CanvasSize = UDim2.new(0, 0, 0, 10)

	local list = Plugins.list()
	hint.Visible = #list == 0

	for i = 1, #list do
		local file = list[i].file
		local position = (i * 25) - 25
		local row = template:Clone()
		rows:add(row)
		row.Visible = true
		row.Position = UDim2.new(0, 0, 0, position + 5)
		row.Text.Text = file
		themed(row, "shade2", rows)
		themed(row.Text, "shade2", rows)
		themed(row.Text, "text1", rows)
		themed(row.Text.Delete, "shade3", rows)
		themed(row.Text.Delete, "text2", rows)

		holder.CanvasSize = UDim2.new(0, 0, 0, position + 30)
		rows:connect(row.Text.Delete.MouseButton1Click, function()
			M.remove(file)
		end)
		row.Parent = holder
	end
	return true
end

-- ═══ open / close ═══════════════════════════════════════════════════════════

--[[ Legacy 6493-6501: the panel refuses to open at all on an executor that
     cannot read and write files, because every plugin is a file. ]]
function M.open()
	if not M.frame then return false end
	if not Env.canPersist then
		Notify.send("Incompatible Exploit",
			"Your exploit is unable to use plugins (missing read/writefile)")
		return false
	end
	M.frame:TweenPosition(OPEN, "InOut", "Quart", 0.5, true, nil)
	Sched.debounce("ui.panels.plugins.open", 0.5, function()
		if M.mounted and chrome.settingsHolder then
			chrome.settingsHolder.Visible = false
		end
	end)
	return true
end

--[[ Legacy 6503-6506. ]]
function M.close()
	if not M.frame then return false end
	if chrome.settingsHolder then chrome.settingsHolder.Visible = true end
	M.frame:TweenPosition(CLOSED, "InOut", "Quart", 0.5, true, nil)
	return true
end

--[[ Legacy 6489-6491. ]]
function M.openEditor()
	if not M.editor then return false end
	M.editor:TweenPosition(EDITOR_OPEN, "InOut", "Quart", 0.5, true, nil)
	return true
end

--[[ Legacy 6484-6487. ]]
function M.closeEditor()
	if not M.editor then return false end
	M.editor:TweenPosition(EDITOR_CLOSED, "InOut", "Quart", 0.5, true, nil)
	fileName.Text = PLACEHOLDER
	return true
end

-- ═══ mount / unmount ════════════════════════════════════════════════════════

function M.mount(context)
	if M.mounted then return true end
	chrome = context or Chrome
	if not chrome.mounted then chrome.mount() end

	rows = bin:branch("rows")
	buildPanel()
	buildEditor()

	-- 743 crops the shared sprite sheet to the plugin icon (legacy 624).
	local row = chrome.makeSettingsRow("Manage Plugins",
		Assets.get("infiniteyield/assets/bindsandplugins.png"), 743)
	row.Position = UDim2.new(0, 5, 0, 175)
	row.Size = UDim2.new(1, -10, 0, 25)
	row.Name = "Plugins"
	row.Parent = chrome.settingsHolder
	-- Chrome's bin holds it too; ours means a panel that unmounts on its own
	-- does not leave a dead row behind.
	bin:add(row)
	M.row = row
	bin:connect(row.MouseButton1Click, function() M.open() end)

	M.mounted = true
	-- `;addplugin` and friends change the list too. add()/remove() above refresh
	-- directly, so the panel is still correct on a build whose features/plugins
	-- has no signal yet.
	if Plugins.changed then
		bin:connect(Plugins.changed, function() M.refresh() end)
	end
	M.refresh()
	return true
end

function M.unmount()
	if not M.mounted then return false end
	M.mounted = false
	bin:empty()
	rows = nil
	chrome, holder, template, hint, fileName = nil, nil, nil, nil, nil
	M.frame, M.editor, M.row = nil, nil, nil
	return true
end

IY.onUnload(function()
	M.unmount()
	bin:destroy()
end, "ui/panels/plugins")

return M
