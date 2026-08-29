--[[═══════════════════════════════════════════════════════════════════════════
	features/unanchored · freeze or drag every loose part in the world
	─────────────────────────────────────────────────────────────────────────
	Legacy source.ref.lua 12857-12958 (freezeunanchored, thawunanchored,
	tpunanchored). Same technique -- a BodyPosition, plus a BodyGyro for freeze,
	with an infinite MaxForce on every unanchored part -- rebuilt around bins:

	  · the `workspace.DescendantAdded` connection lived in a module-level
	    `freezingua` (12857) that only `thawunanchored` disconnected, so
	    `;unloadiy` left it live and every part that streamed in afterwards was
	    frozen by a script that was no longer loaded.
	  · `frozenParts` (12858) was a global both commands appended to, and thaw
	    emptied it by destroying *every* BodyPosition and BodyGyro child of each
	    listed part -- including ones the game itself owned. Each part's forces
	    are a `bin:branch()` now: thaw removes exactly what we made, silently
	    skips parts that have since been destroyed, and one command taking a part
	    over from the other is an explicit hand-off instead of a blind sweep.

	`v:IsA("BasePart" or "UnionOperation")` (12884, 12939) is just
	`IsA("BasePart")` -- `or` between two strings yields the first. It was correct
	by accident, since UnionOperation is a BasePart; it is spelled properly here.
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Feature   = IY.import("features/feature")
local Parts     = IY.import("features/parts")
local Character = IY.import("core/character")
local Guard     = IY.import("core/guard")
local Str       = IY.import("core/util/strings")

local M = {}

local HUGE = Vector3.new(math.huge, math.huge, math.huge)

--[[ Rig part names, R6 and R15 together. Legacy's freeze list (12860-12882) had
     both; its tp list (12939) had only the R6 half, so `;tpua` dragged the R15
     limbs of every rig in the game towards your head and left the head and root
     welded where they were. One list serves both commands. ]]
local RIG_PARTS = {}
for _, name in ipairs({
	"Head", "Torso", "HumanoidRootPart",
	"Right Arm", "Left Arm", "Right Leg", "Left Leg",
	"UpperTorso", "LowerTorso", "RightUpperArm", "LeftUpperArm",
	"RightLowerArm", "LeftLowerArm", "RightHand", "LeftHand",
	"RightUpperLeg", "LeftUpperLeg", "RightLowerLeg", "LeftLowerLeg",
	"RightFoot", "LeftFoot",
}) do RIG_PARTS[Str.lower(name)] = true end

--[[ A part we are willing to take over: loose, not part of a rig, and not one
     of our own -- legacy excluded the speaker's character from both commands
     (12891, 12939), because a BodyPosition on your own leg pointed at your own
     head throws you across the map. ]]
local function eligible(instance, character)
	if not instance:IsA("BasePart") then return false end
	if instance.Anchored then return false end
	if RIG_PARTS[Str.lower(instance.Name)] then return false end
	if character and instance:IsDescendantOf(character) then return false end
	return true
end

-- ── ownership ───────────────────────────────────────────────────────────────

-- part -> { bin = <branch>, owner = "freeze" | "drag" }. Weak keys, so a
-- destroyed part is not kept alive by our bookkeeping the way the legacy
-- `frozenParts` array kept every part it ever saw for the whole session.
local claims = setmetatable({}, { __mode = "k" })

--[[ Take a part over, releasing whoever held it first. That release is what
     legacy achieved by destroying every BodyPosition and BodyGyro it found on
     the part, and it is why `;tpua` after `;freezeua` re-points the part instead
     of fighting a frozen BodyPosition that also has an infinite MaxForce. ]]
local function claim(part, owner, bin)
	local existing = claims[part]
	if existing then existing.bin:destroy() end
	local branch = bin:branch(owner)
	claims[part] = { bin = branch, owner = owner }
	branch:add(function()
		local current = claims[part]
		if current and current.bin == branch then claims[part] = nil end
	end)
	return branch
end

local function freezePart(part, bin)
	local branch = claim(part, "freeze", bin)
	local position = branch:add(Instance.new("BodyPosition"))
	position.MaxForce = HUGE
	position.Position = part.Position
	local gyro = branch:add(Instance.new("BodyGyro"))
	gyro.MaxTorque = HUGE
	gyro.CFrame = part.CFrame
	-- Parented last: legacy set Parent first (12901, 12905), which makes the
	-- solver pick the mover up with a zero target before the real one lands.
	position.Parent = part
	gyro.Parent = part
	return true
end

local function dragPart(part, position, bin)
	local branch = claim(part, "drag", bin)
	local force = branch:add(Instance.new("BodyPosition"))
	force.MaxForce = HUGE
	force.Position = position
	force.Parent = part
	return true
end

-- ── features ────────────────────────────────────────────────────────────────

--[[ One workspace pass, one `apply` per eligible part. Contained per part: a
     part that rejects a BodyPosition -- an unreadable CFrame, or one destroyed
     between the walk and the write -- must not abort a sweep of thousands. ]]
local function sweep(apply)
	local character = Character.get()
	local loose = Parts.find(function(instance) return eligible(instance, character) end)
	local touched = 0
	for i = 1, #loose do
		if pcall(apply, loose[i]) then touched = touched + 1 end
	end
	return touched
end

local freezing = Feature.new("freezeunanchored", {
	command  = "freezeunanchored",
	describe = "unanchored parts held in place",

	start = function(self)
		local bin = self.bin
		self.state.frozen = sweep(function(part) return freezePart(part, bin) end)

		-- One event, not a per-frame rescan: parts stream in constantly and
		-- walking the world every frame is what made the legacy loop commands
		-- unusable in big maps.
		self.bin:connect(workspace.DescendantAdded, Guard.wrap("unanchored.added", function(instance)
			if not eligible(instance, Character.get()) then return end
			if pcall(freezePart, instance, bin) then
				self.state.frozen = (self.state.frozen or 0) + 1
			end
		end))
	end,
})

-- No `command` binding: `tpunanchored` is a one-shot with no toggle, and its
-- forces are cleared by `thawunanchored` exactly as they were in legacy.
local dragging = Feature.new("tpunanchored", {
	describe = "unanchored parts dragged to a position",

	start = function(self, opts)
		local position = opts.position
		if not position then Guard.fail("tpunanchored needs somewhere to drag to") end
		local bin = self.bin
		self.state.dragged = sweep(function(part) return dragPart(part, position, bin) end)
	end,
})

M.freezeFeature = freezing
M.dragFeature   = dragging

--[[ Freeze every loose part and keep freezing them as they appear. Returns how
     many were frozen by this pass. ]]
function M.freeze()
	freezing:start()
	return freezing.state.frozen or 0
end

--[[ Drag every loose part to `position`. Restarting the feature releases the
     previous set first, which is what legacy did by destroying the movers it
     found -- so `;tpua bob` after `;tpua jim` re-points them rather than leaving
     two infinite forces arguing. ]]
function M.teleport(position)
	dragging:start({ position = position })
	return dragging.state.dragged or 0
end

--[[ thawunanchored: everything both commands made goes, parts that no longer
     exist are skipped, and running it when nothing was ever frozen is a no-op
     rather than an error. Returns the number of distinct parts released -- a
     part that was frozen and then dragged is one part, not two. ]]
function M.thaw()
	local released = 0
	for _ in pairs(claims) do released = released + 1 end
	freezing:stop()
	dragging:stop()
	return released
end

function M.isFrozen()   return freezing:isRunning() end
function M.isDragging() return dragging:isRunning() end

return M
