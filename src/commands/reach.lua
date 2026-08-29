--[[═══════════════════════════════════════════════════════════════════════════
	commands/reach · reach, boxreach, grippos
	─────────────────────────────────────────────────────────────────────────
	Legacy equivalent: source.ref.lua 11642-11714.

	`reach` and `boxreach` are two shapes of one feature, so only `reach`
	declares `off`: the generated `unreach` (aliases `noreach`, `unboxreach`)
	turns either of them off. Legacy opened both commands with
	`execCmd('unreach')` followed by a bare `wait()`; `Feature:start` already
	stops a running instance first, so switching shape restores the old geometry
	before the new one is recorded, without the race.
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Cmd   = IY.import("cmd/api")
local Reach = IY.import("features/reach")
local Tools = IY.import("features/tools")

local group = Cmd.group{ category = "Tools" }

group{
	name = "reach",
	description = "Stretches your tool handles into a spear so they hit things far away.",
	args = {
		{ name = "size", type = "number", default = 60, min = 0.05, max = 2048 },
	},
	examples = { "reach", "reach 120", "unreach" },
	requires = { character = true, tool = true },
	offAliases = { "unboxreach" },
	offArgs = {},
	offDescription = "Puts every reached tool back to its original size and grip.",
	run = function(ctx)
		Reach.start{ size = ctx.args.size }
		if not ctx:quiet() then
			-- Size from the feature, not from ctx.args: `togglereach` is generated
			-- with no arguments of its own.
			ctx:reply(string.format("Reach %s studs on %d tool(s)",
				tostring(Reach.size()), Reach.count()))
		end
	end,
	off = function(ctx)
		Reach.stop()
		if not ctx:quiet() then ctx:reply("Reach disabled") end
	end,
}

group{
	name = "boxreach",
	description = "Reach, but the handle becomes a cube -- it hits in every direction.",
	args = {
		{ name = "size", type = "number", default = 60, min = 0.05, max = 2048 },
	},
	examples = { "boxreach", "boxreach 25", "unboxreach" },
	requires = { character = true, tool = true },
	-- No `off` of its own: `unreach` owns both shapes, and generating
	-- `unboxreach` here would collide with the alias reach already claims.
	run = function(ctx)
		Reach.start{ size = ctx.args.size, box = true }
		if not ctx:quiet() then
			ctx:reply(string.format("Box reach %s studs on %d tool(s)",
				tostring(Reach.size()), Reach.count()))
		end
	end,
}

group{
	name = "grippos",
	description = "Moves where your character holds its tools.",
	args = {
		{ name = "position", type = "vector3", default = "0,0,0" },
	},
	examples = { "grippos 0,0,0", "grippos 0,-1,-2" },
	requires = { character = true, tool = true },
	run = function(ctx)
		local changed = Tools.setGrip(ctx.speaker:requirePlayer(), ctx.args.position)
		if not ctx:quiet() then
			ctx:reply(string.format("Set the grip of %d tool(s)", changed))
		end
	end,
}

return true
