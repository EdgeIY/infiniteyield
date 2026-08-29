--[[═══════════════════════════════════════════════════════════════════════════
	commands/teleport · going places
	─────────────────────────────────────────────────────────────────────────
	goto / tweengoto / vehiclegoto / pulsetp, the coordinate commands
	(tpposition, offset, thru, walktopos), the position readouts, and the
	gotopart family. Vehicle noclip lives here too because it shares
	features/teleport's "which vehicle am I in" lookup with vehiclegoto.

	All the actual moving is features/teleport; this file only turns typed
	arguments into calls on it.

	Legacy equivalent: source.ref.lua 9083-9209, 10276-10383 and 10938-11022 --
	twenty-one `addcmd` blocks that between them repeated the same nine-line
	"unsit, assign CFrame, break velocity" preamble.
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Cmd           = IY.import("cmd/api")
local Teleport      = IY.import("features/teleport")
local VehicleNoclip = IY.import("features/vehiclenoclip")
local Character     = IY.import("core/character")
local Env           = IY.import("core/env")
local Guard         = IY.import("core/guard")
local Str           = IY.import("core/util/strings")

local group = Cmd.group{ category = "Teleport" }

-- `;gotopartdelay` is a plain setting, like the fly speed multipliers.
local settings = { partDelay = 0.1 }

-- ── helpers ─────────────────────────────────────────────────────────────────

--[[ Luau's math.round, which Lua 5.1 does not have. ]]
local function round(value)
	if value >= 0 then return math.floor(value + 0.5) end
	return -math.floor(-value + 0.5)
end

--[[ "12, 40, -3" for a target, falling back to any part when the rig has no
     root yet -- the legacy `getposition` did the same, but with a `return
     notify(...)` inside its player loop, so one missing character silently
     skipped everybody after it. ]]
local function positionOf(target)
	local part = target.root
	if not part then
		local character = target.character
		part = character and character:FindFirstChildWhichIsA("BasePart") or nil
	end
	if not part then Guard.fail("%s has no character right now", target.name) end
	local position = part.Position
	return round(position.X) .. ", " .. round(position.Y) .. ", " .. round(position.Z)
end

--[[ `GetModelCFrame` (used by the legacy gotomodel) was removed from the
     engine; GetPivot is its replacement. ]]
local function modelFrame(model)
	local ok, pivot = pcall(function() return model:GetPivot() end)
	if ok and pivot then return pivot end
	local okBox, frame = pcall(function() return (model:GetBoundingBox()) end)
	if okBox then return frame end
	return nil
end

--[[ Teleport to every workspace descendant that matches, one after another,
     pausing `gotopartdelay` between them -- that is what the delay is for, and
     it is how you page through the twelve parts called "Door". ]]
local function gotoMatches(ctx, predicate, frameOf, tweened)
	local descendants = workspace:GetDescendants()
	local matches = 0
	for i = 1, #descendants do
		local instance = descendants[i]
		local ok, matched = pcall(predicate, instance)
		if ok and matched then
			matches = matches + 1
			Teleport.unseat()
			task.wait(settings.partDelay)
			-- The yields above can outlive the instance we matched.
			if instance.Parent then
				local frame = frameOf(instance)
				if frame then
					Teleport.to(frame, { tween = tweened and Teleport.tweenSpeed() or nil })
				end
			end
		end
	end
	if matches == 0 then ctx:fail("nothing in the workspace matched that") end
	return matches
end

local function namedPart(name)
	local needle = Str.lower(name)
	return function(instance)
		return instance:IsA("BasePart") and Str.lower(instance.Name) == needle
	end
end

local function namedModel(name)
	local needle = Str.lower(name)
	return function(instance)
		return instance:IsA("Model") and Str.lower(instance.Name) == needle
	end
end

local function partOfClass(className)
	local needle = Str.lower(className)
	return function(instance)
		return instance:IsA("BasePart") and Str.lower(instance.ClassName) == needle
	end
end

local function partFrame(instance) return instance.CFrame end

-- ── players ─────────────────────────────────────────────────────────────────

group{
	name = "goto",
	aliases = { "to" },
	description = "Teleports you next to a player.",
	args = {
		{ name = "player", type = "player" },
		{ name = "stream", type = "boolean", default = false },
	},
	examples = { "goto bob", "goto nearest", "goto bob true" },
	requires = { root = true },
	run = function(ctx)
		Teleport.toTarget(ctx.args.player, { unseat = true, stream = ctx.args.stream })
	end,
}

group{
	name = "tweengoto",
	aliases = { "tgoto", "tto", "tweento" },
	description = "Slides you over to a player instead of snapping.",
	args = { { name = "player", type = "player" } },
	examples = { "tgoto bob" },
	requires = { root = true },
	run = function(ctx)
		-- The legacy version disabled the Seated humanoid state around the
		-- tween and restored it on the same frame, which was a no-op; only the
		-- unsit and the flat Vector3(3, 1, 0) offset actually did anything.
		Teleport.toTarget(ctx.args.player, {
			unseat   = true,
			distance = 3,
			tween    = Teleport.tweenSpeed(),
		})
	end,
}

group{
	name = "vehiclegoto",
	aliases = { "vgoto", "vtp", "vehicletp" },
	description = "Teleports the vehicle you are sitting in to a player.",
	args = { { name = "player", type = "player" } },
	examples = { "vgoto bob" },
	requires = { character = true },
	run = function(ctx)
		Teleport.to(ctx.args.player:requireRoot():GetPivot(), { vehicle = true })
	end,
}

group{
	name = "pulsetp",
	aliases = { "ptp" },
	description = "Teleports to a player, waits, then puts you back.",
	args = {
		{ name = "players", type = "players" },
		{ name = "seconds", type = "time", default = 1, min = 0 },
	},
	examples = { "ptp bob", "ptp bob 3" },
	requires = { root = true },
	run = function(ctx)
		ctx:each(function(target)
			Teleport.pulse(target, { seconds = ctx.args.seconds })
		end)
	end,
}

-- ── vehicles ────────────────────────────────────────────────────────────────

group{
	name = "vehiclenoclip",
	aliases = { "vnoclip" },
	description = "Lets the vehicle you are sitting in pass through walls.",
	examples = { "vnoclip", "vclip" },
	requires = { character = true },
	offAliases = { "vehicleclip", "vclip", "unvnoclip", "novnoclip" },
	offDescription = "Restores collisions for you and your vehicle.",
	offArgs = {},
	run = function(ctx)
		VehicleNoclip.start()
		if not ctx:quiet() then ctx:reply("Vehicle noclip enabled") end
	end,
	off = function(ctx)
		VehicleNoclip.stop()
		if not ctx:quiet() then ctx:reply("Vehicle noclip disabled") end
	end,
}

group{
	name = "togglevnoclip",
	description = "Toggles vehicle noclip.",
	run = function(ctx)
		-- Legacy branched on the *plain* noclip flag here, so this turned normal
		-- noclip off whenever it happened to be on.
		VehicleNoclip.toggle()
	end,
}

-- ── coordinates ─────────────────────────────────────────────────────────────

group{
	name = "tpposition",
	aliases = { "tppos" },
	description = "Teleports you to a set of coordinates.",
	args = { { name = "position", type = "vector3", greedy = true } },
	examples = { "tppos 0 50 0", "tppos 12,4,-90" },
	requires = { root = true },
	run = function(ctx)
		Teleport.to(ctx.args.position)
	end,
}

group{
	name = "tweentpposition",
	aliases = { "ttppos" },
	description = "Slides you to a set of coordinates.",
	args = { { name = "position", type = "vector3", greedy = true } },
	examples = { "ttppos 0 50 0" },
	requires = { root = true },
	run = function(ctx)
		Teleport.to(ctx.args.position, { tween = Teleport.tweenSpeed() })
	end,
}

group{
	name = "offset",
	description = "Moves you by an amount, relative to where you are now.",
	args = { { name = "amount", type = "vector3", greedy = true } },
	examples = { "offset 0 10 0" },
	requires = { root = true },
	run = function(ctx)
		Character.require():TranslateBy(ctx.args.amount)
	end,
}

group{
	name = "tweenoffset",
	aliases = { "toffset" },
	description = "Slides you by an amount, relative to where you are now.",
	args = { { name = "amount", type = "vector3", greedy = true } },
	examples = { "toffset 0 10 0" },
	requires = { root = true },
	run = function(ctx)
		local root = Character.requireRoot()
		Teleport.to(CFrame.new(root.Position + ctx.args.amount),
			{ tween = Teleport.tweenSpeed() })
	end,
}

group{
	name = "thru",
	description = "Teleports you forward, through whatever is in front of you.",
	args = { { name = "studs", type = "number", default = 5 } },
	examples = { "thru", "thru 10" },
	requires = { root = true },
	run = function(ctx)
		local frame = Character.requireRoot().CFrame
		local position = frame.Position + (frame.LookVector * ctx.args.studs)
		Teleport.to(CFrame.new(position, position + frame.LookVector),
			{ breakVelocity = false })
	end,
}

group{
	name = "walktopos",
	aliases = { "walktoposition" },
	description = "Makes you walk to a set of coordinates.",
	args = { { name = "position", type = "vector3", greedy = true } },
	examples = { "walktopos 0 0 0" },
	requires = { character = true },
	run = function(ctx)
		Teleport.unseat()
		Character.requireHumanoid().WalkToPoint = ctx.args.position
	end,
}

-- ── readouts ────────────────────────────────────────────────────────────────

group{
	name = "getposition",
	aliases = { "getpos", "notifypos", "notifyposition" },
	description = "Shows a player's coordinates.",
	args = { { name = "players", type = "players" } },
	examples = { "getpos", "getpos bob" },
	run = function(ctx)
		ctx:each(function(target)
			local text = positionOf(target)
			if not target.isLocal then text = target.name .. ": " .. text end
			ctx:notify("Current Position", text)
		end)
	end,
}

group{
	name = "copyposition",
	aliases = { "copypos" },
	description = "Copies a player's coordinates to your clipboard.",
	args = { { name = "players", type = "players" } },
	examples = { "copypos", "copypos bob" },
	requires = { capability = "setclipboard" },
	run = function(ctx)
		-- Legacy called the clipboard once per player, so `;copypos all` left
		-- only the last one behind. One copy, one line each.
		local lines = {}
		ctx:each(function(target) lines[#lines + 1] = positionOf(target) end)
		if #lines == 0 then return end
		Env.fn.setclipboard(table.concat(lines, "\n"))
		ctx:notify("Clipboard", "Copied to clipboard")
	end,
}

-- ── parts and models ────────────────────────────────────────────────────────

group{
	name = "gotopart",
	aliases = { "topart" },
	description = "Teleports you to every part in the workspace with this name.",
	args = { { name = "name", type = "text" } },
	examples = { "gotopart Door" },
	requires = { root = true },
	run = function(ctx)
		gotoMatches(ctx, namedPart(ctx.args.name), partFrame, false)
	end,
}

group{
	name = "tweengotopart",
	aliases = { "tgotopart", "ttopart" },
	description = "Slides you to every part in the workspace with this name.",
	args = { { name = "name", type = "text" } },
	examples = { "tgotopart Door" },
	requires = { root = true },
	run = function(ctx)
		gotoMatches(ctx, namedPart(ctx.args.name), partFrame, true)
	end,
}

group{
	name = "gotopartclass",
	aliases = { "gpc" },
	description = "Teleports you to every part in the workspace of this class.",
	args = { { name = "class", type = "class" } },
	examples = { "gpc TrussPart", "gpc SpawnLocation" },
	requires = { root = true },
	run = function(ctx)
		gotoMatches(ctx, partOfClass(ctx.args.class), partFrame, false)
	end,
}

group{
	name = "tweengotopartclass",
	aliases = { "tgpc" },
	description = "Slides you to every part in the workspace of this class.",
	args = { { name = "class", type = "class" } },
	examples = { "tgpc TrussPart" },
	requires = { root = true },
	run = function(ctx)
		gotoMatches(ctx, partOfClass(ctx.args.class), partFrame, true)
	end,
}

group{
	name = "gotomodel",
	aliases = { "tomodel" },
	description = "Teleports you to every model in the workspace with this name.",
	args = { { name = "name", type = "text" } },
	examples = { "gotomodel Shop" },
	requires = { root = true },
	run = function(ctx)
		gotoMatches(ctx, namedModel(ctx.args.name), modelFrame, false)
	end,
}

group{
	name = "tweengotomodel",
	aliases = { "tgotomodel", "ttomodel" },
	description = "Slides you to every model in the workspace with this name.",
	args = { { name = "name", type = "text" } },
	examples = { "tgotomodel Shop" },
	requires = { root = true },
	run = function(ctx)
		gotoMatches(ctx, namedModel(ctx.args.name), modelFrame, true)
	end,
}

group{
	name = "gotopartdelay",
	description = "Sets how long gotopart waits at each match.",
	args = { { name = "delay", type = "time", default = 0.1, min = 0 } },
	examples = { "gotopartdelay 1" },
	run = function(ctx)
		settings.partDelay = ctx.args.delay
		ctx:reply("Gotopart delay set to " .. tostring(settings.partDelay))
	end,
}

return true
