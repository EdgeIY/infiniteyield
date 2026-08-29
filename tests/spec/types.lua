--[[ types: argument coercion and the errors it produces. ]]

local ctx = ...
local expect, IY = ctx.expect, ctx.IY
local Types = IY.import("cmd/types")
local Guard = IY.import("core/guard")

local function parse(typeName, raw, spec)
	local definition = Types.get(typeName)
	return definition.parse(raw, spec or {}, { speaker = IY.import("core/target").localTarget() })
end

local function userError(typeName, raw, spec)
	local ok, err = pcall(parse, typeName, raw, spec)
	if ok then return nil end
	local kind, message = Guard.classify(err)
	return kind, message
end

-- ── numbers ─────────────────────────────────────────────────────────────────
expect.equal(parse("number", "5"), 5, "integer string")
expect.near(parse("number", "-2.5"), -2.5, 1e-9, "negative float")
expect.equal(parse("number", "1e3"), 1000, "exponent")
expect.near(parse("number", "50%"), 0.5, 1e-9, "percentage")
expect.equal(parse("number", "1_000"), 1000, "underscore separators")
expect.equal(parse("number", "inf"), math.huge, "infinity")

local kind, message = userError("number", "fast")
expect.equal(kind, "user", "a bad number is a user error, not a crash")
expect.contains(message, "not a number", "message names the problem")

kind, message = userError("number", "5", { min = 10, name = "speed" })
expect.equal(kind, "user", "below minimum is a user error")
expect.contains(message, "at least", "minimum reported")

kind = userError("number", "5000", { max = 100 })
expect.equal(kind, "user", "above maximum is a user error")

-- ── integers ────────────────────────────────────────────────────────────────
expect.equal(parse("integer", "7"), 7, "integer")
expect.equal(userError("integer", "7.5"), "user", "fractional integer rejected")

-- ── booleans ────────────────────────────────────────────────────────────────
local truthy = { "true", "t", "1", "yes", "y", "on", "enable", "enabled", "ON", "True" }
for i = 1, #truthy do
	expect.equal(parse("boolean", truthy[i]), true, "truthy: " .. truthy[i])
end
local falsy = { "false", "f", "0", "no", "n", "off", "disable", "disabled" }
for i = 1, #falsy do
	expect.equal(parse("boolean", falsy[i]), false, "falsy: " .. falsy[i])
end
expect.equal(userError("boolean", "maybe"), "user", "nonsense boolean rejected")

-- ── text ────────────────────────────────────────────────────────────────────
expect.equal(parse("text", "  hello there  "), "hello there", "text is trimmed")
expect.equal(parse("string", "word"), "word", "string passthrough")
expect.equal(parse("string", "abcdef", { maxLength = 3 }), "abc", "maxLength truncates")
expect.equal(userError("string", "ab", { minLength = 3, name = "name" }), "user",
	"minLength enforced")

-- ── enums ───────────────────────────────────────────────────────────────────
local spec = { values = { "day", "night", "dawn" } }
expect.equal(parse("enum", "night", spec), "night", "exact enum value")
expect.equal(parse("enum", "NIGHT", spec), "night", "enum is case-insensitive")
expect.equal(parse("enum", "daw", spec), "dawn", "unambiguous prefix accepted")
kind, message = userError("enum", "noon", spec)
expect.equal(kind, "user", "unknown enum value rejected")
expect.contains(message, "day", "error lists the options")
expect.equal(userError("enum", "da", spec), "user", "ambiguous prefix rejected")

local mapped = { values = { { "on", 1 }, { "off", 0 } } }
expect.equal(parse("enum", "on", mapped), 1, "enum maps to a value")

-- ── keycodes ────────────────────────────────────────────────────────────────
expect.equal(parse("keycode", "f"), Enum.KeyCode.F, "single letter key")
expect.equal(parse("keycode", "LeftShift"), Enum.KeyCode.LeftShift, "named key")
expect.equal(userError("keycode", "notakey"), "user", "unknown key rejected")

-- ── vectors and colours ─────────────────────────────────────────────────────
local vector = parse("vector3", "1,2,3")
expect.near(vector.X, 1, 1e-9, "vector x")
expect.near(vector.Z, 3, 1e-9, "vector z")
expect.equal(userError("vector3", "1,2"), "user", "incomplete vector rejected")

local red = parse("color", "red")
expect.near(red.R, 1, 1e-6, "named colour")
local hex = parse("color", "#ff8800")
expect.near(hex.G, 136 / 255, 1e-3, "hex colour")
local rgb = parse("color", "255,0,0")
expect.near(rgb.R, 1, 1e-6, "rgb triple")
local unit = parse("color", "1,0.5,0")
expect.near(unit.G, 0.5, 1e-6, "unit triple")
expect.equal(userError("color", "burgundy"), "user", "unknown colour rejected")

-- ── durations ───────────────────────────────────────────────────────────────
expect.equal(parse("time", "5"), 5, "bare seconds")
expect.near(parse("time", "500ms"), 0.5, 1e-9, "milliseconds")
expect.equal(parse("time", "1m30s"), 90, "compound duration")
expect.equal(parse("time", "2h"), 7200, "hours")
expect.equal(userError("time", "soon"), "user", "nonsense duration rejected")

-- ── players ─────────────────────────────────────────────────────────────────
local targets = parse("players", "all")
expect.ok(#targets >= 4, "all resolves every stub player")
targets = parse("players", "me")
expect.count(targets, 1, "me resolves to one target")
expect.ok(targets[1].isLocal, "me is the local player")
expect.equal(userError("players", "nobodyhere"), "user", "unmatched query is a user error")

local single = parse("player", "TestPlayer")
expect.equal(single.name, "TestPlayer", "single player by name")

-- ── describe / usage text ───────────────────────────────────────────────────
expect.equal(Types.describe({ type = "number" }), "number", "number describes itself")
expect.equal(Types.describe({ type = "players" }), "players", "players describes itself")
expect.contains(Types.describe({ type = "enum", values = { "a", "b" } }), "a|b",
	"enum describes its options")

-- ── completion ──────────────────────────────────────────────────────────────
local suggestions = Types.complete({ type = "boolean" }, "o")
expect.ok(#suggestions >= 2, "boolean completes on/off")
suggestions = Types.complete({ type = "players" }, "Test")
expect.ok(#suggestions >= 1, "players completes names")
