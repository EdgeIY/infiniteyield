--[[═══════════════════════════════════════════════════════════════════════════
	commands/performance · frame rate, rendering and world settings
	─────────────────────────────────────────────────────────────────────────
	antilag, setfpscap, datalimit, replicationlag, norender, noprompts,
	2022materials, removeterrain, clearnilinstances, promptr6, promptr15 and
	wallwalk -- plus the un/no/toggle siblings the registry derives, which is
	where the legacy `render`, `showprompts` and `un2022materials` blocks went.

	Legacy equivalent: source.ref.lua 8030-8104 (antilag, setfpscap), 8883-8925
	(datalimit, replicationlag, noprompts, showprompts, promptr6, promptr15,
	wallwalk), 9059-9081 (norender, render, 2022materials, un2022materials),
	12587-12599 (removeterrain, clearnilinstances).

	All of the state is in features/performance and features/prompts; the bugs
	each one fixes are listed in those headers.
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Cmd         = IY.import("cmd/api")
local Env         = IY.import("core/env")
local Guard       = IY.import("core/guard")
local Services    = IY.import("core/services")
local Str         = IY.import("core/util/strings")
local Performance = IY.import("features/performance")
local Prompts     = IY.import("features/prompts")

local group = Cmd.group{ category = "Performance" }

-- ── graphics ────────────────────────────────────────────────────────────────

group{
	name = "antilag",
	aliases = { "boostfps", "lowgraphics" },
	description = "Strips the game's graphics back to raise your frame rate.",
	examples = { "antilag", "unantilag" },
	run = function(ctx)
		Performance.antilag:start({})
		if not ctx:quiet() then
			ctx:notify("Anti Lag", "Graphics stripped back. Effects that were deleted"
				.. " (fire, smoke, beams) do not come back.")
		end
	end,
	off = function(ctx)
		Performance.antilag:stop()
		if not ctx:quiet() then ctx:notify("Anti Lag", "Graphics restored") end
	end,
}

--[[ Legacy fell back to a `while true do end` busy loop when the executor had no
     setfpscap (8094), which pinned a core and could only be stopped by running
     the command again. `requires` reports the missing function instead.

     `;setfpscap none` used to reach `tonumber("none") or 1e6` and uncap by
     accident -- the `num == "none"` test at 8083 compared a number to a string
     and could never be true. `;setfpscap` with no argument and `;unsetfpscap`
     both do that deliberately now. ]]
group{
	name = "setfpscap",
	aliases = { "fpscap", "maxfps" },
	description = "Caps your frame rate. With no number, removes the cap.",
	args = {
		{ name = "fps", type = "number", optional = true, min = 1 },
	},
	examples = { "setfpscap 60", "setfpscap", "unfpscap" },
	requires = { capability = "setfpscap" },
	offArgs = {},
	offAliases = { "unfpscap", "nofpscap", "uncapfps" },
	offDescription = "Removes the frame rate cap.",
	run = function(ctx)
		Performance.fpscap:start({ fps = ctx.args.fps })
		if ctx:quiet() then return end
		if ctx.args.fps then
			ctx:reply("Frame rate capped at " .. tostring(ctx.args.fps))
		else
			ctx:reply("Frame rate uncapped")
		end
	end,
	off = function(ctx)
		Performance.fpscap:stop()
		if not ctx:quiet() then ctx:reply("Frame rate uncapped") end
	end,
}

group{
	name = "norender",
	description = "Switches 3D rendering off. The UI still works.",
	examples = { "norender", "render" },
	-- `render` is the legacy name for the off half of this pair.
	offAliases = { "render" },
	offDescription = "Switches 3D rendering back on.",
	run = function(ctx)
		Performance.norender:start({})
		if not ctx:quiet() then ctx:reply("3D rendering off") end
	end,
	off = function(ctx)
		Performance.norender:stop()
		if not ctx:quiet() then ctx:reply("3D rendering on") end
	end,
}

--[[ `sethiddenproperty` has no readable counterpart that core/snapshot can hold,
     so the off half writes `false` -- which is the engine default, and what
     legacy's `un2022materials` did (9075). ]]
local function set2022Materials(enabled)
	local service = Services.get("MaterialService")
	if not service then Guard.fail("your client has no MaterialService") end
	local ok, err = pcall(Env.fn.sethiddenproperty, service, "Use2022Materials", enabled)
	if not ok then Guard.fail("could not write Use2022Materials (%s)", tostring(err)) end
	return true
end

group{
	name = "2022materials",
	aliases = { "use2022materials" },
	description = "Renders the world with the 2022 material pack.",
	examples = { "2022materials", "un2022materials" },
	requires = { capability = "sethiddenproperty" },
	offRequires = { capability = "sethiddenproperty" },
	offAliases = { "unuse2022materials" },
	offDescription = "Renders the world with the current material pack again.",
	run = function(ctx)
		set2022Materials(true)
		if not ctx:quiet() then ctx:reply("2022 materials on") end
	end,
	off = function(ctx)
		set2022Materials(false)
		if not ctx:quiet() then ctx:reply("2022 materials off") end
	end,
}

-- ── network ─────────────────────────────────────────────────────────────────

group{
	name = "datalimit",
	description = "Throttles how much data your client sends, in KB/s.",
	args = {
		-- Legacy silently did nothing when the argument was not a number (8884).
		{ name = "kbps", type = "number", min = 1 },
	},
	examples = { "datalimit 50", "undatalimit" },
	offArgs = {},
	offDescription = "Removes the outgoing data limit.",
	run = function(ctx)
		Performance.datalimit:start({ kbps = ctx.args.kbps })
		if not ctx:quiet() then
			ctx:reply("Outgoing data limited to " .. tostring(ctx.args.kbps) .. " KB/s")
		end
	end,
	off = function(ctx)
		Performance.datalimit:stop()
		if not ctx:quiet() then ctx:reply("Outgoing data limit removed") end
	end,
}

group{
	name = "replicationlag",
	aliases = { "backtrack" },
	description = "Delays everything the server sends you, in seconds.",
	args = {
		-- Legacy assigned the raw argument string to the property (8892).
		{ name = "seconds", type = "number", min = 0, max = 60 },
	},
	examples = { "replicationlag 0.5", "unbacktrack" },
	offArgs = {},
	offAliases = { "unbacktrack", "nobacktrack" },
	offDescription = "Stops delaying what the server sends you.",
	run = function(ctx)
		Performance.replicationlag:start({ seconds = ctx.args.seconds })
		if not ctx:quiet() then
			ctx:reply("Incoming replication delayed by " .. tostring(ctx.args.seconds) .. "s")
		end
	end,
	off = function(ctx)
		Performance.replicationlag:stop()
		if not ctx:quiet() then ctx:reply("Replication lag removed") end
	end,
}

-- ── the client's own prompts ────────────────────────────────────────────────

group{
	name = "noprompts",
	aliases = { "nopurchaseprompts" },
	description = "Hides Roblox purchase prompts.",
	examples = { "noprompts", "showprompts" },
	offAliases = { "showprompts", "showpurchaseprompts" },
	offDescription = "Shows Roblox purchase prompts again.",
	run = function(ctx)
		Prompts.setPurchasePrompts(false)
		if not ctx:quiet() then ctx:reply("Purchase prompts hidden") end
	end,
	off = function(ctx)
		Prompts.setPurchasePrompts(true)
		if not ctx:quiet() then ctx:reply("Purchase prompts shown") end
	end,
}

--[[ Legacy `promptNewRig` indexed the character with no nil check and then waited
     on the completion event forever (8904-8913). ]]
local function promptRig(ctx, rig)
	local ok, reason = Prompts.promptRig(rig)
	if not ok then ctx:fail("%s", tostring(reason)) end
	if not ctx:quiet() then ctx:reply("Saved your avatar as " .. rig) end
end

group{
	name = "promptr6",
	description = "Asks Roblox to save your avatar as R6, then respawns you.",
	requires = { character = true },
	run = function(ctx) promptRig(ctx, "R6") end,
}

group{
	name = "promptr15",
	description = "Asks Roblox to save your avatar as R15, then respawns you.",
	requires = { character = true },
	run = function(ctx) promptRig(ctx, "R15") end,
}

-- ── the world ───────────────────────────────────────────────────────────────

group{
	name = "removeterrain",
	aliases = { "rterrain", "noterrain" },
	description = "Clears the game's terrain on your client.",
	examples = { "removeterrain" },
	run = function(ctx)
		Performance.clearTerrain()
		if not ctx:quiet() then ctx:reply("Terrain cleared") end
	end,
}

group{
	name = "clearnilinstances",
	aliases = { "nonilinstances", "cni" },
	description = "Destroys every instance that has been left with no parent.",
	examples = { "clearnilinstances" },
	requires = { capability = "getnilinstances" },
	run = function(ctx)
		local destroyed, found = Performance.clearNilInstances()
		if not ctx:quiet() then
			ctx:reply("Destroyed " .. Str.pluralise(destroyed, "parentless instance")
				.. " of " .. tostring(found))
		end
	end,
}

--[[ The fetched script owns its own loop, so IY cannot stop it: the feature only
     guarantees that one copy is running. Legacy loadstring'd the same URL with no
     state at all (8923), so a second `;wallwalk` started a second copy. ]]
group{
	name = "wallwalk",
	aliases = { "walkonwalls" },
	description = "Loads the wall-walking script so you can walk up walls.",
	examples = { "wallwalk" },
	requires = { capability = "loadstring", character = true },
	singleton = true,
	run = function(ctx)
		if Performance.wallwalk:isRunning() then
			ctx:reply("Wall walking is already running (rejoin to stop it)")
			return
		end
		Performance.wallwalk:start({})
		if not ctx:quiet() then
			ctx:reply("Wall walking loaded. It cannot be unloaded -- rejoin to stop it.")
		end
	end,
}

return true
