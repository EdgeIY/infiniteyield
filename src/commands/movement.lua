--[[═══════════════════════════════════════════════════════════════════════════
	commands/movement · fly, noclip, float, swim
	─────────────────────────────────────────────────────────────────────────
	This pack is the reference for how every command pack is written.

	  · one `Cmd.group{}` at the top carries the shared metadata
	  · a command is a table: name, aliases, description, args, run
	  · declaring `off` generates `un<name>`, `no<name>` and `toggle<name>`
	  · all state lives in a features/* module, never in this file
	  · nothing here touches the UI, the save file, or another command's state

	Legacy equivalent: source.ref.lua lines 7055-7548, twenty `addcmd` blocks
	and eleven module-level globals.
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Cmd       = IY.import("cmd/api")
local Fly       = IY.import("features/fly")
local CFrameFly = IY.import("features/cframefly")
local Noclip    = IY.import("features/noclip")
local Float     = IY.import("features/float")
local Swim      = IY.import("features/swim")

local group = Cmd.group{ category = "Movement" }

-- Fly keeps two independent speed multipliers, matching iyflyspeed and
-- vehicleflyspeed, because a vehicle wants a very different value.
local speeds = { normal = 1, vehicle = 1 }

-- ── noclip ──────────────────────────────────────────────────────────────────

group{
	name = "noclip",
	description = "Walk through walls and floors.",
	examples = { "noclip", "togglenoclip" },
	requires = { character = true },
	offAliases = { "clip" },
	run = function(ctx)
		Noclip.start()
		if not ctx:quiet() then ctx:reply("Noclip enabled") end
	end,
	off = function(ctx)
		Noclip.stop()
		if not ctx:quiet() then ctx:reply("Noclip disabled") end
	end,
}

-- ── fly ─────────────────────────────────────────────────────────────────────

group{
	name = "fly",
	description = "Fly with your movement keys. Q and E move you down and up.",
	args = {
		{ name = "speed", type = "number", optional = true, min = 0, max = 100 },
	},
	examples = { "fly", "fly 3", "togglefly" },
	requires = { character = true },
	offAliases = { "novfly", "unvfly", "unvehiclefly", "novehiclefly" },
	offArgs = {},
	run = function(ctx)
		if ctx.args.speed then speeds.normal = ctx.args.speed end
		Fly.start{ speed = speeds.normal, vehicle = false }
	end,
	off = function()
		Fly.stop()
		CFrameFly.stop()
	end,
}

group{
	name = "flyspeed",
	aliases = { "flysp" },
	description = "Sets the fly speed multiplier.",
	args = {
		{ name = "speed", type = "number", default = 1, min = 0, max = 100 },
	},
	run = function(ctx)
		speeds.normal = ctx.args.speed
		if Fly.isRunning() and not Fly.isVehicle() then Fly.setSpeed(speeds.normal) end
		ctx:reply("Fly speed set to " .. tostring(speeds.normal))
	end,
}

group{
	name = "vfly",
	aliases = { "vehiclefly" },
	description = "Fly while keeping the vehicle you are sitting in.",
	args = {
		{ name = "speed", type = "number", optional = true, min = 0, max = 100 },
	},
	examples = { "vfly", "vfly 5" },
	requires = { character = true },
	toggle = false,
	run = function(ctx)
		if ctx.args.speed then speeds.vehicle = ctx.args.speed end
		Fly.start{ speed = speeds.vehicle, vehicle = true }
	end,
}

group{
	name = "togglevfly",
	description = "Toggles vehicle fly.",
	run = function(ctx)
		if Fly.isRunning() then
			Fly.stop()
		else
			Fly.start{ speed = speeds.vehicle, vehicle = true }
		end
	end,
}

group{
	name = "vflyspeed",
	aliases = { "vflysp", "vehicleflyspeed", "vehicleflysp" },
	description = "Sets the vehicle fly speed multiplier.",
	args = {
		{ name = "speed", type = "number", default = 1, min = 0, max = 100 },
	},
	run = function(ctx)
		speeds.vehicle = ctx.args.speed
		if Fly.isRunning() and Fly.isVehicle() then Fly.setSpeed(speeds.vehicle) end
		ctx:reply("Vehicle fly speed set to " .. tostring(speeds.vehicle))
	end,
}

group{
	name = "qefly",
	aliases = { "flyqe" },
	description = "Enables or disables Q and E vertical movement while flying.",
	args = {
		{ name = "enabled", type = "boolean", default = true },
	},
	toggle = false,
	run = function(ctx)
		Fly.setQE(ctx.args.enabled)
		ctx:reply("Q/E flight " .. (ctx.args.enabled and "enabled" or "disabled"))
	end,
}

-- ── cframe fly ──────────────────────────────────────────────────────────────

group{
	name = "cframefly",
	aliases = { "cfly" },
	description = "Flight that moves your head directly, ignoring physics.",
	args = {
		{ name = "speed", type = "number", optional = true, min = 0 },
	},
	requires = { character = true },
	offAliases = { "uncfly" },
	offArgs = {},
	run = function(ctx)
		CFrameFly.start{ speed = ctx.args.speed or CFrameFly.speed() }
	end,
	off = function() CFrameFly.stop() end,
}

group{
	name = "cframeflyspeed",
	aliases = { "cflyspeed" },
	description = "Sets the cframe fly speed.",
	args = {
		{ name = "speed", type = "number", default = 50, min = 0 },
	},
	run = function(ctx)
		CFrameFly.setSpeed(ctx.args.speed)
		ctx:reply("CFrame fly speed set to " .. tostring(ctx.args.speed))
	end,
}

-- ── float ───────────────────────────────────────────────────────────────────

group{
	name = "float",
	aliases = { "platform" },
	description = "Stand on an invisible platform. Q lowers it, E raises it.",
	requires = { character = true },
	offAliases = { "unplatform", "noplatform" },
	run = function(ctx)
		Float.start()
		ctx:notify("Float", "Started floating (Q = down, E = up)")
	end,
	off = function(ctx)
		Float.stop()
		ctx:notify("Float", "Stopped floating")
	end,
}

-- ── swim ────────────────────────────────────────────────────────────────────

group{
	name = "swim",
	description = "Swim through the air with zero gravity.",
	requires = { character = true, alive = true },
	run = function() Swim.start() end,
	off = function() Swim.stop() end,
}

return true
