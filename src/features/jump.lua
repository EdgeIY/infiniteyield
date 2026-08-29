--[[═══════════════════════════════════════════════════════════════════════════
	features/jump · infjump, flyjump, autojump, edgejump
	─────────────────────────────────────────────────────────────────────────
	Four related toggles, one file. What changed from the legacy versions:

	  · all four captured `Char` and `Human` in a closure and then opened their
	    own `speaker.CharacterAdded` connection to patch the captured values
	    back up. autojump and edgejump each did it through the shared
	    `HumanModCons` table with the
	        HumanModCons.x = (HumanModCons.x and HumanModCons.x:Disconnect() and false) or ...
	    idiom, which reads `:Disconnect()`'s nil return as false and so *always*
	    took the right-hand branch -- meaning the re-connect happened whether or
	    not the old connection had been dropped. Here the humanoid is looked up
	    on the frame it is used, so no re-binding is needed at all.
	  · `uninfjump` cleared a global debounce flag that `infjump` shared with
	    nothing, while the connection itself was stored in a file-level local
	    that `flyjump` shadowed by name.
	  · autojump used the deprecated `workspace:FindPartOnRay`, which ignores
	    collision groups; it now uses Raycast with the character excluded.
	  · edgejump read `Human.JumpPower or Human.JumpHeight`, and since
	    JumpPower always has a value it never used JumpHeight -- so on an R15 rig
	    with UseJumpPower off the boost was whatever stale JumpPower held.

	Legacy equivalent: source.ref.lua 9949-10042.
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Feature   = IY.import("features/feature")
local Character = IY.import("core/character")
local Services  = IY.import("core/services")
local Sched     = IY.import("core/scheduler")
local Guard     = IY.import("core/guard")
local Inst      = IY.import("core/util/instances")

local UserInputService = Services.UserInputService

local M = {}

--[[ Blacklist was renamed to Exclude; older clients only have the former. ]]
local EXCLUDE = Guard.try(function() return Enum.RaycastFilterType.Exclude end)
	or Guard.try(function() return Enum.RaycastFilterType.Blacklist end)

local function jump()
	local humanoid = Character.humanoid()
	if not humanoid then return false end
	return pcall(function() humanoid:ChangeState(Enum.HumanoidStateType.Jumping) end)
end

-- ── infjump ─────────────────────────────────────────────────────────────────

--[[ JumpRequest fires every frame the jump key is held, so one jump per frame
     is the whole trick. The gate is a local, not the legacy global. ]]
local infjump = Feature.new("infjump", {
	command   = "infjump",
	exclusive = { "flyjump" },
	describe  = "infinite jump",

	start = function(self)
		local ready = true
		self.bin:connect(UserInputService.JumpRequest, function()
			if not ready then return end
			ready = false
			jump()
			-- Re-open on the next frame without yielding inside the handler.
			task.delay(0, function() ready = true end)
		end)
	end,
})

-- ── flyjump ─────────────────────────────────────────────────────────────────

--[[ Same signal, no gate: holding jump re-enters the Jumping state every frame,
     which is what makes you climb. ]]
local flyjump = Feature.new("flyjump", {
	command   = "flyjump",
	exclusive = { "infjump" },
	describe  = "jump flight",

	start = function(self)
		self.bin:connect(UserInputService.JumpRequest, jump)
	end,
})

-- ── autojump ────────────────────────────────────────────────────────────────

local autojump = Feature.new("autojump", {
	command  = "autojump",
	describe = "jumping over obstacles",

	start = function(self)
		local params = RaycastParams.new()
		if EXCLUDE then params.FilterType = EXCLUDE end

		self.bin:add(Sched.frameLoop("autojump.step", function()
			local character = Character.get()
			local humanoid = Inst.humanoid(character)
			local root = Inst.root(character)
			if not humanoid or not root then return end

			params.FilterDescendantsInstances = { character }
			local ahead = root.CFrame.LookVector * 3
			local low  = workspace:Raycast(root.Position - Vector3.new(0, 1.5, 0), ahead, params)
			local high = workspace:Raycast(root.Position + Vector3.new(0, 1.5, 0), ahead, params)
			if low or high then humanoid.Jump = true end
		end))
	end,
})

-- ── edgejump ────────────────────────────────────────────────────────────────

--[[ Full credit to NoelGamer06 @V3rmillion for the technique: when the rig
     enters Freefall without having jumped, it walked off an edge -- so put it
     back on the last solid frame's CFrame and launch it upwards instead. ]]
local edgejump = Feature.new("edgejump", {
	command  = "edgejump",
	describe = "jumping off edges",

	start = function(self)
		local lastState, lastCFrame

		self.bin:add(Sched.frameLoop("edgejump.step", function()
			local character = Character.get()
			local humanoid = Inst.humanoid(character)
			local root = Inst.root(character)
			if not humanoid or not root then
				lastCFrame = nil
				return
			end

			local previous = lastState
			lastState = humanoid:GetState()
			local walkedOff = lastCFrame ~= nil
				and previous ~= lastState
				and lastState == Enum.HumanoidStateType.Freefall
				and previous ~= Enum.HumanoidStateType.Jumping

			if walkedOff then
				local power = humanoid.UseJumpPower and humanoid.JumpPower or humanoid.JumpHeight
				local velocity = root.AssemblyLinearVelocity
				root.CFrame = lastCFrame
				root.AssemblyLinearVelocity = Vector3.new(velocity.X, power, velocity.Z)
			end
			lastCFrame = root.CFrame
		end))
	end,
})

-- ── exports ─────────────────────────────────────────────────────────────────

M.infjump  = infjump
M.flyjump  = flyjump
M.autojump = autojump
M.edgejump = edgejump

return M
