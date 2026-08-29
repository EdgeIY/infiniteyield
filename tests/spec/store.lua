--[[ store: settings validation, legacy migration and non-destructive recovery.
     The legacy loader overwrote a save file it could not parse, which is the
     worst bug in the original script -- one bad byte and your waypoints,
     keybinds and aliases were gone. ]]

local ctx = ...
local expect, IY, env = ctx.expect, ctx.IY, ctx.env
local Store = IY.import("core/store")
local Json = IY.import("core/json")
local Fs = IY.import("core/fs")

expect.ok(Fs.available, "the stub filesystem works")
expect.ok(Store.persistent, "store reports itself persistent")

-- ── defaults and typing ─────────────────────────────────────────────────────
expect.isType(Store.get("prefix"), "string", "prefix is a string")
expect.isType(Store.get("guiScale"), "number", "guiScale is a number")
expect.isType(Store.get("keepIY"), "boolean", "keepIY is a boolean")
expect.isType(Store.get("waypoints"), "table", "waypoints is a table")
expect.equal(typeof(Store.get("theme.shade1")), "Color3", "theme colours are Color3 values")

-- ── validation ──────────────────────────────────────────────────────────────
local ok, reason = Store.set("prefix", ";")
expect.ok(ok, "a valid prefix is accepted")
ok, reason = Store.set("prefix", "; ")
expect.notOk(ok, "a prefix with whitespace is rejected")
expect.isType(reason, "string", "rejection explains itself")
expect.equal(Store.get("prefix"), ";", "a rejected value does not mutate the store")

ok = Store.set("guiScale", 99)
expect.notOk(ok, "guiScale above the maximum is rejected")
expect.notOk(Store.set("guiScale", 0), "guiScale below the minimum is rejected")
expect.ok(Store.set("guiScale", 1.25), "an in-range guiScale is accepted")
expect.near(Store.get("guiScale"), 1.25, 1e-9, "guiScale round-trips")

expect.notOk(Store.set("espTransparency", 5), "espTransparency is clamped by schema")
expect.notOk(Store.set("keepIY", "yes"), "a string is not a boolean")

