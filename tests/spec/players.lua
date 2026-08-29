--[[ players: the target query engine, including the selectors that used to
     return nil and crash their callers. ]]

local ctx = ...
local expect, IY, env = ctx.expect, ctx.IY, ctx.env
local Players = IY.import("core/players")
local Target = IY.import("core/target")
local Services = IY.import("core/services")

local service = Services.Players
local me = Target.localTarget()
local roster = service:GetPlayers()

expect.ok(#roster >= 4, "stub server has players")

local function names(targets)
	local out = {}
	for i = 1, #targets do out[i] = targets[i].name end
	table.sort(out)
	return table.concat(out, ",")
end

-- ── defaults ────────────────────────────────────────────────────────────────
local mine = Players.resolve(nil, me)
expect.count(mine, 1, "no query resolves to the speaker")
expect.equal(mine[1].name, me.name, "speaker is the default target")
expect.count(Players.resolve("", me), 1, "empty query resolves to the speaker")

-- ── selectors ───────────────────────────────────────────────────────────────
expect.count(Players.resolve("all", me), #roster, "all covers the server")
expect.count(Players.resolve("others", me), #roster - 1, "others excludes the speaker")
expect.count(Players.resolve("me", me), 1, "me is one")

local randoms = Players.resolve("#2", me)
expect.count(randoms, 2, "#2 picks two")
local sampled = Players.resolve("#" .. tostring(#roster + 10), me)
expect.count(sampled, #roster, "#N clamps to the number of players")

local random = Players.resolve("random", me)
expect.count(random, 1, "random picks one")
expect.notEqual(random[1].name, me.name, "random never picks you")

expect.count(Players.resolve("alive", me), #roster, "everyone in the stub is alive")
expect.count(Players.resolve("dead", me), 0, "nobody is dead")

-- These four returned nil in the legacy resolver, and the caller then did
-- pairs(nil): `;goto nearest` alone in a server was a hard error.
expect.isType(Players.resolve("nearest", me), "table", "nearest returns a table")
expect.isType(Players.resolve("farthest", me), "table", "farthest returns a table")
expect.isType(Players.resolve("rad50", me), "table", "rad returns a table")
expect.isType(Players.resolve("cursor", me), "table", "cursor returns a table")
expect.isType(Players.resolve("npcs", me), "table", "npcs returns a table")
expect.isType(Players.resolve("bacons", me), "table", "bacons does not index a nil character")
expect.isType(Players.resolve("guests", me), "table", "guests returns a table")
expect.isType(Players.resolve("friends", me), "table", "friends returns a table")
expect.isType(Players.resolve("age30", me), "table", "ageN returns a table")
expect.isType(Players.resolve("group123", me), "table", "groupN returns a table")
expect.isType(Players.resolve("%red", me), "table", "team selector returns a table")

-- ── names ───────────────────────────────────────────────────────────────────
local byName = Players.resolve(me.name, me)
expect.count(byName, 1, "exact name matches one")
expect.equal(byName[1].name, me.name, "exact name resolves correctly")

local prefix = Players.resolve(string.sub(me.name, 1, 4), me)
expect.ok(#prefix >= 1, "prefix matching works")

-- Exact beats prefix: with "Bob" and "Bobby" present, ";kill bob" must hit Bob.
env.players.add("Bob")
env.players.add("Bobby")
local exact = Players.resolve("bob", me)
expect.count(exact, 1, "an exact name wins over a longer prefix match")
expect.equal(exact[1].name, "Bob", "exact match picked Bob, not Bobby")
expect.count(Players.resolve("bobb", me), 1, "prefix still reaches Bobby")

local viaAt = Players.resolve("@bob", me)
expect.count(viaAt, 1, "@name matches the account name")

expect.count(Players.resolve("nosuchplayer", me), 0, "unknown name matches nobody")

-- ── operators ───────────────────────────────────────────────────────────────
local without = Players.resolve("all-" .. me.name, me)
expect.count(without, #service:GetPlayers() - 1, "subtracting a name removes them")

local union = Players.resolve("Bob,Bobby", me)
expect.count(union, 2, "comma unions two groups")

-- The legacy resolver did not de-duplicate, so `;kill me,all` fired twice on you.
local overlap = Players.resolve("me,all", me)
expect.count(overlap, #service:GetPlayers(), "overlapping groups are de-duplicated")

local intersect = Players.resolve("all+" .. me.name, me)
expect.count(intersect, 1, "intersection narrows to one")

-- ── user ids ────────────────────────────────────────────────────────────────
local localPlayer = service.LocalPlayer
local byId = Players.resolve(tostring(localPlayer.UserId), me)
expect.count(byId, 1, "a bare number resolves as a user id")
expect.equal(byId[1].name, localPlayer.Name, "user id resolved to the right player")

-- ── require / requireOne ────────────────────────────────────────────────────
expect.succeeds(function() Players.require("all", me) end, "require succeeds with matches")
expect.raises(function() Players.require("nosuchplayer", me) end, "no player matched",
	"require raises a readable error")
expect.equal(Players.requireOne("me", me).name, me.name, "requireOne returns one target")

-- ── suggestions and help ────────────────────────────────────────────────────
local suggestions = Players.suggest("B")
expect.ok(#suggestions >= 2, "suggest offers names")
expect.ok(#Players.suggest("") > 0, "suggest with no partial offers everything")
local help = Players.selectorHelp()
expect.ok(#help >= 15, "every selector is documented")

-- ── targets stay live across a respawn ──────────────────────────────────────
local target = Players.resolve("me", me)[1]
local before = target.character
expect.ok(before ~= nil, "target has a character")
env.players.respawn(localPlayer)
env.scheduler.drain(500)
local after = target.character
expect.ok(after ~= nil, "target still has a character after respawning")
expect.notEqual(after, before, "the target now points at the new character")

-- ── cleanup ─────────────────────────────────────────────────────────────────
env.players.remove("Bob")
env.players.remove("Bobby")
env.scheduler.drain(200)
expect.count(Players.resolve("bob", me), 0, "a player who left no longer resolves")
