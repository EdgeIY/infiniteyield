--[[═══════════════════════════════════════════════════════════════════════════
	core/target · what a command actually operates on
	─────────────────────────────────────────────────────────────────────────
	The legacy player resolver returned an array of *names*, and every command
	then did `Players[name]` -- which throws if the player left in the meantime,
	and cannot represent an NPC at all (the `npcs` selector called
	`Instance.new("Player")`, which modern Roblox refuses to create).

	A Target wraps "the thing to act on" uniformly:

	    target.name          "Player1"
	    target.player        Player instance, or nil for an NPC
	    target.character      live lookup, nil-safe
	    target.root           HumanoidRootPart, nil-safe
	    target.humanoid       Humanoid, nil-safe
	    target.alive          boolean
	    target.position       Vector3 or nil
	    target:requireRoot()  raises a clean "X has no character" user error

	Computed fields are looked up on access, so a target held across a respawn
	still points at the new character instead of a destroyed model.
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Guard    = IY.import("core/guard")
local Inst     = IY.import("core/util/instances")
local Services = IY.import("core/services")

local Players = Services.Players

local Target = {}
local methods = {}
local computed = {}

-- ── computed properties ─────────────────────────────────────────────────────

computed.character = function(self)
	if self.player then
		local ok, character = pcall(function() return self.player.Character end)
		if ok then return character end
		return nil
	end
	local model = rawget(self, "_character")
	if model and model.Parent then return model end
	return nil
end

computed.root      = function(self) return Inst.root(self.character) end
computed.humanoid  = function(self) return Inst.humanoid(self.character) end
computed.alive     = function(self) return Inst.alive(self.character) end
computed.position  = function(self) local r = self.root return r and r.Position or nil end
computed.cframe    = function(self) local r = self.root return r and r.CFrame or nil end
computed.health    = function(self) local h = self.humanoid return h and h.Health or 0 end

computed.displayName = function(self)
	if self.player then
		local ok, name = pcall(function() return self.player.DisplayName end)
		if ok and name then return name end
	end
	return self.name
end

computed.userId = function(self)
	if self.player then
		local ok, id = pcall(function() return self.player.UserId end)
		if ok then return id end
	end
	return 0
end

computed.team = function(self)
	if self.player then
		local ok, team = pcall(function() return self.player.Team end)
		if ok then return team end
	end
	return nil
end

computed.backpack = function(self)
	if self.player then
		local ok, backpack = pcall(function() return self.player:FindFirstChildOfClass("Backpack") end)
		if ok then return backpack end
	end
	return nil
end

computed.tools = function(self)
	if self.player then return Inst.tools(self.player) end
	return {}
end

computed.isLocal = function(self)
	return self.player ~= nil and self.player == Players.LocalPlayer
end

-- ── methods ─────────────────────────────────────────────────────────────────

--[[ Character or a user-facing error. Commands that cannot work without a
     character call this instead of silently doing nothing. ]]
function methods:requireCharacter()
	local character = self.character
	if not character then
		Guard.fail("%s has no character right now", self.name)
	end
	return character
end

function methods:requireRoot()
	local root = self.root
	if not root then
		Guard.fail("%s has no character right now", self.name)
	end
	return root
end

function methods:requireHumanoid()
	local humanoid = self.humanoid
	if not humanoid then
		Guard.fail("%s has no humanoid right now", self.name)
	end
	return humanoid
end

function methods:requirePlayer()
	if not self.player then
		Guard.fail("%s is an NPC -- this command needs a real player", self.name)
	end
	return self.player
end

function methods:distanceTo(position)
	local root = self.root
	if not root or not position then return math.huge end
	return (root.Position - position).Magnitude
end

--[[ "Name (DisplayName)" when they differ, else just the name. ]]
function methods:label()
	local display = self.displayName
	if display and display ~= self.name then
		return string.format("%s (%s)", self.name, display)
	end
	return self.name
end

function methods:exists()
	if self.player then
		local ok, parent = pcall(function() return self.player.Parent end)
		return ok and parent ~= nil
	end
	return self.character ~= nil
end

function methods:identity()
	if self.player then return "p:" .. tostring(self.userId ~= 0 and self.userId or self.name) end
	return "n:" .. tostring(self.name)
end

-- ── metatable ───────────────────────────────────────────────────────────────

Target.__index = function(self, key)
	local getter = computed[key]
	if getter then return getter(self) end
	return methods[key]
end

Target.__tostring = function(self)
	return self.name
end

Target.__eq = function(a, b)
	return a.identityKey == b.identityKey
end

-- ── constructors ────────────────────────────────────────────────────────────

local M = {}

function M.fromPlayer(player)
	if not player then return nil end
	local ok, name = pcall(function() return player.Name end)
	if not ok then return nil end
	local userId = 0
	pcall(function() userId = player.UserId end)
	return setmetatable({
		name        = name,
		player      = player,
		isNPC       = false,
		identityKey = "p:" .. tostring(userId ~= 0 and userId or name),
	}, Target)
end

--[[ An NPC target: a character model with no Player behind it. Identity is a
     per-model token from a weak table, because NPC models have duplicate names
     and GetDebugId is not available on every executor. ]]
local npcIdentity = setmetatable({}, { __mode = "k" })
local npcCounter = 0

function M.fromCharacter(model, name)
	if not model then return nil end
	local key = npcIdentity[model]
	if not key then
		npcCounter = npcCounter + 1
		key = "n:" .. tostring(npcCounter) .. ":" .. tostring(model.Name)
		npcIdentity[model] = key
	end
	return setmetatable({
		name        = name or tostring(model.Name),
		player      = nil,
		isNPC       = true,
		_character  = model,
		identityKey = key,
	}, Target)
end

function M.localTarget()
	return M.fromPlayer(Players.LocalPlayer)
end

function M.is(value)
	return type(value) == "table" and getmetatable(value) == Target
end

--[[ Wrap a mixed list of Players / Targets / character models. ]]
function M.coerce(value)
	if value == nil then return nil end
	if M.is(value) then return value end
	if typeof(value) == "Instance" then
		if value:IsA("Player") then return M.fromPlayer(value) end
		if value:IsA("Model") then
			local player = Players:GetPlayerFromCharacter(value)
			if player then return M.fromPlayer(player) end
			return M.fromCharacter(value)
		end
	end
	return nil
end

function M.coerceList(list)
	local out = {}
	for i = 1, #list do
		local target = M.coerce(list[i])
		if target then out[#out + 1] = target end
	end
	return out
end

M.class = Target
M.methods = methods
M.computed = computed

return M
