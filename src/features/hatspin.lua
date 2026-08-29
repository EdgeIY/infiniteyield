--[[═══════════════════════════════════════════════════════════════════════════
	features/hatspin · detach your accessories and spin them
	─────────────────────────────────────────────────────────────────────────
	Legacy source.ref.lua 11240-11278. Each accessory's Handle gets a
	BodyPosition that pins it to your head and a BodyAngularVelocity that spins
	it, once its Weld is destroyed. Three legacy bugs are fixed:

	  · `unhatspin` iterated `pairs(v.Handle)` (11270) -- a plain `pairs` over an
	    Instance, which raises "invalid argument #1 to 'for iterator'". The
	    BodyPosition and BodyAngularVelocity were therefore never removed, so
	    every hat stayed detached and floating until you died. Both movers are in
	    the bin now, which means `;unhatspin`, a respawn and `;unloadiy` all
	    remove them without iterating anything.
	  · the Stepped connection was created *inside* the loop over accessories and
	    stored in one global (11256), so wearing four hats left three live
	    connections for the rest of the session. One loop drives every hat.
	  · the whole thing broke permanently on the first respawn, because the new
	    accessories had no movers and nothing re-applied them. `reapply` does.

	`;hatspin` also needed `wait(.5)` before it could run twice (11242); a
	feature restart stops the previous run first, so it does not.
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Feature   = IY.import("features/feature")
local Character = IY.import("core/character")
local Sched     = IY.import("core/scheduler")
local Guard     = IY.import("core/guard")
local Str       = IY.import("core/util/strings")

local M = {}

local DEFAULT_SPEED = 100

--[[ Destroying the Weld is what frees the hat, and re-parenting the accessory
     out of the character and back is what makes the engine build a new one.
     That needs a frame in between, so it runs on its own thread -- by the time
     this cleanup is reached the bin has already destroyed both movers, which is
     the ordering that matters. ]]
local function reweld(accessories, character)
	if #accessories == 0 then return end
	task.spawn(function()
		for i = 1, #accessories do
			local accessory = accessories[i]
			if accessory.Parent then
				pcall(function() accessory.Parent = workspace end)
			end
		end
		task.wait()
		if not character or not character.Parent then return end
		for i = 1, #accessories do
			local accessory = accessories[i]
			if accessory.Parent == workspace then
				pcall(function() accessory.Parent = character end)
			end
		end
	end)
end

local feature = Feature.new("hatspin", {
	command  = "hatspin",
	reapply  = true,
	describe = "spinning your accessories",

	start = function(self, opts)
		local character = Character.require()
		local humanoid = Character.requireHumanoid()
		local accessories = humanoid:GetAccessories()
		if #accessories == 0 then
			Guard.fail("you are not wearing any accessories")
		end

		local speed = opts.speed or DEFAULT_SPEED
		local keeps, detached = {}, {}

		-- Registered first so it runs last, after the movers are gone.
		self.bin:add(function() reweld(detached, character) end)

		for i = 1, #accessories do
			local accessory = accessories[i]
			local handle = accessory:FindFirstChild("Handle")
			if handle then
				local weld = handle:FindFirstChildOfClass("Weld")
				if weld then pcall(function() weld:Destroy() end) end

				local keep = self.bin:add(Instance.new("BodyPosition"))
				keep.Name = "IY_" .. Str.random(8)
				keep.P = 30000
				keep.D = 50
				keep.Parent = handle

				local spin = self.bin:add(Instance.new("BodyAngularVelocity"))
				spin.Name = "IY_" .. Str.random(8)
				spin.AngularVelocity = Vector3.new(0, speed, 0)
				spin.MaxTorque = Vector3.new(0, speed * 2, 0)
				spin.Parent = handle

				keeps[#keeps + 1] = keep
				detached[#detached + 1] = accessory
			end
		end

		if #keeps == 0 then
			Guard.fail("none of your accessories have a handle to spin")
		end

		self.bin:add(Sched.frameLoop("hatspin.step", function()
			local current = Character.get()
			local head = current and current:FindFirstChild("Head")
			if not head then return end
			local position = head.Position
			for i = 1, #keeps do
				local keep = keeps[i]
				if keep.Parent then keep.Position = position end
			end
		end, "stepped"))
	end,
})

M.feature = feature

function M.start(opts) return feature:start(opts or {}) end
function M.stop() return feature:stop() end
function M.toggle(opts) return feature:toggle(opts or {}) end
function M.isRunning() return feature:isRunning() end

return M
