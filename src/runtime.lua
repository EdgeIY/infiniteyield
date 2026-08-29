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
