--[[═══════════════════════════════════════════════════════════════════════════
	commands/waypoints · saved positions, spawn points, flashback
	─────────────────────────────────────────────────────────────────────────
	Fifteen legacy commands (source.ref.lua 7550-7760 and 11218-11238) over two
	features: features/waypoints owns the list and the markers,
	features/spawnpoint owns the respawn hook. Nothing here keeps state beyond
	the arguments of the invocation it is running.

	Beyond the individual ports:

	  · `setwaypoint` was a command name *and* an alias of `waypointpos`, so one
	    of the two was unreachable depending on which registered last. The
	    command keeps the name and the alias is gone (noted again below).
	  · `hidewaypoints` and `nospawnpoint` are the generated off-halves of
	    `showwaypoints` and `spawnpoint`, so their names, their aliases and their
	    toggles cannot drift apart.
	  · every command that could not find the waypoint you named used to do
	    nothing at all -- no message, no error, no clue. They all answer now.
	  · teleports go through features/teleport, which stands you up out of a seat
	    first. Legacy only did that in `walktowaypoint` and `flashback`, so `;wp`
	    from a vehicle silently snapped you straight back into it.
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Cmd        = IY.import("cmd/api")
local Waypoints  = IY.import("features/waypoints")
local Spawnpoint = IY.import("features/spawnpoint")
local Teleport   = IY.import("features/teleport")
local Character  = IY.import("core/character")
local Services   = IY.import("core/services")
local Str        = IY.import("core/util/strings")
local Tbl        = IY.import("core/util/tables")

local group = Cmd.group{ category = "Waypoints" }

local LIST_LIMIT = 8   -- names shown by ;waypoints before "+n more"

-- ── shared bits ─────────────────────────────────────────────────────────────

--[[ The waypoint an argument names and where it is, or a user-facing error.
     Legacy walked both waypoint lists and simply fell off the end when the name
     matched neither. ]]
local function resolve(ctx, name)
	local entry = Waypoints.find(name)
	if not entry then
		ctx:fail("no waypoint called '%s' here (%d saved)",
			tostring(name), #Waypoints.names())
	end
	local cframe = Waypoints.cframeOf(entry)
	if not cframe then
		ctx:fail("'%s' follows a part that is no longer in the game", entry.name)
	end
	return entry, cframe
end

local function describePosition(cframe)
	local position = cframe.Position
	return string.format("%.1f, %.1f, %.1f", position.X, position.Y, position.Z)
end

--[[ Legacy set `Humanoid.WalkToPoint` and hoped: you walked into the first wall
     between you and the waypoint, forever, in silence. Pathfind when the service
     is available, fall back to the straight line when it is not, and say what
     went wrong when there is no route.

     This walks the route once and returns. features/walkto owns the other shape
     of the same idea -- the follow-forever loop behind `;pathfindwalktowaypoint`
     and `;walkto` -- which is why this does not call into it. ]]
local function walkTo(position, label)
	local humanoid = Character.requireHumanoid()
	local pathfinding = Services.get("PathfindingService")
	if not pathfinding then
		humanoid.WalkToPoint = position
		return true
	end

	local path = pathfinding:CreatePath()
	local computed = pcall(function()
		path:ComputeAsync(Character.requireRoot().Position, position)
	end)
	if not computed or path.Status ~= Enum.PathStatus.Success then
		return false, string.format("no path found to %s", label)
	end

	local points = path:GetWaypoints()
	for i = 1, #points do
		local current = Character.humanoid()
		if not current then
			return false, string.format("you lost your character on the way to %s", label)
		end
		if points[i].Action == Enum.PathWaypointAction.Jump then current.Jump = true end
		current:MoveTo(points[i].Position)
		-- MoveToFinished always fires (it gives up after 8 seconds), so this
		-- cannot hang the way legacy's `repeat wait() until distance <= 5` did
		-- when the point turned out to be unreachable.
		if not current.MoveToFinished:Wait() then
			if not Character.alive() then
				return false, string.format("you died on the way to %s", label)
			end
			return false, string.format("the way to %s is blocked", label)
		end
	end
	return true
end

-- ── saving ──────────────────────────────────────────────────────────────────

group{
	name = "setwaypoint",
	--[[ `setwaypoint` was this command's name *and* an alias of `waypointpos`.
	     The name wins; the alias is dropped from waypointpos below. ]]
	aliases = { "swp", "setwp", "spos", "saveposition", "savepos" },
	description = "Saves where you are standing as a waypoint.",
	args = {
		{ name = "name", type = "text" },
	},
	examples = { "setwaypoint base", "swp under the bridge" },
	requires = { root = true },
	run = function(ctx)
		local position = Character.requireRoot().Position
		-- Legacy floored the coordinates on the way in; kept so a file written
		-- here looks like one written by the old script.
		local cframe = CFrame.new(math.floor(position.X), math.floor(position.Y),
			math.floor(position.Z))
		local entry, replaced = Waypoints.add(ctx.args.name, cframe)
		ctx:notify("Modified Waypoints",
			(replaced and "Replaced waypoint: " or "Created waypoint: ") .. entry.name)
	end,
}

--[[ Three legacy fixes here. The name came from getstring(1), which takes the
     *rest of the line*, so `;waypointpos tower 120 45 -8` saved a waypoint
     called "tower 120 45 -8" -- quote a name with spaces instead. The
     coordinates went to disk as the strings you typed. And it required a
     character for no reason, so you could not save a coordinate while dead. ]]
group{
	name = "waypointpos",
	aliases = { "wpp", "setwaypointposition", "setpos", "setwaypointpos" },
	description = "Saves a waypoint at the coordinates you give.",
	args = {
		{ name = "name", type = "string" },
		{ name = "x", type = "number" },
		{ name = "y", type = "number" },
		{ name = "z", type = "number" },
	},
	examples = { "waypointpos tower 120 45 -8", 'waypointpos "top floor" 0 200 0' },
	run = function(ctx)
		local entry, replaced = Waypoints.add(ctx.args.name,
			CFrame.new(ctx.args.x, ctx.args.y, ctx.args.z))
		ctx:notify("Modified Waypoints",
			(replaced and "Replaced waypoint: " or "Created waypoint: ") .. entry.name)
	end,
}

-- ── listing and markers ─────────────────────────────────────────────────────

--[[ Legacy opened the waypoints panel. The interface is a separate pack and
     builds its own list from Waypoints.changed, so this answers the question
     directly rather than depending on the UI being up at all. ]]
group{
	name = "waypoints",
	aliases = { "positions" },
	description = "Lists the waypoints saved for this place.",
	examples = { "waypoints" },
	run = function(ctx)
		local names = Waypoints.names()
		if #names == 0 then
			ctx:notify("Waypoints", "Nothing saved here yet -- try ;setwaypoint <name>")
			return
		end
		local shown = Tbl.slice(names, 1, LIST_LIMIT)
		local text = table.concat(shown, ", ")
		if #names > #shown then
			text = text .. " (+" .. tostring(#names - #shown) .. " more)"
		end
		ctx:notify("Waypoints", Str.pluralise(#names, "waypoint") .. ": " .. text)
	end,
}

group{
	name = "showwaypoints",
	aliases = { "showwp", "showwps" },
	description = "Shows a labelled marker at every waypoint in this place.",
	examples = { "showwaypoints", "hidewaypoints" },
	offAliases = { "hidewaypoints", "hidewp", "hidewps" },
	offDescription = "Removes the waypoint markers.",
	run = function(ctx)
		local shown = Waypoints.showMarkers()
		if ctx:quiet() then return end
		if shown == 0 then
			ctx:reply("Nothing to mark here yet -- markers appear as you save waypoints")
		else
			ctx:reply("Showing " .. Str.pluralise(shown, "waypoint marker"))
		end
	end,
	off = function(ctx)
		Waypoints.hideMarkers()
		if not ctx:quiet() then ctx:reply("Waypoint markers hidden") end
	end,
}

-- ── travelling ──────────────────────────────────────────────────────────────

group{
	name = "waypoint",
	aliases = { "wp", "lpos", "loadposition", "loadpos" },
	description = "Teleports you to a saved waypoint.",
	args = {
		{ name = "name", type = "waypoint" },
	},
	examples = { "waypoint base", "wp ba" },
	requires = { root = true },
	run = function(ctx)
		local entry, cframe = resolve(ctx, ctx.args.name)
		Teleport.to(cframe, { unseat = true })
		if not ctx:quiet() then ctx:reply("Teleported to " .. entry.name) end
	end,
}

--[[ Legacy `tweenSpeed` went straight into TweenInfo.new, so it has always been
     a duration in seconds despite the name. features/teleport reads the same
     setting for its own tweening commands. ]]
group{
	name = "tweenspeed",
	aliases = { "tspeed" },
	description = "Sets how long a tween takes, in seconds.",
	args = {
		{ name = "seconds", type = "time", default = 1, min = 0, max = 300 },
	},
	examples = { "tweenspeed 0.5", "tspeed 3" },
	run = function(ctx)
		local value = Waypoints.setTweenSpeed(ctx.args.seconds)
		ctx:reply("Tween time set to " .. tostring(value) .. "s")
	end,
}

group{
	name = "tweenwaypoint",
	aliases = { "twp" },
	description = "Slides you to a waypoint over the tween time.",
	args = {
		{ name = "name", type = "waypoint" },
	},
	examples = { "tweenwaypoint base", "tweenspeed 5 \\ twp base" },
	requires = { root = true },
	run = function(ctx)
		local entry, cframe = resolve(ctx, ctx.args.name)
		Teleport.to(cframe, { tween = Waypoints.tweenSpeed, unseat = true })
		if not ctx:quiet() then ctx:reply("Tweening to " .. entry.name) end
	end,
}

group{
	name = "walktowaypoint",
	aliases = { "wtwp" },
	description = "Walks you to a waypoint instead of teleporting.",
	args = {
		{ name = "name", type = "waypoint" },
	},
	examples = { "walktowaypoint base" },
	requires = { root = true, alive = true },
	singleton = true,   -- two walks at once fought over the same humanoid
	run = function(ctx)
		local entry, cframe = resolve(ctx, ctx.args.name)
		Teleport.unseat()
		local ok, reason = walkTo(cframe.Position, entry.name)
		if not ok then ctx:fail("%s", reason) end
	end,
}

-- ── deleting ────────────────────────────────────────────────────────────────

group{
	name = "deletewaypoint",
	aliases = { "dwp", "dpos", "deleteposition", "deletepos" },
	description = "Deletes one saved waypoint.",
	args = {
		{ name = "name", type = "waypoint" },
	},
	examples = { "deletewaypoint base" },
	run = function(ctx)
		local entry = Waypoints.find(ctx.args.name)
		if not entry then
			ctx:fail("no waypoint called '%s' here", tostring(ctx.args.name))
		end
		Waypoints.remove(entry.name)
		ctx:notify("Modified Waypoints", "Deleted waypoint: " .. entry.name)
	end,
}

group{
	name = "clearwaypoints",
	aliases = { "cwp", "clearpositions", "cpos", "clearpos" },
	description = "Deletes every waypoint you have saved, in every game.",
	examples = { "clearwaypoints" },
	run = function(ctx)
		local removed = Waypoints.clearAll()
		ctx:notify("Modified Waypoints",
			"Removed " .. Str.pluralise(removed, "waypoint") .. " from every game")
	end,
}

--[[ The two names are the wrong way round and always have been: it is
     `clearwaypoints` that wipes every game and `cleargamewaypoints` that stops
     at this one. Kept, because every guide out there says so. ]]
group{
	name = "cleargamewaypoints",
	aliases = { "cgamewp" },
	description = "Deletes the waypoints saved for this game only.",
	examples = { "cleargamewaypoints" },
	run = function(ctx)
		local removed = Waypoints.clear()
		ctx:notify("Modified Waypoints",
			"Deleted " .. Str.pluralise(removed, "waypoint") .. " saved for this game")
	end,
}

-- ── spawn point and flashback ───────────────────────────────────────────────

group{
	name = "spawnpoint",
	aliases = { "spawn" },
	description = "Puts you back on this spot every time you respawn.",
	args = {
		{ name = "delay", type = "time", default = 0.1, min = 0, max = 30 },
	},
	examples = { "spawnpoint", "spawnpoint 0.5", "nospawnpoint" },
	requires = { root = true },
	offArgs = {},
	offAliases = { "nospawn", "removespawnpoint" },
	offDescription = "Stops putting you back on your spawn point.",
	run = function(ctx)
		local cframe = Character.requireRoot().CFrame
		-- The generated togglespawnpoint takes no arguments, so the delay can be
		-- absent here; the feature owns the legacy 0.1s default.
		Spawnpoint.start{ cframe = cframe, delay = ctx.args.delay }
		ctx:notify("Spawn Point", "Spawn point created at " .. describePosition(cframe))
	end,
	off = function(ctx)
		Spawnpoint.stop()
		ctx:notify("Spawn Point", "Removed spawn point")
	end,
}

group{
	name = "flashback",
	aliases = { "diedtp" },
	description = "Teleports you to where you last died.",
	examples = { "flashback" },
	requires = { root = true },
	run = function(ctx)
		local point = Character.lastDeath
		-- Legacy did nothing at all when you had not died yet.
		if not point then
			ctx:fail("you have not died since IY loaded, so there is nowhere to go back to")
		end
		Teleport.to(point, { unseat = true })
		if not ctx:quiet() then ctx:reply("Teleported to your last death") end
	end,
}

return true
