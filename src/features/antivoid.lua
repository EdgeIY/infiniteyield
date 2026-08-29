--[[═══════════════════════════════════════════════════════════════════════════
	features/antivoid · bounce off the kill plane, and the fakeout stunt
	─────────────────────────────────────────────────────────────────────────
	Replaces source.ref.lua 12608-12644 (antivoid, unantivoid, fakeout).

	`workspace.FallenPartsDestroyHeight` had four independent writers in the
	legacy script -- respawn() at 5000, `destroyheight` at 12604, and both
	commands here through the load-time global `OrgDestroyHeight` (12608). Two
	consequences:

	  · `fakeout` restored `OrgDestroyHeight`, the value the property held when
	    IY *loaded*, so once anyone had run `;dh` it handed back the wrong height
	    (12639).
	  · `antivoid` compared your altitude against that same stale global (12614),
	    so after `;dh -5000` it stopped catching you anywhere near the real plane.

	Every write here goes through core/snapshot, and the loop reads the live
	property each step, so the two commands and `;dh` can no longer disagree.
	core/character's respawn does the same thing for its void drop.

	`unantivoid` also could not throw any more: legacy wrapped
	`antivoidloop:Disconnect()` in a pcall precisely because it was nil until the
	command had been run once.
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Feature   = IY.import("features/feature")
local Character = IY.import("core/character")
local Guard     = IY.import("core/guard")
local Sched     = IY.import("core/scheduler")
local Services  = IY.import("core/services")
local Snapshot  = IY.import("core/snapshot")

local Workspace = Services.Workspace

-- Shared with core/character's void drop and with `;destroyheight`.
local TAG = "world"
local MARGIN = 25       -- how far above the plane the catch starts (legacy 12614)
local BOOST  = 250      -- upward velocity added per step (legacy 12615)
local HOLD   = 1        -- seconds spent "voided" during a fakeout (legacy 12637)

local M = {}

--[[ The live destroy height, or nil when it is not a usable number -- which is
     exactly the case while a fakeout is holding it at NaN, and the reason the
     loop stands down instead of comparing against NaN. ]]
local function liveHeight()
	local ok, value = pcall(function() return Workspace.FallenPartsDestroyHeight end)
	if not ok or type(value) ~= "number" or value ~= value then return nil end
	return value
end

--[[ Velocity is the deprecated spelling; assemblies want AssemblyLinearVelocity,
     and old clients only have the former. ]]
local function addVelocity(part, delta)
	local ok = pcall(function()
		part.AssemblyLinearVelocity = part.AssemblyLinearVelocity + delta
	end)
	if ok then return true end
	return pcall(function() part.Velocity = part.Velocity + delta end)
end

local feature = Feature.new("antivoid", {
	command  = "antivoid",
	describe = "caught above the kill plane",

	start = function(self)
		local lift = Vector3.new(0, BOOST, 0)
		-- The root is read per step, so a respawn needs no re-apply pass.
		self.bin:add(Sched.frameLoop("antivoid.step", function()
			local root = Character.root()
			if not root then return end
			local height = liveHeight()
			if not height then return end
			if root.Position.Y > height + MARGIN then return end
			addVelocity(root, lift)
		end, "stepped"))
	end,
})

M.feature = feature

function M.start(opts) return feature:start(opts or {}) end
function M.stop() return feature:stop() end
function M.toggle(opts) return feature:toggle(opts or {}) end
function M.isRunning() return feature:isRunning() end

-- ── destroy height ──────────────────────────────────────────────────────────

--[[ `;destroyheight` and `;fakeout` share this so the record -- and therefore
     what any later restore puts back -- belongs to whoever wrote first. ]]
function M.setHeight(value)
	local ok, reason = Snapshot.set(Workspace, "FallenPartsDestroyHeight", value, TAG)
	if not ok then Guard.fail("could not set the destroy height (%s)", tostring(reason)) end
	return true
end

function M.restoreHeight()
	return Snapshot.restore(Workspace, "FallenPartsDestroyHeight")
end

-- ── fakeout ─────────────────────────────────────────────────────────────────

--[[ Drop below the kill plane with part destruction switched off, then come
     back: to everyone else you fell out of the world and reappeared.

     Legacy read the position, stopped antivoid, wrote NaN, dropped to
     `OrgDestroyHeight - 25`, waited a second and wrote `OrgDestroyHeight` back
     (12628-12643). The height now comes from the live property and goes back
     through the snapshot record, and a watchdog guarantees it is restored even
     if this thread is cancelled part way through -- legacy left part
     destruction switched off for the rest of the session in that case. ]]
function M.fakeout()
	local root = Character.requireRoot()
	local height = liveHeight()
	if not height then
		Guard.fail("workspace.FallenPartsDestroyHeight is not a usable number right now")
	end
	local origin = root.CFrame

	local resume = feature:isRunning()
	if resume then feature:stop() end

	local finished = false
	local function finish()
		if finished then return end
		finished = true
		pcall(function() root.CFrame = origin end)
		M.restoreHeight()
		if resume then Guard.call("antivoid.resume", function() feature:start({}) end) end
	end

	local ok, reason = Snapshot.set(Workspace, "FallenPartsDestroyHeight", 0 / 0, TAG)
	if not ok then
		if resume then feature:start({}) end
		Guard.fail("could not switch part destruction off (%s)", tostring(reason))
	end

	Sched.after(HOLD + 2, finish, "antivoid.fakeout")
	pcall(function() root.CFrame = CFrame.new(Vector3.new(0, height - MARGIN, 0)) end)
	task.wait(HOLD)
	finish()
	return true
end

return M
