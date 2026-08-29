--[[═══════════════════════════════════════════════════════════════════════════
	commands/social · who a player is, and two odds and ends
	─────────────────────────────────────────────────────────────────────────
	age, chatage, joindate, chatjoindate, findfriendgroups, listento, blockhead,
	blockhats and blocktool.

	Legacy equivalent: source.ref.lua 8927-8978 (age, chatage, joindate,
	chatjoindate), 12515-12581 (playerGroups, findfriendgroups), 12736-12755
	(listento, unlistento) and 10786-10810 (blockhead, blockhats, blocktool).

	The four account-info commands read `Players[v].AccountAge` and then did
	arithmetic on it (8953). Both halves can fail: `Players[v]` throws once the
	player has left, and the read itself is not guaranteed, so the multiplication
	was on nil. Each read is contained and reported per player, and `ctx:each`
	keeps one departed player from cancelling the whole list.

	`findfriendgroups` is a web call per *pair* of players. Legacy wrapped each in
	a pcall already; what it did not do was tolerate a player leaving mid-scan.

	The listener lives in features/listento; the block* commands are one-shots
	and stay here.
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Cmd      = IY.import("cmd/api")
local Chat     = IY.import("features/chat")
local Listen   = IY.import("features/listento")
local Guard    = IY.import("core/guard")
local Inst     = IY.import("core/util/instances")
local Services = IY.import("core/services")

local Players = Services.Players

local group = Cmd.group{ category = "Players" }

-- ── account age and join date ───────────────────────────────────────────────

local function accountAge(target)
	local player = target:requirePlayer()
	local ok, age = Guard.call("social.accountAge", function() return player.AccountAge end)
	if not ok or type(age) ~= "number" then
		Guard.fail("could not read %s's account age", target.name)
	end
	return age
end

local function ageLines(ctx)
	local lines = {}
	ctx:each(function(target)
		lines[#lines + 1] = target.name .. "'s age is: " .. tostring(accountAge(target))
	end)
	return lines
end

--[[ Legacy 8951-8956: AccountAge is in days, so the creation date is now minus
     that many days, formatted month/day/year. ]]
local function joinLines(ctx)
	local lines = {}
	local now = os.time()
	ctx:each(function(target)
		local seconds = accountAge(target) * 24 * 60 * 60
		lines[#lines + 1] = target.name .. " joined: " .. os.date("%m/%d/%y", now - seconds)
	end)
	return lines
end

group{
	name = "age",
	description = "Shows how many days old a player's account is.",
	args = {
		{ name = "players", type = "players" },
	},
	examples = { "age", "age bob", "age all" },
	run = function(ctx)
		ctx:notify("Account Age", table.concat(ageLines(ctx), ",\n"))
	end,
}

group{
	name = "chatage",
	description = "Says a player's account age in the chat.",
	args = {
		{ name = "players", type = "players" },
	},
	examples = { "chatage", "chatage bob" },
	run = function(ctx)
		Chat.say(table.concat(ageLines(ctx), ", "))
	end,
}

group{
	name = "joindate",
	aliases = { "jd" },
	description = "Shows the date a player's account was created.",
	args = {
		{ name = "players", type = "players" },
	},
	examples = { "joindate", "jd bob" },
	run = function(ctx)
		ctx:notify("Join Date (Month/Day/Year)", table.concat(joinLines(ctx), ",\n"))
	end,
}

group{
	name = "chatjoindate",
	aliases = { "cjd" },
	description = "Says a player's account creation date in the chat.",
	args = {
		{ name = "players", type = "players" },
	},
	examples = { "chatjoindate", "cjd bob" },
	run = function(ctx)
		Chat.say(table.concat(joinLines(ctx), ", "))
	end,
}

-- ── friend groups ───────────────────────────────────────────────────────────

--[[ Legacy playerGroups (12515-12561): build a friendship graph over everyone in
     the server, then take its connected components. One web call per pair, which
     is why the command warns first. A failed or refused call means "not
     friends" rather than aborting the scan. ]]
local function friendGroups()
	local players = Players:GetPlayers()
	local edges = {}
	for i = 1, #players do edges[players[i]] = {} end

	for i = 1, #players do
		for j = i + 1, #players do
			local a, b = players[i], players[j]
			local ok, friends = Guard.call("social.isFriends", function()
				return a:IsFriendsWithAsync(b.UserId)
			end)
			if ok and friends == true then
				table.insert(edges[a], b)
				table.insert(edges[b], a)
			end
		end
	end

	local seen, components = {}, {}
	local function walk(player, component)
		seen[player] = true
		component[#component + 1] = player
		local neighbours = edges[player] or {}
		for k = 1, #neighbours do
			if not seen[neighbours[k]] then walk(neighbours[k], component) end
		end
	end
	for i = 1, #players do
		if not seen[players[i]] then
			local component = {}
			walk(players[i], component)
			components[#components + 1] = component
		end
	end
	return components
end

group{
	name = "findfriendgroups",
	description = "Finds which players in the server are friends with each other.",
	examples = { "findfriendgroups" },
	run = function(ctx)
		ctx:notify("Checking Players", "This might take a while (slow function)")

		-- Legacy read the PlayerList CoreGui to decide which name the user is
		-- actually looking at (12571).
		local display = Guard.try(function()
			return Services.StarterGui:GetCoreGuiEnabled(Enum.CoreGuiType.PlayerList)
		end) == true

		local lines = {}
		local components = friendGroups()
		for i = 1, #components do
			local component = components[i]
			if #component > 1 then
				local names = {}
				for j = 1, #component do
					local player = component[j]
					local name = tostring(player.Name)
					if display then
						name = tostring(Guard.try(function() return player.DisplayName end) or name)
					end
					names[#names + 1] = name
				end
				lines[#lines + 1] = tostring(#lines + 1) .. ". " .. table.concat(names, ", ")
			end
		end

		-- Legacy showed this in a popup window; a notification carries the same
		-- text without the command pack having to reach into the interface.
		ctx:notify("Friend Groups", #lines == 0 and "None" or table.concat(lines, "\n"))
	end,
}

-- ── the audio listener ──────────────────────────────────────────────────────

group{
	name = "listento",
	description = "Hears the world from another player's position.",
	args = {
		-- Required, where legacy returned silently with no argument (12738).
		{ name = "player", type = "player", optional = false },
	},
	examples = { "listento bob", "unlistento" },
	toggle = false,
	offArgs = {},
	offDescription = "Puts the audio listener back on your camera.",
	run = function(ctx)
		local target = ctx.args.player
		Listen.start(target)
		if not ctx:quiet() then ctx:reply("Listening from " .. target:label()) end
	end,
	off = function(ctx)
		Listen.stop()
		if not ctx:quiet() then ctx:reply("Listening from your camera again") end
	end,
}

-- ── block heads, hats and tools ─────────────────────────────────────────────

--[[ Destroy every SpecialMesh under `instance`. Legacy chained
     `Head:FindFirstChildOfClass("SpecialMesh"):Destroy()` (10787) with no nil
     check at either step, so a character with no Head, or a Head whose mesh the
     game had already removed, threw. ]]
local function destroyMeshes(instance, deep)
	local meshes = Inst.ofClass(instance, "SpecialMesh", deep)
	local removed = 0
	for i = 1, #meshes do
		if pcall(function() meshes[i]:Destroy() end) then removed = removed + 1 end
	end
	return removed
end

--[[ Tools and HopperBins held by the character, which is what legacy walked
     (10801). ]]
local function heldItems(character)
	local out = Inst.ofClass(character, "Tool", false)
	local bins = Inst.ofClass(character, "HopperBin", false)
	for i = 1, #bins do out[#out + 1] = bins[i] end
	return out
end

--[[ These three destroy meshes, which nothing can put back, so they stay
     one-shots with no off command -- exactly as legacy had them. The optional
     players argument is new and defaults to you: the change is local either way,
     so `;blockhead all` is a client-side visual like the rest of this pack. ]]
group{
	name = "blockhead",
	category = "Character",
	description = "Removes the mesh from a head, leaving a plain block.",
	args = {
		{ name = "players", type = "players", optional = true },
	},
	examples = { "blockhead", "blockhead all" },
	run = function(ctx)
		local removed = 0
		ctx:each(function(target)
			local character = target:requireCharacter()
			local head = character:FindFirstChild("Head")
			if not head then Guard.fail("%s has no head", target.name) end
			removed = removed + destroyMeshes(head, false)
		end)
		if removed == 0 then ctx:fail("there was no head mesh to remove") end
		if not ctx:quiet() then
			ctx:reply("Removed " .. tostring(removed) .. " head mesh(es)")
		end
	end,
}

group{
	name = "blockhats",
	category = "Character",
	description = "Removes the meshes from a player's accessories.",
	args = {
		{ name = "players", type = "players", optional = true },
	},
	examples = { "blockhats", "blockhats all" },
	run = function(ctx)
		local removed = 0
		ctx:each(function(target)
			local humanoid = target:requireHumanoid()
			-- GetAccessories does not exist on every client, and legacy walked
			-- whatever it returned with `pairs` -- nil included (10791).
			local accessories = Guard.try(function() return humanoid:GetAccessories() end) or {}
			for i = 1, #accessories do
				removed = removed + destroyMeshes(accessories[i], true)
			end
		end)
		if removed == 0 then ctx:fail("there were no accessory meshes to remove") end
		if not ctx:quiet() then
			ctx:reply("Removed " .. tostring(removed) .. " accessory mesh(es)")
		end
	end,
}

group{
	name = "blocktool",
	category = "Character",
	description = "Removes the meshes from the tools a player is holding.",
	args = {
		{ name = "players", type = "players", optional = true },
	},
	examples = { "blocktool", "blocktool all" },
	run = function(ctx)
		local removed = 0
		ctx:each(function(target)
			local items = heldItems(target:requireCharacter())
			for i = 1, #items do
				removed = removed + destroyMeshes(items[i], true)
			end
		end)
		if removed == 0 then ctx:fail("there were no tool meshes to remove") end
		if not ctx:quiet() then
			ctx:reply("Removed " .. tostring(removed) .. " tool mesh(es)")
		end
	end,
}

return true
