--[[═══════════════════════════════════════════════════════════════════════════
	commands/lighting · fullbright, time of day, fog, shadows, restore
	─────────────────────────────────────────────────────────────────────────
	fullbright, loopfullbright, ambient, day, night, nofog, brightness,
	globalshadows and restorelighting. Every property write is in
	features/lighting, which routes them through core/snapshot under the
	"lighting" tag -- so `restorelighting` is a tag restore and `;unloadiy`
	restores lighting whether or not anyone ran it.

	Legacy equivalent: source.ref.lua 11484-11557, eleven `addcmd` blocks, a
	module-level `brightLoop` connection and the load-time `origsettings` table.

	Argument typing changed two of these for the better:
	  · `;brightness` with no argument assigned nil (11536) and threw. It has a
	    default and a range now.
	  · `;ambient` read args[1..3] as strings (11514) and `;ambient` alone threw
	    the same way. It takes one colour argument.
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Cmd      = IY.import("cmd/api")
local Lighting = IY.import("features/lighting")
local Str      = IY.import("core/util/strings")

local group = Cmd.group{ category = "Lighting" }

local function say(ctx, text)
	if not ctx:quiet() then ctx:reply(text) end
end

local function clamp01(value)
	if value < 0 then return 0 end
	if value > 1 then return 1 end
	return value
end

--[[ `;ambient 1 1 1` is the legacy 0-1 form and `;ambient 128 128 128` is what
     people type when they mean bytes, so anything above 1 is read as 0-255. The
     argument is `vector3` rather than `color` because the colour type parses one
     token and the legacy spelling is three space-separated numbers; vector3
     accepts both `1 1 1` and `1,1,1`. ]]
local function colourFrom(vector)
	local r, g, b = vector.X, vector.Y, vector.Z
	if r > 1 or g > 1 or b > 1 then
		r, g, b = r / 255, g / 255, b / 255
	end
	return Color3.new(clamp01(r), clamp01(g), clamp01(b))
end

-- ── fullbright ──────────────────────────────────────────────────────────────

group{
	name = "fullbright",
	aliases = { "fb", "fullbrightness" },
	description = "Brightens the whole map: midday sun, no shadows, no fog.",
	examples = { "fullbright", "restorelighting" },
	-- A one-shot, as in legacy: there is no `unfullbright`, because the way back
	-- is `restorelighting`, which puts every recorded property back at once.
	run = function(ctx)
		Lighting.fullbright()
		say(ctx, "Fullbright applied")
	end,
}

group{
	name = "loopfullbright",
	aliases = { "loopfb" },
	description = "Re-applies fullbright every frame, for games that fight it.",
	examples = { "loopfullbright", "unloopfb" },
	offAliases = { "unloopfb" },
	run = function(ctx)
		Lighting.startLoop()
		say(ctx, "Looping fullbright on")
	end,
	off = function(ctx)
		Lighting.stopLoop()
		say(ctx, "Looping fullbright off (`;restorelighting` puts the lighting back)")
	end,
}

-- ── individual properties ───────────────────────────────────────────────────

group{
	name = "ambient",
	description = "Sets the indoor and outdoor ambient light colour.",
	args = {
		{ name = "colour", type = "vector3", greedy = true },
	},
	examples = { "ambient 1 1 1", "ambient 0 0 0", "ambient 128,128,128" },
	run = function(ctx)
		local colour = colourFrom(ctx.args.colour)
		Lighting.ambient(colour)
		say(ctx, string.format("Ambient set to %d, %d, %d",
			colour.R * 255, colour.G * 255, colour.B * 255))
	end,
}

group{
	name = "day",
	description = "Sets the time of day to midday.",
	examples = { "day" },
	run = function(ctx)
		Lighting.clockTime(14)
		say(ctx, "Time set to day")
	end,
}

group{
	name = "night",
	description = "Sets the time of day to midnight.",
	examples = { "night" },
	run = function(ctx)
		Lighting.clockTime(0)
		say(ctx, "Time set to night")
	end,
}

group{
	name = "nofog",
	description = "Pushes fog out of sight and flattens any Atmosphere haze.",
	examples = { "nofog", "restorelighting" },
	-- Legacy destroyed every Atmosphere instance (11530), which `restorelighting`
	-- could never undo. features/lighting zeroes Density, Haze and Glare instead
	-- and records all three, so the game's own atmosphere comes back.
	run = function(ctx)
		local atmospheres = Lighting.noFog()
		if ctx:quiet() then return end
		if atmospheres > 0 then
			ctx:reply(string.format("Fog cleared (%s flattened)",
				Str.pluralise(atmospheres, "Atmosphere")))
		else
			ctx:reply("Fog cleared")
		end
	end,
}

group{
	name = "brightness",
	description = "Sets how bright the map's light sources are.",
	args = {
		-- Lighting.Brightness is a 0-10 property; 2 is the value fullbright uses.
		{ name = "level", type = "number", default = 2, min = 0, max = 10 },
	},
	examples = { "brightness", "brightness 5", "brightness 0" },
	run = function(ctx)
		Lighting.brightness(ctx.args.level)
		say(ctx, "Brightness set to " .. tostring(ctx.args.level))
	end,
}

group{
	name = "globalshadows",
	aliases = { "gshadows" },
	description = "Turns the map's shadows on.",
	examples = { "globalshadows", "unglobalshadows" },
	offAliases = { "nogshadows", "ungshadows" },
	run = function(ctx)
		Lighting.globalShadows(true)
		say(ctx, "Global shadows on")
	end,
	off = function(ctx)
		Lighting.globalShadows(false)
		say(ctx, "Global shadows off")
	end,
}

-- ── restore ─────────────────────────────────────────────────────────────────

group{
	name = "restorelighting",
	aliases = { "rlighting" },
	description = "Puts every lighting property this pack changed back.",
	examples = { "restorelighting" },
	run = function(ctx)
		-- Stops loopfullbright first: otherwise the next frame writes fullbright
		-- straight back over the restore.
		local restored, failures = Lighting.restore()
		if ctx:quiet() then return end
		if restored == 0 and #failures == 0 then
			ctx:reply("Lighting was already untouched")
			return
		end
		ctx:reply(string.format("Restored %s%s",
			Str.pluralise(restored, "lighting property", "lighting properties"),
			#failures > 0 and (", " .. #failures .. " could not be written") or ""))
	end,
}

return true
