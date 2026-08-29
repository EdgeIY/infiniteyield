--[[═══════════════════════════════════════════════════════════════════════════
	commands/parts · deleting, revealing, bringing and freezing world parts
	─────────────────────────────────────────────────────────────────────────
	lockws, delete, deleteclass, chardelete, chardeleteclass, deletevelocity,
	deleteinvisparts, invisibleparts, bringpart and bringpartclass, plus the
	unanchored-part trio (freezeunanchored, thawunanchored, tpunanchored) whose
	state lives in features/unanchored.

	Legacy equivalent: source.ref.lua 8766-8843, 10922-10936 and 12857-12958.
	Every search goes through features/parts, which walks workspace once per
	invocation instead of once per command as the legacy pack did, and nothing
	here scans on a timer.

	The four `delete*` commands are destructive by design and stay that way. What
	changed is that they cannot be *accidentally* destructive: the name arguments
	are required, so `;delete` on its own is rejected with a usage line instead of
	walking the whole workspace comparing every name against the empty string and
	then reporting `Deleted ` (8776-8780), and the class arguments are the
	validated `class` type, so `;dc Prat` says "'Prat' is not a Roblox class"
	instead of quietly matching nothing and claiming success.
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Cmd        = IY.import("cmd/api")
local Parts      = IY.import("features/parts")
local Unanchored = IY.import("features/unanchored")
local Character  = IY.import("core/character")
local Inst       = IY.import("core/util/instances")
local Str        = IY.import("core/util/strings")

local group = Cmd.group{ category = "World" }

--[[ Legacy `bringpart` moved every match with no ceiling (10922). Fifty is fine;
     five thousand welded parts landing on one CFrame stalls the client for
     seconds and, in games that let the client own those assemblies, drags the
     server with it. 250 covers every door/coin/spawner sweep anyone actually
     runs, and hitting the cap is reported rather than silently truncated. ]]
local BRING_LIMIT = 250

-- ── helpers ─────────────────────────────────────────────────────────────────

local function requireName(ctx, value)
	local name = Str.trim(tostring(value or ""))
	ctx:assert(name ~= "", "which name should I look for?")
	return name
end

local function say(ctx, text)
	if not ctx:quiet() then ctx:reply(text) end
end

--[[ Delete a list and say what went. Legacy notified "Deleted <name>" whether or
     not anything matched (8780), which is how `;delete Dor` looked like it had
     worked. ]]
local function purge(ctx, matches, label)
	if #matches == 0 then ctx:fail("nothing in the workspace matched '%s'", label) end
	local destroyed = Parts.destroy(matches)
	if not ctx:quiet() then
		ctx:notify("Item(s) deleted", string.format("Deleted %s matching '%s'",
			Str.pluralise(destroyed, "item"), label))
	end
	return destroyed
end

local function bring(ctx, matches, label)
	if #matches == 0 then ctx:fail("no part in the workspace matched '%s'", label) end
	local frame = Character.requireRoot().CFrame
	local moved = 0
	for i = 1, math.min(#matches, BRING_LIMIT) do
		local part = matches[i]
		-- The list was taken before the first write; parts can be streamed out
		-- while we work through it.
		if Inst.isAlive(part) and pcall(function() part.CFrame = frame end) then
			moved = moved + 1
		end
	end
	if ctx:quiet() then return moved end
	if #matches > BRING_LIMIT then
		ctx:reply(string.format("Moved %d of %d parts matching '%s' (capped at %d)",
			moved, #matches, label, BRING_LIMIT))
	else
		ctx:reply(string.format("Moved %s matching '%s'", Str.pluralise(moved, "part"), label))
	end
	return moved
end

-- ── the workspace ───────────────────────────────────────────────────────────

group{
	name = "lockws",
	aliases = { "lockworkspace" },
	description = "Locks every part in the workspace so build tools cannot select them.",
	examples = { "lockws", "unlockws" },
	-- Not routed through core/snapshot: `unlockws` is the inverse command and
	-- Locked has no effect beyond selection, so recording thousands of parts to
	-- hand a boolean back on unload would cost more than it is worth.
	offAliases = { "unlockworkspace" },
	offDescription = "Unlocks every part in the workspace.",
	toggle = false,
	run = function(ctx)
		local parts = Parts.parts()
		local locked = 0
		for i = 1, #parts do
			if pcall(function() parts[i].Locked = true end) then locked = locked + 1 end
		end
		say(ctx, string.format("Locked %s", Str.pluralise(locked, "part")))
	end,
	off = function(ctx)
		local parts = Parts.parts()
		local unlocked = 0
		for i = 1, #parts do
			if pcall(function() parts[i].Locked = false end) then unlocked = unlocked + 1 end
		end
		say(ctx, string.format("Unlocked %s", Str.pluralise(unlocked, "part")))
	end,
}

group{
	name = "delete",
	aliases = { "remove" },
	description = "Destroys everything in the workspace with that name.",
	args = {
		{ name = "name", type = "text" },
	},
	examples = { "delete Door", "remove Invisible Wall" },
	run = function(ctx)
		local name = requireName(ctx, ctx.args.name)
		purge(ctx, Parts.named(name), name)
	end,
}

group{
	name = "deleteclass",
	aliases = { "removeclass", "deleteclassname", "removeclassname", "dc" },
	description = "Destroys everything in the workspace of that class.",
	args = {
		{ name = "class", type = "class" },
	},
	examples = { "deleteclass Fire", "dc PointLight" },
	run = function(ctx)
		purge(ctx, Parts.ofClass(ctx.args.class), ctx.args.class)
	end,
}

-- ── characters ──────────────────────────────────────────────────────────────

--[[ Legacy walked `speaker.Character:GetDescendants()` with no nil check (8793),
     so `;cd Head` between death and respawn threw. `ctx:each` over a players
     argument that defaults to you keeps the old spelling working, gives the
     command a target list, and isolates a player who has no character right now
     instead of abandoning the rest. ]]
local function purgeCharacters(ctx, matcher, label)
	local destroyed = 0
	ctx:each(function(target)
		destroyed = destroyed + Parts.destroy(matcher(target:requireCharacter()))
	end)
	if destroyed == 0 then ctx:fail("nothing in that character matched '%s'", label) end
	if not ctx:quiet() then
		ctx:notify("Item(s) deleted", string.format("Deleted %s matching '%s'",
			Str.pluralise(destroyed, "item"), label))
	end
	return destroyed
end

group{
	name = "chardelete",
	aliases = { "charremove", "cd" },
	description = "Destroys everything in a character with that name.",
	args = {
		-- Name first so `;cd Head` still parses as a name. A name containing a
		-- space has to be quoted now that an argument follows it.
		{ name = "name",    type = "string" },
		{ name = "players", type = "players", optional = true },
	},
	examples = { "chardelete Hat", "cd \"Right Arm\"", "chardelete Hat bob" },
	run = function(ctx)
		local name = requireName(ctx, ctx.args.name)
		purgeCharacters(ctx, function(character)
			return Parts.named(name, character)
		end, name)
	end,
}

group{
	name = "chardeleteclass",
	aliases = { "charremoveclass", "chardeleteclassname", "charremoveclassname", "cdc" },
	description = "Destroys everything in a character of that class.",
	args = {
		{ name = "class",   type = "class" },
		{ name = "players", type = "players", optional = true },
	},
	examples = { "chardeleteclass Accessory", "cdc Shirt bob" },
	run = function(ctx)
		purgeCharacters(ctx, function(character)
			return Parts.ofClass(ctx.args.class, character)
		end, ctx.args.class)
	end,
}

group{
	name = "deletevelocity",
	aliases = { "dv", "removevelocity", "removeforces" },
	description = "Destroys the body movers and forces attached to a character.",
	args = {
		{ name = "players", type = "players", optional = true },
	},
	examples = { "deletevelocity", "dv bob" },
	run = function(ctx)
		local destroyed = 0
		ctx:each(function(target)
			destroyed = destroyed + Parts.destroy(Parts.forces(target:requireCharacter()))
		end)
		if destroyed == 0 then
			say(ctx, "No body movers or forces attached")
		else
			say(ctx, string.format("Removed %s", Str.pluralise(destroyed, "force")))
		end
	end,
}

-- ── invisible parts ─────────────────────────────────────────────────────────

group{
	name = "deleteinvisparts",
	aliases = { "deleteinvisibleparts", "dip" },
	description = "Destroys every invisible part you can still walk into.",
	examples = { "deleteinvisparts" },
	run = function(ctx)
		local matches = Parts.invisibleParts(true)
		if #matches == 0 then ctx:fail("no invisible collidable parts here") end
		local destroyed = Parts.destroy(matches)
		say(ctx, string.format("Deleted %s", Str.pluralise(destroyed, "invisible part")))
	end,
}

group{
	name = "invisibleparts",
	aliases = { "invisparts" },
	description = "Reveals every fully transparent part in the workspace.",
	examples = { "invisibleparts", "uninvisparts" },
	offAliases = { "uninvisparts" },
	run = function(ctx)
		local revealed, total = Parts.showInvisible()
		if ctx:quiet() then return end
		if total == 0 then ctx:reply("No invisible parts here") return end
		if revealed == 0 then
			ctx:reply(string.format("Already showing %s", Str.pluralise(total, "part")))
		else
			ctx:reply(string.format("Showing %s", Str.pluralise(total, "invisible part")))
		end
	end,
	off = function(ctx)
		local hidden = Parts.hideInvisible()
		say(ctx, string.format("Hid %s again", Str.pluralise(hidden, "part")))
	end,
}

-- ── bring ───────────────────────────────────────────────────────────────────

group{
	name = "bringpart",
	description = "Moves every part in the workspace with that name to you.",
	args = {
		{ name = "name", type = "text" },
	},
	examples = { "bringpart Coin", "bringpart Door" },
	requires = { character = true, root = true },
	run = function(ctx)
		local name = requireName(ctx, ctx.args.name)
		bring(ctx, Parts.partsNamed(name), name)
	end,
}

group{
	name = "bringpartclass",
	aliases = { "bpc" },
	description = "Moves every part in the workspace of that class to you.",
	args = {
		{ name = "class", type = "class" },
	},
	examples = { "bringpartclass MeshPart", "bpc TrussPart" },
	requires = { character = true, root = true },
	run = function(ctx)
		bring(ctx, Parts.partsOfClass(ctx.args.class), ctx.args.class)
	end,
}

-- ── unanchored parts ────────────────────────────────────────────────────────

group{
	name = "freezeunanchored",
	aliases = { "freezeua" },
	description = "Holds every unanchored part in the world where it is.",
	examples = { "freezeunanchored", "thawunanchored" },
	-- The generated off command is `unfreezeunanchored` (+ `nofreezeunanchored`);
	-- these are the names legacy shipped for the same thing.
	offAliases = { "thawunanchored", "thawua", "unfreezeua" },
	run = function(ctx)
		local frozen = Unanchored.freeze()
		say(ctx, string.format("Froze %s", Str.pluralise(frozen, "part")))
	end,
	off = function(ctx)
		local released = Unanchored.thaw()
		say(ctx, string.format("Thawed %s", Str.pluralise(released, "part")))
	end,
}

--[[ Legacy read `Players[v].Character.Head.Position` twice per part (12939,
     12955) after checking FindFirstChild('Head') once, and skipped the whole
     player when the rig had no Head. The root part is a fine fallback. ]]
local function dragPosition(target)
	local character = target:requireCharacter()
	local head = character:FindFirstChild("Head")
	if head and head:IsA("BasePart") then return head.Position end
	return target:requireRoot().Position
end

group{
	name = "tpunanchored",
	aliases = { "tpua" },
	description = "Drags every unanchored part in the world to a player.",
	args = {
		{ name = "players", type = "players", optional = true },
	},
	examples = { "tpunanchored", "tpua bob" },
	run = function(ctx)
		-- One target per pass, last one wins, exactly as legacy: it rebuilt the
		-- force set for every player in the list (12936).
		local dragged = 0
		ctx:each(function(target)
			dragged = Unanchored.teleport(dragPosition(target))
		end)
		say(ctx, string.format("Dragged %s (`;thawua` releases them)",
			Str.pluralise(dragged, "part")))
	end,
}

return true
