--[[═══════════════════════════════════════════════════════════════════════════
	ui/panels/reference · the help window behind the "?" button
	─────────────────────────────────────────────────────────────────────────
	Legacy source.ref.lua 2776-2928.

	The legacy version was `reference = (function() ... end)()` with no return
	value, so the global was always nil: the window existed only because its
	Close and ReferenceButton handlers captured it. Nothing could open, close or
	reposition it from anywhere else. It is a module now.

	The eight sections are the same eight, with the same text, sizes and
	positions -- except that the "Special Player Cases" rows are generated from
	`Players.selectorHelp()` instead of being 19 hand-written pairs of labels
	that nobody remembered to update when a selector was added. `cursor` and
	`npcs`, which the legacy list never mentioned, therefore appear. The section
	and canvas heights are computed from the row count with the legacy
	arithmetic (18px a row), so at 19 rows the numbers are the legacy numbers.

	Everything else -- the command-syntax examples, the looping form, the event
	bind notes -- is authored text and stays authored text.
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Assets   = IY.import("ui/assets")
local Bin      = IY.import("core/bin")
local Chrome   = IY.import("ui/chrome")
local Env      = IY.import("core/env")
local Guard    = IY.import("core/guard")
local Lib      = IY.import("ui/lib")
local Sched    = IY.import("core/scheduler")
local Selector = IY.import("core/players")
local Services = IY.import("core/services")
local Theme    = IY.import("ui/theme")

local M = {}

M.frame   = nil
M.mounted = false

local bin = Bin.new("ui/panels/reference")
M.bin = bin

local chrome  = nil
local list    = nil          -- the scrolling body
local invite  = nil          -- the Discord button
local pressed = 0            -- token, so two clicks do not fight over the label

local INVITE = "https://discord.gg/78ZuWSq"
local INVITE_TEXT = "Copy Discord Invite Link (" .. INVITE .. ")"

local OPEN   = UDim2.new(0.5, -250, 0.5, -150)
local CLOSED = UDim2.new(0.5, -250, 0, -500)

local ROW_HEIGHT = 18        -- one selector row
local CASES_TOP  = 55        -- where the rows start inside the first section
local SECTION_PADDING = 87   -- the first section is this plus the rows

local function inst(className)
	local instance = Instance.new(className)
	bin:add(instance)
	return instance
end

local function themed(instance, registry)
	Theme.register(instance, registry)
	bin:add(function() Theme.unregister(instance, registry) end)
	return instance
end

-- ═══ building blocks ════════════════════════════════════════════════════════

--[[ A section of the list. Every label inside one is registered in text1, which
     is what the legacy descendant sweep at 2895-2899 did. ]]
local function section(height)
	local frame = inst("Frame")
	frame.Name = "Section"
	frame.BackgroundColor3 = Color3.new(1, 1, 1)
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.new(1, 0, 0, height)
	frame.ZIndex = 10
	frame.Parent = list
	return frame
end

local function header(parent, text)
	local label = inst("TextLabel")
	label.Name = "Header"
	label.Parent = parent
	label.BackgroundColor3 = Color3.new(1, 1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.SourceSansBold
	label.Position = UDim2.new(0, 8, 0, 5)
	label.Size = UDim2.new(1, -8, 0, 20)
	label.Text = text
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextSize = 20
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.ZIndex = 10
	themed(label, "text1")
	return label
end

--[[ The hairline at the bottom of a section. ]]
local function divider(parent, visible)
	local line = inst("Frame")
	line.Name = "Line"
	line.Parent = parent
	line.BackgroundColor3 = Color3.fromRGB(46, 46, 47)
	line.BorderSizePixel = 0
	line.Position = UDim2.new(0, 10, 1, -1)
	line.Size = UDim2.new(1, -20, 0, 1)
	line.Visible = visible ~= false
	line.ZIndex = 10
	return line
end

--[[ `opts` is { y, height, bold, size, top } -- the four things that vary
     between the twenty-odd body labels. ]]
local function paragraph(parent, text, opts)
	local label = inst("TextLabel")
	label.Name = "Text"
	label.Parent = parent
	label.BackgroundColor3 = Color3.new(1, 1, 1)
	label.BackgroundTransparency = 1
	label.Font = opts.bold and Enum.Font.SourceSansBold or Enum.Font.SourceSans
	label.Position = UDim2.new(0, 8, 0, opts.y)
	label.Size = UDim2.new(1, -8, 0, opts.height)
	label.Text = text
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextSize = opts.size or 14
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	if opts.top then label.TextYAlignment = Enum.TextYAlignment.Top end
	label.ZIndex = 10
	themed(label, "text1")
	return label
end

--[[ How far the description sits from the left, which the legacy data hard-coded
     per row: the rendered width of the token in the bold 14px font. ]]
local function tokenWidth(token)
	local width = Guard.try(function()
		return Services.TextService:GetTextSize(token, 14, Enum.Font.SourceSansBold,
			Vector2.new(999999999, 100)).X
	end)
	if type(width) ~= "number" or width <= 0 then
		-- No TextService (or a stubbed one): 6px a character is close enough that
		-- the two labels do not overlap.
		return #token * 6
	end
	return math.ceil(width)
end

--[[ One "<token> - <what it does>" row. Legacy 2792-2851. ]]
local function caseRow(parent, token, describe, layoutOrder)
	local row = inst("Frame")
	row.Name = "Case"
	row.Parent = parent
	row.BackgroundColor3 = Color3.fromRGB(46, 46, 47)
	row.BackgroundTransparency = 1
	row.BorderSizePixel = 0
	row.Position = UDim2.new(0, 8, 0, 60)
	row.Size = UDim2.new(1, 0, 0, ROW_HEIGHT)
	row.ZIndex = 10
	if layoutOrder then row.LayoutOrder = layoutOrder end

	local name = inst("TextLabel")
	name.Name = "CaseName"
	name.Parent = row
	name.BackgroundColor3 = Color3.new(1, 1, 1)
	name.BackgroundTransparency = 1
	name.Font = Enum.Font.SourceSansBold
	name.Size = UDim2.new(1, 0, 1, 0)
	name.Text = token
	name.TextColor3 = Color3.new(1, 1, 1)
	name.TextSize = 14
	name.TextWrapped = true
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.ZIndex = 10
	themed(name, "text1")

	local desc = inst("TextLabel")
	desc.Name = "CaseDesc"
	desc.Parent = row
	desc.BackgroundColor3 = Color3.new(1, 1, 1)
	desc.BackgroundTransparency = 1
	desc.Font = Enum.Font.SourceSans
	desc.Position = UDim2.new(0, tokenWidth(token), 0, 0)
	desc.Size = UDim2.new(1, 0, 1, 0)
	desc.Text = "- " .. describe
	desc.TextColor3 = Color3.new(1, 1, 1)
	desc.TextSize = 14
	desc.TextWrapped = true
	desc.TextXAlignment = Enum.TextXAlignment.Left
	desc.ZIndex = 10
	themed(desc, "text1")
	return row
end

-- ═══ the eight sections ═════════════════════════════════════════════════════

--[[ Legacy 2786-2851, generated. The three tokens the legacy list put first keep
     their LayoutOrder, and `@username` is authored because plain name matching
     is not a selector entry -- cmd/players falls through to it. ]]
local function buildSelectors()
	local rows = Selector.selectorHelp()
	local count = #rows + 1
	local height = SECTION_PADDING + ROW_HEIGHT * count

	local frame = section(height)
	header(frame, "Special Player Cases")
	paragraph(frame, "These keywords can be used to quickly select groups of players in commands:",
		{ y = 25, height = 20 })
	divider(frame)

	local cases = inst("Frame")
	cases.Name = "Cases"
	cases.Parent = frame
	cases.BackgroundColor3 = Color3.fromRGB(46, 46, 47)
	cases.BackgroundTransparency = 1
	cases.BorderSizePixel = 0
	cases.Position = UDim2.new(0, 8, 0, CASES_TOP)
	cases.Size = UDim2.new(1, -16, 0, ROW_HEIGHT * count)
	cases.ZIndex = 10

	local layout = inst("UIListLayout")
	layout.Parent = cases
	layout.SortOrder = Enum.SortOrder.LayoutOrder

	local first = { all = -4, others = -3, me = -2 }
	for i = 1, #rows do
		caseRow(cases, rows[i].token, rows[i].describe, first[rows[i].token])
	end
	caseRow(cases, "@username",
		"searches for players by username only (ignores displaynames)", -1)

	return height
end

--[[ Legacy 2852-2860. ]]
local function buildOperators()
	local frame = section(180)
	header(frame, "Various Operators")
	divider(frame)
	paragraph(frame, "Use commas to separate multiple expressions:",
		{ y = 30, height = 16, bold = true, top = true })
	paragraph(frame, ";locate noob,noob2,bob", { y = 46, height = 16, top = true })
	paragraph(frame, "Use - to exclude, and + to include players in your expression:",
		{ y = 75, height = 16, bold = true, top = true })
	paragraph(frame, ";locate %blue-friends (gets players in blue team who aren't your friends)",
		{ y = 91, height = 16, top = true })
	paragraph(frame, "Put ! before a command to run it with the last arguments it was ran with:",
		{ y = 120, height = 16, bold = true, top = true })
	paragraph(frame, "After running ;offset 0 100 0,  you can run !offset anytime to repeat that command with the same arguments that were used to run it last time",
		{ y = 136, height = 32, top = true })
	return 180
end

--[[ Legacy 2861-2867. ]]
local function buildLooping()
	local frame = section(154)
	header(frame, "Command Looping")
	paragraph(frame, "Form: [How many times it loops]^[delay (optional)]^[command]",
		{ y = 30, height = 20, bold = true, size = 15 })
	divider(frame)
	paragraph(frame, "Use the 'breakloops' command to stop all running loops.",
		{ y = 50, height = 20, size = 15 })
	paragraph(frame, "Examples:", { y = 80, height = 16, bold = true, top = true })
	paragraph(frame, ";5^btools - gives you 5 sets of btools\n;10^3^drophats - drops your hats every 3 seconds 10 times\n;inf^0.1^animspeed 100 - infinitely loops your animation speed to 100",
		{ y = 98, height = 42, top = true })
	return 154
end

--[[ Legacy 2868-2873. ]]
local function buildChaining()
	local frame = section(120)
	header(frame, "Execute Multiple Commands at Once")
	paragraph(frame, "You can execute multiple commands at once using \"\\\"",
		{ y = 30, height = 20, bold = true })
	divider(frame)
	paragraph(frame, "Examples:", { y = 60, height = 16, bold = true, top = true })
	paragraph(frame, ";drophats\\respawn - drops your hats and respawns you\n;enable inventory\\enable playerlist\\refresh - enables those coregui items and refreshes you",
		{ y = 78, height = 32, top = true })
	return 120
end

--[[ Legacy 2874-2881. ]]
local function buildHistory()
	local frame = section(75)
	header(frame, "Browse Command History")
	paragraph(frame, "While focused on the command bar, you can use the up and down arrow keys to browse recently used commands",
		{ y = 30, height = 32 })
	divider(frame)

	local autocomplete = section(75)
	header(autocomplete, "Autocomplete in the Command Bar")
	paragraph(autocomplete, "While focused on the command bar, you can use the tab key to insert the top suggested command into the command bar.",
		{ y = 30, height = 32 })
	divider(autocomplete)
	return 150
end

--[[ Legacy 2882-2888. ]]
local function buildEventBinds()
	local frame = section(175)
	header(frame, "Using Event Binds")
	paragraph(frame, "Use event binds to set up commands that get executed when certain events happen. You can edit the conditions for an event command to run (such as which player triggers it).",
		{ y = 30, height = 32 })
	divider(frame)
	paragraph(frame, "Some events may send arguments; you can use them in your event command by using $ followed by the argument number ($1, $2, etc). You can find out the order and types of these arguments by looking at the settings of the event command.",
		{ y = 70, height = 48 })
	paragraph(frame, "Example:", { y = 130, height = 16, bold = true, top = true })
	paragraph(frame, "Setting up 'goto $1' on the OnChatted event will teleport you to any player that chats.",
		{ y = 148, height = 16, top = true })
	return 175
end

--[[ Legacy 2889-2893. The hairline is present but hidden, as it was. ]]
local function buildHelp()
	local frame = section(105)
	header(frame, "Get Further Help")
	paragraph(frame, "You can join the Discord server to get support with IY,  and read up on more documentation such as the Plugin API.",
		{ y = 30, height = 32 })
	divider(frame, false)

	local button = inst("TextButton")
	button.Name = "InviteButton"
	button.Parent = frame
	button.BackgroundColor3 = Color3.fromRGB(124, 158, 217)
	button.BorderColor3 = Color3.fromRGB(46, 46, 47)
	button.Font = Enum.Font.SourceSansBold
	button.Position = UDim2.new(0, 5, 0, 75)
	button.Size = UDim2.new(1, -10, 0, 25)
	button.Text = INVITE_TEXT
	button.TextColor3 = Color3.fromRGB(46, 46, 47)
	button.TextSize = 16
	button.ZIndex = 10
	invite = button
	return 105
end

-- ═══ the window ═════════════════════════════════════════════════════════════

--[[ Legacy 2778-2785 and 2894-2923. ]]
local function build()
	local frame = inst("Frame")
	frame.Name = Lib.randomName()
	frame.Parent = chrome.scaled
	frame.BackgroundColor3 = Color3.fromRGB(36, 36, 37)
	frame.BackgroundTransparency = 1
	frame.BorderColor3 = Color3.fromRGB(40, 40, 40)
	frame.BorderSizePixel = 0
	frame.Position = CLOSED
	frame.Size = UDim2.new(0, 500, 0, 20)
	frame.ZIndex = 10

	local topBar = inst("Frame")
	topBar.Name = "TopBar"
	topBar.Parent = frame
	topBar.BackgroundColor3 = Color3.fromRGB(46, 46, 47)
	topBar.BorderSizePixel = 0
	topBar.Size = UDim2.new(1, 0, 0, 20)
	topBar.ZIndex = 10
	themed(topBar, "shade2")

	-- Not themed: the legacy registry sweep only reached labels inside the list,
	-- so this one stays white whatever text1 is set to.
	local title = inst("TextLabel")
	title.Name = "Title"
	title.Parent = topBar
	title.BackgroundColor3 = Color3.new(1, 1, 1)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.SourceSans
	title.Size = UDim2.new(1, 0, 0.94999998807907, 0)
	title.Text = "Reference"
	title.TextColor3 = Color3.new(1, 1, 1)
	title.TextSize = 14
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

	local content = inst("Frame")
	content.Name = "Content"
	content.Parent = frame
	content.BackgroundColor3 = Color3.fromRGB(36, 36, 37)
	content.BorderSizePixel = 0
	content.Position = UDim2.new(0, 0, 0, 20)
	content.Size = UDim2.new(1, 0, 0, 300)
	content.ZIndex = 10
	themed(content, "shade1")

	list = inst("ScrollingFrame")
	list.Name = "List"
	list.Parent = content
	list.BackgroundColor3 = Color3.fromRGB(36, 36, 37)
	list.BackgroundTransparency = 1
	list.BorderColor3 = Color3.fromRGB(40, 40, 40)
	list.BorderSizePixel = 0
	list.BottomImage = "rbxasset://textures/ui/Scroll/scroll-middle.png"
	list.TopImage = "rbxasset://textures/ui/Scroll/scroll-middle.png"
	list.CanvasSize = UDim2.new(0, 0, 0, 0)
	list.ScrollBarImageColor3 = Color3.fromRGB(78, 78, 79)
	list.ScrollBarThickness = 8
	list.Size = UDim2.new(1, 0, 1, 0)
	list.VerticalScrollBarInset = Enum.ScrollBarInset.Always
	list.ZIndex = 10
	themed(list, "scroll")

	local layout = inst("UIListLayout")
	layout.Parent = list
	layout.SortOrder = Enum.SortOrder.LayoutOrder

	-- Legacy hard-coded a 1313px canvas for its 19 selector rows; the sum is the
	-- same arithmetic with however many there are.
	local total = buildSelectors() + buildOperators() + buildLooping()
		+ buildChaining() + buildHistory() + buildEventBinds() + buildHelp()
	list.CanvasSize = UDim2.new(0, 0, 0, total)

	bin:add(Lib.drag(frame, frame, chrome.scale))

	M.frame = frame
	bin:connect(close.MouseButton1Click, function() M.close() end)
	bin:connect(invite.MouseButton1Click, function() M.copyInvite() end)
end

-- ═══ behaviour ══════════════════════════════════════════════════════════════

--[[ Legacy 2909-2921: the label reports what happened and goes back to normal
     two seconds later, unless it has been clicked again since. ]]
function M.copyInvite()
	if not invite then return false end
	local copied = false
	if Env.usable("setclipboard") then
		copied = Guard.call("ui/panels/reference.copy", Env.fn.setclipboard, INVITE)
	end
	invite.Text = copied and "Copied" or "No Clipboard Function, type out the link"

	pressed = pressed + 1
	local mine = pressed
	Sched.after(2, function()
		if mine ~= pressed or not M.mounted or not invite then return end
		invite.Text = INVITE_TEXT
	end, "ui.panels.reference.invite")
	return copied
end

--[[ Legacy 2925-2927 (the "?" button). ]]
function M.open()
	if not M.frame then return false end
	M.frame:TweenPosition(OPEN, "InOut", "Quart", 0.5, true, nil)
	return true
end

--[[ Legacy 2904-2906. ]]
function M.close()
	if not M.frame then return false end
	M.frame:TweenPosition(CLOSED, "InOut", "Quart", 0.5, true, nil)
	return true
end

--[[ Rebuild the selector rows from live data. Nothing calls this yet -- the
     selector set is fixed at load -- but a plugin that adds one can. ]]
function M.refresh()
	if not M.mounted then return false end
	local context = chrome
	local position = M.frame and M.frame.Position or nil
	M.unmount()
	M.mount(context)
	if position and M.frame then M.frame.Position = position end
	return true
end

-- ═══ mount / unmount ════════════════════════════════════════════════════════

function M.mount(context)
	if M.mounted then return true end
	chrome = context or Chrome
	if not chrome.mounted then chrome.mount() end

	build()

	-- The "?" in the title bar is the shell's; this is the only thing that opens
	-- the window, which is why the legacy nil global was never noticed.
	if chrome.referenceButton then
		bin:connect(chrome.referenceButton.MouseButton1Click, function() M.open() end)
	end

	M.mounted = true
	return true
end

function M.unmount()
	if not M.mounted then return false end
	M.mounted = false
	bin:empty()
	chrome, list, invite = nil, nil, nil
	M.frame = nil
	return true
end

IY.onUnload(function()
	M.unmount()
	bin:destroy()
end, "ui/panels/reference")

return M
