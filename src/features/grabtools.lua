--[[═══════════════════════════════════════════════════════════════════════════
	features/grabtools · pick up every tool that lands in the workspace
	─────────────────────────────────────────────────────────────────────────
	Legacy equivalent: source.ref.lua 11106-11133.

	    local humanoid = speaker.Character:FindFirstChildWhichIsA("Humanoid")
	    grabtoolsFunc = workspace.ChildAdded:Connect(function(child)
	        if speaker.Character and child:IsA("BackpackItem") ... then
	            humanoid:EquipTool(child)

	The Humanoid was captured once, at the moment the command ran. After the
	first respawn the handler kept firing and kept calling EquipTool on a
	destroyed Humanoid -- forever, because the connection lived in a global that
	only `nograbtools` ever cleared, and `;unloadiy` did not know about it. The
	first line also threw outright when you had no character.

	Here the humanoid is looked up per event, `reapply` re-runs the workspace
	sweep for each new character, and the connection is in the feature bin so
	`;unloadiy`, a failed start and `nograbtools` all let go of it.
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Feature   = IY.import("features/feature")
local Character = IY.import("core/character")
local Guard     = IY.import("core/guard")
local Services  = IY.import("core/services")

local Workspace = Services.Workspace

local M = {}

--[[ Equip one candidate. The Handle check is legacy's and is worth keeping:
     Humanoid:EquipTool throws on a BackpackItem that has none. ]]
local function grab(child)
	local humanoid = Character.humanoid()
	if not humanoid then return false end
	if not child:IsA("BackpackItem") then return false end
	if not child:FindFirstChild("Handle") then return false end
	humanoid:EquipTool(child)
	return true
end

local feature = Feature.new("grabtools", {
	command  = "grabtools",
	reapply  = true,
	describe = "picking up dropped tools",

	start = function(self)
		-- Wrapped once: a tool that cannot be equipped must not kill the
		-- connection for every tool after it.
		local grabbed = Guard.wrap("grabtools", grab)
		local children = Workspace:GetChildren()
		for i = 1, #children do grabbed(children[i]) end
		self.bin:connect(Workspace.ChildAdded, grabbed)
	end,
})

M.feature = feature

function M.start() return feature:start() end
function M.stop() return feature:stop() end
function M.toggle() return feature:toggle() end
function M.isRunning() return feature:isRunning() end

return M
