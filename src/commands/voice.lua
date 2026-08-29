--[[═══════════════════════════════════════════════════════════════════════════
	commands/voice · muting voice chat
	─────────────────────────────────────────────────────────────────────────
	muteallvoices, unmuteallvoices, mutevc and unmutevc.

	Legacy equivalent: source.ref.lua 12824-12844. features/voice owns the
	service lookup, the guarded calls, and the record of who we muted -- which is
	what makes `unmuteallvoices` able to undo `;mutevc bob` as well as the global
	pause. Legacy cleared only the global flag and left individual pauses in
	place with nothing tracking them.
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Cmd   = IY.import("cmd/api")
local Voice = IY.import("features/voice")

local group = Cmd.group{ category = "Chat" }

group{
	name = "muteallvoices",
	aliases = { "muteallvcs" },
	description = "Mutes every voice in the server for you.",
	examples = { "muteallvoices", "unmuteallvoices" },
	-- No generated toggle: the on half is destructive enough that it belongs
	-- behind an explicit name, and legacy shipped none.
	toggle = false,
	offAliases = { "unmuteallvcs" },
	offDescription = "Unmutes every voice, including any you muted individually.",
	run = function(ctx)
		if not Voice.available() then ctx:fail("this game does not have voice chat") end
		Voice.muteAll()
		if not ctx:quiet() then ctx:reply("Muted every voice") end
	end,
	off = function(ctx)
		if not Voice.available() then ctx:fail("this game does not have voice chat") end
		local individual = Voice.unmuteAll()
		if ctx:quiet() then return end
		if individual > 0 then
			ctx:reply("Unmuted every voice, including " .. tostring(individual)
				.. " you had muted individually")
		else
			ctx:reply("Unmuted every voice")
		end
	end,
}

group{
	name = "mutevc",
	description = "Mutes the voice of the players you name.",
	args = {
		-- Legacy skipped the speaker with `continue` (12834), so `;mutevc` with
		-- no argument silently did nothing at all. `excludeSelf` says so.
		{ name = "players", type = "players", excludeSelf = true },
	},
	examples = { "mutevc bob", "mutevc others", "unmutevc bob" },
	toggle = false,
	offDescription = "Unmutes the voice of the players you name.",
	run = function(ctx)
		if not Voice.available() then ctx:fail("this game does not have voice chat") end
		local muted = ctx:each(function(target) Voice.mute(target) end)
		if not ctx:quiet() then
			ctx:reply("Muted " .. tostring(muted) .. " voice(s)")
		end
	end,
	off = function(ctx)
		if not Voice.available() then ctx:fail("this game does not have voice chat") end
		local unmuted = ctx:each(function(target) Voice.unmute(target) end)
		if not ctx:quiet() then
			ctx:reply("Unmuted " .. tostring(unmuted) .. " voice(s)")
		end
	end,
}

return true
