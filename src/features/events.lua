--[[═══════════════════════════════════════════════════════════════════════════
	features/events · the event bus behind the event editor
	─────────────────────────────────────────────────────────────────────────
	Replaces the data half of source.ref.lua's `eventEditor` (2248-2301,
	2627-2641, 2731-2756) and the eight event sources at 4074 and 13162-13256.
	The interface half is ui/panels/events; this file has no idea a window
	exists, so event binds keep working when the UI fails to mount.

	    Events.register("OnSpawn", {{ Type = "Player", Name = "Player ($1)" }})
	    Events.bind("OnSpawn", { command = "fly", conditions = {0}, delay = 0 })
	    Events.fire("OnSpawn", "SomePlayer")
	    Events.list("OnSpawn")            -- the live array of bound commands
	    Events.changed:Connect(refresh)   -- the panel listens

	A bind is `{ command = "goto $1", conditions = {...}, delay = 0 }`. On disk
	it is still the legacy positional form -- `{ "goto $1", {1}, 0 }` under the
	`eventBinds` settings key, JSON-encoded into a string -- so a save file works
	in either build.

	Bugs fixed, all of them in the legacy fire path:

	  · 2289 wrapped the body in `pcall(task.spawn(fn))`, which passes pcall the
	    *thread* task.spawn returns rather than a function. The body therefore ran
	    unprotected and any error inside an event-bound command was swallowed by
	    the scheduler. Sched.spawn contains and logs it.
	  · argument substitution used the raw value as a gsub replacement, so a chat
	    message containing `%` raised "invalid use of '%'" and lost the event.
	  · a condition that could not be evaluated (a Number filter against a nil
	    argument) errored and stopped every later bind on the same event.
	  · 13211 fired OnKilled with `killedBy.Name`, the name of the ObjectValue --
	    always the literal "creator" -- instead of the killer it points at, so a
	    killer filter could never match anybody.
	  · OnChatted was only hooked for players who joined *after* the script ran,
	    and never for you, on the legacy chat service.
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Bin       = IY.import("core/bin")
local Character = IY.import("core/character")
local Guard     = IY.import("core/guard")
local Inst      = IY.import("core/util/instances")
local Json      = IY.import("core/json")
local Log       = IY.import("core/log")
local Platform  = IY.import("core/platform")
local Sched     = IY.import("core/scheduler")
local Selector  = IY.import("core/players")
local Services  = IY.import("core/services")
local Signal    = IY.import("core/signal")
local Store     = IY.import("core/store")
local Str       = IY.import("core/util/strings")
local Tbl       = IY.import("core/util/tables")

local log = Log.scope("features/events")

local Players = Services.Players

local M = {}

--[[ Fired as (name) after a bind is added, removed or loaded. In-place edits
     (the panel's own text boxes) persist through save() without firing, exactly
     as the legacy `onEdited` hook did, so a rebuild cannot steal focus. ]]
M.changed = Signal.new("events.changed")

local events  = {}          -- name -> { name, sets, commands }
local order   = {}          -- names in registration order
local bin     = Bin.new("features/events")
local primed  = false       -- has `eventBinds` been read yet
local writing = false       -- our own Store.set, so the watch can ignore it
local hooked  = false

M.events = events
M.order  = order

-- Cached because the test stubs and older clients have no TextChatService enums.
local INVALID_PERMISSIONS = Guard.try(function()
	return Enum.TextChatMessageStatus.InvalidTextChannelPermissions
end)

-- ── registration ────────────────────────────────────────────────────────────

--[[ Declare an event and the arguments it carries. `argSpecs` is the legacy
     `sets` array: { Type = "Player"|"String"|"Number", Name = ..., Default = ... }.
     Re-registering keeps the binds already loaded for that name. ]]
function M.register(name, argSpecs)
	name = tostring(name)
	local record = events[name]
	if not record then
		record = { name = name, sets = {}, commands = {} }
		events[name] = record
		order[#order + 1] = name
	end
	record.sets = argSpecs or {}
	return record
end

function M.get(name)
	return events[name]
end

function M.names()
	local out = {}
	for i = 1, #order do out[i] = order[i] end
	return out
end

-- ── binds ───────────────────────────────────────────────────────────────────

--[[ The value a condition starts at: 0 is "me only" for a player filter and
     "any" for the other two, which is what legacy defaultSettings produced. ]]
local function defaultConditions(record)
	local out = {}
	for i = 1, #record.sets do
		local set = record.sets[i]
		out[i] = set.Default or 0
	end
	return out
end
M.defaultConditions = defaultConditions

--[[ Accept both shapes: the named one this module uses and the positional one
     that is on disk. Missing conditions are filled with their default, so a
     save file written before an argument was added still loads. ]]
local function normalise(record, entry)
	if type(entry) ~= "table" then return nil end
	local command = entry.command or entry[1]
	if type(command) ~= "string" then return nil end
	local conditions = entry.conditions or entry[2]
	if type(conditions) ~= "table" then conditions = {} end
	local out = {}
	for i = 1, #record.sets do
		local value = conditions[i]
		if value == nil then value = record.sets[i].Default or 0 end
		out[i] = value
	end
	return {
		command    = command,
		conditions = out,
		delay      = tonumber(entry.delay or entry[3]) or 0,
	}
end
M.normalise = normalise

local prime                 -- defined with the persistence helpers below

function M.list(name)
	prime()
	local record = events[name]
	if not record then return {} end
	return record.commands
end

function M.count(name)
	return #M.list(name)
end

function M.bind(name, entry)
	prime()
	local record = events[name]
	if not record then Guard.fail("'%s' is not an event", tostring(name)) end
	local row = normalise(record, entry)
	if not row then Guard.fail("an event bind needs a command") end
	record.commands[#record.commands + 1] = row
	M.save()
	M.changed:Fire(name)
	return row
end

--[[ Remove by position in `list(name)`. Callers that hold a row resolve its
     index at the moment of the click (Tbl.find), because the legacy editor
     captured the loop index in its Delete handler -- deleting from another row
     first shifted every index below it and removed the wrong bind. ]]
function M.unbind(name, index)
	prime()
	local record = events[name]
	if not record then return nil end
	index = tonumber(index)
	if not index or record.commands[index] == nil then return nil end
	local row = table.remove(record.commands, index)
	M.save()
	M.changed:Fire(name)
	return row
end

function M.clear(name)
	prime()
	local record = events[name]
	if not record then return 0 end
	local removed = #record.commands
	record.commands = {}
	M.save()
	M.changed:Fire(name)
	return removed
end

-- ── persistence ─────────────────────────────────────────────────────────────

local function toDisk()
	local out = {}
	for i = 1, #order do
		local record = events[order[i]]
		local rows = {}
		for j = 1, #record.commands do
			local row = record.commands[j]
			rows[j] = Json.array({ row.command, Json.array(row.conditions), row.delay })
		end
		out[record.name] = Json.array(rows)
	end
	return out
end

--[[ Encode every event's binds and write them to the settings document. Returns
     the JSON string, which is what the legacy SaveData() handed to updatesaves. ]]
function M.save()
	prime()
	local ok, encoded = pcall(Json.encode, toDisk())
	if not ok then
		log.warn("could not encode event binds: %s", Guard.describe(encoded))
		return nil
	end
	writing = true
	local written, reason = Store.set("eventBinds", encoded)
	writing = false
	if not written then log.warn("could not save event binds: %s", tostring(reason)) end
	return encoded
end

--[[ Replace the binds of every event named in `data`, which may be the JSON
     string from the settings file or an already-decoded table. Events the file
     does not mention keep what they have, as legacy loadData did. ]]
function M.load(data)
	local decoded = data
	if type(data) == "string" then
		if Str.trim(data) == "" then return false end
		local ok, result = pcall(Json.decode, data)
		if not ok or type(result) ~= "table" then
			-- Legacy let this throw, which aborted the rest of the startup.
			log.warn("stored event binds are not valid JSON; ignoring them")
			return false
		end
		decoded = result
	end
	if type(decoded) ~= "table" then return false end

	for name, rows in pairs(decoded) do
		local record = events[name]
		if record and type(rows) == "table" then
			local out = {}
			for i = 1, #rows do
				local row = normalise(record, rows[i])
				if row then out[#out + 1] = row end
			end
			record.commands = out
		end
	end
	M.changed:Fire()
	return true
end

--[[ `spawnCommands` (legacy `spawnCmds`) is a pre-event-editor save format that
     nothing writes any more. Legacy re-appended it to OnSpawn on every single
     load; matching on the command text makes that idempotent. ]]
local function migrateSpawnCommands()
	local stored = Store.get("spawnCommands")
	local record = events["OnSpawn"]
	if type(stored) ~= "table" or #stored == 0 or not record then return 0 end
	local added = 0
	for i = 1, #stored do
		local raw = stored[i]
		local command = type(raw) == "table" and (raw.COMMAND or raw.command) or nil
		if type(command) == "string" and command ~= "" then
			local exists = false
			for j = 1, #record.commands do
				if record.commands[j].command == command then exists = true end
			end
			if not exists then
				record.commands[#record.commands + 1] = normalise(record, {
					command    = command,
					conditions = { 0 },
					delay      = tonumber(raw.DELAY or raw.delay) or 0,
				})
				added = added + 1
			end
		end
	end
	return added
end

--[[ Read the settings key once, lazily: a module imported before boot's
     settings phase would otherwise latch an empty document and save it back
     over the real one. ]]
local function loadFromStore(value)
	primed = true
	M.load(value)
	if migrateSpawnCommands() > 0 then M.save() end
end

function prime()
	if primed or not Store.loaded then return false end
	loadFromStore(Store.get("eventBinds"))
	return true
end
M.prime = prime

-- ── conditions ──────────────────────────────────────────────────────────────

--[[ 0 is you, 1 is anybody, anything else is a player selector expression --
     the same three cases the settings editor writes. ]]
local function playerMatches(condition, value)
	if condition == 1 or condition == "1" then return true end
	if condition == 0 or condition == "0" then
		local me = Players.LocalPlayer
		return me ~= nil and tostring(me) == value
	end
	local names = Selector.resolveNames(tostring(condition))
	return Tbl.contains(names, value)
end

--[[ Plain substring, not a Lua pattern: the legacy version passed the user's
     text straight to string.find, so a filter containing `(` or `%` raised
     "malformed pattern" and killed the event. ]]
local function stringMatches(condition, value)
	if condition == nil or condition == 0 or condition == "0" or condition == "" then
		return true
	end
	return string.find(Str.lower(tostring(value)), Str.lower(tostring(condition)), 1, true) ~= nil
end

local function numberMatches(condition, value)
	if condition == nil or condition == 0 or condition == "0" then return true end
	local limit, number = tonumber(condition), tonumber(value)
	if not limit or not number then return false end
	return number <= limit
end

local function matches(record, row, args)
	for i = 1, #record.sets do
		local kind = record.sets[i].Type
		local condition, value = row.conditions[i], args[i]
		local ok = true
		if kind == "Player" then
			ok = playerMatches(condition, value)
		elseif kind == "String" then
			ok = stringMatches(condition, value)
		elseif kind == "Number" then
			ok = numberMatches(condition, value)
		end
		if not ok then return false end
	end
	return true
end

-- ── firing ──────────────────────────────────────────────────────────────────

--[[ `$1`, `$2`, ... become the event's arguments. Backwards, so `$10` is not
     eaten by `$1`, and the replacement is escaped because a value containing a
     percent sign is not a valid gsub replacement string. ]]
local function substitute(line, args, count)
	for i = count, 1, -1 do
		if args[i] ~= nil then
			local replacement = (string.gsub(tostring(args[i]), "%%", "%%%%"))
			line = (string.gsub(line, "%$" .. tostring(i), replacement))
		end
	end
	return line
end
M.substitute = substitute

local function runRow(name, row, args, count)
	Sched.spawn("events." .. name, function()
		local line = substitute(row.command, args, count)
		-- Legacy safeguard: an event must not be able to load a plugin.
		if string.find(Str.lower(line), "plugin", 1, true) then return end
		task.wait(tonumber(row.delay) or 0)
		IY.import("cmd/dispatch").run(line, nil, { record = false })
	end)
end

--[[ Run every bind on `name` whose conditions the arguments satisfy. Returns
     how many were started. ]]
function M.fire(name, ...)
	prime()
	local record = events[name]
	if not record then return 0 end
	local count = select("#", ...)
	local args = { ... }
	local list = record.commands
	local ran = 0
	for i = 1, #list do
		local row = list[i]
		local ok, matched = Guard.call("events.match:" .. name, matches, record, row, args)
		if ok and matched then
			ran = ran + 1
			runRow(name, row, args, count)
		end
	end
	return ran
end

-- ── the eight sources ───────────────────────────────────────────────────────

local charBins   = {}       -- player -> bin holding this life's connections
local playerBins = {}       -- player -> bin holding the per-player connections

local function died(player, humanoid)
	M.fire("OnDied", tostring(player))
	local creator = humanoid and humanoid:FindFirstChild("creator")
	local killer = creator and creator.Value
	if killer and killer.Parent then
		M.fire("OnKilled", tostring(player), tostring(killer))
	end
end

--[[ Damage for every player, plus death for everybody but us (ours arrives
     through core/character, which already owns exactly one Died connection per
     life). Legacy opened a fresh HealthChanged connection per spawn and never
     closed the previous one. ]]
local function hookCharacter(player, character)
	if not character then return end
	local holder = charBins[player]
	if not holder then
		holder = bin:branch("life")
		charBins[player] = holder
	end
	holder:empty()
	holder:spawn(function()
		local humanoid = Inst.humanoid(character) or Inst.waitFor(character, "Humanoid", 10)
		if not humanoid or not humanoid:IsA("Humanoid") then return end
		local last = humanoid.Health
		holder:connect(humanoid.HealthChanged, function(health)
			if last > health then M.fire("OnDamage", tostring(player), tonumber(health)) end
			last = health
		end)
		if player ~= Players.LocalPlayer then
			holder:connect(humanoid.Died, function() died(player, humanoid) end)
		end
	end)
end

local function attachPlayer(player)
	local holder = playerBins[player]
	if not holder then
		holder = bin:branch("player")
		playerBins[player] = holder
	end

	if Platform.isLegacyChat then
		holder:connect(player.Chatted, function(message)
			M.fire("OnChatted", tostring(player), message)
		end)
	end

	if player ~= Players.LocalPlayer then
		holder:connect(player.CharacterAdded, function(character)
			M.fire("OnSpawn", tostring(player))
			hookCharacter(player, character)
		end)
		hookCharacter(player, player.Character)
	end
end

local function detachPlayer(player)
	if charBins[player] then charBins[player]:destroy() charBins[player] = nil end
	if playerBins[player] then playerBins[player]:destroy() playerBins[player] = nil end
end

--[[ The modern chat service reports everybody's messages, including ours, so no
     per-player connection is needed. Legacy 13233-13249. ]]
local function attachModernChat()
	local TextChatService = Services.get("TextChatService")
	if not TextChatService then return end
	bin:connect(TextChatService.MessageReceived, function(message)
		local source = message.TextSource
		if not source then return end
		if INVALID_PERMISSIONS and message.Status == INVALID_PERMISSIONS then return end
		local player = Players:GetPlayerByUserId(source.UserId)
		if not player then return end
		M.fire("OnChatted", tostring(player), message.Text)
	end)
end

--[[ Connect every source. Safe to call twice. ]]
function M.attach()
	if hooked then return false end
	hooked = true

	bin:connect(Players.PlayerAdded, function(player)
		M.fire("OnJoin", tostring(player))
		attachPlayer(player)
	end)

	bin:connect(Players.PlayerRemoving, function(player)
		M.fire("OnLeave", tostring(player))
		detachPlayer(player)
	end)

	-- Our own character, through the one lifecycle hub.
	bin:connect(Character.spawned, function(character)
		M.fire("OnSpawn", tostring(Players.LocalPlayer))
		hookCharacter(Players.LocalPlayer, character)
	end)
	bin:connect(Character.died, function(character)
		died(Players.LocalPlayer, Inst.humanoid(character))
	end)

	if not Platform.isLegacyChat then attachModernChat() end

	local list = Guard.try(function() return Players:GetPlayers() end) or {}
	for i = 1, #list do
		Guard.call("events.attach", attachPlayer, list[i])
	end
	hookCharacter(Players.LocalPlayer, Character.get())

	return true
end

-- ── the eight events ────────────────────────────────────────────────────────

-- Legacy 13163-13187, in the same order, which is the order the panel lists.
M.register("OnExecute")
M.register("OnSpawn", {
	{ Type = "Player", Name = "Player Filter ($1)" },
})
M.register("OnDied", {
	{ Type = "Player", Name = "Player Filter ($1)" },
})
M.register("OnDamage", {
	{ Type = "Player", Name = "Player Filter ($1)" },
	{ Type = "Number", Name = "Below Health ($2)" },
})
M.register("OnKilled", {
	{ Type = "Player", Name = "Victim Player ($1)" },
	{ Type = "Player", Name = "Killer Player ($2)", Default = 1 },
})
M.register("OnJoin", {
	{ Type = "Player", Name = "Player Filter ($1)", Default = 1 },
})
M.register("OnLeave", {
	{ Type = "Player", Name = "Player Filter ($1)", Default = 1 },
})
M.register("OnChatted", {
	{ Type = "Player", Name = "Player Filter ($1)", Default = 1 },
	{ Type = "String", Name = "Message Filter ($2)" },
})

--[[ An external write (a settings reset, another build's file) reloads rather
     than being clobbered by whatever this session holds. This is also what
     primes the list during a normal boot, because watch() fires immediately. ]]
bin:add(Store.watch("eventBinds", function(value)
	if writing or not Store.loaded then return end
	loadFromStore(value)
end))

Guard.call("features/events.attach", M.attach)

-- Legacy fired OnExecute at the very end of the script (13268); deferred by a
-- frame so the panel that imported us has finished mounting first.
bin:add(Sched.after(0, function()
	prime()
	M.fire("OnExecute")
end, "events.onexecute"))

IY.onUnload(function()
	bin:destroy()
	charBins, playerBins = {}, {}
	hooked = false
end, "features/events")

return M
