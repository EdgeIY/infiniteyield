--[[═══════════════════════════════════════════════════════════════════════════
	commands/watch · rolewatch and staffwatch
	─────────────────────────────────────────────────────────────────────────
	rolewatch, rolewatchstop, rolewatchleave, staffwatch and unstaffwatch.

	Legacy equivalent: source.ref.lua 12427-12513. features/watch owns both join
	connections; nothing here holds state.

	One alias is deliberately re-pointed. Legacy `rolewatchleave` carried the
	alias `unrolewatch` (12458), so `;unrolewatch` toggled *kick-on-detect* and
	left the watch running -- the opposite of what `un<name>` means everywhere
	else in the command set, and the reason "rolewatch won't turn off" was a
	recurring report. `unrolewatch` now stops rolewatch, alongside the generated
	`norolewatch` and legacy's own `rolewatchstop`; `rolewatchleave` keeps its
	canonical name and does what it says.
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Cmd   = IY.import("cmd/api")
local Watch = IY.import("features/watch")

local group = Cmd.group{ category = "Server" }

-- ── rolewatch ───────────────────────────────────────────────────────────────

group{
	name = "rolewatch",
	description = "Warns you when somebody with a given group role joins.",
	args = {
		-- `min = 1` where legacy took `tonumber(args[1] or 0)`: zero was its
		-- "watch nothing" sentinel, so `;rolewatch 0 admin` armed a watch that
		-- could never fire and still reported that it was watching.
		{ name = "group", type = "integer", min = 1 },
		{ name = "role",  type = "text" },
	},
	examples = { "rolewatch 1200769 Roblox Employee", "rolewatchstop" },
	-- The watch needs both arguments to start, so a generated toggle could never
	-- turn it back on.
	toggle = false,
	offArgs = {},
	offAliases = { "rolewatchstop" },
	offDescription = "Stops rolewatch and clears the leave setting.",
	run = function(ctx)
		Watch.startRolewatch(ctx.args.group, ctx.args.role)
		ctx:notify("Rolewatch", "Watching Group ID \"" .. tostring(ctx.args.group)
			.. "\" for Role \"" .. ctx.args.role .. "\"")
	end,
	off = function(ctx)
		Watch.stopRolewatch()
		ctx:notify("Rolewatch", "Disabled")
	end,
}

group{
	name = "rolewatchleave",
	description = "Makes rolewatch leave the server instead of notifying you.",
	args = {
		-- Legacy flipped the flag with no way to set it explicitly; omitting the
		-- argument still flips it.
		{ name = "enabled", type = "boolean", optional = true },
	},
	examples = { "rolewatchleave", "rolewatchleave off" },
	toggle = false,
	run = function(ctx)
		local leaving = Watch.setLeave(ctx.args.enabled)
		ctx:notify("Rolewatch",
			leaving and "Leave has been Enabled" or "Leave has been Disabled")
	end,
}

-- ── staffwatch ──────────────────────────────────────────────────────────────

group{
	name = "staffwatch",
	description = "Warns you when a member of the game group's staff joins.",
	examples = { "staffwatch", "unstaffwatch" },
	run = function(ctx)
		Watch.startStaffwatch()
		-- Legacy reported the staff already in the server and fell back to
		-- "Enabled" when there were none (12498-12502).
		local found = Watch.scanStaff()
		if #found > 0 then
			ctx:notify("Staffwatch", table.concat(found, ",\n"))
		else
			ctx:notify("Staffwatch", "Enabled")
		end
	end,
	off = function(ctx)
		Watch.stopStaffwatch()
		ctx:notify("Staffwatch", "Disabled")
	end,
}

return true
