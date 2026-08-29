--[[═══════════════════════════════════════════════════════════════════════════
	core/guard · error containment and classification
	─────────────────────────────────────────────────────────────────────────
	Three kinds of failure need three different treatments, and the legacy
	script treated them all the same (a silent pcall):

	  · user error      -- bad arguments, no target found. Show a message.
	  · capability      -- the executor cannot do this. Explain why.
	  · internal error  -- a real bug. Log it with a traceback, keep running.

	    Guard.fail("no player matched '%s'", query)   -- raise a user error
	    Guard.need("hookfunction")                    -- raise a capability error
	    local ok, err = Guard.call("fly.step", step)   -- contain + classify
	    Guard.describe(err)                            -- one line for the user

	Guard.call never lets an error escape, always records internal errors to
	core/log, and returns a classified error object so callers can decide how
	to surface it.
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Log = IY.import("core/log")
local Env = IY.import("core/env")

local unpack = table.unpack or unpack
local pack = table.pack or function(...) return { n = select("#", ...), ... } end

local M = {}

local USER_TAG = "\1iy-user\1"

-- The tag contains a `-`, which is a Lua pattern quantifier: interpolating the
-- raw tag into a pattern silently matched nothing, so every user error was
-- classified as internal and shown with the tag still attached.
local USER_PATTERN = (string.gsub(USER_TAG, "([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1"))

--[[ Raise a message meant for the person who typed the command. ]]
function M.fail(message, ...)
	if select("#", ...) > 0 then
		local ok, formatted = pcall(string.format, message, ...)
		message = ok and formatted or message
	end
	error(USER_TAG .. tostring(message), 0)
end

--[[ Raise a "your executor cannot do this" error. ]]
function M.need(capability)
	if not Env.usable(capability) then
		error({ iyCapability = capability }, 0)
	end
	return Env.fn[capability]
end

--[[ Assert with a user-facing message. ]]
function M.assert(condition, message, ...)
	if not condition then M.fail(message, ...) end
	return condition
end

--[[ Classify any caught error value. ]]
function M.classify(err)
	if type(err) == "table" then
		if err.iyCapability then
			return "capability", Env.explain(err.iyCapability), err.iyCapability
		end
		if err.iyUser then
			return "user", tostring(err.iyUser)
		end
		return "internal", Log.stringify(err)
	end
	local text = tostring(err)
	local stripped = string.match(text, "^" .. USER_PATTERN .. "(.*)$")
		or string.match(text, USER_PATTERN .. "(.*)$")
	if stripped then
		-- Strip a trailing traceback Roblox may have appended.
		stripped = string.gsub(stripped, "\nstack traceback:.*$", "")
		return "user", stripped
	end
	return "internal", text
end

--[[ One short line suitable for a notification. ]]
function M.describe(err)
	local kind, message = M.classify(err)
	if kind == "user" or kind == "capability" then return message end
	-- Trim Roblox's "script:123:" prefix for readability.
	message = string.gsub(message, "^.-:%d+:%s*", "")
	message = string.gsub(message, "\nstack traceback:.*$", "")
	local firstLine = string.match(message, "^[^\n]*") or message
	if #firstLine > 160 then firstLine = string.sub(firstLine, 1, 157) .. "..." end
	return firstLine
end

local function traceback(err)
	if type(err) == "table" then return err end
	if type(debug) == "table" and type(debug.traceback) == "function" then
		local ok, tb = pcall(debug.traceback, tostring(err), 2)
		if ok then return tb end
	end
	return err
end

--[[ Run fn(...) with full containment.
     Returns true, results... on success.
     Returns false, err, kind on failure (internal errors are logged). ]]
function M.call(label, fn, ...)
	local args = pack(...)
	local results = pack(xpcall(function() return fn(unpack(args, 1, args.n)) end, traceback))
	if results[1] then
		return true, unpack(results, 2, results.n)
	end
	local err = results[2]
	local kind, message = M.classify(err)
	if kind == "internal" then
		Log.error(label or "guard", "%s", tostring(err))
	else
		Log.debug(label or "guard", "%s: %s", kind, message)
	end
	return false, err, kind
end

--[[ Single-return variant kept separate so hot paths avoid the pack(). ]]
function M.callArgs(label, fn, ...)
	local args = pack(...)
	local ok, result = xpcall(function() return fn(unpack(args, 1, args.n)) end, traceback)
	if ok then return true, result end
	local kind, message = M.classify(result)
	if kind == "internal" then
		Log.error(label or "guard", "%s", tostring(result))
	else
		Log.debug(label or "guard", "%s: %s", kind, message)
	end
	return false, result, kind
end

--[[ Wrap fn so it can never throw. Ideal for event handlers. ]]
function M.wrap(label, fn)
	return function(...)
		local ok, err = M.callArgs(label, fn, ...)
		if not ok then return nil, err end
		return err
	end
end

--[[ Retry a flaky operation (HTTP, WaitForChild) with linear backoff. ]]
function M.retry(label, attempts, delay, fn)
	local lastErr
	for attempt = 1, math.max(1, attempts) do
		local ok, result = pcall(fn, attempt)
		if ok then return true, result end
		lastErr = result
		Log.debug(label, "attempt %d/%d failed: %s", attempt, attempts, Log.stringify(result))
		if attempt < attempts then task.wait(delay or 0.25) end
	end
	return false, lastErr
end

--[[ pcall that returns nil instead of false on failure -- for reads that are
     allowed to fail (properties behind FFlags, hidden properties). ]]
function M.try(fn, ...)
	local ok, result = pcall(fn, ...)
	if ok then return result end
	return nil
end

M.USER_TAG = USER_TAG

IY.guard = M
return M
