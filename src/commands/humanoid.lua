--[[═══════════════════════════════════════════════════════════════════════════
	commands/humanoid · speed, jump power, gravity, hip height, slope, density
	─────────────────────────────────────────────────────────────────────────
	The numeric knobs on a Humanoid, plus the two spoofs and the two loop
	re-appliers that live in features/humanoid.

	Every value arrives as a number from the type system. That is not cosmetic:
	`;speed all fast` used to assign the string "fast" to WalkSpeed, and
	`spoofspeed` handed `args[1]` -- a string -- back to any game script that
	read the property.

	Legacy equivalent: source.ref.lua 9756-9833, 10385-10509.
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Cmd      = IY.import("cmd/api")
local Players  = IY.import("core/players")
local Snapshot = IY.import("core/snapshot")
local Str      = IY.import("core/util/strings")
local Inst     = IY.import("core/util/instances")
local Humanoid = IY.import("features/humanoid")

local group = Cmd.group{ category = "Character" }

--[[ `;speed 100` and `;speed bob 100` both have to keep working: legacy read
     args[2] and fell back to args[1]. A bare number in the players slot means
     "you", and the value argument picks that number back up through its
     default, so neither shape needs a special case in `run`. ]]
Cmd.defineType("humanoidtargets", {
	multi = true,
	defaultWhenOptional = "me",
	describe = function() return "players" end,
	parse = function(raw, spec, ctx)
		local text = Str.trim(tostring(raw))
		if Str.toNumber(text) ~= nil then
			return { ctx and ctx.speaker or Players.me() }
		end
		return Players.require(text, ctx and ctx.speaker or nil)
	end,
	complete = function(partial) return Players.suggest(partial) end,
})

local function leadingNumber(ctx, fallback)
	local first = ctx.tokens and ctx.tokens[1] or nil
	local value = first and Str.toNumber(first) or nil
	if value then return value end
	return fallback
end

--[[ No lower bound on speed, jump power or gravity: negative values are all
     legal in the engine and legacy accepted them (walking backwards, falling
     upwards), so bounding them here would remove working behaviour. ]]

-- ── walk speed ──────────────────────────────────────────────────────────────

group{
	name = "speed",
	aliases = { "ws", "walkspeed" },
	description = "Sets how fast a player walks.",
	args = {
		{ name = "players", type = "humanoidtargets", optional = true },
		{ name = "speed", type = "number",
			default = function(ctx) return leadingNumber(ctx, 16) end },
	},
	examples = { "speed", "speed 100", "speed all 100" },
	run = function(ctx)
		ctx:each(function(target)
			target:requireHumanoid().WalkSpeed = ctx.args.speed
		end)
	end,
}

group{
	name = "spoofspeed",
	aliases = { "spoofws", "spoofwalkspeed" },
	description = "Reports a fake WalkSpeed to anything that reads it, without changing how fast you move.",
	args = { { name = "speed", type = "number", default = 16 } },
	examples = { "spoofspeed", "spoofspeed 16", "unspoofspeed" },
	requires = { character = true, capability = "hookmetamethod" },
	offAliases = { "unspoofws", "unspoofwalkspeed" },
	offArgs = {},
	run = function(ctx)
		local speed = ctx.args.speed or 16
		Humanoid.spoofspeed:start({ value = speed })
		if not ctx:quiet() then ctx:reply("WalkSpeed now reads as " .. tostring(speed)) end
	end,
	off = function(ctx)
		Humanoid.spoofspeed:stop()
		if not ctx:quiet() then ctx:reply("WalkSpeed reads normally again") end
	end,
}

group{
	name = "loopspeed",
	aliases = { "loopws" },
	description = "Re-applies a walk speed every time the game changes it.",
	args = { { name = "speed", type = "number", default = 16 } },
	examples = { "loopspeed 100", "unloopspeed" },
	requires = { character = true },
	offAliases = { "unloopws" },
	offArgs = {},
	run = function(ctx) Humanoid.loopspeed:start({ speed = ctx.args.speed or 16 }) end,
	off = function() Humanoid.loopspeed:stop() end,
}

-- ── jump power ──────────────────────────────────────────────────────────────

--[[ UseJumpPower decides which of the two properties the engine reads; writing
     the wrong one does nothing at all, which is why every command here asks. ]]
local function setJumpPower(humanoid, power)
	if humanoid.UseJumpPower then
		humanoid.JumpPower = power
	else
		humanoid.JumpHeight = power
	end
end

group{
	name = "jpower",
	aliases = { "jumppower", "jp" },
	description = "Sets how high you jump.",
	args = { { name = "power", type = "number", default = 50 } },
	examples = { "jpower 100", "jp" },
	requires = { character = true },
	run = function(ctx)
		setJumpPower(ctx.speaker:requireHumanoid(), ctx.args.power)
	end,
}

group{
	name = "spoofjumppower",
	aliases = { "spoofjp" },
	description = "Reports a fake JumpPower to anything that reads it.",
	args = { { name = "power", type = "number", default = 50 } },
	examples = { "spoofjumppower", "spoofjp 50", "unspoofjp" },
	requires = { character = true, capability = "hookmetamethod" },
	offAliases = { "unspoofjp" },
	offArgs = {},
	run = function(ctx)
		local power = ctx.args.power or 50
		Humanoid.spoofjumppower:start({ value = power })
		if not ctx:quiet() then ctx:reply("JumpPower now reads as " .. tostring(power)) end
	end,
	off = function(ctx)
		Humanoid.spoofjumppower:stop()
		if not ctx:quiet() then ctx:reply("JumpPower reads normally again") end
	end,
}

group{
	name = "loopjumppower",
	aliases = { "loopjp", "loopjpower" },
	description = "Re-applies a jump power every time the game changes it.",
	args = { { name = "power", type = "number", default = 50 } },
	examples = { "loopjumppower 200", "unloopjp" },
	requires = { character = true },
	offAliases = { "unloopjp", "unloopjpower" },
	offArgs = {},
	run = function(ctx) Humanoid.loopjumppower:start({ power = ctx.args.power or 50 }) end,
	off = function(ctx)
		Humanoid.loopjumppower:stop()
		-- Legacy's off-command also put the default back; keeping that means
		-- `;unloopjp` leaves you jumping normally rather than at 200.
		Humanoid.resetJumpPower(ctx.speaker.humanoid, 50)
	end,
}

-- ── world and posture ───────────────────────────────────────────────────────

group{
	name = "gravity",
	aliases = { "grav" },
	description = "Sets world gravity. With no value, puts the original back.",
	args = { { name = "gravity", type = "number", optional = true } },
	examples = { "gravity 50", "gravity", "ungravity" },
	toggle = false,
	offArgs = {},
	--[[ Legacy defaulted to the `oldgrav` global, which `swim` also owned and
	     overwrote, so the two commands handed each other the wrong value.
	     core/snapshot records the first writer's original and is the one place
	     either of them reads it back from. ]]
	run = function(ctx)
		if ctx.args.gravity == nil then
			Snapshot.restore(workspace, "Gravity")
			if not ctx:quiet() then ctx:reply("Gravity restored to " .. tostring(workspace.Gravity)) end
			return
		end
		Snapshot.set(workspace, "Gravity", ctx.args.gravity, "gravity")
	end,
	off = function(ctx)
		Snapshot.restore(workspace, "Gravity")
		if not ctx:quiet() then ctx:reply("Gravity restored to " .. tostring(workspace.Gravity)) end
	end,
}

group{
	name = "hipheight",
	aliases = { "hheight" },
	description = "Sets how far off the ground you stand.",
	args = {
		{ name = "height", type = "number",
			default = function(ctx) return Inst.isR15(ctx.speaker.character) and 2.1 or 0 end },
	},
	examples = { "hipheight 5", "hipheight" },
	requires = { character = true },
	run = function(ctx)
		ctx.speaker:requireHumanoid().HipHeight = ctx.args.height
	end,
}

group{
	name = "maxslopeangle",
	aliases = { "msa" },
	description = "Sets the steepest slope you can walk up.",
	args = { { name = "angle", type = "number", default = 89, min = 0, max = 89 } },
	examples = { "maxslopeangle", "msa 0" },
	requires = { character = true },
	run = function(ctx)
		ctx.speaker:requireHumanoid().MaxSlopeAngle = ctx.args.angle
	end,
}

-- ── part density ────────────────────────────────────────────────────────────

local MIN_DENSITY, MAX_DENSITY, DEFAULT_DENSITY = 0.01, 100, 0.7

--[[ Roblox only accepts 0.01-100. Legacy `weaken` passed `-args[1]`, which is
     out of range for every positive input, so clamping is what reproduces the
     observable result (parts as light as they can be) without throwing. ]]
local function clampDensity(value)
	if type(value) ~= "number" or value ~= value then return DEFAULT_DENSITY end
	if value < MIN_DENSITY then return MIN_DENSITY end
	if value > MAX_DENSITY then return MAX_DENSITY end
	return value
end

--[[ Legacy matched `child.ClassName == "Part"`, which skips every MeshPart --
     that is every limb of an R15 rig, so all three commands only ever did
     anything on R6. ]]
local function setDensity(character, value)
	local density = clampDensity(value)
	local count = 0
	for _, part in ipairs(character:GetDescendants()) do
		if part:IsA("BasePart") then
			local ok = pcall(function()
				part.CustomPhysicalProperties = PhysicalProperties.new(density, 0.3, 0.5)
			end)
			if ok then count = count + 1 end
		end
	end
	return count
end

group{
	name = "strengthen",
	description = "Makes your body parts heavy, so other physics gives way to you.",
	args = { { name = "density", type = "number", default = 100 } },
	examples = { "strengthen", "strengthen 50", "unstrengthen" },
	requires = { character = true },
	run = function(ctx)
		setDensity(ctx.speaker:requireCharacter(), ctx.args.density)
	end,
}

group{
	name = "weaken",
	description = "Makes your body parts as light as the engine allows.",
	args = { { name = "density", type = "number", default = 0 } },
	examples = { "weaken", "unweaken" },
	requires = { character = true },
	offAliases = { "unstrengthen", "nostrengthen" },
	offArgs = {},
	toggle = false,
	run = function(ctx)
		setDensity(ctx.speaker:requireCharacter(), -(ctx.args.density or 0))
	end,
	--[[ Shared with `strengthen` through the `unstrengthen` alias: both are
	     undone by putting the engine default back. ]]
	off = function(ctx)
		setDensity(ctx.speaker:requireCharacter(), DEFAULT_DENSITY)
	end,
}

return true
