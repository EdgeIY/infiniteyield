--[[═══════════════════════════════════════════════════════════════════════════
	features/partesp · outline every part with a given name
	─────────────────────────────────────────────────────────────────────────
	Legacy source.ref.lua 8158-8223. The same lime-green BoxHandleAdornment on
	the part itself and the same live `workspace.DescendantAdded` pickup, with
	its two failure modes removed:

	  · `unpartesp` with no arguments called `partEspTrigger:Disconnect()` on a
	    nil whenever partesp had never been used (8214), so the very first
	    `;unpartesp` of a session threw. Off is a feature stop now, which is safe
	    whether or not it was ever started.
	  · the DescendantAdded handler disconnected *itself* whenever a part was
	    added while the name list happened to be empty (8174), so the
	    connection's lifetime was decided by world traffic rather than by the
	    command. Each tracked name owns a `bin:branch()` instead; the last one
	    going away stops the feature, and the connection goes with it.
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Feature   = IY.import("features/feature")
local Highlight = IY.import("features/highlight")
local Guard     = IY.import("core/guard")
local Str       = IY.import("core/util/strings")

local M = {}

local function adorn(entry, part)
	local box = entry.bin:add(Instance.new("BoxHandleAdornment"))
	box.Name = Str.lower(part.Name) .. "_PESP"
	box.Adornee = part
	box.AlwaysOnTop = true
	box.ZIndex = 0
	box.Size = part.Size
	box.Transparency = Highlight.transparency()
	box.Color = BrickColor.new("Lime green")
	box.Parent = part
	entry.adornments[#entry.adornments + 1] = box
	return box
end

local feature = Feature.new("partesp", {
	command  = "partesp",
	describe = "part ESP",

	start = function(self)
		local entries = {}
		self.state.entries = entries

		self.bin:connect(workspace.DescendantAdded, function(instance)
			if not instance:IsA("BasePart") then return end
			local entry = entries[Str.lower(instance.Name)]
			if entry then adorn(entry, instance) end
		end)

		self.bin:add(Highlight.onTransparency(function(value)
			for _, entry in pairs(entries) do
				Highlight.setTransparency(entry.adornments, value)
			end
		end))
	end,
})

M.feature = feature

local function tracked()
	if not feature:isRunning() then return nil end
	return feature.state.entries
end

--[[ Start tracking a part name. Returns the normalised name, how many parts
     already in the world matched, and whether it was newly added. ]]
function M.add(name)
	local key = Str.lower(Str.trim(tostring(name or "")))
	if key == "" then Guard.fail("which part should be highlighted?") end
	if not feature:isRunning() then feature:start() end

	local entries = feature.state.entries
	if entries[key] then return key, 0, false end

	local entry = { bin = feature.bin:branch("part:" .. key), adornments = {} }
	entries[key] = entry
	entry.bin:add(function() entries[key] = nil end)

	local matched = 0
	local descendants = workspace:GetDescendants()
	for i = 1, #descendants do
		local part = descendants[i]
		if part:IsA("BasePart") and Str.lower(part.Name) == key then
			adorn(entry, part)
			matched = matched + 1
		end
	end
	return key, matched, true
end

--[[ Stop tracking one name, taking only its own adornments with it. ]]
function M.remove(name)
	local entries = tracked()
	if not entries then return false end
	local key = Str.lower(Str.trim(tostring(name or "")))
	local entry = entries[key]
	if not entry then return false end
	entry.bin:destroy()
	if next(entries) == nil then feature:stop() end
	return true
end

function M.clear() return feature:stop() end
function M.isRunning() return feature:isRunning() end

function M.names()
	local out = {}
	local entries = tracked()
	if entries then
		for key in pairs(entries) do out[#out + 1] = key end
		table.sort(out)
	end
	return out
end

return M
