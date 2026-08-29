--[[═══════════════════════════════════════════════════════════════════════════
	core/bin · deterministic cleanup
	─────────────────────────────────────────────────────────────────────────
	Every stateful thing in IY -- a feature, a command invocation, a UI panel,
	a plugin -- owns a Bin. Anything it creates goes in the bin, and stopping
	it empties the bin. That single rule removes the entire class of bugs the
	legacy script was full of: connections that outlived their command, loops
	that kept running after the flag was cleared, and ESP folders left in
	CoreGui after `noesp`.

	    local bin = Bin.new("fly")
	    bin:connect(RunService.RenderStepped, step)   -- disconnected on empty
	    bin:add(Instance.new("BodyVelocity"))         -- destroyed on empty
	    bin:spawn(function() ... end)                 -- cancelled on empty
	    bin:empty()                                   -- bin is reusable
	    bin:destroy()                                 -- bin is finished

	Bins accept: RBXScriptConnection, core/signal connections, Instance,
	thread, function, nested Bin, and any table exposing Destroy/Disconnect/
	destroy/disconnect. Unknown values raise -- silently ignoring them is how
	leaks hide.
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Signal = IY.import("core/signal")

local Bin = {}
Bin.__index = Bin

local function cleanupOne(item)
	local kind = typeof and typeof(item) or type(item)

	if kind == "RBXScriptConnection" then
		item:Disconnect()
		return true
	end
	if kind == "Instance" then
		item:Destroy()
		return true
	end
	if kind == "thread" then
		if coroutine.status(item) ~= "dead" then
			pcall(task.cancel, item)
		end
		return true
	end
	if kind == "function" then
		item()
		return true
	end
	if kind == "table" then
		if getmetatable(item) == Bin then item:destroy() return true end
		local m = item.Destroy or item.destroy or item.Disconnect or item.disconnect
			or item.Cancel or item.cancel or item.stop or item.Stop
		if type(m) == "function" then m(item) return true end
	end
	return false
end

function Bin.new(label)
	return setmetatable({
		label   = label or "bin",
		items   = {},
		alive   = true,
		emptied = Signal.new("bin.emptied"),
	}, Bin)
end

function Bin.is(value)
	return type(value) == "table" and getmetatable(value) == Bin
end

--[[ Store something for later cleanup. Returns the value, so it chains:
         local part = bin:add(Instance.new("Part")) ]]
function Bin:add(item, name)
	if item == nil then return nil end
	if not self.alive then
		-- The owner already shut down; clean up immediately rather than
		-- silently leaking into a dead bin.
		pcall(cleanupOne, item)
		return item
	end
	local kind = typeof and typeof(item) or type(item)
	local ok = kind == "RBXScriptConnection" or kind == "Instance" or kind == "thread"
		or kind == "function" or kind == "table"
	if not ok then
		error("[iy] Bin '" .. self.label .. "' cannot hold a " .. tostring(kind), 2)
	end
	self.items[#self.items + 1] = item
	if name then
		self.named = self.named or {}
		self.named[name] = item
	end
	return item
end
Bin.give = Bin.add
Bin.hold = Bin.add

function Bin:get(name)
	return self.named and self.named[name] or nil
end

--[[ Connect to a Roblox signal or a core/signal, tracking the connection. ]]
function Bin:connect(signal, fn)
	if type(signal) ~= "table" and typeof and typeof(signal) ~= "RBXScriptSignal" then
		error("[iy] Bin:connect got a " .. tostring(typeof and typeof(signal) or type(signal)), 2)
	end
	return self:add(signal:Connect(fn))
end

--[[ Connect to a property-changed signal in one call. ]]
function Bin:onChange(instance, property, fn)
	return self:add(instance:GetPropertyChangedSignal(property):Connect(fn))
end

--[[ Spawn a tracked thread. Cancelled when the bin empties, so a feature's
     `while running do` loop can never survive its own shutdown. ]]
function Bin:spawn(fn, ...)
	local thread = task.spawn(fn, ...)
	return self:add(thread)
end

function Bin:delay(seconds, fn, ...)
	return self:add(task.delay(seconds, fn, ...))
end

--[[ Create + parent an Instance that dies with the bin. ]]
function Bin:instance(className, props)
	local inst = Instance.new(className)
	if props then
		local parent = props.Parent
		for key, value in pairs(props) do
			if key ~= "Parent" then inst[key] = value end
		end
		if parent then inst.Parent = parent end
	end
	return self:add(inst)
end

--[[ Run every cleanup, newest first, and keep going if one errors. The bin
     stays usable afterwards -- that is what makes toggling cheap. ]]
function Bin:empty()
	local items = self.items
	self.items = {}
	self.named = nil
	local errors
	for i = #items, 1, -1 do
		local item = items[i]
		local ok, err = pcall(cleanupOne, item)
		if not ok then
			errors = errors or {}
			errors[#errors + 1] = err
		end
	end
	self.emptied:Fire(errors)
	return errors
end
Bin.clean = Bin.empty

--[[ Empty and mark dead: further adds clean up immediately. ]]
function Bin:destroy()
	if not self.alive then return end
	local errors = self:empty()
	self.alive = false
	self.emptied:DisconnectAll()
	return errors
end
Bin.Destroy = Bin.destroy

function Bin:count()
	return #self.items
end

function Bin:isEmpty()
	return #self.items == 0
end

--[[ A child bin that is emptied with its parent but can also be emptied
     independently -- used for per-player state inside a feature. ]]
function Bin:branch(label)
	local child = Bin.new((self.label or "bin") .. "/" .. (label or "branch"))
	self:add(child)
	return child
end

IY.Bin = Bin
return Bin
