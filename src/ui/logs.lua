--[[═══════════════════════════════════════════════════════════════════════════
	ui/logs · the chat / join log window
	─────────────────────────────────────────────────────────────────────────
	Legacy source.ref.lua 1751-1967 (the window, its two tabs, the Clear / Save /
	Toggle buttons, the two scrolling panes and the tab selector), 3287-3392 (the
	row builders), 3911-3969 (the button handlers), 4022-4049 (save to file) and
	4077-4087 (hide / exit).

	    Logs.mount(Chrome)
	    Logs.open() / close() / toggle()
	    Logs.showTab("chat"|"join")
	    Logs.refresh()
	    Logs.unmount()

	The data is features/chatlogs. This module only renders it and calls into it:
	nothing here records a message, which is why chat logging now works with the
	interface closed, absent, or broken.

	Four legacy bugs are fixed, all marked at the code:

	  · both tab handlers did `table.remove(shade3, table.find(shade3, selectChat))`
	    for a button that was registered in `shade2`. `table.find` returned nil and
	    `table.remove(list, nil)` removes the *last* element, so clicking the tab
	    you were already on quietly deleted an unrelated instance from a colour
	    registry. Duplicated at 3952-3953, 11746-11747 and 11760-11761.
	  · line 3385 set the join pane's CanvasPosition from the *chat* pane's.
	  · the 2546-row cap called `ClearAllChildren` on the pane, which left every
	    one of those destroyed labels in the `text1` registry (and, on the join
	    pane, destroyed the UIListLayout the rows were laid out by).
	  · `Hide` branched on the window's current position, which is mid-tween for
	    0.3s, so a fast second click toggled the wrong way.

	Every button is `MouseButton1Click`; the logs window was the only place in the
	interface still using `MouseButton1Down`.
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Assets   = IY.import("ui/assets")
local Bin      = IY.import("core/bin")
local Chat     = IY.import("features/chatlogs")
local Guard    = IY.import("core/guard")
local Lib      = IY.import("ui/lib")
local Notify   = IY.import("core/notify")
local Sched    = IY.import("core/scheduler")
local Services = IY.import("core/services")
local Store    = IY.import("core/store")
local Theme    = IY.import("ui/theme")

local Players      = Services.Players
local TweenService = Services.TweenService

local M = {}

M.mounted = false

-- Legacy 1755/4078, 11739 and 4083: parked, open, and title-bar-only.
local CLOSED_POSITION    = UDim2.new(0, 0, 1, 10)
local OPEN_POSITION      = UDim2.new(0, 0, 1, -265)
local MINIMIZED_POSITION = UDim2.new(0, 0, 1, -20)

-- Legacy 3296 / 3339. Reached now that the rows outlive the 2500-entry buffer.
local ROW_CAP = 2546

local SHADE1 = Color3.new(0.141176, 0.141176, 0.145098)
local SHADE2 = Color3.new(0.180392, 0.180392, 0.184314)
local SHADE3 = Color3.new(0.305882, 0.305882, 0.309804)
local WHITE  = Color3.new(1, 1, 1)

local bin = Bin.new("ui/logs")
M.bin = bin

local chrome = nil
local chatRowsBin, joinRowsBin = nil, nil

-- the window
local root, chatPane, joinPane = nil, nil, nil
local chatScroll, joinScroll, joinLayout = nil, nil, nil
local chatToggle, joinToggle = nil, nil
local selectChat, selectJoin = nil, nil
local hideButton, exitButton = nil, nil
local chatClear, joinClear, saveButton = nil, nil, nil

local opened    = false
local minimized = false
local tab       = "chat"

local chatRows   = {}    -- TextLabels, oldest first
local chatRowOf  = {}    -- chat entry -> its label
local chatHeight = 0     -- legacy `alls`: the cumulative row height
local joinRows   = {}    -- Frames, oldest first
local joinRowOf  = {}    -- join entry -> { frame = , info = }

--[[ Every instance goes in a bin, and the theme registration is undone before
     the instance is destroyed -- the legacy registries only ever grew. ]]
local function themed(ownerBin, instance, registry)
	Theme.register(instance, registry)
	ownerBin:add(function() Theme.unregister(instance) end)
	return instance
end

local function inst(className)
	return bin:add(Instance.new(className))
end

--[[ Legacy 1751-1810: the window, its title strip, the minimize button and the
     close button. `background` is deliberately not themed -- the legacy window
     did not register it either, and both tab panes cover it exactly. ]]
local function buildShell()
	root = inst("Frame")
	root.Name = Lib.randomName()
	root.Parent = chrome.scaled
	root.Active = true
	root.BackgroundTransparency = 1
	root.Position = CLOSED_POSITION
	root.Size = UDim2.new(0, 338, 0, 20)
	root.ZIndex = 10

	local shadow = inst("Frame")
	shadow.Name = "shadow"
	shadow.Parent = root
	shadow.BackgroundColor3 = SHADE2
	shadow.BorderSizePixel = 0
	shadow.Position = UDim2.new(0, 0, 0.00999999978, 0)
	shadow.Size = UDim2.new(0, 338, 0, 20)
	shadow.ZIndex = 10
	themed(bin, shadow, "shade2")

	hideButton = inst("TextButton")
	hideButton.Name = "Hide"
	hideButton.Parent = shadow
	hideButton.BackgroundTransparency = 1
	hideButton.Position = UDim2.new(1, -40, 0, 0)
	hideButton.Size = UDim2.new(0, 20, 0, 20)
	hideButton.ZIndex = 10
	hideButton.Text = ""

	local hideImage = inst("ImageLabel")
	hideImage.Parent = hideButton
	hideImage.BackgroundColor3 = WHITE
	hideImage.BackgroundTransparency = 1
	hideImage.Position = UDim2.new(0, 3, 0, 3)
	hideImage.Size = UDim2.new(0, 14, 0, 14)
	hideImage.Image = Assets.get("infiniteyield/assets/minimize.png")
	hideImage.ZIndex = 10

	local caption = inst("TextLabel")
	caption.Name = "PopupText"
	caption.Parent = shadow
	caption.BackgroundTransparency = 1
	caption.Size = UDim2.new(1, 0, 0.949999988, 0)
	caption.ZIndex = 10
	caption.Font = Enum.Font.SourceSans
	caption.FontSize = Enum.FontSize.Size14
	caption.Text = "Logs"
	caption.TextColor3 = WHITE
	caption.TextWrapped = true
	themed(bin, caption, "text1")

	exitButton = inst("TextButton")
	exitButton.Name = "Exit"
	exitButton.Parent = shadow
	exitButton.BackgroundTransparency = 1
	exitButton.Position = UDim2.new(1, -20, 0, 0)
	exitButton.Size = UDim2.new(0, 20, 0, 20)
	exitButton.ZIndex = 10
	exitButton.Text = ""

	local exitImage = inst("ImageLabel")
	exitImage.Parent = exitButton
	exitImage.BackgroundColor3 = WHITE
	exitImage.BackgroundTransparency = 1
	exitImage.Position = UDim2.new(0, 5, 0, 5)
	exitImage.Size = UDim2.new(0, 10, 0, 10)
	exitImage.Image = Assets.get("infiniteyield/assets/close.png")
	exitImage.ZIndex = 10

	local background = inst("Frame")
	background.Name = "background"
	background.Parent = root
	background.Active = true
	background.BackgroundColor3 = SHADE1
	background.BorderSizePixel = 0
	background.ClipsDescendants = true
	background.Position = UDim2.new(0, 0, 1, 0)
	background.Size = UDim2.new(0, 338, 0, 245)
	background.ZIndex = 10
	return background
end

--[[ The Clear / Toggle / Save buttons: one 20px shade2 button, four different
     positions. Legacy wrote all four out longhand (1832-1872, 1899-1925). ]]
local function paneButton(parent, name, position, size, text)
	local button = inst("TextButton")
	button.Name = name
	button.Parent = parent
	button.BackgroundColor3 = SHADE2
	button.BorderSizePixel = 0
	button.Position = position
	button.Size = size
	button.ZIndex = 10
	button.Font = Enum.Font.SourceSans
	button.FontSize = Enum.FontSize.Size14
	button.Text = text
	button.TextColor3 = WHITE
	themed(bin, button, "shade2")
	themed(bin, button, "text1")
	return button
end

--[[ Legacy 1874-1886 / 1927-1939: the two panes are identical. ]]
local function paneScroll(parent)
	local scroll = inst("ScrollingFrame")
	scroll.Name = "scroll"
	scroll.Parent = parent
	scroll.BackgroundColor3 = SHADE2
	scroll.BorderSizePixel = 0
	scroll.Position = UDim2.new(0, 5, 0, 25)
	scroll.Size = UDim2.new(0, 328, 0, 190)
	scroll.ZIndex = 10
	scroll.BottomImage = "rbxasset://textures/ui/Scroll/scroll-middle.png"
	scroll.CanvasSize = UDim2.new(0, 0, 0, 10)
	scroll.ScrollBarThickness = 8
	scroll.TopImage = "rbxasset://textures/ui/Scroll/scroll-middle.png"
	themed(bin, scroll, "scroll")
	themed(bin, scroll, "shade2")
	return scroll
end

local function tabButton(parent, name, position, text)
	local button = inst("TextButton")
	button.Name = name
	button.Parent = parent
	button.BorderSizePixel = 0
	button.Position = position
	button.Size = UDim2.new(0, 164, 0, 20)
	button.ZIndex = 10
	button.Font = Enum.Font.SourceSans
	button.FontSize = Enum.FontSize.Size14
	button.Text = text
	button.TextColor3 = WHITE
	themed(bin, button, "text1")
	return button
end

--[[ Legacy 1822-1830 (chat pane), 1888-1897 (join pane) and 1941-1967 (the two
     tab buttons). The selected tab is shade2 and the other one shade3, which is
     the state the legacy construction started in. ]]
local function buildPanes(background)
	chatPane = inst("Frame")
	chatPane.Name = "chat"
	chatPane.Parent = background
	chatPane.Active = true
	chatPane.BackgroundColor3 = SHADE1
	chatPane.BorderSizePixel = 0
	chatPane.ClipsDescendants = true
	chatPane.Size = UDim2.new(0, 338, 0, 245)
	chatPane.ZIndex = 10
	themed(bin, chatPane, "shade1")

	chatClear  = paneButton(chatPane, "Clear",
		UDim2.new(0, 5, 0, 220), UDim2.new(0, 50, 0, 20), "Clear")
	saveButton = paneButton(chatPane, "SaveChatlogs",
		UDim2.new(0, 258, 0, 220), UDim2.new(0, 75, 0, 20), "Save To .txt")
	chatToggle = paneButton(chatPane, "Toggle",
		UDim2.new(0, 60, 0, 220), UDim2.new(0, 66, 0, 20), "Disabled")
	chatScroll = paneScroll(chatPane)

	joinPane = inst("Frame")
	joinPane.Name = "join"
	joinPane.Parent = background
	joinPane.Active = true
	joinPane.BackgroundColor3 = SHADE1
	joinPane.BorderSizePixel = 0
	joinPane.ClipsDescendants = true
	joinPane.Size = UDim2.new(0, 338, 0, 245)
	joinPane.Visible = false
	joinPane.ZIndex = 10
	themed(bin, joinPane, "shade1")

	joinToggle = paneButton(joinPane, "Toggle",
		UDim2.new(0, 60, 0, 220), UDim2.new(0, 66, 0, 20), "Disabled")
	joinClear  = paneButton(joinPane, "Clear",
		UDim2.new(0, 5, 0, 220), UDim2.new(0, 50, 0, 20), "Clear")
	joinScroll = paneScroll(joinPane)

	joinLayout = inst("UIListLayout")
	joinLayout.Parent = joinScroll

	selectChat = tabButton(background, "selectChat", UDim2.new(0, 5, 0, 5), "Chat Logs")
	selectChat.BackgroundColor3 = SHADE2
	themed(bin, selectChat, "shade2")

	selectJoin = tabButton(background, "selectJoin", UDim2.new(0, 169, 0, 5), "Join Logs")
	selectJoin.BackgroundColor3 = SHADE3
	themed(bin, selectJoin, "shade3")
end

-- ═══ chat rows ══════════════════════════════════════════════════════════════

local function clearChatRows()
	if chatRowsBin then chatRowsBin:empty() end
	chatRows, chatRowOf = {}, {}
	chatHeight = 0
	if chatScroll then chatScroll.CanvasSize = UDim2.new(0, 0, 0, 10) end
end

--[[ Legacy CreateLabel's view half (3296-3334). The pane has no layout, so each
     row is positioned at the running total of the ones above it -- legacy summed
     the children's heights on every message; the total is carried instead.

     `animate` is false for a bulk rebuild: 2,500 rows must not each start two
     tweens. A live message animates exactly as it always did. ]]
local function addChatRow(entry, animate)
	if #chatRows >= ROW_CAP then clearChatRows() end
	local offset = chatHeight

	local label = chatRowsBin:add(Instance.new("TextLabel"))
	label.Name = tostring(entry.player)
	label.Parent = chatScroll
	label.ZIndex = 10
	label.RichText = true
	label.Text = Chat.line(entry)
	-- Legacy 3316: reading ContentText back strips the markup, so a message
	-- containing rich-text tags cannot format the log.
	label.Text = label.ContentText
	label.Size = UDim2.new(0, 322, 0, 84)
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.Font = Enum.Font.SourceSans
	label.Position = UDim2.new(-1, 0, 0, offset)
	label.TextTransparency = 1
	label.TextScaled = false
	label.TextSize = 14
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Top
	themed(chatRowsBin, label, "text1")

	local height = label.TextBounds.Y
	label.Size = UDim2.new(0, 322, 0, height)

	chatHeight = offset + height
	chatScroll.CanvasSize = UDim2.new(0, 0, 0, chatHeight)
	chatScroll.CanvasPosition = Vector2.new(0, chatScroll.CanvasPosition.Y + height)

	if animate then
		label:TweenPosition(UDim2.new(0, 3, 0, offset), "In", "Quint", 0.5)
		TweenService:Create(label, TweenInfo.new(1.25, Enum.EasingStyle.Linear),
			{ TextTransparency = 0 }):Play()
	else
		label.Position = UDim2.new(0, 3, 0, offset)
		label.TextTransparency = 0
	end

	chatRows[#chatRows + 1] = label
	chatRowOf[entry] = label
	return label
end

--[[ Legacy 3293: a repeated message rewrites its own row as "... (xN)" rather
     than adding another. The row is not resized, exactly as before, so the rows
     below it keep their offsets. ]]
local function updateChatRow(entry)
	local label = chatRowOf[entry]
	if not label then return addChatRow(entry, true) end
	label.Text = Chat.line(entry)
	label.Text = label.ContentText
	return label
end

-- ═══ join rows ══════════════════════════════════════════════════════════════

local function updateJoinCanvas()
	if not (joinScroll and joinLayout) then return end
	joinScroll.CanvasSize = UDim2.new(0, 0, 0, joinLayout.AbsoluteContentSize.Y)
end

local function clearJoinRows()
	if joinRowsBin then joinRowsBin:empty() end
	joinRows, joinRowOf = {}, {}
	if joinScroll then joinScroll.CanvasSize = UDim2.new(0, 0, 0, 10) end
end

--[[ Legacy 3374: "User ID / Account Age / Joined Roblox". features/chatlogs
     fills `created` in asynchronously and re-fires `changed`, which is what
     replaces the legacy in-place `gsub` of the "Loading..." placeholder. A leave
     entry never gets one looked up, so it says so rather than loading forever. ]]
local function accountText(entry)
	local created = entry.created
	if not created then
		created = (entry.action == "join") and "Loading..." or "Unknown"
	end
	return "User ID: " .. tostring(entry.userId)
		.. "\nAccount Age: " .. tostring(entry.accountAge)
		.. "\nJoined Roblox: " .. created
end

--[[ Legacy CreateJoinLabel's view half (3339-3385). ]]
local function addJoinRow(entry)
	if #joinRows >= ROW_CAP then clearJoinRows() end

	local frame = joinRowsBin:add(Instance.new("Frame"))
	frame.Name = Lib.randomName()
	frame.Parent = joinScroll
	frame.BackgroundColor3 = WHITE
	frame.BackgroundTransparency = 1
	frame.BorderColor3 = Color3.new(0.105882, 0.164706, 0.207843)
	frame.Size = UDim2.new(1, 0, 0, 50)

	local info1 = joinRowsBin:add(Instance.new("TextLabel"))
	info1.Name = Lib.randomName()
	info1.Parent = frame
	info1.BackgroundTransparency = 1
	info1.BorderSizePixel = 0
	info1.Position = UDim2.new(0, 45, 0, 0)
	info1.Size = UDim2.new(0, 135, 1, 0)
	info1.ZIndex = 10
	info1.Font = Enum.Font.SourceSans
	info1.FontSize = Enum.FontSize.Size14
	info1.Text = "Username: " .. tostring(entry.player) .. "\n"
		.. ((entry.action == "leave") and "Left Server: " or "Joined Server: ")
		.. tostring(entry.time)
	info1.TextColor3 = WHITE
	info1.TextWrapped = true
	info1.TextXAlignment = Enum.TextXAlignment.Left
	-- Legacy left the join rows out of `text1` altogether, so they stayed white
	-- whatever the palette was. Registered, which is identical by default.
	themed(joinRowsBin, info1, "text1")

	local info2 = joinRowsBin:add(Instance.new("TextLabel"))
	info2.Name = Lib.randomName()
	info2.Parent = frame
	info2.BackgroundTransparency = 1
	info2.BorderSizePixel = 0
	info2.Position = UDim2.new(0, 185, 0, 0)
	info2.Size = UDim2.new(0, 140, 1, -5)
	info2.ZIndex = 10
	info2.Font = Enum.Font.SourceSans
	info2.FontSize = Enum.FontSize.Size14
	info2.Text = accountText(entry)
	info2.TextColor3 = WHITE
	info2.TextWrapped = true
	info2.TextXAlignment = Enum.TextXAlignment.Left
	info2.TextYAlignment = Enum.TextYAlignment.Center
	themed(joinRowsBin, info2, "text1")

	local avatar = joinRowsBin:add(Instance.new("ImageLabel"))
	avatar.Parent = frame
	avatar.BackgroundTransparency = 1
	avatar.BorderSizePixel = 0
	avatar.Size = UDim2.new(0, 45, 1, 0)
	-- Legacy called GetUserThumbnailAsync inline (3383), so a throttled thumbnail
	-- request stalled the whole PlayerAdded handler. Off-thread and contained: the
	-- headshot just appears when it arrives.
	Sched.spawn("ui.logs.thumbnail", function()
		local image = Guard.try(function()
			return Players:GetUserThumbnailAsync(entry.userId,
				Enum.ThumbnailType.AvatarThumbnail, Enum.ThumbnailSize.Size420x420)
		end)
		if image and avatar.Parent then avatar.Image = image end
	end)

	updateJoinCanvas()
	-- Legacy 3385 read `scroll_2.CanvasPosition` here -- the chat pane's -- so the
	-- join pane scrolled to an offset derived from the wrong list.
	joinScroll.CanvasPosition =
		Vector2.new(0, joinScroll.CanvasPosition.Y + frame.AbsoluteSize.Y)

	joinRows[#joinRows + 1] = frame
	joinRowOf[entry] = { frame = frame, info = info2 }
	return frame
end

local function updateJoinRow(entry)
	local row = joinRowOf[entry]
	if not row then return addJoinRow(entry) end
	row.info.Text = accountText(entry)
	return row.frame
end

-- ═══ window state ═══════════════════════════════════════════════════════════

local function slide(position)
	if not root then return false end
	root:TweenPosition(position, "InOut", "Quart", 0.3, true, nil)
	return true
end

--[[ Legacy 11739. ]]
function M.open()
	if not M.mounted then return false end
	opened, minimized = true, false
	return slide(OPEN_POSITION)
end

--[[ Legacy 4077-4079: Exit only slides the window away. ]]
function M.close()
	if not M.mounted then return false end
	opened, minimized = false, false
	return slide(CLOSED_POSITION)
end

--[[ Legacy 4081-4087, the Hide button. Legacy compared the frame's *current*
     position, which is mid-tween for 0.3s, so a fast second click toggled the
     wrong way. The state is explicit. ]]
function M.minimize()
	if not M.mounted then return false end
	opened, minimized = true, true
	return slide(MINIMIZED_POSITION)
end

function M.toggle()
	if not M.mounted then return false end
	if opened then return M.close() end
	return M.open()
end

function M.isOpen()
	return opened
end

--[[ Legacy 3949-3969 and its two copies at 11742-11767. Which registry each tab
     button belongs to is changed through the theme: legacy removed `selectChat`
     from `shade3` when it was in `shade2`, so `table.find` returned nil and
     `table.remove(list, nil)` dropped the last entry of that registry instead --
     clicking the tab you were already on unthemed an unrelated instance. ]]
function M.showTab(name)
	if not M.mounted then return false end
	tab = (name == "join") and "join" or "chat"
	local chatActive = tab == "chat"

	joinPane.Visible = not chatActive
	chatPane.Visible = chatActive

	local activeButton = chatActive and selectChat or selectJoin
	local idleButton   = chatActive and selectJoin or selectChat
	Theme.unregister(activeButton, "shade3")
	Theme.register(activeButton, "shade2")
	Theme.unregister(idleButton, "shade2")
	Theme.register(idleButton, "shade3")
	return true
end

function M.tab()
	return tab
end

-- ═══ content ════════════════════════════════════════════════════════════════

--[[ Legacy 3208-3218 set these two captions once, at load, from the settings it
     had just read. They follow the setting now, so `;chatlogs`, a settings reload
     and the buttons themselves all agree. ]]
local function syncToggles()
	if not M.mounted then return end
	chatToggle.Text = Chat.chatEnabled() and "Enabled" or "Disabled"
	joinToggle.Text = Chat.joinEnabled() and "Enabled" or "Disabled"
end

--[[ Rebuild both panes from features/chatlogs. ]]
function M.refresh()
	if not M.mounted then return false end
	clearChatRows()
	clearJoinRows()
	local chat, joins = Chat.chat, Chat.joins
	for i = 1, #chat do addChatRow(chat[i], false) end
	for i = 1, #joins do addJoinRow(joins[i]) end
	syncToggles()
	return true
end

local function attachData()
	bin:connect(Chat.changed, function(kind, entry, updated)
		if not M.mounted then return end
		if kind == "chat" then
			if updated then updateChatRow(entry) else addChatRow(entry, true) end
		elseif kind == "join" then
			if updated then updateJoinRow(entry) else addJoinRow(entry) end
		elseif kind == "chat-cleared" then
			clearChatRows()
		elseif kind == "join-cleared" then
			clearJoinRows()
		elseif kind == "settings" then
			syncToggles()
		end
	end)

	-- Both watches fire immediately, which is what primes the two captions.
	bin:add(Store.watch("logsEnabled", syncToggles))
	bin:add(Store.watch("joinLogsEnabled", syncToggles))

	-- Legacy read AbsoluteContentSize one line after parenting the row, before
	-- the layout had run, so the join pane was always one row short of scrollable.
	bin:onChange(joinLayout, "AbsoluteContentSize", updateJoinCanvas)
end

-- ═══ buttons ════════════════════════════════════════════════════════════════

--[[ Legacy 3911-3969, 4022-4049 and 4077-4087. Every handler was
     `MouseButton1Down` -- the only place in the interface that was -- so a press
     that slid off the button still fired. They are all Clicks now. ]]
local function attachButtons()
	bin:connect(hideButton.MouseButton1Click, function()
		if minimized then M.open() else M.minimize() end
	end)

	bin:connect(exitButton.MouseButton1Click, function() M.close() end)

	bin:connect(selectChat.MouseButton1Click, function() M.showTab("chat") end)
	bin:connect(selectJoin.MouseButton1Click, function() M.showTab("join") end)

	bin:connect(chatClear.MouseButton1Click, function() Chat.clearChat() end)
	bin:connect(joinClear.MouseButton1Click, function() Chat.clearJoins() end)

	bin:connect(chatToggle.MouseButton1Click, function()
		Chat.setChatEnabled(not Chat.chatEnabled())
	end)
	bin:connect(joinToggle.MouseButton1Click, function()
		Chat.setJoinEnabled(not Chat.joinEnabled())
	end)

	bin:connect(saveButton.MouseButton1Click, function()
		-- The first save resolves the place name, which is a web call: legacy said
		-- so with this exact notification (4025) before it started.
		if #Chat.chat > 0 then Notify.send("Loading", "Hold on a sec") end
		Sched.spawn("ui.logs.save", function()
			local ok, result = Guard.call("ui/logs.save", Chat.saveToFile)
			if ok then
				Notify.send("Chat Logs",
					"Saved chat logs to the workspace folder within your exploit folder.")
			else
				Notify.send("Chat Logs", Guard.describe(result))
			end
		end)
	end)
end

-- ═══ mount / unmount ════════════════════════════════════════════════════════

function M.mount(Chrome)
	if M.mounted then return true end
	chrome = Chrome or IY.import("ui/chrome")
	if not chrome.scaled then
		Guard.fail("the interface has not mounted yet")
	end

	chatRowsBin = bin:branch("chatrows")
	joinRowsBin = bin:branch("joinrows")

	local background = buildShell()
	buildPanes(background)

	-- Legacy 2243: dragGUI(logs), by the whole window.
	bin:add(Lib.drag(root, root, chrome.scale))

	M.mounted = true

	attachButtons()
	attachData()
	M.refresh()
	return true
end

function M.unmount()
	if not M.mounted then return false end
	M.mounted = false
	bin:empty()
	chatRowsBin, joinRowsBin = nil, nil
	root, chatPane, joinPane = nil, nil, nil
	chatScroll, joinScroll, joinLayout = nil, nil, nil
	chatToggle, joinToggle = nil, nil
	selectChat, selectJoin = nil, nil
	hideButton, exitButton = nil, nil
	chatClear, joinClear, saveButton = nil, nil, nil
	chatRows, chatRowOf = {}, {}
	joinRows, joinRowOf = {}, {}
	chatHeight = 0
	opened, minimized, tab = false, false, "chat"
	chrome = nil
	return true
end

IY.onUnload(function()
	M.unmount()
	bin:destroy()
end, "ui/logs")

return M