-- ── change notification ─────────────────────────────────────────────────────
local seen = {}
local connection = Store.changed:Connect(function(key, new, old)
	seen[#seen + 1] = { key = key, new = new, old = old }
end)
Store.set("espTransparency", 0.5)
expect.ok(#seen >= 1, "changed fires on set")
expect.equal(seen[#seen].key, "espTransparency", "changed reports the key")
connection:Disconnect()

local watched = {}
local watcher = Store.watch("prefix", function(value) watched[#watched + 1] = value end)
expect.count(watched, 1, "watch fires immediately with the current value")
Store.set("prefix", ":")
expect.count(watched, 2, "watch fires on change")
Store.set("prefix", ";")
if watcher and watcher.Disconnect then watcher:Disconnect() end

-- ── dotted paths ────────────────────────────────────────────────────────────
expect.ok(Store.set("theme.shade1", Color3.fromRGB(10, 20, 30)), "dotted set works")
local shade = Store.get("theme.shade1")
expect.near(shade.R * 255, 10, 1, "dotted get returns the new colour")

-- ── legacy migration ────────────────────────────────────────────────────────
local legacy = {
	prefix = "!",
	StayOpen = true,
	guiScale = 2,
	keepIY = false,
	espTransparency = 0.7,
	logsEnabled = true,
	jLogsEnabled = true,
	logsWebhook = "https://example.invalid/hook",
	aliases = { { ALIAS = "f", CMD = "fly" } },
	binds = { { COMMAND = "fly", KEY = "Enum.KeyCode.F", ISKEYUP = false } },
	spawnCmds = { { COMMAND = "fly", DELAY = 0 } },
	WayPoints = { { NAME = "spot", COORD = { 1, 2, 3 }, GAME = 12345 } },
	PluginsTable = { "thing.iy" },
	currentShade1 = { 0.1, 0.2, 0.3 },
	currentShade2 = { 0.2, 0.2, 0.2 },
	currentShade3 = { 0.3, 0.3, 0.3 },
	currentText1 = { 1, 1, 1 },
	currentText2 = { 0.5, 0.5, 0.5 },
	currentScroll = { 0.4, 0.4, 0.4 },
	eventBinds = "opaque",
}

local migrated, applied = Store.migrate(legacy)
expect.isType(migrated, "table", "migrate returns a document")
expect.ok((applied or 0) >= 1, "at least one migration applied")
expect.equal(migrated.prefix, "!", "prefix carried over")
expect.equal(migrated.stayOpen, true, "StayOpen -> stayOpen")
expect.equal(migrated.joinLogsEnabled, true, "jLogsEnabled -> joinLogsEnabled")
expect.isType(migrated.waypoints, "table", "WayPoints -> waypoints")
expect.equal(#migrated.waypoints, 1, "the waypoint survived")
expect.equal(migrated.waypoints[1].NAME, "spot", "waypoint shape unchanged on disk")
expect.isType(migrated.plugins, "table", "PluginsTable -> plugins")
expect.isType(migrated.spawnCommands, "table", "spawnCmds -> spawnCommands")
expect.isType(migrated.theme, "table", "the six colours became a theme table")
expect.equal(migrated.currentShade1, nil, "legacy colour keys are gone")

-- ── round trip through the real file ────────────────────────────────────────
expect.ok(Store.save(), "save succeeds")
local saved = Fs.read("IY_FE.iy") or env.fs.read("IY_FE.iy")
expect.isType(saved, "string", "the settings file exists on disk")
local decoded = Json.decode(saved or "")
expect.isType(decoded, "table", "the settings file is valid JSON")
expect.ok(decoded.prefix ~= nil, "scalar settings are written")
expect.isType(decoded.version, "number", "the document carries its schema version")
-- Written in the current schema shape (a `theme` group), not the legacy six
-- `current*` keys; the migration reads the old shape, it does not write it.
expect.isType(decoded.theme, "table", "colours are written as a theme group")
expect.isType(decoded.theme.shade1, "table", "each colour is an {r,g,b} array")
expect.equal(decoded.currentShade1, nil, "legacy colour keys are not written back")

-- Writing twice must produce identical bytes: users diff this file, and an
-- unstable key order made every save look like a change.
Store.save()
local again = Fs.read("IY_FE.iy") or env.fs.read("IY_FE.iy")
expect.equal(again, saved, "saving twice produces identical bytes")

-- A colour survives a full save/load cycle.
local before = Store.get("theme.shade2")
Store.save()
Store.load()
local after = Store.get("theme.shade2")
expect.near(after.R, before.R, 1 / 255, "colour red channel round-trips")
expect.near(after.G, before.G, 1 / 255, "colour green channel round-trips")
expect.near(after.B, before.B, 1 / 255, "colour blue channel round-trips")

-- ── unknown keys are preserved ──────────────────────────────────────────────
local document = Json.decode(saved or "") or {}
document.someFutureSetting = "keep me"
env.fs.write("IY_FE.iy", Json.encode(document))
Store.load()
Store.save()
local reloaded = Json.decode(env.fs.read("IY_FE.iy") or "") or {}
expect.equal(reloaded.someFutureSetting, "keep me",
	"a key from a newer build survives a save from this one")

-- ── a corrupt file is never destroyed ───────────────────────────────────────
env.fs.write("IY_FE.iy", "{this is not json,,,")
local loadOk = Store.load()
expect.notOk(loadOk == false and false, "load returns rather than raising on corrupt input")
expect.equal(env.fs.read("IY_FE.iy"), "{this is not json,,,",
	"the corrupt file is left exactly as it was")
expect.isType(env.fs.read("IY_FE.iy.corrupt") or env.fs.read("IY_FE.iy"), "string",
	"a recovery copy exists or the original is intact")
expect.isType(Store.get("prefix"), "string", "defaults are used after a corrupt load")

-- Restore a clean file so later specs are not affected.
env.fs.write("IY_FE.iy", Json.encode(document))
Store.load()
expect.isType(Store.get("prefix"), "string", "store recovered")
