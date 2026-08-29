--[[═══════════════════════════════════════════════════════════════════════════
	ui/panels/aliases · the alias list
	─────────────────────────────────────────────────────────────────────────
	Legacy source.ref.lua 1279-1368 (the panel), 1593-1606 (the empty-state
	hint), 4121-4130 (the navigation), 4232-4238 (Clear) and 6101-6127
	(refreshaliases).

	An alias now maps to a whole command *line* rather than to a command object,
	so `f -> fly 100` is possible and the row shows the line it will run. The
	panel reads cmd/aliases and rebuilds from `Aliases.changed`.

	Two legacy problems are gone: the rows were added to four colour registries
	on every refresh and never removed, and the hint was `:Destroy()`ed the first
	time the list had anything in it -- so it stayed in the text1 registry for the
	rest of the session and never came back when you cleared your aliases. It is
	hidden and shown now.
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Aliases = IY.import("cmd/aliases")
local Assets  = IY.import("ui/assets")
local Bin     = IY.import("core/bin")
local Chrome  = IY.import("ui/chrome")
local Notify  = IY.import("core/notify")
local Sched   = IY.import("core/scheduler")
local Theme   = IY.import("ui/theme")

local M = {}

M.frame   = nil
M.row     = nil
M.mounted = false

local bin  = Bin.new("ui/panels/aliases")
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

--[[ Legacy 1289-1315: Close on the right, Clear on the left. ]]
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

--[[ Legacy 1279-1368 and 1593-1606. ]]
local function build()
	local frame = inst("Frame")
	frame.Name = "AliasesFrame"
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
	local clear = makeButton(frame, "Clear", 5)
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
	text.Text = "honk"
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
	label.Name = "AliasHint"
	label.Parent = frame
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.Position = UDim2.new(0, 25, 0, 40)
	label.Size = UDim2.new(0, 200, 0, 50)
	label.Font = Enum.Font.SourceSansItalic
	label.TextSize = 16
	label.Text = "Add aliases by using the 'addalias' command"
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeColor3 = Color3.new(1, 1, 1)
	label.TextWrapped = true
	label.ZIndex = 10
	themed(label, "text1")

	M.frame, holder, template, hint = frame, list, row, label

	bin:connect(close.MouseButton1Click, function() M.close() end)
	bin:connect(clear.MouseButton1Click, function()
		Aliases.clear()
		Notify.send("Aliases Modified", "Removed all aliases")
	end)
end

-- ═══ the list ═══════════════════════════════════════════════════════════════

--[[ Legacy refreshaliases (6101-6127). The row reads "<command line> > <alias>",
     the legacy order, except that the left side is now the whole line: an alias
     to `fly 100` shows as "fly 100 > f" where legacy could only show "fly". ]]
function M.refresh()
	if not M.mounted or not holder then return false end
	rows:empty()
	holder.CanvasSize = UDim2.new(0, 0, 0, 10)

	local list = Aliases.list()
	hint.Visible = #list == 0

	for i = 1, #list do
		local entry = list[i]
		local position = (i * 25) - 25
		local row = template:Clone()
		rows:add(row)
		row.Visible = true
		row.Position = UDim2.new(0, 0, 0, position + 5)
		row.Text.Text = entry.command .. " > " .. entry.alias
		themed(row, "shade2", rows)
		themed(row.Text, "shade2", rows)
		themed(row.Text, "text1", rows)
		themed(row.Text.Delete, "shade3", rows)
		themed(row.Text.Delete, "text2", rows)

		holder.CanvasSize = UDim2.new(0, 0, 0, position + 30)
		rows:connect(row.Text.Delete.MouseButton1Click, function()
			if Aliases.remove(entry.alias) then
				Notify.send("Aliases Modified",
					"Removed the alias " .. entry.alias .. " from " .. entry.command)
			end
		end)
		row.Parent = holder
	end
	return true
end

-- ═══ open / close ═══════════════════════════════════════════════════════════

--[[ Legacy 4126-4130. ]]
function M.open()
	if not M.frame then return false end
	M.frame:TweenPosition(OPEN, "InOut", "Quart", 0.5, true, nil)
	Sched.debounce("ui.panels.aliases.open", 0.5, function()
		if M.mounted and chrome.settingsHolder then
			chrome.settingsHolder.Visible = false
		end
	end)
	return true
end

--[[ Legacy 4121-4124. ]]
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

	local row = chrome.makeSettingsRow("Edit Aliases",
		Assets.get("infiniteyield/assets/editaliases.png"))
	row.Position = UDim2.new(0, 5, 0, 115)
	row.Size = UDim2.new(1, -10, 0, 25)
	row.Name = "Aliases"
	row.Parent = chrome.settingsHolder
	-- Chrome's bin holds it too; ours means a panel that unmounts on its own
	-- does not leave a dead row behind.
	bin:add(row)
	M.row = row
	bin:connect(row.MouseButton1Click, function() M.open() end)

	M.mounted = true
	bin:connect(Aliases.changed, function() M.refresh() end)
	M.refresh()
	return true
end

function M.unmount()
	if not M.mounted then return false end
	M.mounted = false
	bin:empty()
	rows = nil
	chrome, holder, template, hint = nil, nil, nil, nil
	M.frame, M.row = nil, nil
	return true
end

IY.onUnload(function()
	M.unmount()
	bin:destroy()
end, "ui/panels/aliases")

return M
