--[[═══════════════════════════════════════════════════════════════════════════
	features/waypoints · saved positions, one list and one signal
	─────────────────────────────────────────────────────────────────────────
	Legacy kept the same data three times -- `AllWaypoints` (every place, the
	one that was written to disk), `WayPoints` (this place, rebuilt at load) and
	`pWayPoints` (part-tracking) -- and every command had to remember to update
	all three, with different rules for each. That is why `deletewaypoint` could
	remove a waypoint from the list you could see but not from the file, and why
	`clearwaypoints` called `updatesaves()` *before* emptying `AllWaypoints`, so
	every waypoint you had just deleted came back on the next rejoin.

	Here there is one persisted list and one session list, and which place a
	waypoint belongs to is a filter rather than a second copy:

	    Waypoints.add("base", Character.cframe())
	    Waypoints.find("ba")           -> entry (exact match first, then prefix)
	    Waypoints.cframeOf(entry)      -> CFrame, or nil for a part that is gone
	    Waypoints.changed:Connect(fn)  -- the markers and the UI panel listen

	An entry is:

	    { name  = "base",       as the user typed it
	      place = 1234 or nil,  nil belongs to every place (legacy GAME-less)
	      coord = { x, y, z },  a coordinate waypoint
	      part  = BasePart }    tracks a part; session-only, never persisted

	On disk the shape is exactly the legacy one -- an array of
	{ NAME = string, COORD = {x,y,z}, GAME = placeId } under the `waypoints`
	key -- so a save file still works in either build, in either direction.

	Replaces source.ref.lua 2189 (AllWaypoints), 3165-3174 (the per-place
	filter), 4201-4228 (ChoosePart's data half) and 7591-7630 (the markers).
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Feature  = IY.import("features/feature")
local Store    = IY.import("core/store")
local Signal   = IY.import("core/signal")
local Platform = IY.import("core/platform")
local Guard    = IY.import("core/guard")
local Log      = IY.import("core/log")
local Inst     = IY.import("core/util/instances")
local Str      = IY.import("core/util/strings")

local M = {}

local log = Log.scope("waypoints")

--[[ Fired as (reason, entry) with reason "added", "removed", "cleared" or
     "loaded". Everything that draws a waypoint list rebuilds from this. ]]
M.changed = Signal.new("waypoints.changed")

--[[ How long a ;tweenwaypoint takes, in seconds. Legacy called it a speed and
     passed it straight to TweenInfo.new as a duration; features/teleport reads
     this field for every other tweening command. ]]
M.tweenSpeed = 1

local saved   = {}     -- every persisted waypoint, every place (legacy AllWaypoints)
local parts   = {}     -- part-tracking waypoints, this session (legacy pWayPoints)
local primed  = false  -- has the store been read into `saved` yet
local writing = false  -- our own Store.set, so the watch below can ignore it

-- ── disk ────────────────────────────────────────────────────────────────────

--[[ Coordinates go back through tonumber because legacy `waypointpos` saved its
     raw arguments, so real files contain COORD = {"0","50","0"}. An entry that
     cannot be salvaged is dropped here rather than throwing at teleport time. ]]
local function fromDisk(list)
	local out = {}
	if type(list) ~= "table" then return out end
	for i = 1, #list do
		local raw = list[i]
		if type(raw) == "table" and type(raw.COORD) == "table" and raw.NAME ~= nil then
			local x = tonumber(raw.COORD[1])
			local y = tonumber(raw.COORD[2])
			local z = tonumber(raw.COORD[3])
			if x and y and z then
				out[#out + 1] = {
					name  = tostring(raw.NAME),
					coord = { x, y, z },
					place = tonumber(raw.GAME),
				}
			end
		end
	end
	return out
end

local function toDisk()
	local out = {}
	for i = 1, #saved do
		local entry = saved[i]
		out[i] = {
			NAME  = entry.name,
			COORD = { entry.coord[1], entry.coord[2], entry.coord[3] },
			GAME  = entry.place,
		}
	end
	return out
end

--[[ Read the file once, lazily. The store has to have loaded first: a module
     imported before boot's settings phase would otherwise latch an empty list
     and then save it back over the real one. ]]
local function prime()
	if primed or not Store.loaded then return end
	primed = true
	saved = fromDisk(Store.get("waypoints"))
end

local function persist()
	writing = true
	local ok, reason = Store.set("waypoints", toDisk())
	writing = false
	if not ok then log.warn("could not save waypoints: %s", tostring(reason)) end
	return ok
end

-- ── queries ─────────────────────────────────────────────────────────────────

--[[ A waypoint with no place belongs to every game, which is how the legacy
     loader (3170) treated an entry with no GAME field. ]]
local function belongsHere(entry)
	return entry.place == nil or entry.place == Platform.placeId
end

function M.list()
	prime()
	local out = {}
	for i = 1, #saved do
		if belongsHere(saved[i]) then out[#out + 1] = saved[i] end
	end
	for i = 1, #parts do out[#out + 1] = parts[i] end
	return out
end

function M.all()
	prime()
	local out = {}
	for i = 1, #saved do out[i] = saved[i] end
	return out
end

function M.names()
	local list = M.list()
	local out = {}
	for i = 1, #list do out[i] = list[i].name end
	return out
end

--[[ Exact name first, then a prefix, both case-insensitive: `;wp ba` reaches
     "base", while a waypoint actually called "ba" always wins over it. ]]
function M.find(name)
	if type(name) ~= "string" then return nil end
	local needle = Str.lower(Str.trim(name))
	if needle == "" then return nil end
	local list = M.list()
	for i = 1, #list do
		if Str.lower(list[i].name) == needle then return list[i] end
	end
	for i = 1, #list do
		if Str.matchesPrefix(list[i].name, needle) then return list[i] end
	end
	return nil
end

-- ── editing ─────────────────────────────────────────────────────────────────

--[[ Remove every entry with this name. Backwards, because the legacy
     `for i,v in pairs(t) do table.remove(t, i) end` skipped the element after
     each hit -- with two waypoints of the same name, one always survived. ]]
local function dropNamed(list, name, hereOnly)
	local needle = Str.lower(name)
	local removed = 0
	for i = #list, 1, -1 do
		local entry = list[i]
		if Str.lower(entry.name) == needle and (not hereOnly or belongsHere(entry)) then
			table.remove(list, i)
			removed = removed + 1
		end
	end
	return removed
end

local function requireName(name)
	local text = Str.trim(tostring(name or ""))
	if text == "" then Guard.fail("a waypoint needs a name") end
	return text
end

local function savedHere(name)
	local needle = Str.lower(name)
	for i = 1, #saved do
		if belongsHere(saved[i]) and Str.lower(saved[i].name) == needle then return saved[i] end
	end
	return nil
end

--[[ Create or overwrite, keeping the casing just typed. Returns the entry and
     whether it replaced one, which is what lets a command say "Replaced" rather
     than "Created" -- legacy appended unconditionally, so saving twice under one
     name left two waypoints and `deletewaypoint` only removed one of them. ]]
function M.add(name, cframe)
	prime()
	name = requireName(name)
	local kind = (typeof and typeof(cframe)) or type(cframe)
	local position = nil
	if kind == "CFrame" then position = cframe.Position
	elseif kind == "Vector3" then position = cframe end
	if not position then Guard.fail("a waypoint needs a position") end

	-- Overwriting a waypoint that belongs to every place keeps it global; only a
	-- brand new one is stamped with this place.
	local previous = savedHere(name)
	local place = Platform.placeId
	if previous then place = previous.place end

	local replaced = dropNamed(saved, name, true) > 0
	if dropNamed(parts, name) > 0 then replaced = true end

	local entry = {
		name  = name,
		coord = { position.X, position.Y, position.Z },
		place = place,
	}
	saved[#saved + 1] = entry
	persist()
	M.changed:Fire("added", entry)
	return entry, replaced
end

--[[ A waypoint that follows a part -- legacy `pWayPoints`, filled in by the
     "teleport to part" panel. Deliberately not persisted: the part only exists
     for this session, which is why the save format has nowhere to put one. ]]
function M.addPart(name, part)
	prime()
	name = requireName(name)
	if not Inst.isAlive(part) then Guard.fail("that part is no longer in the game") end
	local isPart = Guard.try(function() return part:IsA("BasePart") end)
	if not isPart then Guard.fail("a waypoint can only follow a part") end

	local replaced = dropNamed(parts, name) > 0
	if dropNamed(saved, name, true) > 0 then
		replaced = true
		persist()
	end

	local entry = { name = name, part = part }
	parts[#parts + 1] = entry
	M.changed:Fire("added", entry)
	return entry, replaced
end

--[[ Exact name, so a mistyped prefix cannot delete the wrong waypoint. Callers
     that want prefix matching resolve through find() first and pass entry.name.

     Only this place's waypoints and the global ones, exactly as legacy
     deletewaypoint guarded its AllWaypoints pass (7714): a waypoint of the same
     name saved in another game is not yours to delete from here. ]]
function M.remove(name)
	prime()
	local text = Str.trim(tostring(name or ""))
	if text == "" then return false end
	local fromSaved = dropNamed(saved, text, true)
	local fromParts = dropNamed(parts, text)
	if fromSaved + fromParts == 0 then return false end
	if fromSaved > 0 then persist() end
	M.changed:Fire("removed", text)
	return true
end

--[[ This place only (;cleargamewaypoints). Waypoints with no place survive:
     they belong to every game, so dropping them from here would silently delete
     them everywhere -- legacy's `v.GAME == PlaceId` test made the same call.
     Part waypoints do go, which legacy's did not: it tested pWayPoints entries
     for a GAME field they never had, so the loop never matched anything. ]]
function M.clear()
	prime()
	local removed = #parts
	parts = {}
	for i = #saved, 1, -1 do
		if saved[i].place == Platform.placeId then
			table.remove(saved, i)
			removed = removed + 1
		end
	end
	persist()
	M.changed:Fire("cleared")
	return removed
end

--[[ Every waypoint in every game (;clearwaypoints). Persisted immediately --
     legacy wrote the save file before it emptied AllWaypoints. ]]
function M.clearAll()
	prime()
	local removed = #saved + #parts
	saved, parts = {}, {}
	persist()
	M.changed:Fire("cleared")
	return removed
end

--[[ Where an entry is now. Part waypoints resolve to the part's current
     position (position only, as legacy did) and to nil once the part is gone,
     so callers can say so instead of teleporting into the void at 0,0,0. ]]
function M.cframeOf(entry)
	if type(entry) ~= "table" then return nil end
	if entry.part then
		if not Inst.isAlive(entry.part) then return nil end
		return CFrame.new(entry.part.Position)
	end
	local coord = entry.coord
	if type(coord) ~= "table" then return nil end
	local x, y, z = tonumber(coord[1]), tonumber(coord[2]), tonumber(coord[3])
	if not x or not y or not z then return nil end
	return CFrame.new(x, y, z)
end

function M.setTweenSpeed(seconds)
	local value = tonumber(seconds) or 1
	if value < 0 then value = 0 end
	M.tweenSpeed = value
	return value
end

-- ── markers ─────────────────────────────────────────────────────────────────

local MARKER_SIZE = Vector3.new(5, 5, 5)

local function adorn(bin, target)
	local adornment = bin:add(Instance.new("BoxHandleAdornment"))
	adornment.Name = "IY_" .. Str.random(10)
	adornment.Adornee = target
	adornment.AlwaysOnTop = true
	adornment.ZIndex = 10
	adornment.Size = target.Size
	adornment.Parent = target
	return adornment
end

--[[ The name over the marker. Legacy drew five identical grey cubes and left you
     to guess which was which. ]]
local function label(part, text)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "IY_" .. Str.random(10)
	billboard.Size = UDim2.new(0, 200, 0, 40)
	billboard.StudsOffset = Vector3.new(0, 3, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = part

	local caption = Instance.new("TextLabel")
	caption.BackgroundTransparency = 1
	caption.Size = UDim2.new(1, 0, 1, 0)
	caption.Font = Enum.Font.SourceSansBold
	caption.TextScaled = true
	caption.TextColor3 = Color3.fromRGB(255, 255, 255)
	caption.TextStrokeTransparency = 0.4
	caption.Text = text
	caption.Parent = billboard
	return billboard
end

--[[ One marker per waypoint. A part waypoint is adorned in place, which is what
     legacy did -- except that adornment went onto a *game* part and was only
     tracked in a `waypointParts` table that nothing but `hidewaypoints` ever
     read, so `;unloadiy` left it in the world for good. Here it is in the bin. ]]
local function addMarker(bin, folder, entry)
	if entry.part then
		if not Inst.isAlive(entry.part) then return false end
		adorn(bin, entry.part)
		return true
	end
	local cframe = M.cframeOf(entry)
	if not cframe then return false end
	local part = bin:add(Instance.new("Part"))
	part.Name = "IY_" .. Str.random(10)
	part.Size = MARKER_SIZE
	part.CFrame = cframe
	part.Anchored = true
	part.CanCollide = false
	part.Parent = folder
	adorn(bin, part)
	label(part, entry.name)
	return true
end

local markers = Feature.new("waypointmarkers", {
	command  = "showwaypoints",
	describe = "waypoint markers",

	start = function(self)
		local folder = self.bin:instance("Folder", {
			Name   = "IY_" .. Str.random(10),
			Parent = workspace,
		})
		local held = self.bin:branch("markers")

		local function rebuild()
			held:empty()
			local list = M.list()
			local shown = 0
			for i = 1, #list do
				if addMarker(held, folder, list[i]) then shown = shown + 1 end
			end
			self.state.count = shown
		end

		rebuild()
		-- Legacy markers were a snapshot: saving a waypoint while they were up
		-- did nothing until you re-ran the command.
		self.bin:connect(M.changed, rebuild)
	end,
})

--[[ Returns how many markers are up, so the command can say "nothing to show"
     without asking twice. Starting again is a rebuild, not a second set. ]]
function M.showMarkers()
	markers:start()
	return markers.state.count or 0
end

function M.hideMarkers()
	return markers:stop()
end

function M.markersVisible()
	return markers:isRunning()
end

--[[ The store is the source of truth, so an external write (a settings reset,
     another build's file) reloads rather than being clobbered by whatever this
     session happens to hold. `writing` skips our own saves, and the immediate
     first callback is what primes the list during a normal boot. ]]
local connection = Store.watch("waypoints", function(list)
	if writing or not Store.loaded then return end
	primed = true
	saved = fromDisk(list)
	M.changed:Fire("loaded")
end)

IY.onUnload(function() connection:Disconnect() end, "features/waypoints")

return M
