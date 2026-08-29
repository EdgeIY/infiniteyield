--[[═══════════════════════════════════════════════════════════════════════════
	core/snapshot · remember the original before you change it
	─────────────────────────────────────────────────────────────────────────
	Dozens of legacy commands wrote engine or instance properties with no
	record of what was there:

	  · workspace.FallenPartsDestroyHeight had four independent writers --
	    respawn() (line 5000), `destroyheight` (12604) and both `antivoid` and
	    `fakeout` through the load-time global OrgDestroyHeight (12608, 12635).
	    Because that global was captured once at load, `fakeout` handed back a
	    height that was correct at boot and wrong after anyone ran `;dh`.
	  · freecam saved Camera.FieldOfView (8520) and then restored a hard-coded
	    70 (8521, 8537, 8582), so anyone whose FOV was not 70 got it changed
	  · mousesensitivity (12280), ctrllock, hitbox, headsize, darkchat and
	    nofog had no restore path at all

	One registry, one rule: the first writer records the value, and that is the
	value any later restore puts back.

	    Snapshot.set(Lighting, "FogEnd", 1e6, "lighting")
	    Snapshot.capture(camera, "FieldOfView", "camera")  -- mutated in a loop
	    Snapshot.restoreTag("lighting")                    -- count, failures
	    Snapshot.restoreAll()                              -- the unload hook

	Records are keyed weakly by instance and never hold a strong reference back
	to it, so a destroyed part's records are collectable; restores whose
	instance has left the DataModel are dropped rather than retried. Values are
	stored as-is -- Color3, CFrame, EnumItem, Instance, number, boolean -- with
	no serialisation, and every read and write is wrapped, because hidden and
	FFlag-gated properties throw on some clients.
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Log   = IY.import("core/log")
local Guard = IY.import("core/guard")

local log = Log.scope("core/snapshot")

local M = {}
-- instance -> { [property] = { value = <original>, tag = <string>, at = clock } }
-- Weak keys, and a record deliberately does not store its own instance: a
-- strong back reference from the value to the key is exactly what would keep a
-- destroyed instance alive for the rest of the session.
local records = setmetatable({}, { __mode = "k" })

-- tag -> weak-keyed { [instance] = { [property] = true } }
local tagIndex = {}

local function now()
	if os and os.clock then return os.clock() end
	return 0
end

local function read(instance, property) return instance[property] end
local function write(instance, property, value) instance[property] = value end

local function describe(instance)
	local ok, name = pcall(read, instance, "Name")
	if ok and name ~= nil then return tostring(name) end
	return "<instance>"
end

--[[ Still in the DataModel? A destroyed instance keeps answering reads, so
     Parent is the only cheap liveness test. ]]
local function parented(instance)
	local ok, parent = pcall(read, instance, "Parent")
	return ok and parent ~= nil
end

local function bucketFor(tag)
	local bucket = tagIndex[tag]
	if not bucket then
		bucket = setmetatable({}, { __mode = "k" })
		tagIndex[tag] = bucket
	end
	return bucket
end

local function recordFor(instance, property)
	if instance == nil then return nil end
	local byProperty = records[instance]
	if not byProperty then return nil end
	return byProperty[property]
end

--[[ Record the current value the first time an (instance, property) pair is
     touched. Later calls return the existing record untouched -- that is the
     whole point: the value four writers restore has to be the one the game
     started with, not whatever the previous writer left behind.

     The tag of the first writer owns the record. ]]
local function remember(instance, property, tag)
	local existing = recordFor(instance, property)
	if existing then return existing end
	local ok, current = pcall(read, instance, property)
	if not ok then
		return nil, "cannot read " .. tostring(property) .. " on " .. describe(instance)
	end
	local byProperty = records[instance]
	if not byProperty then
		byProperty = {}
		records[instance] = byProperty
	end
	local record = { value = current, tag = tag or "misc", at = now() }
	byProperty[property] = record

	local bucket = bucketFor(record.tag)
	local properties = bucket[instance]
	if not properties then
		properties = {}
		bucket[instance] = properties
	end
	properties[property] = true
	return record
end

--[[ Drop a record without restoring it. ]]
function M.forget(instance, property)
	local record = recordFor(instance, property)
	if not record then return false end
	local byProperty = records[instance]
	byProperty[property] = nil
	if next(byProperty) == nil then records[instance] = nil end
	local bucket = tagIndex[record.tag]
	local properties = bucket and bucket[instance]
	if properties then
		properties[property] = nil
		if next(properties) == nil then bucket[instance] = nil end
	end
	return true
end

--[[ Record-then-assign. Returns true, or false plus a reason when the property
     cannot be read or written (missing, read-only, hidden, instance gone). ]]
function M.set(instance, property, value, tag)
	if instance == nil then return false, "no instance" end
	if type(property) ~= "string" then return false, "property must be a string" end
	local had = recordFor(instance, property) ~= nil
	local record, reason = remember(instance, property, tag)
	if not record then return false, reason end
	local ok, err = pcall(write, instance, property, value)
	if not ok then
		-- Nothing changed, so a record created for *this* call would make a
		-- later restoreAll write a value the game never asked for.
		if not had then M.forget(instance, property) end
		return false, Guard.describe(err)
	end
	record.writes = (record.writes or 0) + 1
	return true
end

--[[ Record without assigning -- for values a feature mutates directly, e.g. a
     camera CFrame written every frame by a render loop. ]]
function M.capture(instance, property, tag)
	if instance == nil then return false, "no instance" end
	if type(property) ~= "string" then return false, "property must be a string" end
	local record, reason = remember(instance, property, tag)
	if not record then return false, reason end
	return true
end

--[[ The recorded original, plus whether a record exists at all. The second
     return matters: plenty of Roblox properties are legitimately nil
     (Humanoid.RootPart, Model.PrimaryPart, Player.Character). ]]
function M.original(instance, property)
	local record = recordFor(instance, property)
	if not record then return nil, false end
	return record.value, true
end

function M.isModified(instance, property)
	if instance == nil then return false end
	local byProperty = records[instance]
	if not byProperty then return false end
	if property == nil then return next(byProperty) ~= nil end
	return byProperty[property] ~= nil
end

--[[ Put the original back and forget the record. The record is dropped even
     when the write fails, so a property that can no longer be written cannot
     keep failing on every subsequent restoreTag / restoreAll. ]]
function M.restore(instance, property)
	if instance == nil then return false, "no instance" end
	local record = recordFor(instance, property)
	if not record then
		return false, "nothing recorded for " .. tostring(property)
	end
	local value = record.value
	M.forget(instance, property)
	if not parented(instance) then
		-- Destroyed or never parented: the record is gone, which is all the
		-- caller actually needs.
		return true
	end
	local ok, err = pcall(write, instance, property, value)
	if not ok then return false, Guard.describe(err) end
	return true
end

--[[ Restore everything recorded under a tag ("lighting", "camera",
     "humanoid", ...). Returns how many were restored and a list of failures. ]]
function M.restoreTag(tag)
	local bucket = tagIndex[tag]
	if not bucket then return 0, {} end
	-- Collect first: restore() mutates the bucket as it goes.
	local pending = {}
	for instance, properties in pairs(bucket) do
		for property in pairs(properties) do
			pending[#pending + 1] = { instance = instance, property = property }
		end
	end
	local restored, failures = 0, {}
	for i = 1, #pending do
		local item = pending[i]
		local ok, reason = M.restore(item.instance, item.property)
		if ok then
			restored = restored + 1
		else
			failures[#failures + 1] = {
				instance = describe(item.instance),
				property = item.property,
				reason   = reason,
			}
		end
	end
	if next(bucket) == nil then tagIndex[tag] = nil end
	return restored, failures
end

function M.restoreAll()
	local tags = {}
	for tag in pairs(tagIndex) do tags[#tags + 1] = tag end
	table.sort(tags)
	local restored, failures = 0, {}
	for i = 1, #tags do
		local count, tagFailures = M.restoreTag(tags[i])
		restored = restored + count
		for j = 1, #tagFailures do failures[#failures + 1] = tagFailures[j] end
	end
	-- Anything left can only be a record whose tag bucket lost its weak key
	-- before the sweep reached it; clear those so a reload starts clean.
	for instance, byProperty in pairs(records) do
		for property in pairs(byProperty) do
			if M.restore(instance, property) then restored = restored + 1 end
		end
	end
	return restored, failures
end

--[[ Number of recorded properties, and of instances holding them. ]]
function M.count()
	local properties, instances = 0, 0
	for _, byProperty in pairs(records) do
		instances = instances + 1
		for _ in pairs(byProperty) do properties = properties + 1 end
	end
	return properties, instances
end

--[[ Grouped by tag for ;iydiag. Instances are reported by name: handing live
     references to a diagnostics panel is how a read-only report ends up
     pinning half the workspace in memory. `writes` is how many features have
     assigned the property since it was recorded -- the four-writer
     FallenPartsDestroyHeight bug would have been obvious from that column. ]]
function M.snapshot()
	local out = {}
	for tag, bucket in pairs(tagIndex) do
		local entries = {}
		for instance, properties in pairs(bucket) do
			local name = describe(instance)
			local live = parented(instance)
			for property in pairs(properties) do
				local record = recordFor(instance, property)
				entries[#entries + 1] = {
					instance = name,
					property = property,
					original = tostring(record and record.value),
					writes   = record and record.writes or 0,
					live     = live,
				}
			end
		end
		table.sort(entries, function(a, b)
			if a.instance == b.instance then return a.property < b.property end
			return a.instance < b.instance
		end)
		out[#out + 1] = { tag = tag, count = #entries, entries = entries }
	end
	table.sort(out, function(a, b) return a.tag < b.tag end)
	return out
end

IY.onUnload(function()
	local restored, failures = M.restoreAll()
	if restored > 0 or #failures > 0 then
		log.debug("restored %d propert%s, %d failure(s)",
			restored, restored == 1 and "y" or "ies", #failures)
	end
end, "core/snapshot")

IY.snapshot = M
return M
