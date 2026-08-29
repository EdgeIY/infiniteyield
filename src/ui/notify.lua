--[[═══════════════════════════════════════════════════════════════════════════
	ui/notify · the notification driver, the popup and the announcement window
	─────────────────────────────────────────────────────────────────────────
	Legacy source.ref.lua 3239-3285 (`notify`, the pin button, the two tweens and
	the dedupe counter), 2976-3058 (`createPopup`) and 13300-13394 (the server
	announcement window).

	    Notify.mount(Chrome)         wire up the widget ui/chrome built
	    Notify.render(entry)         show one { title, text, duration, level, repeated }
	    Notify.popup(title, text)    the modal popup
	    Notify.announcement(text)    the server announcement window
	    Notify.unmount()

	core/notify buffers everything raised before the interface exists and replays
	it through `render` the moment ui/init hands the sink over, so several
	messages arrive back to back on the first frame. The legacy `notify()` could
	not survive that, and five bugs came out of it:

	  · `CloseButton.MouseButton1Click` was connected on *every* call and never
	    disconnected, so after N notifications one close click ran N handlers.
	  · `pinNotification` was a single module-wide connection: a second
	    notification disconnected the first one's pin handler, and the first one's
	    later `:Disconnect()` hit the second one's.
	  · the title and body were only assigned after `wait(0.6)`, so a
	    notification arriving inside that window rewrote the text of the one that
	    was still sliding in.
	  · the counter bookkeeping was self-cancelling -- `local LnotifyCount =
	    notifyCount+1` immediately followed by `notifyCount = notifyCount+1` --
	    so `LnotifyCount == notifyCount` was always true.
	  · nothing was queued, so two notifications half a second apart showed one
	    message inside the other one's lifetime.

	There is one close connection, one pin connection, per-notification state and
	a queue: one at a time, in order.
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Assets = IY.import("ui/assets")
local Bin    = IY.import("core/bin")
local Guard  = IY.import("core/guard")
local Lib    = IY.import("ui/lib")
local Log    = IY.import("core/log")
local Sched  = IY.import("core/scheduler")
local Theme  = IY.import("ui/theme")

local log = Log.scope("ui/notify")

local M = {}

M.mounted = false

-- Legacy 3272-3276: ten seconds unless the caller asked for a length.
local DEFAULT_DURATION = 10
-- Legacy 3257: the pause between parking the frame and re-texting it.
local SETTLE = 0.6
-- Legacy 3256/3266/3280: both directions, same tween.
local SLIDE = 0.5
local SHOWN_Y  = -100
local PARKED_Y = 0

local bin = Bin.new("ui/notify")
M.bin = bin

local chrome  = nil
local widget  = nil          -- Chrome.notification
local queue   = {}           -- entries waiting for the frame
local queued  = {}           -- entry -> true, so a dedupe repeat is not queued twice
local current = nil          -- state of the notification on screen
local pump    = nil          -- the thread draining the queue
local windows = {}           -- live popup / announcement bins

local function clock()
	if os and os.clock then return os.clock() end
	return tick()
end

-- ═══ the notification widget ════════════════════════════════════════════════

--[[ `PARKED_Y` puts the frame just under the bottom edge and `SHOWN_Y` shows it.
     The X offset is wherever dragging the main window left it (legacy read
     `Notification.Position.X.Offset` on every tween), so it is read each time
     rather than remembered. ]]
local function slide(y)
	if not widget then return end
	local frame = widget.frame
	frame:TweenPosition(UDim2.new(1, frame.Position.X.Offset, 1, y),
		"InOut", "Quart", SLIDE, true, nil)
end

--[[ Legacy 3259-3265, plus the repeat counter. core/notify hands the *same*
     entry table back with `repeated` set when a message repeats inside its
     dedupe window, which is what turns a second identical message into an "x2"
     counter instead of a second notification. ]]
local function applyText(entry)
	if not widget then return end
	local title, text = entry.title, entry.text
	if text == nil then title, text = "Notification", entry.title end
	text = tostring(text)
	local count = tonumber(entry.repeated)
	if count and count > 1 then
		text = text .. " (x" .. tostring(count) .. ")"
	end
	widget.title.Text = tostring(title)
	widget.body.Text = text
end

local function durationOf(entry)
	local seconds = tonumber(entry.duration)
	if not seconds or seconds <= 0 then return DEFAULT_DURATION end
	return seconds
end

--[[ Show one entry and hold the frame until it is closed, pinned or times out.
     Runs on the pump thread, so the yields here are what serialise the queue. ]]
local function present(entry)
	local state = { entry = entry, pinned = false, closed = false }
	current = state
	queued[entry] = nil

	-- Park first, exactly as legacy did even for the very first notification:
	-- the text is only ever swapped while the frame is out of sight.
	slide(PARKED_Y)
	task.wait(SETTLE)
	if not M.mounted or current ~= state then return end

	applyText(entry)
	slide(SHOWN_Y)

	state.deadline = clock() + durationOf(entry)
	while M.mounted and current == state do
		-- Pinned: it stays up until the next notification takes the frame, so
		-- `current` is deliberately left pointing at it and the close button
		-- keeps working.
		if state.pinned then return end
		if clock() >= state.deadline then break end
		task.wait(0.05)
	end
	if current ~= state then return end
	slide(PARKED_Y)
	current = nil
end

--[[ One thread drains the queue. Started on demand and left to finish, so a
     pinned notification simply ends the run with the frame still on screen. ]]
local function drain()
	if pump and coroutine.status(pump) ~= "dead" then return end
	pump = task.spawn(function()
		while M.mounted and #queue > 0 do
			local entry = table.remove(queue, 1)
			-- Contained per entry: one bad message must not stall the queue.
			Guard.call("ui/notify.present", present, entry)
		end
	end)
end

--[[ The sink core/notify calls. Never yields: it queues and returns, which is
     what lets the boot-time replay hand over two dozen messages in one go. ]]
function M.render(entry)
	if not M.mounted or type(entry) ~= "table" then return false end

	if entry.repeated then
		local state = current
		if state and state.entry == entry then
			-- Same message inside the dedupe window: bump the counter in place and
			-- give it its full duration again, rather than sliding an identical
			-- notification in behind it.
			applyText(entry)
			state.deadline = clock() + durationOf(entry)
			return true
		end
		if queued[entry] then return true end
	end

	queue[#queue + 1] = entry
	queued[entry] = true
	drain()
	return true
end

function M.pending()
	return #queue
end

-- ═══ the shared window shell ════════════════════════════════════════════════

local OPEN_POSITION   = UDim2.new(0.5, -180, 0, 150)
local CLOSED_POSITION = UDim2.new(0.5, -180, 0, -500)

local function forgetWindow(windowBin)
	for i = #windows, 1, -1 do
		if windows[i] == windowBin then table.remove(windows, i) end
	end
end

--[[ The popup and the announcement are the same 360-wide window: a 20px title
     strip ("shadow") carrying a caption and a close button, over a background
     panel holding one wrapped label. Legacy wrote it out twice, verbatim, at
     2976 and 13312 -- and three more times for the keybind, plugin and logs
     windows. Geometry, tweens and ZIndex are unchanged.

     The one difference: the frames go through the theme instead of being handed
     a literal Color3, so a popup opened after the palette has been changed is
     the colour the user chose. The announcement window already read the live
     colours (13331-13365); createPopup hard-coded the defaults. ]]
local function makeWindow(spec)
	if not (chrome and chrome.scaled) then
		Guard.fail("the interface has not mounted yet")
	end

	local windowBin = Bin.new("ui/notify/window")
	windows[#windows + 1] = windowBin

	local function inst(className)
		return windowBin:add(Instance.new(className))
	end

	local function themed(instance, registry)
		Theme.register(instance, registry)
		-- Added after the instance, so it runs before the destroy on cleanup.
		windowBin:add(function() Theme.unregister(instance) end)
		return instance
	end

	local root = inst("Frame")
	root.Name = Lib.randomName()
	root.Parent = chrome.scaled
	root.Active = true
	root.BackgroundTransparency = 1
	root.Position = CLOSED_POSITION
	root.Size = UDim2.new(0, 360, 0, 20)
	root.ZIndex = 10

	local background = inst("Frame")
	background.Name = "background"
	background.Parent = root
	background.Active = true
	background.BackgroundColor3 = Color3.fromRGB(36, 36, 37)
	background.BorderSizePixel = 0
	background.Position = UDim2.new(0, 0, 0, 20)
	background.Size = UDim2.new(0, 360, 0, spec.height)
	background.ZIndex = 10
	themed(background, "shade1")

	local body = inst("TextLabel")
	body.Name = spec.bodyName
	body.Parent = background
	body.BackgroundTransparency = 1
	body.BorderSizePixel = 0
	body.Position = spec.bodyPosition
	body.Size = spec.bodySize
	body.Font = Enum.Font.SourceSans
	body.TextSize = spec.bodyTextSize
	body.Text = spec.text
	body.TextColor3 = Color3.new(1, 1, 1)
	body.TextWrapped = true
	body.TextXAlignment = Enum.TextXAlignment.Left
	body.TextYAlignment = Enum.TextYAlignment.Top
	body.ZIndex = 10
	themed(body, "text1")

	local shadow = inst("Frame")
	shadow.Name = "shadow"
	shadow.Parent = root
	shadow.BackgroundColor3 = Color3.fromRGB(46, 46, 47)
	shadow.BorderSizePixel = 0
	shadow.Size = UDim2.new(0, 360, 0, 20)
	shadow.ZIndex = 10
	themed(shadow, "shade2")

	local caption = inst("TextLabel")
	caption.Name = "PopupText"
	caption.Parent = shadow
	caption.BackgroundTransparency = 1
	caption.Size = UDim2.new(1, 0, 0.95, 0)
	caption.ZIndex = 10
	caption.Font = Enum.Font.SourceSans
	caption.TextSize = 14
	caption.Text = spec.title
	caption.TextColor3 = Color3.new(1, 1, 1)
	caption.TextWrapped = true
	themed(caption, "text1")

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

	-- Legacy 3053-3057 / 13387-13391: slide away, wait out the tween, destroy.
	windowBin:connect(exit.MouseButton1Click, function()
		root:TweenPosition(CLOSED_POSITION, "InOut", "Quart", 0.5, true, nil)
		task.wait(SETTLE)
		forgetWindow(windowBin)
		windowBin:destroy()
	end)

	return root, windowBin
end

--[[ Legacy createPopup (2976-3058): 360x225, slides in from above. ]]
function M.popup(title, text)
	if not M.mounted then
		log.debug("popup('%s') ignored: the interface is not mounted", tostring(title))
		return nil
	end
	local root = makeWindow({
		title        = tostring(title or ""),
		text         = tostring(text or ""),
		height       = 205,
		bodyName     = "Directions",
		bodyPosition = UDim2.new(0, 10, 0, 10),
		bodySize     = UDim2.new(0, 340, 0, 185),
		bodyTextSize = 14,
	})
	root:TweenPosition(OPEN_POSITION, "InOut", "Quart", 0.5, true, nil)
	return root
end

--[[ Legacy 13311-13392: the announcement carried in the version file. The one
     second pause before it slides in is the legacy `task.wait(1)` at 13384.
     features/version owns the text; this only shows it. ]]
function M.announcement(text)
	if not M.mounted then
		log.debug("announcement ignored: the interface is not mounted")
		return nil
	end
	local root, windowBin = makeWindow({
		title        = "Server Announcement",
		text         = tostring(text or ""),
		height       = 150,
		bodyName     = "TextLabel",
		bodyPosition = UDim2.new(0, 5, 0, 5),
		bodySize     = UDim2.new(0, 350, 0, 140),
		bodyTextSize = 18,
	})
	windowBin:add(Sched.after(1, function()
		root:TweenPosition(OPEN_POSITION, "InOut", "Quart", 0.5, true, nil)
	end))
	return root
end

-- ═══ mount / unmount ════════════════════════════════════════════════════════

--[[ Wire the widget ui/chrome already built. One connection each; which
     notification they act on is read from `current`. ]]
function M.mount(Chrome)
	if M.mounted then return true end
	chrome = Chrome or IY.import("ui/chrome")
	widget = chrome.notification
	if not (widget and widget.frame and widget.title and widget.body
		and widget.close and widget.pin) then
		Guard.fail("the notification widget is missing from the shell")
	end

	bin:connect(widget.close.MouseButton1Click, function()
		local state = current
		if not state then return end
		state.closed = true
		-- Dropping `current` here is what ends the wait in present(), and it
		-- stops a stray pin click from blinking a frame that is already gone.
		current = nil
		slide(PARKED_Y)
	end)

	bin:connect(widget.pin.MouseButton1Click, function()
		local state = current
		if not state or state.pinned or state.closed then return end
		state.pinned = true
		-- Legacy 3251-3253: the title bar blinks once to acknowledge the pin.
		widget.title.BackgroundTransparency = 1
		Sched.after(0.5, function()
			if widget then widget.title.BackgroundTransparency = 0 end
		end, "ui.notify.pin")
	end)

	bin:add(function() Sched.stop("ui.notify.pin") end)

	bin:add(function()
		if pump and coroutine.status(pump) ~= "dead" then
			pcall(task.cancel, pump)
		end
		pump = nil
	end)

	bin:add(function()
		for i = #windows, 1, -1 do windows[i]:destroy() end
		windows = {}
	end)

	M.mounted = true
	return true
end

function M.unmount()
	if not M.mounted then return false end
	M.mounted = false
	bin:empty()
	queue, queued = {}, {}
	current = nil
	chrome, widget = nil, nil
	return true
end

IY.onUnload(function()
	M.unmount()
	bin:destroy()
end, "ui/notify")

return M
