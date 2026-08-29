--[[═══════════════════════════════════════════════════════════════════════════
	ui/cmdlist · the command list, its filter, autocomplete and tooltips
	─────────────────────────────────────────────────────────────────────────
	Legacy source.ref.lua 4333-4478 (`Match`, `IndexContents`, the chat-bar
	suggestion driver, `autoComplete`, the canvas-size handling), 4918-4977 (a row
	cloned per command, click-to-insert, `checkTT`), 5205-5221 (the greying-out
	half of `removecmd`), 5247-5267 (`addcmdtext`) and 5644-5718 (the command bar
	handlers).

	    CmdList.mount(Chrome)
	    CmdList.refresh()          rebuild the rows from the registry
	    CmdList.filter(text)       what IndexContents did
	    CmdList.complete()         insert the top match into the command bar
	    CmdList.topMatch()         that match, or nil
	    CmdList.unmount()

	The rows come from `Registry.all()`. Legacy 4480-4916 was a 436-entry
	`{NAME=, DESC=}` literal that had to be kept in step with the commands by
	hand -- it listed commands that no longer existed and missed ones that did --
	plus a second `addcmdtext` path so plugins could append to it. Subscribing to
	`Registry.changed` means adding, removing or disabling a command updates the
	list by itself, and `removecmd` needs no UI code at all.

	Other things that are not a straight copy:

	  · `checkTT` ran a full-tree `GetGuiObjectsAtPosition` on every single
	    Mouse.Move event. It is throttled now -- see the comment on it.
	  · `IndexContents` walked all ~440 rows on every keystroke even when the text
	    had not changed. The pass is skipped when the needle is unchanged, and it
	    still only toggles `Visible` -- rows are never rebuilt to filter them.
	  · `cmdHistory` / `historyCount` are cmd/history now, so the chat hook, the
	    keybinds and the bar share one history.
	  · `topCommand` and `canvasPos` were file-locals that the chat driver, the
	    Tab handler and the settings panel all reached into. They are local here.
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Bin      = IY.import("core/bin")
local Dispatch = IY.import("cmd/dispatch")
local Guard    = IY.import("core/guard")
local History  = IY.import("cmd/history")
local Log      = IY.import("core/log")
local Notify   = IY.import("core/notify")
local Parser   = IY.import("cmd/parser")
local Platform = IY.import("core/platform")
local Registry = IY.import("cmd/registry")
local Sched    = IY.import("core/scheduler")
local Services = IY.import("core/services")
local Store    = IY.import("core/store")
local Str      = IY.import("core/util/strings")
local Theme    = IY.import("ui/theme")

local log = Log.scope("ui/cmdlist")

local Players          = Services.Players
local RunService       = Services.RunService
local UserInputService = Services.UserInputService

local M = {}

M.mounted = false

--[[ Replaces the legacy `tabAllowed` global: a panel that is capturing raw
     keystrokes can switch Tab completion off while it does. ]]
M.tabEnabled = true

local bin = Bin.new("ui/cmdlist")
M.bin = bin

local chrome     = nil
local rowsBin    = nil
local rows       = {}      -- { button = TextButton, definition = definition|nil }
local topCommand = nil     -- legacy file-local: the best match's row text
local canvasPos  = nil     -- legacy file-local: scroll offset across a focus
local lastFilter = nil     -- the needle the visible set was computed for
local visibleRows = 0
local mouse      = nil
local guiTarget  = nil     -- the BasePlayerGui the rows actually live under

-- ═══ matching ═══════════════════════════════════════════════════════════════

--[[ Legacy Match (4333-4336). `%W` -> `%%%1` escapes every non-word character,
     which is wider than a pattern escape needs to be, but it is what the legacy
     list matched with so it stays byte for byte. ]]
local function matches(name, needle)
	needle = string.gsub(needle, "%W", "%%%1")
	return string.find(string.lower(name), string.lower(needle)) ~= nil
end

--[[ Legacy 4357-4362: only the last `\`-separated command on the line is being
     typed, and a leading `!` (recall) is not part of the name. ]]
local function normalise(text)
	local str = tostring(text or "")
	if string.sub(str, #str, #str) == "\\" then str = "" end
	local chunks = {}
	for piece in string.gmatch(str, "[^\\]+") do chunks[#chunks + 1] = piece end
	if #chunks > 0 then str = chunks[#chunks] end
	if string.sub(str, 1, 1) == "!" then str = string.sub(str, 2) end
	return str
end

--[[ Legacy 4340-4349. The UIListLayout reports its content size in *scaled*
     pixels while CanvasSize is set in the container's own units, so the height
     has to be divided by the UIScale or the list cannot scroll to its end. ]]
local function updateCanvasSize()
	if not chrome then return end
	local list, layout = chrome.commandList, chrome.commandListLayout
	if not (list and layout) then return end
	local scale = 1
	if chrome.scale then
		local value = chrome.scale.Scale
		if type(value) == "number" and value > 0 then scale = value end
	end
	local unscaledY = math.ceil(layout.AbsoluteContentSize.Y / scale)
	list.CanvasSize = UDim2.new(0, 0, 0, math.max(0, unscaledY))
end

-- ═══ autocomplete ═══════════════════════════════════════════════════════════

--[[ Legacy autoComplete (4454-4478): put `str` up to its first argument marker
     into the bar, keeping any earlier `\`-separated commands, then park the
     caret at the end. Verbatim, including the RenderStepped wait, which is what
     lets the Tab keystroke be stripped out on the next frame. ]]
local function autoComplete(str, curText)
	-- Legacy `endingChar` = { "[", "/", "(", " " }: the first of these ends the
	-- part of the row text that is actually the command name.
	local stop = 0
	for i = 1, #str do
		local c = string.sub(str, i, i)
		if c == "[" or c == "/" or c == "(" or c == " " then stop = i break end
	end

	local bar = chrome.commandBar
	curText = curText or bar.Text

	local subPos = 0
	local pos = 1
	local findRes = string.find(curText, "\\", pos, true)
	while findRes do
		subPos = findRes
		pos = findRes + 1
		findRes = string.find(curText, "\\", pos, true)
	end
	if string.sub(curText, subPos + 1, subPos + 1) == "!" then subPos = subPos + 1 end

	bar.Text = string.sub(curText, 1, subPos) .. string.sub(str, 1, stop - 1) .. " "
	RunService.RenderStepped:Wait()
	bar.Text = (string.gsub(bar.Text, "\t", ""))
	bar.CursorPosition = #bar.Text + 1
end

function M.topMatch()
	return topCommand
end

--[[ Tab completion. Legacy 5711-5713. ]]
function M.complete()
	if not M.mounted or topCommand == nil then return false end
	Guard.call("ui/cmdlist.complete", autoComplete, topCommand)
	return true
end

-- ═══ rows ═══════════════════════════════════════════════════════════════════

--[[ One row. `definition` is nil for the blank spacer rows the legacy `CMDs`
     table carried between groups (4907, 4911, 4916). ]]
local function addRow(definition, text)
	local button = chrome.rowTemplate:Clone()
	button.Parent = chrome.commandList
	button.Visible = false
	button.Text = text
	button.Name = "CMD"
	rowsBin:add(button)
	Theme.register(button, "text1")
	-- Added after the button, so cleanup unregisters before the destroy. The
	-- legacy rows were pushed into `text1` and never taken out again, which is
	-- why that registry held 440+ entries before the script had finished loading.
	rowsBin:add(function() Theme.unregister(button) end)

	if definition then
		if definition.description ~= "" then
			button:SetAttribute("Title", text)
			button:SetAttribute("Desc", definition.description)
		end
		-- Legacy removecmd (5211-5215) greyed the row out and added a click
		-- handler that explained why; both belong with the row now.
		if definition.disabled then button.TextTransparency = 0.7 end

		-- MouseButton1Down, as legacy: it fires *before* the command bar loses
		-- focus, so `bar.Text` below is still what the user had typed.
		rowsBin:connect(button.MouseButton1Down, function()
			if definition.disabled then
				Notify.send(button.Text, definition.disabledReason
					or "Command has been disabled by you or a plugin")
				return
			end
			if Platform.isMobile then return end
			if not button.Visible or button.TextTransparency ~= 0 then return end
			local bar = chrome.commandBar
			local currentText = bar.Text
			bar:CaptureFocus()
			autoComplete(button.Text, currentText)
			chrome.maximize()
		end)
	end

	rows[#rows + 1] = { button = button, definition = definition }
	return button
end

--[[ Build every row from the registry, in registration order, with a spacer
     wherever the category changes -- which is where the legacy table had its
     blank entries. ]]
local function buildRows()
	local definitions = Registry.all()
	local lastCategory = nil
	for i = 1, #definitions do
		local definition = definitions[i]
		if lastCategory ~= nil and definition.category ~= lastCategory then
			addRow(nil, "")
		end
		lastCategory = definition.category
		addRow(definition, Registry.listText(definition))
	end
	updateCanvasSize()
end

local function clearRows()
	rowsBin:empty()
	rows = {}
	topCommand = nil
	lastFilter = nil
	visibleRows = 0
end

-- ═══ filtering ══════════════════════════════════════════════════════════════

--[[ Legacy IndexContents (4350-4397). Its `bool` parameter was true at every one
     of its call sites, so it is gone; `cmdbar` and `Ianim` are `opts`:

       opts.fromCommandBar   the bar has focus, so collapse to the bar rather
                             than all the way down (legacy `cmdbar`)
       opts.minimize         always collapse (legacy `Ianim`)
       opts.quiet            leave the window where it is -- used by refresh(),
                             which must not pop the menu open every time a
                             plugin registers a command ]]
function M.filter(text, opts)
	if not M.mounted then return false end
	opts = opts or {}
	local list = chrome.commandList
	if not list then return false end

	-- Legacy 4351: every pass starts at the top of the list.
	list.CanvasPosition = Vector2.new(0, 0)

	local needle = normalise(text)
	if needle ~= lastFilter then
		lastFilter = needle
		visibleRows = 0
		topCommand = nil
		for i = 1, #rows do
			local row = rows[i]
			local button = row.button
			if matches(button.Text, needle) then
				visibleRows = visibleRows + 1
				button.Visible = true
				-- Spacers are never the top match; legacy could pick one up.
				if topCommand == nil and row.definition then
					topCommand = button.Text
				end
			else
				button.Visible = false
			end
		end
		updateCanvasSize()
	end

	if opts.quiet then return true end
	if opts.minimize then
		chrome.minimize()
	elseif visibleRows == 0 or string.find(needle, " ") then
		if opts.fromCommandBar then chrome.showCommandBar() else chrome.minimize() end
	else
		chrome.maximize()
	end
	return true
end

--[[ Rebuild the rows and re-apply whatever is being typed. Wired to
     Registry.changed, so `;removecmd`, a plugin loading and a plugin unloading
     all reach the list without asking. ]]
function M.refresh()
	if not M.mounted then return false end
	clearRows()
	buildRows()
	local bar = chrome.commandBar
	local text = (bar and bar:IsFocused()) and bar.Text or ""
	M.filter(text, { quiet = true })
	return true
end

-- ═══ tooltips ═══════════════════════════════════════════════════════════════

--[[ `GetGuiObjectsAtPosition` only exists on the BasePlayerGui that actually
     contains the rows, and ui/lib picks that at boot from five strategies.
     CoreGui is a BasePlayerGui, so an ancestor walk covers both the executor and
     the PlayerGui cases; legacy hard-coded CoreGui and silently did nothing when
     the interface had landed in the PlayerGui instead. ]]
local function findGuiTarget()
	local host = chrome and chrome.parent
	if host then
		local ancestor = Guard.try(function()
			return host:FindFirstAncestorWhichIsA("BasePlayerGui")
		end)
		if ancestor then return ancestor end
		if Guard.try(function() return host:IsA("BasePlayerGui") end) then return host end
	end
	return Services.get("CoreGui")
end

--[[ Legacy checkTT (4941-4977): the tooltip follows the pointer while it is over
     a row that has a description, and is positioned to stay on screen.

     Legacy bound this straight to Mouse.Move (13288), so every mouse-move event
     ran a full-tree hit test -- hundreds of tree walks a second while the
     pointer was moving. It is throttled to 30ms (~33Hz), which is well inside
     the range where the tooltip still tracks the pointer. ]]
local function checkTT()
	if not (M.mounted and chrome and chrome.tooltip and mouse) then return end
	local tooltip = chrome.tooltip

	local objects = guiTarget and Guard.try(function()
		return guiTarget:GetGuiObjectsAtPosition(mouse.X, mouse.Y)
	end)

	local hit = nil
	if objects then
		for i = 1, #objects do
			if objects[i].Parent == chrome.commandList then hit = objects[i] end
		end
	end

	local title = hit and hit:GetAttribute("Title") or nil
	if title == nil then
		tooltip.frame.Visible = false
		return
	end

	local x, y = mouse.X, mouse.Y
	local xP = (x > 200) and (x - 201) or (x + 21)
	local yP = (y > (mouse.ViewSizeY - 96)) and (y - 97) or y
	-- moveTo converts raw pointer pixels into the scaled container's units.
	tooltip.moveTo(xP, yP)
	tooltip.body.Text = hit:GetAttribute("Desc") or ""
	tooltip.title.Text = title
	tooltip.frame.Visible = true
end

local function attachTooltip()
	if not mouse then
		log.debug("no mouse: command tooltips are unavailable")
		return
	end
	guiTarget = findGuiTarget()
	bin:connect(mouse.Move, function()
		Sched.throttle("ui.cmdlist.tooltip", 0.03, checkTT)
	end)
end

-- ═══ the command bar ════════════════════════════════════════════════════════

--[[ Legacy 5704-5708 / 5692-5696: while the bar has focus the settings panel
     slides out of the way so the list can use the body, and slides back when
     focus is lost. The 0.2 tween and the fact that the panel stays *logically*
     open are both as they were -- which is why this cannot go through
     Chrome.setSettingsOpen, whose tween is 0.5 and which flips the flag. ]]
local function revealList()
	if not chrome.settingsOpen() then return end
	task.wait(0.2)
	chrome.commandList.Visible = true
	chrome.settings:TweenPosition(UDim2.new(0, 0, 0, 220), "InOut", "Quart", 0.2, true, nil)
end

local function hideList()
	if not chrome.settingsOpen() then return end
	task.wait(0.2)
	chrome.settings:TweenPosition(UDim2.new(0, 0, 0, 45), "InOut", "Quart", 0.2, true, nil)
	chrome.commandList.Visible = false
end

--[[ Legacy 5650-5651: an out-of-range CursorPosition clamps to the end of the
     text, which is how the bar jumps the caret to the end after a history step. ]]
local function setBarText(text)
	local bar = chrome.commandBar
	bar.Text = text or ""
	bar.CursorPosition = 1020
end

local function attachCommandBar()
	local bar = chrome.commandBar

	bin:onChange(bar, "Text", function()
		if bar:IsFocused() then
			M.filter(bar.Text, { fromCommandBar = true })
		end
	end)

	bin:connect(bar.Focused, function()
		History.resetCursor()
		canvasPos = chrome.commandList.CanvasPosition
		revealList()
	end)

	bin:connect(bar.FocusLost, function(enterPressed)
		if enterPressed then
			-- Legacy 5684 stripped the prefix with a pattern built from the prefix
			-- itself; cmd/parser does it by comparison, so a prefix that happens to
			-- be a pattern character ("." or "%") behaves too.
			local text = bar.Text
			local stripped = Parser.stripPrefix(text, Store.get("prefix") or ";")
			Dispatch.run(stripped or text, nil, { record = true })
		end
		task.wait()
		if not bar:IsFocused() then
			bar.Text = ""
			M.filter("", { minimize = true })
			hideList()
		end
		chrome.commandList.CanvasPosition = canvasPos or Vector2.new(0, 0)
	end)
end

--[[ Legacy 5644-5662 (Up / Down) and 5709-5717 (Tab). Legacy opened a fresh
     InputBegan connection every time the bar was focused and disconnected it on
     focus loss; one connection guarded by IsFocused() is the same behaviour
     without the churn. The history itself is cmd/history. ]]
local function attachKeys()
	bin:connect(UserInputService.InputBegan, function(input)
		local bar = chrome and chrome.commandBar
		if not bar or not bar:IsFocused() then return end
		local code = input.KeyCode
		if code == Enum.KeyCode.Tab then
			if M.tabEnabled then M.complete() end
		elseif code == Enum.KeyCode.Up then
			setBarText(History.previous())
		elseif code == Enum.KeyCode.Down then
			setBarText(History.next())
		end
	end)
end

-- ═══ suggestions for the legacy chat bar ═════════════════════════════════════

--[[ Legacy 4399-4452. Typing ";fl" in the *game* chat filters the list too, on
     the legacy chat service only -- TextChatService has no reachable text box.
     The chat bar is rebuilt whenever Roblox re-creates the chat frame, so the
     three connections live in a branch that is emptied and re-made rather than
     stacked, which is what legacy did by hand with three saved connections.

     Runs on its own thread because of the WaitForChild: legacy spawned it for
     the same reason (4399), and blocking here would hold up the whole mount. ]]
local function attachChatSuggestions()
	if not Platform.isLegacyChat then return end

	local playerGui = Guard.try(function()
		return Players.LocalPlayer:FindFirstChildWhichIsA("PlayerGui")
	end)
	if not playerGui then return end

	local chatGui = Guard.try(function() return playerGui:WaitForChild("Chat", 10) end)
	local parentFrame = chatGui and Guard.try(function()
		return chatGui.Frame.ChatBarParentFrame
	end)
	if not parentFrame or not M.mounted then return end

	local chatBin = bin:branch("chatbar")

	local function chatBarOf()
		return Guard.try(function()
			return parentFrame.Frame.BoxFrame.Frame.ChatBar
		end)
	end

	local function prefixOf()
		return Store.get("prefix") or ";"
	end

	local function bindTo(box)
		chatBin:empty()
		if not box then return end

		chatBin:connect(box.Focused, function()
			canvasPos = chrome.commandList.CanvasPosition
		end)

		chatBin:connect(box:GetPropertyChangedSignal("Text"), function()
			local stripped = Parser.stripPrefix(Str.lower(box.Text), Str.lower(prefixOf()))
			if stripped then
				revealList()
				M.filter(stripped)
			else
				chrome.minimize()
				hideList()
			end
		end)

		chatBin:connect(box.FocusLost, function(enterPressed)
			if not enterPressed
				or not Parser.stripPrefix(Str.lower(box.Text), Str.lower(prefixOf())) then
				M.filter("")
			end
			chrome.commandList.CanvasPosition = canvasPos or Vector2.new(0, 0)
			chrome.minimize()
		end)
	end

	bindTo(chatBarOf())

	bin:connect(parentFrame.ChildAdded, function(child)
		task.wait()
		if child:FindFirstChild("BoxFrame") then bindTo(chatBarOf()) end
	end)
end

-- ═══ mount / unmount ════════════════════════════════════════════════════════

function M.mount(Chrome)
	if M.mounted then return true end
	chrome = Chrome or IY.import("ui/chrome")
	if not (chrome.commandList and chrome.commandListLayout
		and chrome.rowTemplate and chrome.commandBar) then
		Guard.fail("the command list is missing from the shell")
	end

	rowsBin = bin:branch("rows")
	mouse = Guard.try(function() return Players.LocalPlayer:GetMouse() end)

	buildRows()

	-- Legacy 4347-4349: the layout tells us when the content height changed.
	bin:onChange(chrome.commandListLayout, "AbsoluteContentSize", updateCanvasSize)

	-- Registering a command pack fires this once per command, so a rebuild is
	-- coalesced rather than run 900 times during boot.
	bin:connect(Registry.changed, function()
		Sched.debounce("ui.cmdlist.refresh", 0.1, function() M.refresh() end)
	end)

	attachCommandBar()
	attachKeys()
	attachTooltip()

	M.mounted = true

	Sched.spawn("ui/cmdlist.chat", attachChatSuggestions)

	-- Legacy 4939: the list starts filtered to everything and collapsed.
	M.filter("", { minimize = true })
	return true
end

function M.unmount()
	if not M.mounted then return false end
	M.mounted = false
	bin:empty()
	rowsBin = nil
	rows = {}
	topCommand = nil
	canvasPos = nil
	lastFilter = nil
	visibleRows = 0
	mouse = nil
	guiTarget = nil
	chrome = nil
	return true
end

IY.onUnload(function()
	M.unmount()
	bin:destroy()
end, "ui/cmdlist")

return M
