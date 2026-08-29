--[[═══════════════════════════════════════════════════════════════════════════
	features/lighting · fullbright, time of day, fog and the restore path
	─────────────────────────────────────────────────────────────────────────
	Legacy source.ref.lua 11484-11557. Every one of those commands wrote Lighting
	directly, and the undo was a single `origsettings` table captured *at load*
	(11547) that `restorelighting` (11549) wrote back property by property. Three
	things were wrong with that:

	  · the record was taken once, at load. A game that changed its own lighting
	    afterwards -- day/night cycles do it constantly -- had `restorelighting`
	    hand back a snapshot of the moment IY started, not what the game wanted.
	  · `origsettings` covered seven properties. `nofog` (11526) *destroyed* every
	    Atmosphere in Lighting, which no restore can undo: the instance and its
	    Density, Haze, Glare, Colour and Decay are simply gone. Here nofog zeroes
	    Density, Haze and Glare instead, which is what actually clears the haze,
	    and every value is recorded so it comes back.
	  · nothing restored on unload.

	So every write in this file goes through `Snapshot.set(..., "lighting")`, and
	`restorelighting` is `Snapshot.restoreTag("lighting")` -- which also means
	`;unloadiy` restores lighting for free through core/snapshot's own hook.

	`loopfullbright` (11492) re-applied on RenderStepped for games that fight
	fullbright; it is still a frame loop, but each property is compared before it
	is written, so a game that leaves the values alone costs five reads a frame
	and no writes.
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Feature  = IY.import("features/feature")
local Sched    = IY.import("core/scheduler")
local Snapshot = IY.import("core/snapshot")
local Services = IY.import("core/services")
local Guard    = IY.import("core/guard")

local Lighting = Services.Lighting

local M = {}

local TAG = "lighting"
M.TAG = TAG

-- Far enough that fog is behind the far plane in every game anyone plays.
local FOG_END = 100000

-- Legacy's fullbright values (11485-11489), in a fixed order so the loop and the
-- one-shot cannot drift apart.
local FULLBRIGHT = {
	{ "Brightness",     2 },
	{ "ClockTime",      14 },
	{ "FogEnd",         FOG_END },
	{ "GlobalShadows",  false },
	{ "OutdoorAmbient", Color3.fromRGB(128, 128, 128) },
}

local function readProperty(instance, property) return instance[property] end

--[[ Record the original, then assign -- but only when the value differs, so the
     frame loop is not writing five identical properties sixty times a second.
     The capture is unconditional: skipping it when the value already matches
     would mean a game that changes the property later gets *its* value recorded
     as the original, and `restorelighting` would hand back the wrong thing. ]]
local function put(instance, property, value)
	Snapshot.capture(instance, property, TAG)
	local current = Guard.try(readProperty, instance, property)
	if current == value then return false end
	return (Snapshot.set(instance, property, value, TAG)) == true
end

function M.fullbright()
	local changed = 0
	for i = 1, #FULLBRIGHT do
		if put(Lighting, FULLBRIGHT[i][1], FULLBRIGHT[i][2]) then changed = changed + 1 end
	end
	return changed
end

--[[ Legacy set Ambient and OutdoorAmbient from the same arguments (11514). ]]
function M.ambient(colour)
	put(Lighting, "Ambient", colour)
	put(Lighting, "OutdoorAmbient", colour)
	return colour
end

function M.clockTime(hour)
	put(Lighting, "ClockTime", hour)
	return hour
end

function M.brightness(level)
	put(Lighting, "Brightness", level)
	return level
end

function M.globalShadows(enabled)
	put(Lighting, "GlobalShadows", enabled == true)
	return enabled == true
end

--[[ Push fog past the far plane and flatten any Atmosphere, without destroying
     it (11530). Density is the property that produces the haze; Haze and Glare
     are zeroed too because a dense-but-hazy sky still greys out distant
     geometry. All three are recorded, so `restorelighting` puts the game's own
     atmosphere back -- something the legacy Destroy made impossible. ]]
function M.noFog()
	put(Lighting, "FogEnd", FOG_END)
	local found = 0
	local descendants = Guard.try(function() return Lighting:GetDescendants() end) or {}
	for i = 1, #descendants do
		local child = descendants[i]
		if child:IsA("Atmosphere") then
			found = found + 1
			put(child, "Density", 0)
			put(child, "Haze", 0)
			put(child, "Glare", 0)
		end
	end
	return found
end

-- ── loopfullbright ──────────────────────────────────────────────────────────

local loop = Feature.new("loopfullbright", {
	command  = "loopfullbright",
	describe = "fullbright re-applied every frame",

	start = function(self)
		M.fullbright()
		self.bin:add(Sched.frameLoop("lighting.fullbright", function()
			M.fullbright()
		end))
	end,
})

M.loop = loop

function M.startLoop()  return loop:start() end
function M.isLooping()  return loop:isRunning() end

--[[ Stopping the loop leaves the lighting bright, exactly as legacy
     `unloopfullbright` (11507) did -- `restorelighting` is the undo. ]]
function M.stopLoop() return loop:stop() end

--[[ restorelighting. The loop has to stop first: otherwise the next frame writes
     fullbright straight back over the restore, which is what legacy did if you
     ran `;rlighting` while `;loopfb` was on. Returns how many properties went
     back, plus any that could not be written. ]]
function M.restore()
	loop:stop()
	return Snapshot.restoreTag(TAG)
end

return M
