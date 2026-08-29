--[[═══════════════════════════════════════════════════════════════════════════
	features/toolinvisible · the root-part swap that hides held tools
	─────────────────────────────────────────────────────────────────────────
	Stand on an anchored slab at y = 10000, and when the character lands on it
	swap the root part for a clone of itself and walk back to where you started.
	The rig keeps working; the tool welds do not come back visibly.

	Legacy (lines 9717-9754) leaked everything it made:

	  · `loc` was a global, so two invocations fought over the return position
	  · the box and its Touched connection were only ever cleaned up by a
	    `CharacterAdded` handler, so if you never respawned they stayed forever,
	    and there was no un-command
	  · `Char` was captured once and then `repeat wait() until Char` waited on
	    the captured value *after* already indexing it
	  · `Char.Humanoid.RootPart` was indexed three times with no nil check

	Everything here is in the bin, the position is a local, and the feature ends
	itself once the swap is done -- from a timer rather than from inside its own
	tracked thread, which would otherwise be cancelled mid-cleanup.
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Feature   = IY.import("features/feature")
local Character = IY.import("core/character")
local Sched     = IY.import("core/scheduler")
local Guard     = IY.import("core/guard")
local Inst      = IY.import("core/util/instances")
local Str       = IY.import("core/util/strings")

local M = {}

local PERCH = Vector3.new(0, 10000, 0)

local feature = Feature.new("toolinvisible", {
	command  = "toolinvisible",
	describe = "tool invisibility",

	start = function(self)
		local character = Character.require()
		local root = Character.requireRoot()
		local origin = root.Position
		local swapping = false

		local box = self.bin:add(Instance.new("Part"))
		box.Name = "IY_" .. Str.random(10)
		box.Anchored = true
		box.CanCollide = true
		box.Size = Vector3.new(10, 1, 10)
		box.Position = PERCH
		box.Parent = workspace

		self.bin:connect(box.Touched, function(part)
			if swapping then return end
			local current = Character.get()
			if not current then return end
			local ok, mine = pcall(function() return part:IsDescendantOf(current) end)
			if not ok or not mine then return end
			swapping = true

			self.bin:spawn(function()
				Guard.call("toolinvisible.swap", function()
					local liveRoot = Inst.root(current)
					if not liveRoot then return end
					local replacement = liveRoot:Clone()
					task.wait(0.25)
					liveRoot:Destroy()
					replacement.Parent = current
					current:MoveTo(origin)
				end)
				swapping = false
				-- Off a timer, not from this thread: stopping empties the bin, and
				-- the bin would try to cancel the very thread doing the cleanup.
				Sched.after(0.1, function() M.stop() end, "toolinvisible.finish")
			end)
		end)

		pcall(function() character:MoveTo(box.Position + Vector3.new(0, 0.5, 0)) end)
	end,
})

M.feature = feature

function M.start(opts) return feature:start(opts or {}) end
function M.stop() return feature:stop() end
function M.toggle(opts) return feature:toggle(opts) end
function M.isRunning() return feature:isRunning() end

return M
