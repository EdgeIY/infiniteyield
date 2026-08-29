--[[═══════════════════════════════════════════════════════════════════════════
	commands/chat · saying things and how the chat looks
	─────────────────────────────────────────────────────────────────────────
	chat, spam, whisper, pmspam, spamspeed, bubblechat, chatwindow and darkchat,
	plus the `un`/`no` siblings the registry derives from their `off` handlers.

	Legacy equivalent: source.ref.lua 10660-10785. All the state lives in
	features/chat (sending, the two spam loops) and features/chatappearance
	(bubbles, the window, the dark restyle); nothing is kept here.

	Names that changed hands, both because the registry derives `un<name>` from
	`off`:

	  · legacy `nospam` (10676) had `unspam` as its alias; it is now `unspam`
	    with `nospam` as the alias. Both still work.
	  · same for `nopmspam` / `unpmspam` and `unbubblechat` / `nobubblechat`.
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Cmd        = IY.import("cmd/api")
local Chat       = IY.import("features/chat")
local Appearance = IY.import("features/chatappearance")

local group = Cmd.group{ category = "Chat" }

-- ── saying things ───────────────────────────────────────────────────────────

group{
	name = "chat",
	aliases = { "say" },
	description = "Says something in the chat.",
	args = {
		-- Required: legacy `getstring(1, args)` handed an empty string to
		-- SendAsync, which the engine rejects.
		{ name = "message", type = "text" },
	},
	examples = { "chat hello", "say hi there" },
	run = function(ctx)
		Chat.say(ctx.args.message)
	end,
}

group{
	name = "whisper",
	aliases = { "pm" },
	description = "Sends a private message to one player.",
	args = {
		-- Not optional: a whisper to yourself is not a whisper, and the framework
		-- would otherwise resolve the missing argument to you. Legacy accepted a
		-- whole player list here (10681); pmspam is the multi-target command.
		{ name = "player",  type = "player", optional = false },
		{ name = "message", type = "text" },
	},
	examples = { "whisper bob hello", "pm jim on my way" },
	run = function(ctx)
		local target = ctx.args.player
		Chat.whisper(target:requirePlayer().Name, ctx.args.message)
		if not ctx:quiet() then ctx:reply("Whispered " .. target.name) end
	end,
}

group{
	name = "spam",
	description = "Repeats a message in the chat until you stop it.",
	args = {
		{ name = "message", type = "text" },
	},
	examples = { "spam hello", "nospam", "spamspeed 3" },
	-- No `togglespam`: the off half takes no arguments, so a generated toggle
	-- could never supply the message needed to turn it back on.
	toggle = false,
	offArgs = {},
	run = function(ctx)
		Chat.startSpam(ctx.args.message)
		if not ctx:quiet() then
			ctx:reply("Spamming every " .. tostring(Chat.speed()) .. " second(s)")
		end
	end,
	off = function(ctx)
		Chat.stopSpam()
		if not ctx:quiet() then ctx:reply("Stopped spamming") end
	end,
}

group{
	name = "pmspam",
	description = "Repeatedly whispers a message to players until you stop it.",
	args = {
		{ name = "players", type = "players", optional = false },
		{ name = "message", type = "text" },
	},
	examples = { "pmspam bob hello", "unpmspam bob", "nopmspam" },
	toggle = false,
	offArgs = {
		-- `;nopmspam` on its own cleared nobody in legacy: the missing argument
		-- resolved to *you* (10713), so it only worked if you were the victim.
		{ name = "players", type = "players", default = "all" },
	},
	run = function(ctx)
		local added, already = Chat.startPmspam(ctx:targets("players"), ctx.args.message)
		if ctx:quiet() then return end
		if added == 0 then
			ctx:reply("Already whisper-spamming " .. tostring(already) .. " player(s)")
		else
			ctx:reply("Whisper-spamming " .. tostring(Chat.pmspamCount()) .. " player(s)")
		end
	end,
	off = function(ctx)
		local removed = Chat.stopPmspam(ctx:targets("players"))
		if not ctx:quiet() then
			ctx:reply("Stopped whisper-spamming " .. tostring(removed) .. " player(s)")
		end
	end,
}

group{
	name = "spamspeed",
	description = "Sets how long spam and pmspam wait between messages.",
	args = {
		-- Legacy stored `args[1]` as a *string* and only rejected it if
		-- `isNumber` said no, so the loop waited on "2" (10726).
		{ name = "seconds", type = "number", default = 1, min = 0, max = 60 },
	},
	examples = { "spamspeed 3", "spamspeed" },
	run = function(ctx)
		local value = Chat.setSpeed(ctx.args.seconds)
		if not ctx:quiet() then
			ctx:reply("Spam speed set to " .. tostring(value) .. " second(s)")
		end
	end,
}

-- ── how the chat looks ──────────────────────────────────────────────────────

group{
	name = "bubblechat",
	description = "Shows chat messages in a bubble above each player's head.",
	examples = { "bubblechat", "unbubblechat", "togglebubblechat" },
	run = function(ctx)
		Appearance.setBubbles(true)
		if not ctx:quiet() then ctx:reply("Bubble chat enabled") end
	end,
	off = function(ctx)
		Appearance.setBubbles(false)
		if not ctx:quiet() then ctx:reply("Bubble chat disabled") end
	end,
}

group{
	name = "chatwindow",
	description = "Shows or hides the chat window.",
	examples = { "chatwindow", "unchatwindow" },
	run = function(ctx)
		Appearance.setWindow(true)
		if not ctx:quiet() then ctx:reply("Chat window enabled") end
	end,
	off = function(ctx)
		Appearance.setWindow(false)
		if not ctx:quiet() then ctx:reply("Chat window disabled") end
	end,
}

group{
	name = "darkchat",
	description = "Restyles the chat window, input bar and bubbles dark.",
	examples = { "darkchat", "undarkchat" },
	-- New: legacy had no way back short of rejoining. Every colour is recorded
	-- by core/snapshot, so this restores the game's own chat styling.
	offDescription = "Puts the game's own chat colours back.",
	run = function(ctx)
		local changed = Appearance.startDark()
		if not ctx:quiet() then
			ctx:reply("Dark chat on (" .. tostring(changed) .. " properties restyled)")
		end
	end,
	off = function(ctx)
		Appearance.stopDark()
		if not ctx:quiet() then ctx:reply("Dark chat off") end
	end,
}

return true
