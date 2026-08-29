--[[═══════════════════════════════════════════════════════════════════════════
	features/cframefly · anchored-head flight
	─────────────────────────────────────────────────────────────────────────
	Credit for the technique: peyton (apeyton).

	The legacy version left `CFloop` connected across respawns, so after one
	death it kept CFraming a destroyed Head while reading the new Humanoid, and
	`PlatformStand` was never cleared. `fixcam` also un-anchored the Head
	without stopping the loop, half-undoing it. Both are structural here: the
	loop, the anchor and the PlatformStand all live in the feature bin, and the
	feature re-arms on the new character instead of clinging to the old one.
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Feature   = IY.import("features/feature")
local Character = IY.import("core/character")
local Sched     = IY.import("core/scheduler")
local Inst      = IY.import("core/util/instances")

local M = {}

local feature = Feature.new("cframefly", {
	command   = "cframefly",
	reapply   = true,
	exclusive = { "fly" },
	describe  = "cframe flight",

	start = function(self, opts)
		local character = Character.require()
		local humanoid = Character.requireHumanoid()
		local head = Inst.waitFor(character, "Head", 5)
		if not head then
			local root = Character.requireRoot()
			head = root
		end

		humanoid.PlatformStand = true
		head.Anchored = true

		self.bin:add(function()
			if head and head.Parent then pcall(function() head.Anchored = false end) end
			local currentHumanoid = Character.humanoid()
			if currentHumanoid then pcall(function() currentHumanoid.PlatformStand = false end) end
		end)

		self.bin:add(Sched.frameLoop("cframefly.step", function(deltaTime)
			local currentHumanoid = Character.humanoid()
			local camera = workspace.CurrentCamera
			if not currentHumanoid or not camera or not head.Parent then return end

			local speed = self:option("speed", 50)
			local moveDirection = currentHumanoid.MoveDirection * (speed * (deltaTime or 1 / 60))
			local headFrame = head.CFrame
			local cameraFrame = camera.CFrame
			local offset = headFrame:ToObjectSpace(cameraFrame).Position
			cameraFrame = cameraFrame * CFrame.new(-offset.X, -offset.Y, -offset.Z + 1)
			local cameraPosition = cameraFrame.Position
			local headPosition = headFrame.Position

			local objectSpaceVelocity = CFrame.new(cameraPosition,
				Vector3.new(headPosition.X, cameraPosition.Y, headPosition.Z)):VectorToObjectSpace(moveDirection)
			head.CFrame = CFrame.new(headPosition) * (cameraFrame - cameraPosition) * CFrame.new(objectSpaceVelocity)
		end, "heartbeat"))
	end,
})

M.feature = feature

function M.start(opts) return feature:start(opts or {}) end
function M.stop() return feature:stop() end
function M.toggle(opts) return feature:toggle(opts) end
function M.isRunning() return feature:isRunning() end

function M.setSpeed(speed)
	feature:configure({ speed = speed })
	return speed
end

function M.speed()
	return feature:option("speed", 50)
end

return M
