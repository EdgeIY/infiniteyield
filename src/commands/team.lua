--[[═══════════════════════════════════════════════════════════════════════════
	commands/team · joining a team, and clearing your overhead guis
	─────────────────────────────────────────────────────────────────────────
	`;team` keeps the legacy order of attack -- touch a SpawnLocation of that
	team's colour so the *server* moves you, and only fall back to writing
	Player.Team locally -- with three fixes:

	  · the team name is now an argument type, so `;team` with a name that does
	    not exist reports with the usage line instead of the command running and
	    doing nothing.
	  · legacy matched with `v.Name:lower():match(query)`, a Lua *pattern*, so a
	    team called "Red (VIP)" could never be matched by typing it. Plain
	    substring search.
	  · when no SpawnLocation of that colour existed, legacy fell out of its loop
	    and returned silently. The Player.Team fallback now runs in that case
	    too.

	Legacy equivalent: source.ref.lua 10044-10068, 10070-10097.
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Cmd    = IY.import("cmd/api")
local NoBgui = IY.import("features/nobgui")
local Env    = IY.import("core/env")
local Guard  = IY.import("core/guard")
local Str    = IY.import("core/util/strings")
local Services = IY.import("core/services")

local group = Cmd.group{ category = "Character" }

local function teamList()
	local teams = Services.get("Teams")
	if not teams then return {} end
	return Guard.try(function() return teams:GetChildren() end) or {}
end

Cmd.defineType("teamname", {
	greedy = true,   -- team names have spaces in them
	parse = function(raw)
		local teams = teamList()
		if #teams == 0 then Guard.fail("this game has no teams") end
		local needle = Str.lower(Str.trim(tostring(raw or "")))
		if needle == "" then Guard.fail("expected a team name") end
		for i = 1, #teams do
			if Str.lower(teams[i].Name) == needle then return teams[i] end
		end
		for i = 1, #teams do
			if string.find(Str.lower(teams[i].Name), needle, 1, true) then return teams[i] end
		end
		Guard.fail("'%s' is not a team in this server", tostring(raw))
	end,
	describe = function() return "team" end,
	complete = function(partial)
		local out = {}
		local teams = teamList()
		for i = 1, #teams do
			if Str.matchesPrefix(teams[i].Name, partial) then out[#out + 1] = teams[i].Name end
		end
		table.sort(out)
		return out
	end,
})

--[[ The first spawn pad that hands out this team on touch. ]]
local function spawnFor(team)
	local descendants = Guard.try(function() return workspace:GetDescendants() end)
	if not descendants then return nil end
	for i = 1, #descendants do
		local pad = descendants[i]
		if pad:IsA("SpawnLocation") and pad.AllowTeamChangeOnTouch
			and pad.BrickColor == team.TeamColor then
			return pad
		end
	end
	return nil
end

group{
	name = "team",
	description = "Puts you on a team by name.",
	args = {
		{ name = "team", type = "teamname" },
	},
	examples = { "team red", "team Guests" },
	run = function(ctx)
		local team = ctx.args.team
		local player = ctx.speaker:requirePlayer()
		local root = ctx.speaker.root

		if root and Env.usable("firetouchinterest") then
			local pad = spawnFor(team)
			if pad then
				local touch = Env.fn.firetouchinterest
				pcall(touch, pad, root, 0)
				pcall(touch, pad, root, 1)
				if not ctx:quiet() then ctx:reply("Touched the " .. team.Name .. " spawn") end
				return
			end
		end

		local ok = pcall(function() player.Team = team end)
		if not ok then ctx:fail("this game would not let you change team") end
		if not ctx:quiet() then ctx:reply("Team set to " .. team.Name) end
	end,
}

-- ── overhead guis ───────────────────────────────────────────────────────────

group{
	name = "nobgui",
	aliases = { "unbgui", "nobillboardgui", "unbillboardgui", "noname", "rohg" },
	description = "Removes every BillboardGui and SurfaceGui from your character.",
	examples = { "nobgui", "noname" },
	requires = { character = true },
	run = function(ctx)
		local removed = NoBgui.sweep()
		if not ctx:quiet() then
			ctx:reply(string.format("Removed %d overhead gui(s)", removed))
		end
	end,
}

group{
	name = "loopnobgui",
	aliases = { "loopunbgui", "loopnobillboardgui", "loopunbillboardgui", "loopnoname", "looprohg" },
	description = "Keeps overhead guis off your character, including after a respawn.",
	examples = { "loopnobgui", "unloopnobgui" },
	requires = { character = true },
	offAliases = { "unloopunbgui", "unloopnobillboardgui", "unloopunbillboardgui",
		"unloopnoname", "unlooprohg" },
	run = function(ctx)
		NoBgui.start()
		if not ctx:quiet() then ctx:reply("Overhead guis will be removed") end
	end,
	off = function(ctx)
		NoBgui.stop()
		if not ctx:quiet() then ctx:reply("No longer removing overhead guis") end
	end,
}

return true
