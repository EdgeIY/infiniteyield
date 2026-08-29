--[[═══════════════════════════════════════════════════════════════════════════
	features/camera · everything that changes the camera or your camera settings
	─────────────────────────────────────────────────────────────────────────
	fov, maxzoom, minzoom, camdistance, firstp, thirdp, lookat, enableshiftlock,
	noclipcam and fixcam all leave state behind after the command returns, so all
	of it goes through core/snapshot under one tag. Two consequences:

	  · `;fixcam` becomes "hand back the camera snapshot" instead of the legacy
	    list of hard-coded values (`CameraMinZoomDistance = 0.5`,
	    `CameraMaxZoomDistance = 400`, `CameraMode = Classic`), which overwrote
	    whatever the game had actually configured.
	  · `;unloadiy` puts the camera back, which nothing in the legacy script did.

	Also fixed here:

	  · `enableshiftlock` made a GetPropertyChangedSignal connection it never
	    stored, so it kept forcing DevEnableMouseLock on for the rest of the
	    session -- including after the script was unloaded. It is a feature with
	    a bin now.
	  · `lookat` remembered the zoom range in two module locals behind an
	    `if speaker.CameraMaxZoomDistance ~= 0.5` guard, so a second `;lookat`
	    during the first one's delay loop recorded 0.5 as "the old value" and
	    left you stuck in first person.
	  · `noclipcam` was self-inverse -- you ran it twice to undo it -- so there
	    was nothing for an off-command or for unload to call. It now records
	    every constant it patches and puts them back.
	  · every entry point tolerates `workspace.CurrentCamera` being nil, which it
	    is for a frame or two after a respawn and while the engine swaps it.

	Legacy equivalent: source.ref.lua lines 8657-8756.
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Feature   = IY.import("features/feature")
local Character = IY.import("core/character")
local Snapshot  = IY.import("core/snapshot")
local Sched     = IY.import("core/scheduler")
local Guard     = IY.import("core/guard")
local Env       = IY.import("core/env")

local M = {}

local TAG = "camera"

--[[ core/env does not register the constant-patching helpers (they live under
     `debug` on most executors) and it is not ours to edit, so they are added
     here through its public `cap`. That is what lets ;noclipcam declare
     `requires = { capability = ... }` and get the standard "your executor does
     not support this" message instead of failing inside the command. ]]
local function executorFunction(name)
	local direct = Env.lookup(name)
	if type(direct) == "function" then return direct end
	local debugTable = Env.lookup("debug")
	if type(debugTable) == "table" then
		local ok, value = pcall(function() return debugTable[name] end)
		if ok and type(value) == "function" then return value end
	end
	return nil
end

do
	local extra = { "setconstant", "getconstants" }
	for i = 1, #extra do
		if Env.caps[extra[i]] == nil then Env.cap(extra[i], executorFunction(extra[i])) end
	end
end

-- ── the camera itself ───────────────────────────────────────────────────────

function M.get()
	local ok, camera = pcall(function() return workspace.CurrentCamera end)
	if ok and camera then return camera end
	return nil
end

--[[ The camera, or a clean user error. Waits briefly first: CurrentCamera is
     nil for a frame or two after a respawn, and the legacy helpers did
     arithmetic on it anyway. ]]
function M.require(timeout)
	local camera = M.get()
	if camera then return camera end
	Sched.waitUntil(function() return M.get() ~= nil end, timeout or 0.5)
	camera = M.get()
	if not camera then
		Guard.fail("there is no camera right now -- try again in a moment")
	end
	return camera
end

local function localPlayer()
	local player = Character.player
	if not player then Guard.fail("you are not in the game yet") end
	return player
end

-- ── field of view ───────────────────────────────────────────────────────────

function M.setFov(value)
	local camera = M.require()
	Snapshot.set(camera, "FieldOfView", value, TAG)
	return value
end

function M.restoreFov()
	local camera = M.get()
	if not camera then return false end
	Snapshot.restore(camera, "FieldOfView")
	return true
end

function M.fov()
	local camera = M.get()
	return camera and camera.FieldOfView or nil
end

-- ── zoom range ──────────────────────────────────────────────────────────────

function M.zoom()
	local player = localPlayer()
	return player.CameraMinZoomDistance, player.CameraMaxZoomDistance
end

--[[ Write the pair in whichever order keeps min <= max at every step: Roblox
     rejects a minimum above the current maximum, which is what made
     `;minzoom 500` throw in the legacy script. Either bound may be nil to mean
     "leave it alone". ]]
function M.setZoom(minimum, maximum)
	local player = localPlayer()
	local low  = minimum or player.CameraMinZoomDistance
	local high = maximum or player.CameraMaxZoomDistance
	if low > high then low = high end

	if high >= player.CameraMaxZoomDistance then
		Snapshot.set(player, "CameraMaxZoomDistance", high, TAG)
		Snapshot.set(player, "CameraMinZoomDistance", low, TAG)
	else
		Snapshot.set(player, "CameraMinZoomDistance", low, TAG)
		Snapshot.set(player, "CameraMaxZoomDistance", high, TAG)
	end
	return low, high
end

--[[ `which` is "min", "max", or nil for both. ]]
function M.restoreZoom(which)
	local player = Character.player
	if not player then return false end
	if which ~= "max" then Snapshot.restore(player, "CameraMinZoomDistance") end
	if which ~= "min" then Snapshot.restore(player, "CameraMaxZoomDistance") end
	return true
end

--[[ ;camdistance: pin the camera at `distance` for a frame, then hand the range
     back. The legacy version kept the ceiling raised when you asked for a
     distance beyond it, so `;camdistance 500` in a game capped at 100 leaves
     you able to zoom out that far -- preserved. ]]
function M.pulseDistance(distance)
	local player = localPlayer()
	local originalMin = player.CameraMinZoomDistance
	local originalMax = player.CameraMaxZoomDistance
	M.setZoom(distance, distance)
	task.wait()
	M.setZoom(originalMin, math.max(originalMax, distance))
	return distance
end

-- ── camera mode ─────────────────────────────────────────────────────────────

function M.setCameraMode(mode)
	local player = localPlayer()
	Snapshot.set(player, "CameraMode", mode, TAG)
	return mode
end

-- ── lookat ──────────────────────────────────────────────────────────────────

local function headOf(target)
	local character = target.character
	if not character then return nil end
	return character:FindFirstChild("Head") or target.root
end

--[[ Drop the zoom range to 0.5 so the camera sits at your head, point it at each
     target in turn, then hand the range back. The visible behaviour -- including
     the 0.1s dwell per target -- is the legacy one; the re-entrancy bug is not
     (see the header). The range is put back by value rather than by
     `restoreZoom`, so an outstanding `;maxzoom` survives a `;lookat`. ]]
function M.lookAt(targets, dwell)
	M.require()
	local player = localPlayer()
	local entryMin = player.CameraMinZoomDistance
	local entryMax = player.CameraMaxZoomDistance

	M.setZoom(0.5, 0.5)
	task.wait()

	local seen = 0
	for i = 1, #targets do
		local head = headOf(targets[i])
		local camera = M.get()
		if head and camera then
			camera.CFrame = CFrame.new(camera.CFrame.Position, head.Position)
			seen = seen + 1
			task.wait(dwell or 0.1)
		end
	end

	M.setZoom(entryMin, entryMax)
	return seen
end

-- ── restore / reset ─────────────────────────────────────────────────────────

--[[ Put back every property any camera command changed. ]]
function M.restoreAll()
	return Snapshot.restoreTag(TAG)
end

--[[ ;fixcam: restore the snapshot, then make the engine build a fresh camera --
     which is what actually unsticks a camera a game has taken over. The legacy
     version called `:remove()` and indexed the replacement on the very next
     line, which is the nil-camera window everything here guards against. ]]
function M.reset()
	M.restoreAll()

	local previous = M.get()
	if previous then pcall(function() previous.Parent = nil end) end

	-- CurrentCamera can keep pointing at the camera we just detached, so wait for
	-- a genuinely different one rather than for "not nil".
	Sched.waitUntil(function()
		local current = M.get()
		return current ~= nil and current ~= previous
	end, 3)

	local replacement = M.get()
	if previous and (replacement == nil or replacement == previous) then
		-- The engine did not replace it; put it back rather than leaving the
		-- client with no camera at all.
		pcall(function() previous.Parent = workspace end)
		replacement = M.get() or previous
	elseif not replacement then
		-- A few games clear CurrentCamera outright.
		replacement = Instance.new("Camera")
		replacement.Name = "Camera"
		replacement.Parent = workspace
		pcall(function() workspace.CurrentCamera = replacement end)
	end

	local humanoid = Character.humanoid()
	if humanoid then pcall(function() replacement.CameraSubject = humanoid end) end
	pcall(function() replacement.CameraType = Enum.CameraType.Custom end)
	return replacement
end

-- ── shift lock ──────────────────────────────────────────────────────────────

local shiftlock = Feature.new("shiftlock", {
	command  = "enableshiftlock",
	describe = "shift lock forced available",

	start = function(self)
		local player = localPlayer()
		Snapshot.set(player, "DevEnableMouseLock", true, TAG)
		self.bin:add(function() Snapshot.restore(player, "DevEnableMouseLock") end)

		-- Games that turn shift lock off again get overruled. Registered after
		-- the restore above so the bin disconnects it *before* restoring, or the
		-- handler would immediately undo the restore.
		self.bin:onChange(player, "DevEnableMouseLock", function()
			if not player.DevEnableMouseLock then player.DevEnableMouseLock = true end
		end)
	end,
})

-- ── noclipcam ───────────────────────────────────────────────────────────────

--[[ The default camera's wall-avoidance lives in ZoomController.Popper. ]]
local function popperModule()
	local player = localPlayer()
	local scripts   = player:FindFirstChild("PlayerScripts")
	local module    = scripts and scripts:FindFirstChild("PlayerModule")
	local cameras   = module and module:FindFirstChild("CameraModule")
	local zoom      = cameras and cameras:FindFirstChild("ZoomController")
	local popper    = zoom and zoom:FindFirstChild("Popper")
	if not popper then
		Guard.fail("this game does not use the default camera scripts, so there is no Popper module to patch")
	end
	return popper
end

local function scriptOf(fn)
	local environment = Guard.try(getfenv, fn)
	if type(environment) ~= "table" then return nil end
	local ok, script = pcall(function() return environment.script end)
	if ok then return script end
	return nil
end

local noclipcam = Feature.new("noclipcam", {
	command  = "noclipcam",
	describe = "camera ignores walls",

	start = function(self)
		local getgc        = Guard.need("getgc")
		local getconstants = Guard.need("getconstants")
		local setconstant  = Guard.need("setconstant")
		local popper = popperModule()

		local patched = {}
		for _, value in pairs(getgc()) do
			if type(value) == "function" and scriptOf(value) == popper then
				local constants = Guard.try(getconstants, value)
				if type(constants) == "table" then
					for index, constant in pairs(constants) do
						--[[ 0.25 is the Popper's near-plane margin; zeroing it is
						     what lets the camera pass through geometry. The
						     legacy loop swapped 0 back the other way as well,
						     which is what made it self-inverse -- kept, so the
						     effect is identical. Only real numbers are touched:
						     replacing a string constant with a number would
						     break the module outright. ]]
						if type(constant) == "number" and (constant == 0.25 or constant == 0) then
							local replacement = (constant == 0.25) and 0 or 0.25
							if pcall(setconstant, value, index, replacement) then
								patched[#patched + 1] = { fn = value, index = index, previous = constant }
							end
						end
					end
				end
			end
		end

		if #patched == 0 then
			Guard.fail("could not find the camera's Popper constants -- this game may compile its camera differently")
		end
		self.state.patched = #patched

		self.bin:add(function()
			for i = 1, #patched do
				local entry = patched[i]
				pcall(setconstant, entry.fn, entry.index, entry.previous)
			end
		end)
	end,
})

-- ── feature surface ─────────────────────────────────────────────────────────

M.shiftlock = shiftlock
M.noclipcam = noclipcam

function M.startShiftlock() return shiftlock:start({}) end
function M.stopShiftlock() return shiftlock:stop() end
function M.shiftlockRunning() return shiftlock:isRunning() end

function M.startNoclipCam() return noclipcam:start({}) end
function M.stopNoclipCam() return noclipcam:stop() end
function M.noclipCamRunning() return noclipcam:isRunning() end

--[[ Unload needs no hook here: core/snapshot restores every tag it holds when
     IY tears down, and the two features above give their own bits back through
     their bins. ]]

return M
