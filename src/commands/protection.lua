--[[═══════════════════════════════════════════════════════════════════════════
	commands/protection · keeping the client yours
	─────────────────────────────────────────────────────────────────────────
	clientantikick, clientantiteleport, antigameplaypaused, antiafk, antivoid,
	fakeout and destroyheight -- plus the un/no/toggle siblings the registry
	derives from their `off` handlers, which is where the legacy
	`unantigameplaypaused` and `unantivoid` blocks went.

	Legacy equivalent: source.ref.lua 7928-7940 (antigameplaypaused),
	7942-8015 (clientantikick, clientantiteleport), 8862-8881 (antiafk),
	12601-12644 (destroyheight, antivoid, fakeout).

	Every hook these commands install is a named registration on core/hooks and
	every property they write is a core/snapshot record, so each one can actually
	be turned back off -- none of them could be in the legacy script. The feature
	headers list the individual bugs.
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Cmd          = IY.import("cmd/api")
local Str          = IY.import("core/util/strings")
local AntiAfk      = IY.import("features/antiafk")
local AntiKick     = IY.import("features/antikick")
local AntiTeleport = IY.import("features/antiteleport")
local AntiVoid     = IY.import("features/antivoid")
local Prompts      = IY.import("features/prompts")

local group = Cmd.group{ category = "Protection" }

-- ── kicks and teleports ─────────────────────────────────────────────────────

group{
	name = "clientantikick",
	aliases = { "antikick" },
	description = "Blocks kicks that come from a localscript.",
	examples = { "clientantikick", "unantikick" },
	-- Legacy checked for hookmetamethod by hand and notified when it was absent;
	-- `requires` says the same thing before the command body runs.
	requires = { capability = "hookmetamethod" },
	offAliases = { "unantikick", "noantikick" },
	run = function(ctx)
		AntiKick.start()
		if not ctx:quiet() then
			ctx:notify("Client Antikick",
				"Client anti kick is now active (only effective on localscript kick)")
		end
	end,
	off = function(ctx)
		AntiKick.stop()
		if not ctx:quiet() then ctx:notify("Client Antikick", "Client anti kick is off") end
	end,
}

group{
	name = "clientantiteleport",
	aliases = { "antiteleport" },
	description = "Blocks teleports that come from a localscript.",
	examples = { "clientantiteleport", "allowrejoin", "unantiteleport" },
	requires = { capability = "hookmetamethod" },
	offAliases = { "unantiteleport", "noantiteleport" },
	run = function(ctx)
		AntiTeleport.start()
		if not ctx:quiet() then
			ctx:notify("Client AntiTP",
				"Client anti teleport is now active (only effective on localscript teleport)")
		end
	end,
	off = function(ctx)
		AntiTeleport.stop()
		if not ctx:quiet() then ctx:notify("Client AntiTP", "Client anti teleport is off") end
	end,
}

-- ── the network pause overlay ───────────────────────────────────────────────

group{
	name = "antigameplaypaused",
	description = "Removes the \"gameplay paused\" overlay as soon as it appears.",
	examples = { "antigameplaypaused", "unantigameplaypaused" },
	run = function(ctx)
		Prompts.gameplayPaused:start({})
		if not ctx:quiet() then
			ctx:notify("Gameplay Paused", "The pause overlay will be removed as it appears")
		end
	end,
	off = function(ctx)
		Prompts.gameplayPaused:stop()
		if not ctx:quiet() then ctx:notify("Gameplay Paused", "The pause overlay is left alone") end
	end,
}

-- ── idling ──────────────────────────────────────────────────────────────────

group{
	name = "antiafk",
	aliases = { "antiidle" },
	description = "Keeps you in the game when you stop playing.",
	examples = { "antiafk", "unantiafk" },
	offAliases = { "unantiidle", "noantiidle" },
	run = function(ctx)
		AntiAfk.start()
		if ctx:quiet() then return end
		local report = AntiAfk.report()
		local lines = { "Anti idle is enabled" }
		if report.disabled > 0 then
			lines[#lines + 1] = Str.pluralise(report.disabled, "idle handler")
				.. " paused (re-enabled when you turn this off)"
		end
		if report.disconnected > 0 then
			lines[#lines + 1] = Str.pluralise(report.disconnected, "idle handler")
				.. " had to be disconnected -- that cannot be undone this session"
		end
		ctx:notify("Anti Idle", table.concat(lines, "\n"))
	end,
	off = function(ctx)
		AntiAfk.stop()
		if not ctx:quiet() then ctx:notify("Anti Idle", "Anti idle is disabled") end
	end,
}

-- ── the void ────────────────────────────────────────────────────────────────

group{
	name = "antivoid",
	description = "Throws you back up whenever you fall near the kill plane.",
	examples = { "antivoid", "unantivoid" },
	run = function(ctx)
		AntiVoid.start()
		if not ctx:quiet() then ctx:notify("antivoid", "Enabled") end
	end,
	off = function(ctx)
		AntiVoid.stop()
		if not ctx:quiet() then ctx:notify("antivoid", "Disabled") end
	end,
}

group{
	name = "fakeout",
	description = "Drops you below the map for a second and brings you back.",
	examples = { "fakeout" },
	requires = { character = true, root = true },
	-- The stunt owns the destroy height for a second; two at once would fight
	-- over it and over your position.
	singleton = true,
	run = function(ctx)
		AntiVoid.fakeout()
	end,
}

group{
	name = "destroyheight",
	aliases = { "dh" },
	description = "Sets the height below which the engine deletes falling parts.",
	args = {
		{ name = "height", type = "number", default = -500 },
	},
	examples = { "destroyheight -1000", "dh", "undh" },
	-- A height has no meaningful "toggle"; legacy shipped none either.
	toggle = false,
	offArgs = {},
	offAliases = { "undh", "nodh" },
	offDescription = "Puts the destroy height back to what the game set.",
	run = function(ctx)
		AntiVoid.setHeight(ctx.args.height)
		if not ctx:quiet() then
			ctx:reply("Falling parts are destroyed below " .. tostring(ctx.args.height))
		end
	end,
	off = function(ctx)
		local ok = AntiVoid.restoreHeight()
		if not ctx:quiet() then
			ctx:reply(ok and "Destroy height restored" or "The destroy height was not changed by IY")
		end
	end,
}

return true
