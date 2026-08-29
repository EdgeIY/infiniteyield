--[[═══════════════════════════════════════════════════════════════════════════
	commands/character · the character pack
	─────────────────────────────────────────────────────────────────────────
	Respawning, freezing, posture, limb removal, hitboxes and the four character
	swaps (god, invisible, toolinvisible, replaceroot). Every stateful one of
	them is a features/* module; this file only declares the commands.

	Three legacy behaviours are deliberately not reproduced, and each is marked
	where it happens:

	  · `god` referenced two globals that were never assigned and destroyed your
	    Humanoid before erroring, leaving you with no character (features/god)
	  · `invisible` defined its restore path as globals inside the command body,
	    so `;visible` on its own nil-called them (features/invisible)
	  · `headsize` and `hitbox` changed other players' parts with no record of
	    the original, so they could never be undone (core/snapshot, tag "hitbox")

	Legacy equivalent: source.ref.lua 9434-9755, 9853-9947, 11202-11216,
	11320-11362, 11559-11589, 12349-12396.
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Cmd       = IY.import("cmd/api")
local Character = IY.import("core/character")
local Snapshot  = IY.import("core/snapshot")
local Sched     = IY.import("core/scheduler")
local Guard     = IY.import("core/guard")
local Inst      = IY.import("core/util/instances")
local God       = IY.import("features/god")
local Invisible = IY.import("features/invisible")
local ToolInvis = IY.import("features/toolinvisible")
local States    = IY.import("features/states")
local Loopoof   = IY.import("features/loopoof")
local Boombox   = IY.import("features/muteboombox")

local group = Cmd.group{ category = "Character" }

--[[ headsize and hitbox share one tag, so either off-command puts back
     everything both of them touched. ]]
local HITBOX_TAG = "hitbox"
local DEFAULT_PART_SIZE = Vector3.new(2, 1, 1)

-- ── respawning ──────────────────────────────────────────────────────────────

--[[ Invisibility parks your real character in Lighting, and respawning while it
     is parked loses it -- which is why the legacy `respawn()` called
     `TurnVisible()` first. Stopping a feature that is not running is free. ]]
local function leaveInvisible()
	Invisible.stop()
end

group{
	name = "respawn",
	description = "Kills you so the game hands you a new character.",
	requires = { character = true },
	run = function(ctx)
		leaveInvisible()
		local ok, reason = Character.respawn()
		if not ok then ctx:fail("%s", tostring(reason)) end
	end,
}

group{
	name = "refresh",
	aliases = { "re" },
	description = "Respawns you and puts you back where you were standing.",
	requires = { character = true },
	run = function(ctx)
		leaveInvisible()
		local ok, reason = Character.refresh()
		if not ok then ctx:fail("%s", tostring(reason)) end
	end,
}

group{
	name = "reset",
	description = "Resets your character the way the Roblox menu does.",
	requires = { character = true },
	run = function(ctx)
		local character = ctx.speaker:requireCharacter()
		local humanoid = ctx.speaker.humanoid
		if humanoid then
			humanoid:ChangeState(Enum.HumanoidStateType.Dead)
		else
			character:BreakJoints()
		end
	end,
}

group{
	name = "god",
	description = "Swaps in a Humanoid the server cannot damage.",
	examples = { "god", "ungod" },
	requires = { character = true, alive = true },
	run = function(ctx)
		God.start()
		if not ctx:quiet() then ctx:reply("Damage no longer applies to you") end
	end,
	off = function(ctx)
		God.stop()
		if not ctx:quiet() then ctx:reply("You can be damaged again") end
	end,
}

-- ── freeze / anchor ─────────────────────────────────────────────────────────

--[[ `IY_` parts belong to another feature -- float's platform is anchored on
     purpose -- and the legacy thaw skipped them through the `floatName`
     global. ]]
local function setAnchored(character, anchored)
	local count = 0
	for _, part in ipairs(character:GetDescendants()) do
		if part:IsA("BasePart") and part.Anchored ~= anchored
			and (anchored or string.sub(part.Name, 1, 3) ~= "IY_") then
			if pcall(function() part.Anchored = anchored end) then count = count + 1 end
		end
	end
	return count
end

group{
	name = "freeze",
	aliases = { "fr" },
	description = "Anchors a player where they stand.",
	args = { { name = "players", type = "players", optional = true } },
	examples = { "freeze bob", "thaw bob" },
	toggle = false,
	offAliases = { "thaw", "unfr" },
	run = function(ctx)
		ctx:each(function(target) setAnchored(target:requireCharacter(), true) end)
	end,
	off = function(ctx)
		ctx:each(function(target) setAnchored(target:requireCharacter(), false) end)
	end,
}

group{
	name = "anchor",
	description = "Anchors your root part only, so you hold position but still animate.",
	requires = { character = true, root = true },
	toggle = false,
	run = function(ctx) ctx.speaker:requireRoot().Anchored = true end,
	off = function(ctx) ctx.speaker:requireRoot().Anchored = false end,
}

group{
	name = "breakvelocity",
	description = "Zeroes the velocity of every part of your character for a second.",
	requires = { character = true },
	run = function(ctx)
		--[[ A labelled loop, so running the command again replaces the first one
		     instead of leaving two of them fighting. Legacy used a `delay(1)`
		     against a local flag with a `while ... wait()` loop, which kept
		     running if the character went away. ]]
		local handle = Sched.frameLoop("breakvelocity.step", function()
			Inst.breakVelocity(Character.get())
		end, "heartbeat")
		Sched.after(1, function() handle:stop() end, "breakvelocity.stop")
	end,
}

-- ── sounds ──────────────────────────────────────────────────────────────────

group{
	name = "loopoof",
	description = "Keeps every player's head sounds playing.",
	examples = { "loopoof", "unloopoof" },
	run = function() Loopoof.start() end,
	off = function() Loopoof.stop() end,
}

group{
	name = "muteboombox",
	description = "Stops every sound a player is playing.",
	args = { { name = "players", type = "players", optional = true } },
	examples = { "muteboombox all", "unmuteboombox bob" },
	toggle = false,
	run = function(ctx)
		ctx:each(function(target) Boombox.mute(target) end)
	end,
	off = function(ctx)
		ctx:each(function(target) Boombox.unmute(target) end)
	end,
}

-- ── the character swaps ─────────────────────────────────────────────────────

group{
	name = "invisible",
	aliases = { "invis" },
	description = "Makes you appear invisible to other players.",
	examples = { "invisible", "visible" },
	requires = { character = true, root = true },
	toggle = false,        -- `toggleinvis` below carries the legacy name too
	offAliases = { "visible", "vis" },
	run = function(ctx)
		Invisible.start()
		if not ctx:quiet() then
			ctx:notify("Invisible", "You now appear invisible to other players")
		end
	end,
	off = function(ctx)
		Invisible.stop()
		if not ctx:quiet() then ctx:notify("Invisible", "You are visible again") end
	end,
}

group{
	name = "toggleinvis",
	aliases = { "toggleinvisible" },
	description = "Toggles invisibility.",
	run = function(ctx)
		if Invisible.isRunning() then
			Invisible.stop()
		else
			Invisible.start()
		end
	end,
}

group{
	name = "toolinvisible",
	aliases = { "toolinvis", "tinvis" },
	description = "Hides the tool you are holding by swapping your root part.",
	examples = { "toolinvisible", "untoolinvis" },
	requires = { character = true, root = true },
	offAliases = { "untoolinvis", "notoolinvis", "untinvis", "notinvis" },
	run = function() ToolInvis.start() end,
	off = function() ToolInvis.stop() end,
}

-- ── posture ─────────────────────────────────────────────────────────────────

group{
	name = "sit",
	description = "Sits down.",
	requires = { character = true },
	run = function(ctx) ctx.speaker:requireHumanoid().Sit = true end,
}

group{
	name = "lay",
	aliases = { "laydown" },
	description = "Lies down on the floor.",
	requires = { character = true, alive = true },
	run = function(ctx)
		local humanoid = ctx.speaker:requireHumanoid()
		humanoid.Sit = true
		task.wait(0.1)
		-- Re-read the root: sitting can reparent or replace it.
		local root = ctx.speaker.root
		if root then
			root.CFrame = root.CFrame * CFrame.Angles(math.pi * 0.5, 0, 0)
		end
		local tracks = Guard.try(function() return humanoid:GetPlayingAnimationTracks() end) or {}
		for i = 1, #tracks do
			pcall(function() tracks[i]:Stop() end)
		end
	end,
}

group{
	name = "sitwalk",
	description = "Uses the sitting animation for walking, running and jumping.",
	examples = { "sitwalk", "unsitwalk" },
	requires = { character = true },
	run = function() States.sitwalk:start() end,
	off = function() States.sitwalk:stop() end,
}

group{
	name = "nosit",
	description = "Stops you being seated, so seats and vehicles cannot hold you.",
	examples = { "nosit", "unnosit" },
	requires = { character = true },
	run = function() States.set(Enum.HumanoidStateType.Seated, false) end,
	off = function() States.clear(Enum.HumanoidStateType.Seated) end,
}

group{
	name = "stun",
	aliases = { "platformstand" },
	description = "Puts you in PlatformStand, so you cannot move or stand up.",
	examples = { "stun", "unstun" },
	requires = { character = true },
	offAliases = { "unplatformstand", "noplatformstand" },
	run = function() States.stun:start() end,
	off = function() States.stun:stop() end,
}

group{
	name = "norotate",
	aliases = { "noautorotate" },
	description = "Stops your character turning to face the way you walk.",
	examples = { "norotate", "unnorotate" },
	requires = { character = true },
	offAliases = { "autorotate" },
	run = function() States.norotate:start() end,
	off = function() States.norotate:stop() end,
}

group{
	name = "freezeanims",
	description = "Freezes every animation your character plays.",
	examples = { "freezeanims", "unfreezeanims" },
	requires = { character = true },
	run = function() States.freezeanims:start() end,
	off = function() States.freezeanims:stop() end,
}

--[[ `enumitem` gives these two autocomplete over the real enum. The legacy
     versions passed the raw argument string through a shadowed local, so they
     only ever worked by accident, on the names Roblox happens to coerce.
     A fresh spec per command: the registry normalises specs in place. ]]
local function stateArg()
	return {
		name = "state", type = "enumitem",
		enum = Enum.HumanoidStateType, enumName = "HumanoidStateType",
	}
end

group{
	name = "enablestate",
	description = "Re-enables one humanoid state.",
	args = { stateArg() },
	examples = { "enablestate Jumping" },
	requires = { character = true },
	run = function(ctx) States.set(ctx.args.state, true) end,
}

group{
	name = "disablestate",
	description = "Disables one humanoid state.",
	args = { stateArg() },
	examples = { "disablestate Jumping", "disablestate Seated" },
	requires = { character = true },
	run = function(ctx) States.set(ctx.args.state, false) end,
}

-- ── taking your character apart ─────────────────────────────────────────────

local LIMB_NAMES = {
	arms = {
		R15 = { "RightUpperArm", "LeftUpperArm" },
		R6  = { "Right Arm", "Left Arm" },
	},
	legs = {
		R15 = { "RightUpperLeg", "LeftUpperLeg" },
		R6  = { "Right Leg", "Left Leg" },
	},
}

--[[ Legacy wrote `if v:IsA("BasePart") and v.Name == "A" or v.Name == "B"`,
     which Lua reads as `(IsA and Name == "A") or Name == "B"` -- so anything at
     all called "Left Arm" was destroyed, BasePart or not. The name set makes
     the precedence impossible to get wrong. ]]
local function removeLimbs(character, groups)
	local rig = Inst.isR15(character) and "R15" or "R6"
	local wanted = {}
	for i = 1, #groups do
		local names = LIMB_NAMES[groups[i]][rig]
		for j = 1, #names do wanted[names[j]] = true end
	end
	local removed = 0
	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("BasePart") and wanted[child.Name] then
			if pcall(function() child:Destroy() end) then removed = removed + 1 end
		end
	end
	return removed
end

group{
	name = "nolimbs",
	aliases = { "rlimbs" },
	description = "Removes your arms and legs.",
	requires = { character = true },
	run = function(ctx) removeLimbs(ctx.speaker:requireCharacter(), { "arms", "legs" }) end,
}

group{
	name = "noarms",
	aliases = { "rarms" },
	description = "Removes your arms.",
	requires = { character = true },
	run = function(ctx) removeLimbs(ctx.speaker:requireCharacter(), { "arms" }) end,
}

group{
	name = "nolegs",
	aliases = { "rlegs" },
	description = "Removes your legs.",
	requires = { character = true },
	run = function(ctx) removeLimbs(ctx.speaker:requireCharacter(), { "legs" }) end,
}

group{
	name = "naked",
	description = "Removes your shirt, pants and t-shirt.",
	requires = { character = true },
	run = function(ctx)
		for _, item in ipairs(ctx.speaker:requireCharacter():GetDescendants()) do
			if item:IsA("Clothing") or item:IsA("ShirtGraphic") then
				pcall(function() item:Destroy() end)
			end
		end
	end,
}

group{
	name = "noface",
	aliases = { "removeface" },
	description = "Removes your face.",
	requires = { character = true },
	run = function(ctx)
		for _, item in ipairs(ctx.speaker:requireCharacter():GetDescendants()) do
			if item:IsA("Decal") and item.Name == "face" then
				pcall(function() item:Destroy() end)
			end
		end
	end,
}

group{
	name = "split",
	description = "Destroys the waist joint, so your torso comes apart.",
	requires = { character = true },
	run = function(ctx)
		local character = ctx.speaker:requireCharacter()
		ctx:assert(Inst.isR15(character), "this command needs an R15 rig")
		local torso = character:FindFirstChild("UpperTorso")
		local waist = torso and torso:FindFirstChild("Waist")
		ctx:assert(waist ~= nil, "your rig has no Waist joint")
		waist:Destroy()
	end,
}

group{
	name = "nilchar",
	description = "Takes your character out of the world without destroying it.",
	examples = { "nilchar", "unnilchar" },
	requires = { character = true },
	run = function(ctx) ctx.speaker:requireCharacter().Parent = nil end,
	off = function(ctx) ctx.speaker:requireCharacter().Parent = workspace end,
}

group{
	name = "noroot",
	aliases = { "removeroot", "rroot" },
	description = "Destroys your root part.",
	requires = { character = true, root = true },
	run = function(ctx)
		local character = ctx.speaker:requireCharacter()
		local root = ctx.speaker:requireRoot()
		-- Out of the world first, so the server does not see the rig without a
		-- root; legacy hard-coded the way back to Workspace instead of keeping
		-- the parent it actually had.
		local parent = character.Parent
		character.Parent = nil
		root:Destroy()
		character.Parent = parent or workspace
	end,
}

group{
	name = "replaceroot",
	aliases = { "replacerootpart" },
	description = "Swaps your root part for an identical copy.",
	requires = { character = true, root = true },
	run = function(ctx)
		local character = ctx.speaker:requireCharacter()
		local root = ctx.speaker:requireRoot()
		local parent = character.Parent
		local where = root.CFrame

		character.Parent = game
		-- Contained: whatever happens, the character goes back in the world. The
		-- legacy version would have left it parented to `game` on any error.
		local ok, err = Guard.call("replaceroot", function()
			local replacement = root:Clone()
			replacement.Parent = character
			root:Destroy()
			replacement.CFrame = where
		end)
		character.Parent = parent or workspace
		if not ok then error(err, 0) end
	end,
}

-- ── hitboxes ────────────────────────────────────────────────────────────────

--[[ Every size, collision and transparency change goes through core/snapshot
     under one tag. Legacy wrote these straight onto other players' parts with
     no record at all, so `;headsize all 10` was permanent for the session. ]]
local function resizePart(part, size, transparency)
	Snapshot.set(part, "CanCollide", false, HITBOX_TAG)
	Snapshot.set(part, "Size", size, HITBOX_TAG)
	if transparency ~= nil then
		Snapshot.set(part, "Transparency", transparency, HITBOX_TAG)
	end
end

--[[ A size of 1 means "put it back to normal", which is what the legacy
     `if not args[2] or sizeArg == 1` branch did. ]]
local function sizeVector(size)
	if size == 1 then return DEFAULT_PART_SIZE end
	return Vector3.new(size, size, size)
end

group{
	name = "headsize",
	description = "Resizes another player's head, so it is easier to hit.",
	args = {
		{ name = "players", type = "players", excludeSelf = true },
		{ name = "size", type = "number", default = 1, min = 0 },
	},
	examples = { "headsize all 10", "unheadsize" },
	toggle = false,
	offArgs = {},
	run = function(ctx)
		local size = sizeVector(ctx.args.size or 1)
		ctx:each(function(target)
			local head = target:requireCharacter():FindFirstChild("Head")
			if not head or not head:IsA("BasePart") then
				ctx:fail("%s has no head", target.name)
			end
			resizePart(head, size, nil)
		end)
	end,
	off = function() Snapshot.restoreTag(HITBOX_TAG) end,
	offDescription = "Puts back every head and hitbox size this session changed.",
}

group{
	name = "hitbox",
	description = "Resizes another player's root part, so it is easier to hit.",
	args = {
		{ name = "players", type = "players", excludeSelf = true },
		{ name = "size", type = "number", default = 1, min = 0 },
		{ name = "transparency", type = "number", default = 0.4, min = 0, max = 1 },
	},
	examples = { "hitbox all 20", "hitbox bob 20 0", "unhitbox" },
	toggle = false,
	offArgs = {},
	run = function(ctx)
		local size = sizeVector(ctx.args.size or 1)
		local transparency = ctx.args.transparency or 0.4
		ctx:each(function(target)
			resizePart(target:requireRoot(), size, transparency)
		end)
	end,
	off = function() Snapshot.restoreTag(HITBOX_TAG) end,
	offDescription = "Puts back every head and hitbox size this session changed.",
}

--[[ `settings()` is not reachable on every executor, so it is asked for at call
     time and refused cleanly rather than erroring at load. ]]
local function renderSettings()
	return Guard.try(function() return settings():GetService("RenderSettings") end)
end

group{
	name = "hitboxes",
	description = "Draws a bounding box around every part on screen.",
	examples = { "hitboxes", "unhitboxes" },
	run = function(ctx)
		local render = renderSettings()
		ctx:assert(render ~= nil, "this executor cannot reach RenderSettings")
		Snapshot.set(render, "ShowBoundingBoxes", true, "hitboxes")
	end,
	off = function()
		local restored = Snapshot.restoreTag("hitboxes")
		if restored == 0 then
			local render = renderSettings()
			if render then pcall(function() render.ShowBoundingBoxes = false end) end
		end
	end,
}

return true
