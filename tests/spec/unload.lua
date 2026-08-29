--[[ unload: `;unloadiy` must genuinely leave nothing behind. This spec runs
     last because it tears the script down.

     The legacy `unloadiy` disconnected one table of UI connections and
     destroyed the ScreenGui. Everything else -- every feature loop, every
     metamethod hook, every changed engine property, every per-player
     adornment -- survived, which is why "unload then reload" was known to
     stack behaviour rather than reset it. ]]

local ctx = ...
local expect, IY, env = ctx.expect, ctx.IY, ctx.env

local Feature = IY.import("features/feature")
local Sched = IY.import("core/scheduler")
local Snapshot = IY.import("core/snapshot")
local Hooks = IY.import("core/hooks")
local Services = IY.import("core/services")
local Fly = IY.import("features/fly")
local Noclip = IY.import("features/noclip")

-- ── set up state that must be cleaned ───────────────────────────────────────
Noclip.start()
expect.ok(Noclip.isRunning(), "noclip is running before unload")

Snapshot.set(workspace, "Gravity", 1, "spec.unload")
expect.near(workspace.Gravity, 1, 1e-9, "the snapshot applied a value")
expect.ok(Snapshot.count() >= 1, "the snapshot registry has an entry")

local hookRegistered = Hooks.namecall("spec.unload.hook", function() end)
local hooksBefore = Hooks.snapshot()

Sched.interval("spec.unload.loop", 0.05, function() end)
expect.ok(Sched.isRunning("spec.unload.loop"), "a loop is running before unload")

env.scheduler.advance(0.2)

local featuresBefore = #Feature.active()
expect.ok(featuresBefore >= 1, "at least one feature is running before unload")

-- ── unload ──────────────────────────────────────────────────────────────────
local errors = IY.unload()
env.scheduler.drain(4000)
env.scheduler.advance(1)
env.scheduler.drain(4000)

expect.isType(errors, "table", "unload returns a list of teardown errors")
for i = 1, math.min(#errors, 20) do
	expect.ok(false, "teardown error in " .. tostring(errors[i].label) .. ": " .. tostring(errors[i].error))
end
expect.count(errors, 0, "every teardown callback completed")

-- ── nothing left running ────────────────────────────────────────────────────
expect.count(Feature.active(), 0, "no features are running after unload")
expect.notOk(Noclip.isRunning(), "noclip stopped")
expect.notOk(Fly.isRunning(), "fly is not running")
expect.count(Sched.snapshot(), 0, "no scheduler loops survive")
expect.notOk(Sched.isRunning("spec.unload.loop"), "the test loop was stopped")

-- ── properties restored ─────────────────────────────────────────────────────
expect.equal(Snapshot.count(), 0, "every recorded property was restored")

-- ── hooks removed ───────────────────────────────────────────────────────────
local hooksAfter = Hooks.snapshot()
local remaining = 0
for _, list in pairs(hooksAfter or {}) do
	if type(list) == "table" then remaining = remaining + #list end
end
expect.equal(remaining, 0, "no hook handlers are still registered")

-- ── the interface is gone ───────────────────────────────────────────────────
-- Only what IY created counts: a client may already have had a RobloxGui, and
-- `ui/lib` deliberately does not destroy a ScreenGui it did not make.
local Lib = IY.import("ui/lib")
if Lib.hostOwned then
	expect.equal(Lib.host and Lib.host.Parent or nil, nil, "the host ScreenGui we created was destroyed")
else
	expect.ok(true, "the host ScreenGui belongs to the client, so it stays")
end

local coreGui = Services.get("CoreGui")
local ours = 0
if coreGui then
	for _, child in ipairs(coreGui:GetChildren()) do
		if child:IsA("ScreenGui") and child.Name ~= "RobloxGui" then ours = ours + 1 end
	end
end
expect.equal(ours, 0, "no ScreenGui of ours left in CoreGui")

-- ── the global surface is cleared, so a reload starts fresh ─────────────────
expect.equal(env.globals.IY_LOADED, nil, "IY_LOADED cleared")
expect.equal(env.globals.IY, nil, "the global IY reference cleared")

-- ── the loop count did not grow after unload ────────────────────────────────
local ticksBefore = 0
local snapshot = Sched.snapshot()
for i = 1, #snapshot do ticksBefore = ticksBefore + snapshot[i].ticks end
env.scheduler.advance(1)
local snapshotAfter = Sched.snapshot()
expect.count(snapshotAfter, 0, "still no loops a second later")

-- ── background threads are quiet ────────────────────────────────────────────
local threadErrors = env.scheduler.errors or {}
local afterUnload = 0
for i = 1, #threadErrors do
	if threadErrors[i].afterUnload then afterUnload = afterUnload + 1 end
end
expect.equal(afterUnload, 0, "nothing errored after unload")
