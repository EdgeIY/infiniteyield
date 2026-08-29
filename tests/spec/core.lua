--[[ core: the load-bearing runtime modules, exercised directly.

     These are the pieces every feature depends on, so a regression here is a
     regression everywhere: the hook dispatcher, the property snapshot registry,
     the character lifecycle, and the JSON/filesystem layer under the settings. ]]

local ctx = ...
local expect, IY, env = ctx.expect, ctx.IY, ctx.env

local Hooks = IY.import("core/hooks")
local Snapshot = IY.import("core/snapshot")
local Character = IY.import("core/character")
local Json = IY.import("core/json")
local Fs = IY.import("core/fs")
local Env = IY.import("core/env")
local Sched = IY.import("core/scheduler")
local Services = IY.import("core/services")

-- ═══ hooks ══════════════════════════════════════════════════════════════════

expect.isType(Hooks.canHook, "function", "hooks reports whether it can hook")
expect.isType(Hooks.snapshot(), "table", "hooks snapshot is a table")

-- Registering the same id twice must replace, never stack: a command run twice
-- used to add a second permanent metamethod layer.
local first = Hooks.namecall("spec.hook", function() end)
local second = Hooks.namecall("spec.hook", function() end)
if Hooks.canHook() then
	expect.ok(first ~= false, "a namecall handler registers")
	expect.ok(second ~= false, "re-registering the same id succeeds")
	expect.ok(Hooks.isRegistered("spec.hook"), "the id is registered")
else
	expect.ok(true, "this environment cannot hook, and said so instead of erroring")
end
expect.succeeds(function() Hooks.unregister("spec.hook") end, "unregister runs")
expect.succeeds(function() Hooks.unregister("spec.neverregistered") end,
	"unregistering something that was never registered is safe")

-- ═══ snapshot ═══════════════════════════════════════════════════════════════

local probe = Instance.new("Part")
probe.Name = "SpecProbe"
probe.Transparency = 0
probe.Parent = workspace

expect.notOk(Snapshot.isModified(probe, "Transparency"), "nothing recorded yet")
expect.ok(Snapshot.set(probe, "Transparency", 0.5, "spec"), "set applies the value")
expect.near(probe.Transparency, 0.5, 1e-9, "the value was applied")
expect.equal(Snapshot.original(probe, "Transparency"), 0, "the original was recorded")
expect.ok(Snapshot.isModified(probe, "Transparency"), "the pair is marked modified")

-- Setting again must not overwrite the recorded original: that is the bug that
-- made `fakeout` restore the wrong FallenPartsDestroyHeight.
Snapshot.set(probe, "Transparency", 0.9, "spec")
expect.equal(Snapshot.original(probe, "Transparency"), 0, "the original is still the first value")

Snapshot.restore(probe, "Transparency")
expect.near(probe.Transparency, 0, 1e-9, "restore puts the original back")
expect.notOk(Snapshot.isModified(probe, "Transparency"), "the record is forgotten after restore")

Snapshot.set(probe, "Transparency", 0.3, "spec.tag")
Snapshot.set(probe, "CanCollide", false, "spec.tag")
local restored = Snapshot.restoreTag("spec.tag")
expect.ok((restored or 0) >= 2, "restoreTag restores everything under the tag")
expect.near(probe.Transparency, 0, 1e-9, "transparency restored by tag")

-- A destroyed instance must not make restore throw.
Snapshot.set(probe, "Transparency", 0.7, "spec.dead")
probe:Destroy()
expect.succeeds(function() Snapshot.restoreTag("spec.dead") end,
	"restoring a destroyed instance is safe")

-- ═══ character ══════════════════════════════════════════════════════════════

expect.ok(Character.get() ~= nil, "there is a character")
expect.ok(Character.root() ~= nil, "the root part is reachable")
expect.ok(Character.humanoid() ~= nil, "the humanoid is reachable")
expect.ok(Character.alive(), "the character is alive")
expect.equal(typeof(Character.position()), "Vector3", "position returns a Vector3")
expect.succeeds(function() Character.require() end, "require succeeds with a character")

local spawnCalls = 0
local connection = Character.onSpawn(function() spawnCalls = spawnCalls + 1 end)
expect.equal(spawnCalls, 1, "onSpawn fires immediately when a character exists")

env.players.respawn(Services.Players.LocalPlayer)
env.scheduler.drain(3000)
env.scheduler.advance(1)
env.scheduler.drain(3000)
expect.equal(spawnCalls, 2, "onSpawn fires again after a respawn")
connection:Disconnect()

-- reapply replaces on the same label instead of stacking, which is what stopped
-- the legacy features from accumulating CharacterAdded handlers.
local reapplyCalls = 0
Character.reapply("spec.reapply", function() reapplyCalls = reapplyCalls + 1 end)
Character.reapply("spec.reapply", function() reapplyCalls = reapplyCalls + 100 end)
env.players.respawn(Services.Players.LocalPlayer)
env.scheduler.drain(3000)
env.scheduler.advance(1)
env.scheduler.drain(3000)
expect.equal(reapplyCalls, 100, "only the latest handler for a label runs")
Character.cancelReapply("spec.reapply")

