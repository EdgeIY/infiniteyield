--[[═══════════════════════════════════════════════════════════════════════════
	commands/tools · tools, gear, hats and the build tools
	─────────────────────────────────────────────────────────────────────────
	Eighteen commands over three features. Legacy equivalent: source.ref.lua
	8845-8860, 10511-10552, 11106-11167, 11364-11448, 11449-11482 and
	11591-11640.

	What changed for the whole pack:

	  · nothing indexes `Backpack`, `.Character` or `Humanoid` directly any more.
	    Every legacy body in this range opened with one of those, so a player
	    with no backpack -- or one caught mid-respawn -- got a thrown error the
	    dispatcher swallowed, and the command merely appeared to do nothing.
	  · the bodies live in features/tools, features/grabtools and
	    features/toolremoval; this file declares arguments and reports counts.
	  · commands that reach other players go through `ctx:each`, so one player
	    leaving cannot abort the rest.
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Cmd         = IY.import("cmd/api")
local Tools       = IY.import("features/tools")
local GrabTools   = IY.import("features/grabtools")
local ToolRemoval = IY.import("features/toolremoval")
local ClickTP     = IY.import("features/clicktp")
local Env         = IY.import("core/env")
local Guard       = IY.import("core/guard")
local Sched       = IY.import("core/scheduler")
local Services    = IY.import("core/services")
local Inst        = IY.import("core/util/instances")
local Str         = IY.import("core/util/strings")

local Workspace = Services.Workspace

local group = Cmd.group{ category = "Tools" }

-- ── inventory ───────────────────────────────────────────────────────────────

group{
	name = "tools",
	aliases = { "gears" },
	description = "Copies every tool left lying in Lighting or ReplicatedStorage to you.",
	examples = { "tools" },
	run = function(ctx)
		local backpack = Tools.backpack(ctx.speaker:requirePlayer())
		if not backpack then ctx:fail("you have no backpack right now") end
		local copied = Tools.copyFrom(Services.Lighting, backpack)
			+ Tools.copyFrom(Services.ReplicatedStorage, backpack)
		if copied == 0 then
			ctx:fail("there are no tools in Lighting or ReplicatedStorage")
		end
		if not ctx:quiet() then
			ctx:notify("Tools", string.format(
				"Copied %d tool(s) from ReplicatedStorage and Lighting", copied))
		end
	end,
}

group{
	name = "notools",
	aliases = { "rtools", "clrtools", "removetools", "deletetools", "dtools" },
	description = "Deletes every tool a player is carrying.",
	-- Legacy took no argument at all and always meant you. Somebody else's
	-- backpack is not replicated to this client, so `notools all` can only clear
	-- the tools they are actually holding, and only in your own view.
	args = { { name = "players", type = "players", optional = true } },
	examples = { "notools", "notools all" },
	run = function(ctx)
		local removed = 0
		ctx:each(function(target)
			removed = removed + Tools.destroy(target:requirePlayer())
		end)
		if not ctx:quiet() then
			ctx:reply(string.format("Deleted %d tool(s)", removed))
		end
	end,
}

group{
	name = "deleteselectedtool",
	aliases = { "dst" },
	description = "Deletes the tool you are holding.",
	examples = { "deleteselectedtool" },
	requires = { character = true },
	run = function(ctx)
		local removed = Tools.destroyEquipped(ctx.speaker:requirePlayer())
		if removed == 0 then ctx:fail("you are not holding a tool") end
		if not ctx:quiet() then
			ctx:reply(string.format("Deleted %d held tool(s)", removed))
		end
	end,
}

-- ── equipping ───────────────────────────────────────────────────────────────

group{
	name = "equiptools",
	description = "Holds every tool in your backpack at once.",
	examples = { "equiptools", "unequiptools" },
	requires = { character = true },
	offDescription = "Unequips everything you are holding.",
	run = function(ctx)
		local equipped = Tools.equipAll(ctx.speaker:requirePlayer())
		if not ctx:quiet() then
			ctx:reply(string.format("Equipped %d tool(s)", equipped))
		end
	end,
	off = function(ctx)
		Tools.unequipAll(ctx.speaker:requirePlayer())
		if not ctx:quiet() then ctx:reply("Unequipped your tools") end
	end,
}

-- ── dropping and using ──────────────────────────────────────────────────────

group{
	name = "droptools",
	aliases = { "droptool" },
	description = "Drops every tool you are carrying on the floor.",
	examples = { "droptools" },
	requires = { character = true },
	run = function(ctx)
		local dropped = Tools.drop(ctx.speaker:requirePlayer())
		if dropped == 0 then ctx:fail("you have no tools to drop") end
		if not ctx:quiet() then
			ctx:reply(string.format("Dropped %d tool(s)", dropped))
		end
	end,
}

group{
	name = "droppabletools",
	description = "Lets you drop tools the game marked as undroppable.",
	examples = { "droppabletools" },
	run = function(ctx)
		local changed = Tools.droppable(ctx.speaker:requirePlayer())
		if changed == 0 then ctx:fail("you have no tools") end
		if not ctx:quiet() then
			ctx:reply(string.format("%d tool(s) can now be dropped", changed))
		end
	end,
}

group{
	name = "usetools",
	description = "Activates every tool you own, as many times as you ask.",
	args = {
		{ name = "amount", type = "integer", default = 1, min = 1, max = 1000 },
		{ name = "delay",  type = "time", optional = true, min = 0, max = 60 },
	},
	examples = { "usetools", "usetools 25", "usetools 25 0.5" },
	requires = { character = true },
	run = function(ctx)
		local used = Tools.use(ctx.speaker:requirePlayer(), ctx.args.amount, ctx.args.delay)
		if not ctx:quiet() then
			ctx:reply(string.format("Activating %d tool(s) %d time(s)", used, ctx.args.amount))
		end
	end,
}

-- ── duplicating ─────────────────────────────────────────────────────────────

group{
	name = "dupetools",
	aliases = { "clonetools" },
	description = "Duplicates your tools by dropping and re-collecting them across a respawn.",
	args = {
		{ name = "count", type = "integer", default = 1, min = 1, max = 100 },
	},
	examples = { "dupetools", "dupetools 5" },
	requires = { character = true, root = true, alive = true },
	run = function(ctx)
		-- The feature refuses to restart mid-run: it owns your character for the
		-- next few seconds per round, and a second pass would fight it.
		if not Tools.startDupe(ctx.args.count) then
			ctx:fail("dupetools is already running")
		end
		ctx:reply(string.format(
			"Duplicating your tools over %d round(s) -- this respawns you each round",
			ctx.args.count))
	end,
}

-- ── grabbing ────────────────────────────────────────────────────────────────

group{
	name = "grabtools",
	description = "Picks up every tool dropped anywhere in the game.",
	examples = { "grabtools", "nograbtools" },
	offDescription = "Stops picking up dropped tools.",
	run = function(ctx)
		GrabTools.start()
		if not ctx:quiet() then
			ctx:notify("Grabtools", "Picking up any dropped tools")
		end
	end,
	off = function(ctx)
		GrabTools.stop()
		if not ctx:quiet() then
			ctx:notify("Grabtools", "Grabtools has been disabled")
		end
	end,
}

-- ── removing by name ────────────────────────────────────────────────────────

group{
	name = "removespecifictool",
	description = "Deletes a tool from your backpack as fast as the game hands it to you.",
	args = {
		{ name = "tool", type = "tool" },
	},
	examples = { "removespecifictool Classic Sword", "unremovespecifictool Classic Sword" },
	-- One name is not a state you can sensibly flip, so no `toggle` sibling.
	toggle = false,
	offDescription = "Stops deleting one tool by name.",
	run = function(ctx)
		local name = ToolRemoval.add(ctx.args.tool)
		if not ctx:quiet() then
			ctx:reply("Deleting every '" .. name .. "' you are given")
		end
	end,
	off = function(ctx)
		local removed, name = ToolRemoval.remove(ctx.args.tool)
		if not removed then ctx:fail("'%s' is not being deleted", name) end
		if not ctx:quiet() then
			ctx:reply("No longer deleting '" .. name .. "'")
		end
	end,
}

group{
	name = "clearremovespecifictool",
	description = "Stops deleting every tool name you have listed.",
	examples = { "clearremovespecifictool" },
	run = function(ctx)
		local cleared = ToolRemoval.clear()
		if not ctx:quiet() then
			ctx:reply(string.format("Cleared %d tool name(s)", cleared))
		end
	end,
}

-- ── building tools ──────────────────────────────────────────────────────────

group{
	name = "btools",
	description = "Gives you the four HopperBin building tools.",
	examples = { "btools" },
	run = function(ctx)
		local made = Tools.buildTools(ctx.speaker:requirePlayer())
		if not ctx:quiet() then
			ctx:reply(string.format("Added %d build tool(s)", made))
		end
	end,
}

--[[ Third-party code: this downloads and runs F3X from the infyiff mirror,
     exactly as the legacy one-liner did. Nothing inside that script is ours, so
     the download, the compile and the call are reported separately instead of
     failing as one opaque `loadstring(game:HttpGet(...))()`. ]]
local F3X_URL = "https://raw.githubusercontent.com/infyiff/backup/refs/heads/main/f3x.lua"

group{
	name = "f3x",
	aliases = { "fex" },
	description = "Loads the F3X building tools.",
	examples = { "f3x" },
	requires = { capability = "loadstring" },
	run = function(ctx)
		local ok, body = pcall(function() return game:HttpGet(F3X_URL, true) end)
		if not ok then
			ctx:fail("could not download F3X (%s)", Guard.describe(body))
		end
		if type(body) ~= "string" or body == "" then
			ctx:fail("the F3X download came back empty")
		end
		local chunk, err = Env.fn.loadstring(body)
		if not chunk then ctx:fail("F3X would not compile (%s)", tostring(err)) end
		local ran, runError = Guard.call("f3x", chunk)
		if not ran then ctx:fail("F3X errored (%s)", Guard.describe(runError)) end
		if not ctx:quiet() then ctx:reply("F3X loaded") end
	end,
}

-- ── touch events ────────────────────────────────────────────────────────────

--[[ Every part in the workspace whose touch event we should fire. Legacy filter:

	 if v:IsA("TouchTransmitter") and v.Name:lower() == name or v.Parent.Name:lower() == name

     `and` binds tighter than `or`, so *any* instance whose parent happened to
     match the name went through, and firetouchinterest was then handed something
     that was not a part at all. Parenthesised here, with the parent checked for
     nil -- a transmitter whose part is being destroyed has none.

     Legacy also resolved the part with FindFirstAncestorWhichIsA("Part"), which
     skips MeshParts and unions and then fell through to `x.CFrame = Root.CFrame`
     on the nil it had just tested. BasePart covers what games actually build
     with, and a miss is skipped. ]]
local function touchParts(name)
	local out, seen = {}, {}
	local descendants = Workspace:GetDescendants()
	for i = 1, #descendants do
		local item = descendants[i]
		if item:IsA("TouchTransmitter") then
			local parent = item.Parent
			local matched = name == nil
				or Str.lower(item.Name) == name
				or (parent ~= nil and Str.lower(parent.Name) == name)
			local part = matched and item:FindFirstAncestorWhichIsA("BasePart") or nil
			if part and not seen[part] then
				seen[part] = true
				out[#out + 1] = part
			end
		end
	end
	return out
end

group{
	name = "touchinterests",
	aliases = { "touchinterest", "firetouchinterests", "firetouchinterest" },
	description = "Fires every touch event in the game at you, or only those on named parts.",
	args = { { name = "name", type = "text", optional = true } },
	examples = { "touchinterests", "touchinterests coin" },
	requires = { character = true, root = true, capability = "firetouchinterest" },
	run = function(ctx)
		local root = ctx.speaker:requireRoot()
		local name = ctx.args.name and Str.lower(ctx.args.name) or nil
		local parts = touchParts(name)
		if #parts == 0 then
			if name then ctx:fail("nothing named '%s' has a touch event", name) end
			ctx:fail("nothing in this game has a touch event")
		end

		-- One thread for the batch: legacy spawned a thread per transmitter,
		-- which in a large map meant thousands of them inside a single frame.
		local fire = Env.fn.firetouchinterest
		Sched.spawn("touchinterests", function()
			task.wait()
			for i = 1, #parts do pcall(fire, parts[i], root, 0) end
			task.wait()
			for i = 1, #parts do pcall(fire, parts[i], root, 1) end
		end)

		if not ctx:quiet() then
			ctx:reply(string.format("Fired %d touch event(s)", #parts))
		end
	end,
}

-- ── hats and appearance ─────────────────────────────────────────────────────

group{
	name = "drophats",
	aliases = { "drophat" },
	description = "Drops your hats on the floor.",
	examples = { "drophats" },
	requires = { character = true },
	run = function(ctx)
		local dropped = Tools.dropHats(ctx.speaker:requireCharacter())
		if dropped == 0 then ctx:fail("you are not wearing any accessories") end
		if not ctx:quiet() then
			ctx:reply(string.format("Dropped %d accessor%s", dropped,
				dropped == 1 and "y" or "ies"))
		end
	end,
}

group{
	name = "deletehats",
	aliases = { "nohats", "rhats" },
	description = "Unwelds your hats so they fall off.",
	examples = { "deletehats" },
	requires = { character = true },
	run = function(ctx)
		local broken = Tools.unweldHats(ctx.speaker:requireCharacter())
		if broken == 0 then ctx:fail("none of your accessories are welded on") end
		if not ctx:quiet() then
			ctx:reply(string.format("Unwelded %d accessory joint(s)", broken))
		end
	end,
}

group{
	name = "clearcharappearance",
	aliases = { "clearchar", "clrchar" },
	description = "Strips your character back to a plain blocky avatar.",
	examples = { "clearcharappearance" },
	requires = { character = true },
	run = function(ctx)
		local player = ctx.speaker:requirePlayer()
		local ok, err = pcall(function() player:ClearCharacterAppearance() end)
		if not ok then
			ctx:fail("could not clear your appearance (%s)", Guard.describe(err))
		end
		if not ctx:quiet() then ctx:reply("Cleared your character appearance") end
	end,
}

--[[ Legacy `partpath` (8858) opened the explorer's "To Part" panel and printed
     the path into a text box you then had to copy by hand. The path itself is
     the useful part, so it goes straight to the clipboard. ]]
group{
	name = "partpath",
	aliases = { "partname" },
	description = "Copies the full path of whatever your mouse is over.",
	examples = { "partpath" },
	requires = { capability = "setclipboard" },
	run = function(ctx)
		local mouse = ClickTP.mouse()
		local target = mouse and mouse.Target or nil
		if not target then ctx:fail("your mouse is not pointing at anything") end
		local path = Inst.path(target)
		Env.fn.setclipboard(path)
		ctx:notify("Part path", path)
	end,
}

return true
