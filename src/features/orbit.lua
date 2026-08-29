--[[═══════════════════════════════════════════════════════════════════════════
	features/orbit · circle a player
	─────────────────────────────────────────────────────────────────────────
	Legacy equivalent: source.ref.lua 9395-9431. The maths is unchanged -- the
	same rotate-around-their-root-and-look-inward frame each physics step -- but
	the three connections it left in the globals `orbit1`, `orbit2` and `orbit3`
	are now one bin, which means:

	  · `;orbit` twice no longer leaves the first loop running against the old
	    player (the second call only overwrote `orbit1`, so both kept CFraming
	    the root part and it juddered between two orbits)
	  · `;unorbit` is safe before `;orbit`
	  · dying or sitting down still stops it -- through `Character.died` and the
	    humanoid's Seated signal in the bin, rather than by recursing into the
	    command dispatcher
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Feature   = IY.import("features/feature")
local Character = IY.import("core/character")
local Sched     = IY.import("core/scheduler")
local Guard     = IY.import("core/guard")
local Inst      = IY.import("core/util/instances")

local M = {}

local feature = Feature.new("orbit", {
	command  = "orbit",
	describe = "orbiting a player",

	start = function(self, opts)
		local target = opts.target
		if not target then Guard.fail("there is nobody to orbit") end
		target:requireRoot()

		local humanoid = Character.requireHumanoid()
		Character.requireRoot()

		local rotation = 0
		local speed    = opts.speed or 0.2
		local distance = opts.distance or 6

		self.bin:add(Sched.frameLoop("orbit.step", function()
			local root = Character.root()
			local targetRoot = target.root
			if not root or not targetRoot then return end

			Inst.breakVelocity(Character.get())
			rotation = rotation + speed

			local centre = targetRoot.Position
			local orbitPosition = (CFrame.new(centre)
				* CFrame.Angles(0, math.rad(rotation), 0)
				* CFrame.new(distance, 0, 0)).Position
			root.CFrame = CFrame.lookAt(orbitPosition,
				Vector3.new(centre.X, orbitPosition.Y, centre.Z))
		end, "stepped"))

		self.bin:connect(Character.died, function() self:stop() end)
		self.bin:connect(humanoid.Seated, function(seated)
			if seated then self:stop() end
		end)
	end,
})

M.feature = feature

function M.start(target, opts)
	opts = opts or {}
	return feature:start({ target = target, speed = opts.speed, distance = opts.distance })
end

function M.stop() return feature:stop() end
function M.isRunning() return feature:isRunning() end

function M.target()
	return feature:option("target", nil)
end

return M