-- ═══ json ═══════════════════════════════════════════════════════════════════

local document = {
	text = "quotes \" and \\ and \n newline",
	number = -12.5,
	big = 2 ^ 40,
	yes = true,
	no = false,
	list = { 1, 2, 3 },
	nested = { deep = { deeper = { "value" } } },
	empty = Json.array({}),
}
local encoded = Json.encode(document)
expect.isType(encoded, "string", "encode produces a string")
local decoded = Json.decode(encoded)
expect.isType(decoded, "table", "decode round-trips")
expect.equal(decoded.text, document.text, "escapes survive the round trip")
expect.near(decoded.number, -12.5, 1e-9, "negative floats survive")
expect.equal(decoded.yes, true, "booleans survive")
expect.equal(#decoded.list, 3, "arrays survive")
expect.equal(decoded.nested.deep.deeper[1], "value", "nesting survives")

local bad, reason = Json.decode("{not json,,,}")
expect.equal(bad, nil, "malformed JSON decodes to nil")
expect.isType(reason, "string", "malformed JSON explains itself")

local cyclic = {}
cyclic.self = cyclic
expect.raises(function() Json.encode(cyclic) end, nil, "a cycle is rejected rather than hanging")
expect.raises(function() Json.encode({ value = math.huge }) end, nil,
	"infinity is rejected -- it is not valid JSON")

-- Pretty output must be deterministic, or every settings save looks like a diff.
local pretty = Json.encode(document, true)
expect.equal(Json.encode(document, true), pretty, "pretty encoding is stable")
expect.contains(pretty, "\n", "pretty output is multi-line")

-- ═══ filesystem ═════════════════════════════════════════════════════════════

expect.ok(Fs.available, "the stub filesystem is available")
expect.raises(function() Fs.path("../escape") end, nil, "path traversal is rejected")
expect.raises(function() Fs.path("/etc/passwd") end, nil, "absolute paths are rejected")
expect.raises(function() Fs.path("C:\\Windows") end, nil, "drive letters are rejected")

expect.ok(Fs.write("spec/probe.txt", "hello"), "write succeeds")
expect.equal(Fs.read("spec/probe.txt"), "hello", "read returns what was written")
expect.ok(Fs.exists("spec/probe.txt"), "exists reports true")
expect.ok(Fs.writeJSON("spec/probe.json", { a = 1 }), "writeJSON succeeds")
local readBack = Fs.readJSON("spec/probe.json")
expect.equal(readBack and readBack.a, 1, "readJSON round-trips")
expect.ok(Fs.delete("spec/probe.txt"), "delete succeeds")
expect.notOk(Fs.exists("spec/probe.txt"), "the file is gone")

-- queueWrite coalesces: three writes to one file become one underlying write
-- with the newest payload.
local before = Fs.stats.writes
Fs.queueWrite("spec/queued.txt", "one")
Fs.queueWrite("spec/queued.txt", "two")
Fs.queueWrite("spec/queued.txt", "three")
Fs.flush("spec/queued.txt")
expect.equal(Fs.read("spec/queued.txt"), "three", "the newest payload won")
expect.ok(Fs.stats.writes - before <= 2, "the writes were coalesced")
Fs.delete("spec/queued.txt")
Fs.delete("spec/probe.json")

-- ═══ capabilities ═══════════════════════════════════════════════════════════

expect.isType(Env.executor, "string", "the executor is identified")
expect.isType(Env.snapshot(), "table", "capabilities snapshot is a table")
expect.ok(Env.usable("writefile"), "writefile is usable in the harness")
expect.notOk(Env.usable("definitelynotacapability"), "an unknown capability is not usable")
expect.raises(function() Env.need("definitelynotacapability") end, nil,
	"need raises for a missing capability")

-- ═══ scheduler ══════════════════════════════════════════════════════════════

-- A loop that keeps throwing is stopped instead of erroring every frame forever.
local failures = 0
Sched.interval("spec.badloop", 0.02, function()
	failures = failures + 1
	error("always fails", 0)
end)
env.scheduler.advance(1)
expect.ok(failures >= 1, "the loop ran")
expect.ok(failures <= 6, "the loop was stopped after repeated failures (ran " .. tostring(failures) .. ")")
expect.notOk(Sched.isRunning("spec.badloop"), "the failing loop is no longer registered")

-- Starting a loop with a label that is already running replaces it.
local ticksA, ticksB = 0, 0
Sched.interval("spec.replace", 0.05, function() ticksA = ticksA + 1 end)
Sched.interval("spec.replace", 0.05, function() ticksB = ticksB + 1 end)
env.scheduler.advance(0.4)
expect.equal(ticksA, 0, "the first loop was replaced before it ticked")
expect.ok(ticksB > 0, "the replacement is running")
Sched.stop("spec.replace")
expect.notOk(Sched.isRunning("spec.replace"), "stop works")

local throttled = 0
for _ = 1, 5 do
	Sched.throttle("spec.throttle", 10, function() throttled = throttled + 1 end)
end
expect.equal(throttled, 1, "throttle allows one call per period")
