--[[═══════════════════════════════════════════════════════════════════════════
	cmd/history · command bar history
	─────────────────────────────────────────────────────────────────────────
	Up/down through what you typed. Kept separate from the dispatcher so the UI
	can bind to it without importing the execution path, and so the same
	history serves the command bar, the chat hook and keybinds.

	Consecutive duplicates collapse, and `lastcommand`-style commands are never
	recorded -- otherwise pressing Up after using one replays the replay.
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Signal = IY.import("core/signal")
local Str    = IY.import("core/util/strings")

local M = {}

local LIMIT = 40
local EXCLUDED = { lastcommand = true, lastcmd = true }

local entries = {}   -- newest first
local cursor = 0

M.entries = entries
M.changed = Signal.new("history.changed")

--[[ Record a line. Returns true when it was actually stored. ]]
function M.push(line)
	line = Str.trim(tostring(line or ""))
	if line == "" then return false end

	local firstWord = Str.lower(string.match(line, "^%S+") or "")
	if EXCLUDED[firstWord] then return false end
	if entries[1] == line then
		cursor = 0
		return false
	end

	table.insert(entries, 1, line)
	while #entries > LIMIT do table.remove(entries) end
	cursor = 0
	M.changed:Fire()
	return true
end

function M.last()
	return entries[1]
end

--[[ Move back through history; returns the line to show. ]]
function M.previous()
	if #entries == 0 then return nil end
	cursor = math.min(cursor + 1, #entries)
	return entries[cursor]
end

--[[ Move forward; returns nil once past the newest entry (clears the box). ]]
function M.next()
	if cursor <= 1 then
		cursor = 0
		return nil
	end
	cursor = cursor - 1
	return entries[cursor]
end

function M.resetCursor()
	cursor = 0
end

function M.all()
	return entries
end

function M.clear()
	for i = #entries, 1, -1 do entries[i] = nil end
	cursor = 0
	M.changed:Fire()
end

return M
