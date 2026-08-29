--[[═══════════════════════════════════════════════════════════════════════════
	core/util/instances · safe Instance traversal
	─────────────────────────────────────────────────────────────────────────
	Every helper here is nil-tolerant. The legacy equivalents were not:

	    function tools(plr)   -- errors when the player has no Backpack
	        if plr:FindFirstChildOfClass("Backpack"):FindFirstChildOfClass("Tool")

	    function r15(plr)     -- errors when the player has no Character
	        if plr.Character:FindFirstChildOfClass("Humanoid").RigType == ...

	Those two lines alone account for a long tail of "command does nothing"
	reports, because the thrown error was swallowed by the dispatcher's pcall.
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Env = IY.import("core/env")

local M = {}

local ROOT_FALLBACKS = { "HumanoidRootPart", "UpperTorso", "Torso", "LowerTorso", "Head" }

--[[ The Humanoid of a character model, or nil. ]]
function M.humanoid(character)
	if not character then return nil end
	local ok, humanoid = pcall(function() return character:FindFirstChildOfClass("Humanoid") end)
	if ok then return humanoid end
	return nil
end

--[[ The root part of a character. Prefers Humanoid.RootPart (correct for both
     rigs), then falls back through the usual suspects so partially-loaded or
     custom characters still work. ]]
function M.root(character)
	if not character then return nil end
	local humanoid = M.humanoid(character)
	if humanoid then
		local ok, rootPart = pcall(function() return humanoid.RootPart end)
		if ok and rootPart then return rootPart end
	end
	for i = 1, #ROOT_FALLBACKS do
		local ok, part = pcall(function() return character:FindFirstChild(ROOT_FALLBACKS[i]) end)
		if ok and part and part:IsA("BasePart") then return part end
	end
	local ok, primary = pcall(function() return character.PrimaryPart end)
	if ok and primary then return primary end
	return nil
end

function M.alive(character)
	local humanoid = M.humanoid(character)
	return humanoid ~= nil and humanoid.Health > 0
end

function M.position(character)
	local root = M.root(character)
	if root then return root.Position end
	return nil
end

function M.cframe(character)
	local root = M.root(character)
	if root then return root.CFrame end
	return nil
end

--[[ Is this an R15 rig? Nil-safe, returns false when unknown. ]]
function M.isR15(character)
	local humanoid = M.humanoid(character)
	if not humanoid then return false end
	local ok, rigType = pcall(function() return humanoid.RigType end)
	return ok and rigType == Enum.HumanoidRigType.R15
end

--[[ Every Tool a player owns, across Backpack and Character. Never errors. ]]
function M.tools(player)
	local out = {}
	if not player then return out end
	local okBackpack, backpack = pcall(function() return player:FindFirstChildOfClass("Backpack") end)
	if okBackpack and backpack then
		for _, child in ipairs(backpack:GetChildren()) do
			if child:IsA("Tool") or child:IsA("HopperBin") then out[#out + 1] = child end
		end
	end
	local character = player.Character
	if character then
		for _, child in ipairs(character:GetChildren()) do
			if child:IsA("Tool") or child:IsA("HopperBin") then out[#out + 1] = child end
		end
	end
	return out
end

function M.hasTools(player)
	return #M.tools(player) > 0
end

--[[ The currently equipped tool, or nil. ]]
function M.equippedTool(player)
	if not player or not player.Character then return nil end
	local ok, tool = pcall(function() return player.Character:FindFirstChildOfClass("Tool") end)
	if ok then return tool end
	return nil
end

--[[ Children (or descendants) matching a class. ]]
function M.ofClass(parent, className, deep)
	local out = {}
	if not parent then return out end
	local ok, list = pcall(function()
		return deep and parent:GetDescendants() or parent:GetChildren()
	end)
	if not ok then return out end
	for i = 1, #list do
		local child = list[i]
		local isA = pcall(function() return child:IsA(className) end) and child:IsA(className)
		if isA then out[#out + 1] = child end
	end
	return out
end

--[[ WaitForChild with a timeout that cannot warn or hang forever. ]]
function M.waitFor(parent, name, timeout)
	if not parent then return nil end
	local existing = parent:FindFirstChild(name)
	if existing then return existing end
	local ok, child = pcall(function() return parent:WaitForChild(name, timeout or 5) end)
	if ok then return child end
	return nil
end

--[[ Zero the velocity of every part in a model. ]]
function M.breakVelocity(model)
	if not model then return false end
	local zero = Vector3.new(0, 0, 0)
	local ok, descendants = pcall(function() return model:GetDescendants() end)
	if not ok then return false end
	for i = 1, #descendants do
		local part = descendants[i]
		if part:IsA("BasePart") then
			pcall(function()
				part.AssemblyLinearVelocity = zero
				part.AssemblyAngularVelocity = zero
			end)
		end
	end
	return true
end

--[[ Anchor / unanchor every part in a model. ]]
function M.setAnchored(model, anchored)
	if not model then return 0 end
	local count = 0
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			local ok = pcall(function() part.Anchored = anchored end)
			if ok then count = count + 1 end
		end
	end
	return count
end

--[[ A Lua expression that resolves to `instance`, for the explorer / copypath.
     Rewritten from the legacy getHierarchy: no repeat-until that assumes the
     instance is a descendant of a service, and it survives nil parents. ]]
function M.path(instance)
	if not instance then return "nil" end
	local segments = {}
	local node = instance
	local guard = 0
	while node and node ~= game and guard < 64 do
		local name = tostring(node.Name)
		if string.match(name, "^[%a_][%w_]*$") then
			table.insert(segments, 1, { text = name, bracket = false })
		else
			table.insert(segments, 1, { text = '["' .. string.gsub(name, '"', '\\"') .. '"]', bracket = true })
		end
		node = node.Parent
		guard = guard + 1
	end
	if #segments == 0 then return "game" end

	local out
	if node == game then
		-- The first segment is a service: express it as GetService, which is
		-- both shorter and valid even when the service name has no accessor.
		table.remove(segments, 1)
		out = 'game:GetService("' .. tostring(M.serviceNameOf(instance) or "Workspace") .. '")'
	else
		out = "nil --[[ orphaned instance ]]"
		return out
	end
	for i = 1, #segments do
		local segment = segments[i]
		out = out .. (segment.bracket and segment.text or ("." .. segment.text))
	end
	return out
end

--[[ Walk up to the top-level service of an instance. ]]
function M.serviceNameOf(instance)
	local node = instance
	local guard = 0
	while node and node.Parent and node.Parent ~= game and guard < 64 do
		node = node.Parent
		guard = guard + 1
	end
	if node and node.Parent == game then
		local ok, className = pcall(function() return node.ClassName end)
		if ok then return className end
	end
	return nil
end

--[[ Best-effort GUI protection so anti-cheats and CoreGui scanners skip our
     interface. Falls back silently when unsupported. ]]
function M.protect(gui)
	if Env.fn.protectgui then pcall(Env.fn.protectgui, gui) end
	return gui
end

--[[ Destroy children matching a predicate; returns how many went. ]]
function M.destroyWhere(parent, predicate)
	if not parent then return 0 end
	local count = 0
	for _, child in ipairs(parent:GetChildren()) do
		local ok, matched = pcall(predicate, child)
		if ok and matched then
			pcall(function() child:Destroy() end)
			count = count + 1
		end
	end
	return count
end

--[[ Is the instance still in the DataModel? Cheap liveness check that avoids
     "attempt to index nil" after a Destroy. ]]
function M.alive_(instance)
	if not instance then return false end
	local ok, result = pcall(function() return instance.Parent ~= nil end)
	return ok and result
end
M.isAlive = M.alive_

return M
