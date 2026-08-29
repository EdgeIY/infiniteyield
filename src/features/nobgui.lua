--[[═══════════════════════════════════════════════════════════════════════════
	features/nobgui · keep BillboardGuis and SurfaceGuis off your character
	─────────────────────────────────────────────────────────────────────────
	`;nobgui` is a single sweep; `;loopnobgui` keeps sweeping. The legacy loop
	version (10078-10097) had three problems:

	  · it connected to `speaker.Character.DescendantAdded`, so the moment you
	    died the connection went with the model and the loop silently stopped --
	    the one situation where you want it, because the new rig arrives with a
	    fresh name tag.
	  · `charPartTrigger` was a global, so running `;loopnobgui` twice leaked the
	    first connection and `;unloopnobgui` only ever disconnected the last.
	  · the handler waited a frame before destroying, which achieved nothing
	    beyond making the tag visible for that frame.

	`reapply` handles the respawn, and the single connection lives in the bin.

	Legacy equivalent: source.ref.lua 10070-10097.
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Feature   = IY.import("features/feature")
local Character = IY.import("core/character")
local Guard     = IY.import("core/guard")

local M = {}

local function isOverheadGui(instance)
	return Guard.try(function()
		return instance:IsA("BillboardGui") or instance:IsA("SurfaceGui")
	end) == true
end

--[[ One pass over the character. This is all `;nobgui` does. ]]
function M.sweep(character)
	character = character or Character.get()
	if not character then return 0 end
	local descendants = Guard.try(function() return character:GetDescendants() end)
	if not descendants then return 0 end
	local removed = 0
	for i = 1, #descendants do
		local descendant = descendants[i]
		if isOverheadGui(descendant) then
			local ok = pcall(function() descendant:Destroy() end)
			if ok then removed = removed + 1 end
		end
	end
	return removed
end

local feature = Feature.new("nobgui", {
	command  = "loopnobgui",
	reapply  = true,
	describe = "overhead guis removed",

	start = function(self)
		local character = Character.require()
		self.state.removed = M.sweep(character)
		self.bin:connect(character.DescendantAdded, function(descendant)
			if isOverheadGui(descendant) then
				pcall(function() descendant:Destroy() end)
			end
		end)
	end,
})

M.feature = feature

function M.start() return feature:start() end
function M.stop() return feature:stop() end
function M.toggle() return feature:toggle() end
function M.isRunning() return feature:isRunning() end

return M
