--[[═══════════════════════════════════════════════════════════════════════════
	cmd/registry · the command store
	─────────────────────────────────────────────────────────────────────────
	One command is one table. The registry validates it, indexes it, derives
	everything the rest of the script needs from it (usage text, the UI list
	entry, autocomplete, docs), and -- when the command declares an `off`
	handler -- generates the `un`/`no`/`toggle` variants automatically.

	That last part removes a third of the legacy command count. `fly` used to be
	four separate `addcmd` blocks (`fly`, `unfly`, `togglefly`, plus `flyspeed`)
	each repeating the same target resolution and the same state flag. Now:

	    Cmd.register{
	        name = "fly", aliases = {"f"}, category = "Movement",
	        description = "Fly with your movement keys.",
	        args = {{ name = "speed", type = "number", optional = true }},
	        run = function(ctx) Fly.start(ctx.args.speed) end,
	        off = function(ctx) Fly.stop() end,
	    }

	and `unfly`, `nofly` and `togglefly` exist, are documented, appear in the
	command list, and stay in sync forever.

	Collisions are never silent. The legacy script shipped `setwaypoint` as both
	a command name and an alias of `waypointpos`, so one of them was
	unreachable depending on table order; here the second registration is
	rejected with a diagnostic, and tools/check.py fails the build on it.
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Log    = IY.import("core/log")
local Signal = IY.import("core/signal")
local Str    = IY.import("core/util/strings")
local Tbl    = IY.import("core/util/tables")
local Types  = IY.import("cmd/types")

local M = {}

local commands = {}     -- ordered array of definitions
local byName   = {}     -- name/alias (lowercase) -> definition
local owners   = {}     -- definition -> owner tag (plugin id or module)

M.commands = commands
M.changed  = Signal.new("registry.changed")

local VALID_NAME = "^[%w_%.]+$"

-- ═══ validation ═════════════════════════════════════════════════════════════

local function fail(context, message, ...)
	local detail = select("#", ...) > 0 and string.format(message, ...) or message
	error("[iy] invalid command '" .. tostring(context) .. "': " .. detail, 0)
end

--[[ Normalise and validate one argument spec. ]]
local function normaliseArg(commandName, spec, index, seenOptional)
	if type(spec) ~= "table" then
		fail(commandName, "argument #%d must be a table", index)
	end
	spec.name = spec.name or ("arg" .. index)
	spec.type = spec.type or "string"
	if not Types.exists(spec.type) then
		fail(commandName, "argument '%s' has unknown type '%s'", spec.name, tostring(spec.type))
	end
	local definition = Types.get(spec.type)
	spec.greedy = spec.greedy
	if spec.greedy == nil then spec.greedy = definition.greedy or false end
	spec.multi = definition.multi or false

	-- Target arguments are optional unless the command says otherwise: the
	-- legacy `getPlayer(args[1], speaker)` resolved a missing argument to the
	-- speaker, so `;speed` on its own worked. A command that genuinely needs a
	-- target sets `optional = false`.
	if spec.optional == nil and definition.optionalByDefault then
		spec.optional = true
	end

	if spec.default ~= nil then spec.optional = true end
	spec.optional = spec.optional == true
	if spec.optional then
		if spec.default == nil and definition.defaultWhenOptional ~= nil then
			spec.default = definition.defaultWhenOptional
		end
		return spec, true
	end
	if seenOptional then
		fail(commandName, "required argument '%s' cannot follow an optional one", spec.name)
	end
	return spec, false
end

--[[ Build the usage string: `speed <players> [speed]`. ]]
local function buildUsage(definition)
	local parts = { definition.name }
	local args = definition.args
	for i = 1, #args do
		local spec = args[i]
		local label = spec.name
		if spec.optional then
			parts[#parts + 1] = "[" .. label .. "]"
		else
			parts[#parts + 1] = "<" .. label .. ">"
		end
	end
	return table.concat(parts, " ")
end

--[[ The one-line signature shown in the command list, with type hints. ]]
local function buildSignature(definition)
	local parts = { definition.name }
	local args = definition.args
	for i = 1, #args do
		local spec = args[i]
		local hint = Types.describe(spec)
		local label = spec.name
		if hint ~= label then label = label .. ": " .. hint end
		if spec.default ~= nil and type(spec.default) ~= "function" then
			label = label .. " = " .. tostring(spec.default)
		end
		parts[#parts + 1] = spec.optional and ("[" .. label .. "]") or ("<" .. label .. ">")
	end
	return table.concat(parts, " ")
end

-- ═══ registration ═══════════════════════════════════════════════════════════

local function claim(key, definition)
	key = Str.lower(key)
	local existing = byName[key]
	if existing then
		if existing == definition then return true end
		IY:diagnostic("command-collision",
			"'" .. key .. "' is already registered by '" .. existing.name .. "'")
		return false
	end
	byName[key] = definition
	return true
end

--[[ Register a command. Returns the normalised definition. ]]
function M.add(input, owner)
	if type(input) ~= "table" then
		error("[iy] Cmd.register expects a table", 2)
	end

	local definition = Tbl.copy(input)
	local name = definition.name
	if type(name) ~= "string" or name == "" then
		fail("?", "missing name")
	end
	definition.name = Str.lower(name)
	if not string.match(definition.name, VALID_NAME) then
		fail(name, "name must be alphanumeric")
	end
	if type(definition.run) ~= "function" then
		fail(name, "missing run function")
	end

	definition.aliases     = definition.aliases or {}
	definition.category    = definition.category or "Misc"
	definition.description = definition.description or ""
	definition.tags        = definition.tags or {}
	definition.args        = definition.args or {}
	definition.requires    = definition.requires or {}
	definition.hidden      = definition.hidden == true
	definition.examples    = definition.examples or {}

	local seenOptional = false
	for i = 1, #definition.args do
		local spec, optional = normaliseArg(definition.name, definition.args[i], i, seenOptional)
		definition.args[i] = spec
		seenOptional = seenOptional or optional
		if spec.greedy and i ~= #definition.args then
			fail(definition.name, "greedy argument '%s' must be last", spec.name)
		end
	end

	definition.usage     = definition.usage or buildUsage(definition)
	definition.signature = buildSignature(definition)
	definition.owner     = owner or "core"

	if not claim(definition.name, definition) then
		return nil
	end
	local acceptedAliases = {}
	for i = 1, #definition.aliases do
		local alias = Str.lower(tostring(definition.aliases[i]))
		if alias ~= "" and claim(alias, definition) then
			acceptedAliases[#acceptedAliases + 1] = alias
		end
	end
	definition.aliases = acceptedAliases

	commands[#commands + 1] = definition
	owners[definition] = definition.owner

	-- Derive the off / toggle siblings.
	if type(definition.off) == "function" and definition.generated ~= true then
		M.addOffVariants(definition, owner)
	end

	M.changed:Fire("added", definition)
	return definition
end

--[[ Create `un<name>` (+ `no<name>` alias) and `toggle<name>` for a command
     that declares `off`. Anything the author explicitly registered wins: if a
     command called `unfly` already exists, the generated one is skipped. ]]
function M.addOffVariants(definition, owner)
	local base = definition.name
	local offArgs = definition.offArgs or definition.args

	if not byName["un" .. base] then
		local aliases = {}
		if not byName["no" .. base] then aliases[#aliases + 1] = "no" .. base end
		for i = 1, #(definition.offAliases or {}) do
			aliases[#aliases + 1] = definition.offAliases[i]
		end
		M.add({
			name        = "un" .. base,
			aliases     = aliases,
			category    = definition.category,
			description = definition.offDescription or ("Turns off " .. base .. "."),
			args        = offArgs,
			requires    = definition.offRequires or {},
			generated   = true,
			generatedFrom = base,
			hidden      = definition.hidden,
			run         = definition.off,
		}, owner)
	end

	if definition.toggle ~= false and not byName["toggle" .. base] then
		M.add({
			name        = "toggle" .. base,
			category    = definition.category,
			description = "Toggles " .. base .. " on or off.",
			args        = offArgs,
			generated   = true,
			generatedFrom = base,
			hidden      = definition.hidden,
			run         = function(ctx)
				local Dispatch = IY.import("cmd/dispatch")
				if Dispatch.isActive(base) then
					local result = definition.off(ctx)
					Dispatch.setActive(base, false)
					return result
				end
				local result = definition.run(ctx)
				Dispatch.setActive(base, true)
				return result
			end,
		}, owner)
	end
end

--[[ Look up by canonical name or alias. User aliases are *not* resolved here:
     they can carry arguments ("jf" -> "fly 100"), so the dispatcher expands
     them at parse time instead. ]]
function M.find(query)
	if type(query) ~= "string" then return nil end
	return byName[Str.lower(Str.trim(query))]
end

function M.exists(query)
	return M.find(query) ~= nil
end

--[[ Remove a command and everything it generated. ]]
function M.remove(query)
	local definition = M.find(query)
	if not definition then return false end
	for key, value in pairs(byName) do
		if value == definition then byName[key] = nil end
	end
	Tbl.removeValue(commands, definition)
	owners[definition] = nil
	-- Generated siblings go with it.
	for i = #commands, 1, -1 do
		if commands[i].generatedFrom == definition.name then
			M.remove(commands[i].name)
		end
	end
	M.changed:Fire("removed", definition)
	return true
end

--[[ Remove every command owned by a tag (used when unloading a plugin). ]]
function M.removeOwner(owner)
	local removed = 0
	for i = #commands, 1, -1 do
		if commands[i].owner == owner then
			M.remove(commands[i].name)
			removed = removed + 1
		end
	end
	return removed
end

--[[ Replace a command's implementation, keeping its metadata. ]]
function M.override(query, fn)
	local definition = M.find(query)
	if not definition then return false end
	definition.run = fn
	M.changed:Fire("changed", definition)
	return true
end

--[[ Disable without removing: the command stays listed but explains itself. ]]
function M.setEnabled(query, enabled, reason)
	local definition = M.find(query)
	if not definition then return false end
	definition.disabled = not enabled
	definition.disabledReason = reason
	M.changed:Fire("changed", definition)
	return true
end

-- ═══ queries ════════════════════════════════════════════════════════════════

function M.all(includeHidden)
	if includeHidden then return commands end
	return Tbl.filter(commands, function(definition) return not definition.hidden end)
end

function M.count()
	return #commands
end

function M.categories()
	local seen, out = {}, {}
	for i = 1, #commands do
		local category = commands[i].category
		if not seen[category] then
			seen[category] = true
			out[#out + 1] = category
		end
	end
	table.sort(out)
	return out
end

function M.byCategory(category)
	return Tbl.filter(commands, function(definition)
		return definition.category == category and not definition.hidden
	end)
end

--[[ Names and aliases starting with `partial`, ranked: exact prefix on the
     canonical name first, then aliases, then fuzzy matches. ]]
function M.suggest(partial, limit)
	local needle = Str.lower(Str.trim(partial or ""))
	limit = limit or 12
	local names, aliases, fuzzy = {}, {}, {}

	for i = 1, #commands do
		local definition = commands[i]
		if not definition.hidden then
			if needle == "" or Str.matchesPrefix(definition.name, needle) then
				names[#names + 1] = definition.name
			else
				local matchedAlias = false
				for a = 1, #definition.aliases do
					if Str.matchesPrefix(definition.aliases[a], needle) then
						aliases[#aliases + 1] = definition.aliases[a]
						matchedAlias = true
						break
					end
				end
				if not matchedAlias and #needle >= 3 and Str.distance(definition.name, needle, 2) <= 2 then
					fuzzy[#fuzzy + 1] = definition.name
				end
			end
		end
	end

	table.sort(names)
	table.sort(aliases)
	table.sort(fuzzy)
	local out = {}
	Tbl.append(out, names)
	Tbl.append(out, aliases)
	Tbl.append(out, fuzzy)
	return Tbl.slice(out, 1, limit)
end

--[[ "did you mean" for an unknown command. Canonical names are preferred over
     aliases at the same edit distance, so a typo of `fly` suggests `fly` rather
     than whichever alias of another command happened to register first. ]]
function M.closest(query, maxDistance)
	local needle = Str.lower(Str.trim(query or ""))
	if needle == "" then return nil end
	local limit = maxDistance or 3
	local best, bestScore = nil, limit + 1
	for i = 1, #commands do
		local definition = commands[i]
		if not definition.hidden then
			local score = Str.distance(definition.name, needle, limit)
			if score < bestScore then
				best, bestScore = definition.name, score
			end
			for a = 1, #definition.aliases do
				-- Half a point of penalty: a name match of equal distance wins.
				local aliasScore = Str.distance(definition.aliases[a], needle, limit) + 0.5
				if aliasScore < bestScore then
					best, bestScore = definition.name, aliasScore
				end
			end
		end
	end
	if bestScore <= limit then return best end
	return nil
end

--[[ The text the UI command list shows for a command. Derived, never authored
     separately -- the legacy `addcmdtext` had to be kept in sync by hand. ]]
function M.listText(definition)
	local parts = { definition.name }
	for i = 1, #definition.aliases do
		parts[#parts + 1] = definition.aliases[i]
	end
	local names = table.concat(parts, " / ")
	local args = {}
	for i = 1, #definition.args do
		local spec = definition.args[i]
		args[#args + 1] = spec.optional and ("[" .. spec.name .. "]") or ("<" .. spec.name .. ">")
	end
	if #args > 0 then return names .. " " .. table.concat(args, " ") end
	return names
end

--[[ Everything needed to generate documentation. ]]
function M.export()
	local out = {}
	for i = 1, #commands do
		local definition = commands[i]
		local args = {}
		for a = 1, #definition.args do
			local spec = definition.args[a]
			args[a] = {
				name = spec.name, type = spec.type, optional = spec.optional,
				default = (type(spec.default) ~= "function") and spec.default or nil,
				describe = Types.describe(spec),
			}
		end
		out[#out + 1] = {
			name        = definition.name,
			aliases     = definition.aliases,
			category    = definition.category,
			description = definition.description,
			usage       = definition.usage,
			signature   = definition.signature,
			args        = args,
			examples    = definition.examples,
			hidden      = definition.hidden,
			generated   = definition.generated == true,
			owner       = definition.owner,
			requires    = definition.requires,
		}
	end
	return Tbl.sortBy(out, function(entry) return entry.name end)
end

--[[ Integrity report used by the test suite and ;iydiag: collisions, missing
     descriptions, undocumented arguments. ]]
function M.audit()
	local issues = {}
	local seen = {}
	for i = 1, #commands do
		local definition = commands[i]
		if seen[definition.name] then
			issues[#issues + 1] = { kind = "duplicate", name = definition.name }
		end
		seen[definition.name] = true
		if definition.description == "" and not definition.generated then
			issues[#issues + 1] = { kind = "no-description", name = definition.name }
		end
		for a = 1, #definition.args do
			local spec = definition.args[a]
			if spec.name == ("arg" .. a) then
				issues[#issues + 1] = { kind = "unnamed-arg", name = definition.name, arg = a }
			end
		end
	end
	return issues
end

return M
