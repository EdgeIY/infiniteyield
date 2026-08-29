--[[ smoke: run every registered command once and prove none of them raise an
     *internal* error. A user error ("missing <players>") is a pass -- that is
     the framework doing its job. An internal error is a real bug, and in the
     legacy script it would have been invisible: the dispatcher's pcall only
     warned when a debug global happened to be set. ]]

local ctx = ...
local expect, IY, env = ctx.expect, ctx.IY, ctx.env
local Registry = IY.import("cmd/registry")
local Dispatch = IY.import("cmd/dispatch")
local Feature = IY.import("features/feature")
local Sched = IY.import("core/scheduler")
local Guard = IY.import("core/guard")

-- Commands that must not run in a test process: they end the session, teleport,
-- unload the script, or fetch and execute third-party code.
local SKIP = {}
for _, name in ipairs({
	"unloadiy", "unload", "killiy",
	"exit", "shutdown", "leave",
	"rejoin", "rj", "serverhop", "shop", "gametp", "gameteleport",
	"autorejoin", "autorj", "inviteprompt",
	"respawn", "refresh", "re", "reset",
	"console", "oldconsole", "explorer", "dex", "moondex", "mdex",
	"remotespy", "rspy", "cobalt", "cspy", "simplespy", "sspy",
	"audiologger", "alogger", "btools", "f3x", "fex", "wallwalk", "walkonwalls",
	"savegame", "saveplace", "rec", "record", "screenshot", "scrnshot",
	"debug", "iylog", "clearerror", "clearerrors",
	"addallplugins", "loadallplugins", "reloadplugin",
	"removecmd", "deletecmd", "clraliases",
	"jerk", "removeads", "adblock",
	"muteallvoices", "muteallvcs",
	"phonebook", "call",
	"cleargamewaypoints", "cgamewp", "clearwaypoints", "cwp",
	"clearbinds", "clearhats", "cleanhats", "clearcharappearance", "clearchar", "clrchar",
	"nilchar", "split", "noroot", "removeroot", "rroot", "chardelete", "charremove", "cd",
	"delete", "remove", "deleteclass", "removeclass", "lockws", "lockworkspace",
	"removeterrain", "rterrain", "noterrain", "clearnilinstances", "cni",
	"notools", "rtools", "clrtools", "removetools", "deletetools", "dtools",
	"deletehats", "nohats", "rhats", "drophats", "drophat", "droptools", "droptool",
	"god", "invisible", "invis", "toolinvisible", "toolinvis", "tinvis",
	"setfpscap", "fpscap", "maxfps", "antiafk", "antiidle",
	"setcreatorid", "setcreator",
}) do
	SKIP[name] = true
end

local failures = {}
local listener = Dispatch.failed:Connect(function(definition, err, kind)
	failures[#failures + 1] = {
		name = definition and definition.name or "?",
		kind = kind,
		message = Guard.describe(err),
	}
end)

local all = Registry.all(true)
local ran, skipped = 0, 0

for i = 1, #all do
	local definition = all[i]
	if SKIP[definition.name] then
		skipped = skipped + 1
	else
		ran = ran + 1
		-- Run with no arguments: every command must either work with its
		-- defaults or say what it needs.
		Guard.call("smoke", function()
			Dispatch.runSync(definition.name, nil, { silent = true })
		end)
		-- Let anything the command spawned settle before the next one.
		env.scheduler.drain(400)
	end
end

env.scheduler.advance(0.5)
env.scheduler.drain(4000)
listener:Disconnect()

