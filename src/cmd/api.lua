--[[═══════════════════════════════════════════════════════════════════════════
	cmd/api · the surface command modules and plugins author against
	─────────────────────────────────────────────────────────────────────────
	This is the whole public API for adding behaviour to IY:

	    local Cmd = IY.import("cmd/api")

	    local group = Cmd.group{ category = "Movement" }

	    group{
	        name = "speed",
	        aliases = {"ws", "walkspeed"},
	        description = "Sets walk speed.",
	        args = {
	            { name = "players", type = "players" },
	            { name = "speed",   type = "number", default = 16, min = 0 },
	        },
	        examples = {"speed all 100"},
	        run = function(ctx)
	            ctx:each(function(target)
	                target:requireHumanoid().WalkSpeed = ctx.args.speed
	            end)
	        end,
	    }

	`Cmd.group` applies shared defaults (category, requires, owner) so a command
	pack states them once. Everything else -- usage text, the UI list entry,
	autocomplete, the `un`/`toggle` siblings, docs -- is derived.
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Registry = IY.import("cmd/registry")
local Types    = IY.import("cmd/types")
local Tbl      = IY.import("core/util/tables")
local Log      = IY.import("core/log")

local M = {}

--[[ Register one command. Returns the normalised definition (nil when it was
     rejected for a name collision -- the diagnostic explains why). ]]
function M.register(definition, owner)
	return Registry.add(definition, owner)
end
M.add = M.register

--[[ A registrar with shared defaults. Call the returned function with each
     command table; anything the command sets wins over the group default.

     `requires` and `tags` merge rather than replace, so a group can demand
     `requires = { character = true }` and a command can add `alive = true`. ]]
function M.group(defaults)
	defaults = defaults or {}
	local owner = defaults.owner
	return function(definition)
		for key, value in pairs(defaults) do
			if key ~= "requires" and key ~= "tags" and key ~= "owner" then
				if definition[key] == nil then definition[key] = value end
			end
		end
		if defaults.requires then
			definition.requires = Tbl.defaults(definition.requires or {}, defaults.requires)
		end
		if defaults.tags then
			definition.tags = Tbl.append(Tbl.copy(defaults.tags), definition.tags or {})
		end
		return Registry.add(definition, definition.owner or owner)
	end
end

--[[ Register several commands at once (an array of definitions). ]]
function M.registerAll(list, owner)
	local added = 0
	for i = 1, #list do
		if Registry.add(list[i], owner) then added = added + 1 end
	end
	return added
end

-- ── execution ───────────────────────────────────────────────────────────────

function M.run(line, speaker, opts)
	return IY.import("cmd/dispatch").run(line, speaker, opts)
end

function M.runSync(line, speaker, opts)
	return IY.import("cmd/dispatch").runSync(line, speaker, opts)
end

function M.isActive(name)
	return IY.import("cmd/dispatch").isActive(name)
end

function M.setActive(name, value)
	return IY.import("cmd/dispatch").setActive(name, value)
end

-- ── introspection ───────────────────────────────────────────────────────────

M.find       = Registry.find
M.exists     = Registry.exists
M.all        = Registry.all
M.count      = Registry.count
M.remove     = Registry.remove
M.override   = Registry.override
M.setEnabled = Registry.setEnabled
M.categories = Registry.categories
M.suggest    = Registry.suggest
M.export     = Registry.export

--[[ Add a custom argument type. Plugins use this to accept domain values
     (a pet name, a shop item) with validation and autocomplete for free. ]]
M.defineType = Types.define

--[[ Usage text for a command, for help output. ]]
function M.help(name)
	local definition = Registry.find(name)
	if not definition then return nil end
	local lines = { definition.signature }
	if definition.description ~= "" then lines[#lines + 1] = definition.description end
	if #definition.aliases > 0 then
		lines[#lines + 1] = "aliases: " .. table.concat(definition.aliases, ", ")
	end
	for i = 1, #definition.examples do
		lines[#lines + 1] = "e.g. " .. definition.examples[i]
	end
	return table.concat(lines, "\n")
end

return M
