--[[═══════════════════════════════════════════════════════════════════════════
	commands/input · injected input, mouse feel, spin and the ad blocker
	─────────────────────────────────────────────────────────────────────────
	autoclick, autokeypress, mousesensitivity, spin and removeads. Five legacy
	commands that had one thing in common: each ran or wrote something with no
	record of how to undo it.

	  · `autoclick` and `autokeypress` looped on the command thread until a
	    global went false, and released neither the mouse button nor the key when
	    stopped through their un-commands.
	  · `mousesensitivity` assigned the raw argument string with no bounds and no
	    restore, so `;ms 100` cost you the session.
	  · `removeads` walked every descendant of workspace every frame, forever,
	    with no off-command at all.

	Legacy equivalent: source.ref.lua 12154-12177 (spin), 12246-12281
	(autoclick, mousesensitivity), 12655-12670 (removeads), 13031-13065
	(autokeypress).
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Cmd          = IY.import("cmd/api")
local Env          = IY.import("core/env")
local Services     = IY.import("core/services")
local Snapshot     = IY.import("core/snapshot")
local Autoclick    = IY.import("features/autoclick")
local Autokeypress = IY.import("features/autokeypress")
local Spin         = IY.import("features/spin")
local Removeads    = IY.import("features/removeads")

local UserInputService = Services.UserInputService

local group = Cmd.group{ category = "Input" }

local CANCEL_HINT = "Press [backspace] and [=] at the same time to stop"
-- ── injected input ──────────────────────────────────────────────────────────

--[[ `requires = { capability = "mouse1click" }` on its own would block the two
     executors this actually works on: legacy used mouse1press/mouse1release, and
     features/autoclick falls back to VirtualUser. A `check` asks the feature
     what it can do and still produces the same "your executor cannot do this"
     message when the answer is nothing. ]]
group{
	name = "autoclick",
	description = "Clicks the mouse for you on a loop.",
	args = {
		{ name = "delay", type = "time", default = 0.1, min = 0, max = 60 },
		{ name = "hold",  type = "time", default = 0.1, min = 0, max = 60 },
	},
	examples = { "autoclick", "autoclick 0.05 0.05", "unautoclick" },
	requires = {
		check = function()
			if Autoclick.available() then return true end
			return false, Env.explain("mouse1click")
		end,
	},
	offArgs = {},
	run = function(ctx)
		Autoclick.start({ delay = ctx.args.delay, hold = ctx.args.hold })
		if not ctx:quiet() then ctx:notify("Auto Clicker", CANCEL_HINT) end
	end,
	off = function(ctx)
		Autoclick.stop()
		if not ctx:quiet() then ctx:notify("Auto Clicker", "Stopped") end
	end,
}

group{
	name = "autokeypress",
	aliases = { "keypress" },
	description = "Holds a key down for you on a loop.",
	args = {
		{ name = "key",   type = "string" },
		{ name = "delay", type = "time", default = 0.1, min = 0, max = 60 },
		{ name = "hold",  type = "time", default = 0.1, min = 0, max = 60 },
	},
	examples = { "autokeypress space", "keypress w 0.05 0.2", "unautokeypress" },
	requires = {
		check = function()
			if Autokeypress.available() then return true end
			return false, Env.explain("keypress")
		end,
	},
	offAliases = { "unkeypress", "nokeypress" },
	offArgs = {},
	run = function(ctx)
		Autokeypress.start({
			key   = ctx.args.key,
			delay = ctx.args.delay,
			hold  = ctx.args.hold,
		})
		if not ctx:quiet() then ctx:notify("Auto Key Press", CANCEL_HINT) end
	end,
	off = function(ctx)
		Autokeypress.stop()
		if not ctx:quiet() then ctx:notify("Auto Key Press", "Stopped") end
	end,
}

-- ── mouse feel ──────────────────────────────────────────────────────────────

group{
	name = "mousesensitivity",
	aliases = { "ms" },
	description = "Sets how far the camera turns per unit of mouse movement.",
	args = {
		{ name = "sensitivity", type = "number", default = 1, min = 0.05, max = 5 },
	},
	examples = { "ms 0.3", "ms 1", "unms" },
	toggle = false,
	offAliases = { "unms", "noms" },
	offArgs = {},
	offDescription = "Puts your mouse sensitivity back to what the game set.",
	run = function(ctx)
		--[[ Legacy assigned `args[1]` -- the raw string -- with no bounds and no
		     record (12280). Anything much outside 0.05-5 makes the camera
		     unusable, and there was no way back short of rejoining. ]]
		local ok, reason = Snapshot.set(UserInputService, "MouseDeltaSensitivity",
			ctx.args.sensitivity, "mousesensitivity")
		if not ok then
			ctx:fail("could not change mouse sensitivity: %s", tostring(reason))
		end
		if not ctx:quiet() then
			ctx:reply("Mouse sensitivity set to " .. tostring(ctx.args.sensitivity))
		end
	end,
	off = function(ctx)
		Snapshot.restore(UserInputService, "MouseDeltaSensitivity")
		if not ctx:quiet() then ctx:reply("Mouse sensitivity restored") end
	end,
}

-- ── spin ────────────────────────────────────────────────────────────────────

group{
	name = "spin",
	category = "Character",
	description = "Spins you on the spot.",
	args = {
		{ name = "speed", type = "number", default = 20 },
	},
	examples = { "spin", "spin 50", "unspin" },
	requires = { character = true, root = true },
	offArgs = {},
	run = function(ctx)
		-- Changing the speed of a running spin should not rebuild the force, which
		-- is what legacy's destroy-and-recreate did on every call (12159).
		if Spin.isRunning() then
			Spin.setSpeed(ctx.args.speed)
		else
			Spin.start({ speed = ctx.args.speed })
		end
	end,
	off = function() Spin.stop() end,
}

-- ── ads ─────────────────────────────────────────────────────────────────────

group{
	name = "removeads",
	category = "World",
	aliases = { "adblock" },
	description = "Deletes Roblox's in-game billboard ads, including ones that stream in later.",
	examples = { "removeads", "unremoveads" },
	offAliases = { "unadblock", "noadblock" },
	run = function(ctx)
		Removeads.start()
		if not ctx:quiet() then ctx:reply("Removing ads") end
	end,
	-- New: legacy's loop could not be stopped by anything (12656).
	off = function(ctx)
		Removeads.stop()
		if not ctx:quiet() then ctx:reply("Stopped removing ads") end
	end,
}

return true
