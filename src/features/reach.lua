--[[═══════════════════════════════════════════════════════════════════════════
	features/reach · oversized tool handles
	─────────────────────────────────────────────────────────────────────────
	    Reach.start{ size = 60 }              a 0.5 x 0.5 x size spear (;reach)
	    Reach.start{ size = 60, box = true }  a size cube            (;boxreach)
	    Reach.stop()                          everything back

	Legacy equivalent: source.ref.lua 11642-11704, and the two bugs that made it
	unusable with more than one tool:

	  · the originals were two module scalars, `currentToolSize` and
	    `currentGripPos`, both initialised to `""`. With two tools reached, both
	    were restored to the geometry of whichever tool the loop saw last -- and
	    `;unreach` before any `;reach` assigned the empty string to `Handle.Size`,
	    which throws.
	  · `unreach` did `v.Handle.SelectionBoxCreated:Destroy()` unguarded, so it
	    threw for any tool that had never been reached.

	Originals are recorded per handle through core/snapshot under the "reach"
	tag, so every tool gets its own size and grip back and the off-command is a
	`Snapshot.restoreTag` plus the bin. That also restores tools which have been
	unequipped in the meantime: legacy scanned the character, and `reach` itself
	unequips everything it touches, so `;unreach` normally found nothing at all
	to restore -- and a second `;reach` found nothing to apply to, which is why
	this scans the whole inventory rather than just the character.
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Feature   = IY.import("features/feature")
local Character = IY.import("core/character")
local Snapshot  = IY.import("core/snapshot")
local Guard     = IY.import("core/guard")
local Inst      = IY.import("core/util/instances")

local M = {}

local TAG = "reach"
local DEFAULT_SIZE = 60

local feature = Feature.new("reach", {
	command  = "reach",
	reapply  = true,
	describe = "oversized tool handles",

	start = function(self, opts)
		local size = opts.size or DEFAULT_SIZE
		local box = opts.box == true

		-- Registered first so it runs last: the geometry comes back even if the
		-- loop below throws halfway through.
		self.bin:add(function() Snapshot.restoreTag(TAG) end)

		local tools = Inst.tools(Character.player)
		local reached = 0
		for i = 1, #tools do
			local tool = tools[i]
			local handle = tool:FindFirstChild("Handle")
			if handle and handle:IsA("BasePart") then
				Snapshot.set(handle, "Massless", true, TAG)
				Snapshot.set(handle, "Size",
					box and Vector3.new(size, size, size) or Vector3.new(0.5, 0.5, size), TAG)
				Snapshot.set(tool, "GripPos", Vector3.new(0, 0, 0), TAG)
				-- Same name as legacy, so anything looking for it still finds it.
				local adornment = self.bin:add(Instance.new("SelectionBox"))
				adornment.Name = "SelectionBoxCreated"
				adornment.Adornee = handle
				adornment.Parent = handle
				reached = reached + 1
			end
		end
		if reached == 0 then Guard.fail("none of your tools have a Handle") end

		-- A handle that size drags the character around, so put the tools away.
		-- Re-equipping one keeps the reach.
		local humanoid = Character.humanoid()
		if humanoid then pcall(function() humanoid:UnequipTools() end) end

		self.state.count = reached
		self.state.size  = size
		self.state.box   = box
	end,
})

M.feature = feature

--[[ `opts.size`, `opts.box`. Restarting restores the previous geometry first,
     which is what the legacy `execCmd('unreach')` at the top of both commands
     was reaching for. ]]
function M.start(opts) return feature:start(opts or {}) end

--[[ Safe at any time. The records are keyed by handle, so restoring the tag
     puts back exactly what each tool started with; the extra restoreTag catches
     a `reach` that failed after recording but before the bin was populated. ]]
function M.stop()
	local wasRunning = feature:stop()
	local restored = Snapshot.restoreTag(TAG)
	return wasRunning, restored
end

function M.isRunning() return feature:isRunning() end
function M.count() return (feature.state and feature.state.count) or 0 end

--[[ The size actually applied, so `;togglereach` (which carries no arguments)
     can report the same number `;reach 120` did. ]]
function M.size() return (feature.state and feature.state.size) or DEFAULT_SIZE end

return M
