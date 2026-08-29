--[[═══════════════════════════════════════════════════════════════════════════
	commands/camera · spectate, freecam and the camera settings
	─────────────────────────────────────────────────────────────────────────
	Twenty-one commands (plus the un/no/toggle siblings the registry derives)
	over three features:

	    features/spectate   view, viewpart
	    features/freecam    freecam and its position / speed commands
	    features/camera     fov, zoom, camera mode, shift lock, noclipcam, fixcam

	Nothing in this file holds state. The legacy versions of these commands
	shared twenty-odd globals between them -- `fcRunning`, `viewing`, `viewDied`,
	`cameraFov`, `preMaxZoom`, a Spring class, six PlayerState slots -- which is
	where nearly all of their bugs came from. Each feature header lists the ones
	that are fixed.

	Legacy equivalent: source.ref.lua lines 8277-8756.
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Cmd      = IY.import("cmd/api")
local Camera   = IY.import("features/camera")
local Freecam  = IY.import("features/freecam")
local Spectate = IY.import("features/spectate")
local Teleport = IY.import("features/teleport")
local Guard    = IY.import("core/guard")
local Env      = IY.import("core/env")

local group = Cmd.group{ category = "Camera" }

--[[ features/waypoints belongs to another pack, so it is imported on demand: a
     module that is missing or fails to load must not take every camera command
     down with it. ]]
local function waypoints()
	local ok, module = pcall(function() return IY.import("features/waypoints") end)
	if not ok or type(module) ~= "table" then
		Guard.fail("waypoints are not available in this build")
	end
	return module
end

--[[ Away from zero, matching Luau's math.round, which the legacy notify used. ]]
local function round(value)
	if value < 0 then return -math.floor(-value + 0.5) end
	return math.floor(value + 0.5)
end

local function describePosition(position)
	return string.format("%d, %d, %d", round(position.X), round(position.Y), round(position.Z))
end

-- ── spectate ────────────────────────────────────────────────────────────────

group{
	name = "view",
	aliases = { "spectate" },
	description = "Watches another player's camera.",
	args = {
		{ name = "player", type = "player", optional = true },
	},
	examples = { "view bob", "unview" },
	offAliases = { "unspectate" },
	offArgs = {},
	offDescription = "Stops spectating and gives you your camera back.",
	run = function(ctx)
		local target = ctx.args.player or ctx.speaker
		Spectate.startTarget(target)
		if not ctx:quiet() then ctx:notify("Spectate", "Viewing " .. target:label()) end
	end,
	off = function(ctx)
		local watching = Spectate.label()
		Spectate.stop()
		if not ctx:quiet() then
			ctx:notify("Spectate", watching and ("Stopped viewing " .. watching) or "View turned off")
		end
	end,
}

group{
	name = "viewpart",
	aliases = { "viewp" },
	description = "Watches a part in the workspace by name.",
	args = {
		{ name = "part", type = "text" },
	},
	examples = { "viewpart Door" },
	toggle = false,
	offArgs = {},
	run = function(ctx)
		local part = Spectate.startPart(ctx.args.part)
		if not ctx:quiet() then ctx:notify("Spectate", "Viewing " .. part.Name) end
	end,
	off = function(ctx)
		Spectate.stop()
		if not ctx:quiet() then ctx:notify("Spectate", "View turned off") end
	end,
}

-- ── freecam ─────────────────────────────────────────────────────────────────

group{
	name = "freecam",
	aliases = { "fc" },
	description = "Detaches the camera from your character and flies it.",
	examples = { "freecam", "unfreecam" },
	offAliases = { "unfc", "nofc" },
	run = function(ctx)
		Freecam.start()
		if not ctx:quiet() then
			ctx:notify("Freecam", "WASD to move, Q and E for down and up, arrow keys for speed")
		end
	end,
	off = function(ctx)
		Freecam.stop()
		if not ctx:quiet() then ctx:notify("Freecam", "Camera returned") end
	end,
}

group{
	name = "freecampos",
	aliases = { "fcpos", "fcp", "freecamposition", "fcposition" },
	description = "Starts freecam at a set of coordinates.",
	args = {
		{ name = "x", type = "number" },
		-- Legacy passed the missing arguments straight to CFrame.new, so
		-- `;freecampos 10` threw instead of doing anything.
		{ name = "y", type = "number", default = 0 },
		{ name = "z", type = "number", default = 0 },
	},
	examples = { "freecampos 100 50 -20" },
	run = function(ctx)
		Freecam.start{ cframe = CFrame.new(ctx.args.x, ctx.args.y, ctx.args.z) }
	end,
}

group{
	name = "freecamwaypoint",
	aliases = { "fcwp" },
	description = "Starts freecam at a saved waypoint.",
	args = {
		{ name = "waypoint", type = "waypoint" },
	},
	examples = { "freecamwaypoint base" },
	run = function(ctx)
		local Waypoints = waypoints()
		local entry = Waypoints.find(ctx.args.waypoint)
		ctx:assert(entry, "no waypoint called '%s'", ctx.args.waypoint)
		local cframe = Waypoints.cframeOf(entry)
		ctx:assert(cframe, "waypoint '%s' has no position", ctx.args.waypoint)
		Freecam.start{ cframe = cframe }
	end,
}

group{
	name = "freecamgoto",
	aliases = { "fcgoto", "freecamtp", "fctp" },
	description = "Starts freecam at a player's position.",
	args = {
		{ name = "player", type = "player" },
	},
	examples = { "freecamgoto bob" },
	run = function(ctx)
		-- Legacy restarted freecam once per matched player, so only the last one
		-- in the list ever took effect.
		local target = ctx.args.player
		Freecam.start{ cframe = target:requireRoot().CFrame }
		if not ctx:quiet() then ctx:notify("Freecam", "Moved to " .. target:label()) end
	end,
}

group{
	name = "freecamspeed",
	aliases = { "fcspeed" },
	description = "Sets how fast freecam moves. Takes effect immediately.",
	args = {
		{ name = "speed", type = "number", default = 1, min = 0, max = 100 },
	},
	examples = { "freecamspeed 5", "freecamspeed" },
	run = function(ctx)
		Freecam.setSpeed(ctx.args.speed)
		if not ctx:quiet() then ctx:reply("Freecam speed set to " .. tostring(ctx.args.speed)) end
	end,
}

group{
	name = "notifyfreecamposition",
	aliases = { "notifyfcpos" },
	description = "Shows where the freecam is.",
	examples = { "notifyfreecamposition" },
	run = function(ctx)
		local position = Freecam.position()
		ctx:assert(position, "freecam is not running")
		ctx:notify("Current Position", describePosition(position))
	end,
}

group{
	name = "copyfreecamposition",
	aliases = { "copyfcpos" },
	description = "Copies the freecam position to your clipboard.",
	examples = { "copyfreecamposition" },
	requires = { capability = "setclipboard" },
	run = function(ctx)
		local position = Freecam.position()
		ctx:assert(position, "freecam is not running")
		local text = describePosition(position)
		Env.fn.setclipboard(text)
		if not ctx:quiet() then ctx:reply("Copied " .. text) end
	end,
}

-- ── going to the camera ─────────────────────────────────────────────────────

group{
	name = "gotocamera",
	aliases = { "gotocam", "tocam" },
	description = "Teleports you to wherever the camera is.",
	examples = { "gotocamera" },
	requires = { character = true, root = true },
	run = function(ctx)
		Teleport.to(Camera.require().CFrame)
	end,
}

group{
	name = "tweengotocamera",
	aliases = { "tweengotocam", "tgotocam", "ttocam" },
	description = "Slides you to the camera instead of teleporting.",
	examples = { "tweengotocamera" },
	requires = { character = true, root = true },
	run = function(ctx)
		--[[ `tween = true` takes the duration from the shared ;tweenspeed setting,
		     which is what the legacy global `tweenSpeed` was. ]]
		Teleport.to(Camera.require().CFrame, { tween = true })
	end,
}

-- ── field of view ───────────────────────────────────────────────────────────

group{
	name = "fov",
	description = "Sets the camera's field of view.",
	args = {
		{ name = "fov", type = "number", default = 70, min = 1, max = 120 },
	},
	examples = { "fov 90", "unfov" },
	toggle = false,
	offArgs = {},
	offDescription = "Puts the field of view back where it was.",
	run = function(ctx)
		-- Freecam writes FieldOfView every frame, so it has to be told directly;
		-- in the legacy script `;fov` during freecam was silently overwritten.
		if not Freecam.setFov(ctx.args.fov) then Camera.setFov(ctx.args.fov) end
		if not ctx:quiet() then ctx:reply("Field of view set to " .. tostring(ctx.args.fov)) end
	end,
	off = function(ctx)
		Camera.restoreFov()
		local restored = Camera.fov()
		if restored then Freecam.setFov(restored) end
		if not ctx:quiet() then ctx:reply("Field of view restored") end
	end,
}

-- ── zoom ────────────────────────────────────────────────────────────────────

group{
	name = "maxzoom",
	description = "Sets how far you can zoom out.",
	args = {
		{ name = "distance", type = "number", min = 0 },
	},
	examples = { "maxzoom 1000", "unmaxzoom" },
	toggle = false,
	offArgs = {},
	offDescription = "Puts the zoom-out limit back.",
	run = function(ctx)
		Camera.setZoom(nil, ctx.args.distance)
		if not ctx:quiet() then ctx:reply("Max zoom set to " .. tostring(ctx.args.distance)) end
	end,
	off = function() Camera.restoreZoom("max") end,
}

group{
	name = "minzoom",
	description = "Sets how far in you can zoom.",
	args = {
		{ name = "distance", type = "number", min = 0 },
	},
	examples = { "minzoom 0.5", "unminzoom" },
	toggle = false,
	offArgs = {},
	offDescription = "Puts the zoom-in limit back.",
	run = function(ctx)
		Camera.setZoom(ctx.args.distance, nil)
		if not ctx:quiet() then ctx:reply("Min zoom set to " .. tostring(ctx.args.distance)) end
	end,
	off = function() Camera.restoreZoom("min") end,
}

group{
	name = "camdistance",
	description = "Snaps the camera to a distance, then lets you zoom freely again.",
	args = {
		{ name = "distance", type = "number", min = 0 },
	},
	examples = { "camdistance 20" },
	run = function(ctx)
		Camera.pulseDistance(ctx.args.distance)
	end,
}

group{
	name = "lookat",
	description = "Points your camera at a player.",
	args = {
		{ name = "players", type = "players" },
	},
	examples = { "lookat bob", "lookat all" },
	-- The legacy version held the zoom range in two module locals, so overlapping
	-- runs restored each other's temporary values; one at a time removes the race.
	singleton = true,
	run = function(ctx)
		local seen = Camera.lookAt(ctx:targets())
		if seen == 0 then ctx:fail("none of those players have a head to look at") end
	end,
}

-- ── camera mode and repair ──────────────────────────────────────────────────

group{
	name = "firstp",
	description = "Locks you into first person.",
	examples = { "firstp" },
	run = function(ctx)
		Camera.setCameraMode(Enum.CameraMode.LockFirstPerson)
	end,
}

group{
	name = "thirdp",
	description = "Puts you back into third person.",
	examples = { "thirdp" },
	run = function(ctx)
		Camera.setCameraMode(Enum.CameraMode.Classic)
	end,
}

group{
	name = "enableshiftlock",
	aliases = { "enablesl", "shiftlock" },
	description = "Makes shift lock available in games that turned it off.",
	examples = { "enableshiftlock", "unenableshiftlock" },
	offAliases = { "unshiftlock", "disableshiftlock" },
	offDescription = "Stops forcing shift lock on.",
	run = function(ctx)
		Camera.startShiftlock()
		if not ctx:quiet() then ctx:notify("Shiftlock", "Shift lock should now be available") end
	end,
	off = function(ctx)
		Camera.stopShiftlock()
		if not ctx:quiet() then ctx:notify("Shiftlock", "Shift lock left as the game had it") end
	end,
}

group{
	name = "noclipcam",
	aliases = { "nccam" },
	description = "Lets the camera pass through walls.",
	examples = { "noclipcam", "unnoclipcam" },
	-- setconstant / getconstants are registered by features/camera, because
	-- core/env does not know about them and is not this pack's to edit.
	requires = { capability = { "getgc", "getconstants", "setconstant" } },
	run = function(ctx)
		Camera.startNoclipCam()
		if not ctx:quiet() then ctx:reply("Camera will now clip through walls") end
	end,
	off = function(ctx)
		Camera.stopNoclipCam()
		if not ctx:quiet() then ctx:reply("Camera collision restored") end
	end,
}

group{
	name = "fixcam",
	aliases = { "restorecam" },
	description = "Stops every camera command and puts the camera back.",
	examples = { "fixcam" },
	run = function(ctx)
		Freecam.stop()
		Spectate.stop()
		Camera.stopShiftlock()
		Camera.stopNoclipCam()
		Camera.reset()

		--[[ cframefly anchors your head and its own bin unanchors it, but fixcam
		     is the button people reach for when something has left them stuck,
		     and the legacy version un-anchored it here too. ]]
		local character = ctx.speaker.character
		local head = character and character:FindFirstChild("Head")
		if head and head.Anchored then head.Anchored = false end

		if not ctx:quiet() then ctx:reply("Camera restored") end
	end,
}

return true
