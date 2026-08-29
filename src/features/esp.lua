--[[═══════════════════════════════════════════════════════════════════════════
	features/esp · boxes and a nameplate on every player
	─────────────────────────────────────────────────────────────────────────
	Legacy source.ref.lua 5728-5822 (the renderer) and 8116-8149 (esp, espteam,
	noesp). Every connection, folder and loop is now features/highlight's
	problem; what is left here is the adornment set, unchanged: a
	BoxHandleAdornment per body part plus a billboard showing name, health and
	distance, refreshed each frame.

	`team = true` is the old `espteam` -- your own team green, everyone else red.
	Running this alongside chams is fine now; see features/highlight.
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Highlight = IY.import("features/highlight")

local M = {}

local session = Highlight.create("esp", {
	command  = "esp",
	describe = "player ESP",
	suffix   = "ESP",

	build = function(bin, target, folder, opts)
		Highlight.boxes(bin, folder, target,
			Highlight.playerColour(target.player, opts.team == true))
		return { label = Highlight.nameplate(bin, folder, target) }
	end,

	update = Highlight.refreshNameplate,
})

M.session = session

function M.start(opts) return session:start(opts or {}) end
function M.stop() return session:stop() end
function M.toggle(opts) return session:toggle(opts or {}) end
function M.isRunning() return session:isRunning() end
function M.isTeamMode() return session:option("team", false) == true end
function M.count() return session:count() end

return M
