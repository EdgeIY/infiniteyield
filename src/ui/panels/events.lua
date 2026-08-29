--[[═══════════════════════════════════════════════════════════════════════════
	ui/panels/events · the event editor
	─────────────────────────────────────────────────────────────────────────
	Legacy source.ref.lua 2248-2774. The bus half of that closure -- registering
	events, storing binds, firing them, saving and loading -- is
	features/events; this file is its window: the list of events, the command
	rows under each one, and the slide-in settings editor for a row's conditions
	and delay.

	  · the eight `RegisterEvent` calls and the eight sources moved with the bus,
	    so an event bind still fires when the interface fails to mount.
	  · legacy 2405 indexed `events[...].commands` through an attribute read on
	    the row label, unguarded: any frame in the list that was not an event row
	    -- or an event that had been renamed -- made resizing the list throw. The
	    panel keeps its own array of rows.
	  · legacy 2683/2692 captured the loop index `i` in the Delete and FocusLost
	    handlers of each command row. Deleting a row above shifted every index
	    below it, so the next edit wrote to (or deleted) the wrong bind. Rows are
	    keyed by the bind table itself and the index is resolved at click time.
	  · legacy 2360 passed `currentShade1` as a positional array element instead
	    of `BackgroundColor3 = ...`, which only did no harm because the global
	    was still nil there; the template was left the default grey until the
	    theme applied. Written properly.
	  · opening the settings editor for a custom player/string filter enabled the
	    checkbox *before* filling the text box, and the enable callback copied the
	    empty box into the bind -- so looking at a filter deleted it. The initial
	    state is set silently now.
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Assets   = IY.import("ui/assets")
local Bin      = IY.import("core/bin")
local Chrome   = IY.import("ui/chrome")
local Events   = IY.import("features/events")
local Guard    = IY.import("core/guard")
local Lib      = IY.import("ui/lib")
local Notify   = IY.import("core/notify")
local Services = IY.import("core/services")
local Str      = IY.import("core/util/strings")
local Tbl      = IY.import("core/util/tables")
local Theme    = IY.import("ui/theme")

local TweenService = Services.TweenService

local M = {}

M.frame   = nil
M.row     = nil
M.mounted = false

local bin         = Bin.new("ui/panels/events")
local listBin     = nil     -- one refresh worth of event rows
local settingsBin = nil     -- one visit to the settings editor
M.bin = bin

local chrome = nil

-- The window's furniture, resolved once in build().
local content, eventList, eventListHolder = nil, nil, nil
local eventTemplate, cmdTemplate = nil, nil
local slider, settingsScroll, settingsList, templates = nil, nil, nil, nil

local rows       = {}       -- array of row records, in list order
local rowsByName = {}       -- name -> row record
local expanded   = {}       -- name -> bool, kept across a rebuild
local editing    = nil      -- the bind the settings editor is showing
local rebuilding = false    -- guards refresh() against re-entering itself

local OPEN   = UDim2.new(0.5, -175, 0.5, -101)
local CLOSED = UDim2.new(0.5, -175, 0, -500)
local SLIDER_OPEN   = UDim2.new(0, 0, 0, 0)
local SLIDER_CLOSED = UDim2.new(0, -150, 0, 0)

local TWEEN = TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)

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

-- ═══ shared shapes ══════════════════════════════════════════════════════════

--[[ A 20x20 box with a 16x16 tick inside it, as used by every checkbox in the
     interface. The tick's BackgroundTransparency is the state, so it is never
     themed. Legacy 2325-2326. ]]
local function checkboxBox(parent, name, x, y)
	local box = inst("Frame")
	box.Name = name
	box.Parent = parent
	box.BackgroundColor3 = Color3.fromRGB(78, 78, 79)
	box.BorderSizePixel = 0
	box.Position = UDim2.new(x[1], x[2], y[1], y[2])
	box.Size = UDim2.new(0, 20, 0, 20)
	box.ZIndex = 10
	themed(box, "shade3")

	local tick = inst("TextButton")
	tick.Name = "On"
	tick.Parent = box
	tick.BackgroundColor3 = Color3.fromRGB(150, 150, 151)
	tick.BackgroundTransparency = 1
	tick.BorderSizePixel = 0
	tick.Font = Enum.Font.SourceSans
	tick.Position = UDim2.new(0, 2, 0, 2)
	tick.Size = UDim2.new(0, 16, 0, 16)
	tick.Text = ""
	tick.TextColor3 = Color3.new(0, 0, 0)
	tick.TextSize = 14
	tick.ZIndex = 10
	return box
end

--[[ A labelled checkbox row inside a settings template. Legacy 2324-2329. ]]
local function checkboxRow(parent, name, text, y)
	local label = inst("TextLabel")
	label.Name = name
	label.Parent = parent
	label.BackgroundColor3 = Color3.fromRGB(46, 46, 47)
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.Font = Enum.Font.SourceSans
	label.Position = UDim2.new(0, 5, 0, y)
	label.Size = UDim2.new(1, -10, 0, 20)
	label.Text = text
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextSize = 14
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.ZIndex = 10
	themed(label, "text1")
	checkboxBox(label, "Button", { 1, -20 }, { 0, 0 })
	return label
end

--[[ The centred heading of a settings template. Legacy 2323. ]]
local function templateTitle(parent, text)
	local label = inst("TextLabel")
	label.Name = "Title"
	label.Parent = parent
	label.BackgroundColor3 = Color3.new(1, 1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.SourceSans
	label.Size = UDim2.new(1, 0, 0, 20)
	label.Text = text
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextSize = 14
	label.ZIndex = 10
	themed(label, "text1")
	return label
end

--[[ The free-text half of a settings template: a box plus its own checkbox.
     Legacy 2330-2332. ]]
local function customRow(parent, placeholder, y)
	local box = inst("TextBox")
	box.Name = "Custom"
	box.Parent = parent
	box.BackgroundColor3 = Color3.fromRGB(46, 46, 47)
	box.BorderColor3 = Color3.fromRGB(40, 40, 40)
	box.BorderSizePixel = 0
	box.ClearTextOnFocus = false
	box.Font = Enum.Font.SourceSans
	box.PlaceholderColor3 = Color3.fromRGB(120, 120, 120)
	box.PlaceholderText = placeholder
	box.Position = UDim2.new(0, 5, 0, y)
	box.Size = UDim2.new(1, -35, 0, 20)
	box.Text = ""
	box.TextColor3 = Color3.new(1, 1, 1)
	box.TextSize = 14
	box.TextXAlignment = Enum.TextXAlignment.Left
	box.ZIndex = 10
	themed(box, "shade2")
	themed(box, "text1")
	checkboxBox(parent, "CustomButton", { 1, -25 }, { 0, y })
	return box
end

local function templateFrame(parent, name, height)
	local frame = inst("Frame")
	frame.Name = name
	frame.Parent = parent
	frame.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
	frame.BackgroundTransparency = 1
	frame.BorderColor3 = Color3.fromRGB(40, 40, 40)
	frame.Position = UDim2.new(0, 0, 0, 25)
	frame.Size = UDim2.new(1, 0, 0, height)
	frame.Visible = false
	frame.ZIndex = 10
	return frame
end

-- ═══ templates ══════════════════════════════════════════════════════════════

--[[ The four things the settings editor clones. Legacy 2321-2351. ]]
local function buildTemplates(parent)
	templates = inst("Folder")
	templates.Name = "Templates"
	templates.Parent = parent

	local players = templateFrame(templates, "Players", 86)
	templateTitle(players, "Choose Players")
	checkboxRow(players, "Me", "Me Only", 20)
	checkboxRow(players, "Any", "Any Player", 42)
	customRow(players, "Custom Player Set", 64)

	local strings = templateFrame(templates, "Strings", 64)
	templateTitle(strings, "Choose String")
	checkboxRow(strings, "Any", "Any String", 20)
	customRow(strings, "Match String", 42)

	local numbers = templateFrame(templates, "Numbers", 64)
	-- Legacy says "Choose String" here as well; every clone overwrites it with
	-- the argument's own name, so it has never been visible.
	templateTitle(numbers, "Choose String")
	checkboxRow(numbers, "Any", "Any Number", 20)
	customRow(numbers, "Number", 42)

	local delayEditor = templateFrame(templates, "DelayEditor", 24)

	local secs = inst("TextBox")
	secs.Name = "Secs"
	secs.Parent = delayEditor
	secs.BackgroundColor3 = Color3.fromRGB(46, 46, 47)
	secs.BorderColor3 = Color3.fromRGB(40, 40, 40)
	secs.BorderSizePixel = 0
	secs.Font = Enum.Font.SourceSans
	secs.PlaceholderColor3 = Color3.fromRGB(120, 120, 120)
	secs.Position = UDim2.new(0, 60, 0, 2)
	secs.Size = UDim2.new(1, -65, 0, 20)
	secs.Text = ""
	secs.TextColor3 = Color3.new(1, 1, 1)
	secs.TextSize = 14
	secs.TextXAlignment = Enum.TextXAlignment.Left
	secs.ZIndex = 10
	themed(secs, "shade2")
	themed(secs, "text1")

	local secsLabel = inst("TextLabel")
	secsLabel.Name = "Label"
	secsLabel.Parent = secs
	secsLabel.BackgroundColor3 = Color3.fromRGB(46, 46, 47)
	secsLabel.BackgroundTransparency = 1
	secsLabel.BorderSizePixel = 0
	secsLabel.Font = Enum.Font.SourceSans
	secsLabel.Position = UDim2.new(0, -55, 0, 0)
	secsLabel.Size = UDim2.new(1, 0, 1, 0)
	secsLabel.Text = "Delay (s):"
	secsLabel.TextColor3 = Color3.new(1, 1, 1)
	secsLabel.TextSize = 14
	secsLabel.TextXAlignment = Enum.TextXAlignment.Left
	secsLabel.ZIndex = 10
	themed(secsLabel, "text1")
end

--[[ One event in the list: an expander, a name, and a clipped body holding its
     command rows plus the "add" box. Legacy 2352-2359. ]]
local function buildEventTemplate(parent)
	local frame = inst("Frame")
	frame.Name = "EventTemplate"
	frame.Parent = parent
	frame.BackgroundColor3 = Color3.fromRGB(36, 36, 37)
	frame.BorderSizePixel = 0
	frame.ClipsDescendants = true
	frame.Size = UDim2.new(1, 0, 0, 20)
	frame.Visible = false
	frame.ZIndex = 10
	themed(frame, "shade2")

	local expand = inst("TextButton")
	expand.Name = "Expand"
	expand.Parent = frame
	expand.BackgroundColor3 = Color3.new(1, 1, 1)
	expand.BackgroundTransparency = 1
	expand.Font = Enum.Font.SourceSans
	expand.Size = UDim2.new(0, 20, 0, 20)
	expand.Text = ">"
	expand.TextColor3 = Color3.new(1, 1, 1)
	expand.TextSize = 18
	expand.ZIndex = 10

	local name = inst("TextLabel")
	name.Name = "EventName"
	name.Parent = frame
	name.BackgroundColor3 = Color3.new(1, 1, 1)
	name.BackgroundTransparency = 1
	name.Font = Enum.Font.SourceSans
	name.Position = UDim2.new(0, 25, 0, 0)
	name.Size = UDim2.new(1, -25, 0, 20)
	name.Text = "OnSpawn"
	name.TextColor3 = Color3.new(1, 1, 1)
	name.TextSize = 14
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.ZIndex = 10
	themed(name, "text1")

	local cmds = inst("Frame")
	cmds.Name = "Cmds"
	cmds.Parent = frame
	cmds.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
	cmds.BackgroundTransparency = 1
	cmds.BorderSizePixel = 0
	cmds.ClipsDescendants = true
	cmds.Position = UDim2.new(0, 0, 0, 20)
	cmds.Size = UDim2.new(1, 0, 1, -20)
	cmds.ZIndex = 10

	local add = inst("Frame")
	add.Name = "Add"
	add.Parent = cmds
	add.BackgroundColor3 = Color3.fromRGB(36, 36, 37)
	add.BorderColor3 = Color3.fromRGB(46, 46, 47)
	add.Position = UDim2.new(0, 0, 1, -20)
	add.Size = UDim2.new(1, 0, 0, 20)
	add.ZIndex = 10
	themed(add, "shade1")

	local addBox = inst("TextBox")
	addBox.Parent = add
	addBox.BackgroundColor3 = Color3.new(1, 1, 1)
	addBox.BackgroundTransparency = 1
	addBox.ClearTextOnFocus = false
	addBox.Font = Enum.Font.SourceSans
	addBox.PlaceholderColor3 = Color3.fromRGB(200, 200, 200)
	addBox.PlaceholderText = "Add new command"
	addBox.Position = UDim2.new(0, 5, 0, 0)
	addBox.Size = UDim2.new(1, -10, 1, 0)
	addBox.Text = ""
	addBox.TextColor3 = Color3.new(1, 1, 1)
	addBox.TextSize = 14
	addBox.TextXAlignment = Enum.TextXAlignment.Left
	addBox.ZIndex = 10

	local holder = inst("Frame")
	holder.Name = "Holder"
	holder.Parent = cmds
	holder.BackgroundColor3 = Color3.new(1, 1, 1)
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.new(1, 0, 1, -20)
	holder.ZIndex = 10

	local layout = inst("UIListLayout")
	layout.Parent = holder
	layout.SortOrder = Enum.SortOrder.LayoutOrder

	eventTemplate = frame
end

--[[ One bound command: the line itself, a settings button and an X. Legacy
     2360-2364, with the misplaced positional colour written as a property. ]]
local function buildCommandTemplate(parent)
	local frame = inst("Frame")
	frame.Name = "CmdTemplate"
	frame.Parent = parent
	frame.BackgroundColor3 = Color3.fromRGB(36, 36, 37)
	frame.BorderSizePixel = 0
	frame.ClipsDescendants = true
	frame.Size = UDim2.new(1, 0, 0, 20)
	frame.Visible = false
	frame.ZIndex = 10
	themed(frame, "shade1")

	local box = inst("TextBox")
	box.Parent = frame
	box.BackgroundColor3 = Color3.new(1, 1, 1)
	box.BackgroundTransparency = 1
	box.ClearTextOnFocus = false
	box.Font = Enum.Font.SourceSans
	box.PlaceholderColor3 = Color3.new(1, 1, 1)
	box.Position = UDim2.new(0, 5, 0, 0)
	box.Size = UDim2.new(1, -45, 0, 20)
	box.Text = "a\\b\\c\\d"
	box.TextColor3 = Color3.new(1, 1, 1)
	box.TextSize = 14
	box.TextXAlignment = Enum.TextXAlignment.Left
	box.ZIndex = 10
	themed(box, "text1")

	local remove = inst("TextButton")
	remove.Name = "Delete"
	remove.Parent = frame
	remove.BackgroundColor3 = Color3.fromRGB(36, 36, 37)
	remove.BorderSizePixel = 0
	remove.Font = Enum.Font.SourceSans
	remove.Position = UDim2.new(1, -20, 0, 0)
	remove.Size = UDim2.new(0, 20, 0, 20)
	remove.Text = "X"
	remove.TextColor3 = Color3.new(1, 1, 1)
	remove.TextSize = 18
	remove.ZIndex = 10
	themed(remove, "shade2")

	local settings = inst("TextButton")
	settings.Name = "Settings"
	settings.Parent = frame
	settings.BackgroundColor3 = Color3.fromRGB(36, 36, 37)
	settings.BorderSizePixel = 0
	settings.Font = Enum.Font.SourceSans
	settings.Position = UDim2.new(1, -40, 0, 0)
	settings.Size = UDim2.new(0, 20, 0, 20)
	settings.Text = ""
	settings.TextColor3 = Color3.new(1, 1, 1)
	settings.TextSize = 18
	settings.ZIndex = 10
	themed(settings, "shade2")

	local icon = inst("ImageLabel")
	icon.Parent = settings
	icon.BackgroundColor3 = Color3.new(1, 1, 1)
	icon.BackgroundTransparency = 1
	icon.Image = Assets.get("infiniteyield/assets/settings.png")
	icon.Position = UDim2.new(0, 2, 0, 2)
	icon.Size = UDim2.new(0, 16, 0, 16)
	icon.ZIndex = 10

	cmdTemplate = frame
end

-- ═══ the window ═════════════════════════════════════════════════════════════

--[[ Legacy 2313-2320: the settings pane lives off the right edge of the content
     frame and slides in over it. ]]
local function buildSettingsPane(parent)
	local pane = inst("Frame")
	pane.Name = "Settings"
	pane.Parent = parent
	pane.BackgroundColor3 = Color3.fromRGB(36, 36, 37)
	pane.BackgroundTransparency = 1
	pane.BorderColor3 = Color3.fromRGB(80, 80, 80)
	pane.BorderSizePixel = 0
	pane.ClipsDescendants = true
	pane.Position = UDim2.new(1, 0, 0, 0)
	pane.Size = UDim2.new(0, 150, 1, 0)
	pane.ZIndex = 10

	slider = inst("Frame")
	slider.Name = "Slider"
	slider.Parent = pane
	slider.BackgroundColor3 = Color3.fromRGB(36, 36, 37)
	slider.Position = SLIDER_CLOSED
	slider.Size = UDim2.new(1, 0, 1, 0)
	slider.ZIndex = 10
	themed(slider, "shade1")

	local line = inst("Frame")
	line.Name = "Line"
	line.Parent = slider
	line.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
	line.BorderColor3 = Color3.fromRGB(80, 80, 80)
	line.BorderSizePixel = 0
	line.Size = UDim2.new(0, 1, 1, 0)
	line.ZIndex = 10
	themed(line, "shade2")

	settingsScroll = inst("ScrollingFrame")
	settingsScroll.Name = "List"
	settingsScroll.Parent = slider
	settingsScroll.BackgroundColor3 = Color3.fromRGB(36, 36, 37)
	settingsScroll.BackgroundTransparency = 1
	settingsScroll.BorderColor3 = Color3.fromRGB(40, 40, 40)
	settingsScroll.BorderSizePixel = 0
	settingsScroll.BottomImage = "rbxasset://textures/ui/Scroll/scroll-middle.png"
	settingsScroll.TopImage = "rbxasset://textures/ui/Scroll/scroll-middle.png"
	settingsScroll.CanvasSize = UDim2.new(0, 0, 0, 100)
	settingsScroll.Position = UDim2.new(0, 0, 0, 25)
	settingsScroll.ScrollBarImageColor3 = Color3.fromRGB(78, 78, 79)
	settingsScroll.ScrollBarThickness = 8
	settingsScroll.Size = UDim2.new(1, 0, 1, -25)
	settingsScroll.ZIndex = 10
	themed(settingsScroll, "scroll")

	settingsList = inst("Frame")
	settingsList.Name = "Holder"
	settingsList.Parent = settingsScroll
	settingsList.BackgroundColor3 = Color3.new(1, 1, 1)
	settingsList.BackgroundTransparency = 1
	settingsList.Size = UDim2.new(1, 0, 1, 0)
	settingsList.ZIndex = 10

	local layout = inst("UIListLayout")
	layout.Parent = settingsList
	layout.SortOrder = Enum.SortOrder.LayoutOrder

	-- Not themed, exactly as it was: this heading stays white.
	local title = inst("TextLabel")
	title.Name = "Title"
	title.Parent = slider
	title.BackgroundColor3 = Color3.new(1, 1, 1)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.SourceSans
	title.Size = UDim2.new(1, 0, 0, 20)
	title.Text = "Event Settings"
	title.TextColor3 = Color3.new(1, 1, 1)
	title.TextSize = 14
	title.ZIndex = 10

	local close = inst("TextButton")
	close.Name = "Close"
	close.Parent = slider
	close.BackgroundColor3 = Color3.fromRGB(36, 36, 37)
	close.BorderColor3 = Color3.fromRGB(40, 40, 40)
	close.BorderSizePixel = 0
	close.Font = Enum.Font.SourceSans
	close.Position = UDim2.new(1, -20, 0, 0)
	close.Size = UDim2.new(0, 20, 0, 20)
	close.Text = "<"
	close.TextColor3 = Color3.new(1, 1, 1)
	close.TextSize = 18
	close.ZIndex = 10
	themed(close, "shade2")

	buildTemplates(pane)

	bin:connect(close.MouseButton1Click, function() M.closeSettings() end)
end

--[[ Legacy 2304-2312 and 2366-2374. ]]
local function build()
	local frame = inst("Frame")
	frame.Name = Lib.randomName()
	frame.Parent = chrome.scaled
	frame.BackgroundColor3 = Color3.fromRGB(36, 36, 37)
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	frame.Position = CLOSED
	frame.Size = UDim2.new(0, 350, 0, 20)
	frame.ZIndex = 10

	local topBar = inst("Frame")
	topBar.Name = "TopBar"
	topBar.Parent = frame
	topBar.BackgroundColor3 = Color3.fromRGB(46, 46, 47)
	topBar.BorderSizePixel = 0
	topBar.Size = UDim2.new(1, 0, 0, 20)
	topBar.ZIndex = 10
	themed(topBar, "shade2")

	local title = inst("TextLabel")
	title.Name = "Title"
	title.Parent = topBar
	title.BackgroundColor3 = Color3.new(1, 1, 1)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.SourceSans
	title.Position = UDim2.new(0, 0, 0, 0)
	title.Size = UDim2.new(1, 0, 0.95, 0)
	title.Text = "Event Editor"
	title.TextColor3 = Color3.new(1, 1, 1)
	title.TextSize = 14
	title.TextXAlignment = Enum.TextXAlignment.Center
	title.ZIndex = 10

	local close = inst("TextButton")
	close.Name = "Close"
	close.Parent = topBar
	close.BackgroundColor3 = Color3.new(1, 1, 1)
	close.BackgroundTransparency = 1
	close.Font = Enum.Font.SourceSans
	close.Position = UDim2.new(1, -20, 0, 0)
	close.Size = UDim2.new(0, 20, 0, 20)
	close.Text = ""
	close.TextColor3 = Color3.new(1, 1, 1)
	close.TextSize = 14
	close.ZIndex = 10

	local closeImage = inst("ImageLabel")
	closeImage.Parent = close
	closeImage.BackgroundColor3 = Color3.new(1, 1, 1)
	closeImage.BackgroundTransparency = 1
	closeImage.Image = Assets.get("infiniteyield/assets/close.png")
	closeImage.Position = UDim2.new(0, 5, 0, 5)
	closeImage.Size = UDim2.new(0, 10, 0, 10)
	closeImage.ZIndex = 10

	content = inst("Frame")
	content.Name = "Content"
	content.Parent = frame
	content.BackgroundColor3 = Color3.fromRGB(36, 36, 37)
	content.BorderSizePixel = 0
	content.Position = UDim2.new(0, 0, 0, 20)
	content.Size = UDim2.new(1, 0, 0, 202)
	content.ZIndex = 10
	themed(content, "shade1")

	eventList = inst("ScrollingFrame")
	eventList.Name = "List"
	eventList.Parent = content
	eventList.BackgroundColor3 = Color3.fromRGB(36, 36, 37)
	eventList.BackgroundTransparency = 1
	eventList.BorderColor3 = Color3.fromRGB(40, 40, 40)
	eventList.BorderSizePixel = 0
	eventList.BottomImage = "rbxasset://textures/ui/Scroll/scroll-middle.png"
	eventList.TopImage = "rbxasset://textures/ui/Scroll/scroll-middle.png"
	eventList.CanvasSize = UDim2.new(0, 0, 0, 100)
	eventList.Position = UDim2.new(0, 5, 0, 5)
	eventList.ScrollBarImageColor3 = Color3.fromRGB(78, 78, 79)
	eventList.ScrollBarThickness = 8
	eventList.Size = UDim2.new(1, -10, 1, -10)
	eventList.ZIndex = 10
	themed(eventList, "scroll")

	eventListHolder = inst("Frame")
	eventListHolder.Name = "Holder"
	eventListHolder.Parent = eventList
	eventListHolder.BackgroundColor3 = Color3.new(1, 1, 1)
	eventListHolder.BackgroundTransparency = 1
	eventListHolder.Size = UDim2.new(1, 0, 1, 0)
	eventListHolder.ZIndex = 10

	local layout = inst("UIListLayout")
	layout.Parent = eventListHolder
	layout.SortOrder = Enum.SortOrder.LayoutOrder

	buildSettingsPane(content)
	buildEventTemplate(content)
	buildCommandTemplate(content)

	bin:add(Lib.drag(frame, frame, chrome.scale))

	M.frame = frame
	bin:connect(close.MouseButton1Click, function() M.close() end)
end

-- ═══ sizing ═════════════════════════════════════════════════════════════════

--[[ How tall one event row is: its own 20px, and when it is expanded 20px for
     every command plus 20 for the "add" box. Legacy computed the same number
     twice, once from `#Cmds.Holder:GetChildren()` (which counts the layout) and
     once from `1 + #commands`. ]]
local function rowHeight(row)
	if not row.expanded then return 20 end
	return 20 + 20 * (#Events.list(row.name) + 1)
end

local function sizeRow(row, animate)
	local size = UDim2.new(1, 0, 0, rowHeight(row))
	if animate then
		row.frame:TweenSize(size, Enum.EasingDirection.Out, Enum.EasingStyle.Quart, 0.25, true)
	else
		row.frame.Size = size
	end
end

--[[ Legacy resizeList (2398-2417), reading the panel's own rows instead of
     re-deriving the event from an attribute on a label. ]]
local function resizeList()
	if not eventList then return end
	local size = 0
	for i = 1, #rows do
		size = size + rowHeight(rows[i])
	end
	TweenService:Create(eventList, TWEEN, { CanvasSize = UDim2.new(0, 0, 0, size) }):Play()
	if size > eventList.AbsoluteSize.Y then
		eventListHolder.Size = UDim2.new(1, -8, 1, 0)
	else
		eventListHolder.Size = UDim2.new(1, 0, 1, 0)
	end
end

--[[ Legacy resizeSettingsList (2419-2435). ]]
local function resizeSettingsList()
	if not settingsList then return end
	local size = 0
	local children = settingsList:GetChildren()
	for i = 1, #children do
		if children[i]:IsA("Frame") then size = size + children[i].AbsoluteSize.Y end
	end
	settingsScroll.CanvasSize = UDim2.new(0, 0, 0, size)
	if size > settingsScroll.AbsoluteSize.Y then
		settingsList.Size = UDim2.new(1, -8, 1, 0)
	else
		settingsList.Size = UDim2.new(1, 0, 1, 0)
	end
end

-- ═══ the event list ═════════════════════════════════════════════════════════

--[[ Legacy refreshCommands (2663-2706). Rebuilds one event's command rows; the
     row records hold the bind table, so nothing depends on a captured index. ]]
local function refreshCommands(row)
	local name = row.name
	row.cmdsBin:empty()
	local list = Events.list(name)
	row.frame.EventName.Text = name .. (#list > 0 and (" (" .. tostring(#list) .. ")") or "")

	for i = 1, #list do
		local entry = list[i]
		local frame = cmdTemplate:Clone()
		row.cmdsBin:add(frame)
		local box = frame.TextBox
		Lib.viewportTextBox(box, row.cmdsBin)
		box.Text = entry.command
		frame.Visible = true
		themed(frame, "shade1", row.cmdsBin)
		themed(frame.Delete, "shade2", row.cmdsBin)
		themed(frame.Settings, "shade2", row.cmdsBin)

		row.cmdsBin:connect(box.FocusLost, function()
			entry.command = box.Text
			Events.save()
		end)

		row.cmdsBin:connect(frame.Settings.MouseButton1Click, function()
			M.openSettings(name, entry)
		end)

		row.cmdsBin:connect(frame.Delete.MouseButton1Click, function()
			-- Resolved now, not when the row was built.
			local index = Tbl.find(Events.list(name), entry)
			if index then Events.unbind(name, index) end
			if editing == entry then M.closeSettings() end
		end)

		frame.Parent = row.frame.Cmds.Holder
	end

	sizeRow(row, row.laidOut == true)
	row.laidOut = true
end

--[[ Legacy 2646-2725: one row per registered event. ]]
local function buildEventRow(name)
	local frame = eventTemplate:Clone()
	listBin:add(frame)
	frame.Visible = true
	themed(frame, "shade2", listBin)
	themed(frame.EventName, "text1", listBin)
	themed(frame.Cmds.Add, "shade1", listBin)

	local row = {
		name     = name,
		frame    = frame,
		expanded = expanded[name] == true,
		cmdsBin  = listBin:branch("cmds"),
	}
	rows[#rows + 1] = row
	rowsByName[name] = row
	frame.Expand.Rotation = row.expanded and 90 or 0

	listBin:connect(frame.Expand.MouseButton1Down, function()
		row.expanded = not row.expanded
		expanded[name] = row.expanded
		sizeRow(row, true)
		frame.Expand.Rotation = row.expanded and 90 or 0
		resizeList()
	end)

	local addBox = frame.Cmds.Add.TextBox
	Lib.viewportTextBox(addBox, listBin)
	listBin:connect(addBox.FocusLost, function(enter)
		if not enter then return end
		local text = addBox.Text
		addBox.Text = ""
		-- Legacy bound whatever was in the box, including nothing at all.
		if Str.trim(text) == "" then return end
		local ok, err = Guard.call("ui/panels/events.bind", Events.bind, name, { command = text })
		if not ok then Notify.error("Event Binds", Guard.describe(err)) end
	end)

	frame.Parent = eventListHolder
	refreshCommands(row)
end

--[[ Legacy refreshList (2643-2729). The store is primed first: reading a bind
     list can trigger the lazy load, and that fires `changed` -- which would
     re-enter this function and destroy the rows it is halfway through building. ]]
function M.refresh()
	if not M.mounted or rebuilding then return false end
	Events.prime()
	rebuilding = true
	listBin:empty()
	rows, rowsByName = {}, {}
	local names = Events.order
	for i = 1, #names do
		-- One row that cannot be built must not cost the other seven.
		Guard.call("ui/panels/events.row:" .. tostring(names[i]), buildEventRow, names[i])
	end
	rebuilding = false
	resizeList()
	return true
end

-- ═══ the settings editor ════════════════════════════════════════════════════

--[[ Legacy setupCheckbox (2437-2456). `silent` replaces the legacy `nocall`
     argument, and the mutual-exclusion calls pass it: the callbacks are what
     write the condition, so a checkbox turning another one off must not write
     anything itself. ]]
local function setupCheckbox(button, callback)
	local enabled = button.On.BackgroundTransparency == 0
	local api = {}

	local function update()
		button.On.BackgroundTransparency = enabled and 0 or 1
	end

	settingsBin:connect(button.On.MouseButton1Click, function()
		enabled = not enabled
		update()
		if callback then callback(enabled) end
	end)

	function api.enable(silent)
		if enabled then return end
		enabled = true
		update()
		if not silent and callback then callback(true) end
	end

	function api.disable(silent)
		if not enabled then return end
		enabled = false
		update()
		if not silent and callback then callback(false) end
	end

	function api.isEnabled()
		return enabled
	end

	return api
end

--[[ Legacy 2477-2533: me / anybody / a player selector expression. ]]
local function playerEditor(entry, index, set)
	local template = templates.Players:Clone()
	settingsBin:add(template)
	template.Title.Text = set.Name or "Player"

	local box = template.Custom
	local me, any, custom

	me = setupCheckbox(template.Me.Button, function(on)
		if not on then return end
		any.disable(true)
		custom.disable(true)
		entry.conditions[index] = 0
		Events.save()
	end)

	any = setupCheckbox(template.Any.Button, function(on)
		if not on then return end
		me.disable(true)
		custom.disable(true)
		entry.conditions[index] = 1
		Events.save()
	end)

	custom = setupCheckbox(template.CustomButton, function(on)
		if not on then return end
		me.disable(true)
		any.disable(true)
		entry.conditions[index] = box.Text
		Events.save()
	end)

	Lib.viewportTextBox(box, settingsBin)
	settingsBin:connect(box.FocusLost, function()
		if not custom.isEnabled() then return end
		entry.conditions[index] = box.Text
		Events.save()
	end)

	-- The text goes in before the box is ticked, and ticking is silent, so
	-- looking at a filter no longer overwrites it with an empty string.
	local value = entry.conditions[index]
	if value == 0 then
		me.enable(true)
	elseif value == 1 then
		any.enable(true)
	else
		box.Text = tostring(value)
		custom.enable(true)
	end

	template.Visible = true
	themed(template.Title, "text1", settingsBin)
	themed(template.CustomButton, "shade3", settingsBin)
	themed(template.Any.Button, "shade3", settingsBin)
	themed(template.Me.Button, "shade3", settingsBin)
	themed(template.Any, "text1", settingsBin)
	themed(template.Me, "text1", settingsBin)
	template.Parent = settingsList
end

--[[ Legacy 2534-2620: the String and Number editors, which differ only in the
     template they clone and in the Number one normalising what you type. ]]
local function valueEditor(entry, index, set, kind)
	local template = templates[kind == "Number" and "Numbers" or "Strings"]:Clone()
	settingsBin:add(template)
	template.Title.Text = set.Name or kind

	local box = template.Custom
	local any, custom

	any = setupCheckbox(template.Any.Button, function(on)
		if not on then return end
		custom.disable(true)
		entry.conditions[index] = 0
		Events.save()
	end)

	custom = setupCheckbox(template.CustomButton, function(on)
		if not on then return end
		any.disable(true)
		entry.conditions[index] = kind == "Number" and (tonumber(box.Text) or 0) or box.Text
		Events.save()
	end)

	Lib.viewportTextBox(box, settingsBin)
	settingsBin:connect(box.FocusLost, function()
		if kind == "Number" then
			-- Normalise what is displayed either way, but only write the
			-- condition when this row is the one in use: legacy wrote it even
			-- while "Any" was ticked, leaving the two out of step.
			local number = tonumber(box.Text) or 0
			box.Text = tostring(number)
			if not custom.isEnabled() then return end
			entry.conditions[index] = number
		else
			if not custom.isEnabled() then return end
			entry.conditions[index] = box.Text
		end
		Events.save()
	end)

	local value = entry.conditions[index]
	if value == 0 then
		any.enable(true)
	else
		box.Text = tostring(value)
		custom.enable(true)
	end

	template.Visible = true
	themed(template.Title, "text1", settingsBin)
	themed(template.Any, "text1", settingsBin)
	themed(template.Any.Button, "shade3", settingsBin)
	themed(template.CustomButton, "shade3", settingsBin)
	template.Parent = settingsList
end

--[[ Legacy openSettingsEditor (2458-2625): the delay box, then one editor per
     argument the event carries. ]]
function M.openSettings(name, entry)
	local record = Events.get(name)
	if not record or not settingsList then return false end
	editing = entry
	settingsBin:empty()

	local delayEditor = templates.DelayEditor:Clone()
	settingsBin:add(delayEditor)
	settingsBin:connect(delayEditor.Secs.FocusLost, function()
		entry.delay = tonumber(delayEditor.Secs.Text) or 0
		delayEditor.Secs.Text = tostring(entry.delay)
		Events.save()
	end)
	delayEditor.Secs.Text = tostring(entry.delay or 0)
	delayEditor.Visible = true
	themed(delayEditor.Secs, "shade2", settingsBin)
	themed(delayEditor.Secs, "text1", settingsBin)
	themed(delayEditor.Secs.Label, "text1", settingsBin)
	delayEditor.Parent = settingsList

	for i = 1, #record.sets do
		local set = record.sets[i]
		if set.Type == "Player" then
			playerEditor(entry, i, set)
		elseif set.Type == "String" then
			valueEditor(entry, i, set, "String")
		elseif set.Type == "Number" then
			valueEditor(entry, i, set, "Number")
		end
	end

	resizeSettingsList()
	slider:TweenPosition(SLIDER_OPEN, Enum.EasingDirection.Out, Enum.EasingStyle.Quart, 0.25, true)
	return true
end

--[[ Legacy 2394-2396. ]]
function M.closeSettings()
	if not slider then return false end
	editing = nil
	slider:TweenPosition(SLIDER_CLOSED, Enum.EasingDirection.Out, Enum.EasingStyle.Quart, 0.25, true)
	return true
end

-- ═══ open / close ═══════════════════════════════════════════════════════════

--[[ Legacy 4089-4091. ]]
function M.open()
	if not M.frame then return false end
	M.frame:TweenPosition(OPEN, "InOut", "Quart", 0.5, true, nil)
	return true
end

--[[ Legacy 2758-2760. ]]
function M.close()
	if not M.frame then return false end
	M.frame:TweenPosition(CLOSED, "InOut", "Quart", 0.5, true, nil)
	return true
end

-- ═══ mount / unmount ════════════════════════════════════════════════════════

function M.mount(context)
	if M.mounted then return true end
	chrome = context or Chrome
	if not chrome.mounted then chrome.mount() end

	listBin = bin:branch("rows")
	settingsBin = bin:branch("settings")
	build()

	-- 759 crops the shared sprite sheet to the event-bind icon (legacy 618).
	local row = chrome.makeSettingsRow("Edit Event Binds",
		Assets.get("infiniteyield/assets/bindsandplugins.png"), 759)
	row.Position = UDim2.new(0, 5, 0, 205)
	row.Size = UDim2.new(1, -10, 0, 25)
	row.Name = "EventBinds"
	row.Parent = chrome.settingsHolder
	-- Chrome's bin holds it too; ours means a panel that unmounts on its own
	-- does not leave a dead row behind.
	bin:add(row)
	M.row = row
	bin:connect(row.MouseButton1Click, function() M.open() end)

	M.mounted = true

	--[[ A bind added or removed touches one event, so only that row is rebuilt --
	     which is what legacy did by calling refreshCommands directly. A load
	     (or a settings reset) has no name and rebuilds the lot. ]]
	bin:connect(Events.changed, function(name)
		local target = name and rowsByName[name] or nil
		if target then
			refreshCommands(target)
			resizeList()
		else
			M.refresh()
		end
	end)

	M.refresh()
	return true
end

function M.unmount()
	if not M.mounted then return false end
	M.mounted = false
	bin:empty()
	listBin, settingsBin = nil, nil
	rows, rowsByName, editing = {}, {}, nil
	chrome, content, eventList, eventListHolder = nil, nil, nil, nil
	eventTemplate, cmdTemplate = nil, nil
	slider, settingsScroll, settingsList, templates = nil, nil, nil, nil
	M.frame, M.row = nil, nil
	return true
end

IY.onUnload(function()
	M.unmount()
	bin:destroy()
end, "ui/panels/events")

return M
