--[[═══════════════════════════════════════════════════════════════════════════
	features/stareat · keep facing a player
	─────────────────────────────────────────────────────────────────────────
	Legacy source.ref.lua 12398-12425, which had two bugs in seven lines:

	  · it created a RenderStepped connection inside the loop over targets and
	    stored only the last one in a global (12417). Every earlier connection
	    leaked for the rest of the session, and they all wrote the character's
	    CFrame on the same frame, so `;stareat all` fought itself and
	    `unstareat` could only ever stop one of them.
	  · the guard at 12404 read `if not getRoot(me) and getRoot(them) then
	    return end`, so it bailed only when *they* had a root and you did not --
	    exactly backwards. A target with no root fell straight through into the
	    loop and threw.

	One loop, the target list re-read every frame so a target that dies, leaves
	or has not spawned yet is simply skipped, and both roots checked.
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Feature   = IY.import("features/feature")
local Character = IY.import("core/character")
local Sched     = IY.import("core/scheduler")
local Guard     = IY.import("core/guard")

local M = {}

--[[ The first target that currently has a root part. Legacy effectively stared
     at whichever of its competing connections wrote last; picking the first live
     target makes `;stareat all` deterministic instead. ]]
local function aim(targets)
	for i = 1, #targets do
		local root = targets[i].root
		if root then return root end
	end
	return nil
end

local feature = Feature.new("stareat", {
	command  = "stareat",
	describe = "staring at a player",

	start = function(self, opts)
		local targets = opts.targets or {}
		if #targets == 0 then Guard.fail("stareat needs a player to look at") end

		self.bin:add(Sched.frameLoop("stareat.step", function()
			local character = Character.get()
			local primary = character and character.PrimaryPart
			if not primary then return end
			local root = aim(targets)
			if not root then return end
			local origin, at = primary.Position, root.Position
			-- Yaw only: match the target's X/Z but keep your own height (12409).
			character:SetPrimaryPartCFrame(
				CFrame.new(origin, Vector3.new(at.X, origin.Y, at.Z)))
		end))
	end,
})

M.feature = feature

function M.start(opts) return feature:start(opts or {}) end
function M.stop() return feature:stop() end
function M.isRunning() return feature:isRunning() end
function M.targets() return feature:option("targets", {}) end

return M
