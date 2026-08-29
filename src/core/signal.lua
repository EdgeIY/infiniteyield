--[[═══════════════════════════════════════════════════════════════════════════
	core/signal · dependency-free event emitter
	─────────────────────────────────────────────────────────────────────────
	Used for every internal event in IY (state changes, command lifecycle,
	character respawn, theme updates). Deliberately NOT RBXScriptSignal:

	  · handlers are isolated -- one erroring listener cannot stop the others
	  · disconnecting during a fire is safe (the fire iterates a snapshot)
	  · every connection remembers where it was made, so leaks are traceable

	Signal.onError is set once by core/log during boot; keeping it a plain
	hook means this module has zero imports and can never be part of a cycle.
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...

local Signal = {}
Signal.__index = Signal

local Connection = {}
Connection.__index = Connection

Signal.onError = nil   -- function(err, signalName, source)

function Connection:Disconnect()
	if not self.connected then return end
	self.connected = false
	local handlers = self.signal.handlers
	for i = 1, #handlers do
		if handlers[i] == self then
			table.remove(handlers, i)
			break
		end
	end
end
Connection.disconnect = Connection.Disconnect
Connection.Destroy = Connection.Disconnect

function Signal.new(name)
	return setmetatable({
		name     = name or "signal",
		handlers = {},
	}, Signal)
end

function Signal.is(value)
	return type(value) == "table" and getmetatable(value) == Signal
end

local function describeCaller()
	if type(debug) == "table" and type(debug.info) == "function" then
		local ok, src, line = pcall(debug.info, 3, "sl")
		if ok and src then return tostring(src) .. ":" .. tostring(line) end
	end
	return "?"
end

function Signal:Connect(fn)
	if type(fn) ~= "function" then
		error("Signal:Connect expects a function, got " .. type(fn), 2)
	end
	local conn = setmetatable({
		signal    = self,
		fn        = fn,
		connected = true,
		source    = describeCaller(),
	}, Connection)
	self.handlers[#self.handlers + 1] = conn
	return conn
end
Signal.connect = Signal.Connect

function Signal:Once(fn)
	local conn
	conn = self:Connect(function(...)
		conn:Disconnect()
		fn(...)
	end)
	return conn
end
Signal.once = Signal.Once

--[[ Yield until the next fire. Returns the fired arguments. ]]
function Signal:Wait()
	local thread = coroutine.running()
	local conn
	conn = self:Connect(function(...)
		conn:Disconnect()
		task.spawn(thread, ...)
	end)
	return coroutine.yield()
end
Signal.wait = Signal.Wait

--[[ Fire synchronously over a snapshot of the handler list. ]]
function Signal:Fire(...)
	local handlers = self.handlers
	local count = #handlers
	if count == 0 then return end
	local snapshot = table.create and table.create(count) or {}
	for i = 1, count do snapshot[i] = handlers[i] end
	for i = 1, count do
		local conn = snapshot[i]
		if conn.connected then
			local ok, err = pcall(conn.fn, ...)
			if not ok then
				if Signal.onError then
					pcall(Signal.onError, err, self.name, conn.source)
				else
					warn("[iy] signal '" .. tostring(self.name) .. "' handler error: " .. tostring(err))
				end
			end
		end
	end
end
Signal.fire = Signal.Fire

--[[ Fire each handler on its own thread. Use when handlers may yield. ]]
function Signal:FireAsync(...)
	local args = table.pack and table.pack(...) or { n = select("#", ...), ... }
	local handlers = self.handlers
	for i = 1, #handlers do
		local conn = handlers[i]
		if conn.connected then
			task.spawn(function()
				local ok, err = pcall(conn.fn, table.unpack(args, 1, args.n))
				if not ok and Signal.onError then pcall(Signal.onError, err, self.name, conn.source) end
			end)
		end
	end
end

function Signal:DisconnectAll()
	local handlers = self.handlers
	for i = #handlers, 1, -1 do
		handlers[i].connected = false
		handlers[i] = nil
	end
end
Signal.Destroy = Signal.DisconnectAll

function Signal:count()
	return #self.handlers
end

--[[ Sources of every live connection -- feeds the leak report in ;iydiag. ]]
function Signal:sources()
	local out = {}
	for i = 1, #self.handlers do out[i] = self.handlers[i].source end
	return out
end

IY.Signal = Signal
return Signal
