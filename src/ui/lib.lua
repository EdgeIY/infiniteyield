--[[═══════════════════════════════════════════════════════════════════════════
	ui/lib · the interface primitives
	─────────────────────────────────────────────────────────────────────────
	Legacy source.ref.lua 306-333 (the host ScreenGui), 1969-1984 (`create`),
	1986-2058 (`ViewportTextBox`) and 2206-2241 (`dragGUI`).

	    Lib.host                     the ScreenGui everything lives under
	    Lib.hostKind                 which of the five strategies produced it
	    Lib.create(data)             the declarative two-pass instance builder
	    Lib.viewportTextBox(box)     single-line horizontally scrolling TextBox
	    Lib.drag(gui, handle, scale) tween-based window dragging

	`drag` is the one behavioural fix in here: the legacy version connected
	`UserInputService.InputChanged` once per draggable window -- eight times
	before the script had finished loading -- and never disconnected any of them.
	There is now a single shared connection, owned by this module's bin, plus a
	per-window bin the caller can stop on its own.
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Bin      = IY.import("core/bin")
local Env      = IY.import("core/env")
local Guard    = IY.import("core/guard")
local Log      = IY.import("core/log")
local Services = IY.import("core/services")
local Str      = IY.import("core/util/strings")
local Theme    = IY.import("ui/theme")

local log = Log.scope("ui/lib")

local Players          = Services.Players
local TextService      = Services.TextService
local TweenService     = Services.TweenService
local UserInputService = Services.UserInputService

local M = {}

local bin = Bin.new("ui/lib")
M.bin = bin

--[[ Legacy randomString(): 10 to 20 characters, so a CoreGui scanner cannot
     fingerprint the interface by instance name. ]]
function M.randomName()
	return Str.random(math.random(10, 20))
end

-- ═══ host ScreenGui ═════════════════════════════════════════════════════════

local MAX_DISPLAY_ORDER = 1.7976931348623157e308

local function newScreenGui()
	local gui = Instance.new("ScreenGui")
	gui.Name = M.randomName()
	gui.ResetOnSpawn = false
	-- DisplayOrder is a 32-bit int and the legacy script assigned the largest
	-- double there is, relying on the engine to clamp. Guarded, with a real
	-- int32 as the second attempt, because a client that rejects the value must
	-- not take the whole interface with it.
	if not Guard.try(function() gui.DisplayOrder = MAX_DISPLAY_ORDER return true end) then
		Guard.try(function() gui.DisplayOrder = 2147483647 end)
	end
	return gui
end

--[[ syn.protect_gui is nested, so core/env's flat lookup does not find it.
     SirHurt is excluded exactly as the legacy code did it. ]]
local function findProtect()
	if Env.lookup("is_sirhurt_closure") ~= nil then return nil end
	if Env.fn.protectgui then return Env.fn.protectgui end
	local syn = Env.lookup("syn")
	if type(syn) == "table" then
		local ok, fn = pcall(function() return syn.protect_gui end)
		if ok and type(fn) == "function" then return fn end
	end
	return nil
end

local function findPlayerGui()
	local player = Players.LocalPlayer
	if not player then return nil end
	local gui = player:FindFirstChildWhichIsA("PlayerGui")
	if not gui then return nil end
	local cloneref = Env.fn.cloneref
	if cloneref then
		local ok, cloned = pcall(cloneref, gui)
		if ok and cloned then return cloned end
	end
	return gui
end

--[[ Returns gui, kind, owned. `owned` is false only for RobloxGui, which we
     borrow and must never destroy on unload. ]]
local function chooseHost()
	local hidden = Env.lookup("gethui") or Env.lookup("get_hidden_gui")
	if type(hidden) == "function" then
		local ok, parent = pcall(hidden)
		if ok and parent then
			local gui = newScreenGui()
			gui.Parent = parent
			return gui, "gethui", true
		end
	end

	local core = Services.get("CoreGui")

	local protect = findProtect()
	if protect and core then
		local gui = newScreenGui()
		pcall(protect, gui)
		gui.Parent = core
		return gui, "protectgui", true
	end

	if core then
		local robloxGui = core:FindFirstChild("RobloxGui")
		if robloxGui then
			return robloxGui, "robloxgui", false
		end
		local gui = newScreenGui()
		gui.Parent = core
		return gui, "coregui", true
	end

	-- No CoreGui at all (no executor, or a locked-down client): the PlayerGui
	-- still works, it just does not survive some teleports.
	local playerGui = findPlayerGui()
	if playerGui then
		local gui = newScreenGui()
		gui.Parent = playerGui
		return gui, "playergui", true
	end

	return nil, "none", false
end

M.host      = nil
M.hostKind  = "none"
M.hostOwned = false

do
	local ok, gui, kind, owned = Guard.call("ui/lib.host", chooseHost)
	if ok and gui then
		M.host, M.hostKind, M.hostOwned = gui, kind, owned
		if owned then bin:add(gui) end
	else
		log.error("could not create a host ScreenGui -- the interface cannot mount")
	end
end

-- ═══ create ═════════════════════════════════════════════════════════════════

--[[ Declarative instance tree. Two passes so a property can reference another
     entry by key: {1, "Frame", {Parent = ...}}, {"body", "TextLabel", {Parent = {1}}}.
     Returns entry 1. Verbatim from legacy 1969-1984. ]]
function M.create(data)
	local insts = {}
	for _, v in pairs(data) do insts[v[1]] = Instance.new(v[2]) end

	for _, v in pairs(data) do
		for prop, val in pairs(v[3]) do
			if type(val) == "table" then
				insts[v[1]][prop] = insts[val[1]]
			else
				insts[v[1]][prop] = val
			end
		end
	end

	return insts[1]
end

-- ═══ ViewportTextBox ════════════════════════════════════════════════════════

local ViewportTextBox = {}
ViewportTextBox.__index = ViewportTextBox

--[[ Slide the TextBox inside its clipping frame so the caret stays visible.
     Verbatim from legacy 1989-2015. ]]
function ViewportTextBox:Update()
	local box = self.TextBox
	local cursorPos = box.CursorPosition
	local text = box.Text
	if text == "" then box.Position = UDim2.new(0, 2, 0, 0) return end
	if cursorPos == -1 then return end

	local cursorText = string.sub(text, 1, cursorPos - 1)
	local pos = nil
	local leftEnd = -box.Position.X.Offset
	local rightEnd = leftEnd + self.View.AbsoluteSize.X

	local totalTextSize = TextService:GetTextSize(text, box.TextSize, box.Font, Vector2.new(999999999, 100)).X
	local cursorTextSize = TextService:GetTextSize(cursorText, box.TextSize, box.Font, Vector2.new(999999999, 100)).X

	if cursorTextSize > rightEnd then
		pos = math.max(-2, cursorTextSize - self.View.AbsoluteSize.X + 2)
	elseif cursorTextSize < leftEnd then
		pos = math.max(-2, cursorTextSize - 2)
	elseif totalTextSize < rightEnd then
		pos = math.max(-2, totalTextSize - self.View.AbsoluteSize.X + 2)
	end

	if pos then
		box.Position = UDim2.new(0, -pos, 0, 0)
		box.Size = UDim2.new(1, pos, 1, 0)
	end
end
ViewportTextBox.update = ViewportTextBox.Update

--[[ Wrap `textbox` in a clipping frame that takes its place in the tree. The
     renaming and re-parenting are exactly as they were: the frame inherits the
     TextBox's name, the TextBox becomes "Input", and `textbox.Parent` is the
     frame afterwards -- callers rely on that. ]]
function M.viewportTextBox(textbox, ownerBin)
	local obj = setmetatable({ OffsetX = 0, TextBox = textbox }, ViewportTextBox)

	local view = Instance.new("Frame")
	view.BackgroundTransparency = textbox.BackgroundTransparency
	view.BackgroundColor3 = textbox.BackgroundColor3
	view.BorderSizePixel = textbox.BorderSizePixel
	view.BorderColor3 = textbox.BorderColor3
	view.Position = textbox.Position
	view.Size = textbox.Size
	view.ClipsDescendants = true
	view.Name = textbox.Name
	view.ZIndex = 10
	textbox.BackgroundTransparency = 1
	textbox.Position = UDim2.new(0, 4, 0, 0)
	textbox.Size = UDim2.new(1, -8, 1, 0)
	textbox.TextXAlignment = Enum.TextXAlignment.Left
	textbox.Name = "Input"
	Theme.register(textbox, "text1")
	Theme.register(view, "shade2")

	obj.View = view

	local owner = ownerBin or bin
	owner:connect(textbox.Changed, function(prop)
		if prop == "Text" or prop == "CursorPosition" or prop == "AbsoluteSize" then
			obj:Update()
		end
	end)
	owner:add(function()
		Theme.unregister(textbox)
		Theme.unregister(view)
	end)

	obj:Update()

	view.Parent = textbox.Parent
	textbox.Parent = view

	return obj
end

-- ═══ dragging ═══════════════════════════════════════════════════════════════

local active = {}          -- every live drag state
local shared = nil         -- the one UserInputService.InputChanged connection

--[[ `scale` may be a UIScale, a number, or nil. Windows parented to the
     inverse-scaled container measure their Position in scaled units while input
     arrives in raw pixels, so the delta has to be divided by the scale or the
     window moves faster than the pointer. ]]
local function scaleFactor(scale)
	if scale == nil then return 1 end
	if type(scale) == "number" then
		if scale <= 0 then return 1 end
		return scale
	end
	local ok, value = pcall(function() return scale.Scale end)
	if ok and type(value) == "number" and value > 0 then return value end
	return 1
end
M.scaleFactor = scaleFactor

local function ensureShared()
	if shared then return end
	shared = bin:connect(UserInputService.InputChanged, function(input)
		for i = 1, #active do
			local state = active[i]
			if state.dragging and state.dragInput == input then
				state.update(input)
			end
		end
	end)
end

--[[ Drag `gui` by `handle` (defaults to `gui` itself, as the legacy dragGUI
     did). Returns the bin holding the window's own connections. ]]
function M.drag(gui, handle, scale)
	handle = handle or gui
	local dragBin = bin:branch("drag")
	local state = {
		dragging  = false,
		dragInput = nil,
		start     = Vector3.new(0, 0, 0),
		origin    = gui.Position,
	}

	function state.update(input)
		local delta = (input.Position - state.start) / scaleFactor(scale)
		local position = UDim2.new(
			state.origin.X.Scale, state.origin.X.Offset + delta.X,
			state.origin.Y.Scale, state.origin.Y.Offset + delta.Y)
		TweenService:Create(gui, TweenInfo.new(.20), { Position = position }):Play()
	end

	dragBin:connect(handle.InputBegan, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			state.dragging = true
			state.start = input.Position
			state.origin = gui.Position
			-- One connection per drag press, replaced rather than stacked: the
			-- legacy version added a new input.Changed handler every time.
			if state.ending then state.ending:Disconnect() end
			state.ending = input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					state.dragging = false
				end
			end)
		end
	end)

	dragBin:connect(handle.InputChanged, function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch then
			state.dragInput = input
		end
	end)

	active[#active + 1] = state
	ensureShared()

	dragBin:add(function()
		for i = #active, 1, -1 do
			if active[i] == state then table.remove(active, i) end
		end
		if state.ending then state.ending:Disconnect() state.ending = nil end
	end)

	return dragBin
end

function M.dragCount()
	return #active
end

IY.onUnload(function()
	bin:destroy()
	active = {}
	shared = nil
end, "ui/lib")

return M
