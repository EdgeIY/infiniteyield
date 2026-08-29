--[[═══════════════════════════════════════════════════════════════════════════
	features/plugins · the plugin subsystem
	─────────────────────────────────────────────────────────────────────────
	Replaces source.ref.lua 6314-6478 (addPlugin, deletePlugin, refreshplugins,
	LoadPlugin, FindPlugins).

	A plugin is a `.iy` file that returns a table:

	    return {
	        PluginName = "Example",
	        PluginDescription = "What it does",
	        Commands = {
	            example = { Aliases = {"ex"}, Description = "...",
	                        Function = function(args, speaker) ... end },
	        },
	    }

	The file format, the numbering of colliding command names and the saved
	plugin list are all unchanged, so an existing plugin folder keeps working.
	What changed:

	  · commands are registered under `plugin:<file>`, so removing a plugin now
	    actually removes its commands (Registry.removeOwner). The legacy version
	    only deleted rows from its own `cmds` array and left the UI entries
	    behind, and had no way to unload a plugin at all without a rejoin.
	  · a plugin that errors is contained one at a time. The legacy loader also
	    *deleted the plugin from the saved list* when it threw, so one bad load
	    -- a game that blocked HttpGet, say -- silently lost the user's plugin.
	  · each chunk runs in its own environment (compat/legacy), so plugins no
	    longer share, or clobber, one global table.
	  · files are looked up in infiniteyield/plugins first and next to the
	    executor's workspace second, which is where legacy IY read them from.
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Cmd      = IY.import("cmd/api")
local Registry = IY.import("cmd/registry")
local Legacy   = IY.import("compat/legacy")
local Env      = IY.import("core/env")
local FS       = IY.import("core/fs")
local Guard    = IY.import("core/guard")
local Log      = IY.import("core/log")
local Store    = IY.import("core/store")
local Str      = IY.import("core/util/strings")
local Tbl      = IY.import("core/util/tables")

local log = Log.scope("features/plugins")

local M = {}

M.folder = "plugins"      -- inside the IY folder
M.loaded = {}             -- file name -> info

-- Names the legacy loader refused: the settings file, and the placeholder text
-- of the "add plugin" box.
local RESERVED = { ["plugin file name"] = true, ["iy_fe.iy"] = true, ["iy_fe"] = true }

-- ── paths ───────────────────────────────────────────────────────────────────

function M.folderPath()
	return FS.rootPath(M.folder)
end

--[[ `;addplugin thing` and `;addplugin thing.iy` name the same file, exactly as
     before. ]]
local function fileNameOf(name)
	local text = Str.trim(tostring(name or ""))
	if text == "" then Guard.fail("name the plugin's file") end
	if RESERVED[Str.lower(text)] then Guard.fail("'%s' is not a plugin", text) end
	if Str.lower(string.sub(text, -3)) ~= ".iy" then text = text .. ".iy" end
	if RESERVED[Str.lower(text)] then Guard.fail("'%s' is not a plugin", text) end
	return text
end
M.fileNameOf = fileNameOf

local function ownerOf(file)
	return "plugin:" .. file
end

--[[ The IY plugins folder first, then the workspace root, which is where the
     legacy script read plugins from. Returns the contents and the path. ]]
local function locate(file)
	local candidates = { FS.path(M.folderPath(), file), file }
	for i = 1, #candidates do
		local contents = FS.read(candidates[i])
		if contents ~= nil then return contents, candidates[i] end
	end
	return nil
end

-- ── loading ─────────────────────────────────────────────────────────────────

local function compile(file, source)
	local load = Env.fn.loadstring
	if type(load) ~= "function" then
		Guard.fail("your executor cannot compile plugin files (no loadstring)")
	end
	-- Not every implementation accepts a chunk name.
	local chunk, err
	pcall(function() chunk, err = load(source, "=iy/plugin/" .. file) end)
	if not chunk then
		pcall(function() chunk, err = load(source) end)
	end
	if not chunk then
		Guard.fail("%s has a syntax error: %s", file, tostring(err))
	end
	return chunk
end

--[[ Read, compile and run one plugin file. Returns the table it returned plus
     the path it came from. Raises a user-facing error for every failure mode. ]]
function M.loadFile(name)
	local file = fileNameOf(name)
	local source, path = locate(file)
	if source == nil then
		Guard.fail("cannot locate '%s' -- put it in %s or next to your executor's workspace folder",
			file, M.folderPath())
	end

	local chunk = compile(file, source)
	local env = Legacy.environment({
		owner    = ownerOf(file),
		plugin   = file,
		category = "Plugins",
	})
	local injected = Legacy.setEnvironment(chunk, env)
	if not injected then
		log.warn("%s: setfenv is unavailable, so the legacy plugin helpers are not injected", file)
	end

	local ok, result = Guard.call(ownerOf(file), chunk)
	if not ok then
		Guard.fail("an error occurred with the plugin '%s' and it could not be loaded: %s",
			file, Guard.describe(result))
	end
	if type(result) ~= "table" then
		Guard.fail("'%s' did not return a plugin table", file)
	end
	return result, path, env
end

--[[ Legacy numbering: a plugin command whose name is taken gets a numeric
     suffix rather than being dropped. ]]
local function uniqueName(base)
	if not Registry.exists(base) then return base end
	local suffix = 1
	while Registry.exists(base .. tostring(suffix)) do suffix = suffix + 1 end
	return base .. tostring(suffix)
end

local function registerCommands(file, plugin)
	local registered = {}
	local commands = plugin.Commands
	if type(commands) ~= "table" then return registered end
	local owner = ownerOf(file)
	local category = tostring(plugin.PluginName or file)
	-- Sorted, so the suffixes a collision produces are the same every session.
	local keys = Tbl.keys(commands, true)
	for i = 1, #keys do
		local entry = commands[keys[i]]
		if type(entry) == "table" and type(entry.Function) == "function" then
			local definition = {
				name        = uniqueName(Str.lower(Str.trim(tostring(keys[i])))),
				aliases     = type(entry.Aliases) == "table" and entry.Aliases or {},
				description = tostring(entry.Description or ""),
				category    = category,
				args        = { { name = "arguments", type = "raw", optional = true } },
				tags        = { "plugin" },
				run         = Legacy.wrapCommand(entry.Function),
			}
			local ok, result = pcall(Cmd.register, definition, owner)
			if ok and result then
				registered[#registered + 1] = result.name
			else
				log.warn("%s: command '%s' was rejected: %s", file, tostring(keys[i]),
					ok and "name collision" or Guard.describe(result))
			end
		end
	end
	return registered
end

-- ── public API ──────────────────────────────────────────────────────────────

--[[ Load a file and register its commands, without touching the saved list. ]]
local function activate(name)
	local file = fileNameOf(name)
	if M.loaded[file] then Guard.fail("'%s' is already added", file) end
	local plugin, path = M.loadFile(file)
	local info = {
		file        = file,
		path        = path,
		name        = tostring(plugin.PluginName or file),
		description = tostring(plugin.PluginDescription or ""),
		plugin      = plugin,
	}
	info.commands = registerCommands(file, plugin)
	M.loaded[file] = info
	return info
end

local function savedList()
	local stored = Store.get("plugins") or {}
	local out = {}
	for i = 1, #stored do out[i] = tostring(stored[i]) end
	return out
end

local function remember(file)
	local list = savedList()
	if Tbl.containsInsensitive(list, file) then return false end
	list[#list + 1] = file
	Store.set("plugins", list)
	return true
end

local function forget(file)
	local list = savedList()
	local kept = Tbl.filter(list, function(entry) return Str.lower(entry) ~= Str.lower(file) end)
	if #kept == #list then return false end
	Store.set("plugins", kept)
	return true
end

--[[ Add a plugin and remember it for next session. ]]
function M.add(name)
	local info = activate(name)
	remember(info.file)
	log.info("loaded %s from %s (%d command(s))", info.file, tostring(info.path), #info.commands)
	return info
end

--[[ Unload a plugin: its commands go with it, which is new. ]]
function M.remove(name)
	local file = fileNameOf(name)
	local info = M.loaded[file]
	local removed = Registry.removeOwner(ownerOf(file))
	M.loaded[file] = nil
	local forgotten = forget(file)
	if not info and not forgotten and removed == 0 then
		return false, 0, file
	end
	log.info("removed %s (%d command(s))", file, removed)
	return true, removed, file
end

function M.reload(name)
	local file = fileNameOf(name)
	local _, removed = M.remove(file)
	local info = M.add(file)
	return info, removed
end

--[[ Ordered summary for the plugin panel. ]]
function M.list()
	local out = {}
	for file, info in pairs(M.loaded) do
		out[#out + 1] = {
			file        = file,
			name        = info.name,
			description = info.description,
			path        = info.path,
			commands    = #info.commands,
		}
	end
	return Tbl.sortBy(out, function(entry) return entry.file end)
end

--[[ Load everything the settings file remembers. Called by the plugins boot
     phase; each plugin is contained on its own so a broken one cannot stop the
     rest, and -- unlike the legacy loader -- a failure does not delete it from
     the saved list. ]]
function M.loadSaved()
	local list = savedList()
	local loaded, failures = 0, {}
	for i = 1, #list do
		local file = list[i]
		-- Already loaded (a second call, or the user added it by hand first) is
		-- not a failure.
		if M.loaded[file] then
			loaded = loaded + 1
		else
			local ok, err = Guard.call(ownerOf(file), activate, file)
			if ok then
				loaded = loaded + 1
			else
				failures[#failures + 1] = { file = file, error = err }
				log.warn("%s could not be loaded: %s", file, Guard.describe(err))
			end
		end
	end
	if #failures > 0 then
		IY.import("core/notify").warn("Plugins",
			Str.pluralise(#failures, "plugin") .. " failed to load. Run ;iylog for the reason.")
	end
	M.failures = failures
	return loaded, failures
end

--[[ Every .iy file in the plugins folder (and, as before, the workspace root)
     that is not already added. ]]
function M.addAllFromFolder()
	local listfiles = Env.fn.listfiles
	if type(listfiles) ~= "function" then
		Guard.fail("your executor cannot list files (missing listfiles)")
	end
	local isfolder = Env.fn.isfolder
	local added, failures, seen = {}, {}, {}
	-- "" is the executor's workspace root, which is what legacy IY scanned.
	local folders = { M.folderPath(), "" }
	for f = 1, #folders do
		local ok, entries = pcall(listfiles, folders[f])
		if ok and type(entries) == "table" then
			for i = 1, #entries do
				local path = tostring(entries[i])
				local file = string.match(path, "([^/\\]+%.iy)$")
				local key = file and Str.lower(file) or nil
				if key and not RESERVED[key] and not seen[key] and not M.loaded[file] then
					seen[key] = true
					-- The legacy version tested isfolder() on the bare file name
					-- rather than the path, so it never actually skipped one.
					local isDirectory = false
					if type(isfolder) == "function" then
						local okDir, result = pcall(isfolder, path)
						isDirectory = okDir and result == true
					end
					if not isDirectory then
						local okAdd, err = Guard.call(ownerOf(file), M.add, file)
						if okAdd then
							added[#added + 1] = file
						else
							failures[#failures + 1] = file
							log.warn("%s could not be loaded: %s", file, Guard.describe(err))
						end
					end
				end
			end
		end
	end
	return added, failures
end

-- A plugin folder is cheap to create and makes the convention discoverable.
if FS.available then
	pcall(FS.ensureFolder, M.folderPath())
end

return M
