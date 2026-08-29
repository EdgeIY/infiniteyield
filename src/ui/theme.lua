--[[═══════════════════════════════════════════════════════════════════════════
	ui/theme · the six colour registries and the applier
	─────────────────────────────────────────────────────────────────────────
	Legacy source.ref.lua 335-340 (the six tables), 2930-2935 (the `current*`
	globals), 3420-3455 (`updateColors`) and 13151-13156 (the boot-time apply).

	    Theme.register(instance, "shade2")   -- replaces table.insert(shade2, x)
	    Theme.unregister(instance)           -- the legacy tables only ever grew
	    Theme.apply("shade2", colour)        -- replaces updateColors(c, shade2)
	    Theme.set("shade2", colour)          -- apply + persist through Store
	    Theme.colors.shade2                  -- the live Color3

	Three things are different from the legacy version, all of them consequences
	of the registries being real objects instead of six array literals:

	  · registration is idempotent and reversible. `text1` held 440+ entries
	    immediately after boot and every list refresh added more, so a theme
	    change walked a list that never stopped growing and kept destroyed
	    instances alive with it.
	  · registering applies the current colour immediately. The legacy code
	    hard-coded the default colour on every row it built, so rows created
	    after boot -- every keybind, alias, waypoint and plugin row -- showed the
	    default palette until the next theme change.
	  · colours live in core/store, so `Store.reset()` and a settings file
	    written by another build both reach the interface.

	Registry -> property is exactly as it was: BackgroundColor3 for the shades,
	TextColor3 for the texts (plus PlaceholderColor3 on a TextBox), and
	ScrollBarImageColor3 for scroll.
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Bin    = IY.import("core/bin")
local Guard  = IY.import("core/guard")
local Log    = IY.import("core/log")
local Signal = IY.import("core/signal")
local Store  = IY.import("core/store")

local log = Log.scope("ui/theme")

local M = {}

--[[ Ordered so applyAll() and the diagnostics report are deterministic. ]]
local NAMES = { "shade1", "shade2", "shade3", "text1", "text2", "scroll" }

--[[ `default` is the legacy palette (2930-2935), which is what the colour
     picker's Default button restores. core/store carries its own defaults for a
     fresh settings file; these are only used when a colour is missing. ]]
local SPEC = {
	shade1 = { property = "BackgroundColor3",     default = Color3.fromRGB(36, 36, 37) },
	shade2 = { property = "BackgroundColor3",     default = Color3.fromRGB(46, 46, 47) },
	shade3 = { property = "BackgroundColor3",     default = Color3.fromRGB(78, 78, 79) },
	text1  = { property = "TextColor3",           default = Color3.new(1, 1, 1), placeholder = true },
	text2  = { property = "TextColor3",           default = Color3.new(0, 0, 0) },
	scroll = { property = "ScrollBarImageColor3", default = Color3.fromRGB(78, 78, 79) },
}

M.names    = NAMES
M.registries = SPEC
M.changed  = Signal.new("theme.changed")
M.colors   = {}
M.defaults = {}

local items = {}          -- name -> array of instances
local slots = {}          -- name -> instance -> index in that array

for i = 1, #NAMES do
	local name = NAMES[i]
	items[name] = {}
	slots[name] = {}
	M.colors[name]   = SPEC[name].default
	M.defaults[name] = SPEC[name].default
end

local bin = Bin.new("ui/theme")
M.bin = bin

-- ── applying ────────────────────────────────────────────────────────────────

local function applyOne(spec, instance, colour)
	instance[spec.property] = colour
	if spec.placeholder and instance:IsA("TextBox") then
		instance.PlaceholderColor3 = colour
	end
end

local function removeFrom(name, instance)
	local slot, list = slots[name], items[name]
	local index = slot[instance]
	if not index then return false end
	local last = #list
	if index ~= last then
		local moved = list[last]
		list[index] = moved
		slot[moved] = index
	end
	list[last] = nil
	slot[instance] = nil
	return true
end

--[[ Walk backwards so dropping an entry mid-loop is safe, and drop anything the
     assignment fails on -- a wrong class or an instance somebody destroyed
     without unregistering would otherwise abort the rest of the palette. ]]
local function applyList(name, colour)
	local spec = SPEC[name]
	local list = items[name]
	local failures
	for i = #list, 1, -1 do
		local instance = list[i]
		local ok = pcall(applyOne, spec, instance, colour)
		if not ok then
			failures = failures or {}
			failures[#failures + 1] = instance
		end
	end
	if failures then
		for i = 1, #failures do removeFrom(name, failures[i]) end
		log.warn("dropped %d unusable entr(ies) from '%s'", #failures, name)
	end
end

-- ── public API ──────────────────────────────────────────────────────────────

--[[ Add an instance to a registry. Idempotent, and the current colour is
     applied on the way in so a row built after boot is never the wrong shade. ]]
function M.register(instance, name)
	if instance == nil then return nil end
	local spec = SPEC[name]
	if not spec then
		log.warn("unknown colour registry '%s'", tostring(name))
		return nil
	end
	if slots[name][instance] then return instance end

	local ok, err = Guard.call("ui/theme.register", applyOne, spec, instance, M.colors[name])
	if not ok then
		-- A class without the property is a caller bug, not a runtime condition:
		-- say so once instead of failing on every future theme change.
		log.warn("cannot register %s in '%s': %s",
			tostring(instance), name, Guard.describe(err))
		return nil
	end

	local list = items[name]
	list[#list + 1] = instance
	slots[name][instance] = #list
	return instance
end

--[[ Remove an instance from one registry, or from all of them. ]]
function M.unregister(instance, name)
	if instance == nil then return false end
	if name ~= nil then return removeFrom(name, instance) end
	local removed = false
	for i = 1, #NAMES do
		if removeFrom(NAMES[i], instance) then removed = true end
	end
	return removed
end

function M.registered(instance, name)
	if name then return slots[name] ~= nil and slots[name][instance] ~= nil end
	for i = 1, #NAMES do
		if slots[NAMES[i]][instance] then return true end
	end
	return false
end

--[[ Colour one registry now, without saving. ]]
function M.apply(name, colour)
	local spec = SPEC[name]
	if not spec then return false, "unknown colour '" .. tostring(name) .. "'" end
	if colour == nil then return false, "no colour given" end
	M.colors[name] = colour
	applyList(name, colour)
	M.changed:Fire(name, colour)
	return true
end

--[[ Re-apply every current colour. Legacy 13151-13156, called once the whole
     window exists. ]]
function M.applyAll()
	for i = 1, #NAMES do
		M.apply(NAMES[i], M.colors[NAMES[i]])
	end
	return true
end

function M.get(name)
	return M.colors[name]
end

--[[ Apply and persist. The store fires back into apply() through the watch
     below, so this is the only path that needs to know about saving. ]]
function M.set(name, colour)
	if not SPEC[name] then return false, "unknown colour '" .. tostring(name) .. "'" end
	if colour == nil then return false, "no colour given" end
	local ok, reason = Store.set("theme." .. name, colour)
	if not ok then
		-- No filesystem, or a value the schema rejected: still colour the
		-- interface, because the picker showing nothing would be worse.
		M.apply(name, colour)
		return false, reason
	end
	if M.colors[name] ~= colour then M.apply(name, colour) end
	return true
end

--[[ Restore the legacy palette (what the picker's Default button does). ]]
function M.setDefaults()
	for i = 1, #NAMES do
		M.set(NAMES[i], M.defaults[NAMES[i]])
	end
	return true
end

--[[ Drop every registration. Used when the interface unmounts. ]]
function M.clear()
	for i = 1, #NAMES do
		items[NAMES[i]] = {}
		slots[NAMES[i]] = {}
	end
end

--[[ How many instances each registry holds -- the number the legacy script had
     no way to see. ]]
function M.snapshot()
	local out = {}
	for i = 1, #NAMES do
		local name = NAMES[i]
		out[name] = { count = #items[name], color = M.colors[name] }
	end
	return out
end

-- ── settings ────────────────────────────────────────────────────────────────

-- watch() fires immediately, so this is also how M.colors is primed.
for i = 1, #NAMES do
	local name = NAMES[i]
	bin:add(Store.watch("theme." .. name, function(colour)
		if colour ~= nil then M.apply(name, colour) end
	end))
end

IY.onUnload(function()
	bin:destroy()
	M.clear()
end, "ui/theme")

return M
