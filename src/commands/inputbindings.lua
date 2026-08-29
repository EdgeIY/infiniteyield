--[[═══════════════════════════════════════════════════════════════════════════
	commands/inputbindings · extra key bindings for the camera and shift lock
	─────────────────────────────────────────────────────────────────────────
	Two toggles that rebind keys the game normally owns. Both used to leave the
	client worse off than they found it -- `unalignmentkeys` could disable the
	Emotes menu permanently, `unctrllock` overwrote the shift-lock key with a
	hard-coded "LeftShift" -- so both restores now go through core/snapshot.
	The details are in features/alignmentkeys and features/ctrllock.

	Legacy equivalent: source.ref.lua 12691-12734.
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Cmd           = IY.import("cmd/api")
local AlignmentKeys = IY.import("features/alignmentkeys")
local CtrlLock      = IY.import("features/ctrllock")

local group = Cmd.group{ category = "Camera" }

group{
	name = "alignmentkeys",
	description = "Binds , and . to pan the camera in 45 degree steps.",
	examples = { "alignmentkeys", "unalignmentkeys" },
	-- Keyboard-only: on a phone this would just switch the Emotes menu off.
	requires = { desktop = true },
	run = function(ctx)
		AlignmentKeys.start()
		if not ctx:quiet() then ctx:reply("Comma and period now pan the camera") end
	end,
	off = function(ctx)
		AlignmentKeys.stop()
		if not ctx:quiet() then ctx:reply("Camera pan keys unbound") end
	end,
}

group{
	name = "ctrllock",
	description = "Moves shift lock onto the Left Control key.",
	examples = { "ctrllock", "unctrllock" },
	run = function(ctx)
		CtrlLock.start()
		if not ctx:quiet() then ctx:reply("Shift lock bound to Left Control") end
	end,
	off = function(ctx)
		CtrlLock.stop()
		if not ctx:quiet() then ctx:reply("Shift lock key restored") end
	end,
}

return true
