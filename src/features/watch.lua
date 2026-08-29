--[[═══════════════════════════════════════════════════════════════════════════
	features/watch · rolewatch and staffwatch
	─────────────────────────────────────────────────────────────────────────
	Replaces source.ref.lua 12427-12461 (the RolewatchData globals, the load-time
	PlayerAdded connection, rolewatch / rolewatchstop / rolewatchleave) and
	12463-12513 (staffRoles, getStaffRole, staffwatch / unstaffwatch).

	Both were "connect at load, never disconnect":

	  · rolewatch installed its `Players.PlayerAdded` handler at line 12428, for
	    every session, whether or not anyone ever ran the command. It was turned
	    off by setting a sentinel group id of 0, so the handler kept running for
	    the life of the script and `;unloadiy` left it connected.
	  · staffwatch's join handler was stored in a global and only disconnected if
	    you ran the command a second time (12481) or ran `unstaffwatch`. Neither
	    the load hook nor unload touched it.

	Each is a feature now, and the connection lives in its bin.

	The group and role lookups matter more than they look: `player:IsInGroup` and
	`player:GetRoleInGroup` are network-backed calls, made here on the join
	thread. Legacy made them bare, so a throttled or refused lookup raised inside
	the handler -- which for staffwatch also aborted the loop over the players
	already in the server (12492), silently reporting nobody. Every one of them is
	contained, and a failed lookup means "not a match" rather than "stop".
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Feature  = IY.import("features/feature")
local Guard    = IY.import("core/guard")
local Notify   = IY.import("core/notify")
local Services = IY.import("core/services")
local Str      = IY.import("core/util/strings")
local Target   = IY.import("core/target")

local Players = Services.Players

local M = {}

-- Legacy 12469: the group whose members Roblox staff belong to.
local ROBLOX_STAFF_GROUP = 1200769

-- Legacy 12463, unchanged: a substring of the role name is enough to match.
local STAFF_ROLES = { "mod", "admin", "staff", "dev", "founder", "owner",
	"supervis", "manager", "management", "executive", "president", "chairman",
	"chairwoman", "chairperson", "director" }

-- Legacy RolewatchData.Leave, which `rolewatchstop` also reset (12454).
local leaving = false

-- ── contained group lookups ─────────────────────────────────────────────────

local function inGroup(player, groupId)
	if not groupId or groupId <= 0 then return false end
	local ok, result = Guard.call("watch.isInGroup", function()
		return player:IsInGroup(groupId)
	end)
	return ok and result == true
end

local function roleIn(player, groupId)
	if not groupId or groupId <= 0 then return nil end
	local ok, role = Guard.call("watch.getRoleInGroup", function()
		return player:GetRoleInGroup(groupId)
	end)
	if not ok or role == nil then return nil end
	return tostring(role)
end

--[[ Legacy formatUsername (5607): "Name (DisplayName)" when they differ. ]]
local function label(player)
	local target = Target.fromPlayer(player)
	if target then return target:label() end
	return tostring(Guard.try(function() return player.Name end) or "someone")
end

-- ── rolewatch ───────────────────────────────────────────────────────────────

--[[ Notification text is legacy's, character for character (12433-12436),
     including the fact that it reports the *watched* role rather than the role
     string the lookup returned. ]]
local function consider(self, player)
	local groupId = self:option("group", 0)
	local wanted = self:option("role", nil)
	if not wanted then return false end
	if not inGroup(player, groupId) then return false end

	local role = roleIn(player, groupId)
	if not role or Str.lower(role) ~= Str.lower(wanted) then return false end

	local message = "Player \"" .. tostring(player.Name)
		.. "\" has joined with the Role \"" .. wanted .. "\""
	if self:option("leave", false) then
		Guard.call("watch.kick", function()
			Players.LocalPlayer:Kick("\n\nRolewatch\n" .. message .. "\n")
		end)
	else
		Notify.send("Rolewatch", message)
	end
	return true
end

local rolewatch = Feature.new("rolewatch", {
	command  = "rolewatch",
	describe = "watching joins for a group role",

	start = function(self, opts)
		local groupId = tonumber(opts.group)
		local role = Str.trim(tostring(opts.role or ""))
		-- Legacy took `tonumber(args[1] or 0)` and treated 0 as "off", so
		-- `;rolewatch 0 admin` armed a watch that could never fire.
		if not groupId or groupId <= 0 then Guard.fail("rolewatch needs a group id") end
		if role == "" then Guard.fail("rolewatch needs a role name") end
		self.opts.group = groupId
		self.opts.role = role
		self.bin:connect(Players.PlayerAdded, function(player)
			consider(self, player)
		end)
	end,
})

M.rolewatchFeature = rolewatch

function M.startRolewatch(groupId, role)
	rolewatch:start({ group = groupId, role = role, leave = leaving })
	return rolewatch:option("group", 0), rolewatch:option("role", "")
end

--[[ Legacy `rolewatchstop` cleared the leave flag as well (12454). ]]
function M.stopRolewatch()
	leaving = false
	return rolewatch:stop()
end

function M.rolewatching() return rolewatch:isRunning() end
function M.leaving() return leaving end

--[[ `enabled = nil` flips it, which is what legacy `rolewatchleave` did. ]]
function M.setLeave(enabled)
	if enabled == nil then
		leaving = not leaving
	else
		leaving = enabled == true
	end
	if rolewatch:isRunning() then rolewatch:configure({ leave = leaving }) end
	return leaving
end

-- ── staffwatch ──────────────────────────────────────────────────────────────

--[[ True when the place is owned by a group, which is the only case where
     `GetRoleInGroup(game.CreatorId)` means anything (12483). ]]
function M.groupOwned()
	return Guard.try(function()
		return game.CreatorType == Enum.CreatorType.Group
	end) == true
end

--[[ Legacy getStaffRole (12465-12478). Roblox employees are reported as such
     whatever their role in the game's group is. ]]
local function staffRole(player)
	local creatorId = Guard.try(function() return game.CreatorId end) or 0
	local role = roleIn(player, creatorId)
	local result = { role = role, staff = false }

	if inGroup(player, ROBLOX_STAFF_GROUP) then
		result.role = "Roblox Employee"
		result.staff = true
	elseif role then
		local lowered = Str.lower(role)
		for i = 1, #STAFF_ROLES do
			-- Plain find: legacy passed these through string.find as patterns,
			-- which happened to be harmless because none contain a magic
			-- character, but only by accident.
			if string.find(lowered, STAFF_ROLES[i], 1, true) then
				result.staff = true
				break
			end
		end
	end
	return result
end
M.staffRole = staffRole

local staffwatch = Feature.new("staffwatch", {
	command  = "staffwatch",
	describe = "watching joins for game staff",

	start = function(self)
		if not M.groupOwned() then Guard.fail("Game is not owned by a Group") end
		self.bin:connect(Players.PlayerAdded, function(player)
			local result = staffRole(player)
			if result.staff then
				Notify.send("Staffwatch", label(player) .. " is a " .. tostring(result.role))
			end
		end)
	end,
})

M.staffwatchFeature = staffwatch

function M.startStaffwatch() return staffwatch:start() end
function M.stopStaffwatch() return staffwatch:stop() end
function M.staffwatching() return staffwatch:isRunning() end

--[[ The staff already in the server, as "Name (Display) is a Role" lines.
     Legacy built this list inside the command with an unguarded lookup per
     player, so one refusal ended the scan (12492-12497). ]]
function M.scanStaff()
	local found = {}
	local list = Players:GetPlayers()
	for i = 1, #list do
		local result = staffRole(list[i])
		if result.staff then
			found[#found + 1] = label(list[i]) .. " is a " .. tostring(result.role)
		end
	end
	return found
end

return M
