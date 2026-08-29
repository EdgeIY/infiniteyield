--[[═══════════════════════════════════════════════════════════════════════════
	features/chams · a solid team-coloured box over every player
	─────────────────────────────────────────────────────────────────────────
	Legacy source.ref.lua 5824-5883 and 8225-8248. Chams is ESP without the
	label, so it is the same `build` minus the nameplate -- and with no `update`
	it costs no render loop at all, where the legacy version still carried three
	connections per player to work out when to clean itself up.

	Legacy refused to start chams while ESP was on and vice versa (8117, 8226)
	because both wrote CoreGui folders named `<player>_ESP` / `<player>_CHMS`
	and cleaned up by name. Adornments are owned by a per-player bin now, so the
	two are independent and that restriction is gone.
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Highlight = IY.import("features/highlight")

local M = {}

local session = Highlight.create("chams", {
	command  = "chams",
	describe = "player chams",
	suffix   = "CHMS",

	build = function(bin, target, folder)
		Highlight.boxes(bin, folder, target, Highlight.playerColour(target.player, false))
	end,
})

M.session = session

function M.start(opts) return session:start(opts or {}) end
function M.stop() return session:stop() end
function M.toggle(opts) return session:toggle(opts or {}) end
function M.isRunning() return session:isRunning() end
function M.count() return session:count() end

return M
