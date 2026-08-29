--[[═══════════════════════════════════════════════════════════════════════════
	features/fly · camera-relative flight
	─────────────────────────────────────────────────────────────────────────
	One feature, three modes, one set of state:

	    Fly.start{ speed = 2 }                  desktop / mobile, auto-detected
	    Fly.start{ vehicle = true }             keeps PlatformStand off so the
	                                            seat you are in comes with you
	    Fly.setSpeed(5)                         live, without restarting

	The flight math is deliberately identical to the legacy `sFLY`, so the feel
	does not change. What changed is the plumbing:

	  · one BodyGyro / BodyVelocity pair, owned by the bin. `invisfling` used to
	    call `sFLY()` without stopping the previous loop, leaving two loops
	    fighting over the same root part.
	  · the input connections live in the bin too, instead of the two module
	    globals `flyKeyDown`/`flyKeyUp` that leaked whenever the on-path was
	    entered twice.
	  · the mobile path no longer wraps its whole teardown in one pcall -- the
	    legacy version threw on the first `:Destroy()` after a respawn and so
	    never reached its `:Disconnect()` calls, leaving the render loop alive
	    forever with the flag already false.
	  · re-applies on respawn, which mobile fly never did (it re-parented the
	    new handlers to a stale root upvalue).
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Feature   = IY.import("features/feature")
local Services  = IY.import("core/services")
local Character = IY.import("core/character")
local Platform  = IY.import("core/platform")
local Guard     = IY.import("core/guard")
local Sched     = IY.import("core/scheduler")
local Str       = IY.import("core/util/strings")

local UserInputService = Services.UserInputService
local RunService       = Services.RunService

local M = {}

local BASE_SPEED = 50

local KEY_AXIS = {
	[Enum.KeyCode.W] = { axis = "F", sign = 1 },
	[Enum.KeyCode.S] = { axis = "B", sign = -1 },
	[Enum.KeyCode.A] = { axis = "L", sign = -1 },
	[Enum.KeyCode.D] = { axis = "R", sign = 1 },
	[Enum.KeyCode.E] = { axis = "Q", sign = 2, vertical = true },
	[Enum.KeyCode.Q] = { axis = "E", sign = -2, vertical = true },
}

-- ── desktop ─────────────────────────────────────────────────────────────────

local function startDesktop(self, opts)
	local root = Character.requireRoot()
	local humanoid = Character.humanoid()

	local control  = { F = 0, B = 0, L = 0, R = 0, Q = 0, E = 0 }
	local lastMove = { F = 0, B = 0, L = 0, R = 0 }
	local speed = 0
	self.state.control = control

	local gyro = self.bin:add(Instance.new("BodyGyro"))
	local velocity = self.bin:add(Instance.new("BodyVelocity"))
	gyro.P = 9e4
	gyro.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
	gyro.CFrame = root.CFrame
	gyro.Parent = root
	velocity.Velocity = Vector3.new(0, 0, 0)
	velocity.MaxForce = Vector3.new(9e9, 9e9, 9e9)
	velocity.Parent = root

	-- PlatformStand keeps the rig from fighting the velocity; vehicle mode
	-- leaves it alone so the seat weld survives.
	self.bin:add(function()
		local currentHumanoid = Character.humanoid()
		if currentHumanoid then pcall(function() currentHumanoid.PlatformStand = false end) end
		pcall(function() workspace.CurrentCamera.CameraType = Enum.CameraType.Custom end)
	end)

	local function multiplier()
		return self:option("speed", 1)
	end

	self.bin:connect(UserInputService.InputBegan, function(input, processed)
		if processed then return end
		local mapping = KEY_AXIS[input.KeyCode]
		if not mapping then return end
		if mapping.vertical and self:option("qe", true) == false then return end
		control[mapping.axis] = mapping.sign * multiplier()
	end)

	self.bin:connect(UserInputService.InputEnded, function(input, processed)
		if processed then return end
		local mapping = KEY_AXIS[input.KeyCode]
		if mapping then control[mapping.axis] = 0 end
	end)

	self.bin:add(Sched.frameLoop("fly.step", function()
		local camera = workspace.CurrentCamera
		if not camera then return end
		if not velocity.Parent then
			-- The root was destroyed under us (respawn mid-frame).
			return
		end

		local currentHumanoid = Character.humanoid()
		if currentHumanoid and not self:option("vehicle", false) then
			currentHumanoid.PlatformStand = true
		end

		local horizontal = control.L + control.R
		local forward    = control.F + control.B
		local vertical   = control.Q + control.E
		local moving = horizontal ~= 0 or forward ~= 0 or vertical ~= 0

		speed = moving and BASE_SPEED or 0

		local cameraFrame = camera.CFrame
		if moving then
			velocity.Velocity = ((cameraFrame.LookVector * forward)
				+ ((cameraFrame * CFrame.new(horizontal, (forward + vertical) * 0.2, 0).Position) - cameraFrame.Position))
				* BASE_SPEED
			lastMove.F, lastMove.B, lastMove.L, lastMove.R = control.F, control.B, control.L, control.R
		elseif speed ~= 0 then
			velocity.Velocity = ((cameraFrame.LookVector * (lastMove.F + lastMove.B))
				+ ((cameraFrame * CFrame.new(lastMove.L + lastMove.R, (lastMove.F + lastMove.B) * 0.2, 0).Position) - cameraFrame.Position))
				* BASE_SPEED
		else
			velocity.Velocity = Vector3.new(0, 0, 0)
		end
		gyro.CFrame = cameraFrame
	end, "heartbeat"))
end

-- ── mobile ──────────────────────────────────────────────────────────────────

local function startMobile(self, opts)
	local root = Character.requireRoot()
	local player = Character.player

	local velocityName = "IY_" .. Str.random(10)
	local gyroName     = "IY_" .. Str.random(10)
	local zero, infinite = Vector3.new(0, 0, 0), Vector3.new(9e9, 9e9, 9e9)

	local controlModule
	local ok = pcall(function()
		local scripts = player:WaitForChild("PlayerScripts", 5)
		local module = scripts and scripts:WaitForChild("PlayerModule", 5)
		local control = module and module:WaitForChild("ControlModule", 5)
		controlModule = control and require(control) or nil
	end)
	if not ok or not controlModule then
		Guard.fail("mobile fly needs the default control module, which this game replaced")
	end

	local velocity = self.bin:add(Instance.new("BodyVelocity"))
	velocity.Name = velocityName
	velocity.MaxForce = zero
	velocity.Velocity = zero
	velocity.Parent = root

	local gyro = self.bin:add(Instance.new("BodyGyro"))
	gyro.Name = gyroName
	gyro.MaxTorque = infinite
	gyro.P = 1000
	gyro.D = 50
	gyro.Parent = root

	self.bin:add(function()
		local currentHumanoid = Character.humanoid()
		if currentHumanoid then pcall(function() currentHumanoid.PlatformStand = false end) end
	end)

	self.bin:add(Sched.frameLoop("fly.mobile.step", function()
		local camera = workspace.CurrentCamera
		local currentHumanoid = Character.humanoid()
		if not camera or not currentHumanoid or not velocity.Parent or not gyro.Parent then return end

		velocity.MaxForce = infinite
		gyro.MaxTorque = infinite
		if not self:option("vehicle", false) then currentHumanoid.PlatformStand = true end
		gyro.CFrame = camera.CFrame

		local direction = controlModule:GetMoveVector()
		local scale = self:option("speed", 1) * BASE_SPEED
		local result = Vector3.new(0, 0, 0)
		if direction.X ~= 0 then result = result + camera.CFrame.RightVector * (direction.X * scale) end
		if direction.Z ~= 0 then result = result - camera.CFrame.LookVector * (direction.Z * scale) end
		velocity.Velocity = result
	end))
end

-- ── feature ─────────────────────────────────────────────────────────────────

local feature = Feature.new("fly", {
	command   = "fly",
	reapply   = true,
	exclusive = { "cframefly" },
	describe  = "flying",

	start = function(self, opts)
		if Platform.isMobile then
			return startMobile(self, opts)
		end
		return startDesktop(self, opts)
	end,
})

M.feature = feature

--[[ `speed` is a multiplier on the base 50 studs/s, matching iyflyspeed. ]]
function M.start(opts) return feature:start(opts or {}) end
function M.stop() return feature:stop() end
function M.toggle(opts) return feature:toggle(opts) end
function M.isRunning() return feature:isRunning() end

function M.setSpeed(speed)
	feature:configure({ speed = speed })
	return speed
end

function M.speed()
	return feature:option("speed", 1)
end

function M.setQE(enabled)
	feature:configure({ qe = enabled })
	return enabled
end

function M.isVehicle()
	return feature:option("vehicle", false) == true
end

return M
