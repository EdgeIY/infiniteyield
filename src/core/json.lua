--[[═══════════════════════════════════════════════════════════════════════════
	core/json · JSON codec with a native fast path and a correct fallback
	─────────────────────────────────────────────────────────────────────────
	IY needs JSON for the settings file, waypoint exports, webhook payloads and
	plugin manifests. HttpService:JSONEncode/JSONDecode is the fast path, but it
	cannot be the only path:

	  · executors hook HttpService, so the methods may be replaced, wrapped, or
	    made to throw on tables the real ones accept
	  · JSONDecode silently DROPS keys whose value is null, which quietly loses
	    the user's `logsWebhook` on every load/save round trip
	  · JSONEncode writes an empty table as `[]`, cannot pretty-print, and
	    orders keys by hash, so the settings file churns between saves and the
	    diffs users look at are noise

	So the native path is used only where it cannot be observed to differ: a
	non-pretty encode of a document with no nulls, no empty tables, no tagged
	arrays and no mixed-key tables, and a decode of text containing no `null`.
	Everything else uses the pure-Lua implementation below -- which is also what
	you get once a hooked native encoder fails (after one failure it is never
	trusted again) or when `M.native` is set to false.

	    Json.encode(doc, true)     -- 2-space indent, sorted keys, stable bytes
	    Json.decode(text)          -- value, or nil + message; never throws
	    Json.decodeStrict(text)    -- value, or a user-facing error with offset
	    Json.null                  -- decoded null; re-encodes as null
	    Json.array(t)              -- always encode t as [], even when empty
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Guard    = IY.import("core/guard")
local Services = IY.import("core/services")

local M = {}

local floor, huge = math.floor, math.huge
local concat, sort = table.concat, table.sort
local byte, char, find, format, gsub, match, rep, sub =
	string.byte, string.char, string.find, string.format, string.gsub,
	string.match, string.rep, string.sub

-- ── sentinels ───────────────────────────────────────────────────────────────

--[[ A decoded JSON `null`. A distinct value rather than nil, so that a key
     whose value is null survives decode -> encode instead of vanishing: the
     legacy settings file stores `"logsWebhook":null` and losing that key on
     every save is how "my webhook keeps unsetting itself" happened. ]]
local NULL = setmetatable({}, {
	__tostring  = function() return "json.null" end,
	__metatable = "json.null",
})
M.null = NULL
function M.isNull(value)
	return value == NULL
end

--[[ Tables tagged here always encode as a JSON array. This is the only way to
     express "empty array" in Lua, where `{}` is indistinguishable from an empty
     object. Weak keys, so tagging a document cannot keep it alive. ]]
local tagged = setmetatable({}, { __mode = "k" })

function M.array(t)
	if type(t) ~= "table" then
		Guard.fail("json.array expects a table, got %s", type(t))
	end
	tagged[t] = true
	return t
end

function M.isArray(t)
	return tagged[t] == true
end

M.emptyArray = M.array({})

-- ── native fast path ────────────────────────────────────────────────────────

local nativeEncode, nativeDecode

--[[ Probe once at load. A hooked HttpService that throws is common enough that
     discovering it lazily -- halfway through writing the settings file -- is
     not acceptable. ]]
do
	local http = Services.get("HttpService")
	if not http then
		M.nativeStatus = "HttpService unavailable"
	else
		local ok, encoded = pcall(function() return http:JSONEncode({ iy = 1 }) end)
		local roundTripped = false
		if ok and type(encoded) == "string" then
			local ok2, decoded = pcall(function() return http:JSONDecode(encoded) end)
			roundTripped = ok2 and type(decoded) == "table" and decoded.iy == 1
		end
		if roundTripped then
			nativeEncode = function(value) return http:JSONEncode(value) end
			nativeDecode = function(text) return http:JSONDecode(text) end
			M.nativeStatus = "available"
		else
			M.nativeStatus = "HttpService JSON round trip failed (hooked?)"
		end
	end
end

M.nativeAvailable = nativeEncode ~= nil
M.native = M.nativeAvailable

-- ── encode ──────────────────────────────────────────────────────────────────

local ESCAPES = {
	['"'] = '\\"', ["\\"] = "\\\\", ["\b"] = "\\b", ["\f"] = "\\f",
	["\n"] = "\\n", ["\r"] = "\\r", ["\t"] = "\\t",
}

--[[ Only control characters, quotes and backslashes have to be escaped; UTF-8
     bytes are passed through, which keeps non-Latin player names readable in
     the settings file. `/` is deliberately not escaped -- legal either way, and
     `\/` only matters when embedding JSON inside HTML. ]]
local function encodeString(value)
	return '"' .. gsub(value, '[%c"\\]', function(c)
		return ESCAPES[c] or format("\\u%04x", byte(c))
	end) .. '"'
end

--[[ Integers print as integers; everything else uses the shortest form that
     still reads back as the same double, so 0.3 stays "0.3" while a value that
     needs all 17 digits keeps them. ]]
local function encodeNumber(value, path)
	if value ~= value or value == huge or value == -huge then
		Guard.fail("cannot encode %s as JSON (at %s) -- JSON has no inf/nan",
			tostring(value), path or "?")
	end
	if value % 1 == 0 and value < 1e15 and value > -1e15 then
		return format("%d", value)
	end
	local text = format("%.14g", value)
	if tonumber(text) ~= value then text = format("%.17g", value) end
	return text
end

--[[ "array"  keys are exactly 1..#t (or the table was tagged)
     "object" every key is a string
     "empty"  no keys at all -- encoded as {} unless tagged
     "mixed"  anything else; written as an object with stringified keys, which
              the native encoder would treat differently, so it forces the
              pure path. ]]
local function classify(t)
	local count, keys = #t, 0
	local allStrings, isSequence = true, true
	for key in pairs(t) do
		keys = keys + 1
		if type(key) == "string" then
			isSequence = false
		elseif type(key) == "number" and key % 1 == 0 and key >= 1 and key <= count then
			allStrings = false
		else
			allStrings, isSequence = false, false
		end
	end
	if keys == 0 then return tagged[t] and "array" or "empty" end
	if isSequence and keys == count then return "array" end
	if allStrings then return "object" end
	return "mixed"
end

--[[ Walk the value before emitting anything: a bad number six levels down must
     not leave half a settings file written. Raises on cycles, non-finite
     numbers and values JSON cannot represent, and returns true when the
     document contains something the native encoder would render differently. ]]
local function inspect(value, seen, path)
	if value == NULL then return true end
	local kind = type(value)
	if kind == "nil" or kind == "boolean" or kind == "string" then return false end
	if kind == "number" then
		if value ~= value or value == huge or value == -huge then
			Guard.fail("cannot encode %s as JSON (at %s) -- JSON has no inf/nan",
				tostring(value), path)
		end
		return false
	end
	if kind ~= "table" then
		Guard.fail("cannot encode a %s as JSON (at %s)",
			(typeof and typeof(value)) or kind, path)
	end
	if seen[value] then
		Guard.fail("cycle detected while encoding JSON: %s at %s is already open at %s",
			tostring(value), path, seen[value])
	end
	seen[value] = path
	local shape = classify(value)
	local special = shape ~= "array" and shape ~= "object"
	if tagged[value] then special = true end
	if shape == "array" then
		for i = 1, #value do
			if inspect(value[i], seen, path .. "[" .. i .. "]") then special = true end
		end
	else
		for key, item in pairs(value) do
			local keyType = type(key)
			if keyType ~= "string" and keyType ~= "number" then
				Guard.fail("cannot use a %s as a JSON object key (at %s)", keyType, path)
			end
			if inspect(item, seen, path .. "." .. tostring(key)) then special = true end
		end
	end
	-- Cleared on the way out: the same table appearing twice side by side is a
	-- shared reference, not a cycle, and must not be rejected.
	seen[value] = nil
	return special
end

local encodeValue

local function encodeArray(value, out, pretty, depth)
	local count = #value
	if count == 0 then out[#out + 1] = "[]" return end
	out[#out + 1] = pretty and "[\n" or "["
	local pad = pretty and rep("  ", depth + 1) or ""
	for i = 1, count do
		if i > 1 then out[#out + 1] = pretty and ",\n" or "," end
		if pretty then out[#out + 1] = pad end
		encodeValue(value[i], out, pretty, depth + 1)
	end
	out[#out + 1] = pretty and ("\n" .. rep("  ", depth) .. "]") or "]"
end

--[[ Keys are always sorted, pretty or not: the settings file is rewritten on
     every change and users diff it, so byte output must not depend on Lua's
     hash order. ]]
local function encodeObject(value, out, pretty, depth)
	local keys = {}
	for key in pairs(value) do keys[#keys + 1] = key end
	if #keys == 0 then out[#out + 1] = "{}" return end
	sort(keys, function(a, b) return tostring(a) < tostring(b) end)
	out[#out + 1] = pretty and "{\n" or "{"
	local pad = pretty and rep("  ", depth + 1) or ""
	for i = 1, #keys do
		local key = keys[i]
		if i > 1 then out[#out + 1] = pretty and ",\n" or "," end
		if pretty then out[#out + 1] = pad end
		out[#out + 1] = encodeString(tostring(key))
		out[#out + 1] = pretty and ": " or ":"
		encodeValue(value[key], out, pretty, depth + 1)
	end
	out[#out + 1] = pretty and ("\n" .. rep("  ", depth) .. "}") or "}"
end

function encodeValue(value, out, pretty, depth)
	if value == nil or value == NULL then out[#out + 1] = "null" return end
	local kind = type(value)
	if kind == "boolean" then out[#out + 1] = value and "true" or "false" return end
	if kind == "number" then out[#out + 1] = encodeNumber(value) return end
	if kind == "string" then out[#out + 1] = encodeString(value) return end
	local shape = classify(value)
	if shape == "array" then return encodeArray(value, out, pretty, depth) end
	if shape == "empty" then out[#out + 1] = "{}" return end
	return encodeObject(value, out, pretty, depth)
end

--[[ The pure-Lua encoder. Exposed so callers that must not touch a hooked
     HttpService (and the tests) can ask for it by name. ]]
function M.encodeLua(value, pretty)
	inspect(value, {}, "$")
	local out = {}
	encodeValue(value, out, pretty and true or false, 0)
	return concat(out)
end

--[[ `pretty` gives 2-space indentation and forces the pure encoder, because
     HttpService cannot pretty-print. Raises (user-facing) on cycles, inf/nan
     and values with no JSON representation. ]]
function M.encode(value, pretty)
	local special = inspect(value, {}, "$")
	if not pretty and M.native and nativeEncode and not special then
		local ok, encoded = pcall(nativeEncode, value)
		if ok and type(encoded) == "string" then return encoded end
		-- It round-tripped during the probe and fails now: a hook landed on it
		-- mid-session, so stop trusting it for the rest of the session.
		M.native = false
		M.nativeStatus = "JSONEncode failed at runtime"
	end
	local out = {}
	encodeValue(value, out, pretty and true or false, 0)
	return concat(out)
end

-- ── decode ──────────────────────────────────────────────────────────────────

-- Deep enough for any real settings file, shallow enough that a hostile
-- plugin manifest cannot blow the C stack.
local MAX_DEPTH = 200

local UNESCAPES = {
	['"'] = '"', ["\\"] = "\\", ["/"] = "/", b = "\b", f = "\f",
	n = "\n", r = "\r", t = "\t",
}

local function fail(pos, message, ...)
	if select("#", ...) > 0 then
		local ok, formatted = pcall(format, message, ...)
		message = ok and formatted or message
	end
	error({ iyJson = true, position = pos, message = message }, 0)
end

local function skip(text, pos)
	local _, last = find(text, "^[ \t\r\n]*", pos)
	return (last or (pos - 1)) + 1
end

--[[ Codepoint -> UTF-8, written out rather than using utf8.char so the module
     behaves identically under Luau and under plain 5.1. ]]
local function utf8Char(code)
	if code < 0x80 then return char(code) end
	if code < 0x800 then
		return char(0xC0 + floor(code / 0x40), 0x80 + code % 0x40)
	end
	if code < 0x10000 then
		return char(0xE0 + floor(code / 0x1000),
			0x80 + floor(code / 0x40) % 0x40, 0x80 + code % 0x40)
	end
	return char(0xF0 + floor(code / 0x40000),
		0x80 + floor(code / 0x1000) % 0x40,
		0x80 + floor(code / 0x40) % 0x40,
		0x80 + code % 0x40)
end

local function hex4(text, pos)
	local digits = sub(text, pos, pos + 3)
	if not find(digits, "^%x%x%x%x$") then return nil end
	return tonumber(digits, 16)
end

--[[ `pos` is the opening quote; returns the string and the position after the
     closing quote. Runs of ordinary characters are copied one slice at a time
     rather than one character at a time -- this is on the settings load path. ]]
local function parseString(text, pos)
	local parts, count = {}, 0
	local cursor = pos + 1
	while true do
		local stop = find(text, '["\\]', cursor)
		if not stop then fail(pos, "unterminated string") end
		if stop > cursor then
			count = count + 1
			parts[count] = sub(text, cursor, stop - 1)
		end
		if sub(text, stop, stop) == '"' then
			return concat(parts, "", 1, count), stop + 1
		end
		local esc = sub(text, stop + 1, stop + 1)
		if esc == "" then fail(stop, "unterminated escape sequence") end
		local simple = UNESCAPES[esc]
		if simple then
			count = count + 1
			parts[count] = simple
			cursor = stop + 2
		elseif esc == "u" then
			local code = hex4(text, stop + 2)
			if not code then fail(stop, "\\u must be followed by four hex digits") end
			cursor = stop + 6
			if code >= 0xD800 and code <= 0xDBFF then
				-- High surrogate: join it with the low half. A lone surrogate
				-- becomes U+FFFD, because emitting it raw would produce a
				-- string Roblox cannot render.
				local low = sub(text, cursor, cursor + 1) == "\\u" and hex4(text, cursor + 2)
				if low and low >= 0xDC00 and low <= 0xDFFF then
					code = 0x10000 + (code - 0xD800) * 0x400 + (low - 0xDC00)
					cursor = cursor + 6
				else
					code = 0xFFFD
				end
			elseif code >= 0xDC00 and code <= 0xDFFF then
				code = 0xFFFD
			end
			count = count + 1
			parts[count] = utf8Char(code)
		else
			fail(stop, "invalid escape sequence '\\%s'", esc)
		end
	end
end

--[[ Lenient where leniency cannot lose data (accepts "1." and leading zeroes),
     strict where it can (a bare "-" or ".5" is an error, not a silent 0). ]]
local function parseNumber(text, pos)
	local literal = match(text, "^%-?%d+%.?%d*[eE][-+]?%d+", pos)
		or match(text, "^%-?%d+%.?%d*", pos)
	local value = literal and tonumber(literal)
	if not value then fail(pos, "invalid number") end
	return value, pos + #literal
end

local parseValue

local function parseObject(text, pos, depth)
	if depth > MAX_DEPTH then fail(pos, "JSON nested deeper than %d levels", MAX_DEPTH) end
	local out = {}
	local cursor = skip(text, pos + 1)
	if sub(text, cursor, cursor) == "}" then return out, cursor + 1 end
	while true do
		-- Also the error for an unquoted key, which is the most common way a
		-- hand-edited settings file breaks.
		if sub(text, cursor, cursor) ~= '"' then
			fail(cursor, "expected a quoted object key")
		end
		local key
		key, cursor = parseString(text, cursor)
		cursor = skip(text, cursor)
		if sub(text, cursor, cursor) ~= ":" then
			fail(cursor, "expected ':' after object key '%s'", key)
		end
		cursor = skip(text, cursor + 1)
		local value
		value, cursor = parseValue(text, cursor, depth + 1)
		out[key] = value
		cursor = skip(text, cursor)
		local ch = sub(text, cursor, cursor)
		if ch == "}" then
			return out, cursor + 1
		elseif ch == "," then
			cursor = skip(text, cursor + 1)
			if sub(text, cursor, cursor) == "}" then
				fail(cursor, "trailing comma in object")
			end
		elseif ch == "" then
			fail(cursor, "unterminated object")
		else
			fail(cursor, "expected ',' or '}' in object but found '%s'", ch)
		end
	end
end

local function parseArray(text, pos, depth)
	if depth > MAX_DEPTH then fail(pos, "JSON nested deeper than %d levels", MAX_DEPTH) end
	local out, count = {}, 0
	local cursor = skip(text, pos + 1)
	if sub(text, cursor, cursor) == "]" then return out, cursor + 1 end
	while true do
		local value
		value, cursor = parseValue(text, cursor, depth + 1)
		count = count + 1
		out[count] = value
		cursor = skip(text, cursor)
		local ch = sub(text, cursor, cursor)
		if ch == "]" then
			return out, cursor + 1
		elseif ch == "," then
			cursor = skip(text, cursor + 1)
			if sub(text, cursor, cursor) == "]" then
				fail(cursor, "trailing comma in array")
			end
		elseif ch == "" then
			fail(cursor, "unterminated array")
		else
			fail(cursor, "expected ',' or ']' in array but found '%s'", ch)
		end
	end
end

function parseValue(text, pos, depth)
	local ch = sub(text, pos, pos)
	if ch == "" then fail(pos, "unexpected end of input") end
	if ch == "{" then return parseObject(text, pos, depth) end
	if ch == "[" then return parseArray(text, pos, depth) end
	if ch == '"' then return parseString(text, pos) end
	if ch == "-" or (ch >= "0" and ch <= "9") then return parseNumber(text, pos) end
	if sub(text, pos, pos + 3) == "true" then return true, pos + 4 end
	if sub(text, pos, pos + 4) == "false" then return false, pos + 5 end
	if sub(text, pos, pos + 3) == "null" then return NULL, pos + 4 end
	fail(pos, "unexpected character '%s'", ch)
end

--[[ Offsets alone are useless when the file is one long line, so report both. ]]
local function describePosition(text, pos)
	local line, column = 1, 1
	for i = 1, math.min((pos or 1) - 1, #text) do
		if byte(text, i) == 10 then line, column = line + 1, 1 else column = column + 1 end
	end
	return format("offset %d (line %d, column %d)", pos or 1, line, column)
end

--[[ The pure-Lua decoder. Same contract as M.decode. ]]
function M.decodeLua(text)
	if type(text) ~= "string" then return nil, "cannot decode a " .. type(text) end
	local ok, result = pcall(function()
		local pos = skip(text, 1)
		local value
		value, pos = parseValue(text, pos, 1)
		pos = skip(text, pos)
		if pos <= #text then
			fail(pos, "unexpected trailing character '%s'", sub(text, pos, pos))
		end
		return value
	end)
	if ok then return result end
	if type(result) == "table" and result.iyJson then
		return nil, result.message .. " at " .. describePosition(text, result.position)
	end
	return nil, tostring(result)
end

--[[ Never throws: returns the value, or nil plus a message carrying the offset. ]]
function M.decode(text)
	if type(text) ~= "string" then return nil, "cannot decode a " .. type(text) end
	if find(text, "^%s*$") then return nil, "empty input" end
	-- JSONDecode drops null-valued keys, so the native path is only safe when
	-- the text contains no `null` anywhere. On failure fall through rather than
	-- returning its error: the pure parser explains *where* the problem is.
	if M.native and nativeDecode and not find(text, "null", 1, true) then
		local ok, decoded = pcall(nativeDecode, text)
		if ok then return decoded end
	end
	return M.decodeLua(text)
end

--[[ For load paths that would rather abort than continue with half a document. ]]
function M.decodeStrict(text)
	local value, err = M.decode(text)
	if err then Guard.fail("invalid JSON: %s", err) end
	return value
end

IY.json = M
return M

