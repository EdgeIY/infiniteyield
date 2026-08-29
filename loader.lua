-- Infinite Yield remote loader (7.0.0)
-- Fetches modules individually so a branch can be tested without rebuilding.
--   getgenv().IY_CONFIG = { branch = "my-branch", debug = true }
--   loadstring(game:HttpGet("https://raw.githubusercontent.com/EdgeIY/infiniteyield/master/loader.lua"))()
-- The release entry point is `source`, which embeds these same modules.

local __IY_RUNTIME__ = (function(...)
--[[═══════════════════════════════════════════════════════════════════════════
	Infinite Yield · Module Runtime
	─────────────────────────────────────────────────────────────────────────
	The single loader core. This file is embedded verbatim into BOTH:

	  · loader.lua  — remote mode: module bodies are fetched over HTTP
	  · source      — bundle mode: module bodies are inlined by tools/bundle.lua

	so there is exactly one implementation of module resolution, caching,
	cycle detection, error reporting and teardown in the entire project.

	Module contract
	───────────────
	Every file under src/ is a chunk that receives the runtime as its only
	vararg and returns a non-nil value:

	    local IY = ...
	    local Log = IY.import("core/log")
	    local M = {}
	    ...
	    return M

	In remote mode the chunk itself is the factory. In bundle mode the bundler
	wraps the identical body in `IY.define("name", function(...) <body> end)`,
	so `local IY = ...` resolves the same way in both. No body rewriting, no
	runtime string compilation, one set of semantics.

	This file has no dependencies and must stay Lua 5.1 compatible.
═══════════════════════════════════════════════════════════════════════════]]

local Runtime = {}
Runtime.__index = Runtime

local STATE_IDLE    = "idle"
local STATE_LOADING = "loading"
local STATE_LOADED  = "loaded"
local STATE_FAILED  = "failed"

local function now()
	if os and os.clock then return os.clock() end
	return 0
end

local function tracebackOf(err)
	if type(debug) == "table" and type(debug.traceback) == "function" then
		local ok, tb = pcall(debug.traceback, tostring(err), 2)
		if ok and type(tb) == "string" then return tb end
	end
	return tostring(err)
end

--[[ Modules call `IY.import("x")` with a dot, because writing `IY:import` in
     every one of a hundred files is noise. These wrappers make every method
     callable either way: they detect the runtime being passed as the first
     argument and shift it off. ]]
local DOT_CALLABLE = {
	"define", "import", "tryImport", "importAll", "has", "isLoaded",
	"onUnload", "unload", "report", "diagnostic", "stackPath",
}

local function bindMethods(self)
	for i = 1, #DOT_CALLABLE do
		local key = DOT_CALLABLE[i]
		local method = Runtime[key]
		self[key] = function(first, ...)
			if first == self then return method(self, ...) end
			return method(self, first, ...)
		end
	end
end

--[[ Create a runtime. `config` is carried through to every module via
     IY.config and is the only place environment-level switches live. ]]
function Runtime.new(config)
	local self = setmetatable({}, Runtime)
	self.config    = config or {}
	self.version   = self.config.version or "0.0.0"
	self.channel   = self.config.channel or "release"
	self.registry  = {}   -- name -> record
	self.loadOrder = {}   -- names, in the order they finished loading
	self.stack     = {}   -- active import stack (cycle detection + blame)
	self.teardown  = {}   -- { {fn = , label = } } run LIFO on unload
	self.diagnostics = {} -- non-fatal problems collected during boot
	self.timings   = {}   -- name -> seconds spent inside the factory
	self.resolve   = nil  -- optional function(name) -> factory | nil
	self.onDiagnostic = nil
	self.unloaded  = false
	bindMethods(self)
	return self
end

--[[ Register a module factory. ]]
function Runtime:define(name, factory)
	if type(name) ~= "string" or name == "" then
		error("[iy] define() expects a module name string, got " .. tostring(name), 2)
	end
	if type(factory) ~= "function" then
		error("[iy] define('" .. name .. "') expects a function, got " .. type(factory), 2)
	end
	local existing = self.registry[name]
	if existing then
		if existing.state == STATE_LOADED or existing.state == STATE_LOADING then
			-- Redefining a live module is always a mistake: fail loudly rather
			-- than leaving two copies of the same state in play.
			error("[iy] module '" .. name .. "' is already " .. existing.state, 2)
		end
		self:diagnostic("redefine", "module '" .. name .. "' was redefined before first use")
	end
	self.registry[name] = { name = name, factory = factory, state = STATE_IDLE }
	return self
end

function Runtime:has(name)
	if self.registry[name] then return true end
	if self.resolve then return self.resolve(name) ~= nil end
	return false
end

function Runtime:isLoaded(name)
	local rec = self.registry[name]
	return rec ~= nil and rec.state == STATE_LOADED
end

--[[ Record a non-fatal problem. Surfaced by `;iydiag` and the boot report. ]]
function Runtime:diagnostic(kind, message, detail)
	local entry = {
		kind    = kind,
		message = message,
		detail  = detail,
		module  = self.stack[#self.stack],
		clock   = now(),
	}
	self.diagnostics[#self.diagnostics + 1] = entry
	if self.onDiagnostic then pcall(self.onDiagnostic, entry) end
	return entry
end

function Runtime:stackPath(name)
	local parts = {}
	for i = 1, #self.stack do parts[#parts + 1] = self.stack[i] end
	if name then parts[#parts + 1] = name end
	return table.concat(parts, " -> ")
end

--[[ Resolve and memoise a module. Errors are wrapped once, with the import
     chain attached, so a failure deep in the tree still says who asked. ]]
function Runtime:import(name)
	if type(name) ~= "string" then
		error("[iy] import() expects a module name string, got " .. type(name), 2)
	end

	local rec = self.registry[name]

	if not rec and self.resolve then
		local ok, factory = pcall(self.resolve, name)
		if ok and type(factory) == "function" then
			self:define(name, factory)
			rec = self.registry[name]
		elseif not ok then
			error("[iy] resolver failed for '" .. name .. "': " .. tostring(factory)
				.. "\n  import chain: " .. self:stackPath(name), 0)
		end
	end

	if not rec then
		error("[iy] unknown module '" .. name .. "'"
			.. "\n  import chain: " .. self:stackPath(name), 0)
	end

	if rec.state == STATE_LOADED then
		return rec.value
	end

	if rec.state == STATE_LOADING then
		error("[iy] circular import: " .. self:stackPath(name)
			.. "\n  break the cycle by importing lazily inside the function that needs it", 0)
	end

	if rec.state == STATE_FAILED then
		error("[iy] module '" .. name .. "' previously failed to load: " .. tostring(rec.error)
			.. "\n  import chain: " .. self:stackPath(name), 0)
	end

	rec.state = STATE_LOADING
	self.stack[#self.stack + 1] = name

	local started = now()
	local ok, result = xpcall(function() return rec.factory(self) end, tracebackOf)
	self.timings[name] = now() - started
	self.stack[#self.stack] = nil

	if not ok then
		rec.state = STATE_FAILED
		rec.error = result
		error("[iy] module '" .. name .. "' failed to load\n" .. tostring(result), 0)
	end

	if result == nil then
		rec.state = STATE_FAILED
		rec.error = "returned nil"
		error("[iy] module '" .. name .. "' returned nil -- missing `return M`?", 0)
	end

	rec.value = result
	rec.state = STATE_LOADED
	self.loadOrder[#self.loadOrder + 1] = name
	return result
end

--[[ Import without throwing. Returns value or nil, err. Used for optional
     subsystems (plugins, exploit-specific integrations) so one broken piece
     cannot take the whole script down. ]]
function Runtime:tryImport(name)
	local ok, result = pcall(self.import, self, name)
	if ok then return result end
	self:diagnostic("import", "optional module '" .. name .. "' failed", result)
	return nil, result
end

--[[ Import every module in `list`, continuing past failures. Returns the
     number that loaded and a table of {name, error} for the ones that did not.
     This is how command packs and UI panels are mounted: one bad pack must not
     prevent the other forty from working. ]]
function Runtime:importAll(list)
	local loaded, failures = 0, {}
	for i = 1, #list do
		local name = list[i]
		local ok, err = pcall(self.import, self, name)
		if ok then
			loaded = loaded + 1
		else
			failures[#failures + 1] = { name = name, error = err }
			self:diagnostic("import", "module '" .. name .. "' failed", err)
		end
	end
	return loaded, failures
end

--[[ Register a teardown callback. Runs LIFO on IY:unload(). ]]
function Runtime:onUnload(fn, label)
	if type(fn) ~= "function" then
		error("[iy] onUnload expects a function", 2)
	end
	self.teardown[#self.teardown + 1] = { fn = fn, label = label or self.stack[#self.stack] or "anonymous" }
	return fn
end

--[[ Tear the whole script down. Every callback runs even if others error;
     collected errors are returned so `;unloadiy` can report them. ]]
function Runtime:unload()
	if self.unloaded then return {} end
	self.unloaded = true
	local errors = {}
	for i = #self.teardown, 1, -1 do
		local entry = self.teardown[i]
		local ok, err = pcall(entry.fn)
		if not ok then
			errors[#errors + 1] = { label = entry.label, error = err }
		end
	end
	self.teardown = {}
	return errors
end

--[[ Boot report: what loaded, in what order, how long it took, what broke. ]]
function Runtime:report()
	local slowest, slowestName = 0, nil
	for name, seconds in pairs(self.timings) do
		if seconds > slowest then slowest, slowestName = seconds, name end
	end
	return {
		version     = self.version,
		channel     = self.channel,
		modules     = #self.loadOrder,
		order       = self.loadOrder,
		timings     = self.timings,
		slowest     = slowestName,
		slowestTime = slowest,
		diagnostics = self.diagnostics,
	}
end

return Runtime
end)()

local config = {}
do
	local ok, genv = pcall(function() return getgenv and getgenv() or _G end)
	if ok and type(genv) == "table" and type(genv.IY_CONFIG) == "table" then
		for key, value in pairs(genv.IY_CONFIG) do config[key] = value end
	end
end
config.version = config.version or "7.0.0"
config.channel = config.channel or "remote"
config.branch  = config.branch or "master"
config.base    = config.base or ("https://raw.githubusercontent.com/EdgeIY/infiniteyield/" .. config.branch .. "/")

local IY = __IY_RUNTIME__.new(config)

local cache = {}

local function fetch(url)
	if cache[url] then return cache[url] end
	local attempts, lastError = 0, nil
	while attempts < 3 do
		attempts = attempts + 1
		local ok, body = pcall(function() return game:HttpGet(url, true) end)
		if ok and type(body) == "string" and #body > 0 then
			cache[url] = body
			return body
		end
		lastError = body
		task.wait(0.35 * attempts)
	end
	error("[iy] could not fetch " .. url .. ": " .. tostring(lastError), 0)
end

local manifestChunk = loadstring(fetch(config.base .. "src/manifest.lua"), "=iy/manifest")
IY.manifest = manifestChunk()

--[[ Modules are compiled on demand; the runtime memoises the result. ]]
IY.resolve = function(name)
	local source = fetch(config.base .. "src/" .. name .. ".lua")
	local chunk, err = loadstring(source, "=iy/" .. name)
	if not chunk then
		error("[iy] syntax error in " .. name .. ": " .. tostring(err), 0)
	end
	return chunk
end

return (function(...)
--[[═══════════════════════════════════════════════════════════════════════════
	entry · the shared bootstrap
	─────────────────────────────────────────────────────────────────────────
	Runs after the module registry is populated (bundle mode) or resolvable
	(remote mode). Both loader.lua and the built `source` execute this exact
	body, so there is one definition of "starting up" for the whole project.

	Responsibilities, in order:
	  1. refuse to run twice
	  2. wait for the DataModel
	  3. expose the public global surface (getgenv().IY)
	  4. attach manifest helpers
	  5. run boot phases
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...

-- ── 1. single instance ──────────────────────────────────────────────────────

local genv = _G
do
	local ok, resolved = pcall(function() return getgenv and getgenv() or nil end)
	if ok and type(resolved) == "table" then genv = resolved end
end

if genv.IY and genv.IY.ready and not genv.IY_DEBUG then
	local existing = genv.IY
	-- Re-running the loader is the most common way users "restart" IY. Rather
	-- than stacking a second copy (which the legacy script only half-prevented
	-- with an IY_LOADED flag it set before it could fail), surface the running
	-- instance and open its command bar.
	pcall(function() existing.focus() end)
	return existing
end

if genv.IY and genv.IY.unload then
	-- A previous instance exists but never finished booting, or debug mode is
	-- on: tear it down first so its connections do not double up.
	pcall(function() genv.IY.unload() end)
end

genv.IY_LOADED = true
genv.IY = IY

-- ── 2. DataModel ────────────────────────────────────────────────────────────

if not game:IsLoaded() then
	game.Loaded:Wait()
end

-- ── 3. manifest helpers ─────────────────────────────────────────────────────

local manifest = IY.manifest or { files = {} }
IY.manifest = manifest

--[[ Every module whose name starts with `prefix`, sorted. Used by boot to pick
     up command packs and UI panels without a hand-maintained list -- dropping a
     file into src/commands/ is all it takes to register it. ]]
function manifest.byPrefix(prefix)
	local out = {}
	local files = manifest.files or {}
	for i = 1, #files do
		local name = files[i]
		if string.sub(name, 1, #prefix) == prefix then out[#out + 1] = name end
	end
	table.sort(out)
	return out
end

function manifest.has(name)
	local files = manifest.files or {}
	for i = 1, #files do
		if files[i] == name then return true end
	end
	return false
end

-- ── 4. public surface ───────────────────────────────────────────────────────

local Signal = IY.import("core/signal")
IY.readySignal = Signal.new("iy.ready")

--[[ The stable API plugins and other scripts use. Everything else is internal.]]
function IY.command(definition)
	return IY.import("cmd/api").register(definition, "external")
end

function IY.exec(line)
	return IY.import("cmd/dispatch").run(line)
end

function IY.notify(title, text, duration)
	return IY.import("core/notify").send(title, text, duration)
end

function IY.focus()
	local ok, UI = pcall(function() return IY.import("ui/init") end)
	if ok and UI and UI.focus then return UI.focus() end
	return false
end

--[[ The runtime's own teardown, captured before we shadow the name: `IY.unload`
     below is the public API, and calling `IY:unload()` from inside it would
     recurse into itself. ]]
local runtimeUnload = IY.unload

function IY.unload()
	local errors = runtimeUnload()
	genv.IY_LOADED = nil
	if genv.IY == IY then genv.IY = nil end
	return errors
end

--[[ `IY.diagnostics` is the runtime's own list of load-time problems, so the
     report accessor is named differently to avoid shadowing it. ]]
function IY.diagnose()
	return IY.import("boot").diagnostics()
end

-- ── 5. boot ─────────────────────────────────────────────────────────────────

local Boot = IY.import("boot")
local report = Boot.start()

return IY
end)(IY)
