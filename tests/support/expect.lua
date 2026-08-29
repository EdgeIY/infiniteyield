--[[═══════════════════════════════════════════════════════════════════════════
	tests/support/expect · a tiny assertion library
	─────────────────────────────────────────────────────────────────────────
	No dependencies, readable failures, and it counts everything so the runner
	can report "412 assertions, 0 failed" rather than just "ok".
═══════════════════════════════════════════════════════════════════════════]]

local M = {}

M.assertions = 0
M.failures = {}
M.context = "?"

local function describe(value)
	local kind = type(value)
	if kind == "string" then return string.format("%q", value) end
	if kind == "table" then
		local count = 0
		for _ in pairs(value) do count = count + 1 end
		return "table(" .. tostring(count) .. ")"
	end
	return tostring(value)
end
M.describe = describe

local function record(ok, message)
	M.assertions = M.assertions + 1
	if ok then return true end
	M.failures[#M.failures + 1] = { context = M.context, message = message }
	return false
end

function M.setContext(name)
	M.context = name
end

function M.ok(value, message)
	return record(value and true or false,
		(message or "expected truthy") .. " (got " .. describe(value) .. ")")
end

function M.notOk(value, message)
	return record(not value,
		(message or "expected falsy") .. " (got " .. describe(value) .. ")")
end

function M.equal(actual, expected, message)
	return record(actual == expected,
		(message or "values differ") .. ": expected " .. describe(expected)
		.. ", got " .. describe(actual))
end

function M.notEqual(actual, expected, message)
	return record(actual ~= expected,
		(message or "values should differ") .. ": both " .. describe(actual))
end

function M.near(actual, expected, tolerance, message)
	tolerance = tolerance or 1e-6
	local ok = type(actual) == "number" and math.abs(actual - expected) <= tolerance
	return record(ok, (message or "numbers differ") .. ": expected ~" .. tostring(expected)
		.. ", got " .. describe(actual))
end

function M.isType(value, expected, message)
	return record(type(value) == expected,
		(message or "wrong type") .. ": expected " .. expected .. ", got " .. type(value))
end

function M.contains(haystack, needle, message)
	local ok = type(haystack) == "string" and string.find(haystack, needle, 1, true) ~= nil
	return record(ok, (message or "substring missing") .. ": " .. describe(needle)
		.. " not in " .. describe(haystack))
end

function M.count(list, expected, message)
	local actual = type(list) == "table" and #list or -1
	return record(actual == expected,
		(message or "wrong length") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

--[[ Assert fn() raises, and optionally that the message contains `needle`. ]]
function M.raises(fn, needle, message)
	local ok, err = pcall(fn)
	if ok then
		return record(false, (message or "expected an error") .. " but the call succeeded")
	end
	if needle then
		local text = tostring(err)
		return record(string.find(text, needle, 1, true) ~= nil,
			(message or "wrong error") .. ": expected to contain " .. describe(needle)
			.. ", got " .. describe(text))
	end
	return record(true, "")
end

function M.succeeds(fn, message)
	local ok, err = pcall(fn)
	return record(ok, (message or "call failed") .. ": " .. tostring(err))
end

function M.reset()
	M.assertions = 0
	M.failures = {}
end

return M
