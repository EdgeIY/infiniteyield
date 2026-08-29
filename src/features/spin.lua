--[[═══════════════════════════════════════════════════════════════════════════
	features/spin · rotate on the spot
	─────────────────────────────────────────────────────────────────────────
	Legacy source.ref.lua 12154-12177: a BodyAngularVelocity named "Spinning" in
	the root part, hunted down by name on both the on and the off path. Three
	things were wrong with that:

	  · both commands started `getRoot(speaker.Character):GetChildren()`, so
	    `;unspin` while dead or still loading threw on a nil root instead of
	    doing nothing
	  · a game with its own part called "Spinning" lost it
	  · the force died with the old root on every respawn and nothing put it
	    back, so `;spin` silently stopped working after your first death

	The bin owns the force, `reapply` re-creates it on the new root, and the
	speed can be changed on a running spin without restarting it.
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Feature   = IY.import("features/feature")
local Character = IY.import("core/character")

local M = {}

local DEFAULT_SPEED = 20

local function velocityFor(speed)
	return Vector3.new(0, speed or DEFAULT_SPEED, 0)
end

local feature = Feature.new("spin", {
	command  = "spin",
	reapply  = true,
	describe = "spinning",

	start = function(self, opts)
		local root = Character.requireRoot()
		local force = self.bin:add(Instance.new("BodyAngularVelocity"))
		force.Name = "Spinning"
		force.MaxTorque = Vector3.new(0, math.huge, 0)
		force.AngularVelocity = velocityFor(opts.speed)
		force.Parent = root
		self.state.force = force
	end,

	configure = function(self, opts)
		local force = self.state.force
		if force and force.Parent then
			force.AngularVelocity = velocityFor(opts.speed)
		end
	end,
})

M.feature = feature

function M.start(opts) return feature:start(opts or {}) end
function M.stop() return feature:stop() end
function M.toggle(opts) return feature:toggle(opts or {}) end
function M.isRunning() return feature:isRunning() end

function M.setSpeed(speed)
	feature:configure({ speed = speed })
	return speed
end

function M.speed()
	return feature:option("speed", DEFAULT_SPEED)
end

return M
