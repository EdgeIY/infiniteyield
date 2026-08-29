--[[ tests/stub/scheduler.lua ------------------------------------------------
  Cooperative task scheduler with a virtual clock.

  Contract: Scheduler.new(opts) -> scheduler, a table of *closures* (call them
  with a dot, e.g. scheduler.step(dt)) so it can be handed straight to callers.

    opts.dt        default step size (1/60)
    opts.epoch     wall-clock base used by tick() (os.time())
    opts.onError   called with {message=, traceback=, source=} for every error
                   raised inside a scheduled thread

    scheduler.step(dt)             advance the clock, resume due threads, run
                                   deferred work, then the step hooks
                                   (RunService signals live in a step hook)
    scheduler.advance(sec, dt)     step repeatedly until `sec` of virtual time passed
    scheduler.drain(maxSteps)      step until nothing is pending (default 10000)
    scheduler.pending()            waiting + deferred thread count
    scheduler.clock()              virtual seconds since creation
    scheduler.errors               array of error records (never thrown upward)
    scheduler.spawn/defer/delay/wait/cancel/resume
    scheduler.addStepHook(fn)      fn(dt, clock) each step
    scheduler.bindRenderStep(name, priority, fn) / unbindRenderStep(name)
    scheduler.reset()              drop queues + recorded errors (clock is kept)

  Errors inside scheduled threads are captured (with a traceback) and recorded
  instead of propagating, exactly like Roblox.  wait() called on the main thread
  cannot yield, so it advances the virtual clock synchronously instead, which
  keeps top-level `wait()` in a script under test working.
--]]

local Scheduler = {}

local EPSILON = 1e-9

