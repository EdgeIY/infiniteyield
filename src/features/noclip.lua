--[[═══════════════════════════════════════════════════════════════════════════
	features/noclip · walk through walls
	─────────────────────────────────────────────────────────────────────────
	Same technique as the legacy version -- clear CanCollide on every character
	part each physics step -- with three fixes:

	  · the 0.1s `task.wait` on both the on and off paths is gone. Because
	    `fling`, `walkfling`, `vnoclip` and `flyfling` all toggle noclip through
	    the command dispatcher, those waits let an off-path clear the restore
	    table while an on-path was still filling it, permanently leaving parts
	    non-collidable.
	  · the restore set lives in the feature bin, so `;unloadiy` and a failed
	    start both put collisions back.
	  · it re-arms itself after a respawn. The legacy spawn handler explicitly
	    turned noclip *off* (`if not Clip then execCmd('clip') end`) even though
	    its loop read the character dynamically and would have kept working.
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Feature   = IY.import("features/feature")
local Sched     = IY.import("core/scheduler")
local Character = IY.import("core/character")

local M = {}

-- Parts other features own and do not want touched (float's platform).
local exempt = setmetatable({}, { __mode = "k" })

function M.exempt(part)
	exempt[part] = true
	return part
end

function M.unexempt(part)
	exempt[part] = nil
end

local feature = Feature.new("noclip", {
	command = "noclip",
	reapply = true,
	describe = "character collisions disabled",

	start = function(self)
		local restore = {}
		self.state.restore = restore

		-- Registered first so it runs last: collisions come back even if the
		-- loop below never starts.
		self.bin:add(function()
			for part in pairs(restore) do
				if typeof(part) == "Instance" and part.Parent then
					pcall(function() part.CanCollide = true end)
				end
			end
		end)

		self.bin:add(Sched.frameLoop("noclip.step", function()
			local character = Character.get()
			if not character then return end
			for _, part in ipairs(character:GetDescendants()) do
				if part:IsA("BasePart") and part.CanCollide and not exempt[part] then
					part.CanCollide = false
					restore[part] = true
				end
			end
		end, "stepped"))
	end,
})

M.feature = feature

function M.start() return feature:start() end
function M.stop() return feature:stop() end
function M.toggle() return feature:toggle() end
function M.isRunning() return feature:isRunning() end

return M
