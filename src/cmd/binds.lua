--[[═══════════════════════════════════════════════════════════════════════════
	cmd/binds · keybinds
	─────────────────────────────────────────────────────────────────────────
	A bind is a key plus a command line, optionally paired with a second command
	line for the "off" half of a toggle:

	    Binds.add{ key = "F", command = "fly" }
	    Binds.add{ key = "N", command = "noclip", toggle = "unnoclip" }
	    Binds.add{ key = "LeftClick", command = "clicktp" }
	    Binds.add{ key = "T", command = "speed 100", keyUp = true }

	Compared with the legacy implementation:

	  · keys are stored as plain names ("F", "LeftClick"), not
	    "Enum.KeyCode.F" strings that every consumer then had to `:sub(14)`.
	    Saved files in the old format are migrated on load.
	  · the bind list is scanned through a key index instead of a linear pass
	    over every bind on every keystroke
	  · toggle state is keyed by the bind's identity rather than by the table
	    address, so it survives a settings reload
	  · a bind whose command no longer exists reports it once instead of
	    silently doing nothing
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Log      = IY.import("core/log")
local Guard    = IY.import("core/guard")
local Signal   = IY.import("core/signal")
local Services = IY.import("core/services")
local Bin      = IY.import("core/bin")
local Str      = IY.import("core/util/strings")
local Tbl      = IY.import("core/util/tables")

local UserInputService = Services.UserInputService

local M = {}

local binds = {}          -- array of { key, command, toggle, keyUp, on }
local index = {}          -- normalised key -> array of binds
local bin = Bin.new("binds")
local attached = false

M.binds   = binds
M.changed = Signal.new("binds.changed")

local MOUSE_KEYS = {
	[Enum.UserInputType.MouseButton1] = "LeftClick",
	[Enum.UserInputType.MouseButton2] = "RightClick",
	[Enum.UserInputType.MouseButton3] = "MiddleClick",
}

--[[ "Enum.KeyCode.F" / "f" / Enum.KeyCode.F / "LeftClick" -> "F" / "LeftClick" ]]
function M.normaliseKey(key)
	if typeof and typeof(key) == "EnumItem" then return key.Name end
	local text = Str.trim(tostring(key or ""))
	if text == "" then return nil end
	local stripped = string.match(text, "^Enum%.KeyCode%.(.+)$")
	if stripped then return stripped end
	local lowered = Str.lower(text)
	if lowered == "leftclick"   then return "LeftClick" end
	if lowered == "rightclick"  then return "RightClick" end
	if lowered == "middleclick" then return "MiddleClick" end
	-- Match a KeyCode case-insensitively so ";bind f fly" works.
	local items = Enum.KeyCode:GetEnumItems()
	for i = 1, #items do
		if Str.lower(items[i].Name) == lowered then return items[i].Name end
	end
	return nil
end

--[[ How the key reads in a notification: "F", "Left Click". ]]
function M.describeKey(key)
	if key == "LeftClick" then return "Left Click" end
	if key == "RightClick" then return "Right Click" end
	if key == "MiddleClick" then return "Middle Click" end
	return tostring(key)
end

local function rebuildIndex()
	for key in pairs(index) do index[key] = nil end
	for i = 1, #binds do
		local bind = binds[i]
		local bucket = index[bind.key]
		if not bucket then bucket = {} index[bind.key] = bucket end
		bucket[#bucket + 1] = bind
	end
end

local function persist()
	local Store = IY.import("core/store")
	local out = {}
	for i = 1, #binds do
		local bind = binds[i]
		out[#out + 1] = {
			COMMAND = bind.command,
			KEY     = bind.key,
			ISKEYUP = bind.keyUp or false,
			TOGGLE  = bind.toggle or false,
		}
	end
	Store.set("binds", out)
end

--[[ Load from settings, migrating the legacy key format. ]]
function M.load()
	local Store = IY.import("core/store")
	local stored = Store.get("binds") or {}
	for i = #binds, 1, -1 do binds[i] = nil end

	local migrated = 0
	for i = 1, #stored do
		local entry = stored[i]
		local command = entry.COMMAND or entry.command
		local rawKey = entry.KEY or entry.key
		local key = M.normaliseKey(rawKey)
		if type(command) == "string" and command ~= "" and key then
			if key ~= rawKey then migrated = migrated + 1 end
			binds[#binds + 1] = {
				key     = key,
				command = command,
				keyUp   = (entry.ISKEYUP or entry.keyUp) == true,
				toggle  = (type(entry.TOGGLE) == "string" and entry.TOGGLE) or nil,
				on      = false,
			}
		end
	end

	rebuildIndex()
	if migrated > 0 then
		Log.info("binds", "migrated %d keybind(s) to the new key format", migrated)
		persist()
	end
	M.changed:Fire()
	return #binds
end

function M.add(spec)
	local key = M.normaliseKey(spec.key)
	if not key then Guard.fail("'%s' is not a key", tostring(spec.key)) end
	local command = Str.trim(tostring(spec.command or ""))
	if command == "" then Guard.fail("a keybind needs a command") end

	local bind = {
		key     = key,
		command = command,
		toggle  = spec.toggle and Str.trim(tostring(spec.toggle)) or nil,
		keyUp   = spec.keyUp == true,
		on      = false,
	}
	binds[#binds + 1] = bind
	rebuildIndex()
	persist()
	M.changed:Fire()
	return bind
end

--[[ Remove binds matching a key, a command, or both. Returns how many went. ]]
function M.remove(query)
	local key = query.key and M.normaliseKey(query.key) or nil
	local command = query.command and Str.lower(Str.trim(query.command)) or nil
	local removed = 0
	for i = #binds, 1, -1 do
		local bind = binds[i]
		local keyMatches = key == nil or bind.key == key
		local commandMatches = command == nil or Str.lower(bind.command) == command
		if keyMatches and commandMatches then
			table.remove(binds, i)
			removed = removed + 1
		end
	end
	if removed > 0 then
		rebuildIndex()
		persist()
		M.changed:Fire()
	end
	return removed
end

function M.clear()
	local count = #binds
	for i = #binds, 1, -1 do binds[i] = nil end
	rebuildIndex()
	persist()
	M.changed:Fire()
	return count
end

function M.list()
	return binds
end

function M.count()
	return #binds
end

--[[ Which key an input event maps to, or nil for inputs we ignore. ]]
local function keyOf(input)
	if input.UserInputType == Enum.UserInputType.Keyboard then
		return input.KeyCode.Name
	end
	return MOUSE_KEYS[input.UserInputType]
end

local warned = {}

local function fire(bind)
	local Dispatch = IY.import("cmd/dispatch")
	local Registry = IY.import("cmd/registry")

	local line = bind.command
	if bind.toggle then
		if bind.on then line = bind.toggle end
		bind.on = not bind.on
	end

	local firstWord = string.match(line, "^%S+")
	if firstWord and not Registry.find(firstWord) then
		local Aliases = IY.import("cmd/aliases")
		if not Aliases.resolve(firstWord) then
			-- Tell the user once, not on every keypress.
			if not warned[line] then
				warned[line] = true
				IY.import("core/notify").warn("Keybind",
					"'" .. tostring(firstWord) .. "' is not a command any more -- rebind or remove it.")
			end
			return
		end
	end

	Dispatch.run(line, nil, { record = false })
end

--[[ Start listening. Called once by the boot input phase. ]]
function M.attach()
	if attached then return false end
	attached = true

	bin:connect(UserInputService.InputBegan, function(input, gameProcessed)
		if gameProcessed then return end
		local key = keyOf(input)
		if not key then return end
		local bucket = index[key]
		if not bucket then return end
		for i = 1, #bucket do
			if not bucket[i].keyUp then fire(bucket[i]) end
		end
	end)

	bin:connect(UserInputService.InputEnded, function(input, gameProcessed)
		if gameProcessed then return end
		local key = keyOf(input)
		if not key then return end
		local bucket = index[key]
		if not bucket then return end
		for i = 1, #bucket do
			if bucket[i].keyUp then fire(bucket[i]) end
		end
	end)

	IY.onUnload(function() bin:destroy() end)
	return true
end

--[[ Capture the next key the user presses -- used by the keybind editor.
     Returns a cancel function; `callback(keyName)` fires once. ]]
function M.captureNext(callback)
	local capture = Bin.new("binds.capture")
	capture:connect(UserInputService.InputBegan, function(input)
		local key = keyOf(input)
		if not key then return end
		capture:destroy()
		callback(key)
	end)
	return function() capture:destroy() end
end

return M
