--[[═══════════════════════════════════════════════════════════════════════════
	commands/server · this server and the ones next door
	─────────────────────────────────────────────────────────────────────────
	Legacy equivalents: source.ref.lua 6608-6937 (serverinfo), 6966-6968
	(gametp), 6989-7010 (rejoin), 7012-7020 (inviteprompt), 7022-7027
	(autorejoin), 7029-7050 (serverhop), 8017-8025 (allowrejoin /
	cancelteleport), 12846-12856 (phonebook).

	All of the state -- and the two bugs described in features/rejoin -- lives
	in features/rejoin. `serverinfo` gathers its numbers through
	features/serverinfo, so the panel and the command cannot drift apart.
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Cmd        = IY.import("cmd/api")
local Env        = IY.import("core/env")
local Log        = IY.import("core/log")
local Services   = IY.import("core/services")
local Rejoin     = IY.import("features/rejoin")
local ServerInfo = IY.import("features/serverinfo")

local TeleportService = Services.TeleportService

local group = Cmd.group{ category = "Server" }

-- ── information ─────────────────────────────────────────────────────────────

--[[ The legacy command built a 300-line GUI inline (6611-6937). That belongs to
     the interface now, which renders ServerInfo.collect(); the command notifies
     the summary and leaves the full report on the clipboard. ]]
group{
	name = "serverinfo",
	aliases = { "info", "sinfo" },
	description = "Summarises this server and copies the full detail to your clipboard.",
	singleton = true,
	run = function(ctx)
		local info = ServerInfo.collect()
		local report = ServerInfo.format(info)
		Log.info("serverinfo", "%s", report)

		local copied = false
		if Env.usable("setclipboard") then
			copied = pcall(Env.fn.setclipboard, report)
		end
		ctx:notify("Server", ServerInfo.summary(info)
			.. (copied and "\nFull detail copied to your clipboard" or ""))
	end,
}

-- ── moving between servers ──────────────────────────────────────────────────

group{
	name = "gametp",
	aliases = { "gameteleport" },
	description = "Joins a different game by place id.",
	args = { { name = "placeid", type = "integer", min = 1 } },
	examples = { "gametp 1818" },
	run = function(ctx)
		-- Legacy passed args[1] through as a string.
		TeleportService:Teleport(ctx.args.placeid)
	end,
}

group{
	name = "rejoin",
	aliases = { "rj" },
	description = "Rejoins this server.",
	args = { { name = "reposition", type = "boolean", default = false } },
	examples = { "rejoin", "rejoin true" },
	run = function(ctx)
		if not ctx:quiet() then ctx:notify("Rejoin", "Rejoining...") end
		Rejoin.rejoin({ reposition = ctx.args.reposition })
	end,
}

group{
	name = "serverhop",
	aliases = { "shop" },
	description = "Teleports you into a different server for this game.",
	singleton = true,
	run = function(ctx)
		local found, count = Rejoin.serverhop()
		if not found then
			ctx:notify("Serverhop", "Couldn't find a server.")
			return
		end
		if not ctx:quiet() then
			ctx:notify("Serverhop", "Hopping (" .. tostring(count) .. " servers available)")
		end
	end,
}

group{
	name = "autorejoin",
	aliases = { "autorj" },
	description = "Rejoins automatically if you are kicked or disconnected.",
	offAliases = { "unautorj", "noautorj" },
	offDescription = "Stops rejoining automatically.",
	run = function(ctx)
		Rejoin.startAuto()
		if not ctx:quiet() then ctx:notify("Auto Rejoin", "Auto rejoin enabled") end
	end,
	off = function(ctx)
		Rejoin.stopAuto()
		if not ctx:quiet() then ctx:notify("Auto Rejoin", "Auto rejoin disabled") end
	end,
}

group{
	name = "cancelteleport",
	aliases = { "canceltp" },
	description = "Cancels a teleport in progress.",
	run = function()
		Rejoin.cancel()
	end,
}

group{
	name = "allowrejoin",
	aliases = { "allowrj" },
	description = "Toggles whether client anti-teleport lets a script rejoin the server.",
	run = function(ctx)
		local allowed = Rejoin.toggleAllowRejoin()
		ctx:notify("Client AntiTP",
			"Scripts now may" .. (allowed and "" or " not") .. " make you rejoin the server")
	end,
}

-- ── social ──────────────────────────────────────────────────────────────────

--[[ Legacy indexed `plr[1].UserId` where the resolved list was called `plrs`, so
     this command threw on every invocation (7012-7020). ]]
group{
	name = "inviteprompt",
	description = "Prompts a player that you invited them to this server.",
	args = { { name = "player", type = "player" } },
	examples = { "inviteprompt bob" },
	run = function(ctx)
		local service = Services.get("ExperienceService")
		if not service then ctx:fail("your client has no ExperienceService") end
		local target = ctx.args.player
		local player = target:requirePlayer()
		local ok, err = pcall(function()
			service:LaunchExperience({
				placeId            = game.PlaceId,
				gameInstanceId     = game.JobId,
				referredByPlayerId = player.UserId,
			})
		end)
		if not ok then ctx:fail("Roblox refused the invite prompt (%s)", tostring(err)) end
		ctx:reply("Prompted " .. target.name)
	end,
}

group{
	name = "phonebook",
	aliases = { "call" },
	description = "Opens the Roblox phone book so you can call a friend. Needs voice chat.",
	run = function(ctx)
		local social = Services.get("SocialService")
		if not social then ctx:fail("your client has no SocialService") end
		local player = ctx.speaker:requirePlayer()
		local ok, canInvite = pcall(function()
			return social:CanSendCallInviteAsync(player)
		end)
		if not ok or not canInvite then
			ctx:notify("Phonebook", "It seems you're not able to call anyone. Sorry!")
			return
		end
		social:PromptPhoneBook(player, "")
	end,
}

return true
