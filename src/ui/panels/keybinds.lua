--[[═══════════════════════════════════════════════════════════════════════════
	ui/panels/keybinds · the keybind list and the keybind editor
	─────────────────────────────────────────────────────────────────────────
	Legacy source.ref.lua 783-886 (the list inside the settings panel), 888-1156
	(the editor window), 4089-4141 (the settings-panel navigation), 5977-6035
	(refreshbinds / unkeybind) and 6129-6262 (the editor's wiring, including the
	two "Add" shortcuts for click teleport and click delete).

	Everything the keybinds themselves do -- storing, saving, matching a
	keystroke, running the command -- belongs to cmd/binds. This file reads
	`Binds.list()`, writes through `Binds.add`/`remove`/`clear`, and rebuilds
	itself from `Binds.changed`, so no command has to remember to refresh the
	panel the way legacy `refreshbinds()` calls had to.

	Three legacy problems are gone:

	  · `Keybinds.MouseButton1Click` was connected twice (4093 and 4104) with
	    byte-identical bodies, so every click ran the slide tween and its
	    half-second sleep twice. Connected once.
	  · the list rows were pushed into the four colour registries on every
	    refresh and never taken out, so the registries grew without bound and
	    each theme change got slower for the rest of the session. Rows live in a
	    bin that unregisters them before it destroys them.
	  · the "Bind to" flow used four module-level globals (`awaitingInput`,
	    `keySelected`, `keyPressed`, `bindChosenKeyUp`) and its own InputBegan
	    handler. It is `Binds.captureNext` and three locals now, and the pending
	    capture is cancelled when the window closes instead of staying armed.
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Assets = IY.import("ui/assets")
local Bin    = IY.import("core/bin")
local Binds  = IY.import("cmd/binds")
local Chrome = IY.import("ui/chrome")
local Guard  = IY.import("core/guard")
local Lib    = IY.import("ui/lib")
local Notify = IY.import("core/notify")
local Sched  = IY.import("core/scheduler")
local Theme  = IY.import("ui/theme")

local M = {}

M.frame   = nil             -- the list panel inside the settings frame
M.editor  = nil             -- the floating "Set Keybinds" window
M.row     = nil             -- the "Edit Keybinds" settings row
M.mounted = false

local bin  = Bin.new("ui/panels/keybinds")
local rows = nil            -- branch bin: one refresh worth of list rows
M.bin = bin

local chrome   = nil
local holder   = nil        -- the scrolling list
local template = nil        -- the hidden row it clones

local commandBox, toggleBox = nil, nil
local bindToButton, triggerButton, toggleTick, toggleView = nil, nil, nil, nil

-- What the editor has collected so far. Legacy kept these as module globals.
local chosenKey     = nil
local bindKeyUp     = false
local makeToggle    = false
local cancelCapture = nil

local OPEN          = UDim2.new(0, 0, 0, 0)
local CLOSED        = UDim2.new(0, 0, 0, 175)
local EDITOR_OPEN   = UDim2.new(0.5, -180, 0, 260)
local EDITOR_CLOSED = UDim2.new(0.5, -180, 0, -500)

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

--[[ Legacy 793-833: the three buttons along the bottom. ]]
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

--[[ Legacy 783-886. ]]
local function buildPanel()
	local frame = inst("Frame")
	frame.Name = "KeybindsFrame"
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
	local clear = makeButton(frame, "Clear", 50)
	clear.Name = "Delete"

	local list = inst("ScrollingFrame")
	list.Name = "Holder"
	list.Parent = frame
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.Position = UDim2.new(0, 0, 0, 0)
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
	text.Text = "nom"
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

	M.frame, holder, template = frame, list, row

	bin:connect(close.MouseButton1Click, function() M.close() end)
	bin:connect(add.MouseButton1Click, function() M.openEditor() end)
	bin:connect(clear.MouseButton1Click, function()
		Binds.clear()
		Notify.send("Keybinds Updated", "Removed all keybinds")
	end)
end

-- ═══ the editor window ══════════════════════════════════════════════════════

--[[ One of the two rows in the Toggles list: a label with an "Add" button that
     binds a fixed command. Legacy 1000-1055. ]]
local function makeToggleRow(parent, name, label, y)
	local row = inst("TextLabel")
	row.Name = name
	row.Parent = parent
	row.BackgroundColor3 = Color3.fromRGB(46, 46, 47)
	row.BorderSizePixel = 0
	row.Position = UDim2.new(0, 0, 0, y)
	row.Size = UDim2.new(0, 200, 0, 20)
	row.ZIndex = 10
	row.Font = Enum.Font.SourceSans
	row.Text = label
	row.TextColor3 = Color3.fromRGB(255, 255, 255)
	row.TextSize = 14
	row.TextXAlignment = Enum.TextXAlignment.Left
	themed(row, "shade2")
	themed(row, "text1")

	local select = inst("TextButton")
	select.Name = "Select"
	select.Parent = row
	select.BackgroundColor3 = Color3.fromRGB(78, 78, 79)
	select.BorderSizePixel = 0
	select.Position = UDim2.new(0, 160, 0, 0)
	select.Size = UDim2.new(0, 40, 0, 20)
	select.ZIndex = 10
	select.Font = Enum.Font.SourceSans
	select.Text = "Add"
	select.TextColor3 = Color3.fromRGB(0, 0, 0)
	select.TextSize = 14
	themed(select, "shade3")
	themed(select, "text2")
	return select
end

--[[ One of the two command boxes. Both are wrapped by ViewportTextBox, which
     replaces them in the tree with a clipping frame -- which is why legacy
     addressed the second one as `Cmdbar_3.Parent` when hiding it. ]]
local function makeCommandBox(parent, name, placeholder, y)
	local box = inst("TextBox")
	box.Name = name
	box.Parent = parent
	box.BackgroundColor3 = Color3.fromRGB(46, 46, 47)
	box.BorderSizePixel = 0
	box.Position = UDim2.new(0, 150, 0, y)
	box.Size = UDim2.new(0, 150, 0, 20)
	box.ZIndex = 10
	box.Font = Enum.Font.SourceSans
	box.PlaceholderText = placeholder
	box.Text = ""
	box.TextColor3 = Color3.fromRGB(255, 255, 255)
	box.TextSize = 14
	box.TextXAlignment = Enum.TextXAlignment.Left
	return box
end

--[[ Legacy 888-1156 plus 2061-2062 (the two viewport conversions) and 2244
     (dragging). ]]
local function buildEditor()
	local editor = inst("Frame")
	editor.Name = Lib.randomName()
	editor.Parent = chrome.scaled
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
	background.Size = UDim2.new(0, 360, 0, 185)
	background.ZIndex = 10
	themed(background, "shade1")

	local divider = inst("Frame")
	divider.Name = "Dark"
	divider.Parent = background
	divider.Active = true
	divider.BackgroundColor3 = Color3.fromRGB(46, 46, 47)
	divider.BorderSizePixel = 0
	divider.Position = UDim2.new(0, 135, 0, 0)
	divider.Size = UDim2.new(0, 2, 0, 185)
	divider.ZIndex = 10
	themed(divider, "shade2")

	local directions = inst("TextLabel")
	directions.Name = "Directions"
	directions.Parent = background
	directions.BackgroundTransparency = 1
	directions.BorderSizePixel = 0
	directions.Position = UDim2.new(0, 10, 0, 15)
	directions.Size = UDim2.new(0, 115, 0, 90)
	directions.ZIndex = 10
	directions.Font = Enum.Font.SourceSans
	directions.Text = "Click the button below and press a key/mouse button. Then select what you want to bind it to."
	directions.TextColor3 = Color3.fromRGB(255, 255, 255)
	directions.TextSize = 14.000
	directions.TextWrapped = true
	directions.TextYAlignment = Enum.TextYAlignment.Top
	themed(directions, "text1")

	local bindTo = inst("TextButton")
	bindTo.Name = "BindTo"
	bindTo.Parent = background
	bindTo.BackgroundColor3 = Color3.fromRGB(46, 46, 47)
	bindTo.BorderSizePixel = 0
	bindTo.Position = UDim2.new(0, 10, 0, 95)
	bindTo.Size = UDim2.new(0, 115, 0, 50)
	bindTo.ZIndex = 10
	bindTo.Font = Enum.Font.SourceSans
	bindTo.Text = "Click to bind"
	bindTo.TextColor3 = Color3.fromRGB(255, 255, 255)
	bindTo.TextSize = 16.000
	themed(bindTo, "shade2")
	themed(bindTo, "text1")

	local triggerLabel = inst("TextLabel")
	triggerLabel.Name = "TriggerLabel"
	triggerLabel.Parent = background
	triggerLabel.BackgroundTransparency = 1
	triggerLabel.Position = UDim2.new(0, 10, 0, 155)
	triggerLabel.Size = UDim2.new(0, 45, 0, 20)
	triggerLabel.ZIndex = 10
	triggerLabel.Font = Enum.Font.SourceSans
	triggerLabel.Text = "Trigger:"
	triggerLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	triggerLabel.TextSize = 14.000
	triggerLabel.TextXAlignment = Enum.TextXAlignment.Left
	themed(triggerLabel, "text1")

	local trigger = inst("TextButton")
	trigger.Name = "BindTo"
	trigger.Parent = background
	trigger.BackgroundColor3 = Color3.fromRGB(46, 46, 47)
	trigger.BorderSizePixel = 0
	trigger.Position = UDim2.new(0, 60, 0, 155)
	trigger.Size = UDim2.new(0, 65, 0, 20)
	trigger.ZIndex = 10
	trigger.Font = Enum.Font.SourceSans
	trigger.Text = "KeyDown"
	trigger.TextColor3 = Color3.fromRGB(255, 255, 255)
	trigger.TextSize = 16.000
	themed(trigger, "shade2")
	themed(trigger, "text1")

	local addButton = inst("TextButton")
	addButton.Name = "Add"
	addButton.Parent = background
	addButton.BackgroundColor3 = Color3.fromRGB(46, 46, 47)
	addButton.BorderSizePixel = 0
	addButton.Position = UDim2.new(0, 310, 0, 35)
	addButton.Size = UDim2.new(0, 40, 0, 20)
	addButton.ZIndex = 10
	addButton.Font = Enum.Font.SourceSans
	addButton.Text = "Add"
	addButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	addButton.TextSize = 14.000
	themed(addButton, "shade2")
	themed(addButton, "text1")

	local toggles = inst("ScrollingFrame")
	toggles.Name = "Toggles"
	toggles.Parent = background
	toggles.BackgroundTransparency = 1
	toggles.BorderSizePixel = 0
	toggles.Position = UDim2.new(0, 150, 0, 125)
	toggles.Size = UDim2.new(0, 200, 0, 50)
	toggles.ZIndex = 10
	toggles.BottomImage = "rbxasset://textures/ui/Scroll/scroll-middle.png"
	toggles.CanvasSize = UDim2.new(0, 0, 0, 50)
	toggles.ScrollBarThickness = 8
	toggles.TopImage = "rbxasset://textures/ui/Scroll/scroll-middle.png"
	toggles.VerticalScrollBarInset = Enum.ScrollBarInset.Always
	themed(toggles, "scroll")

	local clickTP = makeToggleRow(toggles, "Click TP (Hold Key & Click)",
		"    Click TP (Hold Key & Click)", 0)
	local clickDelete = makeToggleRow(toggles, "Click Delete (Hold Key & Click)",
		"    Click Delete (Hold Key & Click)", 25)

	commandBox = makeCommandBox(background, "Cmdbar_2", "Command", 35)
	toggleBox  = makeCommandBox(background, "Cmdbar_3", "Command 2", 60)

	local createToggle = inst("TextLabel")
	createToggle.Name = "CreateToggle"
	createToggle.Parent = background
	createToggle.BackgroundColor3 = Color3.fromRGB(46, 46, 47)
	createToggle.BackgroundTransparency = 1
	createToggle.BorderSizePixel = 0
	createToggle.Position = UDim2.new(0, 152, 0, 10)
	createToggle.Size = UDim2.new(0, 198, 0, 20)
	createToggle.ZIndex = 10
	createToggle.Font = Enum.Font.SourceSans
	createToggle.Text = "Create Toggle"
	createToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
	createToggle.TextSize = 14.000
	createToggle.TextXAlignment = Enum.TextXAlignment.Left
	themed(createToggle, "text1")

	local box = inst("Frame")
	box.Name = "Button"
	box.Parent = createToggle
	box.BackgroundColor3 = Color3.fromRGB(78, 78, 79)
	box.BorderSizePixel = 0
	box.Position = UDim2.new(1, -20, 0, 0)
	box.Size = UDim2.new(0, 20, 0, 20)
	box.ZIndex = 10
	themed(box, "shade3")

	-- The tick. BackgroundTransparency is the state, so it is never themed.
	local tick = inst("TextButton")
	tick.Name = "On"
	tick.Parent = box
	tick.BackgroundColor3 = Color3.fromRGB(150, 150, 151)
	tick.BackgroundTransparency = 1
	tick.BorderSizePixel = 0
	tick.Position = UDim2.new(0, 2, 0, 2)
	tick.Size = UDim2.new(0, 16, 0, 16)
	tick.ZIndex = 10
	tick.Font = Enum.Font.SourceSans
	tick.Text = ""
	tick.TextColor3 = Color3.fromRGB(0, 0, 0)
	tick.TextSize = 14.000

	local shadow = inst("Frame")
	shadow.Name = "shadow"
	shadow.Parent = editor
	shadow.BackgroundColor3 = Color3.fromRGB(46, 46, 47)
	shadow.BorderSizePixel = 0
	shadow.Size = UDim2.new(0, 360, 0, 20)
	shadow.ZIndex = 10
	themed(shadow, "shade2")

	local popup = inst("TextLabel")
	popup.Name = "PopupText_2"
	popup.Parent = shadow
	popup.BackgroundTransparency = 1
	popup.Size = UDim2.new(1, 0, 0.949999988, 0)
	popup.ZIndex = 10
	popup.Font = Enum.Font.SourceSans
	popup.Text = "Set Keybinds"
	popup.TextColor3 = Color3.fromRGB(255, 255, 255)
	popup.TextSize = 14.000
	popup.TextWrapped = true
	themed(popup, "text1")

	local exit = inst("TextButton")
	exit.Name = "Exit_2"
	exit.Parent = shadow
	exit.BackgroundTransparency = 1
	exit.Position = UDim2.new(1, -20, 0, 0)
	exit.Size = UDim2.new(0, 20, 0, 20)
	exit.ZIndex = 10
	exit.Text = ""

	local exitImage = inst("ImageLabel")
	exitImage.Parent = exit
	exitImage.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	exitImage.BackgroundTransparency = 1
	exitImage.Position = UDim2.new(0, 5, 0, 5)
	exitImage.Size = UDim2.new(0, 10, 0, 10)
	exitImage.ZIndex = 10
	exitImage.Image = Assets.get("infiniteyield/assets/close.png")

	-- Legacy 2061-2062: both command boxes scroll horizontally.
	Lib.viewportTextBox(commandBox, bin).View.ZIndex = 10
	toggleView = Lib.viewportTextBox(toggleBox, bin).View
	toggleView.ZIndex = 10
	-- Legacy 6142: the second box only appears once "Create Toggle" is ticked.
	toggleView.Visible = false

	bin:add(Lib.drag(editor, editor, chrome.scale))

	M.editor = editor
	bindToButton, triggerButton, toggleTick = bindTo, trigger, tick

	bin:connect(exit.MouseButton1Click, function() M.closeEditor() end)
	bin:connect(bindTo.MouseButton1Click, function() M.captureKey() end)
	bin:connect(trigger.MouseButton1Click, function()
		bindKeyUp = not bindKeyUp
		trigger.Text = bindKeyUp and "KeyUp" or "KeyDown"
	end)
	bin:connect(tick.MouseButton1Click, function() M.setToggleMode(not makeToggle) end)
	bin:connect(addButton.MouseButton1Click, function() M.addFromEditor() end)
	bin:connect(clickTP.MouseButton1Click, function()
		M.bindCommand("clicktp", "click tp")
	end)
	bin:connect(clickDelete.MouseButton1Click, function()
		M.bindCommand("clickdel", "click delete")
	end)
end

-- ═══ the list ═══════════════════════════════════════════════════════════════

--[[ Legacy 6021-6035 (unkeybind), minus the manual refresh and save: both
     happen inside cmd/binds now. ]]
local function removeBind(bind)
	local removed = Binds.remove({ key = bind.key, command = bind.command })
	if removed > 0 then
		Notify.send("Keybinds Updated",
			"Unbinded " .. Binds.describeKey(bind.key) .. " from " .. bind.command)
	end
	return removed
end

--[[ Legacy refreshbinds (5981-6015). Positions are still computed by hand, at
     25px a row with the first at y=5, because the list has no UIListLayout. ]]
function M.refresh()
	if not M.mounted or not holder then return false end
	rows:empty()
	holder.CanvasSize = UDim2.new(0, 0, 0, 10)

	local list = Binds.list()
	for i = 1, #list do
		local bind = list[i]
		local position = (i * 25) - 25
		local row = template:Clone()
		rows:add(row)
		row.Visible = true
		row.Position = UDim2.new(0, 0, 0, position + 5)
		themed(row, "shade2", rows)
		themed(row.Text, "shade2", rows)
		themed(row.Text, "text1", rows)
		themed(row.Text.Delete, "shade3", rows)
		themed(row.Text.Delete, "text2", rows)

		if bind.toggle then
			row.Text.Text = bind.key .. " > " .. bind.command .. " / " .. bind.toggle
		else
			row.Text.Text = bind.key .. " > " .. bind.command .. "  "
				.. (bind.keyUp and "(keyup)" or "(keydown)")
		end

		holder.CanvasSize = UDim2.new(0, 0, 0, position + 30)
		-- The bind table itself, not the loop index: removing another row first
		-- used to make this one delete the wrong keybind.
		rows:connect(row.Text.Delete.MouseButton1Click, function()
			removeBind(bind)
		end)
		row.Parent = holder
	end
	return true
end

-- ═══ the editor's state ═════════════════════════════════════════════════════

--[[ Legacy 6131-6134 plus onInputBegan's `awaitingInput` branch (6188-6202).
     The capture is cancellable, so closing the window does not leave a handler
     armed that steals the next keystroke. ]]
function M.captureKey()
	if not bindToButton then return false end
	if cancelCapture then cancelCapture() cancelCapture = nil end
	bindToButton.Text = "Press something"
	cancelCapture = Binds.captureNext(function(key)
		cancelCapture = nil
		chosenKey = key
		if bindToButton then bindToButton.Text = key end
	end)
	return true
end

--[[ Legacy 6143-6153: ticking "Create Toggle" swaps the keyup/keydown selector
     for a second command box. ]]
function M.setToggleMode(on)
	makeToggle = on == true
	if toggleTick then toggleTick.BackgroundTransparency = makeToggle and 0 or 1 end
	if toggleView then toggleView.Visible = makeToggle end
	if triggerButton then triggerButton.Visible = not makeToggle end
	return makeToggle
end

local function add(spec, description)
	local ok, err = Guard.call("ui/panels/keybinds.add", Binds.add, spec)
	if not ok then
		Notify.error("Keybind Error", Guard.describe(err))
		return false
	end
	Notify.send("Keybinds Updated",
		"Binded " .. Binds.describeKey(spec.key) .. " to " .. description)
	return true
end

--[[ Legacy 6155-6176. The double-backslash check is unchanged: one backslash
     separates commands, two are a typo that used to produce an empty command. ]]
function M.addFromEditor()
	if not chosenKey or not commandBox then return false end
	local first, second = commandBox.Text, toggleBox.Text
	if string.find(first, "\\\\", 1, true) or string.find(second, "\\\\", 1, true) then
		Notify.send("Keybind Error",
			"Only use one backslash to keybind multiple commands into one keybind or command")
		return false
	end
	if makeToggle and second ~= "" and first ~= "" then
		return add({ key = chosenKey, command = first, toggle = second },
			first .. " / " .. second)
	elseif not makeToggle and first ~= "" then
		return add({ key = chosenKey, command = first, keyUp = bindKeyUp }, first)
	end
	return false
end

--[[ The two shortcut rows, legacy 6239-6263. ]]
function M.bindCommand(command, description)
	if not chosenKey then return false end
	return add({ key = chosenKey, command = command, keyUp = bindKeyUp }, description)
end

-- ═══ open / close ═══════════════════════════════════════════════════════════

--[[ Legacy 4104-4108. Connected once, not twice. ]]
function M.open()
	if not M.frame then return false end
	M.frame:TweenPosition(OPEN, "InOut", "Quart", 0.5, true, nil)
	-- The list covers the settings rows once it has finished sliding in.
	Sched.debounce("ui.panels.keybinds.open", 0.5, function()
		if M.mounted and chrome.settingsHolder then
			chrome.settingsHolder.Visible = false
		end
	end)
	return true
end

--[[ Legacy 4099-4102. ]]
function M.close()
	if not M.frame then return false end
	if chrome.settingsHolder then chrome.settingsHolder.Visible = true end
	M.frame:TweenPosition(CLOSED, "InOut", "Quart", 0.5, true, nil)
	return true
end

--[[ Legacy 4110-4112. ]]
function M.openEditor()
	if not M.editor then return false end
	M.editor:TweenPosition(EDITOR_OPEN, "InOut", "Quart", 0.5, true, nil)
	return true
end

--[[ Legacy 6178-6186. The two boxes are emptied rather than filled with the
     words "Command" and "Command 2": legacy wrote its own placeholder text into
     them, so re-opening the editor and pressing Add bound the command
     "Command". ]]
function M.closeEditor()
	if not M.editor then return false end
	if cancelCapture then cancelCapture() cancelCapture = nil end
	commandBox.Text = ""
	toggleBox.Text = ""
	bindToButton.Text = "Click to bind"
	bindKeyUp = false
	triggerButton.Text = "KeyDown"
	chosenKey = nil
	M.editor:TweenPosition(EDITOR_CLOSED, "InOut", "Quart", 0.5, true, nil)
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

	local row = chrome.makeSettingsRow("Edit Keybinds",
		Assets.get("infiniteyield/assets/editkeybinds.png"))
	row.Position = UDim2.new(0, 5, 0, 85)
	row.Size = UDim2.new(1, -10, 0, 25)
	row.Name = "Keybinds"
	row.Parent = chrome.settingsHolder
	-- Chrome's bin holds it too; ours means a panel that unmounts on its own
	-- does not leave a dead row behind.
	bin:add(row)
	M.row = row
	bin:connect(row.MouseButton1Click, function() M.open() end)

	M.mounted = true
	-- The panel never has to be refreshed by hand from a command again.
	bin:connect(Binds.changed, function() M.refresh() end)
	M.refresh()
	return true
end

function M.unmount()
	if not M.mounted then return false end
	M.mounted = false
	if cancelCapture then cancelCapture() cancelCapture = nil end
	bin:empty()
	rows = nil
	chrome, holder, template = nil, nil, nil
	commandBox, toggleBox, toggleView = nil, nil, nil
	bindToButton, triggerButton, toggleTick = nil, nil, nil
	chosenKey, bindKeyUp, makeToggle = nil, false, false
	M.frame, M.editor, M.row = nil, nil, nil
	return true
end

IY.onUnload(function()
	M.unmount()
	bin:destroy()
end, "ui/panels/keybinds")

return M
