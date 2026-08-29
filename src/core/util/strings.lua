--[[═══════════════════════════════════════════════════════════════════════════
	core/util/strings · string helpers
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...

local M = {}

--[[ Split on a single-character delimiter, dropping empty fields (matches the
     legacy splitString so command syntax stays identical). ]]
function M.split(str, delim)
	local out = {}
	if type(str) ~= "string" then return out end
	delim = delim or ","
	for piece in string.gmatch(str, "[^" .. M.escape(delim) .. "]+") do
		out[#out + 1] = piece
	end
	return out
end

--[[ Split keeping empty fields -- needed for saved data round-trips. ]]
function M.splitKeep(str, delim)
	local out = {}
	if type(str) ~= "string" then return out end
	delim = delim or ","
	local start = 1
	while true do
		local found = string.find(str, delim, start, true)
		if not found then
			out[#out + 1] = string.sub(str, start)
			break
		end
		out[#out + 1] = string.sub(str, start, found - 1)
		start = found + #delim
	end
	return out
end

--[[ Escape Lua pattern magic characters. ]]
function M.escape(str)
	return (string.gsub(tostring(str), "([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1"))
end

function M.trim(str)
	if type(str) ~= "string" then return "" end
	return (string.gsub(str, "^%s*(.-)%s*$", "%1"))
end

function M.startsWith(str, prefix)
	return string.sub(tostring(str), 1, #prefix) == prefix
end

function M.endsWith(str, suffix)
	if suffix == "" then return true end
	return string.sub(tostring(str), -#suffix) == suffix
end

function M.lower(str)
	return string.lower(tostring(str or ""))
end

--[[ Case-insensitive "does haystack start with needle". ]]
function M.matchesPrefix(haystack, needle)
	haystack, needle = M.lower(haystack), M.lower(needle)
	return string.sub(haystack, 1, #needle) == needle
end

function M.contains(haystack, needle)
	return string.find(M.lower(haystack), M.lower(needle), 1, true) ~= nil
end

--[[ Truncate with an ellipsis. ]]
function M.truncate(str, limit)
	str = tostring(str)
	if #str <= limit then return str end
	return string.sub(str, 1, math.max(1, limit - 3)) .. "..."
end

function M.capitalise(str)
	str = tostring(str or "")
	return (string.gsub(str, "^%l", string.upper))
end

--[[ "5" -> 5, "1e3" -> 1000, "abc" -> nil. Also accepts 1_000 and 50%. ]]
function M.toNumber(str)
	if type(str) == "number" then return str end
	if type(str) ~= "string" then return nil end
	str = M.trim(str)
	str = string.gsub(str, "_", "")
	local percent = string.match(str, "^([%-%d%.]+)%%$")
	if percent then
		local value = tonumber(percent)
		if value then return value / 100 end
	end
	return tonumber(str)
end

--[[ Human-friendly durations: 1m30s, 500ms, 2.5, 1h. ]]
function M.toSeconds(str)
	if type(str) == "number" then return str end
	if type(str) ~= "string" then return nil end
	str = M.lower(M.trim(str))
	local plain = tonumber(str)
	if plain then return plain end
	local total, matched = 0, false
	for value, unit in string.gmatch(str, "([%d%.]+)%s*(%a*)") do
		local number = tonumber(value)
		if not number then return nil end
		matched = true
		if unit == "ms" then total = total + number / 1000
		elseif unit == "s" or unit == "" then total = total + number
		elseif unit == "m" then total = total + number * 60
		elseif unit == "h" then total = total + number * 3600
		else return nil end
	end
	if not matched then return nil end
	return total
end

--[[ Comma-separate a list for messages: "a, b and c". ]]
function M.list(items, conjunction)
	local count = #items
	if count == 0 then return "" end
	if count == 1 then return tostring(items[1]) end
	local head = {}
	for i = 1, count - 1 do head[#head + 1] = tostring(items[i]) end
	return table.concat(head, ", ") .. " " .. (conjunction or "and") .. " " .. tostring(items[count])
end

function M.pluralise(count, singular, plural)
	if count == 1 then return "1 " .. singular end
	return tostring(count) .. " " .. (plural or (singular .. "s"))
end

--[[ Random alphabetic name -- used to make GUI instance names unguessable. ]]
function M.random(length)
	local out = {}
	for _ = 1, length or 16 do
		out[#out + 1] = string.char(math.random(65, 90) + (math.random(0, 1) * 32))
	end
	return table.concat(out)
end

--[[ Comma-group a number: 1234567 -> "1,234,567". ]]
function M.comma(number)
	local formatted = tostring(math.floor(tonumber(number) or 0))
	local negative = string.sub(formatted, 1, 1) == "-"
	if negative then formatted = string.sub(formatted, 2) end
	local out = string.reverse(formatted)
	out = string.gsub(out, "(%d%d%d)", "%1,")
	out = string.reverse(out)
	out = string.gsub(out, "^,", "")
	return (negative and "-" or "") .. out
end

--[[ HH:MM:SS AM/PM from a monotonic clock value (legacy Time()). ]]
function M.clockTime(seconds)
	seconds = seconds or (os.time and os.time() or tick())
	local hour = math.floor((seconds % 86400) / 3600)
	local minute = math.floor((seconds % 3600) / 60)
	local second = math.floor(seconds % 60)
	local suffix = hour > 11 and "PM" or "AM"
	hour = (hour % 12 == 0) and 12 or (hour % 12)
	return string.format("%02d:%02d:%02d %s", hour, minute, second, suffix)
end

--[[ Damerau-Levenshtein distance (optimal string alignment), capped for speed.
     Adjacent transpositions count as one edit, which matters because most
     command typos are transpositions: "fyl" is one edit from "fly" but two from
     "fov", so "did you mean" picks the right one. ]]
function M.distance(a, b, cap)
	a, b = M.lower(a), M.lower(b)
	if a == b then return 0 end
	local la, lb = #a, #b
	cap = cap or 4
	if math.abs(la - lb) > cap then return cap + 1 end

	local rows = {}
	for i = 0, la do
		rows[i] = {}
		rows[i][0] = i
	end
	for j = 0, lb do rows[0][j] = j end

	for i = 1, la do
		local best = math.huge
		local ai = string.byte(a, i)
		for j = 1, lb do
			local cost = (ai == string.byte(b, j)) and 0 or 1
			local value = math.min(
				rows[i - 1][j] + 1,
				rows[i][j - 1] + 1,
				rows[i - 1][j - 1] + cost)
			if i > 1 and j > 1
				and ai == string.byte(b, j - 1)
				and string.byte(a, i - 1) == string.byte(b, j) then
				value = math.min(value, rows[i - 2][j - 2] + 1)
			end
			rows[i][j] = value
			if value < best then best = value end
		end
		if best > cap then return cap + 1 end
	end
	return rows[la][lb]
end

return M
