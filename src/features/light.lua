--[[═══════════════════════════════════════════════════════════════════════════
	features/light · a PointLight on a character
	─────────────────────────────────────────────────────────────────────────
	Legacy source.ref.lua 11169-11187. One bug per command:

	  · `;light 30` assigned `light.Brightness = args[2]` with args[2] nil
	    (11174), which raises -- so the only forms that ever worked were `;light`
	    and `;light <range> <brightness>`. Typed arguments give both a default.
	  · `unlight` destroyed *every* PointLight in your character (11182),
	    including any the game had put there, and threw outright when you had no
	    character. Each target gets a `bin:branch()`, so off removes exactly the
	    lights this feature made and nothing else -- no name or class search.

	It also re-applies after a respawn, which the legacy version did not.
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Feature = IY.import("features/feature")
local Target  = IY.import("core/target")

local M = {}

local feature = Feature.new("light", {
	command  = "light",
	reapply  = true,
	describe = "point light",

	start = function(self, opts)
		local targets = opts.targets
		if not targets or #targets == 0 then targets = { Target.localTarget() } end
		local range = self:option("range", 30)
		local brightness = self:option("brightness", 5)

		local lit = 0
		for i = 1, #targets do
			local target = targets[i]
			local root = target.root
			if root then
				local branch = self.bin:branch("target:" .. tostring(target.identityKey))
				local light = branch:add(Instance.new("PointLight"))
				light.Range = range
				light.Brightness = brightness
				light.Parent = root
				lit = lit + 1
			end
		end
		self.state.lit = lit
	end,
})

M.feature = feature

function M.start(opts) return feature:start(opts or {}) end
function M.stop() return feature:stop() end
function M.toggle(opts) return feature:toggle(opts or {}) end
function M.isRunning() return feature:isRunning() end
function M.count() return feature.state.lit or 0 end

return M