-- ── results ─────────────────────────────────────────────────────────────────
local internal, user, capability = {}, 0, 0
for i = 1, #failures do
	local entry = failures[i]
	if entry.kind == "internal" then
		internal[#internal + 1] = entry
	elseif entry.kind == "capability" then
		capability = capability + 1
	else
		user = user + 1
	end
end

io.write(string.format("    smoke: ran %d, skipped %d -- %d user errors, %d capability, %d internal\n",
	ran, skipped, user, capability, #internal))

for i = 1, math.min(#internal, 40) do
	expect.ok(false, "internal error in ;" .. internal[i].name .. " -- " .. tostring(internal[i].message))
end
expect.equal(#internal, 0, "no command raised an internal error")

-- Errors raised on background threads would not surface through the dispatcher.
local threadErrors = env.scheduler.errors or {}
for i = 1, math.min(#threadErrors, 20) do
	expect.ok(false, "background thread error: " .. tostring(threadErrors[i].message))
end

-- ── second pass: run everything again, with plausible arguments ─────────────
-- The first pass leaves the ~100 commands that need arguments untested, which
-- is exactly where a nil index or a string-where-a-number-was-expected hides.
-- Synthesise a value per argument type and run them all again.

local SAMPLES = {
	players   = "me",
	player    = "me",
	number    = "1",
	integer   = "1",
	boolean   = "true",
	string    = "test",
	text      = "test",
	raw       = "test",
	keycode   = "f",
	vector3   = "0,0,0",
	color     = "red",
	time      = "1",
	class     = "Part",
	command   = "jump",
	waypoint  = "smokewaypoint",
	tool      = "test",
}

local function sampleFor(spec)
	if spec.type == "enum" then
		local values = spec.values or {}
		local first = values[1]
		if first == nil then return nil end
		return tostring(type(first) == "table" and first[1] or first)
	end
	if spec.type == "enumitem" then
		if not spec.enum then return nil end
		local items = spec.enum:GetEnumItems()
		return items[1] and items[1].Name or nil
	end
	if spec.min then
		-- Respect the declared range so the run is not rejected on bounds.
		local value = spec.min
		if spec.max and spec.max > spec.min then value = spec.min + (spec.max - spec.min) / 2 end
		return tostring(value)
	end
	return SAMPLES[spec.type]
end

-- Give the waypoint sample something real to find.
local Waypoints = IY:tryImport("features/waypoints")
if Waypoints and Waypoints.add then
	Guard.call("smoke.waypoint", function()
		Waypoints.add("smokewaypoint", CFrame.new(0, 10, 0))
	end)
end

local argued = {}
local arguedListener = Dispatch.failed:Connect(function(definition, err, kind)
	argued[#argued + 1] = {
		name = definition and definition.name or "?",
		kind = kind,
		message = Guard.describe(err),
	}
end)

local withArgs, unsupported = 0, 0
for i = 1, #all do
	local definition = all[i]
	if not SKIP[definition.name] and #definition.args > 0 then
		local parts = { definition.name }
		local complete = true
		for a = 1, #definition.args do
			local sample = sampleFor(definition.args[a])
			if sample == nil then
				complete = false
				break
			end
			parts[#parts + 1] = sample
		end
		if complete then
			withArgs = withArgs + 1
			Guard.call("smoke.args", function()
				Dispatch.runSync(table.concat(parts, " "), nil, { silent = true })
			end)
			env.scheduler.drain(400)
		else
			unsupported = unsupported + 1
		end
	end
end

env.scheduler.advance(0.5)
env.scheduler.drain(4000)
arguedListener:Disconnect()

local arguedInternal, arguedUser = {}, 0
for i = 1, #argued do
	if argued[i].kind == "internal" then
		arguedInternal[#arguedInternal + 1] = argued[i]
	else
		arguedUser = arguedUser + 1
	end
end

io.write(string.format("    smoke: re-ran %d with generated arguments (%d skipped for an untypeable argument)"
	.. " -- %d rejected, %d internal\n", withArgs, unsupported, arguedUser, #arguedInternal))

for i = 1, math.min(#arguedInternal, 40) do
	expect.ok(false, "internal error in ;" .. arguedInternal[i].name
		.. " (with arguments) -- " .. tostring(arguedInternal[i].message))
end
expect.equal(#arguedInternal, 0, "no command raised an internal error when given arguments")

-- ── leave the process clean for the unload spec ─────────────────────────────
local stopped = Feature.stopAll()
io.write(string.format("    smoke: stopped %d features started by the sweep\n", #stopped))
Sched.stopAll()
env.scheduler.drain(4000)

expect.count(Feature.active(), 0, "no features left running after the sweep")
expect.count(Sched.snapshot(), 0, "no scheduler loops left running after the sweep")
