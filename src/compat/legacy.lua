--[[═══════════════════════════════════════════════════════════════════════════
	compat/legacy · the old global surface, for plugins only
	─────────────────────────────────────────────────────────────────────────
	**Backward compatibility only.** Nothing in src/ may import this except
	features/plugins; new code uses the real modules directly.

	Every published IY plugin was written against the monolith's globals
	(`addcmd`, `notify`, `getPlayer`, `execCmd`, `getstring`, `Players`, ...).
	Those globals are gone, so each plugin chunk is run with this table as its
	environment via `setfenv`, and reads anything it is missing -- game, task,
	Instance, the executor's own functions -- straight through `__index`.

	Writes stay inside the plugin's own table, so two plugins that both use a
	global called `enabled` no longer overwrite each other.

	Legacy equivalents: source.ref.lua 290-296 (randomString), 2076-2130
	(isNumber / getRoot / toClipboard / chatMessage), 4979 (FindInTable),
	5078-5090 (parseBoolean / getstring), 5112 (execCmd), 5195 (addcmd),
	5557 (getPlayer).
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Cmd      = IY.import("cmd/api")
local Dispatch = IY.import("cmd/dispatch")
local Env      = IY.import("core/env")
local Guard    = IY.import("core/guard")
local Log      = IY.import("core/log")
local Notify   = IY.import("core/notify")
local Players  = IY.import("core/players")
local Platform = IY.import("core/platform")
local Services = IY.import("core/services")
local Str      = IY.import("core/util/strings")

local log = Log.scope("compat/legacy")

local M = {}

-- ── legacy helpers ──────────────────────────────────────────────────────────

local function isNumber(str)
	return tonumber(str) ~= nil or str == "inf"
end

local function toClipboard(text)
	local setclipboard = Env.fn.setclipboard
	if setclipboard then
		-- tostring: some executors reject a number outright.
		pcall(setclipboard, tostring(text))
		Notify.send("Clipboard", "Copied to clipboard")
	else
		Notify.send("Clipboard", "Your exploit doesn't have the ability to use the clipboard")
	end
end

local function chatMessage(text)
	text = tostring(text)
	if Platform.isLegacyChat then
		local events = Services.ReplicatedStorage:FindFirstChild("DefaultChatSystemChatEvents")
		local request = events and events:FindFirstChild("SayMessageRequest")
		if not request then Guard.fail("this game has no legacy chat events") end
		request:FireServer(text, "All")
	else
		Services.TextChatService.TextChannels.RBXGeneral:SendAsync(text)
	end
end

local function findInTable(list, value)
	if type(list) ~= "table" then return false end
	for _, entry in pairs(list) do
		if entry == value then return true end
	end
	return false
end

local BOOLY = {
	truthy = { ["true"] = true, t = true, ["1"] = true, yes = true, y = true, on = true,
		enable = true, enabled = true, show = true },
	falsy = { ["false"] = true, f = true, ["0"] = true, no = true, n = true, off = true,
		disable = true, disabled = true, hide = true },
}

local function parseBoolean(raw, default)
	local text = Str.lower(tostring(raw))
	if BOOLY.truthy[text] then return true end
	if BOOLY.falsy[text] then return false end
	return default or false
end

--[[ `args` is the raw token array a legacy command body receives, so
     getstring(2, args) is still "everything from the second token on". ]]
local function getstring(begin, args)
	if type(args) ~= "table" then return "" end
	return table.concat(args, " ", math.max(1, tonumber(begin) or 1))
end

-- ── command bridge ──────────────────────────────────────────────────────────

--[[ Adapt a legacy `function(args, speaker)` body to a modern `run(ctx)`.
     `args` is the token array exactly as the parser produced it and `speaker`
     is the Player instance, which is what every legacy body indexes. ]]
function M.wrapCommand(fn)
	return function(ctx)
		local speaker = ctx.speaker and ctx.speaker.player or Services.Players.LocalPlayer
		return fn(ctx.tokens or {}, speaker)
	end
end

--[[ `addcmd` for one plugin. Invalid names are reported and skipped rather than
     raised: the legacy loader let one bad `addcmd` abort the whole plugin. ]]
local function makeAddcmd(opts)
	local owner = opts.owner
	local category = opts.category
	return function(name, aliases, fn)
		if type(name) ~= "string" or type(fn) ~= "function" then
			log.warn("%s: addcmd needs a name and a function", tostring(opts.plugin))
			return nil
		end
		local definition = {
			name        = Str.lower(Str.trim(name)),
			aliases     = type(aliases) == "table" and aliases or {},
			description = tostring(opts.description or ""),
			category    = category,
			args        = { { name = "arguments", type = "raw", optional = true } },
			tags        = { "plugin" },
			run         = M.wrapCommand(fn),
		}
		local ok, result = pcall(Cmd.register, definition, owner)
		if not ok then
			log.warn("%s: addcmd('%s') was rejected: %s",
				tostring(opts.plugin), tostring(name), Guard.describe(result))
			return nil
		end
		return result
	end
end

-- ── environment ─────────────────────────────────────────────────────────────

--[[ Anything the plugin reads that this shim does not define is looked up in
     the real global scopes -- getfenv, getgenv, _G, shared -- so `game`,
     `task`, `Instance` and the executor's own functions all still work. ]]
local fallback = {
	__index = function(_, key)
		if type(key) ~= "string" then return nil end
		return Env.lookup(key)
	end,
}

--[[ Build the environment one plugin chunk runs in.
       opts.owner   registry owner tag, so removeOwner can unload it
       opts.plugin  file name, used in log messages
       opts.category  category its commands are filed under ]]
function M.environment(opts)
	opts = opts or {}
	local env = {
		addcmd       = makeAddcmd(opts),
		notify       = function(title, text, length) return Notify.send(title, text, length) end,
		execCmd      = function(line, speaker) return Dispatch.run(line, speaker) end,
		getPlayer    = function(query, speaker) return Players.resolveNames(query, speaker) end,
		getstring    = getstring,
		randomString = function() return Str.random(math.random(10, 20)) end,
		getRoot      = function(character) return IY.import("core/util/instances").root(character) end,
		isNumber     = isNumber,
		toClipboard  = toClipboard,
		chatMessage  = chatMessage,
		FindInTable  = findInTable,
		parseBoolean = parseBoolean,
		splitString  = function(text, delim) return Str.split(text, delim) end,
		Players      = Services.Players,
		Services     = Services,
		-- An escape hatch for plugins that want the real thing.
		IY           = IY,
	}
	env.PLUGIN = opts.plugin
	-- `_G` is deliberately left to the fallback: a plugin that reaches for it
	-- means the real global table, as it did before.
	return setmetatable(env, fallback)
end

--[[ Swap a compiled chunk's environment. setfenv exists in Lua 5.1 and Luau; if
     an executor's loadstring hands back a 5.2-style chunk there is nothing to
     swap, so the plugin runs against the real globals instead of not at all. ]]
function M.setEnvironment(chunk, env)
	if type(setfenv) ~= "function" then return false end
	local ok = pcall(setfenv, chunk, env)
	return ok
end

return M
