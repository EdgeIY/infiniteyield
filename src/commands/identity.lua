--[[═══════════════════════════════════════════════════════════════════════════
	commands/identity · names and ids, on the clipboard or in a notification
	─────────────────────────────────────────────────────────────────────────
	Legacy equivalent: source.ref.lua 8979-9058.

	Two things changed for every command in this pack:

	  · the legacy bodies did `for i,v in pairs(getPlayer(...)) do
	    toClipboard(Players[v].UserId) end`, so `;copyid all` overwrote the
	    clipboard once per player and left only the last one. Each command
	    gathers first and copies once.
	  · `Players[name]` threw when the player had left between resolving and
	    reading. Targets look their player up on access.
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Cmd      = IY.import("cmd/api")
local Env      = IY.import("core/env")
local Guard    = IY.import("core/guard")
local Services = IY.import("core/services")

local group = Cmd.group{ category = "Identity" }

local function copy(ctx, text)
	Env.fn.setclipboard(tostring(text))
	ctx:notify("Clipboard", "Copied to clipboard")
end

--[[ Collect one field from every target, skipping the ones that failed --
     ctx:each already reports a summary. ]]
local function gather(ctx, fn)
	local out = {}
	ctx:each(function(target)
		local value = fn(target)
		if value ~= nil then out[#out + 1] = tostring(value) end
	end)
	if #out == 0 then Guard.fail("nothing to read from those players") end
	return out
end

-- ── players ─────────────────────────────────────────────────────────────────

group{
	name = "copyname",
	aliases = { "copyuser" },
	description = "Copies a player's full username to your clipboard.",
	args = { { name = "players", type = "players", optional = true } },
	requires = { capability = "setclipboard" },
	examples = { "copyname", "copyname all" },
	run = function(ctx)
		copy(ctx, table.concat(gather(ctx, function(target) return target.name end), ", "))
	end,
}

group{
	name = "userid",
	aliases = { "id" },
	description = "Notifies you a player's user id.",
	args = { { name = "players", type = "players", optional = true } },
	run = function(ctx)
		local rows = gather(ctx, function(target)
			return target.name .. ": " .. tostring(target.userId)
		end)
		-- One notification for the batch; the legacy version sent one per player
		-- and the dedupe window swallowed most of them.
		ctx:notify("User ID", table.concat(rows, "\n"))
	end,
}

group{
	name = "copyid",
	aliases = { "copyuserid" },
	description = "Copies a player's user id to your clipboard.",
	args = { { name = "players", type = "players", optional = true } },
	requires = { capability = "setclipboard" },
	run = function(ctx)
		copy(ctx, table.concat(gather(ctx, function(target) return target.userId end), ", "))
	end,
}

group{
	name = "appearanceid",
	aliases = { "aid" },
	description = "Notifies you a player's character appearance id.",
	args = { { name = "players", type = "players", optional = true } },
	run = function(ctx)
		local rows = gather(ctx, function(target)
			local player = target:requirePlayer()
			return target.name .. ": " .. tostring(player.CharacterAppearanceId)
		end)
		ctx:notify("Appearance ID", table.concat(rows, "\n"))
	end,
}

group{
	name = "copyappearanceid",
	aliases = { "caid" },
	description = "Copies a player's character appearance id to your clipboard.",
	args = { { name = "players", type = "players", optional = true } },
	requires = { capability = "setclipboard" },
	run = function(ctx)
		copy(ctx, table.concat(gather(ctx, function(target)
			return target:requirePlayer().CharacterAppearanceId
		end), ", "))
	end,
}

-- ── this place ──────────────────────────────────────────────────────────────

group{
	name = "copyplaceid",
	aliases = { "placeid" },
	description = "Copies this place's id to your clipboard.",
	requires = { capability = "setclipboard" },
	run = function(ctx)
		copy(ctx, game.PlaceId)
	end,
}

group{
	name = "copygameid",
	aliases = { "gameid" },
	description = "Copies this game's universe id to your clipboard.",
	requires = { capability = "setclipboard" },
	run = function(ctx)
		copy(ctx, game.GameId)
	end,
}

--[[ For a group-owned game the creator is the group's *owner*, which needs a web
     call. Contained, because GetGroupInfoAsync fails in games that block it --
     the legacy version let the error out as "attempt to index nil". ]]
local function creatorId()
	local isGroup = false
	pcall(function() isGroup = game.CreatorType == Enum.CreatorType.Group end)
	if not isGroup then return game.CreatorId, "user" end

	local ok, info = pcall(function()
		return Services.GroupService:GetGroupInfoAsync(game.CreatorId)
	end)
	if not ok or type(info) ~= "table" or type(info.Owner) ~= "table" then
		Guard.fail("could not look up the owner of group %s", tostring(game.CreatorId))
	end
	return info.Owner.Id, "group"
end

group{
	name = "creatorid",
	aliases = { "creator" },
	description = "Notifies you the id of whoever owns this game.",
	run = function(ctx)
		local id, kind = creatorId()
		-- The legacy group branch also assigned speaker.UserId here, which was a
		-- copy-and-paste of setcreatorid and threw on every group game.
		ctx:notify("Creator ID", tostring(id) .. " (" .. kind .. ")")
	end,
}

group{
	name = "copycreatorid",
	aliases = { "copycreator" },
	description = "Copies the id of whoever owns this game to your clipboard.",
	requires = { capability = "setclipboard" },
	run = function(ctx)
		Env.fn.setclipboard(tostring(creatorId()))
		ctx:notify("Copied ID", "Copied creator ID to clipboard")
	end,
}

group{
	name = "setcreatorid",
	aliases = { "setcreator" },
	description = "Sets your local user id to the game owner's.",
	run = function(ctx)
		local id = creatorId()
		local player = ctx.speaker:requirePlayer()
		local ok, err = pcall(function() player.UserId = id end)
		if not ok then
			ctx:fail("your executor cannot change UserId locally (%s)", Guard.describe(err))
		end
		ctx:notify("Set ID", "Set UserId to " .. tostring(id))
	end,
}

return true
