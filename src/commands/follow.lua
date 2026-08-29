--[[═══════════════════════════════════════════════════════════════════════════
	commands/follow · following, orbiting and looping
	─────────────────────────────────────────────────────────────────────────
	walkto / pathfindwalkto / pathfindwalktowaypoint / unwalkto, orbit,
	clientbring, loopbring and loopgoto.

	Legacy equivalent: source.ref.lua 9211-9431 and 10610-10643. Every one of
	those commands ran its own `repeat wait() ... until <module flag>` loop on
	the command thread, so none of them ever returned, `;breakloops` could not
	touch them and `;unloadiy` left them running. The loops live in
	features/walkto, features/orbit, features/loopbring and features/loopgoto
	now; this file is argument handling only.
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Cmd       = IY.import("cmd/api")
local Teleport  = IY.import("features/teleport")
local Walkto    = IY.import("features/walkto")
local Orbit     = IY.import("features/orbit")
local LoopBring = IY.import("features/loopbring")
local LoopGoto  = IY.import("features/loopgoto")
local Guard     = IY.import("core/guard")

local group = Cmd.group{ category = "Teleport" }

--[[ features/waypoints owns the saved list, the shape of a record and the
     resolution of part-backed waypoints, so ask it where the entry is. ]]
local function waypointPosition(name)
	local ok, Waypoints = pcall(function() return IY.import("features/waypoints") end)
	if not ok or not Waypoints or type(Waypoints.find) ~= "function" then
		Guard.fail("waypoints are not available")
	end
	local entry = Waypoints.find(name)
	if not entry then Guard.fail("no waypoint called '%s'", tostring(name)) end

	local value = entry
	if type(Waypoints.cframeOf) == "function" then
		value = Waypoints.cframeOf(entry)
	end
	local kind = typeof(value)
	if kind == "CFrame" then return value.Position end
	if kind == "Vector3" then return value end
	-- A part-backed waypoint whose part has been destroyed resolves to nil.
	Guard.fail("waypoint '%s' no longer has a position", tostring(name))
end

-- ── walking ─────────────────────────────────────────────────────────────────

group{
	name = "walkto",
	aliases = { "follow" },
	description = "Walks you to a player and keeps following them.",
	args = { { name = "player", type = "player" } },
	examples = { "walkto bob", "unfollow" },
	requires = { character = true },
	toggle = false,
	offAliases = { "unfollow", "nofollow" },
	offDescription = "Stops following a player or walking to a waypoint.",
	offArgs = {},
	run = function(ctx)
		ctx:assert(ctx.args.player, "who should I follow?")
		Walkto.follow(ctx.args.player)
	end,
	off = function()
		-- One feature covers all three follow commands, so this is also the off
		-- switch for pathfindwalkto and pathfindwalktowaypoint -- as `;unwalkto`
		-- was in the legacy script, where it cleared two separate flags.
		Walkto.stop()
	end,
}

group{
	name = "pathfindwalkto",
	aliases = { "pathfindfollow" },
	description = "Follows a player using pathfinding, so stairs and walls work. Stop with unwalkto.",
	args = { { name = "player", type = "player" } },
	examples = { "pathfindwalkto bob" },
	requires = { character = true },
	run = function(ctx)
		Walkto.follow(ctx.args.player, { pathfind = true })
	end,
}

group{
	name = "pathfindwalktowaypoint",
	aliases = { "pathfindwalktowp" },
	description = "Walks you to a saved waypoint using pathfinding. Stop with unwalkto.",
	args = { { name = "waypoint", type = "waypoint" } },
	examples = { "pathfindwalktowp base" },
	requires = { character = true },
	run = function(ctx)
		Walkto.walkTo(waypointPosition(ctx.args.waypoint))
	end,
}

-- ── orbit ───────────────────────────────────────────────────────────────────

group{
	name = "orbit",
	description = "Circles you around a player.",
	args = {
		{ name = "player",   type = "player" },
		{ name = "speed",    type = "number", default = 0.2, min = 0 },
		{ name = "distance", type = "number", default = 6 },
	},
	examples = { "orbit bob", "orbit bob 0.5 10" },
	requires = { root = true },
	toggle = false,
	offArgs = {},
	run = function(ctx)
		local target = ctx.args.player
		ctx:assert(target, "who should I orbit?")
		Orbit.start(target, { speed = ctx.args.speed, distance = ctx.args.distance })
		if not ctx:quiet() then
			ctx:notify("Orbit", "Started orbiting " .. target:label())
		end
	end,
	off = function(ctx)
		Orbit.stop()
		if not ctx:quiet() then ctx:notify("Orbit", "Stopped orbiting") end
	end,
}

-- ── bringing ────────────────────────────────────────────────────────────────

group{
	name = "clientbring",
	aliases = { "cbring" },
	description = "Teleports players to you -- on your client only.",
	args = { { name = "players", type = "players" } },
	examples = { "cbring bob", "cbring all" },
	requires = { root = true },
	run = function(ctx)
		ctx:each(function(target) Teleport.bring(target) end)
	end,
}

group{
	name = "loopbring",
	description = "Keeps teleporting players to you.",
	args = {
		{ name = "players",  type = "players" },
		{ name = "distance", type = "number", default = 3 },
		{ name = "delay",    type = "time",   default = 0, min = 0 },
	},
	examples = { "loopbring bob", "loopbring all 5 0.5", "unloopbring bob" },
	requires = { root = true },
	toggle = false,
	offDescription = "Stops looping players to you.",
	offArgs = { { name = "players", type = "players", default = "all" } },
	run = function(ctx)
		local added = LoopBring.add(ctx.args.players, {
			distance = ctx.args.distance,
			delay    = ctx.args.delay,
		})
		if not ctx:quiet() then
			ctx:reply("Bringing " .. tostring(added) .. " player(s)")
		end
	end,
	off = function(ctx)
		-- Legacy resolved a missing argument to the speaker, who was never in
		-- the list, so `;unloopbring` on its own did nothing at all. It now
		-- defaults to everybody.
		LoopBring.remove(ctx.args.players or {})
	end,
}

group{
	name = "loopgoto",
	description = "Keeps teleporting you to a player.",
	args = {
		{ name = "player",   type = "player" },
		{ name = "distance", type = "number", default = 3 },
		{ name = "delay",    type = "time",   default = 0, min = 0 },
	},
	examples = { "loopgoto bob", "loopgoto bob 5 0.5" },
	requires = { root = true },
	toggle = false,
	offArgs = {},
	run = function(ctx)
		ctx:assert(ctx.args.player, "who should I go to?")
		LoopGoto.start(ctx.args.player, {
			distance = ctx.args.distance,
			delay    = ctx.args.delay,
		})
	end,
	off = function()
		LoopGoto.stop()
	end,
}

return true
