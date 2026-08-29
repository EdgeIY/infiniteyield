--[[═══════════════════════════════════════════════════════════════════════════
	commands/visual · ESP, chams and world visuals
	─────────────────────────────────────────────────────────────────────────
	esp, espteam, esptransparency, chams, locate, partesp, xray, loopxray,
	hovername, stareat, light and copytools -- plus every `un`/`no`/`toggle`
	sibling the registry derives from their `off` handlers.

	Legacy equivalent: source.ref.lua 5720-5975 (the three renderers),
	8116-8274 (esp, espteam, noesp, esptransparency, partesp, unpartesp, chams,
	nochams, locate, nolocate), 12179-12215 (xray), 12283-12347 (hovername),
	12398-12425 (stareat), 11169-11200 (light, unlight, copytools), plus the
	re-application on join at 13217-13231 and the leave cleanup at 4057-4075,
	both of which features/highlight now owns.

	esp and chams are no longer mutually exclusive. Legacy refused to start one
	while the other was on (8117, 8226) because both wrote CoreGui folders named
	after the player and each cleaned up by searching for that name; adornments
	belong to a per-player bin now, so esp, chams and locate can all run at once.
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Cmd       = IY.import("cmd/api")
local Env       = IY.import("core/env")
local Store     = IY.import("core/store")
local Inst      = IY.import("core/util/instances")
local Esp       = IY.import("features/esp")
local Chams     = IY.import("features/chams")
local Locate    = IY.import("features/locate")
local PartEsp   = IY.import("features/partesp")
local Xray      = IY.import("features/xray")
local HoverName = IY.import("features/hovername")
local StareAt   = IY.import("features/stareat")
local Light     = IY.import("features/light")

local group = Cmd.group{ category = "Visuals" }

-- ── player ESP ──────────────────────────────────────────────────────────────

group{
	name = "esp",
	description = "Draws a box and a name/health/distance label on every player.",
	examples = { "esp", "noesp", "toggleesp" },
	offAliases = { "unespteam" },
	run = function(ctx)
		Esp.start{ team = false }
		if not ctx:quiet() then ctx:reply("ESP enabled") end
	end,
	off = function(ctx)
		Esp.stop()
		if not ctx:quiet() then ctx:reply("ESP disabled") end
	end,
}

group{
	name = "espteam",
	description = "ESP that colours your own team green and everyone else red.",
	examples = { "espteam", "unespteam" },
	run = function(ctx)
		Esp.start{ team = true }
		if not ctx:quiet() then ctx:reply("Team ESP enabled") end
	end,
}

group{
	name = "chams",
	description = "Draws a solid team-coloured box over every player, with no label.",
	examples = { "chams", "nochams" },
	run = function(ctx)
		Chams.start()
		if not ctx:quiet() then ctx:reply("Chams enabled") end
	end,
	off = function(ctx)
		Chams.stop()
		if not ctx:quiet() then ctx:reply("Chams disabled") end
	end,
}

group{
	name = "esptransparency",
	description = "Sets how transparent ESP, chams, locate and part ESP boxes are.",
	args = {
		{ name = "transparency", type = "number", default = 0.3, min = 0, max = 1 },
	},
	examples = { "esptransparency 0.5", "esptransparency" },
	run = function(ctx)
		-- Saving is also what applies it: features/highlight watches the setting
		-- and pushes it onto live adornments, where legacy re-ran `esp` and
		-- `chams` from scratch to pick the new value up (8151).
		local ok, reason = Store.set("espTransparency", ctx.args.transparency)
		if not ok then ctx:fail("%s", tostring(reason)) end
		if not ctx:quiet() then
			ctx:reply("ESP transparency set to " .. tostring(ctx.args.transparency))
		end
	end,
}

group{
	name = "locate",
	description = "Highlights only the players you name.",
	args = {
		-- Required, where legacy defaulted to you and then skipped you, so
		-- `;locate` on its own silently did nothing (8250 + 5893).
		{ name = "players", type = "players" },
	},
	examples = { "locate bob", "locate %raiders", "nolocate bob", "nolocate" },
	-- A set of players has no meaningful toggle, and legacy shipped none.
	toggle = false,
	offArgs = {
		-- `;nolocate` with no argument cleared every highlight (8267).
		{ name = "players", type = "players", default = "all" },
	},
	run = function(ctx)
		local added = Locate.add(ctx:targets("players"))
		if added == 0 then ctx:fail("locate needs somebody other than you") end
		if not ctx:quiet() then
			ctx:reply("Locating " .. tostring(Locate.count()) .. " player(s)")
		end
	end,
	off = function(ctx)
		Locate.remove(ctx:targets("players"))
		if not ctx:quiet() then ctx:reply("Locate cleared") end
	end,
}

-- ── part ESP ────────────────────────────────────────────────────────────────

group{
	name = "partesp",
	description = "Outlines every part in the world with the given name, as they appear.",
	args = {
		{ name = "part", type = "text" },
	},
	examples = { "partesp door", "unpartesp door", "unpartesp" },
	toggle = false,
	offArgs = {
		{ name = "part", type = "text", optional = true },
	},
	run = function(ctx)
		local name, matched, added = PartEsp.add(ctx.args.part)
		if ctx:quiet() then return end
		if added then
			ctx:reply(string.format("Highlighting '%s' (%d in the world now)", name, matched))
		else
			ctx:reply(string.format("'%s' is already highlighted", name))
		end
	end,
	off = function(ctx)
		local part = ctx.args.part
		if part and part ~= "" then
			if not PartEsp.remove(part) then
				ctx:fail("'%s' is not highlighted", tostring(part))
			end
			if not ctx:quiet() then ctx:reply("Stopped highlighting " .. tostring(part)) end
			return
		end
		PartEsp.clear()
		if not ctx:quiet() then ctx:reply("Part ESP cleared") end
	end,
}

-- ── world visuals ───────────────────────────────────────────────────────────

--[[ `xray` and `loopxray` are one feature, so turning either off has to clear
     both toggle flags -- otherwise `;togglexray` and `;toggleloopxray` disagree
     about what is on and the next press does nothing. ]]
local function xrayOff()
	Xray.stop()
	Cmd.setActive("xray", false)
	Cmd.setActive("loopxray", false)
end

group{
	name = "xray",
	description = "Makes the world semi-transparent so you can see through it.",
	examples = { "xray", "unxray", "togglexray" },
	run = function(ctx)
		Xray.start{ loop = false }
		Cmd.setActive("loopxray", false)
		if not ctx:quiet() then ctx:reply("X-ray on") end
	end,
	off = function(ctx)
		xrayOff()
		if not ctx:quiet() then ctx:reply("X-ray off") end
	end,
}

group{
	name = "loopxray",
	description = "X-ray that keeps re-applying, so parts that stream in are covered too.",
	examples = { "loopxray", "unloopxray" },
	run = function(ctx)
		Xray.start{ loop = true }
		Cmd.setActive("xray", true)
		if not ctx:quiet() then ctx:reply("Looping x-ray on") end
	end,
	off = function(ctx)
		xrayOff()
		if not ctx:quiet() then ctx:reply("Looping x-ray off") end
	end,
}

group{
	name = "light",
	description = "Attaches a point light to your character.",
	args = {
		-- Legacy order is `;light <range> <brightness>` (11169), so there is no
		-- players argument here to swallow `;light 50`. features/light takes a
		-- target list for callers that want one.
		{ name = "range",      type = "number", default = 30, min = 0 },
		{ name = "brightness", type = "number", default = 5,  min = 0 },
	},
	examples = { "light", "light 60 10", "unlight" },
	requires = { character = true, root = true },
	offArgs = {},
	run = function(ctx)
		Light.start{
			targets    = { ctx.speaker },
			range      = ctx.args.range,
			brightness = ctx.args.brightness,
		}
		if not ctx:quiet() then ctx:reply("Light on") end
	end,
	off = function(ctx)
		Light.stop()
		if not ctx:quiet() then ctx:reply("Light off") end
	end,
}

-- ── cursor and camera ───────────────────────────────────────────────────────

group{
	name = "hovername",
	description = "Shows the name of whatever character your cursor is over.",
	examples = { "hovername", "unhovername" },
	requires = { desktop = true },
	run = function(ctx)
		HoverName.start()
		if not ctx:quiet() then ctx:reply("Hover names on") end
	end,
	off = function(ctx)
		HoverName.stop()
		if not ctx:quiet() then ctx:reply("Hover names off") end
	end,
}

group{
	name = "stareat",
	aliases = { "stare" },
	description = "Turns you to face a player and keeps you facing them.",
	args = {
		{ name = "players", type = "players" },
	},
	examples = { "stareat bob", "unstare" },
	requires = { character = true, root = true },
	toggle = false,
	offAliases = { "unstare", "nostare" },
	offArgs = {},
	run = function(ctx)
		local targets = ctx:targets("players")
		StareAt.start{ targets = targets }
		if not ctx:quiet() then ctx:reply("Staring at " .. targets[1].name) end
	end,
	off = function(ctx)
		StareAt.stop()
		if not ctx:quiet() then ctx:reply("Stopped staring") end
	end,
}

-- ── tools ───────────────────────────────────────────────────────────────────

group{
	name = "copytools",
	description = "Copies the names of a player's tools to your clipboard.",
	args = {
		{ name = "players", type = "players", optional = true },
	},
	examples = { "copytools", "copytools bob" },
	-- Legacy cloned the tools into your own Backpack (11195), which under
	-- filtering produces a local copy the server never sees and that therefore
	-- does nothing. The useful part of the command is knowing what they carry.
	requires = { capability = "setclipboard" },
	run = function(ctx)
		local names = {}
		ctx:each(function(target)
			local tools = Inst.tools(target:requirePlayer())
			for i = 1, #tools do names[#names + 1] = tools[i].Name end
		end)
		if #names == 0 then ctx:fail("no tools to copy") end
		Env.fn.setclipboard(table.concat(names, "\n"))
		if not ctx:quiet() then
			ctx:reply(string.format("Copied %d tool name(s) to the clipboard", #names))
		end
	end,
}

return true
