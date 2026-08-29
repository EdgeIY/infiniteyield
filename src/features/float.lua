--[[═══════════════════════════════════════════════════════════════════════════
	features/float · stand on an invisible platform
	─────────────────────────────────────────────────────────────────────────
	The legacy `float` regenerated its random part name *before* the
	"already floating?" guard, so the guard never fired: every invocation added
	another part plus four connections, and the previous loop -- reading the now
	overwritten global name -- kept driving an orphaned part. `togglefloat` made
	that trivially reachable. `unfloat` then indexed the character with a nil
	name and threw if you had never floated.

	One part, one loop, one bin. The platform registers itself as exempt from
	noclip, which is what the legacy `child.Name ~= floatName` check in the
	noclip loop was doing through a shared global.
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Feature   = IY.import("features/feature")
local Character = IY.import("core/character")
local Services  = IY.import("core/services")
local Sched     = IY.import("core/scheduler")
local Noclip    = IY.import("features/noclip")
local Str       = IY.import("core/util/strings")

local UserInputService = Services.UserInputService

local M = {}

local feature = Feature.new("float", {
	command  = "float",
	reapply  = true,
	describe = "floating platform",

	start = function(self)
		local character = Character.require()
		local root = Character.requireRoot()

		local height = self:option("height", -3.1)
		local offset = 0

		local platform = self.bin:add(Instance.new("Part"))
		platform.Name = "IY_" .. Str.random(10)
		platform.Transparency = 1
		platform.Size = Vector3.new(2, 0.2, 1.5)
		platform.Anchored = true
		platform.CanCollide = true
		platform.Parent = character
		Noclip.exempt(platform)
		self.bin:add(function() Noclip.unexempt(platform) end)

		self.state.platform = platform

		self.bin:connect(UserInputService.InputBegan, function(key, processed)
			if processed then return end
			if key.KeyCode == Enum.KeyCode.Q then offset = offset - 0.5 end
			if key.KeyCode == Enum.KeyCode.E then offset = offset + 1.5 end
		end)

		self.bin:connect(UserInputService.InputEnded, function(key, processed)
			if processed then return end
			if key.KeyCode == Enum.KeyCode.Q then offset = offset + 0.5 end
			if key.KeyCode == Enum.KeyCode.E then offset = offset - 1.5 end
		end)

		self.bin:add(Sched.frameLoop("float.step", function()
			local currentRoot = Character.root()
			if not currentRoot or not platform.Parent then return end
			platform.CFrame = currentRoot.CFrame * CFrame.new(0, height + offset, 0)
		end, "stepped"))
	end,
})

M.feature = feature

function M.start(opts) return feature:start(opts or {}) end
function M.stop() return feature:stop() end
function M.toggle(opts) return feature:toggle(opts) end
function M.isRunning() return feature:isRunning() end

return M
