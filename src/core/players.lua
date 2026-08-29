--[[═══════════════════════════════════════════════════════════════════════════
	core/players · the target query engine
	─────────────────────────────────────────────────────────────────────────
	One place that turns a command argument into a list of Targets.

	    ;kill bob            prefix match on name or display name
	    ;kill @bob           match the account name only
	    ;kill all            every player
	    ;kill others         everyone but you
	    ;kill all-bob        every player except bob
	    ;kill %raiders       every player on a team starting with "raiders"
	    ;kill #3             three random players from the current selection
	    ;kill nearest        closest player to you
	    ;kill rad50          everyone within 50 studs
	    ;kill bob,jim        union of two groups
	    ;kill 1234567        by user id

	Legacy behaviour is preserved, with these deliberate fixes:

	  · a selector that finds nobody returns an empty list instead of nil.
	    `nearest`/`farthest`/`rad` returned nil, and the caller then did
	    `pairs(nil)` -- `;goto nearest` alone in a server was a hard error.
	  · `random` no longer calls math.random(1, 0) in an empty server.
	  · `bacons` no longer indexes a nil Character.
	  · results are de-duplicated, so `;kill me,all` fires once per player.
	  · an exact name match wins over prefix matches, so `;kill bob` picks bob
	    and not bobby when both are present.
	  · `npcs` returns real NPC targets. The legacy selector built fake
	    `Instance.new("Player")` objects and then intersected them with the
	    real player list, which is always empty -- the selector never worked.
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Services = IY.import("core/services")
local Guard    = IY.import("core/guard")
local Log      = IY.import("core/log")
local Str      = IY.import("core/util/strings")
local Tbl      = IY.import("core/util/tables")
local Inst     = IY.import("core/util/instances")
local Target   = IY.import("core/target")

local Players = Services.Players

local M = {}

local function identity(target) return target.identityKey end

local function allTargets()
	local out = {}
	local list = Players:GetPlayers()
	for i = 1, #list do
		local target = Target.fromPlayer(list[i])
		if target then out[#out + 1] = target end
	end
	return out
end

--[[ Selector table. `fn(ctx, captures)` returns a list of Targets; ctx carries
     the speaker and the selection built so far. `universe = true` means the
     selector defines its own candidate set rather than filtering the player
     list. Literal selectors are looked up by hash; pattern selectors are tried
     in a stable sorted order so resolution is deterministic. ]]
local selectors = {}        -- pattern -> entry (for documentation)
local literals  = {}        -- token -> entry
local patterns  = {}        -- ordered array of entries
M.selectors = selectors

local function selector(pattern, describe, fn, opts)
	local entry = {
		pattern  = pattern,
		describe = describe,
		fn       = fn,
		universe = opts and opts.universe or false,
		token    = opts and opts.token or pattern,
	}
	selectors[pattern] = entry
	if string.find(pattern, "[%%%(%)%.%+%-%*%?%[%]%^%$]") then
		patterns[#patterns + 1] = entry
		table.sort(patterns, function(a, b) return a.pattern < b.pattern end)
	else
		literals[pattern] = entry
	end
	return entry
end

selector("all", "every player", function() return allTargets() end)
selector("me", "yourself", function(ctx) return { ctx.speaker } end)

selector("others", "everyone except you", function(ctx)
	return Tbl.filter(allTargets(), function(t) return t.identityKey ~= ctx.speaker.identityKey end)
end)

selector("random", "one random player", function(ctx)
	local pool = Tbl.filter(allTargets(), function(t) return t.identityKey ~= ctx.speaker.identityKey end)
	if #pool == 0 then return {} end
	return { pool[math.random(1, #pool)] }
end)

selector("#(%d+)", "N random players", function(ctx, captures)
	local wanted = tonumber(captures[1]) or 0
	return Tbl.sample(ctx.current, wanted)
end, { token = "#N" })

selector("%%(.+)", "players on a team", function(ctx, captures)
	local query = Str.lower(captures[1])
	return Tbl.filter(allTargets(), function(t)
		local team = t.team
		return team ~= nil and Str.matchesPrefix(team.Name, query)
	end)
end, { token = "%team" })

local function sameTeam(ctx, wantSame)
	local myTeam = ctx.speaker.team
	return Tbl.filter(allTargets(), function(t)
		local same = t.team == myTeam
		return wantSame == same
	end)
end

selector("allies",  "players on your team",     function(ctx) return sameTeam(ctx, true) end)
selector("team",    "players on your team",     function(ctx) return sameTeam(ctx, true) end)
selector("enemies", "players not on your team", function(ctx) return sameTeam(ctx, false) end)
selector("nonteam", "players not on your team", function(ctx) return sameTeam(ctx, false) end)

local function friendFilter(ctx, wantFriend)
	local myId = ctx.speaker.userId
	return Tbl.filter(allTargets(), function(t)
		if t.identityKey == ctx.speaker.identityKey then return false end
		local player = t.player
		if not player then return false end
		local ok, isFriend = pcall(function() return player:IsFriendsWith(myId) end)
		if not ok then return false end
		return isFriend == wantFriend
	end)
end

selector("friends",    "your friends in the server",  function(ctx) return friendFilter(ctx, true) end)
selector("nonfriends", "players who are not friends", function(ctx) return friendFilter(ctx, false) end)

selector("guests", "guest accounts", function()
	return Tbl.filter(allTargets(), function(t)
		local player = t.player
		if not player then return false end
		local ok, guest = pcall(function() return player.Guest end)
		return ok and guest == true
	end)
end)

selector("bacons", "players wearing default hair", function()
	return Tbl.filter(allTargets(), function(t)
		local character = t.character
		if not character then return false end
		return character:FindFirstChild("Pal Hair") ~= nil
			or character:FindFirstChild("Kate Hair") ~= nil
	end)
end)

selector("age(%d+)", "accounts newer than N days", function(_, captures)
	local age = tonumber(captures[1])
	if not age then return {} end
	return Tbl.filter(allTargets(), function(t)
		local player = t.player
		if not player then return false end
		local ok, accountAge = pcall(function() return player.AccountAge end)
		return ok and accountAge <= age
	end)
end, { token = "ageN" })

selector("group(%d+)", "members of a group", function(_, captures)
	local groupId = tonumber(captures[1])
	if not groupId then return {} end
	return Tbl.filter(allTargets(), function(t)
		local player = t.player
		if not player then return false end
		local ok, inGroup = pcall(function() return player:IsInGroup(groupId) end)
		return ok and inGroup == true
	end)
end, { token = "groupN" })

selector("alive", "players who are alive", function()
	return Tbl.filter(allTargets(), function(t) return t.alive end)
end)

selector("dead", "players who are dead", function()
	return Tbl.filter(allTargets(), function(t) return not t.alive end)
end)

local function byDistance(ctx, comparator)
	local origin = ctx.speaker.position
	if not origin then return {} end
	local best, bestDistance = nil, nil
	for i = 1, #ctx.current do
		local candidate = ctx.current[i]
		if candidate.identityKey ~= ctx.speaker.identityKey and candidate.root then
			local distance = candidate:distanceTo(origin)
			if bestDistance == nil or comparator(distance, bestDistance) then
				best, bestDistance = candidate, distance
			end
		end
	end
	if not best then return {} end
	return { best }
end

selector("nearest",  "the closest player",  function(ctx) return byDistance(ctx, function(a, b) return a < b end) end)
selector("farthest", "the furthest player", function(ctx) return byDistance(ctx, function(a, b) return a > b end) end)

selector("rad(%d+)", "players within N studs", function(ctx, captures)
	local radius = tonumber(captures[1])
	local origin = ctx.speaker.position
	if not radius or not origin then return {} end
	return Tbl.filter(allTargets(), function(t)
		return t.root ~= nil and t:distanceTo(origin) <= radius
	end)
end, { token = "radN" })

selector("cursor", "the player under your cursor", function(ctx)
	local found = M.underCursor()
	if not found then return {} end
	return { found }
end)

selector("npcs", "humanoid NPCs in the world", function()
	local out = {}
	local ok, descendants = pcall(function() return workspace:GetDescendants() end)
	if not ok then return out end
	for i = 1, #descendants do
		local model = descendants[i]
		if model:IsA("Model") and Inst.humanoid(model) and Inst.root(model)
			and not Players:GetPlayerFromCharacter(model) then
			local humanoid = Inst.humanoid(model)
			local display = humanoid and humanoid.DisplayName or nil
			local name = tostring(model.Name)
			if display and display ~= "" and display ~= name then
				name = name .. " - " .. display
			end
			out[#out + 1] = Target.fromCharacter(model, name)
		end
	end
	return out
end, { universe = true })

-- ── name matching ───────────────────────────────────────────────────────────

--[[ Players whose account or display name matches `query`.
     Exact matches (case-insensitive) win outright over prefix matches so that
     `;kill bob` cannot hit bobby while bob is in the server. ]]
function M.byName(query, accountOnly)
	local needle = Str.lower(Str.trim(query))
	if needle == "" then return {} end

	local exact, prefix = {}, {}
	local list = Players:GetPlayers()
	for i = 1, #list do
		local player = list[i]
		local name = Str.lower(player.Name)
		local display = accountOnly and name or Str.lower(player.DisplayName or player.Name)
		if name == needle or display == needle then
			exact[#exact + 1] = Target.fromPlayer(player)
		elseif Str.matchesPrefix(name, needle) or (not accountOnly and Str.matchesPrefix(display, needle)) then
			prefix[#prefix + 1] = Target.fromPlayer(player)
		end
	end
	if #exact > 0 then return exact end
	return prefix
end

--[[ A bare number is treated as a user id, which the legacy resolver could not
     do at all -- useful for moderation commands where the name is unreadable. ]]
local function byUserId(query)
	local id = tonumber(query)
	if not id or id <= 0 or query:match("^%d+$") == nil then return nil end
	local list = Players:GetPlayers()
	for i = 1, #list do
		if list[i].UserId == id then return { Target.fromPlayer(list[i]) } end
	end
	return {}
end

--[[ Closest player to the mouse cursor on screen. ]]
function M.underCursor()
	local camera = workspace.CurrentCamera
	if not camera then return nil end
	local mouse = Services.UserInputService:GetMouseLocation()
	local best, bestDistance = nil, math.huge
	local list = Players:GetPlayers()
	for i = 1, #list do
		local player = list[i]
		if player ~= Players.LocalPlayer then
			local root = Inst.root(player.Character)
			if root then
				local ok, screenPoint, onScreen = pcall(function()
					return camera:WorldToViewportPoint(root.Position)
				end)
				if ok and onScreen then
					local distance = (Vector2.new(screenPoint.X, screenPoint.Y) - mouse).Magnitude
					if distance < bestDistance then
						bestDistance, best = distance, Target.fromPlayer(player)
					end
				end
			end
		end
	end
	return best
end

-- ── token evaluation ────────────────────────────────────────────────────────

--[[ Split "+a-b" into ordered {op, text} tokens. A bare name is implicitly +. ]]
local function tokenise(group)
	local tokens = {}
	local text = group
	if string.sub(text, 1, 1) ~= "+" and string.sub(text, 1, 1) ~= "-" then
		text = "+" .. text
	end
	for op, name in string.gmatch(text, "([+-])([^+-]*)") do
		if name ~= "" then tokens[#tokens + 1] = { op = op, text = name } end
	end
	return tokens
end

--[[ Resolve one token to a list of Targets, plus whether it defines a universe. ]]
local function matchToken(ctx, token)
	local text = Str.lower(token)

	local literal = literals[text]
	if literal then
		local ok, result = pcall(literal.fn, ctx, {})
		if not ok then
			Log.debug("players", "selector '%s' failed: %s", text, tostring(result))
			return {}, literal.universe
		end
		return result or {}, literal.universe
	end

	for i = 1, #patterns do
		local entry = patterns[i]
		local captures = { string.match(text, "^" .. entry.pattern .. "$") }
		if captures[1] ~= nil then
			local ok, result = pcall(entry.fn, ctx, captures)
			if not ok then
				Log.debug("players", "selector '%s' failed: %s", entry.pattern, tostring(result))
				return {}, entry.universe
			end
			return result or {}, entry.universe
		end
	end

	if string.sub(token, 1, 1) == "@" then
		return M.byName(string.sub(token, 2), true), false
	end

	local ids = byUserId(token)
	if ids then return ids, false end

	return M.byName(token, false), false
end

--[[ Resolve a full query string into a de-duplicated list of Targets. ]]
function M.resolve(query, speaker, opts)
	opts = opts or {}
	local speakerTarget = speaker and (Target.is(speaker) and speaker or Target.coerce(speaker))
		or Target.localTarget()

	if query == nil or Str.trim(tostring(query)) == "" then
		if opts.defaultAll then return allTargets() end
		return { speakerTarget }
	end

	local found = {}
	local groups = Str.split(tostring(query), ",")
	for g = 1, #groups do
		local group = Str.trim(groups[g])
		if group ~= "" then
			local tokens = tokenise(group)
			local universe = allTargets()
			local current = nil
			for t = 1, #tokens do
				local token = tokens[t]
				local matched, isUniverse = matchToken(
					{ speaker = speakerTarget, current = current or universe }, token.text)
				if current == nil then
					-- First token: a universe selector replaces the candidate
					-- set, everything else filters the full player list.
					if token.op == "-" then
						current = Tbl.differenceBy(universe, matched, identity)
					elseif isUniverse then
						current = matched
					else
						current = Tbl.intersectBy(universe, matched, identity)
					end
				elseif token.op == "+" then
					current = Tbl.intersectBy(current, matched, identity)
				else
					current = Tbl.differenceBy(current, matched, identity)
				end
			end
			if current then Tbl.append(found, current) end
		end
	end

	return Tbl.unique(found, identity)
end

--[[ Resolve, or raise a user-facing error naming the query that failed. This is
     what the `players` argument type uses, so every command gets the same
     "no player matched" message instead of silently doing nothing. ]]
function M.require(query, speaker, opts)
	local targets = M.resolve(query, speaker, opts)
	if #targets == 0 then
		Guard.fail("no player matched '%s'", tostring(query))
	end
	return targets
end

--[[ Exactly one target: the first match, erroring when there is none. ]]
function M.requireOne(query, speaker, opts)
	local targets = M.require(query, speaker, opts)
	return targets[1]
end

function M.me()
	return Target.localTarget()
end

--[[ Autocomplete: names and selectors that start with `partial`. ]]
function M.suggest(partial)
	local needle = Str.lower(Str.trim(partial or ""))
	local out = {}
	local list = Players:GetPlayers()
	for i = 1, #list do
		local name = list[i].Name
		if needle == "" or Str.matchesPrefix(name, needle) then out[#out + 1] = name end
	end
	for _, entry in pairs(selectors) do
		local token = entry.token
		if not string.find(token, "%%") and not string.find(token, "%(") then
			if needle == "" or Str.matchesPrefix(token, needle) then out[#out + 1] = token end
		end
	end
	table.sort(out)
	return out
end

--[[ Documentation rows for the help panel. ]]
function M.selectorHelp()
	local out = {}
	for pattern, entry in pairs(selectors) do
		out[#out + 1] = { token = entry.token, describe = entry.describe }
	end
	return Tbl.sortBy(out, function(row) return row.token end)
end

--[[ Legacy shim: an array of names, for plugins written against getPlayer. ]]
function M.resolveNames(query, speaker)
	return Tbl.map(M.resolve(query, speaker), function(target) return target.name end)
end

return M
