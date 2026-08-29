--[[═══════════════════════════════════════════════════════════════════════════
	features/teleportwalk · move by teleporting a step at a time
	─────────────────────────────────────────────────────────────────────────
	Legacy equivalent: source.ref.lua 12067-12094.

	    tpwalking = RunService.Heartbeat:Connect(function(delta)
	        if not (character and humanoid and humanoid.Parent) then
	            tpwalking:Disconnect()

	`character` and `humanoid` were captured when the command ran, so the first
	respawn hit that guard, disconnected the loop and left nothing to tell you:
	`;tpwalk` looked like it had stopped working, and `;untpwalk` then called
	`:Disconnect()` on a nil global if you had never started it. Both are gone:
	the loop reads the character each frame and the feature re-applies itself
	after a respawn.

	`stack` reproduces the legacy `tpwalkStack` global -- passing the flag adds
	the new speed on top of the accumulated total instead of replacing it -- and
	stopping resets it, exactly as `;unteleportwalk` did.
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Feature   = IY.import("features/feature")
local Character = IY.import("core/character")
local Sched     = IY.import("core/scheduler")

local M = {}

local feature = Feature.new("teleportwalk", {
	command  = "teleportwalk",
	reapply  = true,
	describe = "teleport walking",

	start = function(self)
		Character.requireRoot()

		self.bin:add(Sched.frameLoop("teleportwalk.step", function(delta)
			local character = Character.get()
			local humanoid = Character.humanoid()
			if not character or not humanoid then return end

			local direction = humanoid.MoveDirection
			if direction.Magnitude <= 0 then return end

			local speed = (self:option("speed", 1) or 1) + (self:option("stack", 0) or 0)
			character:TranslateBy(direction * speed * (delta or 0) * 10)
		end, "heartbeat"))
	end,

	stop = function(self)
		if self.opts then self.opts.stack = 0 end
	end,
})

M.feature = feature

--[[ opts.speed  studs multiplier (legacy default 1)
     opts.stack   add this speed to the running total instead of replacing it ]]
function M.start(opts)
	opts = opts or {}
	local speed = opts.speed or 1
	local stack = feature:option("stack", 0) or 0
	if opts.stack then stack = stack + speed end
	return feature:start({ speed = speed, stack = stack })
end

function M.stop() return feature:stop() end
function M.isRunning() return feature:isRunning() end

--[[ The effective speed, for the command's reply. ]]
function M.speed()
	return (feature:option("speed", 1) or 1) + (feature:option("stack", 0) or 0)
end

return M
