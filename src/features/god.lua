--[[═══════════════════════════════════════════════════════════════════════════
	features/god · swap in a Humanoid the server cannot damage
	─────────────────────────────────────────────────────────────────────────
	The technique: clone your Humanoid, disable Dead / Ragdoll / FallingDown on
	the clone, then destroy the original. Server-side damage is applied to the
	Humanoid it replicated, and that object no longer exists, so nothing lands;
	the clone drives the rig locally.

	**The legacy command (lines 9562-9585) was unusable, and this fixes it.** It
	referenced two globals that were never assigned -- `char` and `pos`, where
	the locals are `Char` and `Pos` -- so it:

	  1. parented the cloned Humanoid to nil (`nHuman.Parent = char`)
	  2. set `speaker.Character = nil`
	  3. destroyed your real Humanoid
	  4. set `speaker.Character = char`, i.e. back to nil
	  5. threw on `Cam.CFrame = task.wait() and pos`

	which left you with no Humanoid, no Character and an error, every time. The
	names are corrected here and everything between detaching and re-attaching
	the character runs inside a Guard.call, so a failure part-way through still
	hands your character back rather than stranding you without one.

	`;ungod` re-enables the three states on the replacement, which makes you
	mortal again. The original Humanoid is gone for good either way -- that is
	inherent to the technique, not something a restore path can undo.
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Feature   = IY.import("features/feature")
local Character = IY.import("core/character")
local Guard     = IY.import("core/guard")

local M = {}

--[[ Legacy passed the raw numbers 15, 1 and 0 to SetStateEnabled. ]]
local IMMUNE_STATES = {
	Enum.HumanoidStateType.Dead,
	Enum.HumanoidStateType.Ragdoll,
	Enum.HumanoidStateType.FallingDown,
}

local function setStates(humanoid, enabled)
	if not humanoid then return end
	for i = 1, #IMMUNE_STATES do
		pcall(function() humanoid:SetStateEnabled(IMMUNE_STATES[i], enabled) end)
	end
end

local feature = Feature.new("god", {
	command  = "god",
	describe = "god mode",

	start = function(self)
		local player = Character.player
		if not player then Guard.fail("there is no local player") end
		local character = Character.require()
		local humanoid = Character.requireHumanoid()

		local camera = workspace.CurrentCamera
		local cameraCFrame = camera and Guard.try(function() return camera.CFrame end) or nil

		local replacement = Guard.try(function() return humanoid:Clone() end)
		if not replacement then Guard.fail("your Humanoid could not be cloned") end
		replacement.Parent = character

		-- Detaching the character is what stops the Destroy below from counting
		-- as a death. Everything until it is put back is contained.
		player.Character = nil
		local ok, err = Guard.call("god.swap", function()
			setStates(replacement, false)
			replacement.BreakJointsOnDeath = true
			humanoid:Destroy()
		end)
		player.Character = character

		if not ok then
			pcall(function() replacement:Destroy() end)
			error(err, 0)
		end

		if camera then
			pcall(function() camera.CameraSubject = replacement end)
			task.wait()
			if cameraCFrame then pcall(function() camera.CFrame = cameraCFrame end) end
			pcall(function() camera.CameraType = Enum.CameraType.Custom end)
		end
		pcall(function()
			replacement.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		end)

		-- The default Animate script binds to whichever Humanoid it finds when it
		-- starts, so it has to be restarted to notice the replacement.
		local animate = character:FindFirstChild("Animate")
		if animate then
			pcall(function()
				animate.Disabled = true
				task.wait()
				animate.Disabled = false
			end)
		end
		pcall(function() replacement.Health = replacement.MaxHealth end)

		self.state.humanoid = replacement
		self.bin:add(function()
			setStates(replacement, true)
			local liveCamera = workspace.CurrentCamera
			if liveCamera then
				pcall(function() liveCamera.CameraSubject = Character.humanoid() end)
				pcall(function() liveCamera.CameraType = Enum.CameraType.Custom end)
			end
		end)
	end,
})

M.feature = feature

function M.start(opts) return feature:start(opts or {}) end
function M.stop() return feature:stop() end
function M.toggle(opts) return feature:toggle(opts) end
function M.isRunning() return feature:isRunning() end

return M
