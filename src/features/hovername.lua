--[[═══════════════════════════════════════════════════════════════════════════
	features/hovername · name the character under your cursor
	─────────────────────────────────────────────────────────────────────────
	Legacy source.ref.lua 12283-12347. One label, one SelectionBox, one
	Mouse.Move handler, all three in the bin.

	The legacy `hovername` opened by running `unhovername` through the command
	dispatcher and then waiting a frame, so on a second invocation the teardown
	could land *after* the new connection had overwritten the global
	`nbUpdateFunc`: the fresh label and selection box were destroyed, the old
	handler stayed connected, and it threw on every mouse movement from then on.
	Feature:start stops first, on this thread, so there is only ever one.

	Two smaller fixes: the hover test indexed `target.Parent.Parent` unguarded
	(12309), which threw for any part parented straight into workspace; and the
	SelectionBox was re-parented into the hovered model, so it was destroyed
	along with any model that despawned while hovered and the next mouse move
	then assigned Parent on a destroyed instance. Only `Adornee` moves now --
	SelectionBox renders from that, so the result looks the same.
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Feature   = IY.import("features/feature")
local Highlight = IY.import("features/highlight")
local Services  = IY.import("core/services")
local Guard     = IY.import("core/guard")
local Inst      = IY.import("core/util/instances")
local Str       = IY.import("core/util/strings")

local Players = Services.Players

local M = {}

--[[ The character model a hovered part belongs to, or nil. ]]
local function modelOf(part)
	if not part then return nil end
	local parent = part.Parent
	if not parent then return nil end
	local humanoid = parent:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		local grandparent = parent.Parent
		humanoid = grandparent and grandparent:FindFirstChildOfClass("Humanoid") or nil
	end
	if not humanoid then return nil end
	return humanoid.Parent
end

local feature = Feature.new("hovername", {
	command  = "hovername",
	describe = "names on hover",

	start = function(self)
		local player = Players.LocalPlayer
		local mouse = player and player:GetMouse()
		if not mouse then Guard.fail("this client has no mouse") end

		local host = Highlight.host()

		local screen = self.bin:add(Instance.new("ScreenGui"))
		screen.Name = "IY_" .. Str.random(10)
		screen.ResetOnSpawn = false
		screen.DisplayOrder = 10
		screen.Parent = host
		Inst.protect(screen)

		local label = Instance.new("TextLabel")
		label.Name = Str.random(10)
		label.BackgroundTransparency = 1
		label.Size = UDim2.new(0, 200, 0, 30)
		label.Font = Enum.Font.Code
		label.TextSize = 16
		label.Text = ""
		label.TextColor3 = Color3.new(1, 1, 1)
		label.TextStrokeTransparency = 0
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.ZIndex = 10
		label.Visible = false
		label.Parent = screen

		local selection = self.bin:add(Instance.new("SelectionBox"))
		selection.Name = Str.random(10)
		selection.LineThickness = 0.03
		selection.Color3 = Color3.new(1, 1, 1)
		selection.Parent = host

		self.bin:connect(mouse.Move, function()
			local model = modelOf(mouse.Target)
			if not model then
				label.Visible = false
				selection.Adornee = nil
				return
			end
			local x, y = mouse.X, mouse.Y
			if x > 200 then
				label.TextXAlignment = Enum.TextXAlignment.Right
				label.Position = UDim2.new(0, x - 205, 0, y)
			else
				label.TextXAlignment = Enum.TextXAlignment.Left
				label.Position = UDim2.new(0, x + 25, 0, y)
			end
			label.Text = model.Name
			label.Visible = true
			selection.Adornee = model
		end)
	end,
})

M.feature = feature

function M.start(opts) return feature:start(opts or {}) end
function M.stop() return feature:stop() end
function M.toggle(opts) return feature:toggle(opts or {}) end
function M.isRunning() return feature:isRunning() end

return M
