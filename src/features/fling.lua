--[[═══════════════════════════════════════════════════════════════════════════
	features/fling · the four fling techniques
	─────────────────────────────────────────────────────────────────────────
	`fling`, `walkfling`, `flyfling` and `invisfling` are four separate features
	in one file because they share the same three ingredients: noclip, a body
	mover on the root part, and a loop that slams a velocity the server
	replicates before it can correct it.

	What changed from the legacy versions:

	  · `fling`, `walkfling` and `flyfling` all drove noclip through the command
	    dispatcher (`execCmd('noclip nonotify')` / `execCmd('clip nonotify')` at
	    11786, 11813, 11863, 11894). That command yielded 0.1s in the middle of
	    the operation, so interleaved fling/unfling calls let the off-path clear
	    noclip's restore table while the on-path was still filling it -- which is
	    what left parts permanently non-collidable. features/noclip is called
	    directly now, with no dispatcher round trip and no yield.
	  · `unfling` guessed the original physics back, writing
	    `PhysicalProperties.new(0.7, 0.3, 0.5)` and `Massless = false` to every
	    part (11821), so any game with its own densities lost them. Both go
	    through core/snapshot, tag "fling".
	  · `toggleflyfling` tested `flinging` -- plain fling's flag -- while
	    `flyfling` was built out of `walkfling`, whose flag was `walkflinging`
	    (11850), so the toggle was wrong in both directions. `flyfling` is its
	    own feature and the generated `;toggleflyfling` reads its own state.
	  · `invisfling` called `sFLY()` directly (11942) without stopping the fly
	    loop already running, so two loops fought over one root part. It goes
	    through features/fly.
	  · every loop was `repeat ... until <module global>` on the command thread,
	    so `;breakloops` could not reach them and `;unloadiy` left them running.

	Legacy equivalent: source.ref.lua 11779-11948.
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Feature   = IY.import("features/feature")
local Character = IY.import("core/character")
local Services  = IY.import("core/services")
local Snapshot  = IY.import("core/snapshot")
local Sched     = IY.import("core/scheduler")
local Guard     = IY.import("core/guard")
local Inst      = IY.import("core/util/instances")
local Str       = IY.import("core/util/strings")
local Noclip    = IY.import("features/noclip")
local Fly       = IY.import("features/fly")
local States    = IY.import("features/states")

local RunService = Services.RunService

local M = {}
local TAG   = "fling"
local SPIN  = Vector3.new(0, 99999, 0)
local STILL = Vector3.new(0, 0, 0)
local BOOST = Vector3.new(0, 10000, 0)
local HEAVY = PhysicalProperties.new(100, 0.3, 0.5)

--[[ `BasePart.Velocity` is the deprecated alias of AssemblyLinearVelocity and
     the legacy code used it throughout. Prefer the current name and fall back,
     so this works on old clients as well as new ones. ]]
local function readVelocity(part)
	local value = Guard.try(function() return part.AssemblyLinearVelocity end)
	if typeof(value) == "Vector3" then return value end
	value = Guard.try(function() return part.Velocity end)
	if typeof(value) == "Vector3" then return value end
	return STILL
end

local function writeVelocity(part, value)
	if not pcall(function() part.AssemblyLinearVelocity = value end) then
		pcall(function() part.Velocity = value end)
	end
end

-- ═══ fling ══════════════════════════════════════════════════════════════════

--[[ Heavy, massless, non-collidable and spinning: anything that touches you is
     thrown. The pulse -- 0.2s spinning, 0.1s still -- is the legacy `repeat`
     loop (11804) expressed as one 0.1s interval with a three-step phase, which
     is what lets `;breakloops` and `;unloadiy` stop it. ]]
local fling = Feature.new("fling", {
	command  = "fling",
	describe = "flinging players on contact",

	start = function(self)
		local character = Character.require()
		local root = Character.requireRoot()

		-- Registered first so it runs last: the physics comes back even when a
		-- later step of this start path fails.
		self.bin:add(function() Snapshot.restoreTag(TAG) end)

		for _, part in ipairs(character:GetDescendants()) do
			if part:IsA("BasePart") then
				Snapshot.set(part, "CustomPhysicalProperties", HEAVY, TAG)
			end
		end
		for _, part in ipairs(character:GetChildren()) do
			if part:IsA("BasePart") then
				Snapshot.set(part, "Massless", true, TAG)
			end
		end
		Inst.breakVelocity(character)

		Noclip.start()
		self.bin:add(function() Noclip.stop() end)
		local force = self.bin:add(Instance.new("BodyAngularVelocity"))
		force.Name = "IY_" .. Str.random(10)
		force.AngularVelocity = SPIN
		force.MaxTorque = Vector3.new(0, math.huge, 0)
		force.P = math.huge
		force.Parent = root

		local phase = 0
		self.bin:add(Sched.interval("fling.pulse", 0.1, function()
			if not force.Parent then return end
			phase = phase % 3 + 1
			force.AngularVelocity = (phase == 3) and STILL or SPIN
		end, true))

		self.bin:connect(Character.died, function() self:stop() end)
	end,
})

-- ═══ walkfling ══════════════════════════════════════════════════════════════

--[[ Three writes to the root velocity per frame -- boost, restore, nudge --
     spread across Heartbeat, RenderStepped and Stepped, exactly as the legacy
     `repeat` loop (11865). The order is the whole trick, so it stays one
     sequential loop rather than three frame connections; it is a Sched loop in
     the bin, so `;unwalkfling`, `;breakloops` and `;unloadiy` all reach it. ]]
local walkfling = Feature.new("walkfling", {
	command  = "walkfling",
	describe = "flinging players as you walk",

	start = function(self)
		Character.requireRoot()

		Noclip.start()
		self.bin:add(function() Noclip.stop() end)

		local nudge = 0.1
		self.bin:add(Sched.interval("walkfling.step", 0, function()
			local root = Character.root()
			if not root then return end
			local velocity = readVelocity(root)
			writeVelocity(root, velocity * 10000 + BOOST)

			RunService.RenderStepped:Wait()
			root = Character.root()
			if not root then return end
			writeVelocity(root, velocity)

			RunService.Stepped:Wait()
			root = Character.root()
			if not root then return end
			writeVelocity(root, velocity + Vector3.new(0, nudge, 0))
			nudge = -nudge
		end, true))

		self.bin:connect(Character.died, function() self:stop() end)
	end,
})

-- ═══ flyfling ═══════════════════════════════════════════════════════════════

--[[ Vehicle fly plus walkfling. Legacy was two dispatcher round trips --
     `unvehiclefly\\unwalkfling`, a `task.wait()`, then
     `vehiclefly\\walkfling` (11838) -- and its speed argument was written into
     the `vehicleflyspeed` global. Here it is one feature that owns both halves,
     which is also what makes `;toggleflyfling` correct.

     A speed argument is passed to features/fly; omitting it keeps whatever
     `;vflyspeed` was last set to, as legacy's `or vehicleflyspeed` did. ]]
local flyfling = Feature.new("flyfling", {
	command  = "flyfling",
	describe = "flinging players while you fly",

	start = function(self, opts)
		Character.requireRoot()
		Fly.start({ speed = opts.speed or Fly.speed(), vehicle = true })
		walkfling:start()

		self.bin:add(function()
			walkfling:stop()
			Fly.stop()
			-- Legacy's `unflyfling` chained `breakvelocity` (11846), so you stop
			-- where you are instead of coasting.
			Inst.breakVelocity(Character.get())
		end)
	end,
})

-- ═══ invisfling ═════════════════════════════════════════════════════════════

--[[ Hand the client a decoy rig for three seconds, take the real one back, then
     strip it to a single root part carrying a huge BodyThrust. Other players
     see nothing and anything you touch leaves the map.

     Two legacy statements did nothing and are gone: a Part named "Torso" was
     built and never parented (11906), and a `z2:Clone()` result was discarded
     (11924). Everything else is the same sequence, with the character handed
     back by the bin so an interrupted start cannot strand you with no
     character at all. ]]
local invisfling = Feature.new("invisfling", {
	command  = "invisfling",
	describe = "invisible flinging",

	start = function(self)
		local player = Character.player
		if not player then Guard.fail("there is no local player") end
		local character = Character.require()
		Character.requireHumanoid()

		-- Legacy disabled the Dead state and never put it back; features/states
		-- records the original and restores it on stop and on unload.
		States.set(Enum.HumanoidStateType.Dead, false)
		self.bin:add(function() States.clear(Enum.HumanoidStateType.Dead) end)
		-- Added before the decoy exists, so it runs after the decoy is destroyed.
		self.bin:add(function()
			if player.Character ~= character then
				pcall(function() player.Character = character end)
			end
		end)

		local decoy = Instance.new("Model")
		local head = Instance.new("Part")
		head.Name = "Head"
		head.Anchored = true
		head.CanCollide = false
		head.Parent = decoy
		local decoyHumanoid = Instance.new("Humanoid")
		decoyHumanoid.Name = "Humanoid"
		decoyHumanoid.Parent = decoy
		decoy.Parent = character
		self.bin:add(decoy)

		player.Character = decoy
		task.wait(3)
		player.Character = character
		task.wait(3)

		local root = Character.requireRoot()
		local spare = Instance.new("Humanoid")
		spare.Parent = character
		self.bin:add(spare)

		for _, child in ipairs(character:GetChildren()) do
			if child ~= root and child ~= decoy and not child:IsA("Humanoid") then
				pcall(function() child:Destroy() end)
			end
		end
		pcall(function()
			root.Transparency = 0
			root.Color = Color3.new(1, 1, 1)
		end)

		self.bin:add(Sched.frameLoop("invisfling.collide", function()
			local current = Character.root()
			if current then current.CanCollide = false end
		end, "stepped"))

		Fly.start({ speed = Fly.speed() })
		self.bin:add(function() Fly.stop() end)

		local camera = workspace.CurrentCamera
		if camera then
			Snapshot.set(camera, "CameraSubject", root, "invisfling")
			self.bin:add(function() Snapshot.restore(camera, "CameraSubject") end)
		end

		local thrust = self.bin:add(Instance.new("BodyThrust"))
		thrust.Force = Vector3.new(99999, 99999 * 10, 99999)
		thrust.Location = root.Position
		thrust.Parent = root
	end,
})

-- ═══ module API ═════════════════════════════════════════════════════════════

M.fling      = fling
M.walkfling  = walkfling
M.flyfling   = flyfling
M.invisfling = invisfling

--[[ Plain fling is the default, so the common case reads like every other
     feature module. The other three are addressed by name. ]]
function M.start(opts) return fling:start(opts or {}) end
function M.stop() return fling:stop() end
function M.isRunning() return fling:isRunning() end

--[[ Is any of the four running? `;unloadiy` and the diagnostics panel ask. ]]
function M.anyRunning()
	return fling:isRunning() or walkfling:isRunning()
		or flyfling:isRunning() or invisfling:isRunning()
end

return M
