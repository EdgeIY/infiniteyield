--[[═══════════════════════════════════════════════════════════════════════════
	core/log · levelled logging with an in-memory ring buffer
	─────────────────────────────────────────────────────────────────────────
	The legacy script printed errors only when `_G.IY_DEBUG` was on, so real
	failures were invisible by default. Here everything is recorded to a ring
	buffer that `;iylog` / the diagnostics panel can show, while console noise
	stays opt-in:

	    Log.info("boot", "loaded %d commands", n)   -- buffered, not printed
	    Log.warn("fly", "no character")             -- buffered + warn()
	    Log.error("cmd:fly", err)                   -- buffered + warn(), counted
	    Log.debug(...)                              -- only when debug mode is on

	Scoped loggers avoid repeating the tag:
	    local log = Log.scope("features/fly")
	    log.warn("no character")
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Signal = IY.import("core/signal")

local M = {}

local LEVELS = { trace = 10, debug = 20, info = 30, warn = 40, error = 50 }
local LEVEL_NAMES = { [10] = "TRACE", [20] = "DEBUG", [30] = "INFO", [40] = "WARN", [50] = "ERROR" }

local BUFFER_LIMIT = 300

M.levels     = LEVELS
M.buffer     = {}
M.counts     = { trace = 0, debug = 0, info = 0, warn = 0, error = 0 }
M.written    = Signal.new("log.written")
M.consoleLevel = LEVELS.warn      -- what reaches warn()/print()
M.debugMode  = false

local function stamp()
	local ok, t = pcall(function() return os.date("%H:%M:%S") end)
	if ok and t then return t end
	return "--:--:--"
end

local function stringify(value)
	local t = type(value)
	if t == "string" then return value end
	if t == "nil" then return "nil" end
	if t == "table" then
		if value.iyCapability then return "unsupported by executor: " .. tostring(value.iyCapability) end
		local ok, encoded = pcall(function()
			local parts = {}
			for k, v in pairs(value) do
				parts[#parts + 1] = tostring(k) .. "=" .. tostring(v)
				if #parts >= 8 then parts[#parts + 1] = "..." break end
			end
			return "{" .. table.concat(parts, ", ") .. "}"
		end)
		if ok then return encoded end
	end
	return tostring(value)
end
M.stringify = stringify

local function format(first, ...)
	if select("#", ...) == 0 then return stringify(first) end
	local ok, result = pcall(string.format, stringify(first), ...)
	if ok then return result end
	-- Called with values rather than a format string: join them.
	local parts = { stringify(first) }
	local args = { ... }
	for i = 1, select("#", ...) do parts[#parts + 1] = stringify(args[i]) end
	return table.concat(parts, " ")
end

local function write(level, tag, message)
	local entry = {
		level   = level,
		levelName = LEVEL_NAMES[level],
		tag     = tag or "iy",
		message = message,
		time    = stamp(),
	}
	local buffer = M.buffer
	buffer[#buffer + 1] = entry
	if #buffer > BUFFER_LIMIT then table.remove(buffer, 1) end

	local name = string.lower(LEVEL_NAMES[level])
	M.counts[name] = (M.counts[name] or 0) + 1

	if level >= M.consoleLevel then
		local line = "[IY:" .. entry.tag .. "] " .. message
		if level >= LEVELS.warn then warn(line) else print(line) end
	end
	M.written:Fire(entry)
	return entry
end
M.write = write

function M.trace(tag, ...) return write(LEVELS.trace, tag, format(...)) end
function M.info(tag, ...)  return write(LEVELS.info,  tag, format(...)) end
function M.warn(tag, ...)  return write(LEVELS.warn,  tag, format(...)) end
function M.error(tag, ...) return write(LEVELS.error, tag, format(...)) end

function M.debug(tag, ...)
	if not M.debugMode then return end
	return write(LEVELS.debug, tag, format(...))
end

--[[ Enable/disable console output of debug lines. ;debug flips this. ]]
function M.setDebug(on)
	M.debugMode = not not on
	M.consoleLevel = M.debugMode and LEVELS.debug or LEVELS.warn
	return M.debugMode
end

--[[ A logger bound to one tag. ]]
function M.scope(tag)
	return {
		tag   = tag,
		trace = function(...) return M.trace(tag, ...) end,
		debug = function(...) return M.debug(tag, ...) end,
		info  = function(...) return M.info(tag, ...) end,
		warn  = function(...) return M.warn(tag, ...) end,
		error = function(...) return M.error(tag, ...) end,
	}
end

--[[ Recent entries, newest last, optionally filtered by minimum level. ]]
function M.recent(count, minLevel)
	local out = {}
	local buffer = M.buffer
	for i = #buffer, 1, -1 do
		local entry = buffer[i]
		if not minLevel or entry.level >= minLevel then
			table.insert(out, 1, entry)
			if #out >= (count or 50) then break end
		end
	end
	return out
end

function M.dump(minLevel)
	local lines = {}
	local entries = M.recent(BUFFER_LIMIT, minLevel)
	for i = 1, #entries do
		local e = entries[i]
		lines[#lines + 1] = e.time .. " " .. e.levelName .. " [" .. e.tag .. "] " .. e.message
	end
	return table.concat(lines, "\n")
end

function M.clear()
	M.buffer = {}
	for key in pairs(M.counts) do M.counts[key] = 0 end
end

-- Signals report handler failures through here instead of a bare warn().
Signal.onError = function(err, signalName, source)
	write(LEVELS.error, "signal", tostring(signalName) .. " handler failed at " .. tostring(source) .. ": " .. stringify(err))
end

-- Runtime diagnostics (module load problems) land in the same buffer.
IY.onDiagnostic = function(entry)
	write(LEVELS.warn, "runtime", tostring(entry.kind) .. ": " .. tostring(entry.message)
		.. (entry.detail and ("\n  " .. stringify(entry.detail)) or ""))
end

IY.log = M
return M
