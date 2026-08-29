--[[═══════════════════════════════════════════════════════════════════════════
	commands/jump · jump, infjump, flyjump, autojump, edgejump
	─────────────────────────────────────────────────────────────────────────
	Five commands and, through `off`, their fifteen legacy `un`/`no` spellings.
	All the state is in features/jump.

	Legacy equivalent: source.ref.lua 9949-10042 (eleven `addcmd` blocks, three
	file-level locals and two entries in the shared `HumanModCons` table).
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Cmd  = IY.import("cmd/api")
local Jump = IY.import("features/jump")

local group = Cmd.group{ category = "Movement" }

group{
	name = "jump",
	description = "Makes you jump once.",
	requires = { character = true },
	run = function(ctx)
		ctx.speaker:requireHumanoid():ChangeState(Enum.HumanoidStateType.Jumping)
	end,
}

group{
	name = "infjump",
	aliases = { "infinitejump" },
	description = "Lets you keep jumping in mid-air.",
	examples = { "infjump", "uninfjump" },
	requires = { character = true },
	offAliases = { "uninfinitejump", "noinfinitejump" },
	run = function() Jump.infjump:start() end,
	off = function() Jump.infjump:stop() end,
}

group{
	name = "flyjump",
	description = "Holding jump keeps re-jumping, so you climb.",
	examples = { "flyjump", "unflyjump" },
	requires = { character = true },
	run = function() Jump.flyjump:start() end,
	off = function() Jump.flyjump:stop() end,
}

group{
	name = "autojump",
	aliases = { "ajump" },
	description = "Jumps for you when you walk into something.",
	examples = { "autojump", "unautojump" },
	requires = { character = true },
	offAliases = { "noajump", "unajump" },
	run = function() Jump.autojump:start() end,
	off = function() Jump.autojump:stop() end,
}

group{
	name = "edgejump",
	aliases = { "ejump" },
	description = "Jumps for you when you walk off an edge.",
	examples = { "edgejump", "unedgejump" },
	requires = { character = true },
	offAliases = { "noejump", "unejump" },
	run = function() Jump.edgejump:start() end,
	off = function() Jump.edgejump:stop() end,
}

return true
