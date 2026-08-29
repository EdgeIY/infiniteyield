--[[═══════════════════════════════════════════════════════════════════════════
	core/store · the settings document
	─────────────────────────────────────────────────────────────────────────
	One typed, versioned, validated document, written atomically to the legacy
	path (IY_FE.iy in the workspace root, not in a subfolder) so that IY and
	older builds keep reading each other's settings.

	The schema is data, not code: every key declares its type, default, bounds,
	validator and the legacy disk name it was migrated from. That gives one
	place to add a setting, and it is what lets load() repair a single bad value
	instead of throwing the whole file away.

	Load is deliberately paranoid, because the legacy script's worst bug lived
	here -- a parse error made it *delete* the save file:

	  · missing file       -> write defaults
	  · unreadable/corrupt -> keep a copy as IY_FE.iy.corrupt, continue on
	                          defaults, and do not write over what is on disk
	  · unknown keys       -> preserved untouched in M.extra and written back,
	                          so a newer build's settings survive a downgrade
	  · one invalid value  -> that key falls back to its default and is logged;
	                          every other key is kept

	    Store.get("prefix")              Store.get("theme.shade1") -> Color3
	    Store.set("guiScale", 1.5)       -> false, reason when invalid
	    Store.watch("theme.shade1", fn)  -- fires now, then on every change
	    Store.changed:Connect(fn)        -- (key, new, old)

	Colours live on disk as {r,g,b} float arrays and in Lua as Color3; the
	schema layer converts in both directions. Saves are debounced by a second
	and flushed on unload, so dragging a colour picker is one write, not fifty.
	IY.boot must call Store.load(): save() refuses until it has, so a forgotten
	load cannot overwrite real settings with defaults.
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Log    = IY.import("core/log")
local Guard  = IY.import("core/guard")
local Signal = IY.import("core/signal")
local Sched  = IY.import("core/scheduler")
local Fs     = IY.import("core/fs")
local Json   = IY.import("core/json")

local log = Log.scope("core/store")

local find, format, gmatch, sub =
	string.find, string.format, string.gmatch, string.sub
local sort = table.sort

local M = {}

local SCHEMA_VERSION = 1

M.file          = "IY_FE.iy"
M.corruptFile   = "IY_FE.iy.corrupt"
M.schemaVersion = SCHEMA_VERSION
M.autosaveDelay = 1
M.changed       = Signal.new("store.changed")
M.extra         = {}          -- keys from another build, preserved verbatim
M.issues        = {}          -- key -> why its on-disk value was rejected
M.status        = "unloaded"
M.loaded        = false
M.dirty         = false
M.persistent    = Fs.available

-- ── value helpers ───────────────────────────────────────────────────────────

local function typeName(value)
	return (typeof and typeof(value)) or type(value)
end

--[[ Plain tables are copied; anything carrying a metatable (Color3 and other
     Roblox datatypes) is an opaque value and passed through untouched. ]]
local function deepCopy(value)
	if type(value) ~= "table" or getmetatable(value) ~= nil then return value end
	local out = {}
	for key, item in pairs(value) do out[key] = deepCopy(item) end
	return out
end

--[[ Fill keys `target` does not have from `source`, recursing into plain
     tables. Used to put unknown keys back on save without ever overwriting a
     value the schema produced. ]]
local function fillMissing(target, source)
	for key, value in pairs(source) do
		if target[key] == nil then
			target[key] = deepCopy(value)
		elseif type(target[key]) == "table" and type(value) == "table"
			and getmetatable(target[key]) == nil and getmetatable(value) == nil then
			fillMissing(target[key], value)
		end
	end
	return target
end

local function clamp01(value)
	if value < 0 then return 0 end
	if value > 1 then return 1 end
	return value
end

--[[ Accepts a Color3, the {r,g,b} form used on disk, or a {R=,G=,B=} table
     (what a plugin produces if it serialises a Color3 itself). ]]
local function toColor(value)
	if typeName(value) == "Color3" then return value end
	if type(value) == "table" then
		local r, g, b = value[1], value[2], value[3]
		if r == nil then
			r, g, b = value.R or value.r, value.G or value.g, value.B or value.b
		end
		if type(r) == "number" and type(g) == "number" and type(b) == "number" then
			return Color3.new(clamp01(r), clamp01(g), clamp01(b))
		end
	end
	return nil
end

local function fromColor(value)
	return { value.R, value.G, value.B }
end

local function isList(value)
	if type(value) ~= "table" then return false end
	local count = 0
	for key in pairs(value) do
		if type(key) ~= "number" or key % 1 ~= 0 or key < 1 then return false end
		count = count + 1
	end
	return count == #value
end

local function listOf(kind)
	return function(value)
		for i = 1, #value do
			if type(value[i]) ~= kind then
				return false, format("entry %d is a %s, expected a %s",
					i, type(value[i]), kind)
			end
		end
		return true
	end
end

-- ── schema ──────────────────────────────────────────────────────────────────

--[[ The six UI colours. `legacy` is the loose top-level key each was stored
     under before version 1 folded them into `theme`. ]]
local THEME = {
	shade1 = { type = "color", legacy = "currentShade1", default = Color3.fromRGB(24, 24, 24) },
	shade2 = { type = "color", legacy = "currentShade2", default = Color3.fromRGB(32, 32, 32) },
	shade3 = { type = "color", legacy = "currentShade3", default = Color3.fromRGB(42, 42, 42) },
	text1  = { type = "color", legacy = "currentText1",   default = Color3.fromRGB(255, 255, 255) },
	text2  = { type = "color", legacy = "currentText2",   default = Color3.fromRGB(175, 175, 175) },
	scroll = { type = "color", legacy = "currentScroll",  default = Color3.fromRGB(50, 50, 50) },
}

local SCHEMA = {
	prefix = {
		type = "string", default = ";", legacy = "prefix",
		-- A multi-character or whitespace prefix breaks the command parser, and
		-- the legacy script happily saved one.
		validate = function(value)
			if #value < 1 or #value > 3 then return false, "must be 1 to 3 characters" end
			if find(value, "%s") then return false, "cannot contain whitespace" end
			return true
		end,
	},
	stayOpen        = { type = "boolean", default = false, legacy = "StayOpen" },
	guiScale        = { type = "number",  default = 1, min = 0.5, max = 3, legacy = "guiScale" },
	keepIY          = { type = "boolean", default = true, legacy = "keepIY" },
	espTransparency = { type = "number",  default = 0.3, min = 0, max = 1, legacy = "espTransparency" },
	logsEnabled     = { type = "boolean", default = false, legacy = "logsEnabled" },
	joinLogsEnabled = { type = "boolean", default = false, legacy = "jLogsEnabled" },
	logsWebhook     = { type = "string",  default = nil, optional = true, legacy = "logsWebhook" },
	eventBinds      = { type = "string",  default = nil, optional = true, legacy = "eventBinds" },
	aliases         = { type = "array", default = {}, legacy = "aliases",      validate = listOf("table") },
	binds           = { type = "array", default = {}, legacy = "binds",        validate = listOf("table") },
	spawnCommands   = { type = "array", default = {}, legacy = "spawnCmds",    validate = listOf("table") },
	waypoints       = { type = "array", default = {}, legacy = "WayPoints",    validate = listOf("table") },
	plugins         = { type = "array", default = {}, legacy = "PluginsTable", validate = listOf("string") },
	theme           = { type = "table", fields = THEME },
	version         = { type = "number", default = SCHEMA_VERSION, min = 0 },
}

M.schema = SCHEMA

-- ── validation ──────────────────────────────────────────────────────────────

--[[ Returns true, converted value or false, reason. Never mutates its input,
     so a rejected set() cannot have changed anything. ]]
local function coerce(spec, value)
	if value == Json.null then value = nil end
	if value == nil then
		if spec.optional or spec.fields then return true, nil end
		return false, "a value is required"
	end
	local kind = spec.type
	if kind == "string" then
		if type(value) ~= "string" then
			return false, "expected a string, got " .. typeName(value)
		end
	elseif kind == "boolean" then
		if type(value) ~= "boolean" then
			return false, "expected true or false, got " .. typeName(value)
		end
	elseif kind == "number" then
		if type(value) ~= "number" or value ~= value then
			return false, "expected a number, got " .. typeName(value)
		end
		if spec.min and value < spec.min then
			return false, format("must be at least %s", tostring(spec.min))
		end
		if spec.max and value > spec.max then
			return false, format("must be at most %s", tostring(spec.max))
		end
	elseif kind == "color" then
		local colour = toColor(value)
		if not colour then return false, "expected a Color3 or {r,g,b}" end
		value = colour
	elseif kind == "array" then
		if not isList(value) then
			return false, "expected a list, got " .. typeName(value)
		end
		-- Copied on the way in: the caller keeping a reference to the list must
		-- not be able to edit stored settings afterwards.
		value = deepCopy(value)
	elseif kind == "table" then
		if type(value) ~= "table" then
			return false, "expected a table, got " .. typeName(value)
		end
	end
	if spec.validate then
		local ok, reason = spec.validate(value)
		if not ok then return false, reason or "failed validation" end
	end
	return true, value
end

local function defaultFor(spec)
	if spec.fields then
		local out = {}
		for name, child in pairs(spec.fields) do out[name] = defaultFor(child) end
		return out
	end
	return deepCopy(spec.default)
end

local function defaultDocument()
	local out = {}
	for key, spec in pairs(SCHEMA) do out[key] = defaultFor(spec) end
	return out
end

local doc = defaultDocument()

-- ── dotted paths ────────────────────────────────────────────────────────────

local function specFor(path)
	local spec, node = nil, SCHEMA
	for part in gmatch(tostring(path), "[^%.]+") do
		if type(node) ~= "table" then return nil end
		spec = node[part]
		if not spec then return nil end
		node = spec.fields
	end
	return spec
end

--[[ The table that holds the value, plus the final key: locate("theme.shade1")
     returns doc.theme, "shade1". ]]
local function locate(path)
	local container, field = doc, nil
	for part in gmatch(tostring(path), "[^%.]+") do
		if field then
			container = container[field]
			if type(container) ~= "table" then return nil end
		end
		field = part
	end
	if field == nil then return nil end
	return container, field
end

-- ── disk shape ──────────────────────────────────────────────────────────────

--[[ Lua value -> JSON-able value. Absent optional keys are written as an
     explicit null: HttpService drops null keys on decode, so core/json's null
     sentinel is what keeps `logsWebhook` present in the file at all. ]]
local function encodeStored(spec, value)
	if value == nil then return Json.null end
	if spec.type == "color" then return fromColor(value) end
	-- Tagged so an empty list stays [] instead of collapsing to {}.
	if spec.type == "array" then return Json.array(deepCopy(value)) end
	return value
end

local function toDisk(document)
	local out = {}
	for key, spec in pairs(SCHEMA) do
		if spec.fields then
			local group, value = {}, document[key] or {}
			for name, child in pairs(spec.fields) do
				group[name] = encodeStored(child, value[name])
			end
			out[key] = group
		else
			out[key] = encodeStored(spec, document[key])
		end
	end
	out.version = document.version or SCHEMA_VERSION
	-- Keys this build does not know about go back exactly as they were read, so
	-- running an older IY does not strip a newer one's settings.
	return fillMissing(out, M.extra)
end

--[[ Disk document -> typed document, plus the unknown keys to preserve and a
     map of the values that had to be replaced. A bad entry costs its own key's
     value and nothing else. ]]
local function fromDisk(raw)
	local out, extra, issues = {}, {}, {}

	local function decodeInto(target, specs, source, prefix)
		for key, spec in pairs(specs) do
			if spec.fields then
				local nested = type(source[key]) == "table" and source[key] or {}
				local group = {}
				decodeInto(group, spec.fields, nested, key .. ".")
				target[key] = group
				for name, value in pairs(nested) do
					if not spec.fields[name] then
						extra[key] = extra[key] or {}
						extra[key][name] = value
					end
				end
			else
				local value = source[key]
				if value == nil or value == Json.null then
					target[key] = defaultFor(spec)
				else
					local ok, result = coerce(spec, value)
					if ok then
						target[key] = result
					else
						issues[prefix .. key] = result
						target[key] = defaultFor(spec)
					end
				end
			end
		end
	end

	decodeInto(out, SCHEMA, raw, "")
	for key, value in pairs(raw) do
		if not SCHEMA[key] then extra[key] = value end
	end
	return out, extra, issues
end

-- ── migrations ──────────────────────────────────────────────────────────────

--[[ Migrations run on the *disk* document -- colours still arrays, keys still
     legacy names -- before anything is typed, so each step is a plain table
     rewrite and can be tested on its own. ]]
M.migrations = {
	-- No `version` key means a pre-modular save file: rename every key the
	-- schema knows a legacy name for, and fold the six loose colour arrays into
	-- the `theme` sub-table.
	[1] = function(raw)
		local out = {}
		for key, value in pairs(raw) do out[key] = value end
		for key, spec in pairs(SCHEMA) do
			if spec.legacy and spec.legacy ~= key and raw[spec.legacy] ~= nil then
				out[key] = raw[spec.legacy]
				out[spec.legacy] = nil
			end
		end
		local theme = type(out.theme) == "table" and out.theme or {}
		for name, spec in pairs(THEME) do
			if raw[spec.legacy] ~= nil then
				theme[name] = raw[spec.legacy]
				out[spec.legacy] = nil
			end
		end
		if next(theme) ~= nil then out.theme = theme end
		return out
	end,
}

--[[ Returns the migrated document and how many steps ran. Writing it back is
     load()'s job, so a caller can migrate a document it read itself. ]]
function M.migrate(raw)
	local from = tonumber(raw.version) or 0
	local applied = 0
	for target = from + 1, SCHEMA_VERSION do
		local step = M.migrations[target]
		if step then
			local ok, result = pcall(step, raw)
			if not ok then
				log.error("migration to version %d failed: %s", target, tostring(result))
				break
			end
			if type(result) == "table" then raw = result end
		end
		raw.version = target
		applied = applied + 1
	end
	return raw, applied
end

-- ── persistence ─────────────────────────────────────────────────────────────

local suppressSave = false

local function scheduleSave()
	M.dirty = true
	if suppressSave or not Fs.available then return end
	Sched.debounce("store.save", M.autosaveDelay, function() M.save() end)
end

function M.save()
	if not Fs.available then
		M.persistent = false
		return false, "filesystem unavailable"
	end
	if not M.loaded then
		-- The only reason M.loaded exists: saving before the first load would
		-- write defaults over settings nobody has read yet.
		log.warn("refusing to save before load() -- boot must load the store first")
		return false, "settings have not been loaded yet"
	end
	-- Serialisation is inside the pcall too: a plugin that reached into the
	-- document and left something unencodable there must not break saving.
	local ok, encoded = pcall(function() return Json.encode(toDisk(doc), true) end)
	if not ok then
		local reason = Guard.describe(encoded)
		log.error("could not encode settings: %s", reason)
		return false, reason
	end
	local written, err = Fs.writeAtomic(M.file, encoded)
	if not written then
		log.warn("could not save settings: %s", tostring(err))
		return false, err
	end
	M.dirty = false
	return true
end

function M.load()
	M.persistent = Fs.available
	M.issues = {}
	if not Fs.available then
		doc = defaultDocument()
		M.extra, M.status, M.loaded = {}, "memory", true
		log.warn("no filesystem: settings will apply now but will not survive a rejoin")
		return false, "filesystem unavailable"
	end
	local text, readErr = Fs.read(M.file)
	if text == nil then
		doc = defaultDocument()
		M.extra, M.loaded = {}, true
		if Fs.exists(M.file) == true then
			-- Present but unreadable: leave it alone and run on defaults.
			M.status = "unreadable"
			log.warn("settings file exists but could not be read (%s); using defaults",
				tostring(readErr))
			return false, readErr
		end
		M.status = "created"
		M.save()
		return true
	end
	local raw, parseErr = Json.decode(text)
	if type(raw) ~= "table" then
		-- Legacy IY deleted the file at this point, which is the single worst
		-- data-loss bug in it. Keep the bytes, start from defaults, and do not
		-- save until the user changes something.
		local copied, copyErr = Fs.write(M.corruptFile, text)
		doc = defaultDocument()
		M.extra, M.status, M.loaded = {}, "corrupt", true
		log.warn("settings file is not valid JSON (%s); kept a copy at %s and started from defaults%s",
			tostring(parseErr or ("unexpected " .. typeName(raw))), M.corruptFile,
			copied and "" or (" -- copy failed: " .. tostring(copyErr)))
		return false, parseErr or "settings file is not a JSON object"
	end
	local migrated, applied = M.migrate(raw)
	local issues
	doc, M.extra, issues = fromDisk(migrated)
	M.issues = issues
	for key, reason in pairs(issues) do
		log.warn("setting '%s' was invalid (%s); using the default", key, reason)
	end
	-- A newer build's version number is kept so that upgrading again does not
	-- re-run migrations over data that is already ahead of us.
	local diskVersion = tonumber(migrated.version) or 0
	if diskVersion > SCHEMA_VERSION then
		doc.version = diskVersion
		log.warn("settings were written by a newer IY (version %d); its extra keys are preserved",
			diskVersion)
	end
	M.loaded, M.status, M.dirty = true, "loaded", false
	if applied > 0 then
		log.info("migrated settings from version %d to %d", (tonumber(raw.version) or 0), SCHEMA_VERSION)
		M.save()
	end
	return true, issues
end

-- ── reading ─────────────────────────────────────────────────────────────────

--[[ Dotted paths work: get("theme.shade1") is a Color3. Tables come back live,
     so edit lists through set()/update() -- mutating what get() returns skips
     validation and autosave. raw() is the copy you can keep. ]]
function M.get(key)
	local container, field = locate(key)
	if container == nil then return nil end
	return container[field]
end

function M.raw()
	return deepCopy(doc)
end

function M.defaults()
	return defaultDocument()
end

-- ── writing ─────────────────────────────────────────────────────────────────

local setGroup      -- defined below; M.set delegates to it for `theme`

function M.set(key, value)
	local spec = specFor(key)
	if not spec then return false, format("unknown setting '%s'", tostring(key)) end
	if spec.fields then return setGroup(key, spec, value) end
	local ok, coerced = coerce(spec, value)
	if not ok then return false, coerced end
	local container, field = locate(key)
	if container == nil then return false, format("unknown setting '%s'", tostring(key)) end
	local old = container[field]
	-- Color3 compares by value, so re-applying the same theme is free.
	if old == coerced then return true end
	container[field] = coerced
	M.changed:Fire(key, coerced, old)
	scheduleSave()
	return true
end

--[[ Setting a whole group is all or nothing: every field is validated before any
     is applied, so one bad colour cannot leave half a theme behind. ]]
function setGroup(key, spec, value)
	if type(value) ~= "table" then
		return false, format("expected a table of %s fields", key)
	end
	local names, accepted = {}, {}
	for name in pairs(value) do names[#names + 1] = name end
	sort(names)
	for i = 1, #names do
		local name = names[i]
		local child = spec.fields[name]
		if not child then
			return false, format("unknown field '%s' in %s", tostring(name), key)
		end
		local ok, coerced = coerce(child, value[name])
		if not ok then return false, name .. ": " .. tostring(coerced) end
		accepted[name] = coerced
	end
	local container = M.get(key)
	local changes = 0
	for i = 1, #names do
		local name = names[i]
		local old = container[name]
		if old ~= accepted[name] then
			container[name] = accepted[name]
			changes = changes + 1
			M.changed:Fire(key .. "." .. name, accepted[name], old)
		end
	end
	if changes > 0 then scheduleSave() end
	return true
end

--[[ One save for the batch, one change event per key. Returns false plus a
     key -> reason map when any key was rejected; the rest still applied. ]]
function M.update(values)
	if type(values) ~= "table" then return false, "update expects a table of settings" end
	local keys = {}
	for key in pairs(values) do keys[#keys + 1] = key end
	sort(keys)
	local previous = suppressSave
	suppressSave = true
	local applied, failures = 0, nil
	for i = 1, #keys do
		local ok, reason = M.set(keys[i], values[keys[i]])
		if ok then
			applied = applied + 1
		else
			failures = failures or {}
			failures[keys[i]] = reason
		end
	end
	suppressSave = previous
	if applied > 0 then scheduleSave() end
	if failures then return false, failures end
	return true
end

--[[ Restore defaults for one key, or for the whole document. Unknown keys from
     another build are left alone -- they are not ours to reset. ]]
function M.reset(key)
	if key ~= nil then
		local spec = specFor(key)
		if not spec then return false, format("unknown setting '%s'", tostring(key)) end
		if spec.fields then return setGroup(key, spec, defaultFor(spec)) end
		local container, field = locate(key)
		if container == nil then return false, format("unknown setting '%s'", tostring(key)) end
		local old, value = container[field], defaultFor(spec)
		if old == value then return true end
		container[field] = value
		M.changed:Fire(key, value, old)
		scheduleSave()
		return true
	end
	local previous = doc
	doc = defaultDocument()
	-- Fire per key so listeners need no separate "everything changed" path.
	local keys = {}
	for name in pairs(SCHEMA) do keys[#keys + 1] = name end
	sort(keys)
	for i = 1, #keys do
		local name = keys[i]
		local spec = SCHEMA[name]
		local wasGroup = type(previous[name]) == "table" and previous[name] or {}
		if spec.fields then
			local fields = {}
			for field in pairs(spec.fields) do fields[#fields + 1] = field end
			sort(fields)
			for j = 1, #fields do
				M.changed:Fire(name .. "." .. fields[j], doc[name][fields[j]], wasGroup[fields[j]])
			end
		else
			M.changed:Fire(name, doc[name], previous[name])
		end
	end
	scheduleSave()
	return true
end

--[[ Subscribe to one key. Fires immediately with the current value so callers
     do not need to prime themselves, then on any change to that key, to a key
     inside it (theme -> theme.shade1) or to a group that contains it. ]]
function M.watch(key, fn)
	if type(fn) ~= "function" then
		Guard.fail("store.watch expects a function for '%s'", tostring(key))
	end
	if not specFor(key) then
		Guard.fail("cannot watch unknown setting '%s'", tostring(key))
	end
	local prefix = key .. "."
	local connection = M.changed:Connect(function(changed, _, old)
		if changed == key
			or sub(changed, 1, #prefix) == prefix
			or sub(prefix, 1, #changed + 1) == changed .. "."
		then
			fn(M.get(key), old, changed)
		end
	end)
	local ok, err = Guard.call("store.watch:" .. tostring(key), fn, M.get(key), nil, key)
	if not ok then
		log.warn("first callback for watch('%s') failed: %s", tostring(key), Guard.describe(err))
	end
	return connection
end

-- Saves are debounced, so unloading mid-window would drop the last change.
IY.onUnload(function()
	if M.dirty then M.save() end
end, "core/store")

IY.store = M
return M

