--[[═══════════════════════════════════════════════════════════════════════════
	ui/chrome · the shared shell every other UI module builds against
	─────────────────────────────────────────────────────────────────────────
	Legacy source.ref.lua 342-750 (holder, title, backdrop, command bar, command
	list, gear and ? buttons, settings shell, the settings row factory, the row
	template, the notification widget, the tooltip), 752-781 (the intro overlay),
	3198-3237 (the slide states), 3394-3418 (prefix key + hover), 4246-4331
	(viewport clamping and the main window drag), 13111-13136 (the mobile "IY"
	button), 13138-13156 (UIScale) and 13396-13412 (the intro animation).

	    local Chrome = IY.import("ui/chrome")
	    Chrome.mount()                     -- builds it, returns this table
	    Chrome.holder, Chrome.settingsHolder, Chrome.commandList, ...
	    Chrome.makeSettingsRow("Edit Aliases", icon)
	    Chrome.unmount()                   -- destroys everything it created

	`Chrome.notification` and `Chrome.tooltip` are tables, not the frames
	themselves: a Roblox Instance cannot carry extra fields, so the frame is
	`.frame` and the labels are `.title` / `.body` (plus `.close` / `.pin` on the
	notification). The notification *driver* lives in ui/notify; this module only
	builds the widget.

	What is not a straight copy:
	  · `SettingsOpen` and `isHidden` were file-locals half a dozen commands
	    reached into. They are behind setSettingsOpen/settingsOpen and
	    setHidden/isHidden now.
	  · the prefix key follows Store.watch("prefix"); the legacy handler captured
	    the prefix once at load, so changing it left the old key working.
	  · everything created goes in `Chrome.bin`, so `;unloadiy` removes the whole
	    interface instead of one ScreenGui.
	  · the UIScale coordinate-space fixes, marked inline.
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Assets   = IY.import("ui/assets")
local Bin      = IY.import("core/bin")
local Guard    = IY.import("core/guard")
local Lib      = IY.import("ui/lib")
local Log      = IY.import("core/log")
local Platform = IY.import("core/platform")
local Sched    = IY.import("core/scheduler")
local Services = IY.import("core/services")
local Store    = IY.import("core/store")
local Theme    = IY.import("ui/theme")

local log = Log.scope("ui/chrome")

local Players          = Services.Players
local RunService       = Services.RunService
local TweenService     = Services.TweenService

local M = {}

M.mounted = false
M.bin     = nil

local bin = nil                  -- the live bin while mounted
local mouse = nil                -- LocalPlayer:GetMouse(), for the prefix key
local cameraBin = nil
local introBackground, introLogo, introCredits = nil, nil, nil
local settingsIsOpen = false
local hiddenState = false
local wasStayOpen = false
local minimizeNum = -20          -- legacy global: 0 while ;hideiy is in effect
local prefixKey = ";"
local placeholderPrimed = false
local introRan = false
local lastMinimizeReq = 0

local function clock()
	if os and os.clock then return os.clock() end
	return tick()
end

local function stayOpen()
	return Store.get("stayOpen") == true
end

--[[ Every instance goes in the bin. Children would die with their parent
     anyway, but holding them all means `;unloadiy` cannot miss one that was
     re-parented somewhere else in the meantime. ]]
local function inst(className)
	local instance = Instance.new(className)
	if bin then bin:add(instance) end
	return instance
end

local function themed(instance, registry)
	Theme.register(instance, registry)
	if bin then
		bin:add(function() Theme.unregister(instance) end)
	end
	return instance
end

--[[ The live UIScale factor. Guarded against 0 because every use of it is a
     divisor. ]]
local function scaleValue()
	local scale = M.scale
	if not scale then return 1 end
	local value = scale.Scale
	if type(value) ~= "number" or value <= 0 then return 1 end
	return value
end

-- ═══ title ══════════════════════════════════════════════════════════════════

--[[ Gauss's Easter algorithm, so the egg lands on the right Sunday. Verbatim
     from legacy 373-389. ]]
local function easterKey(year)
	local A = math.floor(year / 100)
	local B = math.floor((13 + 8 * A) / 25)
	local C = (15 - B + A - math.floor(A / 4)) % 30
	local D = (4 + A - math.floor(A / 4)) % 7
	local E = (19 * (year % 19) + C) % 30
	local F = (2 * (year % 4) + 4 * (year % 7) + 6 * E + D) % 7
	local G = (22 + E + F)
	if E == 29 and F == 6 then
		return "04 19"
	elseif E == 28 and F == 6 then
		return "04 18"
	elseif 31 < G then
		return string.format("04 %02d", G - 31)
	end
	return string.format("03 %02d", G)
end

--[[ Legacy 366-396: the title, wrapped in a holiday emoji on six days a year. ]]
local function titleText()
	local text = "Infinite Yield FE v" .. tostring(IY.version)
	local days = {
		["01 01"] = "🎆",
		["02 14"] = "💝",
		["03 17"] = "☘️",
		["10 31"] = "🎃",
		["12 25"] = "🎄",
	}
	local ok, key = pcall(easterKey, tonumber(os.date("%Y")))
	if ok and key then days[key] = "🥚" end
	local emoji = days[os.date("%m %d")]
	if emoji then
		return string.format("%s %s %s", emoji, text, emoji)
	end
	return text
end

-- ═══ construction ═══════════════════════════════════════════════════════════

--[[ Legacy 342-460: the scaled container, the window, the title bar, the dark
     backdrop, the command bar, the command list and the two header buttons. ]]
local function buildWindow()
	local scaled = inst("Frame")
	scaled.Name = Lib.randomName()
	scaled.Size = UDim2.fromScale(1, 1)
	scaled.BackgroundTransparency = 1
	scaled.Parent = M.parent

	local scale = inst("UIScale")
	scale.Name = Lib.randomName()

	local holder = inst("Frame")
	holder.Name = Lib.randomName()
	holder.Parent = scaled
	holder.Active = true
	holder.BackgroundColor3 = Color3.fromRGB(46, 46, 47)
	holder.BorderSizePixel = 0
	holder.Position = UDim2.new(1, -250, 1, -220)
	holder.Size = UDim2.new(0, 250, 0, 220)
	holder.ZIndex = 10
	themed(holder, "shade2")

	local title = inst("TextLabel")
	title.Name = "Title"
	title.Parent = holder
	title.Active = true
	title.BackgroundColor3 = Color3.fromRGB(36, 36, 37)
	title.BorderSizePixel = 0
	title.Size = UDim2.new(0, 250, 0, 20)
	title.Font = Enum.Font.SourceSans
	title.TextSize = 18
	title.Text = titleText()
	title.TextColor3 = Color3.new(1, 1, 1)
	title.ZIndex = 10
	themed(title, "shade1")
	themed(title, "text1")

	local dark = inst("Frame")
	dark.Name = "Dark"
	dark.Parent = holder
	dark.Active = true
	dark.BackgroundColor3 = Color3.fromRGB(36, 36, 37)
	dark.BorderSizePixel = 0
	dark.Position = UDim2.new(0, 0, 0, 45)
	dark.Size = UDim2.new(0, 250, 0, 175)
	dark.ZIndex = 10
	themed(dark, "shade1")

	local cmdbar = inst("TextBox")
	cmdbar.Name = "Cmdbar"
	cmdbar.Parent = holder
	cmdbar.BackgroundTransparency = 1
	cmdbar.BorderSizePixel = 0
	cmdbar.Position = UDim2.new(0, 5, 0, 20)
	cmdbar.Size = UDim2.new(0, 240, 0, 25)
	cmdbar.Font = Enum.Font.SourceSans
	cmdbar.TextSize = 18
	cmdbar.TextXAlignment = Enum.TextXAlignment.Left
	cmdbar.TextColor3 = Color3.new(1, 1, 1)
	cmdbar.Text = ""
	cmdbar.ZIndex = 10
	cmdbar.PlaceholderText = "Command Bar"

	local list = inst("ScrollingFrame")
	list.Name = "CMDs"
	list.Parent = holder
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.Position = UDim2.new(0, 5, 0, 45)
	list.Size = UDim2.new(0, 245, 0, 175)
	list.ScrollBarImageColor3 = Color3.fromRGB(78, 78, 79)
	list.BottomImage = "rbxasset://textures/ui/Scroll/scroll-middle.png"
	list.CanvasSize = UDim2.new(0, 0, 0, 0)
	list.MidImage = "rbxasset://textures/ui/Scroll/scroll-middle.png"
	list.ScrollBarThickness = 8
	list.TopImage = "rbxasset://textures/ui/Scroll/scroll-middle.png"
	list.VerticalScrollBarInset = "Always"
	list.ZIndex = 10
	themed(list, "scroll")

	local layout = inst("UIListLayout")
	layout.Parent = list

	local settingsButton = inst("ImageButton")
	settingsButton.Name = "SettingsButton"
	settingsButton.Parent = holder
	settingsButton.BackgroundTransparency = 1
	settingsButton.Position = UDim2.new(0, 230, 0, 0)
	settingsButton.Size = UDim2.new(0, 20, 0, 20)
	settingsButton.Image = Assets.get("infiniteyield/assets/settings.png")
	settingsButton.ZIndex = 10

	local referenceButton = inst("ImageButton")
	referenceButton.Name = "ReferenceButton"
	referenceButton.Parent = holder
	referenceButton.BackgroundTransparency = 1
	referenceButton.Position = UDim2.new(0, 212, 0, 2)
	referenceButton.Size = UDim2.new(0, 16, 0, 16)
	referenceButton.Image = Assets.get("infiniteyield/assets/reference.png")
	referenceButton.ZIndex = 10

	M.scaled          = scaled
	M.scale           = scale
	M.holder          = holder
	M.title           = title
	M.dark            = dark
	M.commandBar      = cmdbar
	M.commandList     = list
	M.commandListLayout = layout
	M.settingsButton  = settingsButton
	M.referenceButton = referenceButton
end

--[[ Legacy 462-642: the settings panel, its scrolling body, the two rows that
     belong to the shell itself, and the hidden template every command row is
     cloned from. The six icon rows are built by the panels that own them. ]]
local function buildSettings()
	local settings = inst("Frame")
	settings.Name = "Settings"
	settings.Parent = M.holder
	settings.Active = true
	settings.BackgroundColor3 = Color3.fromRGB(36, 36, 37)
	settings.BorderSizePixel = 0
	settings.Position = UDim2.new(0, 0, 0, 220)
	settings.Size = UDim2.new(0, 250, 0, 175)
	settings.ZIndex = 10
	themed(settings, "shade1")

	local holder = inst("ScrollingFrame")
	holder.Name = "Holder"
	holder.Parent = settings
	holder.BackgroundTransparency = 1
	holder.BorderSizePixel = 0
	holder.Size = UDim2.new(1, 0, 1, 0)
	holder.ScrollBarImageColor3 = Color3.fromRGB(78, 78, 79)
	holder.BottomImage = "rbxasset://textures/ui/Scroll/scroll-middle.png"
	holder.CanvasSize = UDim2.new(0, 0, 0, 235)
	holder.MidImage = "rbxasset://textures/ui/Scroll/scroll-middle.png"
	holder.ScrollBarThickness = 8
	holder.TopImage = "rbxasset://textures/ui/Scroll/scroll-middle.png"
	holder.VerticalScrollBarInset = "Always"
	holder.ZIndex = 10
	themed(holder, "scroll")

	local prefix = inst("TextLabel")
	prefix.Name = "Prefix"
	prefix.Parent = holder
	prefix.BackgroundColor3 = Color3.fromRGB(46, 46, 47)
	prefix.BorderSizePixel = 0
	prefix.BackgroundTransparency = 1
	prefix.Position = UDim2.new(0, 5, 0, 5)
	prefix.Size = UDim2.new(1, -10, 0, 20)
	prefix.Font = Enum.Font.SourceSans
	prefix.TextSize = 14
	prefix.Text = "Prefix"
	prefix.TextColor3 = Color3.new(1, 1, 1)
	prefix.TextXAlignment = Enum.TextXAlignment.Left
	prefix.ZIndex = 10
	themed(prefix, "shade2")
	themed(prefix, "text1")

	local prefixBox = inst("TextBox")
	prefixBox.Name = "PrefixBox"
	prefixBox.Parent = prefix
	prefixBox.BackgroundColor3 = Color3.fromRGB(78, 78, 79)
	prefixBox.BorderSizePixel = 0
	prefixBox.Position = UDim2.new(1, -20, 0, 0)
	prefixBox.Size = UDim2.new(0, 20, 0, 20)
	prefixBox.Font = Enum.Font.SourceSansBold
	prefixBox.TextSize = 14
	prefixBox.Text = ""
	prefixBox.TextColor3 = Color3.new(0, 0, 0)
	prefixBox.ZIndex = 10
	themed(prefixBox, "shade3")
	themed(prefixBox, "text2")

	local stayOpenLabel = inst("TextLabel")
	stayOpenLabel.Name = "StayOpen"
	stayOpenLabel.Parent = holder
	stayOpenLabel.BackgroundColor3 = Color3.fromRGB(46, 46, 47)
	stayOpenLabel.BorderSizePixel = 0
	stayOpenLabel.BackgroundTransparency = 1
	stayOpenLabel.Position = UDim2.new(0, 5, 0, 30)
	stayOpenLabel.Size = UDim2.new(1, -10, 0, 20)
	stayOpenLabel.Font = Enum.Font.SourceSans
	stayOpenLabel.TextSize = 14
	stayOpenLabel.Text = "Keep Menu Open"
	stayOpenLabel.TextColor3 = Color3.new(1, 1, 1)
	stayOpenLabel.TextXAlignment = Enum.TextXAlignment.Left
	stayOpenLabel.ZIndex = 10
	themed(stayOpenLabel, "shade2")
	themed(stayOpenLabel, "text1")

	local stayOpenButton = inst("Frame")
	stayOpenButton.Name = "Button"
	stayOpenButton.Parent = stayOpenLabel
	stayOpenButton.BackgroundColor3 = Color3.fromRGB(78, 78, 79)
	stayOpenButton.BorderSizePixel = 0
	stayOpenButton.Position = UDim2.new(1, -20, 0, 0)
	stayOpenButton.Size = UDim2.new(0, 20, 0, 20)
	stayOpenButton.ZIndex = 10
	themed(stayOpenButton, "shade3")

	-- The tick itself: BackgroundTransparency is the checkbox state, which is
	-- why it is never registered with the theme.
	local on = inst("TextButton")
	on.Name = "On"
	on.Parent = stayOpenButton
	on.BackgroundColor3 = Color3.fromRGB(150, 150, 151)
	on.BackgroundTransparency = 1
	on.BorderSizePixel = 0
	on.Position = UDim2.new(0, 2, 0, 2)
	on.Size = UDim2.new(0, 16, 0, 16)
	on.Font = Enum.Font.SourceSans
	on.FontSize = Enum.FontSize.Size14
	on.Text = ""
	on.TextColor3 = Color3.new(0, 0, 0)
	on.ZIndex = 10

	local template = inst("TextButton")
	template.Name = "Example"
	template.Parent = M.holder
	template.BackgroundTransparency = 1
	template.BorderSizePixel = 0
	template.Size = UDim2.new(0, 190, 0, 20)
	template.Visible = false
	template.Font = Enum.Font.SourceSans
	template.TextSize = 18
	template.Text = "Example"
	template.TextColor3 = Color3.new(1, 1, 1)
	template.TextXAlignment = Enum.TextXAlignment.Left
	template.ZIndex = 10
	themed(template, "text1")

	M.settings       = settings
	M.settingsHolder = holder
	M.prefixLabel    = prefix
	M.prefixBox      = prefixBox
	M.stayOpenLabel  = stayOpenLabel
	M.stayOpenToggle = on
	M.rowTemplate    = template
end

--[[ The icon + label row used by every settings panel. Legacy makeSettingsButton
     (518-554). `offset` crops a sprite sheet, which is how the plugin and event
     rows share one image. The caller sets Position, Size, Name and Parent. ]]
function M.makeSettingsRow(name, iconId, offset)
	if not bin then
		Guard.fail("the interface has not mounted yet")
	end
	local button = inst("TextButton")
	button.BackgroundColor3 = Color3.fromRGB(46, 46, 47)
	button.BorderSizePixel = 0
	button.Position = UDim2.new(0, 0, 0, 0)
	button.Size = UDim2.new(1, 0, 0, 25)
	button.Text = ""
	button.ZIndex = 10

	local icon = inst("ImageLabel")
	icon.Name = "Icon"
	icon.Parent = button
	icon.Position = UDim2.new(0, 5, 0, 5)
	icon.Size = UDim2.new(0, 16, 0, 16)
	icon.BackgroundTransparency = 1
	icon.Image = iconId or ""
	icon.ZIndex = 10
	if offset then
		icon.ScaleType = Enum.ScaleType.Crop
		icon.ImageRectSize = Vector2.new(16, 16)
		icon.ImageRectOffset = Vector2.new(offset, 0)
	end

	local label = inst("TextLabel")
	label.Name = "ButtonLabel"
	label.Parent = button
	label.BackgroundTransparency = 1
	label.Text = name
	label.Position = UDim2.new(0, 28, 0, 0)
	label.Size = UDim2.new(1, -28, 1, 0)
	label.Font = Enum.Font.SourceSans
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextSize = 14
	label.ZIndex = 10
	label.TextXAlignment = Enum.TextXAlignment.Left

	themed(button, "shade2")
	themed(label, "text1")
	return button
end

--[[ Legacy 644-709. Built here, driven by ui/notify. ]]
local function buildNotification()
	local frame = inst("Frame")
	frame.Name = Lib.randomName()
	frame.Parent = M.scaled
	frame.BackgroundColor3 = Color3.fromRGB(36, 36, 37)
	frame.BorderSizePixel = 0
	frame.Position = UDim2.new(1, -500, 1, 20)
	frame.Size = UDim2.new(0, 250, 0, 100)
	frame.ZIndex = 10
	themed(frame, "shade1")

	local title = inst("TextLabel")
	title.Name = "Title"
	title.Parent = frame
	title.BackgroundColor3 = Color3.fromRGB(46, 46, 47)
	title.BorderSizePixel = 0
	title.Size = UDim2.new(0, 250, 0, 20)
	title.Font = Enum.Font.SourceSans
	title.TextSize = 14
	title.Text = "Notification Title"
	title.TextColor3 = Color3.new(1, 1, 1)
	title.ZIndex = 10
	themed(title, "shade2")
	themed(title, "text1")

	local body = inst("TextLabel")
	body.Name = "Text"
	body.Parent = frame
	body.BackgroundTransparency = 1
	body.BorderSizePixel = 0
	body.Position = UDim2.new(0, 5, 0, 25)
	body.Size = UDim2.new(0, 240, 0, 75)
	body.Font = Enum.Font.SourceSans
	body.TextSize = 16
	body.Text = "Notification Text"
	body.TextColor3 = Color3.new(1, 1, 1)
	body.TextWrapped = true
	body.ZIndex = 10
	themed(body, "text1")

	local close = inst("TextButton")
	close.Name = "CloseButton"
	close.Parent = frame
	close.BackgroundTransparency = 1
	close.Position = UDim2.new(1, -20, 0, 0)
	close.Size = UDim2.new(0, 20, 0, 20)
	close.Text = ""
	close.ZIndex = 10

	local closeImage = inst("ImageLabel")
	closeImage.Parent = close
	closeImage.BackgroundColor3 = Color3.new(1, 1, 1)
	closeImage.BackgroundTransparency = 1
	closeImage.Position = UDim2.new(0, 5, 0, 5)
	closeImage.Size = UDim2.new(0, 10, 0, 10)
	closeImage.Image = Assets.get("infiniteyield/assets/close.png")
	closeImage.ZIndex = 10

	local pin = inst("TextButton")
	pin.Name = "PinButton"
	pin.Parent = frame
	pin.BackgroundTransparency = 1
	pin.Size = UDim2.new(0, 20, 0, 20)
	pin.ZIndex = 10
	pin.Text = ""

	local pinImage = inst("ImageLabel")
	pinImage.Parent = pin
	pinImage.BackgroundColor3 = Color3.new(1, 1, 1)
	pinImage.BackgroundTransparency = 1
	pinImage.Position = UDim2.new(0, 3, 0, 3)
	pinImage.Size = UDim2.new(0, 14, 0, 14)
	pinImage.ZIndex = 10
	pinImage.Image = Assets.get("infiniteyield/assets/pin.png")

	M.notification = {
		frame = frame,
		title = title,
		body  = body,
		close = close,
		pin   = pin,
	}
end

--[[ Legacy 711-750. Positioned by whoever is hovering something -- see moveTo. ]]
local function buildTooltip()
	local frame = inst("Frame")
	frame.Name = Lib.randomName()
	frame.Parent = M.scaled
	frame.Active = true
	frame.BackgroundColor3 = Color3.fromRGB(36, 36, 37)
	frame.BackgroundTransparency = 0.1
	frame.BorderSizePixel = 0
	frame.Size = UDim2.new(0, 200, 0, 96)
	frame.Visible = false
	frame.ZIndex = 10
	themed(frame, "shade1")

	local title = inst("TextLabel")
	title.Name = "Title"
	title.Parent = frame
	title.BackgroundColor3 = Color3.fromRGB(46, 46, 47)
	title.BackgroundTransparency = 0.1
	title.BorderSizePixel = 0
	title.Size = UDim2.new(0, 200, 0, 20)
	title.Font = Enum.Font.SourceSans
	title.TextSize = 14
	title.Text = ""
	title.TextColor3 = Color3.new(1, 1, 1)
	title.TextTransparency = 0.1
	title.ZIndex = 10
	themed(title, "shade2")
	themed(title, "text1")

	local body = inst("TextLabel")
	body.Name = "Description"
	body.Parent = frame
	body.BackgroundTransparency = 1
	body.BorderSizePixel = 0
	body.Size = UDim2.new(0, 180, 0, 72)
	body.Position = UDim2.new(0, 10, 0, 18)
	body.Font = Enum.Font.SourceSans
	body.TextSize = 16
	body.Text = ""
	body.TextColor3 = Color3.new(1, 1, 1)
	body.TextTransparency = 0.1
	body.TextWrapped = true
	body.ZIndex = 10
	themed(body, "text1")

	M.tooltip = {
		frame = frame,
		title = title,
		body  = body,
		--[[ The tooltip is a child of the inverse-scaled container but callers
		     position it from raw mouse pixels (legacy 4952-4966), so with a
		     guiScale other than 1 it landed nowhere near the pointer. Convert
		     here rather than in every caller. ]]
		moveTo = function(x, y)
			local factor = scaleValue()
			frame.Position = UDim2.new(0, x / factor, 0, y / factor)
			return frame.Position
		end,
	}
end

--[[ Legacy 752-781: the overlay the intro animation plays on. All three are
     destroyed once runIntro() finishes. ]]
local function buildIntro()
	local background = inst("Frame")
	background.Name = "IntroBackground"
	background.Parent = M.holder
	background.Active = true
	background.BackgroundColor3 = Color3.fromRGB(36, 36, 37)
	background.BorderSizePixel = 0
	background.Position = UDim2.new(0, 0, 0, 45)
	background.Size = UDim2.new(0, 250, 0, 175)
	background.ZIndex = 10

	local logo = inst("ImageLabel")
	logo.Name = "Logo"
	logo.Parent = M.holder
	logo.BackgroundTransparency = 1
	logo.BorderSizePixel = 0
	logo.Position = UDim2.new(0, 125, 0, 127)
	logo.Size = UDim2.new(0, 10, 0, 10)
	logo.Image = Assets.get("infiniteyield/assets/logo.png")
	logo.ImageTransparency = 0
	logo.ZIndex = 10

	local credits = inst("TextBox")
	credits.Name = "Credits"
	credits.Parent = M.holder
	credits.BackgroundTransparency = 1
	credits.BorderSizePixel = 0
	credits.Position = UDim2.new(0, 0, 0.9, 30)
	credits.Size = UDim2.new(0, 250, 0, 20)
	credits.Font = Enum.Font.SourceSansLight
	credits.FontSize = Enum.FontSize.Size14
	credits.Text = "Edge // Zwolf // Moon // Toon // Peyton // ATP"
	credits.TextColor3 = Color3.new(1, 1, 1)
	credits.ZIndex = 10

	introBackground, introLogo, introCredits = background, logo, credits
end

--[[ Legacy 13111-13136: the floating "IY" button that opens the command bar on
     a touch device. Lives in the host gui, not the scaled container, so it keeps
     its size whatever the guiScale is. ]]
local function buildMobileButton()
	if not Platform.isMobile then return end

	local button = inst("TextButton")
	button.Name = Lib.randomName()
	button.Parent = M.parent
	button.BackgroundColor3 = Color3.fromRGB(46, 46, 47)
	button.BackgroundTransparency = 0.14
	button.Position = UDim2.new(0.489, 0, 0, 0)
	button.Size = UDim2.new(0, 32, 0, 33)
	button.Font = Enum.Font.SourceSansBold
	button.Text = "IY"
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.TextSize = 20
	button.TextWrapped = true
	button.ZIndex = 10
	button.Draggable = true

	local corner = inst("UICorner")
	corner.Name = Lib.randomName()
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = button

	bin:connect(button.MouseButton1Click, function()
		M.focusCommandBar()
	end)

	themed(button, "shade1")
	themed(button, "text1")
	M.mobileButton = button
end

-- ═══ window states ══════════════════════════════════════════════════════════

--[[ Legacy 3220-3237. All three are no-ops while "Keep Menu Open" is ticked,
     which is what that setting means. ]]
function M.maximize()
	local holder = M.holder
	if not holder or stayOpen() then return false end
	holder:TweenPosition(UDim2.new(1, holder.Position.X.Offset, 1, -220),
		"InOut", "Quart", 0.2, true, nil)
	return true
end

function M.minimize()
	local holder = M.holder
	if not holder or stayOpen() then return false end
	holder:TweenPosition(UDim2.new(1, holder.Position.X.Offset, 1, minimizeNum),
		"InOut", "Quart", 0.5, true, nil)
	return true
end

function M.showCommandBar()
	local holder = M.holder
	if not holder or stayOpen() then return false end
	holder:TweenPosition(UDim2.new(1, holder.Position.X.Offset, 1, -45),
		"InOut", "Quart", 0.5, true, nil)
	return true
end

function M.settingsOpen()
	return settingsIsOpen
end

--[[ Legacy 3888-3896, plus the half-dozen commands that flipped the file-local
     themselves. Opening hides the command list, because both occupy the body. ]]
function M.setSettingsOpen(open)
	open = open == true
	if not M.settings then return false end
	if open == settingsIsOpen then return false end
	settingsIsOpen = open
	if open then
		M.settings:TweenPosition(UDim2.new(0, 0, 0, 45), "InOut", "Quart", 0.5, true, nil)
		M.commandList.Visible = false
	else
		M.commandList.Visible = true
		M.settings:TweenPosition(UDim2.new(0, 0, 0, 220), "InOut", "Quart", 0.5, true, nil)
	end
	return true
end

function M.isHidden()
	return hiddenState
end

--[[ `;hideiy` / `;showiy` (legacy 7870-7893). Hiding tucks the window fully off
     the bottom edge (minimizeNum 0 instead of -20) and forces "Keep Menu Open"
     off so it can actually move; showing puts the setting back. ]]
function M.setHidden(hide)
	hide = hide == true
	if not M.holder then return false end
	if hide then
		hiddenState = true
		wasStayOpen = stayOpen()
		if wasStayOpen then
			Store.set("stayOpen", false)
		end
		minimizeNum = 0
		M.minimize()
	else
		hiddenState = false
		minimizeNum = -20
		if wasStayOpen then
			-- Order matters: maximize() does nothing once the setting is back on.
			M.maximize()
			Store.set("stayOpen", true)
		else
			M.minimize()
		end
	end
	return true
end

--[[ Legacy 3396-3398 and 13130-13133. The RenderStepped wait belongs to the
     prefix-key path, so the keystroke that opened the bar does not land in it. ]]
function M.focusCommandBar()
	if not M.commandBar then return false end
	M.commandBar:CaptureFocus()
	M.maximize()
	return true
end

-- ═══ viewport clamping ══════════════════════════════════════════════════════

--[[ Legacy CamViewport (4246-4250), in the *scaled* container's units. The raw
     viewport width has to be divided by the UIScale, or on mobile the window is
     allowed to travel a scale-factor further than the screen. Returns math.huge
     when there is no camera (there is none for a frame after a respawn), which
     makes every clamp below a no-op instead of an error. ]]
local function viewportWidth()
	local camera = workspace.CurrentCamera
	if not camera then return math.huge end
	local ok, width = pcall(function() return camera.ViewportSize.X end)
	if not ok or type(width) ~= "number" or width <= 0 then return math.huge end
	return width / scaleValue()
end

--[[ Legacy UpdateToViewport (4252-4257): pull the window back on screen when the
     viewport shrinks under it. ]]
local function updateToViewport()
	local holder, notification = M.holder, M.notification
	if not holder or not notification then return end
	local width = viewportWidth()
	if width == math.huge then return end
	if holder.Position.X.Offset < -width then
		holder:TweenPosition(UDim2.new(1, -width, holder.Position.Y.Scale, holder.Position.Y.Offset),
			"InOut", "Quart", 0.04, true, nil)
		local frame = notification.frame
		frame:TweenPosition(UDim2.new(1, -width + 250, frame.Position.Y.Scale, frame.Position.Y.Offset),
			"InOut", "Quart", 0.04, true, nil)
	end
end

--[[ Legacy 4258-4269 kept two globals and reconnected them by hand. The camera
     is replaced on every respawn, so the connections live in their own branch
     that is emptied and rebuilt instead. Watching workspace.CurrentCamera as
     well as the old camera's ancestry is the one addition: a respawn swaps the
     camera without the outgoing one always changing ancestry first, which is why
     the legacy version silently stopped clamping after the first death. ]]
local watchCamera
function watchCamera()
	if not bin then return end
	if cameraBin then cameraBin:empty() else cameraBin = bin:branch("camera") end
	cameraBin:onChange(workspace, "CurrentCamera", watchCamera)
	local camera = workspace.CurrentCamera
	if not camera then
		cameraBin:add(Sched.after(0.5, watchCamera, "ui.chrome.camera"))
		return
	end
	cameraBin:onChange(camera, "ViewportSize", updateToViewport)
	cameraBin:connect(camera.AncestryChanged, function(_, parent)
		if parent ~= workspace then watchCamera() end
	end)
end

-- ═══ dragging the main window ═══════════════════════════════════════════════

--[[ Legacy dragMain (4271-4331): drag by the title bar, clamp to the right edge
     and to the viewport, and slide the notification to whichever side of the
     window still has room. Same tweens and same numbers; the only change is that
     the delta is divided by the UIScale, because Position offsets are in scaled
     units while input arrives in raw pixels. ]]
local function attachMainDrag()
	local holder = M.holder
	local notification = M.notification.frame
	local dragging = false
	local dragInput = nil
	local dragStart = Vector3.new(0, 0, 0)
	local startPos = holder.Position
	local ending = nil

	local function moveNotification(offsetScale, offset)
		TweenService:Create(notification, TweenInfo.new(.20), {
			Position = UDim2.new(offsetScale, offset,
				notification.Position.Y.Scale, notification.Position.Y.Offset),
		}):Play()
	end

	local function moveHolder(offsetScale, offset)
		TweenService:Create(holder, TweenInfo.new(.20), {
			Position = UDim2.new(offsetScale, offset,
				holder.Position.Y.Scale, holder.Position.Y.Offset),
		}):Play()
	end

	local function update(input)
		local delta = (input.Position - dragStart) / scaleValue()
		local target = startPos.X.Offset + delta.X
		local width = viewportWidth()

		-- Which side of the window the notification sits on.
		local pos
		if target <= -500 then
			moveNotification(1, -250)
			pos = 250
		else
			moveNotification(1, -500)
			pos = -250
		end

		if target <= -250 and -width <= target then
			moveHolder(startPos.X.Scale, target)
			moveNotification(startPos.X.Scale, target + pos)
		elseif target > -500 then
			moveHolder(1, -250)
		elseif -width > target then
			-- Legacy started a TweenPosition and a TweenService tween on the same
			-- property here; kept as it was.
			holder:TweenPosition(UDim2.new(1, -width, holder.Position.Y.Scale, holder.Position.Y.Offset),
				"InOut", "Quart", 0.04, true, nil)
			moveHolder(1, -width)
			moveNotification(1, -width + 250)
		end
	end

	bin:connect(M.title.InputBegan, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = holder.Position
			-- Replaced instead of stacked: legacy added one input.Changed
			-- handler per press and never disconnected any of them.
			if ending then ending:Disconnect() end
			ending = input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragging = false
				end
			end)
		end
	end)

	bin:connect(M.title.InputChanged, function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch then
			dragInput = input
		end
	end)

	bin:connect(Services.UserInputService.InputChanged, function(input)
		if input == dragInput and dragging then
			update(input)
		end
	end)

	bin:add(function()
		if ending then ending:Disconnect() ending = nil end
	end)
end

-- ═══ intro ══════════════════════════════════════════════════════════════════

--[[ Legacy 13396-13412: the logo grows, the credits slide in, everything fades,
     the three instances are destroyed and the window tucks itself away. Runs at
     most once; the destroy and the minimize happen even if a tween throws. ]]
function M.runIntro()
	if introRan or not bin then return false end
	if not (introBackground and introLogo and introCredits) then return false end
	introRan = true

	local background, logo, credits = introBackground, introLogo, introCredits
	bin:spawn(function()
		task.wait()
		pcall(function()
			credits:TweenPosition(UDim2.new(0, 0, 0.9, 0), "Out", "Quart", 0.2)
			logo:TweenSizeAndPosition(UDim2.new(0, 175, 0, 175), UDim2.new(0, 37, 0, 45),
				"Out", "Quart", 0.3)
			task.wait(1)
			local outInfo = TweenInfo.new(1.6809, Enum.EasingStyle.Sine, Enum.EasingDirection.Out, 0, false, 0)
			TweenService:Create(logo, outInfo, { ImageTransparency = 1 }):Play()
			TweenService:Create(background, outInfo, { BackgroundTransparency = 1 }):Play()
			credits:TweenPosition(UDim2.new(0, 0, 0.9, 30), "Out", "Quart", 0.2)
			task.wait(0.2)
		end)
		logo:Destroy()
		credits:Destroy()
		background:Destroy()
		introBackground, introLogo, introCredits = nil, nil, nil
		M.minimize()
	end)
	return true
end

-- ═══ scale ══════════════════════════════════════════════════════════════════

--[[ Legacy 13138 read `math.max(Holder.AbsoluteSize.X / 1920, guiScale)`. Holder
     is 250 wide, so that max was 250/1920 = 0.13 against guiScale and therefore
     always guiScale -- it was meant to be the viewport width. The setting is
     used directly. ]]
local function applyScale()
	local scale = M.scale
	if not scale then return end
	local value = Store.get("guiScale")
	if type(value) ~= "number" or value <= 0 then value = 1 end
	scale.Scale = value
end

--[[ Legacy 13140-13148. The container is sized 1/scale so the scaled space still
     covers the viewport, and every visible descendant is toggled off and on
     because Roblox does not re-lay-out text under a changed UIScale on its own. ]]
local function attachScale()
	local scale, scaled = M.scale, M.scaled
	applyScale()
	scale.Parent = scaled
	scaled.Size = UDim2.fromScale(1 / scaleValue(), 1 / scaleValue())
	bin:onChange(scale, "Scale", function()
		local factor = scaleValue()
		scaled.Size = UDim2.fromScale(1 / factor, 1 / factor)
		local descendants = scaled:GetDescendants()
		for i = 1, #descendants do
			local child = descendants[i]
			if child:IsA("GuiObject") and child.Visible then
				child.Visible = false
				child.Visible = true
			end
		end
	end)
	bin:add(Store.watch("guiScale", applyScale))
end

-- ═══ wiring ═════════════════════════════════════════════════════════════════

local function attachSettings()
	bin:connect(M.settingsButton.MouseButton1Click, function()
		M.setSettingsOpen(not settingsIsOpen)
	end)

	-- Legacy 3898-3909: the checkbox is inert while ;hideiy is in effect, because
	-- hiding forced the setting off and showing puts it back.
	bin:connect(M.stayOpenToggle.MouseButton1Click, function()
		if hiddenState then return end
		Store.set("stayOpen", not stayOpen())
	end)

	-- Legacy 3202-3206 set the tick once at load. Watching covers ;hideiy and
	-- anything else that writes the setting.
	bin:add(Store.watch("stayOpen", function(value)
		if M.stayOpenToggle then
			M.stayOpenToggle.BackgroundTransparency = value and 0 or 1
		end
	end))
end

local function attachPrefix()
	-- Legacy 4240-4244.
	bin:onChange(M.prefixBox, "Text", function()
		local text = M.prefixBox.Text
		if text == prefixKey then return end
		local ok, reason = Store.set("prefix", text)
		if not ok then
			-- A half-typed prefix ("" while retyping) is rejected by the schema.
			-- Keep the old one rather than notifying on every keystroke.
			log.debug("prefix '%s' rejected: %s", tostring(text), tostring(reason))
		end
	end)

	bin:add(Store.watch("prefix", function(value)
		prefixKey = value or ";"
		if M.prefixBox and M.prefixBox.Text ~= prefixKey then
			M.prefixBox.Text = prefixKey
		end
		if placeholderPrimed and M.commandBar then
			-- Legacy only ever set the placeholder from the PrefixBox.Text
			-- handler, which was connected *after* the initial assignment (3198
			-- vs 4240), so a fresh session showed the bare "Command Bar" until
			-- the prefix was changed. Kept that way.
			M.commandBar.PlaceholderText = "Command Bar (" .. prefixKey .. ")"
		end
		placeholderPrimed = true
	end))
end

--[[ Legacy 3394-3400. Mouse.KeyDown is deprecated but it is the only input path
     that reports the typed character rather than a KeyCode, so any prefix works
     on any keyboard layout. The RenderStepped wait keeps that keystroke out of
     the box it just opened. ]]
local function attachPrefixKey()
	if not mouse then return end
	bin:connect(mouse.KeyDown, function(key)
		if key == prefixKey then
			RunService.RenderStepped:Wait()
			M.focusCommandBar()
		end
	end)
end

--[[ Legacy 3402-3418: expand on hover, collapse a second after leaving unless
     the command bar has focus or the pointer came back. ]]
local function attachHover()
	bin:connect(M.holder.MouseEnter, function()
		lastMinimizeReq = 0
		M.maximize()
	end)

	bin:connect(M.holder.MouseLeave, function()
		if M.commandBar:IsFocused() then return end
		local requested = clock()
		lastMinimizeReq = requested
		task.wait(1)
		if lastMinimizeReq ~= requested then return end
		if not M.commandBar:IsFocused() then
			M.minimize()
		end
	end)
end

-- ═══ mount / unmount ════════════════════════════════════════════════════════

--[[ Build the shell. Idempotent: a second call returns the same table. ]]
function M.mount()
	if M.mounted then return M end
	if not Lib.host then
		Guard.fail("there is no host ScreenGui, so the interface cannot mount")
	end

	bin = Bin.new("ui/chrome")
	M.bin = bin
	M.parent = Lib.host
	mouse = Guard.try(function() return Players.LocalPlayer:GetMouse() end)

	buildWindow()
	buildSettings()
	buildNotification()
	buildTooltip()
	buildIntro()

	-- Legacy 2060: the command bar is a horizontally scrolling viewport, so the
	-- TextBox ends up inside a clipping frame that takes its place.
	M.commandBarView = Lib.viewportTextBox(M.commandBar, bin)
	M.commandBarView.View.ZIndex = 10

	buildMobileButton()
	attachScale()
	attachSettings()
	attachPrefix()
	attachPrefixKey()
	attachHover()
	attachMainDrag()
	watchCamera()

	-- Legacy 13151-13156: colour everything once it all exists.
	Theme.applyAll()

	M.mounted = true
	return M
end

--[[ Destroy everything mount() built. Idempotent. The host ScreenGui belongs to
     ui/lib, which drops it on unload -- and never drops it when it is CoreGui's
     own RobloxGui. ]]
function M.unmount()
	if not M.mounted then return false end
	M.mounted = false
	if bin then bin:destroy() end
	bin, M.bin = nil, nil
	cameraBin = nil
	introBackground, introLogo, introCredits = nil, nil, nil
	introRan = false
	settingsIsOpen = false
	hiddenState = false
	wasStayOpen = false
	minimizeNum = -20
	placeholderPrimed = false
	mouse = nil
	M.parent, M.scaled, M.scale, M.holder, M.title, M.dark =
		nil, nil, nil, nil, nil, nil
	M.commandBar, M.commandBarView, M.commandList, M.commandListLayout =
		nil, nil, nil, nil
	M.settings, M.settingsHolder, M.settingsButton, M.referenceButton =
		nil, nil, nil, nil
	M.prefixLabel, M.prefixBox, M.stayOpenLabel, M.stayOpenToggle =
		nil, nil, nil, nil
	M.rowTemplate, M.notification, M.tooltip, M.mobileButton =
		nil, nil, nil, nil
	return true
end

IY.onUnload(function()
	M.unmount()
end, "ui/chrome")

return M
