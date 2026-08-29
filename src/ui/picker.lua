--[[═══════════════════════════════════════════════════════════════════════════
	ui/picker · the colour picker window
	─────────────────────────────────────────────────────────────────────────
	Legacy source.ref.lua 3457-3885, plus the "Edit Theme" settings row it is
	opened from (556-560).

	The window itself is a Roblox model (rbxassetid://4908465318) fetched with
	game:GetObjects, so everything here is wiring: HSV/RGB inputs, the colour
	space and value strip, 48 basic swatches, 12 right-click-to-store custom
	swatches, and the six buttons that apply the chosen colour to a theme
	registry.

	Two legacy bugs are fixed:

	  · the model was fetched with an unguarded `game:GetObjects(...)[1]` *after*
	    `colorpickerOpen` had already been set to true, so a network failure left
	    the flag stuck and the Edit Theme button dead for the rest of the session.
	    The fetch is contained, reported, and only marks the window built when it
	    actually worked.
	  · Cancel restored `cache_current*`, which was only refreshed by the Edit
	    Theme button's own click handler. The colours are snapshotted in open()
	    now, so Cancel always undoes exactly this visit.

	The colour-space input also divides by the UIScale: the frame's hit maths is
	written against its unscaled 219x199 size, so on mobile (guiScale < 1) the
	pointer picked the wrong colour.
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Assets   = IY.import("ui/assets")
local Bin      = IY.import("core/bin")
local Chrome   = IY.import("ui/chrome")
local Guard    = IY.import("core/guard")
local Lib      = IY.import("ui/lib")
local Log      = IY.import("core/log")
local Notify   = IY.import("core/notify")
local Services = IY.import("core/services")
local Theme    = IY.import("ui/theme")

local log = Log.scope("ui/picker")

local Players          = Services.Players
local UserInputService = Services.UserInputService

local M = {}

M.model  = "rbxassetid://4908465318"
M.frame  = nil            -- the picker window itself
M.row    = nil            -- the "Edit Theme" settings row
M.built  = false
M.opened = false

local bin = Bin.new("ui/picker")
M.bin = bin

local snapshot = nil      -- the palette as it was when the window opened
local setColor = nil      -- controller: push a Color3 into the inputs
local build               -- forward declaration

local OPEN_POSITION   = UDim2.new(0.5, -219, 0, 100)
local CLOSED_POSITION = UDim2.new(0.5, -219, 0, -500)

-- ═══ the settings row ═══════════════════════════════════════════════════════

--[[ Legacy 556-560: the third row of the settings panel. ]]
function M.mount()
	-- A row whose Parent is gone was destroyed with a previous Chrome.unmount(),
	-- so rebuild rather than hand back a dead instance.
	if M.row and M.row.Parent then return M.row end
	if not Chrome.mounted then Chrome.mount() end

	local row = Chrome.makeSettingsRow("Edit Theme",
		Assets.get("infiniteyield/assets/edittheme.png"))
	row.Position = UDim2.new(0, 5, 0, 55)
	row.Size = UDim2.new(1, -10, 0, 25)
	row.Name = "Colors"
	row.Parent = Chrome.settingsHolder

	bin:connect(row.MouseButton1Click, function() M.open() end)

	M.row = row
	return row
end

-- ═══ open / close ═══════════════════════════════════════════════════════════

local function takeSnapshot()
	local out = {}
	for i = 1, #Theme.names do
		local name = Theme.names[i]
		out[name] = Theme.get(name)
	end
	return out
end

function M.isOpen()
	return M.opened
end

--[[ Snapshot, build on first use, slide in. ]]
function M.open()
	snapshot = takeSnapshot()

	if not M.built then
		local ok, err = Guard.call("ui/picker.build", build)
		if not ok or not M.built then
			-- A half-built window is wired to nothing: drop it so a retry starts
			-- clean instead of stacking a second copy on top.
			if M.frame then M.frame:Destroy() M.frame = nil end
			-- Stays closed and stays retryable, unlike the legacy version.
			Notify.error("Theme", "The colour picker could not be opened: "
				.. (ok and "the model was empty" or Guard.describe(err)))
			return false
		end
	end

	M.frame:TweenPosition(OPEN_POSITION, "InOut", "Quart", 0.5, true, nil)
	M.opened = true
	return true
end

--[[ Legacy 3842-3844: the X only slides the window away, it never destroys it. ]]
function M.close()
	if not M.frame then return false end
	M.frame:TweenPosition(CLOSED_POSITION, "InOut", "Quart", 0.5, true, nil)
	M.opened = false
	return true
end

function M.toggle()
	if M.opened then return M.close() end
	return M.open()
end

--[[ Legacy 3862-3871: undo this visit. ]]
function M.cancel()
	if not snapshot then return false end
	for i = 1, #Theme.names do
		local name = Theme.names[i]
		if snapshot[name] then Theme.set(name, snapshot[name]) end
	end
	return true
end

--[[ Legacy 3872-3881. ]]
function M.restoreDefaults()
	return Theme.setDefaults()
end

-- ═══ the window ═════════════════════════════════════════════════════════════

--[[ Legacy 3512: the classic 48-entry Windows palette, verbatim. ]]
local BASIC_COLORS = {
	Color3.new(0,0,0), Color3.new(0.66666668653488,0,0), Color3.new(0,0.33333334326744,0), Color3.new(0.66666668653488,0.33333334326744,0),
	Color3.new(0,0.66666668653488,0), Color3.new(0.66666668653488,0.66666668653488,0), Color3.new(0,1,0), Color3.new(0.66666668653488,1,0),
	Color3.new(0,0,0.49803924560547), Color3.new(0.66666668653488,0,0.49803924560547), Color3.new(0,0.33333334326744,0.49803924560547), Color3.new(0.66666668653488,0.33333334326744,0.49803924560547),
	Color3.new(0,0.66666668653488,0.49803924560547), Color3.new(0.66666668653488,0.66666668653488,0.49803924560547), Color3.new(0,1,0.49803924560547), Color3.new(0.66666668653488,1,0.49803924560547),
	Color3.new(0,0,1), Color3.new(0.66666668653488,0,1), Color3.new(0,0.33333334326744,1), Color3.new(0.66666668653488,0.33333334326744,1),
	Color3.new(0,0.66666668653488,1), Color3.new(0.66666668653488,0.66666668653488,1), Color3.new(0,1,1), Color3.new(0.66666668653488,1,1),
	Color3.new(0.33333334326744,0,0), Color3.new(1,0,0), Color3.new(0.33333334326744,0.33333334326744,0), Color3.new(1,0.33333334326744,0),
	Color3.new(0.33333334326744,0.66666668653488,0), Color3.new(1,0.66666668653488,0), Color3.new(0.33333334326744,1,0), Color3.new(1,1,0),
	Color3.new(0.33333334326744,0,0.49803924560547), Color3.new(1,0,0.49803924560547), Color3.new(0.33333334326744,0.33333334326744,0.49803924560547), Color3.new(1,0.33333334326744,0.49803924560547),
	Color3.new(0.33333334326744,0.66666668653488,0.49803924560547), Color3.new(1,0.66666668653488,0.49803924560547), Color3.new(0.33333334326744,1,0.49803924560547), Color3.new(1,1,0.49803924560547),
	Color3.new(0.33333334326744,0,1), Color3.new(1,0,1), Color3.new(0.33333334326744,0.33333334326744,1), Color3.new(1,0.33333334326744,1),
	Color3.new(0.33333334326744,0.66666668653488,1), Color3.new(1,0.66666668653488,1), Color3.new(0.33333334326744,1,1), Color3.new(1,1,1),
}

local function clock()
	if os and os.clock then return os.clock() end
	return tick()
end

local function clamp(value, low, high)
	if value < low then return low end
	if value > high then return high end
	return value
end

--[[ Resolve a child, or fail naming it: a truncated model used to surface as
     "attempt to index nil value". ]]
local function child(parent, name)
	local found = parent:FindFirstChild(name)
	if not found then
		Guard.fail("the colour picker model has no %s.%s", tostring(parent.Name), tostring(name))
	end
	return found
end

--[[ Fetch the model and wire every control. Legacy 3465-3858 (ColorPicker.new).
     Returns true once M.frame is on screen and live. ]]
function build()
	local objects = Guard.try(function() return game:GetObjects(M.model) end)
	local model = objects and objects[1]
	if not model then
		log.warn("game:GetObjects(%s) returned nothing", M.model)
		return false
	end

	model.Name = Lib.randomName()
	model.Parent = Chrome.scaled
	bin:add(model)
	M.frame = model

	local gui        = child(model, "ColorPicker")
	local topBar     = child(gui, "TopBar")
	local exitButton = child(topBar, "Exit")
	local content    = child(gui, "Content")
	local colorSpace = child(child(content, "ColorSpaceFrame"), "ColorSpace")
	local colorStrip = child(content, "ColorStrip")
	local preview    = child(content, "Preview")
	local basicFrame = child(content, "BasicColors")
	local customFrame = child(content, "CustomColors")
	local colorScope = child(colorSpace, "Scope")
	local colorArrow = child(child(content, "ArrowFrame"), "Arrow")

	local hueInput   = child(child(content, "Hue"), "Input")
	local satInput   = child(child(content, "Sat"), "Input")
	local valInput   = child(child(content, "Val"), "Input")
	local redInput   = child(child(content, "Red"), "Input")
	local greenInput = child(child(content, "Green"), "Input")
	local blueInput  = child(child(content, "Blue"), "Input")

	local mouse = Players.LocalPlayer:GetMouse()

	local hue, sat, val = 0, 0, 1
	local red, green, blue = 1, 1, 1
	local chosenColor = Color3.new(0, 0, 0)
	local customColors = {}

	bin:add(Lib.drag(model, model, Chrome.scale))

	--[[ Legacy 3517-3541. `noupdate` is 1 to leave the HSV boxes alone and 2 to
	     leave the RGB boxes alone, so editing one set does not fight the other. ]]
	local function updateColor(noupdate)
		local relativeX, relativeY, relativeStripY =
			219 - hue * 219, 199 - sat * 199, 199 - val * 199

		if noupdate == 2 or not noupdate then
			hueInput.Text = tostring(math.ceil(359 * hue))
			satInput.Text = tostring(math.ceil(255 * sat))
			valInput.Text = tostring(math.floor(255 * val))
		end
		if noupdate == 1 or not noupdate then
			redInput.Text = tostring(math.floor(255 * red))
			greenInput.Text = tostring(math.floor(255 * green))
			blueInput.Text = tostring(math.floor(255 * blue))
		end

		chosenColor = Color3.new(red, green, blue)

		colorScope.Position = UDim2.new(0, relativeX - 9, 0, relativeY - 9)
		colorStrip.ImageColor3 = Color3.fromHSV(hue, sat, 1)
		colorArrow.Position = UDim2.new(0, -2, 0, relativeStripY - 4)
		preview.BackgroundColor3 = chosenColor
		M.color = chosenColor
	end

	--[[ The hit maths below is written against the frame's unscaled 219x199 size,
	     but the mouse and AbsolutePosition are raw pixels -- so with a guiScale
	     other than 1 the pointer picked a colour it was not over. ]]
	local function unscale(value)
		return value / Lib.scaleFactor(Chrome.scale)
	end

	local function colorSpaceInput()
		local relativeX = clamp(unscale(mouse.X - colorSpace.AbsolutePosition.X), 0, 219)
		local relativeY = clamp(unscale(mouse.Y - colorSpace.AbsolutePosition.Y), 0, 199)

		hue = (219 - relativeX) / 219
		sat = (199 - relativeY) / 199

		local hsv = Color3.fromHSV(hue, sat, val)
		red, green, blue = hsv.R, hsv.G, hsv.B
		updateColor()
	end

	local function colorStripInput()
		local relativeY = clamp(unscale(mouse.Y - colorStrip.AbsolutePosition.Y), 0, 199)

		val = (199 - relativeY) / 199

		local hsv = Color3.fromHSV(hue, sat, val)
		red, green, blue = hsv.R, hsv.G, hsv.B
		updateColor()
	end

	--[[ Legacy 3646-3684: while the button is held, follow the mouse. One pair of
	     connections per control, replaced on the next press instead of a fresh
	     pair every time. ]]
	local function tracker(apply)
		local release, move = nil, nil
		local function stop()
			if release then release:Disconnect() release = nil end
			if move then move:Disconnect() move = nil end
		end
		bin:add(stop)
		return function(input)
			if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
			stop()
			release = UserInputService.InputEnded:Connect(function(ended)
				if ended.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
				stop()
			end)
			move = UserInputService.InputChanged:Connect(function(changed)
				if changed.UserInputType == Enum.UserInputType.MouseMovement then apply() end
			end)
			apply()
		end
	end

	bin:connect(colorSpace.InputBegan, tracker(colorSpaceInput))
	bin:connect(colorStrip.InputBegan, tracker(colorStripInput))

	--[[ Legacy hookButtons (3572-3644): the spinner arrows next to a number box.
	     One step on press, then repeat every 0.1s once held for 0.3s. ]]
	local function hookButtons(box, apply)
		local arrows = child(box, "ArrowFrame")

		local function hold(button, step)
			local release = nil
			bin:add(function()
				if release then release:Disconnect() release = nil end
			end)

			bin:connect(button.InputBegan, function(input)
				if input.UserInputType == Enum.UserInputType.MouseMovement then
					button.BackgroundTransparency = 0.5
				elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
					local value = tonumber(box.Text)
					if not value then return end
					local started = clock()
					local pressing = true

					if release then release:Disconnect() end
					release = UserInputService.InputEnded:Connect(function(ended)
						if ended.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
						pressing = false
					end)

					value = value + step
					apply(value)
					-- M.built guards the loop: unmounting mid-press must end it.
					while pressing and M.built do
						if clock() - started > 0.3 then
							value = value + step
							apply(value)
						end
						task.wait(0.1)
					end
				end
			end)

			bin:connect(button.InputEnded, function(input)
				if input.UserInputType == Enum.UserInputType.MouseMovement then
					button.BackgroundTransparency = 1
				end
			end)
		end

		hold(child(arrows, "Up"), 1)
		hold(child(arrows, "Down"), -1)
	end

	-- Legacy 3686-3756: the six number boxes.
	local function updateHue(str)
		local num = tonumber(str)
		if num then
			hue = clamp(math.floor(num), 0, 359) / 359
			local hsv = Color3.fromHSV(hue, sat, val)
			red, green, blue = hsv.R, hsv.G, hsv.B
			hueInput.Text = tostring(hue * 359)
			updateColor(1)
		end
	end
	bin:connect(hueInput.FocusLost, function() updateHue(hueInput.Text) end)
	hookButtons(hueInput, updateHue)

	local function updateSat(str)
		local num = tonumber(str)
		if num then
			sat = clamp(math.floor(num), 0, 255) / 255
			local hsv = Color3.fromHSV(hue, sat, val)
			red, green, blue = hsv.R, hsv.G, hsv.B
			satInput.Text = tostring(sat * 255)
			updateColor(1)
		end
	end
	bin:connect(satInput.FocusLost, function() updateSat(satInput.Text) end)
	hookButtons(satInput, updateSat)

	local function updateVal(str)
		local num = tonumber(str)
		if num then
			val = clamp(math.floor(num), 0, 255) / 255
			local hsv = Color3.fromHSV(hue, sat, val)
			red, green, blue = hsv.R, hsv.G, hsv.B
			valInput.Text = tostring(val * 255)
			updateColor(1)
		end
	end
	bin:connect(valInput.FocusLost, function() updateVal(valInput.Text) end)
	hookButtons(valInput, updateVal)

	local function updateRed(str)
		local num = tonumber(str)
		if num then
			red = clamp(math.floor(num), 0, 255) / 255
			hue, sat, val = Color3.toHSV(Color3.new(red, green, blue))
			redInput.Text = tostring(red * 255)
			updateColor(2)
		end
	end
	bin:connect(redInput.FocusLost, function() updateRed(redInput.Text) end)
	hookButtons(redInput, updateRed)

	local function updateGreen(str)
		local num = tonumber(str)
		if num then
			green = clamp(math.floor(num), 0, 255) / 255
			hue, sat, val = Color3.toHSV(Color3.new(red, green, blue))
			greenInput.Text = tostring(green * 255)
			updateColor(2)
		end
	end
	bin:connect(greenInput.FocusLost, function() updateGreen(greenInput.Text) end)
	hookButtons(greenInput, updateGreen)

	local function updateBlue(str)
		local num = tonumber(str)
		if num then
			blue = clamp(math.floor(num), 0, 255) / 255
			hue, sat, val = Color3.toHSV(Color3.new(red, green, blue))
			blueInput.Text = tostring(blue * 255)
			updateColor(2)
		end
	end
	bin:connect(blueInput.FocusLost, function() updateBlue(blueInput.Text) end)
	hookButtons(blueInput, updateBlue)

	-- Legacy 3758-3808: 48 fixed swatches, then 12 the user can right-click to
	-- overwrite with whatever is currently chosen.
	local template = Instance.new("TextButton")
	template.Name = "Choice"
	template.Size = UDim2.new(0, 25, 0, 18)
	template.BorderColor3 = Color3.new(96 / 255, 96 / 255, 96 / 255)
	template.Text = ""
	template.AutoButtonColor = false
	template.ZIndex = 10
	bin:add(template)

	local function pick(colour)
		red, green, blue = colour.R, colour.G, colour.B
		hue, sat, val = Color3.toHSV(colour)
		updateColor()
	end

	local row, column = 0, 0
	for i = 1, #BASIC_COLORS do
		local colour = BASIC_COLORS[i]
		local swatch = template:Clone()
		swatch.BackgroundColor3 = colour
		swatch.Position = UDim2.new(0, 1 + 30 * column, 0, 21 + 23 * row)
		bin:connect(swatch.MouseButton1Click, function() pick(colour) end)
		swatch.Parent = basicFrame
		column = column + 1
		if column == 6 then row = row + 1 column = 0 end
	end

	row, column = 0, 0
	for i = 1, 12 do
		local swatch = template:Clone()
		swatch.BackgroundColor3 = customColors[i] or Color3.new(0, 0, 0)
		swatch.Position = UDim2.new(0, 1 + 30 * column, 0, 20 + 23 * row)
		bin:connect(swatch.MouseButton1Click, function()
			pick(customColors[i] or Color3.new(0, 0, 0))
		end)
		bin:connect(swatch.MouseButton2Click, function()
			customColors[i] = chosenColor
			swatch.BackgroundColor3 = chosenColor
		end)
		swatch.Parent = customFrame
		column = column + 1
		if column == 6 then row = row + 1 column = 0 end
	end

	--[[ Legacy 3810-3840: each button dims while hovered. ]]
	local function hoverable(button, onClick)
		bin:connect(button.MouseButton1Click, onClick)
		bin:connect(button.InputBegan, function(input)
			if input.UserInputType == Enum.UserInputType.MouseMovement then
				button.BackgroundTransparency = 0.4
			end
		end)
		bin:connect(button.InputEnded, function(input)
			if input.UserInputType == Enum.UserInputType.MouseMovement then
				button.BackgroundTransparency = 0
			end
		end)
	end

	-- The six registry buttons. Legacy passed the registry table itself to
	-- updateColors; the registries have names now.
	local targets = {
		{ "Shade1", "shade1" }, { "Shade2", "shade2" }, { "Shade3", "shade3" },
		{ "Text1", "text1" }, { "Text2", "text2" }, { "Scroll", "scroll" },
	}
	for i = 1, #targets do
		local name = targets[i][2]
		hoverable(child(content, targets[i][1]), function()
			Theme.set(name, chosenColor)
		end)
	end

	hoverable(child(content, "Cancel"), function() M.cancel() end)
	hoverable(child(content, "Default"), function() M.restoreDefaults() end)

	bin:connect(exitButton.MouseButton1Click, function() M.close() end)

	updateColor()

	setColor = function(colour)
		red, green, blue = colour.R, colour.G, colour.B
		hue, sat, val = Color3.toHSV(colour)
		updateColor()
	end

	M.built = true
	return true
end

--[[ Legacy newMt:SetColor -- put a colour into the inputs without applying it. ]]
function M.setColor(colour)
	if not setColor or colour == nil then return false end
	setColor(colour)
	return true
end

function M.unmount()
	M.built = false
	M.opened = false
	bin:empty()
	M.frame, M.row, setColor, snapshot = nil, nil, nil, nil
	return true
end

IY.onUnload(function()
	M.unmount()
	bin:destroy()
end, "ui/picker")

return M
