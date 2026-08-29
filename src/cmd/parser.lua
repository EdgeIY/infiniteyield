--[[═══════════════════════════════════════════════════════════════════════════
	cmd/parser · command line -> invocations
	─────────────────────────────────────────────────────────────────────────
	Preserves every piece of the legacy command-line syntax:

	    ;fly \ ;speed 100        two commands, one line   ("\" separator)
	    ;5^jump                  run it five times
	    ;5^0.5^jump              five times, half a second apart
	    ;inf^jump                until ;breakloops
	    ;inf^2^jump              every two seconds
	    ;!goto                   re-run the last `goto` you typed
	    ;chat \\ hello           "\\" is a literal backslash

	and adds quoting, which the legacy tokeniser lacked:

	    ;alias "big jump" jpower 500

	Token offsets are recorded so a greedy argument (`text`, `command`,
	`waypoint`) can take the *exact* remainder of the original line, spaces and
	quotes intact -- the legacy equivalent was a `getstring(n)` call that read a
	global set by the dispatcher.
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Str = IY.import("core/util/strings")

local M = {}

local ESCAPED_BACKSLASH = "\1IYBS\1"

--[[ Remove the command prefix, returning nil when the text is not a command. ]]
function M.stripPrefix(text, prefix)
	if type(text) ~= "string" then return nil end
	prefix = prefix or ";"
	if prefix == "" then return text end
	if string.sub(text, 1, #prefix) ~= prefix then return nil end
	return string.sub(text, #prefix + 1)
end

--[[ Split a line into segments on unescaped backslashes. ]]
function M.splitCommands(line)
	local protected = string.gsub(tostring(line), "\\\\", ESCAPED_BACKSLASH)
	local segments = {}
	for piece in string.gmatch(protected, "[^\\]+") do
		segments[#segments + 1] = (string.gsub(piece, ESCAPED_BACKSLASH, "\\"))
	end
	if #segments == 0 then
		local restored = string.gsub(protected, ESCAPED_BACKSLASH, "\\")
		if Str.trim(restored) ~= "" then segments[1] = restored end
	end
	return segments
end

--[[ Pull the repeat / delay / infinite modifiers off the front of a segment.
     Returns the remaining text plus the modifiers. ]]
function M.parseModifiers(segment)
	local text = segment
	local repeats, delay, infinite = 1, 0, false

	local infHead = string.match(text, "^inf%^")
	if infHead then
		infinite = true
		text = string.sub(text, #infHead + 1)
		local delayText, rest = string.match(text, "^([%d%.]+)%^(.*)$")
		if delayText then
			delay = tonumber(delayText) or 1
			if delay <= 0 then delay = 1 end
			text = rest
		else
			delay = 1
		end
		return text, repeats, delay, infinite
	end

	local countText, afterCount = string.match(text, "^(%d+)%^(.*)$")
	if countText then
		repeats = tonumber(countText) or 1
		text = afterCount
		local delayText, rest = string.match(text, "^([%d%.]+)%^(.*)$")
		if delayText then
			delay = tonumber(delayText) or 0
			text = rest
		end
	end

	return text, repeats, delay, infinite
end

--[[ Split into tokens, honouring "double" and 'single' quotes, and recording
     where each token started in the source string. ]]
function M.tokenise(text)
	local tokens = {}
	local length = #text
	local index = 1

	while index <= length do
		-- skip whitespace
		while index <= length and string.find(string.sub(text, index, index), "%s") do
			index = index + 1
		end
		if index > length then break end

		local startIndex = index
		local first = string.sub(text, index, index)
		local value

		if first == '"' or first == "'" then
			local closing = string.find(text, first, index + 1, true)
			if closing then
				value = string.sub(text, index + 1, closing - 1)
				index = closing + 1
			else
				-- Unterminated quote: treat the rest of the line as one token
				-- rather than failing, which is friendlier while typing.
				value = string.sub(text, index + 1)
				index = length + 1
			end
		else
			local nextSpace = string.find(text, "%s", index)
			if nextSpace then
				value = string.sub(text, index, nextSpace - 1)
				index = nextSpace
			else
				value = string.sub(text, index)
				index = length + 1
			end
		end

		tokens[#tokens + 1] = { value = value, start = startIndex }
	end

	return tokens
end

--[[ Parse one segment into an invocation table. ]]
function M.parseSegment(segment)
	local text, repeats, delay, infinite = M.parseModifiers(Str.trim(segment))

	local recall = nil
	if string.sub(text, 1, 1) == "!" then
		local rest = string.sub(text, 2)
		local firstWord = string.match(rest, "^%S+")
		if firstWord then recall = firstWord end
	end

	local tokens = M.tokenise(text)
	if #tokens == 0 then return nil end

	local args, offsets = {}, {}
	for i = 2, #tokens do
		args[i - 1] = tokens[i].value
		offsets[i - 1] = tokens[i].start
	end

	return {
		name      = tokens[1].value,
		args      = args,
		offsets   = offsets,
		raw       = text,
		repeats   = repeats,
		delay     = delay,
		infinite  = infinite,
		recall    = recall,
	}
end

--[[ The remainder of the raw line starting at argument `index`, exactly as the
     user typed it. Used by greedy argument types. ]]
function M.remainder(invocation, index)
	local offset = invocation.offsets[index]
	if not offset then return "" end
	return string.sub(invocation.raw, offset)
end

--[[ Full parse: a line becomes an ordered list of invocations. ]]
function M.parse(line)
	local out = {}
	local segments = M.splitCommands(line)
	for i = 1, #segments do
		local invocation = M.parseSegment(segments[i])
		if invocation then out[#out + 1] = invocation end
	end
	return out
end

--[[ Where the caret sits relative to the argument list, for autocomplete:
     returns the command name, the index of the argument being typed (0 for the
     command name itself) and the partial text of that argument. ]]
function M.completionContext(line)
	local segments = M.splitCommands(line)
	local segment = segments[#segments] or ""
	local text = select(1, M.parseModifiers(segment))
	local endsWithSpace = string.find(text, "%s$") ~= nil
	local tokens = M.tokenise(text)

	if #tokens == 0 then
		return { name = "", argIndex = 0, partial = "", tokens = tokens }
	end
	if #tokens == 1 and not endsWithSpace then
		return { name = tokens[1].value, argIndex = 0, partial = tokens[1].value, tokens = tokens }
	end
	if endsWithSpace then
		return { name = tokens[1].value, argIndex = #tokens, partial = "", tokens = tokens }
	end
	return { name = tokens[1].value, argIndex = #tokens - 1, partial = tokens[#tokens].value, tokens = tokens }
end

return M
