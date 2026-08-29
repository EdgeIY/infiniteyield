--[[═══════════════════════════════════════════════════════════════════════════
	commands/plugins · add, remove and reload plugins
	─────────────────────────────────────────────────────────────────────────
	Legacy equivalent: source.ref.lua 13067-13098.

	The file handling, the environment each plugin runs in and the saved list all
	live in features/plugins; these four commands are a thin shell over it. The
	visible difference is that `;removeplugin` now removes the plugin's commands
	too -- the legacy version left them registered until you rejoined.
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Cmd     = IY.import("cmd/api")
local Store   = IY.import("core/store")
local Str     = IY.import("core/util/strings")
local Plugins = IY.import("features/plugins")

local group = Cmd.group{ category = "Plugins", requires = { persist = true } }

group{
	name = "addplugin",
	aliases = { "plugin" },
	description = "Loads a plugin file and remembers it for next session.",
	args = { { name = "name", type = "text" } },
	examples = { "addplugin example", "addplugin example.iy" },
	run = function(ctx)
		local info = Plugins.add(ctx.args.name)
		ctx:notify("Loaded Plugin",
			"Name: " .. info.name .. "\nDescription: " .. info.description)
	end,
}

group{
	name = "removeplugin",
	aliases = { "deleteplugin" },
	description = "Unloads a plugin and forgets it.",
	args = { { name = "name", type = "text" } },
	run = function(ctx)
		local ok, removed, file = Plugins.remove(ctx.args.name)
		if not ok then ctx:fail("'%s' is not added", file) end
		ctx:notify("Removed Plugin",
			file .. " was removed (" .. Str.pluralise(removed, "command") .. ")")
	end,
}

group{
	name = "reloadplugin",
	description = "Reloads a plugin from disk.",
	args = { { name = "name", type = "text" } },
	run = function(ctx)
		-- The legacy version slept a second between the remove and the add
		-- because the removal was asynchronous UI work; it is not any more.
		local info = Plugins.reload(ctx.args.name)
		ctx:notify("Reloaded Plugin",
			info.name .. " (" .. Str.pluralise(#info.commands, "command") .. ")")
	end,
}

group{
	name = "addallplugins",
	aliases = { "loadallplugins" },
	description = "Adds every plugin file it can find that is not already loaded.",
	requires = { capability = "listfiles" },
	run = function(ctx)
		local added, failures = Plugins.addAllFromFolder()
		if #added == 0 and #failures == 0 then
			ctx:notify("Plugins", "No new .iy files in " .. Plugins.folderPath()
				.. " or your workspace folder")
			return
		end
		local text = Str.pluralise(#added, "plugin") .. " added"
		if #failures > 0 then
			text = text .. ", " .. tostring(#failures) .. " failed (run "
				.. tostring(Store.get("prefix") or ";") .. "iylog)"
		end
		ctx:notify("Plugins", text)
	end,
}

return true
