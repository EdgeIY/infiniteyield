--[[═══════════════════════════════════════════════════════════════════════════
	cmd/aliases · user-defined command aliases
	─────────────────────────────────────────────────────────────────────────
	The legacy version mapped an alias to a command *object*, so an alias could
	only ever be another name for a command -- `;addalias f fly` worked but
	`;addalias f fly 100` silently dropped the argument.

	Here an alias maps to a command *line*, expanded at parse time, and any
	arguments the user types are appended:

	    ;alias zoom fov 100      ->  ;zoom          == ;fov 100
	    ;alias k kill            ->  ;k bob         == ;kill bob

	Expansion is depth-limited, so an alias that refers to itself reports a
	cycle instead of hanging the client.
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Log    = IY.import("core/log")
local Signal = IY.import("core/signal")
local Guard  = IY.import("core/guard")
local Str    = IY.import("core/util/strings")
local Tbl    = IY.import("core/util/tables")

local M = {}

local MAX_DEPTH = 5

local map = {}      -- alias (lower) -> command line
M.map = map
M.changed = Signal.new("aliases.changed")

local function persist()
	local Store = IY.import("core/store")
	local list = {}
	for alias, command in pairs(map) do
		list[#list + 1] = { ALIAS = alias, CMD = command }
	end
	list = Tbl.sortBy(list, function(entry) return entry.ALIAS end)
	Store.set("aliases", list)
end

--[[ Load from the settings document, accepting both the legacy
     {ALIAS=,CMD=} shape and the newer {alias=,command=} one. ]]
function M.load()
	local Store = IY.import("core/store")
	local stored = Store.get("aliases") or {}
	for key in pairs(map) do map[key] = nil end
	for i = 1, #stored do
		local entry = stored[i]
		local alias = entry.ALIAS or entry.alias
		local command = entry.CMD or entry.command
		if type(alias) == "string" and type(command) == "string" then
			map[Str.lower(alias)] = command
		end
	end
	M.changed:Fire()
	return M.count()
end

function M.set(alias, command)
	alias = Str.lower(Str.trim(tostring(alias)))
	command = Str.trim(tostring(command))
	if alias == "" then Guard.fail("the alias cannot be empty") end
	if command == "" then Guard.fail("the alias needs a command to run") end
	if string.find(alias, "%s") then Guard.fail("an alias cannot contain spaces") end

	local Registry = IY.import("cmd/registry")
	if Registry.find(alias) then
		Guard.fail("'%s' is already a command", alias)
	end

	-- The target must resolve to something, or the alias is dead on arrival.
	local firstWord = string.match(command, "^%S+")
	if not Registry.find(firstWord) and not map[Str.lower(firstWord or "")] then
		Guard.fail("'%s' is not a command", tostring(firstWord))
	end

	map[alias] = command
	persist()
	M.changed:Fire()
	return true
end

function M.remove(alias)
	alias = Str.lower(Str.trim(tostring(alias)))
	if map[alias] == nil then return false end
	map[alias] = nil
	persist()
	M.changed:Fire()
	return true
end

function M.clear()
	local count = M.count()
	for key in pairs(map) do map[key] = nil end
	persist()
	M.changed:Fire()
	return count
end

function M.resolve(alias)
	return map[Str.lower(Str.trim(tostring(alias or "")))]
end

function M.count()
	return Tbl.count(map)
end

--[[ Ordered list for the alias editor panel. ]]
function M.list()
	local out = {}
	for alias, command in pairs(map) do
		out[#out + 1] = { alias = alias, command = command }
	end
	return Tbl.sortBy(out, function(entry) return entry.alias end)
end

--[[ Expand the first word of a raw command segment if it is an alias.
     Returns the expanded line, or nil when nothing matched. ]]
function M.expand(raw, depth)
	depth = depth or 0
	if depth >= MAX_DEPTH then
		Guard.fail("alias loop detected while expanding '%s'", tostring(raw))
	end
	local firstWord, rest = string.match(tostring(raw), "^(%S+)(.*)$")
	if not firstWord then return nil end
	local target = map[Str.lower(firstWord)]
	if not target then return nil end
	local expanded = target .. (rest or "")
	local deeper = M.expand(expanded, depth + 1)
	return deeper or expanded
end

function M.suggest(partial)
	local out = {}
	for alias in pairs(map) do
		if Str.matchesPrefix(alias, partial or "") then out[#out + 1] = alias end
	end
	table.sort(out)
	return out
end

return M
