--[[═══════════════════════════════════════════════════════════════════════════
	commands/system · IY itself
	─────────────────────────────────────────────────────────────────────────
	The commands that act on Infinite Yield rather than on the game: aliases,
	the Discord invite, keepiy, job ids, volume, notifications, loop breaking,
	unloading, and the diagnostics surface.

	Legacy equivalents: source.ref.lua 6516-6554 (aliases), 6555-6578 (discord),
	6580-6606 (keepiy family), 6939-6947 (jobid / notifyjobid / breakloops),
	6950-6964 (unloadiy), 7052-7054 (exit), 8026-8029 (volume), 8106-8114
	(notify / lastcommand), 11102-11104 (notifyping), 13100-13109 (removecmd /
	debug).

	`;iydiag`, `;iylog`, `;help` and `;version` are new: they replace the legacy
	debug affordances (`_G.IY_DEBUG` plus a console `print`) with something a
	user can read and paste into a bug report.
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Cmd        = IY.import("cmd/api")
local Dispatch   = IY.import("cmd/dispatch")
local Aliases    = IY.import("cmd/aliases")
local History    = IY.import("cmd/history")
local Env        = IY.import("core/env")
local Guard      = IY.import("core/guard")
local Json       = IY.import("core/json")
local Log        = IY.import("core/log")
local Notify     = IY.import("core/notify")
local Sched      = IY.import("core/scheduler")
local Services   = IY.import("core/services")
local Store      = IY.import("core/store")
local Str        = IY.import("core/util/strings")
local KeepIY     = IY.import("features/keepiy")
local ServerInfo = IY.import("features/serverinfo")
local Version    = IY.import("features/version")

local group = Cmd.group{ category = "System" }

local function prefix()
	return Store.get("prefix") or ";"
end

-- ── aliases ─────────────────────────────────────────────────────────────────

--[[ Argument order is the legacy one, `addalias <command> <alias>`. Because an
     alias now maps to a whole command *line*, quoting the first argument gives
     you what the legacy version silently dropped: `;addalias "fly 100" jf`. ]]
group{
	name = "addalias",
	description = "Adds your own name for a command.",
	args = {
		{ name = "command", type = "string" },
		{ name = "alias",   type = "string" },
	},
	examples = { "addalias fly f", 'addalias "fly 100" jf' },
	requires = { persist = true },
	run = function(ctx)
		Aliases.set(ctx.args.alias, ctx.args.command)
		ctx:notify("Aliases Modified",
			"Added " .. ctx.args.alias .. " as an alias to " .. ctx.args.command)
	end,
}

group{
	name = "removealias",
	description = "Removes one of your aliases.",
	args = { { name = "alias", type = "string" } },
	requires = { persist = true },
	run = function(ctx)
		local target = Aliases.resolve(ctx.args.alias)
		if not Aliases.remove(ctx.args.alias) then
			ctx:fail("'%s' is not one of your aliases", ctx.args.alias)
		end
		ctx:notify("Aliases Modified",
			"Removed the alias " .. ctx.args.alias .. " from " .. tostring(target))
	end,
}

group{
	name = "clraliases",
	description = "Removes every alias you have added.",
	requires = { persist = true },
	run = function(ctx)
		local removed = Aliases.clear()
		ctx:notify("Aliases Modified", "Removed all aliases (" .. tostring(removed) .. ")")
	end,
}

--[[ The legacy build could only list aliases through the settings panel; this
     is the command-bar equivalent, matching `;binds`. ]]
group{
	name = "aliases",
	aliases = { "listaliases" },
	description = "Lists the aliases you have added.",
	run = function(ctx)
		local list = Aliases.list()
		if #list == 0 then
			return ctx:notify("Aliases",
				"You have no aliases. Add one with " .. (Store.get("prefix") or ";")
				.. "addalias <command> <alias>")
		end
		local lines = {}
		for i = 1, math.min(#list, 20) do
			lines[#lines + 1] = list[i].alias .. "  ->  " .. list[i].command
		end
		if #list > 20 then
			lines[#lines + 1] = "... and " .. tostring(#list - 20) .. " more"
		end
		ctx:notify("Aliases", table.concat(lines, "\n"))
	end,
}

-- ── support ─────────────────────────────────────────────────────────────────

local DISCORD_CODE = "78ZuWSq"

--[[ The legacy command also answered to `help`; `;help` is the command list
     now, and `;discord` / `;support` are the invite. ]]
group{
	name = "discord",
	aliases = { "support" },
	description = "Gives you an invite to the Infinite Yield Discord server.",
	run = function(ctx)
		if Env.usable("setclipboard") then
			pcall(Env.fn.setclipboard, "https://discord.com/invite/" .. DISCORD_CODE)
			ctx:notify("Discord Invite", "Copied to clipboard!\ndiscord.gg/" .. DISCORD_CODE)
		else
			ctx:notify("Discord Invite", "discord.gg/" .. DISCORD_CODE)
		end

		-- Discord's local RPC port opens the invite in an already-running
		-- client. Localhost only, entirely optional, and off the command's
		-- thread so a firewalled port cannot make ;discord hang.
		local request = Env.fn.request
		if not request then return end
		Sched.spawn("discord.rpc", function()
			pcall(request, {
				Url = "http://127.0.0.1:6463/rpc?v=1",
				Method = "POST",
				Headers = {
					["Content-Type"] = "application/json",
					Origin = "https://discord.com",
				},
				Body = Json.encode({
					cmd   = "INVITE_BROWSER",
					nonce = Services.HttpService:GenerateGUID(false),
					args  = { code = DISCORD_CODE },
				}),
			})
		end)
	end,
}

-- ── keepiy ──────────────────────────────────────────────────────────────────

--[[ `off` generates unkeepiy / nokeepiy / togglekeepiy, which is exactly the
     trio the legacy script wrote out by hand. ]]
group{
	name = "keepiy",
	description = "Runs Infinite Yield again automatically after you teleport.",
	requires = { capability = "queueteleport" },
	offRequires = { capability = "queueteleport" },
	offDescription = "Stops running Infinite Yield after you teleport.",
	run = function(ctx)
		KeepIY.set(true)
		if not ctx:quiet() then
			ctx:notify("KeepIY", "Infinite Yield will now run after you teleport")
		end
	end,
	off = function(ctx)
		KeepIY.set(false)
		if not ctx:quiet() then
			ctx:notify("KeepIY", "Infinite Yield will no longer run after you teleport")
		end
	end,
}

-- ── ids ─────────────────────────────────────────────────────────────────────

group{
	name = "jobid",
	description = "Copies a link that joins this exact server to your clipboard.",
	requires = { capability = "setclipboard" },
	run = function(ctx)
		Env.fn.setclipboard(ServerInfo.joinLink())
		ctx:notify("Clipboard", "Copied to clipboard")
	end,
}

group{
	name = "notifyjobid",
	description = "Notifies you this server's job id and place id.",
	run = function(ctx)
		ctx:notify("JobId / PlaceId", tostring(game.JobId) .. " / " .. tostring(game.PlaceId))
	end,
}

-- ── notifications ───────────────────────────────────────────────────────────

group{
	name = "volume",
	aliases = { "vol" },
	description = "Sets your game volume, on a scale of 0 to 10.",
	args = { { name = "level", type = "number", min = 0, max = 10 } },
	examples = { "volume 0", "vol 7" },
	run = function(ctx)
		-- Legacy divided args[1] by ten and assigned the result raw; the number
		-- type is what stops `;volume loud` reaching MasterVolume.
		UserSettings():GetService("UserGameSettings").MasterVolume = ctx.args.level / 10
	end,
}

group{
	name = "notify",
	description = "Sends yourself a notification.",
	args = { { name = "text", type = "text" } },
	examples = { "notify hello" },
	run = function(ctx)
		Notify.send(ctx.args.text)
	end,
}

group{
	name = "notifyping",
	aliases = { "ping" },
	description = "Notifies you your network ping.",
	run = function(ctx)
		local player = ctx.speaker:requirePlayer()
		local ok, value = pcall(function() return player:GetNetworkPing() end)
		if not ok or type(value) ~= "number" then
			ctx:fail("your client will not report a ping")
		end
		ctx:notify("Ping", tostring(math.floor(value * 1000 + 0.5)) .. "ms")
	end,
}

--[[ cmd/history already refuses to record lastcommand itself, so the legacy
     "did I just replay myself" prefix check is structural now. ]]
group{
	name = "lastcommand",
	aliases = { "lastcmd" },
	description = "Runs the command you used before this one, again.",
	run = function(ctx)
		local line = History.last()
		if not line then ctx:fail("you have not run a command yet") end
		Cmd.run(line, ctx.speaker, { record = false })
	end,
}

-- ── lifecycle ───────────────────────────────────────────────────────────────

group{
	name = "breakloops",
	aliases = { "break" },
	description = "Stops every repeating command loop (;inf^cmd).",
	run = function(ctx)
		Dispatch.breakLoops()
		if not ctx:quiet() then ctx:reply("Stopped command loops") end
	end,
}

--[[ The legacy version disconnected its UI connections and destroyed its own
     ScreenGui, and left everything else -- every feature loop, every hook,
     every snapshotted property -- running. IY.unload() runs every registered
     teardown instead, which is what makes this command mean what it says. ]]
group{
	name = "unloadiy",
	aliases = { "unload", "killiy" },
	description = "Unloads Infinite Yield completely.",
	run = function(ctx)
		Dispatch.breakLoops()
		if not ctx:quiet() then ctx:notify("Infinite Yield", "Unloading...") end

		-- entry.lua installs IY.unload; without it (tests, a partial boot) the
		-- runtime method is the fallback.
		local errors
		if type(rawget(IY, "unload")) == "function" then
			errors = IY.unload()
		else
			errors = IY:unload()
		end

		local count = type(errors) == "table" and #errors or 0
		if count > 0 then
			Log.warn("unloadiy", "%s failed during teardown", Str.pluralise(count, "callback"))
			for i = 1, count do
				Log.warn("unloadiy", "  %s: %s",
					tostring(errors[i].label), Guard.describe(errors[i].error))
			end
		else
			Log.info("unloadiy", "unloaded cleanly")
		end
	end,
}

group{
	name = "exit",
	aliases = { "shutdown", "leave" },
	description = "Closes Roblox.",
	run = function()
		game:Shutdown()
	end,
}

-- ── introspection ───────────────────────────────────────────────────────────

--[[ Disabling rather than deleting: the command stays in the list and explains
     itself, which is what the legacy UI did by greying the row out. ]]
group{
	name = "removecmd",
	aliases = { "deletecmd" },
	description = "Disables a command until you reload Infinite Yield.",
	args = { { name = "command", type = "command" } },
	examples = { "removecmd kill" },
	run = function(ctx)
		local definition = Cmd.find(ctx.args.command)
		if not definition then
			ctx:fail("there is no command called '%s'", ctx.args.command)
		end
		Cmd.setEnabled(definition.name, false, "Command has been disabled by you or a plugin")
		ctx:notify("Removed Command", definition.name .. " is disabled until you reload IY")
	end,
}

group{
	name = "debug",
	description = "Turns IY's debug logging on or off.",
	args = { { name = "enabled", type = "boolean", default = true } },
	run = function(ctx)
		local on = ctx.args.enabled
		Log.setDebug(on)
		-- The one global IY still writes. entry.lua reads it to decide whether
		-- re-running the loader should replace a live instance, and legacy
		-- plugins branch on it, so it has to keep working.
		local genv = Env.fn.getgenv and Env.fn.getgenv() or nil
		if type(genv) ~= "table" then genv = _G end
		genv.IY_DEBUG = on
		ctx:notify("debug", tostring(on), 1)
	end,
}

group{
	name = "help",
	aliases = { "commands", "cmds" },
	description = "Shows how many commands are loaded, or the usage of one.",
	args = { { name = "command", type = "command", optional = true } },
	examples = { "help", "help speed" },
	run = function(ctx)
		local name = ctx.args.command
		if not name then
			ctx:notify("Help", tostring(#Cmd.all()) .. " commands are loaded.\nPress "
				.. prefix() .. " to open the command bar, or run "
				.. prefix() .. "help <command>.\nSupport: " .. prefix() .. "discord")
			return
		end
		local text = Cmd.help(name)
		if not text then
			local suggestion = IY.import("cmd/registry").closest(name)
			ctx:fail("there is no command called '%s'%s", name,
				suggestion and (" -- did you mean " .. suggestion .. "?") or "")
		end
		ctx:notify("Help", text)
	end,
}

group{
	name = "version",
	description = "Shows which version of Infinite Yield is running.",
	run = function(ctx)
		ctx:notify("Infinite Yield", Version.describe())
	end,
}

-- ── diagnostics ─────────────────────────────────────────────────────────────

--[[ Sizes of the tables other subsystems hand back, without assuming whether
     they are arrays or keyed maps. ]]
local function size(value)
	if type(value) ~= "table" then return 0 end
	if type(value.count) == "number" then return value.count end
	local n = #value
	if n > 0 then return n end
	local total = 0
	for _ in pairs(value) do total = total + 1 end
	return total
end

local function runningFeatures(info)
	local out = {}
	local features = type(info.features) == "table" and info.features or {}
	for i = 1, #features do
		if features[i].running then out[#out + 1] = tostring(features[i].name) end
	end
	return out
end

--[[ Snapshot.snapshot() is one entry per tag, each carrying its own count. ]]
local function snapshotCount(list)
	if type(list) ~= "table" then return 0 end
	local total = 0
	for i = 1, #list do total = total + (tonumber(list[i].count) or 0) end
	return total
end

--[[ Hooks.snapshot() is keyed by metamethod, plus a list of hooked functions. ]]
local function hookCount(hooks)
	if type(hooks) ~= "table" then return 0 end
	local total = 0
	local kinds = { "namecall", "index", "newindex" }
	for i = 1, #kinds do
		local slot = hooks[kinds[i]]
		if type(slot) == "table" and type(slot.handlers) == "table" then
			total = total + #slot.handlers
		end
	end
	if type(hooks.functions) == "table" then total = total + #hooks.functions end
	return total
end

--[[ The readable report. Goes to the log, not the notification: it is meant to
     be copied into a bug report. ]]
local function describe(info)
	local lines = {}
	local function add(text) lines[#lines + 1] = text end

	local boot = type(info.boot) == "table" and info.boot or {}
	local runtime = type(info.runtime) == "table" and info.runtime or {}
	local executor = type(info.executor) == "table" and info.executor or {}
	local platform = type(info.platform) == "table" and info.platform or {}

	add("Infinite Yield " .. tostring(info.version) .. " (" .. tostring(info.channel) .. ")")
	add("executor: " .. tostring(executor.executor or "Unknown")
		.. (executor.version and (" " .. tostring(executor.version)) or "")
		.. " -- platform " .. tostring(platform.platform or "Unknown")
		.. (platform.mobile and " (mobile)" or ""))
	add("modules: " .. tostring(runtime.modules or 0) .. " loaded in "
		.. string.format("%.2fs", tonumber(boot.elapsed) or 0)
		.. (runtime.slowest and (", slowest " .. tostring(runtime.slowest)) or ""))
	add("commands: " .. tostring(info.commands or 0)
		.. " (" .. tostring(size(info.audit)) .. " audit issue(s))")
	add("settings: " .. (info.persistent and "saved to disk" or "in memory only"))
	add("capabilities: " .. tostring(size(executor.supported)) .. " supported, "
		.. tostring(size(executor.emulated)) .. " emulated, "
		.. tostring(size(executor.missing)) .. " missing")

	local running = runningFeatures(info)
	add("features running: " .. (#running > 0 and table.concat(running, ", ") or "none"))
	add("loops running: " .. tostring(size(info.loops))
		.. " -- properties snapshotted: " .. tostring(snapshotCount(info.snapshots))
		.. " -- hooks: " .. tostring(hookCount(info.hooks)))

	local failed = type(boot.failed) == "table" and boot.failed or {}
	if #failed > 0 then
		for i = 1, #failed do
			add("boot phase '" .. tostring(failed[i].phase) .. "' failed: "
				.. Guard.describe(failed[i].error))
		end
	end

	local diagnostics = type(info.diagnostics) == "table" and info.diagnostics or {}
	if #diagnostics > 0 then
		add("diagnostics (" .. tostring(#diagnostics) .. "):")
		for i = 1, #diagnostics do
			add("  [" .. tostring(diagnostics[i].kind) .. "] "
				.. tostring(diagnostics[i].message))
		end
	end

	if info.degraded then
		add("note: the boot report could not be assembled (" .. tostring(info.degraded) .. ")")
	end

	return table.concat(lines, "\n"), #failed, #diagnostics, #running
end

--[[ boot.diagnostics() is the source of truth, but `;iydiag` is what people run
     when something is already broken -- possibly the aggregator itself, if one
     of the snapshots it collects throws. Falling back to reading the same fields
     directly means the report is never simply unavailable. ]]
local function collect()
	local ok, info = pcall(function() return IY.import("boot").diagnostics() end)
	if ok and type(info) == "table" then return info end

	local reason = Guard.describe(info)
	Log.warn("iydiag", "boot.diagnostics() failed (%s); reading what is available directly", reason)

	local function try(fn)
		local okay, value = pcall(fn)
		if okay then return value end
		return nil
	end
	return {
		version     = IY.version,
		channel     = IY.channel,
		boot        = type(IY.bootReport) == "table" and IY.bootReport or {},
		runtime     = { modules = #(IY.loadOrder or {}) },
		executor    = try(function() return IY.import("core/env").snapshot() end) or {},
		platform    = try(function() return IY.import("core/platform").snapshot() end) or {},
		commands    = Cmd.count(),
		audit       = try(function() return IY.import("cmd/registry").audit() end) or {},
		features    = try(function() return IY.import("features/feature").snapshot() end) or {},
		loops       = try(function() return Sched.snapshot() end) or {},
		persistent  = Store.persistent,
		snapshots   = try(function() return IY.import("core/snapshot").snapshot() end) or {},
		hooks       = try(function() return IY.import("core/hooks").snapshot() end) or {},
		diagnostics = IY.diagnostics or {},
		degraded    = reason,
	}
end

group{
	name = "iydiag",
	aliases = { "diag", "iyinfo" },
	description = "Reports what loaded, what is running and what failed.",
	run = function(ctx)
		local info = collect()
		local report, failed, diagnostics, running = describe(info)
		Log.info("iydiag", "%s", report)

		local executor = type(info.executor) == "table" and info.executor or {}
		local headline = tostring(info.version) .. " (" .. tostring(info.channel) .. ") on "
			.. tostring(executor.executor or "Unknown")
			.. "\n" .. tostring(info.commands or 0) .. " commands, "
			.. tostring(running) .. " feature(s) running"
			.. "\n" .. Str.pluralise(failed, "failed boot phase")
			.. ", " .. Str.pluralise(diagnostics, "diagnostic")
			.. "\nFull report: " .. prefix() .. "iylog"
		ctx:notify("Diagnostics", headline)
	end,
}

group{
	name = "iylog",
	description = "Copies IY's log to your clipboard.",
	run = function(ctx)
		local text = Log.dump()
		local entries = #Log.buffer
		if text ~= "" and Env.usable("setclipboard") then
			local copied = pcall(Env.fn.setclipboard, text)
			if copied then
				ctx:notify("IY Log", Str.pluralise(entries, "entry", "entries")
					.. " copied to your clipboard")
				return
			end
		end
		ctx:notify("IY Log", Str.pluralise(entries, "entry", "entries")
			.. " recorded -- your executor cannot use the clipboard, so check the console")
	end,
}

return true
