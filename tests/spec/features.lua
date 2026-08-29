--[[ features: the base class contract. Each assertion here corresponds to a
     class of bug that appeared repeatedly in the legacy command set. ]]

local ctx = ...
local expect, IY, env = ctx.expect, ctx.IY, ctx.env
local Feature = IY.import("features/feature")
local Bin = IY.import("core/bin")
local Sched = IY.import("core/scheduler")
local Character = IY.import("core/character")
local Services = IY.import("core/services")

local counters = { starts = 0, stops = 0, cleanups = 0, loopTicks = 0 }

local sample = Feature.new("spec.sample", {
	describe = "a test feature",
	start = function(self, opts)
		counters.starts = counters.starts + 1
		self.state.value = opts.value or "default"
		self.bin:add(function() counters.cleanups = counters.cleanups + 1 end)
		self.bin:add(Sched.interval("spec.sample.loop", 0.05, function()
			counters.loopTicks = counters.loopTicks + 1
		end))
	end,
	stop = function()
		counters.stops = counters.stops + 1
	end,
})

-- ── start / stop ────────────────────────────────────────────────────────────
expect.notOk(sample:isRunning(), "a new feature is not running")

-- Stopping something that never started must be a no-op, not an error. In the
-- legacy code this was `X:Disconnect()` on a nil in a dozen off-commands.
expect.succeeds(function() sample:stop() end, "stopping an idle feature is safe")
expect.equal(counters.stops, 0, "the stop body did not run for an idle feature")

sample:start({ value = "first" })
expect.ok(sample:isRunning(), "start marks it running")
expect.equal(counters.starts, 1, "start ran once")
expect.equal(sample.state.value, "first", "options reached the start body")
expect.ok(sample.bin:count() >= 2, "the bin is holding what start created")

-- Restarting must stop first, so two loops can never coexist. The legacy
-- `float` command stacked a part and five connections per invocation.
sample:start({ value = "second" })
expect.equal(counters.starts, 2, "restart started again")
expect.equal(counters.stops, 1, "restart stopped the previous run first")
expect.equal(counters.cleanups, 1, "the previous bin was emptied")
expect.equal(sample.state.value, "second", "new options applied")

-- Only one scheduler loop with that label can exist.
env.scheduler.advance(0.3)
local before = counters.loopTicks
env.scheduler.advance(0.3)
local rate = counters.loopTicks - before
expect.ok(rate > 0, "the loop is running")
expect.ok(rate < 20, "only one loop is running (got " .. tostring(rate) .. " ticks)")

sample:stop()
expect.notOk(sample:isRunning(), "stop clears the flag")
expect.equal(counters.stops, 2, "stop body ran")
expect.equal(counters.cleanups, 2, "the bin was emptied on stop")
expect.equal(sample.bin:count(), 0, "the bin is empty after stop")

local ticksAfterStop = counters.loopTicks
env.scheduler.advance(0.5)
expect.equal(counters.loopTicks, ticksAfterStop, "the loop stopped with the feature")

-- ── toggle ──────────────────────────────────────────────────────────────────
expect.ok(sample:toggle(), "toggle starts when idle")
expect.ok(sample:isRunning(), "toggle turned it on")
expect.notOk(sample:toggle(), "toggle stops when running")
expect.notOk(sample:isRunning(), "toggle turned it off")

-- ── a failing start must not leave it half-on ───────────────────────────────
local broken = Feature.new("spec.broken", {
	start = function() error("nope", 0) end,
})
expect.raises(function() broken:start() end, "nope", "a failing start propagates")
expect.notOk(broken:isRunning(), "a failed start leaves the feature off")
expect.equal(broken.bin:count(), 0, "a failed start leaves nothing in the bin")

-- ── configure ───────────────────────────────────────────────────────────────
local configured = {}
local tunable = Feature.new("spec.tunable", {
	start = function(self, opts) configured[#configured + 1] = opts.speed end,
	configure = function(self, opts) configured[#configured + 1] = opts.speed end,
})
tunable:start({ speed = 1 })
tunable:configure({ speed = 5 })
expect.count(configured, 2, "configure ran without restarting")
expect.equal(configured[2], 5, "configure received the patch")
expect.equal(tunable:option("speed"), 5, "option reads back the patched value")
expect.equal(tunable:option("missing", "fallback"), "fallback", "option falls back")
tunable:stop()

-- ── respawn re-application ──────────────────────────────────────────────────
local reapplied = 0
local persistent = Feature.new("spec.persistent", {
	reapply = true,
	start = function(self)
		reapplied = reapplied + 1
		self.bin:add(function() end)
	end,
})
persistent:start()
expect.equal(reapplied, 1, "started once")

env.players.respawn(Services.Players.LocalPlayer)
env.scheduler.drain(2000)
env.scheduler.advance(1)
env.scheduler.drain(2000)
expect.equal(reapplied, 2, "the feature re-applied itself after a respawn")
expect.ok(persistent:isRunning(), "still running after the respawn")

persistent:stop()
env.players.respawn(Services.Players.LocalPlayer)
env.scheduler.drain(2000)
expect.equal(reapplied, 2, "a stopped feature does not re-apply")

-- ── registry and diagnostics ────────────────────────────────────────────────
expect.ok(Feature.get("spec.sample") ~= nil, "features are registered by name")
expect.notOk(Feature.isRunning("spec.sample"), "isRunning reflects state")

sample:start({})
tunable:start({ speed = 2 })
local active = Feature.active()
expect.ok(#active >= 2, "active lists running features")

local snapshot = Feature.snapshot()
expect.ok(#snapshot >= 3, "snapshot covers every registered feature")
local found = false
for i = 1, #snapshot do
	if snapshot[i].name == "spec.sample" then
		found = true
		expect.ok(snapshot[i].running, "snapshot reports running state")
		expect.ok(snapshot[i].starts >= 1, "snapshot reports start count")
	end
end
expect.ok(found, "snapshot includes our feature")

-- ── stopAll ─────────────────────────────────────────────────────────────────
local stopped = Feature.stopAll()
expect.ok(#stopped >= 2, "stopAll stopped the running features")
expect.count(Feature.active(), 0, "nothing is running after stopAll")

-- ── bins ────────────────────────────────────────────────────────────────────
local bin = Bin.new("spec.bin")
local cleaned = 0
bin:add(function() cleaned = cleaned + 1 end)
bin:add(function() cleaned = cleaned + 1 end)
expect.equal(bin:count(), 2, "bin holds two items")
bin:empty()
expect.equal(cleaned, 2, "everything in the bin was cleaned")
expect.ok(bin:isEmpty(), "the bin is empty")

-- A bin that errors during cleanup keeps going.
local partial = Bin.new("spec.partial")
local ran = 0
partial:add(function() error("bad cleanup", 0) end)
partial:add(function() ran = ran + 1 end)
local errors = partial:empty()
expect.equal(ran, 1, "the other cleanups still ran")
expect.ok(errors ~= nil and #errors == 1, "the failure was reported")

-- Branches die with their parent but can be emptied alone.
local parent = Bin.new("spec.parent")
local branchCleaned = 0
local branch = parent:branch("child")
branch:add(function() branchCleaned = branchCleaned + 1 end)
expect.equal(parent:count(), 1, "the branch is held by the parent")
parent:empty()
expect.equal(branchCleaned, 1, "emptying the parent emptied the branch")

-- Adding to a destroyed bin cleans up immediately rather than leaking.
local dead = Bin.new("spec.dead")
dead:destroy()
local immediate = 0
dead:add(function() immediate = immediate + 1 end)
expect.equal(immediate, 1, "a dead bin cleans up on add")
