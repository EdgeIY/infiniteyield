--[[═══════════════════════════════════════════════════════════════════════════
	core/notify · user-facing messages, decoupled from the UI
	─────────────────────────────────────────────────────────────────────────
	Commands, features and the loader all need to tell the user something, but
	none of them should depend on the interface existing yet. The legacy
	`notify()` was a UI function defined at line 3241, so anything that ran
	before it -- the save-file loader, the capability probe -- had no way to
	report a problem and simply failed silently.

	Here `Notify.send` is available from the first module onwards. Messages
	raised before the UI mounts are buffered and replayed once it does.

	Notifications are also de-duplicated: the same message repeated inside the
	dedupe window increments a counter instead of stacking, which is what makes
	`;inf^1^notify hi` survivable.
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Log    = IY.import("core/log")
local Signal = IY.import("core/signal")

local M = {}

local BUFFER_LIMIT = 24
local DEDUPE_WINDOW = 4

local sink = nil
local buffered = {}
local recent = {}   -- key -> { time, count, entry }

M.sent      = Signal.new("notify.sent")
M.dropped   = 0
M.enabled   = true

local function clock()
	if os and os.clock then return os.clock() end
	return tick and tick() or 0
end

local function deliver(entry)
	if sink then
		local ok, err = pcall(sink, entry)
		if not ok then
			Log.error("notify", "sink failed: %s", tostring(err))
			warn("[IY] " .. entry.title .. ": " .. entry.text)
		end
	else
		if #buffered >= BUFFER_LIMIT then
			table.remove(buffered, 1)
			M.dropped = M.dropped + 1
		end
		buffered[#buffered + 1] = entry
	end
	M.sent:Fire(entry)
end

--[[ Show a notification. `title` alone is allowed (legacy `notify("text")`
     behaviour showed it as the body under a generic title). ]]
function M.send(title, text, duration)
	if not M.enabled then return nil end

	local entry
	if text == nil then
		entry = { title = "Notification", text = tostring(title), duration = duration }
	else
		entry = { title = tostring(title), text = tostring(text), duration = duration }
	end
	entry.time = clock()
	entry.level = "info"

	local key = entry.title .. "\0" .. entry.text
	local previous = recent[key]
	if previous and (entry.time - previous.time) < DEDUPE_WINDOW then
		previous.count = previous.count + 1
		previous.time = entry.time
		previous.entry.repeated = previous.count
		M.sent:Fire(previous.entry)
		if sink then pcall(sink, previous.entry) end
		return previous.entry
	end
	recent[key] = { time = entry.time, count = 1, entry = entry }

	Log.trace("notify", "%s: %s", entry.title, entry.text)
	deliver(entry)
	return entry
end

--[[ An error notification: same channel, flagged so the UI can colour it and
     so the log keeps it at error level. ]]
function M.error(title, text)
	local entry = M.send(title, text)
	if entry then
		entry.level = "error"
		Log.warn("notify", "%s: %s", tostring(title), tostring(text))
	end
	return entry
end

function M.warn(title, text)
	local entry = M.send(title, text)
	if entry then entry.level = "warn" end
	return entry
end

--[[ Attach the real UI renderer. Buffered messages replay in order. ]]
function M.setSink(fn)
	sink = fn
	if not fn then return end
	local pending = buffered
	buffered = {}
	for i = 1, #pending do
		pcall(fn, pending[i])
	end
	if M.dropped > 0 then
		pcall(fn, {
			title = "Notifications",
			text = tostring(M.dropped) .. " earlier message(s) were dropped",
			time = clock(), level = "warn",
		})
		M.dropped = 0
	end
end

function M.hasSink()
	return sink ~= nil
end

function M.pending()
	return #buffered
end

IY.notify = M
return M
