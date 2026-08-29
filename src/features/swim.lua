--[[═══════════════════════════════════════════════════════════════════════════
	features/swim · zero-gravity swimming
	─────────────────────────────────────────────────────────────────────────
	Zero the world gravity, force the Swimming humanoid state, and clamp
	velocity so you hang still unless you are actually pressing something.

	Two legacy problems fixed:

	  · the death handler cleared the `swimming` flag and restored gravity but
	    never disconnected the Heartbeat loop or the Died connection, so a
	    second `;swim` after a death added a second loop; and if `;unswim` bailed
	    early (no character) the flag stayed true and swim could never restart.
	  · gravity was remembered in a module global (`oldgrav`) that `;gravity`
	    also read as its default, so the two commands corrupted each other.
	    Gravity now goes through core/snapshot, which records the original once
	    and hands it back on restore no matter who else touched it.
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Feature   = IY.import("features/feature")
local Character = IY.import("core/character")
local Services  = IY.import("core/services")
local Sched     = IY.import("core/scheduler")
local Snapshot  = IY.import("core/snapshot")
local Inst      = IY.import("core/util/instances")

local UserInputService = Services.UserInputService

local M = {}

--[[ Every humanoid state except None -- disabling them is what stops the rig
     from trying to walk, fall and jump while it is "swimming". ]]
local function stateList()
	local out = {}
	local items = Enum.HumanoidStateType:GetEnumItems()
	for i = 1, #items do
		if items[i] ~= Enum.HumanoidStateType.None then out[#out + 1] = items[i] end
	end
	return out
end

local function setStates(humanoid, enabled)
	local states = stateList()
	for i = 1, #states do
		pcall(function() humanoid:SetStateEnabled(states[i], enabled) end)
	end
end

local feature = Feature.new("swim", {
	command  = "swim",
	reapply  = true,
	describe = "swimming in air",

	start = function(self)
		local humanoid = Character.requireHumanoid()

		Snapshot.set(workspace, "Gravity", 0, "swim")
		self.bin:add(function() Snapshot.restore(workspace, "Gravity") end)

		setStates(humanoid, false)
		self.bin:add(function()
			local currentHumanoid = Character.humanoid()
			if currentHumanoid then setStates(currentHumanoid, true) end
		end)

		pcall(function() humanoid:ChangeState(Enum.HumanoidStateType.Swimming) end)

		self.bin:add(Sched.frameLoop("swim.step", function()
			local currentHumanoid = Character.humanoid()
			local root = Character.root()
			if not currentHumanoid or not root then return end
			local moving = currentHumanoid.MoveDirection.Magnitude > 0
				or UserInputService:IsKeyDown(Enum.KeyCode.Space)
			if not moving then
				pcall(function() root.AssemblyLinearVelocity = Vector3.new(0, 0, 0) end)
			end
		end, "heartbeat"))
	end,
})

M.feature = feature

function M.start(opts) return feature:start(opts or {}) end
function M.stop() return feature:stop() end
function M.toggle(opts) return feature:toggle(opts) end
function M.isRunning() return feature:isRunning() end

return M
