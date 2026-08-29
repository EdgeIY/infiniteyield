--[[ tests/stub/signal.lua ---------------------------------------------------
  RBXScriptSignal / RBXScriptConnection stubs.

  Contract:
    Signal.new(name, runtime) -> signal
      `runtime` is optional and is the scheduler table (see scheduler.lua).
      When present every handler runs through runtime.spawn, so a handler that
      yields (task.wait) or errors cannot break the firing loop -- this mirrors
      Roblox, where each connection is resumed on its own thread and errors are
      reported without stopping the remaining listeners.

    signal:Connect(fn) -> connection      signal:Once(fn) -> connection
    signal:Wait() -> ...                  signal:Fire(...)
    signal:DisconnectAll()                signal:GetConnections() -> {connection}
    Signal.is(v) -> boolean

  typeof() support comes from the `__type` metatable field.
  signal:Wait() called from the main thread (not a coroutine) drives the
  scheduler forward instead of yielding, because the Lua 5.1 main thread cannot
  yield.  Handlers are invoked in connection order.
--]]

local Signal = {}

-- === connection ==========================================================
local Connection = {}
Connection.__index = Connection
Connection.__type = "RBXScriptConnection"
Connection.__tostring = function(self)
    return "Connection<" .. tostring(self._signal and self._signal._name) .. ">"
end

function Connection:Disconnect()
    if not self._alive then return end
    self._alive = false
    self.Connected = false
    local list = self._signal._connections
    for i = 1, #list do
        if list[i] == self then
            table.remove(list, i)
            break
        end
    end
end
Connection.disconnect = Connection.Disconnect
Connection.Destroy = Connection.Disconnect

function Connection:Disable() self._enabled = false end
function Connection:Enable() self._enabled = true end

-- === signal ==============================================================
local Sig = {}
Sig.__index = Sig
Sig.__type = "RBXScriptSignal"
Sig.__tostring = function(self) return "Signal<" .. tostring(self._name) .. ">" end

local function run(self, fn, ...)
    local rt = self._runtime
    if rt and rt.spawn then return rt.spawn(fn, ...) end
    local co = coroutine.create(fn)
    local ok, err = coroutine.resume(co, ...)
    if not ok then
        io.stderr:write("[stub] signal handler error: " .. tostring(err) .. "\n")
    end
    return co
end

function Connection:Fire(...)
    if self.Function then return run(self._signal, self.Function, ...) end
end
Connection.Defer = Connection.Fire

function Signal.new(name, runtime)
    return setmetatable({
        _name = name or "Signal",
        _connections = {},
        _waiting = {},
        _runtime = runtime,
        _fireCount = 0,
    }, Sig)
end

function Signal.is(v)
    return type(v) == "table" and getmetatable(v) == Sig
end

function Signal.isConnection(v)
    return type(v) == "table" and getmetatable(v) == Connection
end
function Sig:Connect(fn)
    if type(fn) ~= "function" then
        error("Attempt to connect failed: Passed value is not a function", 2)
    end
    local conn = setmetatable({
        Function = fn,
        Connected = true,
        ForeignState = false,
        LuaConnection = true,
        _alive = true,
        _enabled = true,
        _signal = self,
    }, Connection)
    self._connections[#self._connections + 1] = conn
    return conn
end
Sig.connect = Sig.Connect
Sig.ConnectParallel = Sig.Connect

function Sig:Once(fn)
    local conn
    conn = self:Connect(function(...)
        conn:Disconnect()
        return fn(...)
    end)
    return conn
end

function Sig:DisconnectAll()
    local list = self._connections
    for i = #list, 1, -1 do
        local c = list[i]
        c._alive = false
        c.Connected = false
        list[i] = nil
    end
end
Sig.Destroy = Sig.DisconnectAll

function Sig:GetConnections()
    local out = {}
    for i = 1, #self._connections do out[i] = self._connections[i] end
    return out
end
function Sig:Wait()
    local co = coroutine.running()
    if co ~= nil then
        self._waiting[#self._waiting + 1] = co
        return coroutine.yield()
    end
    -- main thread: cannot yield, so pump the scheduler until the signal fires.
    local rt = self._runtime
    local results
    local conn = self:Connect(function(...)
        results = { n = select("#", ...), ... }
    end)
    if not (rt and rt.step) then
        conn:Disconnect()
        error("Signal:Wait() on the main thread requires a scheduler runtime", 2)
    end
    local budget = rt.mainWaitSteps or 10000
    local steps = 0
    while results == nil and steps < budget do
        rt.step()
        steps = steps + 1
    end
    conn:Disconnect()
    if results == nil then
        error("Signal:Wait() timed out after " .. steps .. " scheduler steps on signal "
            .. tostring(self._name), 2)
    end
    return unpack(results, 1, results.n)
end
Sig.wait = Sig.Wait

function Sig:Fire(...)
    self._fireCount = self._fireCount + 1
    local waiting = self._waiting
    if #waiting > 0 then
        self._waiting = {}
        local rt = self._runtime
        for i = 1, #waiting do
            if rt and rt.resume then rt.resume(waiting[i], ...)
            else coroutine.resume(waiting[i], ...) end
        end
    end
    local list = self._connections
    local n = #list
    if n == 0 then return end
    local snapshot = {}
    for i = 1, n do snapshot[i] = list[i] end
    for i = 1, n do
        local c = snapshot[i]
        if c._alive and c._enabled then run(self, c.Function, ...) end
    end
end
Sig.fire = Sig.Fire
Sig.FireDeferred = Sig.Fire

return Signal


