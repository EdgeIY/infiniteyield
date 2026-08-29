--[[═══════════════════════════════════════════════════════════════════════════
	features/invisible · appear invisible to other players
	─────────────────────────────────────────────────────────────────────────
	Full credit to AmokahFox @V3rmillion for the technique, which is preserved
	exactly: clone the character, park the *real* one in Lighting after walking
	it to y = pi * 1e6, put the clone in Workspace at the position you were
	standing in and hand control of it to the player. The server keeps
	simulating the real character somewhere no one will ever look, and the clone
	-- half transparent, so you can see the effect yourself -- is what you drive.

	The legacy implementation (lines 9587-9715) worked, but only if you ran the
	commands in the one order it expected:

	  · `Respawn` and `TurnVisible` were *globals defined inside the command
	    body*, so `;visible` before any `;invisible` called a nil value, and a
	    death in the window before TurnVisible was assigned orphaned both
	    characters -- you were left with no character and no way back.
	  · the Stepped watchdog compared a stringified FallenPartsDestroyHeight
	    (`tostring(Void):find'-'`) and used the wrong comparison whenever that
	    height was positive, so the bail-out it exists for did not fire.
	  · `invisRunning` was cleared in one of Respawn's two branches only, so a
	    death while invisible could leave the flag true forever, and `;invisible`
	    would then refuse to run for the rest of the session.
	  · nothing was ever disconnected on unload.

	Here the clone, both watchdogs and the restore all live in `self.bin`:
	`;visible`, `;unloadiy`, a death and a fall into the void all take the same
	path, and stopping when it was never started is a no-op.
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Feature   = IY.import("features/feature")
local Character = IY.import("core/character")
local Services  = IY.import("core/services")
local Sched     = IY.import("core/scheduler")
local Guard     = IY.import("core/guard")
local Inst      = IY.import("core/util/instances")

local Lighting = Services.Lighting

local M = {}

--[[ Somewhere far enough up that nobody will run into the real rig. ]]
local PARKING = Vector3.new(0, math.pi * 1000000, 0)

local function restartAnimate(character)
	local animate = character and character:FindFirstChild("Animate")
	if not animate then return false end
	return pcall(function()
		animate.Disabled = true
		animate.Disabled = false
	end)
end

--[[ Point the camera back at whatever the player now controls. This is the part
     of the legacy `execCmd('fixcam')` call that invisibility actually needs, and
     doing it here means this feature does not depend on another pack's command
     being loaded. ]]
local function pointCameraAt(humanoid, cframe)
	local camera = workspace.CurrentCamera
	if not camera then return false end
	if humanoid then pcall(function() camera.CameraSubject = humanoid end) end
	pcall(function() camera.CameraType = Enum.CameraType.Custom end)
	if cframe then pcall(function() camera.CFrame = cframe end) end
	return true
end

local feature = Feature.new("invisible", {
	command       = "invisible",
	ignoreRestart = true,   -- a second `;invisible` is a no-op, as in legacy
	describe      = "invisible to other players",

	start = function(self)
		local player = Character.player
		if not player then Guard.fail("there is no local player") end
		local character = Character.require()
		local root = Character.requireRoot()
		local camera = workspace.CurrentCamera
		local cameraCFrame = camera and Guard.try(function() return camera.CFrame end) or nil
		local standing = root.CFrame

		pcall(function() character.Archivable = true end)
		local clone = Guard.try(function() return character:Clone() end)
		if not clone then Guard.fail("this game does not allow your character to be cloned") end
		clone.Name = ""              -- an empty name hides the overhead nametag
		clone.Parent = Lighting

		-- Added first, so the bin destroys it *last*: the restore below reads the
		-- clone's position before it goes.
		self.bin:add(clone)

		local cloneHumanoid = Inst.humanoid(clone)
		local cloneRoot = Inst.root(clone)
		if not cloneHumanoid or not cloneRoot then
			Guard.fail("your character did not clone cleanly")
		end

		for _, part in ipairs(clone:GetDescendants()) do
			if part:IsA("BasePart") then
				pcall(function()
					part.Transparency = (part.Name == "HumanoidRootPart") and 1 or 0.5
				end)
			end
		end

		--[[ The single way back, whoever asks for it: `;visible`, a death, the
		     void watchdog, a respawn or `;unloadiy`. Every step is contained, so
		     one failure cannot strand the player between two characters -- which
		     is precisely how the legacy version left people with no character. ]]
		self.bin:add(function()
			local landing = Guard.try(function() return cloneRoot.CFrame end)
			pcall(function() player.Character = character end)
			pcall(function() character.Parent = workspace end)
			if landing then
				local realRoot = Inst.root(character)
				if realRoot then pcall(function() realRoot.CFrame = landing end) end
			end
			pointCameraAt(Inst.humanoid(character), nil)
			restartAnimate(character)
		end)

		-- ── the swap ───────────────────────────────────────────────────────
		pcall(function() character:MoveTo(PARKING) end)
		if camera then
			-- Scriptable for a moment so the camera does not chase the real rig
			-- up to the parking height while it is still the subject.
			pcall(function() camera.CameraType = Enum.CameraType.Scriptable end)
			task.wait(0.2)
			pcall(function() camera.CameraType = Enum.CameraType.Custom end)
		end

		character.Parent = Lighting
		clone.Parent = workspace
		pcall(function() cloneRoot.CFrame = standing end)
		player.Character = clone
		pointCameraAt(cloneHumanoid, cameraCFrame)
		restartAnimate(clone)

		-- ── watchdogs ──────────────────────────────────────────────────────
		self.bin:connect(cloneHumanoid.Died, function() M.stop() end)

		--[[ If the clone falls past the destroy height it is deleted while the
		     real character is still parked in Lighting, and the player is left
		     with nothing. Restore instead. A NaN height means the engine is not
		     destroying anything (core/character's respawn sets that deliberately),
		     so there is nothing to guard against. ]]
		self.bin:add(Sched.frameLoop("invisible.void", function()
			if not clone.Parent then return end
			local position = cloneRoot and Guard.try(function() return cloneRoot.Position end)
			local void = Guard.try(function() return workspace.FallenPartsDestroyHeight end)
			if not position or type(void) ~= "number" or void ~= void then return end
			if position.Y <= void then M.stop() end
		end, "stepped"))
	end,
})

M.feature = feature

function M.start(opts) return feature:start(opts or {}) end
function M.stop() return feature:stop() end
function M.toggle(opts) return feature:toggle(opts) end
function M.isRunning() return feature:isRunning() end

return M
