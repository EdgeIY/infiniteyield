--[[═══════════════════════════════════════════════════════════════════════════
	core/scheduler · named, contained, cancellable work
	─────────────────────────────────────────────────────────────────────────
	Every loop in the legacy script was `while flag do ... end` or a bare
	RunService connection. Two consequences showed up constantly:

	  1. running a toggle command twice started a second loop; the flag only
	     ever stopped one of them
	  2. a loop that threw on a frame threw on *every* frame, flooding the
	     console until the user rejoined

	The scheduler fixes both. Loops are keyed by label -- starting a loop that
	is already running replaces it -- and every iteration is contained, with a
	watchdog that stops a loop after `maxErrors` consecutive failures and logs
	once instead of forever.

	    local handle = Sched.frameLoop("fly.step", function(dt) ... end)
	    handle:stop()

	    Sched.interval("autoclick", 0.1, function() ... end)
	    Sched.after(2, function() ... end)
	    Sched.debounce("save", 0.5, save)

	Handles expose :stop()/:Destroy(), so `bin:add(handle)` works.
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Log      = IY.import("core/log")
local Guard    = IY.import("core/guard")
local Services = IY.import("core/services")

local RunService = Services.RunService

local unpack = table.unpack or unpack

local M = {}

local active = {}          -- label -> handle
local MAX_ERRORS = 5

M.active = active

local Handle = {}
Handle.__index = Handle

function Handle:stop()
	if not self.running then return false end
	self.running = false
	if self.connection then
		pcall(function() self.connection:Disconnect() end)
		self.connection = nil
	end
	if self.thread and coroutine.status(self.thread) ~= "dead" then
		pcall(task.cancel, self.thread)
	end
	self.thread = nil
	if active[self.label] == self then active[self.label] = nil end
	return true
end
Handle.Destroy = Handle.stop
Handle.cancel = Handle.stop

function Handle:isRunning()
	return self.running == true
end

local function newHandle(label, kind)
	-- Replacing an existing loop of the same name is the whole point: a second
	-- `;fly` must not leave the first loop spinning.
	local previous = active[label]
	if previous then previous:stop() end
	local handle = setmetatable({
		label   = label,
		kind    = kind,
		running = true,
		errors  = 0,
		ticks   = 0,
		started = os.clock and os.clock() or 0,
	}, Handle)
	active[label] = handle
	return handle
end

--[[ Wrap one iteration: contain errors, count consecutive failures, and stop
     a hopeless loop instead of letting it spam. ]]
local function iterate(handle, fn, ...)
	local ok, err, kind = Guard.call(handle.label, fn, ...)
	handle.ticks = handle.ticks + 1
	if ok then
		handle.errors = 0
		return true
	end
	handle.errors = handle.errors + 1
	handle.lastError = err
	if kind ~= "internal" or handle.errors >= MAX_ERRORS then
		Log.warn("scheduler", "stopped '%s' after %d error(s): %s",
			handle.label, handle.errors, Guard.describe(err))
		handle:stop()
		return false
	end
	return true
end

--[[ Run fn every frame. `event` selects render / heartbeat / stepped. ]]
function M.frameLoop(label, fn, event)
	local handle = newHandle(label, "frame")
	local signal =
		(event == "heartbeat" and RunService.Heartbeat)
		or (event == "stepped" and RunService.Stepped)
		or RunService.RenderStepped
	handle.connection = signal:Connect(function(...)
		if not handle.running then return end
		iterate(handle, fn, ...)
	end)
	return handle
end

--[[ Run fn every `interval` seconds on its own thread. `immediate` runs the
     first iteration before the first wait. ]]
function M.interval(label, interval, fn, immediate)
	local handle = newHandle(label, "interval")
	handle.thread = task.spawn(function()
		if immediate then
			if not iterate(handle, fn) then return end
		end
		while handle.running do
			task.wait(interval)
			if not handle.running then break end
			if not iterate(handle, fn) then break end
		end
	end)
	return handle
end

--[[ Run fn as fast as the scheduler allows (a `while true do task.wait() end`
     loop) -- for things that must not miss a frame but do not need dt. ]]
function M.tightLoop(label, fn)
	return M.interval(label, nil, fn, true)
end

--[[ A one-shot timer that can be cancelled. ]]
function M.after(seconds, fn, label)
	local handle = newHandle(label or ("after:" .. tostring(seconds) .. ":" .. tostring(math.random(1e6))), "timer")
	handle.thread = task.delay(seconds, function()
		if not handle.running then return end
		iterate(handle, fn)
		handle:stop()
	end)
	return handle
end

--[[ Contained task.spawn: the thread is named and its errors are logged. ]]
function M.spawn(label, fn, ...)
	local args = { ... }
	local n = select("#", ...)
	return task.spawn(function()
		Guard.call(label, function() return fn(unpack(args, 1, n)) end)
	end)
end

--[[ Coalesce rapid calls: fn runs `delay` seconds after the last call. ]]
local debounces = {}
function M.debounce(label, delay, fn)
	local entry = debounces[label]
	if entry then entry.cancelled = true end
	local mine = { cancelled = false }
	debounces[label] = mine
	task.delay(delay, function()
		if mine.cancelled then return end
		debounces[label] = nil
		Guard.call("debounce:" .. label, fn)
	end)
end

--[[ Rate-limit: fn runs at most once per `period`. Returns true when it ran. ]]
local throttles = {}
function M.throttle(label, period, fn)
	local now = os.clock and os.clock() or tick()
	local last = throttles[label]
	if last and (now - last) < period then return false end
	throttles[label] = now
	Guard.call("throttle:" .. label, fn)
	return true
end

--[[ Yield until `predicate()` is truthy or `timeout` elapses.
     Returns true if satisfied, false on timeout. ]]
function M.waitUntil(predicate, timeout, step)
	local deadline = (os.clock and os.clock() or tick()) + (timeout or 5)
	while true do
		local ok, result = pcall(predicate)
		if ok and result then return true, result end
		if (os.clock and os.clock() or tick()) >= deadline then return false end
		task.wait(step or 0.05)
	end
end

function M.isRunning(label)
	local handle = active[label]
	return handle ~= nil and handle.running == true
end

function M.stop(label)
	local handle = active[label]
	if handle then return handle:stop() end
	return false
end

--[[ Stop everything. Used by ;unloadiy and by the panic key. ]]
function M.stopAll(prefix)
	local stopped = 0
	for label, handle in pairs(active) do
		if not prefix or string.sub(label, 1, #prefix) == prefix then
			handle:stop()
			stopped = stopped + 1
		end
	end
	return stopped
end

--[[ Snapshot for ;iydiag: what is running and how healthy it is. ]]
function M.snapshot()
	local out = {}
	for label, handle in pairs(active) do
		out[#out + 1] = {
			label  = label,
			kind   = handle.kind,
			ticks  = handle.ticks,
			errors = handle.errors,
			uptime = (os.clock and os.clock() or 0) - (handle.started or 0),
		}
	end
	table.sort(out, function(a, b) return a.label < b.label end)
	return out
end

-- A loop created outside any bin -- by a plugin, or by code that forgot -- must
-- still die with the script. This is the backstop that makes `;unloadiy` an
-- unconditional stop rather than a best effort.
IY.onUnload(function()
	M.stopAll()
end, "core/scheduler")

IY.sched = M
return M
