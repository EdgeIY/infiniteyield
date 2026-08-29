--[[═══════════════════════════════════════════════════════════════════════════
	commands/devtools · console, explorers, remote spies, audio logger
	─────────────────────────────────────────────────────────────────────────
	Legacy equivalent: source.ref.lua 10554-10608.

	Every command here except `;console` downloads a community script and runs
	it, which is what the legacy commands did and what users expect of them --
	see features/devtools for the URL list and why it is a constant. All the
	fetching, caching and error reporting lives there; these are the names.
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Cmd      = IY.import("cmd/api")
local DevTools = IY.import("features/devtools")

local group = Cmd.group{ category = "Developer" }

group{
	name = "console",
	description = "Opens Roblox's own developer console.",
	run = function(ctx)
		DevTools.devConsole(true)
	end,
}

group{
	name = "oldconsole",
	description = "Loads the standalone console script. Press F9 to open it.",
	requires = { capability = "loadstring" },
	run = function(ctx)
		DevTools.run("oldconsole")
	end,
}

group{
	name = "explorer",
	aliases = { "dex" },
	description = "Loads Dex++, an explorer and property editor for this game.",
	requires = { capability = "loadstring" },
	run = function(ctx)
		DevTools.run("explorer")
	end,
}

group{
	name = "moondex",
	aliases = { "mdex" },
	description = "Loads Moon's fork of Dex.",
	requires = { capability = "loadstring" },
	run = function(ctx)
		DevTools.run("moondex")
	end,
}

group{
	name = "remotespy",
	aliases = { "rspy", "cobalt", "cspy" },
	description = "Loads Cobalt, which shows every remote the game fires.",
	requires = { capability = "loadstring" },
	run = function(ctx)
		DevTools.run("remotespy")
	end,
}

group{
	name = "simplespy",
	aliases = { "sspy" },
	description = "Loads SimpleSpy, a lighter remote spy.",
	requires = { capability = "loadstring" },
	run = function(ctx)
		DevTools.run("simplespy")
	end,
}

group{
	name = "audiologger",
	aliases = { "alogger" },
	description = "Loads the audio logger, which lists every sound the game plays.",
	requires = { capability = "loadstring" },
	run = function(ctx)
		DevTools.run("audiologger")
	end,
}

return true
