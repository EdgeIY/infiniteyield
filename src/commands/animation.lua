--[[═══════════════════════════════════════════════════════════════════════════
	commands/animation · dances, emotes, custom tracks, the Animate script
	─────────────────────────────────────────────────────────────────────────
	Seventeen commands that all reach for the same two objects -- the Animator
	and the `Animate` script -- and in the legacy set each of them reached alone,
	with its own globals and its own missing nil checks. Everything stateful in
	this pack lives in features/animation, which owns every AnimationTrack IY
	creates; this file only parses arguments and reports.

	Legacy equivalent: source.ref.lua 9835-9851, 10099-10129, 10141-10274.
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Cmd       = IY.import("cmd/api")
local Animation = IY.import("features/animation")
local Env       = IY.import("core/env")
local Guard     = IY.import("core/guard")
local Services  = IY.import("core/services")

local group = Cmd.group{ category = "Animation" }

-- The default Animate script's own ids. Copying them back onto yourself does
-- nothing useful, so both copy commands skip them, exactly as legacy did.
local SKIP_IDS = { "507768375", "180435571" }

local function skipped(id)
	for i = 1, #SKIP_IDS do
		if string.find(id, SKIP_IDS[i], 1, true) then return true end
	end
	return false
end

--[[ `track.Animation` is nil for tracks the engine owns, which is what made the
     legacy `v1.Animation.AnimationId` (10186, 10205) throw halfway through a
     copy and abandon the rest. ]]
local function trackId(track)
	local id = Guard.try(function() return track.Animation.AnimationId end)
	if type(id) == "string" and id ~= "" then return id end
	return nil
end

local function productName(assetId)
	local marketplace = Services.get("MarketplaceService")
	if not marketplace then return nil end
	return Guard.try(function()
		return marketplace:GetProductInfo(tonumber(assetId)).Name
	end)
end

-- ── dance / spasm / headthrow ───────────────────────────────────────────────

group{
	name = "dance",
	description = "Plays a random dance animation on a loop.",
	examples = { "dance", "undance" },
	requires = { character = true },
	run = function(ctx)
		Animation.dance:start({})
		if not ctx:quiet() then ctx:reply("Dancing") end
	end,
	off = function(ctx)
		Animation.dance:stop()
		if not ctx:quiet() then ctx:reply("Stopped dancing") end
	end,
}

group{
	name = "spasm",
	description = "Plays a dance animation at 99x speed. Needs an R6 rig.",
	examples = { "spasm", "unspasm" },
	requires = { character = true },
	run = function(ctx)
		Animation.spasm:start()
		if not ctx:quiet() then ctx:reply("Spasming") end
	end,
	off = function(ctx)
		Animation.spasm:stop()
		if not ctx:quiet() then ctx:reply("Stopped spasming") end
	end,
}

group{
	name = "headthrow",
	description = "Plays the head-throw animation. Needs an R6 rig.",
	examples = { "headthrow" },
	requires = { character = true },
	run = function(ctx)
		Animation.headthrow:start()
	end,
}

-- ── playing an id ───────────────────────────────────────────────────────────

group{
	name = "animation",
	aliases = { "anim" },
	description = "Plays an animation id on your character.",
	args = {
		{ name = "id",    type = "string" },
		{ name = "speed", type = "number", optional = true, min = 0 },
	},
	examples = { "animation 27789359", "anim 27789359 2" },
	requires = { character = true },
	run = function(ctx)
		Animation.play(ctx.args.id, {
			speed    = ctx.args.speed,
			priority = Enum.AnimationPriority.Movement,
			resolve  = true,
		})
	end,
}

group{
	name = "loopanimation",
	aliases = { "loopanim" },
	description = "Loops an animation id, or loops whatever you are playing now.",
	args = {
		{ name = "id",    type = "string", optional = true },
		{ name = "speed", type = "number", optional = true, min = 0 },
	},
	examples = { "loopanimation 27789359", "loopanim", "unloopanim" },
	requires = { character = true },
	offAliases = { "unloopanim" },
	offArgs = {},
	run = function(ctx)
		Animation.loopanimation:start({ id = ctx.args.id, speed = ctx.args.speed })
	end,
	off = function(ctx)
		Animation.loopanimation:stop()
		if not ctx:quiet() then ctx:reply("Stopped looping") end
	end,
}

group{
	name = "emote",
	aliases = { "em" },
	description = "Plays one of your equipped emotes by its id.",
	args = {
		{ name = "id",    type = "integer" },
		{ name = "speed", type = "number", optional = true, min = 0 },
	},
	examples = { "emote 3576686446", "em 3576686446 2" },
	requires = { character = true, alive = true },
	run = function(ctx)
		Animation.emote(ctx.args.id, ctx.args.speed)
	end,
}

-- ── speed, stopping, refreshing ─────────────────────────────────────────────

group{
	name = "animspeed",
	description = "Sets the speed of every animation playing on you.",
	args = {
		{ name = "speed", type = "number", default = 1, min = 0 },
	},
	examples = { "animspeed 2", "animspeed 0.5" },
	requires = { character = true },
	run = function(ctx)
		local count = Animation.setSpeed(ctx.args.speed)
		if not ctx:quiet() then
			ctx:reply(string.format("Animation speed %s on %d track(s)",
				tostring(ctx.args.speed), count))
		end
	end,
}

group{
	name = "stopanimations",
	aliases = { "stopanims", "stopanim" },
	description = "Stops every animation playing on you.",
	examples = { "stopanimations" },
	requires = { character = true },
	run = function(ctx)
		-- Ours first so their handles go, then the sweep legacy did over
		-- everything the humanoid is playing.
		Animation.stopAll()
		local count = Animation.stopPlaying()
		if not ctx:quiet() then
			ctx:reply(string.format("Stopped %d animation(s)", count))
		end
	end,
}

group{
	name = "refreshanimations",
	aliases = { "refreshanimation", "refreshanims", "refreshanim" },
	description = "Restarts your Animate script so it reloads its animations.",
	examples = { "refreshanimations" },
	requires = { character = true },
	run = function(ctx)
		Animation.refresh()
		if not ctx:quiet() then ctx:reply("Animations refreshed") end
	end,
}

-- ── the Animate script ──────────────────────────────────────────────────────

group{
	name = "noanim",
	description = "Disables your Animate script, so your character stops animating.",
	examples = { "noanim", "reanim" },
	requires = { character = true },
	-- `reanim` was a separate legacy command (10165); as the off-handler it stays
	-- a name people can type while sharing one restore path.
	offAliases = { "reanim" },
	offDescription = "Re-enables your Animate script.",
	offRequires = { character = true },
	run = function(ctx)
		Animation.setAnimateDisabled(true)
		if not ctx:quiet() then ctx:reply("Animate script disabled") end
	end,
	off = function(ctx)
		Animation.setAnimateDisabled(false)
		if not ctx:quiet() then ctx:reply("Animate script enabled") end
	end,
}

group{
	name = "allowcustomanim",
	aliases = { "allowcustomanimations" },
	description = "Lets your character use custom animations in this game.",
	examples = { "allowcustomanim", "unallowcustomanim" },
	requires = { character = true, capability = "sethiddenproperty" },
	offAliases = { "unallowcustomanimations" },
	offRequires = { character = true, capability = "sethiddenproperty" },
	run = function(ctx)
		Animation.setAllowCustom(true)
		if not ctx:quiet() then ctx:reply("Custom animations allowed") end
	end,
	off = function(ctx)
		Animation.setAllowCustom(false)
		if not ctx:quiet() then ctx:reply("Custom animations disallowed") end
	end,
}

-- ── copying what someone else is playing ────────────────────────────────────

--[[ Only `copyanimationid` touches the clipboard, so only it is gated on that
     capability -- `copyanimation` mimics the player on your own rig and works
     on any executor, which is what legacy did (10178-10198). ]]
group{
	name = "copyanimation",
	aliases = { "copyanim", "copyemote" },
	description = "Plays whatever animations a player is playing, on you.",
	args = {
		{ name = "players", type = "players" },
	},
	examples = { "copyanimation bob", "copyemote bob" },
	requires = { character = true },
	run = function(ctx)
		--[[ Hoisted out of the target loop: legacy stopped your own tracks once
		     per target (10182), so with more than one target every copy but the
		     last was wiped by the following iteration. ]]
		Animation.stopAll()
		Animation.stopPlaying()

		local copied = 0
		ctx:each(function(target)
			local tracks = Animation.playingTracks(target:requireCharacter())
			for i = 1, #tracks do
				local track = tracks[i]
				local id = trackId(track)
				if id and not skipped(id) then
					local handle = Animation.play(id, {
						fade         = 0.1,
						weight       = 1,
						speed        = Guard.try(function() return track.Speed end),
						timePosition = Guard.try(function() return track.TimePosition end),
					})
					-- Ours ends when theirs does.
					Animation.follow(handle, track)
					copied = copied + 1
				end
			end
		end)

		if copied == 0 then ctx:fail("they are not playing anything to copy") end
		if not ctx:quiet() then
			ctx:reply(string.format("Copied %d animation(s)", copied))
		end
	end,
}

group{
	name = "copyanimationid",
	aliases = { "copyanimid", "copyemoteid" },
	description = "Copies the ids of the animations a player is playing to your clipboard.",
	args = {
		{ name = "players", type = "players", optional = true },
	},
	examples = { "copyanimationid", "copyanimid bob" },
	requires = { capability = "setclipboard" },
	run = function(ctx)
		local report = { "Animations Copied" }
		ctx:each(function(target)
			local tracks = Animation.playingTracks(target.character)
			for i = 1, #tracks do
				local id = trackId(tracks[i])
				if id and not skipped(id) then
					local assetId = string.find(id, "rbxassetid://", 1, true) and string.match(id, "%d+")
					if assetId then
						report[#report + 1] = string.format("Name: %s\nAnimation Id: %s",
							productName(assetId) or "Failed to get name", id)
					else
						report[#report + 1] = "Animation Id: " .. id
					end
				end
			end
		end)

		if #report == 1 then
			ctx:notify("Animations", "No animations to copy")
			return
		end
		Env.fn.setclipboard(table.concat(report, "\n\n"))
		if not ctx:quiet() then
			ctx:reply(string.format("Copied %d animation id(s) to the clipboard", #report - 1))
		end
	end,
}

return true
