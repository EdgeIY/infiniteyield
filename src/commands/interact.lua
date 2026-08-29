--[[═══════════════════════════════════════════════════════════════════════════
	commands/interact · ClickDetectors and ProximityPrompts
	─────────────────────────────────────────────────────────────────────────
	noclickdetectorlimits, fireclickdetectors, noproximitypromptlimits,
	fireproximityprompts and instantproximityprompts (with the generated
	`uninstantproximityprompts`). All of the searching and the one piece of state
	live in features/prompts_interact.

	Legacy equivalent: source.ref.lua 11024-11100, six `addcmd` blocks that each
	walked the workspace themselves and each hand-checked `if fireclickdetector
	then ... else notify("Incompatible Exploit", ...)`. That check is
	`requires = { capability = ... }` now, so the message arrives before the
	command runs and names the executor.
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Cmd      = IY.import("cmd/api")
local Interact = IY.import("features/prompts_interact")
local Str      = IY.import("core/util/strings")

local group = Cmd.group{ category = "World" }

local function say(ctx, text)
	if not ctx:quiet() then ctx:reply(text) end
end

local function describeTarget(name)
	if name == nil or Str.trim(name) == "" then return "in the world" end
	return "matching '" .. Str.trim(name) .. "'"
end

--[[ `changed` counts the writes core/snapshot accepted; anything short of `found`
     is a detector whose MaxActivationDistance could not be read or written, which
     is worth saying rather than reporting a number that is quietly wrong. ]]
local function reportLimits(ctx, changed, found, label)
	if ctx:quiet() then return end
	if found == 0 then
		ctx:reply("This game has no " .. label .. "s")
		return
	end
	local text = string.format("Unlimited activation distance on %s", Str.pluralise(changed, label))
	if changed < found then
		text = text .. string.format(" (%d could not be changed)", found - changed)
	end
	ctx:reply(text)
end

-- ── activation distance ─────────────────────────────────────────────────────

group{
	name = "noclickdetectorlimits",
	aliases = { "nocdlimits", "removecdlimits" },
	description = "Lets you click every ClickDetector in the world from any distance.",
	examples = { "noclickdetectorlimits" },
	run = function(ctx)
		local changed, found = Interact.removeClickLimits()
		reportLimits(ctx, changed, found, "ClickDetector")
	end,
}

group{
	name = "noproximitypromptlimits",
	aliases = { "nopplimits", "removepplimits" },
	description = "Lets you trigger every ProximityPrompt in the world from any distance.",
	examples = { "noproximitypromptlimits" },
	run = function(ctx)
		local changed, found = Interact.removePromptLimits()
		reportLimits(ctx, changed, found, "ProximityPrompt")
	end,
}

-- ── firing ──────────────────────────────────────────────────────────────────

group{
	name = "fireclickdetectors",
	aliases = { "firecd", "firecds" },
	description = "Clicks every ClickDetector in the world, or only the ones you name.",
	args = {
		-- Optional: legacy branched on `args[1]` and fired everything when it was
		-- absent (11041). The name matches the detector or the part holding it.
		{ name = "name", type = "text", optional = true },
	},
	examples = { "fireclickdetectors", "firecd Door", "firecds Button" },
	requires = { capability = "fireclickdetector" },
	run = function(ctx)
		local fired, found = Interact.fireClickDetectors(ctx.args.name)
		if found == 0 then ctx:fail("no ClickDetector %s", describeTarget(ctx.args.name)) end
		say(ctx, string.format("Clicked %s %s",
			Str.pluralise(fired, "detector"), describeTarget(ctx.args.name)))
	end,
}

group{
	name = "fireproximityprompts",
	aliases = { "firepp" },
	description = "Triggers every ProximityPrompt in the world, or only the ones you name.",
	args = {
		{ name = "name", type = "text", optional = true },
	},
	examples = { "fireproximityprompts", "firepp Chest" },
	requires = { capability = "fireproximityprompt" },
	run = function(ctx)
		local fired, found = Interact.fireProximityPrompts(ctx.args.name)
		if found == 0 then ctx:fail("no ProximityPrompt %s", describeTarget(ctx.args.name)) end
		say(ctx, string.format("Triggered %s %s",
			Str.pluralise(fired, "prompt"), describeTarget(ctx.args.name)))
	end,
}

group{
	name = "instantproximityprompts",
	aliases = { "instantpp" },
	description = "Fires a proximity prompt the moment you press its key, with no hold.",
	examples = { "instantproximityprompts", "uninstantpp" },
	requires = { capability = "fireproximityprompt" },
	offAliases = { "uninstantpp" },
	run = function(ctx)
		Interact.startInstant()
		say(ctx, "Prompts now fire instantly")
	end,
	off = function(ctx)
		-- Safe when it was never started; that is the whole reason it is a feature.
		Interact.stopInstant()
		say(ctx, "Prompts hold normally again")
	end,
}

return true