function Scheduler.new(opts)
    opts = opts or {}
    local sched = {}
    local timed, deferred, hooks, renderBinds = {}, {}, {}, {}
    local cancelled = setmetatable({}, { __mode = "k" })
    local owned = setmetatable({}, { __mode = "k" })
    local now, seq, steps = 0, 0, 0
    local defaultDt = opts.dt or (1 / 60)
    local epoch = opts.epoch or os.time()
    local minWait = opts.minWait or (1 / 60)

    sched.errors = {}
    sched.onError = opts.onError
    sched.mainWaitSteps = opts.mainWaitSteps or 10000

    local function record(thread, err, source)
        local rec = {
            message = tostring(err),
            traceback = thread and debug.traceback(thread) or debug.traceback(),
            source = source or "task",
            clock = now,
        }
        sched.errors[#sched.errors + 1] = rec
        if sched.onError then sched.onError(rec) end
        return rec
    end
    sched.record = record

    -- resume a thread, capturing (never rethrowing) any error it raises
    function sched.resume(thread, ...)
        if type(thread) ~= "thread" then return false, "not a thread" end
        if cancelled[thread] then return false, "cancelled" end
        if coroutine.status(thread) ~= "suspended" then return false, "not suspended" end
        local ok, err = coroutine.resume(thread, ...)
        if not ok then record(thread, err, "thread") end
        return ok, err
    end

    function sched.spawn(fnOrThread, ...)
        local thread
        if type(fnOrThread) == "thread" then
            thread = fnOrThread
        elseif type(fnOrThread) == "function" then
            thread = coroutine.create(fnOrThread)
        else
            error("Unable to cast value to Object (task.spawn expects a function or thread)", 2)
        end
        owned[thread] = true
        sched.resume(thread, ...)
        return thread
    end

    function sched.defer(fnOrThread, ...)
        local thread
        if type(fnOrThread) == "thread" then
            thread = fnOrThread
        elseif type(fnOrThread) == "function" then
            thread = coroutine.create(fnOrThread)
        else
            error("Unable to cast value to Object (task.defer expects a function or thread)", 2)
        end
        owned[thread] = true
        deferred[#deferred + 1] = { thread = thread, args = { n = select("#", ...), ... } }
        return thread
    end
    function sched.delay(seconds, fnOrThread, ...)
        seconds = tonumber(seconds) or 0
        if seconds < 0 then seconds = 0 end
        local thread
        if type(fnOrThread) == "thread" then
            thread = fnOrThread
        elseif type(fnOrThread) == "function" then
            thread = coroutine.create(fnOrThread)
        else
            error("Unable to cast value to Object (task.delay expects a function or thread)", 2)
        end
        owned[thread] = true
        seq = seq + 1
        timed[#timed + 1] = {
            thread = thread, at = now + seconds, seq = seq, start = now,
            args = { n = select("#", ...), ... },
        }
        return thread
    end

    function sched.wait(seconds)
        seconds = tonumber(seconds) or 0
        if seconds < minWait then seconds = minWait end
        local co = coroutine.running()
        local start = now
        if co == nil then
            -- main thread: emulate the yield by advancing the world instead
            local target = now + seconds
            local guard = 0
            while now < target - EPSILON and guard < 1000000 do
                local remaining = target - now
                sched.step(defaultDt < remaining and defaultDt or remaining)
                guard = guard + 1
            end
            return now - start, now
        end
        seq = seq + 1
        timed[#timed + 1] = { thread = co, at = now + seconds, seq = seq, start = now }
        return coroutine.yield()
    end

    function sched.cancel(thread)
        if type(thread) ~= "thread" then return false end
        cancelled[thread] = true
        for i = #timed, 1, -1 do
            if timed[i].thread == thread then table.remove(timed, i) end
        end
        for i = #deferred, 1, -1 do
            if deferred[i].thread == thread then table.remove(deferred, i) end
        end
        return true
    end
    -- Run one batch of deferred work.  Anything deferred *by* this batch lands
    -- in the next batch, which keeps a defer-loop from hanging a single step.
    local function runDeferred()
        if #deferred == 0 then return end
        local batch = deferred
        deferred = {}
        for i = 1, #batch do
            local e = batch[i]
            sched.resume(e.thread, unpack(e.args, 1, e.args.n))
        end
    end

    local function resumeDue()
        local due
        for i = #timed, 1, -1 do
            local e = timed[i]
            if e.at <= now + EPSILON then
                due = due or {}
                due[#due + 1] = e
                table.remove(timed, i)
            end
        end
        if not due then return end
        table.sort(due, function(a, b)
            if a.at == b.at then return a.seq < b.seq end
            return a.at < b.at
        end)
        for i = 1, #due do
            local e = due[i]
            if e.args then
                sched.resume(e.thread, unpack(e.args, 1, e.args.n))
            else
                sched.resume(e.thread, now - e.start, now)
            end
        end
    end

    local function runRenderBinds(dt)
        if #renderBinds == 0 then return end
        local snapshot = {}
        for i = 1, #renderBinds do snapshot[i] = renderBinds[i] end
        table.sort(snapshot, function(a, b) return a.priority < b.priority end)
        for i = 1, #snapshot do
            local ok, err = pcall(snapshot[i].fn, dt)
            if not ok then record(nil, err, "RenderStep:" .. tostring(snapshot[i].name)) end
        end
    end
    function sched.step(dt)
        dt = tonumber(dt) or defaultDt
        if dt < 0 then dt = 0 end
        now = now + dt
        steps = steps + 1
        resumeDue()
        runDeferred()
        runRenderBinds(dt)
        for i = 1, #hooks do
            local ok, err = pcall(hooks[i], dt, now)
            if not ok then record(nil, err, "stepHook") end
        end
        runDeferred()
        return now
    end

    function sched.advance(seconds, dt)
        seconds = tonumber(seconds) or 0
        dt = tonumber(dt) or defaultDt
        if dt <= 0 then dt = defaultDt end
        local target = now + seconds
        local guard = 0
        while now < target - EPSILON and guard < 10000000 do
            local remaining = target - now
            sched.step(dt < remaining and dt or remaining)
            guard = guard + 1
        end
        if seconds <= 0 then sched.step(0) end
        return now
    end

    function sched.drain(maxSteps)
        maxSteps = tonumber(maxSteps) or 10000
        local n = 0
        while sched.pending() > 0 and n < maxSteps do
            sched.step(defaultDt)
            n = n + 1
        end
        return n
    end

    function sched.pending() return #timed + #deferred end
    function sched.clock() return now end
    function sched.stepCount() return steps end
    function sched.epochClock() return epoch + now end
    function sched.isOwned(thread) return owned[thread] == true end
    function sched.isCancelled(thread) return cancelled[thread] == true end
    function sched.defaultStep() return defaultDt end
    function sched.addStepHook(fn)
        hooks[#hooks + 1] = fn
        return fn
    end

    function sched.bindRenderStep(name, priority, fn)
        sched.unbindRenderStep(name)
        renderBinds[#renderBinds + 1] = {
            name = name, priority = tonumber(priority) or 0, fn = fn,
        }
    end

    function sched.unbindRenderStep(name)
        for i = #renderBinds, 1, -1 do
            if renderBinds[i].name == name then table.remove(renderBinds, i) end
        end
    end

    function sched.renderStepCount() return #renderBinds end

    function sched.reset()
        for i = #timed, 1, -1 do timed[i] = nil end
        for i = #deferred, 1, -1 do deferred[i] = nil end
        for i = #sched.errors, 1, -1 do sched.errors[i] = nil end
        for i = #renderBinds, 1, -1 do renderBinds[i] = nil end
    end

    return sched
end

return Scheduler




