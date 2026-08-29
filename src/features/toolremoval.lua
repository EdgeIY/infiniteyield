--[[═══════════════════════════════════════════════════════════════════════════
	features/toolremoval · delete tools by name as fast as they arrive
	─────────────────────────────────────────────────────────────────────────
	    ToolRemoval.add("classic sword")
	    ToolRemoval.remove("classic sword")
	    ToolRemoval.clear()

	Legacy equivalent: source.ref.lua 11135-11167. There, every
	`;removespecifictool <name>` opened its *own* RenderStepped connection and
	filed it in a name -> connection map, so three blocked names meant three full
	backpack sweeps every frame. Each sweep then called `v:Remove()`, the
	deprecated API that only re-parents to nil (the tool comes back the moment
	anything re-parents it, and every call warns).

	One loop reads the current name list instead, and `:Destroy()` does what
	`Remove` was meant to. The list is feature state, so `;unloadiy` drops it and
	`clearremovespecifictool` is just a stop.
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Feature   = IY.import("features/feature")
local Character = IY.import("core/character")
local Sched     = IY.import("core/scheduler")
local Guard     = IY.import("core/guard")
local Str       = IY.import("core/util/strings")
local Tools     = IY.import("features/tools")

local M = {}

local function blocked(self)
	self.state.names = self.state.names or {}
	return self.state.names
end

local feature = Feature.new("toolremoval", {
	command  = "removespecifictool",
	describe = "deleting tools by name",

	start = function(self, opts)
		self.state.names = opts.names or self.state.names or {}

		self.bin:add(Sched.frameLoop("toolremoval.step", function()
			local names = blocked(self)
			if next(names) == nil then return end
			-- The Backpack only, as legacy: a tool you are actually holding stays
			-- in your hands until you put it away.
			local backpack = Tools.backpack(Character.player)
			if not backpack then return end
			local children = backpack:GetChildren()
			for i = 1, #children do
				local child = children[i]
				if names[Str.lower(child.Name)] then child:Destroy() end
			end
		end))
	end,
})

M.feature = feature

--[[ Block one name. Returns the normalised name and whether it was new. ]]
function M.add(name)
	local key = Str.lower(Str.trim(tostring(name or "")))
	if key == "" then Guard.fail("which tool?") end
	if feature:isRunning() then
		local names = blocked(feature)
		local isNew = names[key] == nil
		names[key] = true
		return key, isNew
	end
	feature:start({ names = { [key] = true } })
	return key, true
end

--[[ Stop blocking one name; stops the loop once nothing is left. ]]
function M.remove(name)
	local key = Str.lower(Str.trim(tostring(name or "")))
	if not feature:isRunning() then return false, key end
	local names = blocked(feature)
	if names[key] == nil then return false, key end
	names[key] = nil
	if next(names) == nil then feature:stop() end
	return true, key
end

--[[ The blocked names, sorted. ]]
function M.names()
	if not feature:isRunning() then return {} end
	local out = {}
	for name in pairs(blocked(feature)) do out[#out + 1] = name end
	table.sort(out)
	return out
end

function M.clear()
	local count = #M.names()
	feature:stop()
	return count
end

function M.isRunning() return feature:isRunning() end

return M
