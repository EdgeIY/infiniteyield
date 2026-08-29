--[[═══════════════════════════════════════════════════════════════════════════
	commands/clickactions · mouse-driven teleports, and the two walk hacks
	─────────────────────────────────────────────────────────────────────────
	clickteleport / clickdelete are toggles sharing one Button1Down connection
	(features/clicktp); mouseteleport, clicktp and clickdel are the one-shot
	forms; tptool is the same hop wrapped in a Tool. teleportwalk and walltp
	round out the "move in a way you shouldn't be able to" set.

	Legacy equivalent: source.ref.lua 6265-6310, 10308-10347, 12067-12094 and
	12217-12243.

	`clickteleport` and `clickdelete` did nothing in the legacy script except
	print "Go to Settings > Keybinds > Add to set up click teleport" -- the work
	only happened if you bound a key, and then it ran off the keybind system's
	own click handler. They are real toggles here; `clicktp` and `clickdel` stay
	as hidden one-shots so keybinds saved against those names still work.
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Cmd          = IY.import("cmd/api")
local ClickTP      = IY.import("features/clicktp")
local TeleportWalk = IY.import("features/teleportwalk")
local WallTP       = IY.import("features/walltp")

local group = Cmd.group{ category = "Teleport" }

-- ── click modes ─────────────────────────────────────────────────────────────

group{
	name = "clickteleport",
	description = "While on, left-clicking teleports you to where you clicked.",
	examples = { "clickteleport", "unclickteleport" },
	run = function(ctx)
		ClickTP.setMode("teleport", true)
		if not ctx:quiet() then ctx:notify("Click TP", "Left click to teleport there") end
	end,
	off = function(ctx)
		ClickTP.setMode("teleport", false)
		if not ctx:quiet() then ctx:notify("Click TP", "Click teleport disabled") end
	end,
}

group{
	name = "clickdelete",
	description = "While on, left-clicking deletes whatever you clicked.",
	examples = { "clickdelete", "unclickdelete" },
	run = function(ctx)
		ClickTP.setMode("delete", true)
		if not ctx:quiet() then ctx:notify("Click Delete", "Left click to delete") end
	end,
	off = function(ctx)
		ClickTP.setMode("delete", false)
		if not ctx:quiet() then ctx:notify("Click Delete", "Click delete disabled") end
	end,
}

-- ── one-shots ───────────────────────────────────────────────────────────────

group{
	name = "mouseteleport",
	aliases = { "mousetp" },
	description = "Teleports you once to wherever your mouse is pointing.",
	examples = { "mousetp" },
	requires = { root = true },
	run = function() ClickTP.teleport() end,
}

--[[ Keybinds saved by older versions point at the literal command names
     `clicktp` and `clickdel` (the panels at source.ref.lua 6241 and 6254 called
     `addbind('clicktp', key, ...)`). The new keybind system executes a command
     line, so those two names have to resolve to real commands. Hidden, because
     `clickteleport` and `mouseteleport` are the names to type. ]]
group{
	name = "clicktp",
	description = "Teleports you once to wherever your mouse is pointing.",
	hidden = true,
	requires = { root = true },
	run = function() ClickTP.teleport() end,
}

group{
	name = "clickdel",
	description = "Deletes whatever your mouse is pointing at.",
	hidden = true,
	run = function() ClickTP.deleteTarget() end,
}

group{
	name = "tptool",
	aliases = { "teleporttool" },
	description = "Gives you a tool that teleports you to wherever you click.",
	examples = { "tptool", "untptool" },
	run = function(ctx)
		ClickTP.tool:start()
		if not ctx:quiet() then ctx:notify("Teleport Tool", "Added to your backpack") end
	end,
	off = function(ctx)
		ClickTP.tool:stop()
		if not ctx:quiet() then ctx:notify("Teleport Tool", "Removed from your backpack") end
	end,
}

-- ── walking ─────────────────────────────────────────────────────────────────

group{
	name = "teleportwalk",
	aliases = { "tpwalk" },
	description = "Moves you in short hops instead of walking.",
	args = {
		{ name = "speed", type = "number",  default = 1, min = 0 },
		{ name = "stack", type = "boolean", default = false },
	},
	examples = { "tpwalk", "tpwalk 3", "tpwalk 3 true" },
	requires = { character = true },
	offAliases = { "untpwalk", "notpwalk" },
	offArgs = {},
	run = function(ctx)
		-- `stack` adds this speed on top of the running total, matching the
		-- legacy tpwalkStack global; stopping resets it.
		TeleportWalk.start({ speed = ctx.args.speed, stack = ctx.args.stack })
	end,
	off = function() TeleportWalk.stop() end,
}

group{
	name = "walltp",
	description = "Puts you on top of anything you walk into.",
	examples = { "walltp", "unwalltp" },
	requires = { character = true },
	run = function(ctx)
		WallTP.start()
		if not ctx:quiet() then ctx:reply("Wall teleport enabled") end
	end,
	off = function(ctx)
		WallTP.stop()
		if not ctx:quiet() then ctx:reply("Wall teleport disabled") end
	end,
}

return true
