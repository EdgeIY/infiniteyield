--[[═══════════════════════════════════════════════════════════════════════════
	features/parts · one workspace pass, plus the invisible-part restore record
	─────────────────────────────────────────────────────────────────────────
	Legacy source.ref.lua 8766-8843 and 10922-10936. Every command in that range
	opened its own `for i,v in pairs(workspace:GetDescendants())` loop -- eleven
	full walks of the world, three of them run back to back by a fourth command.
	`M.find` is the single pass they all share now, and it contains a failing
	predicate per instance so one unreadable part cannot abort the sweep.

	The other half of this module is `invisibleparts`. Legacy remembered what it
	had revealed in a module-level `shownParts` array (8826): a strong reference
	to every part for the rest of the session, nothing to stop the same part
	being listed twice, and no restore at all when IY unloaded. The originals go
	through core/snapshot under the "invisparts" tag instead, which makes the
	off-command, a re-run and `;unloadiy` all correct without a bookkeeping
	table of our own.
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Feature  = IY.import("features/feature")
local Snapshot = IY.import("core/snapshot")
local Inst     = IY.import("core/util/instances")
local Str      = IY.import("core/util/strings")

local M = {}

local TAG = "invisparts"
M.TAG = TAG

-- Everything legacy `deletevelocity` searched for (8812), in one place.
local FORCE_CLASSES = {
	"BodyVelocity", "BodyGyro", "BodyThrust", "BodyForce", "BodyAngularVelocity",
	"RocketPropulsion", "AngularVelocity", "VectorForce", "LineForce",
}

-- ── the single pass ─────────────────────────────────────────────────────────

--[[ Every descendant of `root` (workspace by default) that `predicate` accepts,
     from one GetDescendants() call. ]]
function M.find(predicate, root)
	local out = {}
	local ok, descendants = pcall(function() return (root or workspace):GetDescendants() end)
	if not ok then return out end
	for i = 1, #descendants do
		local instance = descendants[i]
		local okTest, matched = pcall(predicate, instance)
		if okTest and matched then out[#out + 1] = instance end
	end
	return out
end

--[[ Case-insensitive Name match, any class -- what `;delete` searches on. ]]
function M.named(name, root)
	local needle = Str.lower(Str.trim(name))
	return M.find(function(instance)
		return Str.lower(instance.Name) == needle
	end, root)
end

--[[ Exact ClassName match, deliberately not `IsA`: legacy compared ClassName
     (8785), so `;deleteclass Part` takes Parts and leaves MeshParts alone. The
     `class` argument type has already rejected anything that is not a class, so
     a typo cannot reach here and silently match nothing. ]]
function M.ofClass(className, root)
	local needle = Str.lower(Str.trim(className))
	return M.find(function(instance)
		return Str.lower(instance.ClassName) == needle
	end, root)
end

function M.partsNamed(name)
	local needle = Str.lower(Str.trim(name))
	return M.find(function(instance)
		return instance:IsA("BasePart") and Str.lower(instance.Name) == needle
	end)
end

function M.partsOfClass(className)
	local needle = Str.lower(Str.trim(className))
	return M.find(function(instance)
		return instance:IsA("BasePart") and Str.lower(instance.ClassName) == needle
	end)
end

function M.parts(root)
	return M.find(function(instance) return instance:IsA("BasePart") end, root)
end

--[[ Fully transparent parts. `collidableOnly` is the `deleteinvisparts` filter
     (8820) -- an invisible wall you can still walk into is the one worth
     removing. ]]
function M.invisibleParts(collidableOnly)
	return M.find(function(instance)
		if not instance:IsA("BasePart") then return false end
		if instance.Transparency ~= 1 then return false end
		return (not collidableOnly) or instance.CanCollide
	end)
end

--[[ Body movers and forces, for `deletevelocity`. ]]
function M.forces(root)
	return M.find(function(instance)
		for i = 1, #FORCE_CLASSES do
			if instance:IsA(FORCE_CLASSES[i]) then return true end
		end
		return false
	end, root)
end

--[[ Destroy a list, reporting how many actually went. Destroying a parent
     unparents its children, so an instance already taken out by an earlier
     Destroy in the same list is skipped instead of counted twice. ]]
function M.destroy(list)
	local destroyed = 0
	for i = 1, #list do
		local instance = list[i]
		if Inst.isAlive(instance) then
			local ok = pcall(function() instance:Destroy() end)
			if ok then destroyed = destroyed + 1 end
		end
	end
	return destroyed
end

-- ── invisibleparts ──────────────────────────────────────────────────────────

local function sweep()
	local hidden = M.invisibleParts(false)
	local shown = 0
	for i = 1, #hidden do
		if Snapshot.set(hidden[i], "Transparency", 0, TAG) then shown = shown + 1 end
	end
	return shown
end

local feature = Feature.new("invisibleparts", {
	command  = "invisibleparts",
	describe = "invisible world parts revealed",

	start = function(self)
		-- Registered before the sweep, so the restore exists even if the sweep
		-- throws part way through.
		self.bin:add(function() Snapshot.restoreTag(TAG) end)
		self.state.shown = sweep()
	end,
})

M.feature = feature

--[[ Reveal every fully transparent part. Re-running sweeps for parts that have
     streamed in since rather than restarting: Snapshot keeps the *first*
     recorded original, and a part we already revealed no longer reads as
     transparent, so the second pass can neither double-count nor corrupt the
     restore record. Returns newly revealed, total revealed. ]]
function M.showInvisible()
	if not feature:isRunning() then
		feature:start()
		local shown = feature.state.shown or 0
		return shown, shown
	end
	local more = sweep()
	feature.state.shown = (feature.state.shown or 0) + more
	return more, feature.state.shown
end

--[[ Put every revealed part back to the transparency the game gave it. Safe
     when `invisibleparts` was never run. ]]
function M.hideInvisible()
	local shown = feature.state.shown or 0
	feature:stop()
	return shown
end

function M.isRevealing() return feature:isRunning() end

return M
