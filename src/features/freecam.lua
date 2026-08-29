--[[═══════════════════════════════════════════════════════════════════════════
	features/freecam · a camera that detaches from your character
	─────────────────────────────────────────────────────────────────────────
	The flight model is the legacy one, unchanged: two springs (one for velocity,
	one for pan), WASD + QE to move, the arrow keys for the speed trim, LeftShift
	for the slow modifier, and a render step bound at camera priority so the
	default camera scripts cannot fight it.

	What changed is everything around it. The legacy version kept fourteen
	module-level globals -- `fcRunning`, `Camera`, `cameraPos`, `cameraRot`,
	`cameraFov`, `velSpring`, `panSpring`, `Spring`, `Input`, `keyboard`,
	`mouse`, `navSpeed`, `NAV_KEYBOARD_SPEED` and six `PlayerState` save slots --
	and three of the bugs that produced were ones users could feel:

	  · **the field of view was never given back.** `PlayerState.Push` saved it
	    and both `Pop` and `StopFreecam` then assigned a hard-coded 70, so anyone
	    who had run `;fov 40` lost it the first time they used freecam. The whole
	    push/pop goes through core/snapshot now, which hands back the value that
	    was actually there.
	  · **`;freecamspeed` was permanent.** It overwrote the module vector
	    `NAV_KEYBOARD_SPEED` while `Input.StopCapture` reset only `navSpeed`, so
	    the speed survived every later session with no way to see or undo it. The
	    speed is a feature option now, and the per-session trim resets with the
	    session.
	  · **nothing was owned.** The action bindings, the render step and the
	    CurrentCamera watcher were all global, so `;unloadiy` left a script
	    driving the camera. All three live in the feature bin.

	The legacy script bound no gamepad input at all (upstream Roblox freecam
	does); that is left as it was rather than invented here.

	Legacy equivalent: source.ref.lua lines 8326-8631.
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Feature   = IY.import("features/feature")
local Services  = IY.import("core/services")
local Character = IY.import("core/character")
local Snapshot  = IY.import("core/snapshot")
local Guard     = IY.import("core/guard")
local Camera    = IY.import("features/camera")

local UserInputService     = Services.UserInputService
local RunService           = Services.RunService
local ContextActionService = Services.get("ContextActionService")

local unpack = table.unpack or unpack

local M = {}

local TAG = "freecam"

--[[ Bound under our own names. A game that ships Roblox's freecam script already
     owns "Freecam" / "FreecamKeyboard" / "FreecamMousePan", which is exactly
     what the legacy script bound. Whatever name is used, the render step is
     unbound by the same one. ]]
local RENDER_STEP    = "IYFreecam"
local ACTION_KEYS    = "IYFreecamKeyboard"
local ACTION_MOUSE   = "IYFreecamMousePan"
local INPUT_PRIORITY = Enum.ContextActionPriority.High.Value

local PAN_SPEED     = Vector2.new(1, 1) * (math.pi / 64)
local NAV_ADJ_SPEED = 0.75
local NAV_SHIFT_MUL = 0.25
local BASE_SPEED    = 64        -- studs per second at trim 1
local FOCUS_RANGE   = 512
local MAX_FAILURES  = 5
local DEFAULT_SPEED = 1

local NAV_KEYS = {
	Enum.KeyCode.W, Enum.KeyCode.A, Enum.KeyCode.S, Enum.KeyCode.D,
	Enum.KeyCode.E, Enum.KeyCode.Q, Enum.KeyCode.Up, Enum.KeyCode.Down,
}

--[[ Camera properties freecam takes over. These four are recorded without being
     changed -- the render step writes them every frame anyway -- so that
     stopping hands back exactly what was there. ]]
local RECORDED = { "CFrame", "Focus", "FieldOfView", "CameraSubject" }

local function clamp(value, low, high)
	if value < low then return low end
	if value > high then return high end
	return value
end

-- ── spring ──────────────────────────────────────────────────────────────────

local Spring = {}
Spring.__index = Spring

function Spring.new(frequency, position)
	return setmetatable({ f = frequency, p = position, v = position * 0 }, Spring)
end

function Spring:Update(dt, goal)
	local f = self.f * 2 * math.pi
	local p0, v0 = self.p, self.v
	local offset = goal - p0
	local decay = math.exp(-f * dt)

	self.p = goal + (v0 * dt - offset * (f * dt + 1)) * decay
	self.v = (f * dt * (offset * f - v0) + v0) * decay
	return self.p
end

-- ── session state ───────────────────────────────────────────────────────────

--[[ One table per freecam session, replacing the module globals. Building it
     fresh on every start is what makes the speed trim (`navSpeed`) reset
     properly instead of leaking into the next session. ]]
local function newSession(camera, cframe)
	return {
		camera   = camera,
		keyboard = { W = 0, A = 0, S = 0, D = 0, E = 0, Q = 0, Up = 0, Down = 0 },
		mouse    = Vector2.new(0, 0),
		trim     = 1,
		position = cframe.Position,
		rotation = Vector2.new(0, 0),
		fov      = camera.FieldOfView,
		velocity = Spring.new(5, Vector3.new(0, 0, 0)),
		pan      = Spring.new(5, Vector2.new(0, 0)),
	}
end

-- ── focus distance ──────────────────────────────────────────────────────────

local rayParams

local function firstHit(origin, direction)
	if RaycastParams and not rayParams then rayParams = RaycastParams.new() end
	local result = workspace:Raycast(origin, direction, rayParams)
	if result then return result.Position end
	-- The legacy FindPartOnRay returned the end of the ray when it hit nothing.
	return origin + direction
end

--[[ Depth of the nearest geometry across a 3x3 grid of view rays, so Focus (and
     with it depth of field and streaming) tracks what you are looking at. Direct
     port of the legacy GetFocusDistance, including its degrees-into-math.tan
     mix-up: correcting it would narrow the sampling cone and change the look. ]]
local function focusDistance(camera, frame, fov)
	local viewport = camera.ViewportSize
	if not viewport or viewport.Y == 0 then return 0 end

	local near = 0.1
	local projectY = 2 * math.tan(fov / 2)
	local projectX = viewport.X / viewport.Y * projectY
	local right, up, look = frame.RightVector, frame.UpVector, frame.LookVector

	local closest = Vector3.new(0, 0, 0)
	local distance = FOCUS_RANGE

	for x = 0, 1, 0.5 do
		for y = 0, 1, 0.5 do
			local offset = right * ((x - 0.5) * projectX) - up * ((y - 0.5) * projectY) + look
			local origin = frame.Position + offset * near
			local hit = (firstHit(origin, offset.Unit * distance) - origin).Magnitude
			if distance > hit then
				distance = hit
				closest = offset.Unit
			end
		end
	end

	return look:Dot(closest) * distance
end

-- ── input ───────────────────────────────────────────────────────────────────

--[[ The arrow keys trim the speed between 0.01x and 4x, `;freecamspeed` scales
     the whole thing, and LeftShift is the slow modifier. The legacy version kept
     the `;freecamspeed` value in a module vector, so it stuck forever; here it
     is read from the feature's options every frame, which also means changing it
     mid-flight takes effect immediately. ]]
local function velocityGoal(self, session, dt)
	local keys = session.keyboard
	session.trim = clamp(session.trim + dt * (keys.Up - keys.Down) * NAV_ADJ_SPEED, 0.01, 4)

	local direction = Vector3.new(
		keys.D - keys.A,
		keys.E - keys.Q,
		keys.S - keys.W) * self:option("speed", DEFAULT_SPEED)

	local shift = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
	return direction * (session.trim * (shift and NAV_SHIFT_MUL or 1))
end

local function panGoal(session)
	local delta = session.mouse * PAN_SPEED
	session.mouse = Vector2.new(0, 0)
	return delta
end

local function startCapture(self, session)
	if not ContextActionService then
		Guard.fail("your client has no ContextActionService, so freecam cannot read input")
	end

	local function onKey(action, state, input)
		session.keyboard[input.KeyCode.Name] = (state == Enum.UserInputState.Begin) and 1 or 0
		return Enum.ContextActionResult.Sink
	end

	local function onMouse(action, state, input)
		local delta = input.Delta
		session.mouse = Vector2.new(-delta.Y, -delta.X)
		return Enum.ContextActionResult.Sink
	end

	ContextActionService:BindActionAtPriority(ACTION_KEYS, onKey, false, INPUT_PRIORITY, unpack(NAV_KEYS))
	ContextActionService:BindActionAtPriority(ACTION_MOUSE, onMouse, false, INPUT_PRIORITY,
		Enum.UserInputType.MouseMovement)

	self.bin:add(function()
		ContextActionService:UnbindAction(ACTION_KEYS)
		ContextActionService:UnbindAction(ACTION_MOUSE)
	end)
end

-- ── the step ────────────────────────────────────────────────────────────────

local function step(self, session, dt)
	local camera = session.camera
	if not camera or not camera.Parent then return end

	local velocity = session.velocity:Update(dt, velocityGoal(self, session, dt))
	local pan = session.pan:Update(dt, panGoal(session))

	-- Panning slows down as you zoom in, so a narrow field of view stays usable.
	local zoomFactor = math.sqrt(math.tan(math.rad(70 / 2)) / math.tan(math.rad(session.fov / 2)))
	local rotation = session.rotation + pan * Vector2.new(0.75, 1) * 8 * (dt / zoomFactor)
	session.rotation = Vector2.new(
		clamp(rotation.X, -math.rad(90), math.rad(90)),
		rotation.Y % (2 * math.pi))

	local frame = CFrame.new(session.position)
		* CFrame.fromOrientation(session.rotation.X, session.rotation.Y, 0)
		* CFrame.new(velocity * BASE_SPEED * dt)
	session.position = frame.Position

	camera.CFrame = frame
	camera.Focus = frame * CFrame.new(0, 0, -(Guard.try(focusDistance, camera, frame, session.fov) or 0))
	camera.FieldOfView = session.fov
end

local function bindRenderStep(self, session)
	local failures = 0

	--[[ Camera priority, not RenderStepped: the default camera scripts write the
	     CFrame at this priority too, and a step bound after them is the only way
	     to win that argument. ]]
	RunService:BindToRenderStep(RENDER_STEP, Enum.RenderPriority.Camera.Value, function(dt)
		if Guard.call("freecam.step", step, self, session, dt) then
			failures = 0
			return
		end
		failures = failures + 1
		if failures >= MAX_FAILURES then
			-- A camera that throws on every frame would log forever. Same
			-- watchdog core/scheduler applies to its own loops.
			self.log.warn("stopping after %d failed frames", failures)
			task.defer(function() self:stop() end)
		end
	end)

	self.bin:add(function() RunService:UnbindFromRenderStep(RENDER_STEP) end)
end

-- ── camera state (the legacy PlayerState) ───────────────────────────────────

local function push(session)
	local camera = session.camera
	--[[ Snapshot hands a record to whoever wrote first, so if `;fov` already owns
	     FieldOfView, restoring it on stop would give back the game's original
	     rather than the value the user had chosen before starting freecam. Note
	     that case and put our own entry value back instead. ]]
	session.ownsFov = not Snapshot.isModified(camera, "FieldOfView")
	session.entryFov = camera.FieldOfView

	for i = 1, #RECORDED do
		Snapshot.capture(camera, RECORDED[i], TAG)
	end
	Snapshot.set(camera, "CameraType", Enum.CameraType.Custom, TAG)
	Snapshot.set(UserInputService, "MouseIconEnabled", true, TAG)
	Snapshot.set(UserInputService, "MouseBehavior", Enum.MouseBehavior.Default, TAG)
end

local function pop(session)
	local camera = session.camera
	if camera then
		for i = 1, #RECORDED do
			local property = RECORDED[i]
			if property == "FieldOfView" and not session.ownsFov then
				pcall(function() camera.FieldOfView = session.entryFov end)
			else
				Snapshot.restore(camera, property)
			end
		end
		Snapshot.restore(camera, "CameraType")

		--[[ The recorded subject can be a humanoid that died while the camera was
		     detached, and handing that back leaves the camera stuck on a
		     destroyed model. ]]
		local subject = camera.CameraSubject
		if not subject or not subject.Parent then
			pcall(function() camera.CameraSubject = Character.humanoid() end)
		end
	end
	Snapshot.restore(UserInputService, "MouseIconEnabled")
	Snapshot.restore(UserInputService, "MouseBehavior")
end

-- ── feature ─────────────────────────────────────────────────────────────────

local feature = Feature.new("freecam", {
	command   = "freecam",
	exclusive = { "spectate" },
	describe  = "freecam",

	start = function(self, opts)
		local camera = Camera.require()
		--[[ Legacy behaviour: only the position of `opts.cframe` is used, and the
		     rotation always starts axis-aligned. ]]
		local session = newSession(camera, opts.cframe or camera.CFrame)
		self.state.session = session

		push(session)
		self.bin:add(function() pop(session) end)

		--[[ The engine can replace the camera under us (a respawn, or a game
		     resetting it). Move the recorded state across instead of driving one
		     that is no longer rendering -- the legacy version tracked this in a
		     global connection that outlived the session. ]]
		self.bin:onChange(workspace, "CurrentCamera", function()
			local replacement = Camera.get()
			if not replacement or replacement == session.camera then return end
			pop(session)
			session.camera = replacement
			push(session)
		end)

		startCapture(self, session)
		bindRenderStep(self, session)
	end,
})

M.feature = feature

--[[ `opts.cframe` starts the camera somewhere other than where it is now.
     `speed` carries over between sessions, because that is what the legacy
     module vector did -- the difference is that `;freecamspeed 1` now undoes it
     and the value is visible in the feature's options. ]]
function M.start(opts)
	opts = opts or {}
	if opts.speed == nil then opts.speed = feature:option("speed", DEFAULT_SPEED) end
	return feature:start(opts)
end

function M.stop() return feature:stop() end
function M.isRunning() return feature:isRunning() end

function M.toggle(opts)
	if feature:isRunning() then return feature:stop() end
	return M.start(opts)
end

function M.setSpeed(speed)
	feature:configure({ speed = speed })
	return speed
end

function M.speed()
	return feature:option("speed", DEFAULT_SPEED)
end

--[[ ;fov while freecam is running has to change freecam's own value: the render
     step writes FieldOfView every frame, so the legacy command was silently
     overwritten a frame later. Returns false when freecam is not running, which
     is the caller's cue to set the camera directly. ]]
function M.setFov(value)
	local session = feature:isRunning() and feature.state.session or nil
	if not session then return false end
	session.fov = value
	return true
end

--[[ Where the freecam is, or nil when it is not running. ]]
function M.position()
	local session = feature:isRunning() and feature.state.session or nil
	if not session then return nil end
	local camera = session.camera
	if camera and camera.Parent then return camera.CFrame.Position end
	return session.position
end

return M
