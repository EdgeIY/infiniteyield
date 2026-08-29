--[[═══════════════════════════════════════════════════════════════════════════
	features/vehiclenoclip · drive through walls
	─────────────────────────────────────────────────────────────────────────
	Plain noclip for the character (features/noclip owns that) plus CanCollide
	cleared on every part of the vehicle you are sitting in.

	Legacy equivalent: source.ref.lua 9179-9209. Three problems fixed:

	  · it read `speaker.Character:FindFirstChildOfClass('Humanoid').SeatPart`
	    and then `seat.Parent` with no nil checks, so running it on foot threw
	    "attempt to index nil" instead of saying "sit in a vehicle first".
	  · the part list lived in the module global `vnoclipParts`, which
	    `vehiclenoclip` cleared on entry. Toggling it twice while in a different
	    vehicle left the first vehicle permanently non-collidable, and
	    `;unloadiy` never restored anything.
	  · `togglevnoclip` branched on the *noclip* flag (`Clip and "vnoclip" or
	    "vclip"`), so it turned plain noclip off whenever noclip happened to be
	    on. It now toggles this feature.
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Feature  = IY.import("features/feature")
local Noclip   = IY.import("features/noclip")
local Teleport = IY.import("features/teleport")

local M = {}

local feature = Feature.new("vehiclenoclip", {
	command  = "vehiclenoclip",
	reapply  = true,
	describe = "vehicle collisions disabled",

	start = function(self)
		local model = Teleport.vehicleModel()
		self.state.model = model

		Noclip.start()
		self.bin:add(function() Noclip.stop() end)

		-- Registered before the parts are touched so a failure part way through
		-- the walk still puts back whatever was already cleared.
		local restore = {}
		self.state.restore = restore
		self.bin:add(function()
			for part in pairs(restore) do
				if part.Parent then pcall(function() part.CanCollide = true end) end
			end
		end)

		for _, part in ipairs(model:GetDescendants()) do
			if part:IsA("BasePart") and part.CanCollide then
				restore[part] = true
				part.CanCollide = false
			end
		end
	end,
})

M.feature = feature

function M.start(opts) return feature:start(opts or {}) end
function M.stop() return feature:stop() end
function M.toggle(opts) return feature:toggle(opts) end
function M.isRunning() return feature:isRunning() end

--[[ The vehicle currently being clipped, for diagnostics. ]]
function M.model()
	return feature.state and feature.state.model or nil
end

return M
