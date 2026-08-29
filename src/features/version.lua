--[[═══════════════════════════════════════════════════════════════════════════
	features/version · "am I out of date?"
	─────────────────────────────────────────────────────────────────────────
	Replaces source.ref.lua 13300-13320. The legacy check ran inline in a
	task.spawn, wrapped the whole thing in one pcall and threw the reason away,
	so a game that blocks HttpGet looked identical to being up to date.

	Here the result is recorded (`M.outdated`, `M.latest`, `M.error`) and the
	announcement is kept as data. The legacy version built a popup GUI for the
	announcement (13311-13400); that belongs to the interface now, which renders
	`M.announcement`.
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Json   = IY.import("core/json")
local Log    = IY.import("core/log")
local Notify = IY.import("core/notify")
local Sched  = IY.import("core/scheduler")

local M = {}

--[[ Derived from the loader's own base URL, so a build loaded from a branch
     checks that branch's version file rather than the release one. ]]
local FALLBACK_BASE = "https://raw.githubusercontent.com/CarlDV/infiniteyield/master/"
local function versionUrl()
	local base = IY.config and IY.config.base
	if type(base) ~= "string" or base == "" then base = FALLBACK_BASE end
	return base .. "version"
end

M.checked      = false
M.outdated     = false
M.latest       = nil
M.announcement = nil
M.error        = nil

--[[ Check GitHub for the current release. Never blocks the caller: the request
     runs on its own contained thread, so a slow or blocked HttpGet cannot hold
     up boot the way the legacy inline version could. ]]
function M.check(opts)
	opts = opts or {}
	Sched.spawn("version.check", function()
		local ok, body = pcall(function() return game:HttpGet(versionUrl(), true) end)
		if not ok or type(body) ~= "string" then
			M.error = tostring(body)
			Log.debug("version", "could not read the version file: %s", tostring(body))
			return
		end

		local info, parseError = Json.decode(body)
		if type(info) ~= "table" then
			M.error = tostring(parseError or "the version file was not JSON")
			Log.debug("version", "%s", M.error)
			return
		end

		M.checked  = true
		M.latest   = tostring(info.Version or "")
		M.outdated = M.latest ~= "" and M.latest ~= tostring(IY.version)
		if type(info.Announcement) == "string" and info.Announcement ~= "" then
			M.announcement = info.Announcement
		end

		if M.outdated and not opts.quiet then
			Notify.warn("Outdated", "Get the new version at infyiff.github.io")
		end
		if M.announcement and not opts.quiet then
			Notify.send("Announcement", M.announcement)
		end
		Log.info("version", "running %s, latest is %s", tostring(IY.version), tostring(M.latest))
	end)
	return true
end

--[[ One line for `;version` and the diagnostics panel. ]]
function M.describe()
	local parts = { tostring(IY.version) .. " (" .. tostring(IY.channel) .. ")" }
	if M.checked then
		if M.outdated then
			parts[#parts + 1] = "out of date, latest is " .. tostring(M.latest)
		else
			parts[#parts + 1] = "up to date"
		end
	elseif M.error then
		parts[#parts + 1] = "update check failed"
	else
		parts[#parts + 1] = "checking for updates"
	end
	return table.concat(parts, " -- ")
end

function M.snapshot()
	return {
		version      = IY.version,
		channel      = IY.channel,
		checked      = M.checked,
		outdated     = M.outdated,
		latest       = M.latest,
		announcement = M.announcement,
		error        = M.error,
	}
end

return M
