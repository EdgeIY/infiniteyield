--[[═══════════════════════════════════════════════════════════════════════════
	commands/keybinds · bind, unbind, binds, clearbinds
	─────────────────────────────────────────────────────────────────────────
	New commands. Legacy IY had no way to add a keybind from the command bar at
	all: binds were created in the keybind editor window (source.ref.lua
	5977-6262) and removed by `unkeybind(cmd, key)` (6021-6035), which only the
	editor's Delete buttons called. If the interface failed to mount you could not
	touch your keybinds.

	cmd/binds already owns the list, the key index, persistence and the legacy
	key-format migration, so these four commands are a thin surface over it --
	which is also why `;bind f fly` and the editor stay in sync without either
	knowing about the other.
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Cmd   = IY.import("cmd/api")
local Binds = IY.import("cmd/binds")
local Store = IY.import("core/store")
local Str   = IY.import("core/util/strings")

local group = Cmd.group{ category = "Keybinds" }

local function prefix()
	return Store.get("prefix") or ";"
end

group{
	name = "bind",
	aliases = { "keybind" },
	description = "Runs a command whenever you press a key.",
	args = {
		{ name = "key",     type = "keycode" },
		{ name = "command", type = "command" },
	},
	examples = { "bind f fly", "keybind n noclip", "bind t speed 100" },
	run = function(ctx)
		local bind = Binds.add{ key = ctx.args.key, command = ctx.args.command }
		ctx:notify("Keybinds Updated",
			"Bound " .. Binds.describeKey(bind.key) .. " to " .. bind.command)
	end,
}

--[[ `;unbind f` drops every bind on F; `;unbind command fly` drops every bind
     that runs `fly`, whichever key it is on. The first argument is a plain string
     rather than a keycode so that the literal word "command" can select the
     second form, and so mouse binds ("LeftClick") -- which the editor can create
     and Enum.KeyCode cannot express -- are still removable here. ]]
group{
	name = "unbind",
	aliases = { "removebind", "unkeybind" },
	description = "Removes the keybinds on a key, or every bind for one command.",
	args = {
		{ name = "target",  type = "string" },
		{ name = "command", type = "command", optional = true },
	},
	examples = { "unbind f", "unbind command fly", "unkeybind leftclick" },
	run = function(ctx)
		local target = ctx.args.target
		local removed, label

		if Str.lower(target) == "command" then
			local command = ctx.args.command
			if not command then
				ctx:fail("name the command to unbind\nusage: unbind command <command>")
			end
			removed = Binds.remove{ command = command }
			label = command
		else
			local key = Binds.normaliseKey(target)
			if not key then ctx:fail("'%s' is not a key", target) end
			removed = Binds.remove{ key = key }
			label = Binds.describeKey(key)
		end

		if removed == 0 then ctx:fail("nothing is bound to %s", label) end
		ctx:notify("Keybinds Updated",
			"Removed " .. Str.pluralise(removed, "keybind") .. " for " .. label)
	end,
}

--[[ The same row text the keybind editor shows (legacy 6013-6018). ]]
local function describe(bind)
	local text = Binds.describeKey(bind.key) .. " > " .. bind.command
	if bind.toggle then
		return text .. " / " .. bind.toggle
	end
	return text .. "  " .. (bind.keyUp and "(keyup)" or "(keydown)")
end

group{
	name = "binds",
	aliases = { "keybinds", "listbinds" },
	description = "Notifies you every keybind you have.",
	examples = { "binds" },
	run = function(ctx)
		local list = Binds.list()
		if #list == 0 then
			ctx:notify("Keybinds", "You have no keybinds. Add one with "
				.. prefix() .. "bind <key> <command>")
			return
		end
		local lines = {}
		for i = 1, #list do lines[#lines + 1] = describe(list[i]) end
		ctx:notify("Keybinds (" .. tostring(#list) .. ")", table.concat(lines, "\n"))
	end,
}

group{
	name = "clearbinds",
	description = "Removes every keybind you have.",
	examples = { "clearbinds" },
	run = function(ctx)
		local count = Binds.clear()
		if count == 0 then
			ctx:notify("Keybinds Updated", "You had no keybinds")
			return
		end
		ctx:notify("Keybinds Updated",
			"Removed all keybinds (" .. Str.pluralise(count, "keybind") .. ")")
	end,
}

return true
