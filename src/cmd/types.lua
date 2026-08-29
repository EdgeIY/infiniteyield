--[[═══════════════════════════════════════════════════════════════════════════
	cmd/types · the argument type system
	─────────────────────────────────────────────────────────────────────────
	In the legacy script every command parsed its own arguments:

	    addcmd('speed',{'ws'},function(args,speaker)
	        local players = getPlayer(args[1], speaker)
	        for i,v in pairs(players) do
	            Players[v].Character.Humanoid.WalkSpeed = args[2] or 16
	        end
	    end)

	Four latent bugs in four lines: `args[2]` is a *string*, a missing character
	throws, `Players[v]` throws if they left, and typing `;speed all fast` sets
	WalkSpeed to `"fast"`. Multiply by 430 commands.

	Here a command declares what it wants and the framework guarantees it:

	    args = {
	        { name = "players", type = "players" },
	        { name = "speed",   type = "number", default = 16, min = 0 },
	    }

	`run` then receives real values -- a list of live Targets and a number --
	or the user gets "usage: speed <players> [speed]" and the command never
	runs. Types also provide autocomplete and the text shown in the UI.
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Guard   = IY.import("core/guard")
local Str     = IY.import("core/util/strings")
local Tbl     = IY.import("core/util/tables")
local Players = IY.import("core/players")
local Target  = IY.import("core/target")

local M = {}

local registry = {}
M.registry = registry

--[[ Register a type.
     parse(raw, spec, ctx)   -> value            (Guard.fail on bad input)
     complete(partial, spec) -> {strings}        (optional)
     describe(spec)          -> "number"         (optional, for usage text)
     greedy                  -- consumes the rest of the line as one value
     multi                   -- the value is a list (affects usage text) ]]
function M.define(name, definition)
	definition.name = name
	registry[name] = definition
	return definition
end

function M.get(name)
	local definition = registry[name]
	if not definition then
		error("[iy] unknown argument type '" .. tostring(name) .. "'", 2)
	end
	return definition
end

function M.exists(name)
	return registry[name] ~= nil
end

--[[ Human-readable type label used in usage strings. ]]
function M.describe(spec)
	local definition = registry[spec.type]
	if definition and definition.describe then
		local ok, text = pcall(definition.describe, spec)
		if ok and text then return text end
	end
	return spec.type
end

--[[ Suggestions for the current partial token. ]]
function M.complete(spec, partial, ctx)
	local definition = registry[spec.type]
	if not definition or not definition.complete then return {} end
	local ok, result = pcall(definition.complete, partial or "", spec, ctx)
	if ok and type(result) == "table" then return result end
	return {}
end

-- ═══ helpers ════════════════════════════════════════════════════════════════

local function requireNumber(raw, spec)
	local value = Str.toNumber(raw)
	if value == nil then
		if Str.lower(tostring(raw)) == "inf" or Str.lower(tostring(raw)) == "infinite" then
			return math.huge
		end
		Guard.fail("'%s' is not a number", tostring(raw))
	end
	return value
end

local function clamp(value, spec, label)
	if spec.min and value < spec.min then
		Guard.fail("%s must be at least %s", label or spec.name or "value", tostring(spec.min))
	end
	if spec.max and value > spec.max then
		Guard.fail("%s must be at most %s", label or spec.name or "value", tostring(spec.max))
	end
	return value
end

-- ═══ built-in types ═════════════════════════════════════════════════════════

M.define("players", {
	multi = true,
	optionalByDefault = true,
	--[[ An optional players argument means "you" unless the command says
	     otherwise, which is what `getPlayer(nil, speaker)` did and saves the
	     same `default = "me"` line on two hundred commands. ]]
	defaultWhenOptional = "me",
	describe = function() return "players" end,
	parse = function(raw, spec, ctx)
		local targets = Players.resolve(raw, ctx and ctx.speaker or nil, {
			defaultAll = spec.defaultAll,
		})
		if #targets == 0 then
			Guard.fail("no player matched '%s'", tostring(raw))
		end
		if spec.excludeSelf then
			targets = Tbl.filter(targets, function(t) return not t.isLocal end)
			if #targets == 0 then Guard.fail("that only matched you") end
		end
		if spec.aliveOnly then
			local alive = Tbl.filter(targets, function(t) return t.alive end)
			if #alive == 0 then Guard.fail("none of those players are alive") end
			targets = alive
		end
		if spec.max and #targets > spec.max then
			targets = Tbl.slice(targets, 1, spec.max)
		end
		return targets
	end,
	complete = function(partial) return Players.suggest(partial) end,
})

M.define("player", {
	optionalByDefault = true,
	defaultWhenOptional = "me",
	describe = function() return "player" end,
	parse = function(raw, spec, ctx)
		local targets = Players.resolve(raw, ctx and ctx.speaker or nil)
		if #targets == 0 then Guard.fail("no player matched '%s'", tostring(raw)) end
		return targets[1]
	end,
	complete = function(partial) return Players.suggest(partial) end,
})

M.define("number", {
	parse = function(raw, spec)
		return clamp(requireNumber(raw, spec), spec)
	end,
	describe = function(spec)
		if spec.min and spec.max then return "number " .. spec.min .. "-" .. spec.max end
		return "number"
	end,
})

M.define("integer", {
	parse = function(raw, spec)
		local value = requireNumber(raw, spec)
		if value ~= math.huge and math.floor(value) ~= value then
			Guard.fail("'%s' must be a whole number", tostring(raw))
		end
		return clamp(value, spec)
	end,
	describe = function() return "whole number" end,
})

local TRUTHY = { ["true"] = true, t = true, ["1"] = true, yes = true, y = true,
	on = true, enable = true, enabled = true, show = true }
local FALSY = { ["false"] = true, f = true, ["0"] = true, no = true, n = true,
	off = true, disable = true, disabled = true, hide = true }

M.define("boolean", {
	parse = function(raw, spec)
		local text = Str.lower(Str.trim(tostring(raw)))
		if TRUTHY[text] then return true end
		if FALSY[text] then return false end
		Guard.fail("'%s' is not on/off", tostring(raw))
	end,
	describe = function() return "on/off" end,
	complete = function(partial)
		return Tbl.filter({ "on", "off", "true", "false" }, function(v)
			return Str.matchesPrefix(v, partial)
		end)
	end,
})

M.define("string", {
	parse = function(raw, spec)
		local text = tostring(raw)
		if spec.minLength and #text < spec.minLength then
			Guard.fail("%s must be at least %d characters", spec.name or "value", spec.minLength)
		end
		if spec.maxLength and #text > spec.maxLength then
			text = string.sub(text, 1, spec.maxLength)
		end
		if spec.pattern and not string.match(text, spec.pattern) then
			Guard.fail("%s is not in the expected format", spec.name or "value")
		end
		return text
	end,
	describe = function() return "text" end,
})

--[[ Greedy: takes the entire remainder of the line, spaces and all. This is
     what `;chat hello there friend` needs, and it replaces the legacy
     `getstring(1)` idiom that silently depended on a global. ]]
M.define("text", {
	greedy = true,
	parse = function(raw, spec)
		local text = tostring(raw or "")
		if spec.trim ~= false then text = Str.trim(text) end
		if spec.maxLength and #text > spec.maxLength then text = string.sub(text, 1, spec.maxLength) end
		return text
	end,
	describe = function() return "text..." end,
})

M.define("enum", {
	parse = function(raw, spec)
		local text = Str.lower(Str.trim(tostring(raw)))
		local values = spec.values or {}
		for i = 1, #values do
			local candidate = values[i]
			local key = type(candidate) == "table" and candidate[1] or candidate
			if Str.lower(tostring(key)) == text then
				return type(candidate) == "table" and candidate[2] or candidate
			end
		end
		-- Accept an unambiguous prefix, which makes long option lists usable.
		local matches = {}
		for i = 1, #values do
			local candidate = values[i]
			local key = type(candidate) == "table" and candidate[1] or candidate
			if Str.matchesPrefix(tostring(key), text) then
				matches[#matches + 1] = candidate
			end
		end
		if #matches == 1 then
			return type(matches[1]) == "table" and matches[1][2] or matches[1]
		end
		local names = {}
		for i = 1, #values do
			local candidate = values[i]
			names[#names + 1] = tostring(type(candidate) == "table" and candidate[1] or candidate)
		end
		Guard.fail("'%s' must be one of: %s", tostring(raw), table.concat(names, ", "))
	end,
	describe = function(spec)
		local names = {}
		local values = spec.values or {}
		for i = 1, math.min(#values, 4) do
			local candidate = values[i]
			names[#names + 1] = tostring(type(candidate) == "table" and candidate[1] or candidate)
		end
		if #values > 4 then names[#names + 1] = "..." end
		return table.concat(names, "|")
	end,
	complete = function(partial, spec)
		local out = {}
		local values = spec.values or {}
		for i = 1, #values do
			local candidate = values[i]
			local key = tostring(type(candidate) == "table" and candidate[1] or candidate)
			if Str.matchesPrefix(key, partial) then out[#out + 1] = key end
		end
		return out
	end,
})

--[[ An EnumItem from any Roblox Enum, by name. `spec.enum` is the Enum. ]]
M.define("enumitem", {
	parse = function(raw, spec)
		local enum = spec.enum
		if not enum then Guard.fail("this argument is misconfigured (no enum)") end
		local text = Str.lower(Str.trim(tostring(raw)))
		local items = enum:GetEnumItems()
		for i = 1, #items do
			if Str.lower(items[i].Name) == text then return items[i] end
		end
		for i = 1, #items do
			if Str.matchesPrefix(items[i].Name, text) then return items[i] end
		end
		Guard.fail("'%s' is not a valid %s", tostring(raw), tostring(spec.enumName or "option"))
	end,
	describe = function(spec) return tostring(spec.enumName or "enum") end,
	complete = function(partial, spec)
		local out = {}
		if not spec.enum then return out end
		local items = spec.enum:GetEnumItems()
		for i = 1, #items do
			if Str.matchesPrefix(items[i].Name, partial) then out[#out + 1] = items[i].Name end
		end
		table.sort(out)
		return out
	end,
})

M.define("keycode", {
	parse = function(raw, spec)
		local text = Str.trim(tostring(raw))
		local items = Enum.KeyCode:GetEnumItems()
		local lowered = Str.lower(text)
		for i = 1, #items do
			if Str.lower(items[i].Name) == lowered then return items[i] end
		end
		-- Single characters map to their letter/number key.
		if #text == 1 then
			for i = 1, #items do
				if Str.lower(items[i].Name) == lowered then return items[i] end
			end
		end
		Guard.fail("'%s' is not a key", text)
	end,
	describe = function() return "key" end,
	complete = function(partial)
		local out = {}
		local items = Enum.KeyCode:GetEnumItems()
		for i = 1, #items do
			if Str.matchesPrefix(items[i].Name, partial) then out[#out + 1] = items[i].Name end
		end
		table.sort(out)
		return Tbl.slice(out, 1, 25)
	end,
})

M.define("vector3", {
	parse = function(raw, spec)
		local parts = Str.split(tostring(raw), ",")
		if #parts == 1 then parts = Str.split(tostring(raw), " ") end
		if #parts < 3 then Guard.fail("'%s' must be x,y,z", tostring(raw)) end
		local x, y, z = Str.toNumber(parts[1]), Str.toNumber(parts[2]), Str.toNumber(parts[3])
		if not x or not y or not z then Guard.fail("'%s' must be three numbers", tostring(raw)) end
		return Vector3.new(x, y, z)
	end,
	describe = function() return "x,y,z" end,
})

local NAMED_COLORS = {
	red = Color3.fromRGB(255, 0, 0), green = Color3.fromRGB(0, 255, 0),
	blue = Color3.fromRGB(0, 0, 255), yellow = Color3.fromRGB(255, 255, 0),
	orange = Color3.fromRGB(255, 165, 0), purple = Color3.fromRGB(160, 32, 240),
	pink = Color3.fromRGB(255, 105, 180), cyan = Color3.fromRGB(0, 255, 255),
	white = Color3.fromRGB(255, 255, 255), black = Color3.fromRGB(0, 0, 0),
	grey = Color3.fromRGB(128, 128, 128), gray = Color3.fromRGB(128, 128, 128),
	brown = Color3.fromRGB(139, 69, 19), lime = Color3.fromRGB(0, 255, 0),
}

M.define("color", {
	parse = function(raw, spec)
		local text = Str.lower(Str.trim(tostring(raw)))
		local named = NAMED_COLORS[text]
		if named then return named end
		local hex = string.match(text, "^#?(%x%x%x%x%x%x)$")
		if hex then
			return Color3.fromRGB(
				tonumber(string.sub(hex, 1, 2), 16),
				tonumber(string.sub(hex, 3, 4), 16),
				tonumber(string.sub(hex, 5, 6), 16))
		end
		local parts = Str.split(text, ",")
		if #parts >= 3 then
			local r, g, b = Str.toNumber(parts[1]), Str.toNumber(parts[2]), Str.toNumber(parts[3])
			if r and g and b then
				if r <= 1 and g <= 1 and b <= 1 then return Color3.new(r, g, b) end
				return Color3.fromRGB(r, g, b)
			end
		end
		Guard.fail("'%s' is not a colour (try red, #ff0000 or 255,0,0)", tostring(raw))
	end,
	describe = function() return "colour" end,
	complete = function(partial)
		local out = {}
		for name in pairs(NAMED_COLORS) do
			if Str.matchesPrefix(name, partial) then out[#out + 1] = name end
		end
		table.sort(out)
		return out
	end,
})

M.define("time", {
	parse = function(raw, spec)
		local seconds = Str.toSeconds(raw)
		if seconds == nil then Guard.fail("'%s' is not a duration (try 5, 500ms, 1m30s)", tostring(raw)) end
		return clamp(seconds, spec)
	end,
	describe = function() return "duration" end,
})

--[[ A Roblox class name, validated so `;deleteclass Prat` fails loudly instead
     of silently matching nothing. ]]
M.define("class", {
	parse = function(raw)
		local text = Str.trim(tostring(raw))
		local ok = pcall(function() return Instance.new(text) end)
		if not ok then
			-- Not creatable is fine (abstract classes); only reject names that
			-- no instance can ever be.
			local valid = pcall(function() return game:FindFirstChildWhichIsA(text) end)
			if not valid then Guard.fail("'%s' is not a Roblox class", text) end
		end
		return text
	end,
	describe = function() return "ClassName" end,
})

--[[ A command name, used by ;bind, ;alias, ;removecmd. Completes from the
     registry, so these commands can never drift out of sync with it. ]]
M.define("command", {
	greedy = true,
	parse = function(raw, spec, ctx)
		local text = Str.trim(tostring(raw or ""))
		if text == "" then Guard.fail("expected a command") end
		return text
	end,
	describe = function() return "command" end,
	complete = function(partial, spec, ctx)
		local Registry = IY.import("cmd/registry")
		return Registry.suggest(partial, 20)
	end,
})

M.define("waypoint", {
	greedy = true,
	parse = function(raw)
		local text = Str.trim(tostring(raw or ""))
		if text == "" then Guard.fail("expected a waypoint name") end
		return text
	end,
	describe = function() return "waypoint" end,
	complete = function(partial)
		local ok, Waypoints = pcall(function() return IY.import("features/waypoints") end)
		if not ok or not Waypoints or not Waypoints.names then return {} end
		return Tbl.filter(Waypoints.names(), function(name)
			return Str.matchesPrefix(name, partial)
		end)
	end,
})

M.define("tool", {
	greedy = true,
	parse = function(raw)
		return Str.trim(tostring(raw or ""))
	end,
	describe = function() return "tool" end,
	complete = function(partial, spec, ctx)
		local Inst = IY.import("core/util/instances")
		local out = {}
		local speaker = ctx and ctx.speaker
		local player = speaker and speaker.player or nil
		local tools = player and Inst.tools(player) or {}
		for i = 1, #tools do
			if Str.matchesPrefix(tools[i].Name, partial) then out[#out + 1] = tools[i].Name end
		end
		return out
	end,
})

--[[ Anything at all, unvalidated -- an escape hatch for plugin authors that is
     explicit about giving up type safety. ]]
M.define("raw", {
	greedy = true,
	parse = function(raw) return raw end,
	describe = function() return "..." end,
})

return M
