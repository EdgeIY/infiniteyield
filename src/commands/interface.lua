--[[═══════════════════════════════════════════════════════════════════════════
	commands/interface · core GUI, other people's GUIs, and IY's own window
	─────────────────────────────────────────────────────────────────────────
	enable, disable, showguis, hideguis, guidelete, hideiy, guiscale, rec,
	screenshot, togglefs, inspect, savegame and clearerror -- plus the
	`un`/`no`/`toggle` siblings the registry derives from their `off` handlers,
	which is where `unshowguis`, `unhideguis`, `unguidelete` and `showiy` come
	from.

	Legacy equivalent: source.ref.lua 7770-7926 (twelve `addcmd` blocks plus the
	`coreGuiTypeNames` lookup table, the two visibility arrays and the
	`deleteGuiInput` global) and 12805-12822 (guiscale).

	Nothing in this file touches a GUI instance. Window state belongs to
	ui/chrome, the visibility sweeps and the delete listener to features/guis, and
	the scale is a settings key the interface watches -- so `;guiscale` works
	before the interface has mounted, and `;hideiy` says so instead of erroring
	when it never mounted at all.
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Cmd      = IY.import("cmd/api")
local Env      = IY.import("core/env")
local Guard    = IY.import("core/guard")
local Services = IY.import("core/services")
local Store    = IY.import("core/store")
local Str      = IY.import("core/util/strings")
local Guis     = IY.import("features/guis")

local group = Cmd.group{ category = "Interface" }

--[[ `rec`, `screenshot`, `togglefs` and `clearerror` are each one engine call
     that is missing, restricted or permission-gated somewhere:
     CoreGui:ToggleRecording and TakeScreenshot need an elevated identity,
     GuiService:ToggleFullscreen does nothing when a window manager owns the
     window, and ClearError is not implemented on every client. Legacy called
     all four bare, so a client that refused produced a traceback in the console
     and no message at all for the user. ]]
local function engineCall(what, fn)
	local ok, err = Guard.call("interface." .. what, fn)
	if not ok then
		Guard.fail("your client would not %s (%s)", what, Guard.describe(err))
	end
	return true
end

-- ── core GUI ────────────────────────────────────────────────────────────────

--[[ The legacy pair built a lowercase name -> EnumItem table by hand (7770-7773)
     and silently did nothing when the name was not in it. The `enumitem` type
     validates and autocompletes against the live enum instead, so `;enable all`
     still works (All is a CoreGuiType) and `;enable playerlst` says what is
     wrong. ]]
local coreGuiArg = {
	name = "element", type = "enumitem",
	enum = Enum.CoreGuiType, enumName = "CoreGuiType",
}

local function setCoreGui(element, enabled)
	local ok, err = Guard.call("interface.coregui", function()
		Services.StarterGui:SetCoreGuiEnabled(element, enabled)
	end)
	if not ok then
		Guard.fail("this client refused to change %s (%s)",
			tostring(element.Name), Guard.describe(err))
	end
end

group{
	name = "enable",
	description = "Turns one of Roblox's own GUIs back on.",
	args = { coreGuiArg },
	examples = { "enable all", "enable playerlist", "enable backpack" },
	run = function(ctx)
		setCoreGui(ctx.args.element, true)
		if not ctx:quiet() then ctx:reply("Enabled " .. ctx.args.element.Name) end
	end,
}

group{
	name = "disable",
	description = "Turns off one of Roblox's own GUIs.",
	args = { coreGuiArg },
	examples = { "disable all", "disable chat", "disable health" },
	run = function(ctx)
		setCoreGui(ctx.args.element, false)
		if not ctx:quiet() then ctx:reply("Disabled " .. ctx.args.element.Name) end
	end,
}

-- ── the game's own GUIs ─────────────────────────────────────────────────────

group{
	name = "showguis",
	description = "Makes every hidden GUI in your PlayerGui visible.",
	examples = { "showguis", "unshowguis" },
	offDescription = "Puts back the GUIs showguis revealed.",
	run = function(ctx)
		local count = Guis.show()
		if not ctx:quiet() then
			ctx:notify("Show GUIs", "Revealed " .. Str.pluralise(count, "GUI"))
		end
	end,
	off = function(ctx)
		Guis.unshow()
		if not ctx:quiet() then ctx:notify("Show GUIs", "Put the hidden GUIs back") end
	end,
}

group{
	name = "hideguis",
	description = "Hides every visible GUI in your PlayerGui.",
	examples = { "hideguis", "unhideguis" },
	offDescription = "Puts back the GUIs hideguis hid.",
	run = function(ctx)
		local count = Guis.hide()
		if not ctx:quiet() then
			ctx:notify("Hide GUIs", "Hid " .. Str.pluralise(count, "GUI"))
		end
	end,
	off = function(ctx)
		Guis.unhide()
		if not ctx:quiet() then ctx:notify("Hide GUIs", "Put the visible GUIs back") end
	end,
}

group{
	name = "guidelete",
	description = "Hover over a GUI and press backspace to delete it.",
	examples = { "guidelete", "unguidelete" },
	requires = { desktop = true },
	offDescription = "Stops backspace deleting the GUI under your cursor.",
	run = function(ctx)
		Guis.startDelete()
		ctx:notify("GUI Delete Enabled", "Hover over a GUI and press backspace to delete it")
	end,
	off = function(ctx)
		Guis.stopDelete()
		ctx:notify("GUI Delete Disabled", "GUI backspace delete has been disabled")
	end,
}

-- ── IY's own window ─────────────────────────────────────────────────────────

--[[ The window is the interface's business, and the interface is an optional
     boot phase: `;hideiy` has to work out whether there is anything to hide
     rather than reach for a frame that may not exist. ]]
local function chrome()
	local Chrome = IY:tryImport("ui/chrome")
	if not Chrome or not Chrome.mounted then
		Guard.fail("the interface is not loaded, so there is nothing to hide or show")
	end
	return Chrome
end

group{
	name = "hideiy",
	description = "Hides the Infinite Yield window.",
	examples = { "hideiy", "showiy" },
	offAliases = { "showiy" },
	offDescription = "Shows the Infinite Yield window again.",
	run = function(ctx)
		chrome().setHidden(true)
		if not ctx:quiet() then
			ctx:notify("IY Hidden", "You can press the prefix key to access the command bar")
		end
	end,
	off = function(ctx)
		chrome().setHidden(false)
	end,
}

--[[ Legacy wrote the UIScale directly and clamped 0.4-2 by hand, after dividing
     any whole number by 100 and then special-casing 1 and 2 back because 0.01
     and 0.02 "exploded" (12805-12822). The scale is a settings key the interface
     watches now, so this command only writes the setting -- and the bounds are
     the schema's, which is also what tells the user why 5 was refused.

     Percentages still work: anything above the schema maximum is read as one, so
     `;guiscale 150` and `;guiscale 1.5` are the same request and the two magic
     constants are gone. ]]
local guiScaleMax = (Store.schema.guiScale and Store.schema.guiScale.max) or 3

group{
	name = "guiscale",
	description = "Sets how large the Infinite Yield window is.",
	args = { { name = "scale", type = "number", optional = true } },
	examples = { "guiscale 1.5", "guiscale 150", "guiscale" },
	run = function(ctx)
		local scale = ctx.args.scale
		if not scale then
			Store.reset("guiScale")
			if not ctx:quiet() then ctx:reply("GUI scale reset to default") end
			return
		end
		if scale > guiScaleMax then scale = scale / 100 end
		local ok, reason = Store.set("guiScale", scale)
		if not ok then ctx:fail("scale %s", tostring(reason)) end
		if not ctx:quiet() then ctx:reply("GUI scale set to " .. tostring(scale)) end
	end,
}

-- ── client features ─────────────────────────────────────────────────────────

group{
	name = "rec",
	aliases = { "record" },
	description = "Starts or stops Roblox's screen recorder.",
	requires = { desktop = true },
	run = function(ctx)
		engineCall("toggle recording", function()
			Services.CoreGui:ToggleRecording()
		end)
	end,
}

group{
	name = "screenshot",
	aliases = { "scrnshot" },
	description = "Takes a Roblox screenshot.",
	requires = { desktop = true },
	run = function(ctx)
		engineCall("take a screenshot", function()
			Services.CoreGui:TakeScreenshot()
		end)
	end,
}

group{
	name = "togglefs",
	aliases = { "togglefullscreen" },
	description = "Switches Roblox between fullscreen and windowed.",
	requires = { desktop = true },
	run = function(ctx)
		engineCall("toggle fullscreen", function()
			Services.GuiService:ToggleFullscreen()
		end)
	end,
}

group{
	name = "clearerror",
	aliases = { "clearerrors" },
	description = "Dismisses Roblox's error dialog.",
	run = function(ctx)
		engineCall("clear the error dialog", function()
			Services.GuiService:ClearError()
		end)
	end,
}

group{
	name = "inspect",
	aliases = { "examine" },
	description = "Opens Roblox's avatar inspect menu on a player.",
	args = { { name = "players", type = "players" } },
	examples = { "inspect bob", "examine random" },
	run = function(ctx)
		local GuiService = Services.GuiService
		-- One inspect menu can be open at a time, so with several targets the last
		-- one wins -- exactly as the legacy loop behaved (7907-7912). ctx:each is
		-- what stops a target who has just left aborting the rest.
		ctx:each(function(target)
			local player = target:requirePlayer()
			GuiService:CloseInspectMenu()
			GuiService:InspectPlayerFromUserId(player.UserId)
		end)
	end,
}

--[[ saveinstance is a whole-file dumper rather than one of core/env's known
     primitives, so it is probed by name. Legacy notified "Game Saved" whether or
     not the dump worked, because it called saveinstance() unguarded. ]]
group{
	name = "savegame",
	aliases = { "saveplace" },
	description = "Saves a copy of this place into your executor's workspace folder.",
	requires = {
		check = function()
			if Env.lookup("saveinstance") then return true end
			return false, "your executor does not support this command (missing saveinstance)"
		end,
	},
	run = function(ctx)
		local saveinstance = Env.lookup("saveinstance")
		ctx:notify("Loading", "Downloading game. This will take a while")
		local ok, err = Guard.call("interface.savegame", saveinstance)
		if not ok then
			ctx:fail("saving the place failed: %s", Guard.describe(err))
		end
		ctx:notify("Game Saved",
			"Saved place to the workspace folder within your exploit folder.")
	end,
}

return true
