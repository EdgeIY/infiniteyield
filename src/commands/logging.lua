--[[═══════════════════════════════════════════════════════════════════════════
	commands/logging · chat logs, join logs, the Discord webhook
	─────────────────────────────────────────────────────────────────────────
	Legacy equivalent: source.ref.lua 11734-11776 (logs, chatlogs, joinlogs,
	chatlogswebhook).

	Those four commands each reached into the log window directly -- flipping two
	globals, rewriting `Toggle.Text`, swapping entries between the `shade2` and
	`shade3` theme registries and tweening a frame. All four now write the data
	model in features/chatlogs and then *ask* ui/logs to show itself, so they work
	with the interface unmounted: logging starts either way, and the notification
	says so when there is no window to open.

	Each also gained an off handler, so `unlogs`, `unchatlogs` and `unjoinlogs`
	exist. Legacy had no way to turn logging back off from the command bar at
	all -- you had to find the toggle inside the window.
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Cmd      = IY.import("cmd/api")
local Guard    = IY.import("core/guard")
local ChatLogs = IY.import("features/chatlogs")

local group = Cmd.group{ category = "Logs" }

--[[ The window belongs to ui/logs, which is optional and may not exist in this
     build at all. `manifest.has` is the existence test rather than tryImport,
     because tryImport records a boot diagnostic every time it misses -- one per
     `;logs`, forever. ]]
local function window()
	local manifest = IY.manifest
	if type(manifest) == "table" and type(manifest.has) == "function"
		and not manifest.has("ui/logs") then
		return nil
	end
	return IY:tryImport("ui/logs")
end

--[[ Returns false when there is no window, so the caller can say so. ]]
local function open(tab)
	local Logs = window()
	if not Logs then return false end
	if tab and type(Logs.show) == "function" then Guard.try(Logs.show, tab) end
	if type(Logs.open) == "function" then Guard.try(Logs.open) end
	return true
end

local function close()
	local Logs = window()
	if Logs and type(Logs.close) == "function" then Guard.try(Logs.close) end
end

group{
	name = "logs",
	description = "Turns chat and join logging on and opens the log window.",
	examples = { "logs", "unlogs" },
	offDescription = "Turns chat and join logging off.",
	run = function(ctx)
		ChatLogs.setChatEnabled(true)
		ChatLogs.setJoinEnabled(true)
		local opened = open()
		if not ctx:quiet() and not opened then
			ctx:notify("Logs", "Chat and join logging enabled (no log window is loaded)")
		end
	end,
	off = function(ctx)
		ChatLogs.setChatEnabled(false)
		ChatLogs.setJoinEnabled(false)
		close()
		if not ctx:quiet() then ctx:notify("Logs", "Chat and join logging disabled") end
	end,
}

group{
	name = "chatlogs",
	aliases = { "clogs" },
	description = "Records what everyone says and shows the chat log.",
	examples = { "chatlogs", "unchatlogs" },
	offAliases = { "unclogs" },
	offDescription = "Stops recording chat.",
	run = function(ctx)
		ChatLogs.setChatEnabled(true)
		local opened = open("chat")
		if not ctx:quiet() and not opened then
			ctx:notify("Chat Logs", "Chat logging enabled (no log window is loaded)")
		end
	end,
	off = function(ctx)
		ChatLogs.setChatEnabled(false)
		if not ctx:quiet() then ctx:notify("Chat Logs", "Chat logging disabled") end
	end,
}

group{
	name = "joinlogs",
	aliases = { "jlogs" },
	description = "Records who joins and leaves, and shows the join log.",
	examples = { "joinlogs", "unjoinlogs" },
	offAliases = { "unjlogs" },
	offDescription = "Stops recording joins and leaves.",
	run = function(ctx)
		ChatLogs.setJoinEnabled(true)
		local opened = open("join")
		if not ctx:quiet() and not opened then
			ctx:notify("Join Logs", "Join logging enabled (no log window is loaded)")
		end
	end,
	off = function(ctx)
		ChatLogs.setJoinEnabled(false)
		if not ctx:quiet() then ctx:notify("Join Logs", "Join logging disabled") end
	end,
}

--[[ Legacy assigned `logsWebhook = args[1] or nil` and saved, with no check that
     the string was a URL: a typo failed silently on every message forever.
     features/chatlogs validates the scheme, retries a handful of times and then
     switches itself off with one warning. ]]
group{
	name = "chatlogswebhook",
	aliases = { "logswebhook" },
	description = "Mirrors every chat message to a Discord webhook. Run it bare to stop.",
	args = { { name = "url", type = "text", optional = true } },
	examples = { "chatlogswebhook https://discord.com/api/webhooks/...", "chatlogswebhook" },
	requires = { capability = "request" },
	run = function(ctx)
		local url = ChatLogs.setWebhook(ctx.args.url)
		if url then
			ctx:notify("Chat Logs", "Chat messages will be posted to your webhook")
		else
			ctx:notify("Chat Logs", "Webhook cleared")
		end
	end,
}

return true
