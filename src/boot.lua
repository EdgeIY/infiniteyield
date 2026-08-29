--[[═══════════════════════════════════════════════════════════════════════════
	boot · startup orchestration
	─────────────────────────────────────────────────────────────────────────
	Ordered phases, each contained. The rule that shapes this file: **a failure
	in one phase must not take the others down**. The legacy script was a single
	13,000-line chunk, so a single error anywhere -- a hooked HttpService, a
	missing PlayerModule, one bad plugin -- aborted everything after it, usually
	before the command set had even registered.

	Here the command set loads before the interface, the interface loads pack by
	pack, plugins are individually contained, and if the UI cannot mount at all
	the command bar still works through chat. `;iydiag` reports what failed.
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...

local M = {}

local phases = {}

local function phase(name, required, fn)
	phases[#phases + 1] = { name = name, required = required, fn = fn }
end

-- ═══ phases ═════════════════════════════════════════════════════════════════

phase("environment", true, function(report)
	local Env      = IY.import("core/env")
	local Log      = IY.import("core/log")
	local Platform = IY.import("core/platform")
	IY.import("core/services")
	IY.import("core/notify")

	Log.setDebug(IY.config.debug == true)
	report.executor = Env.executor
	report.platform = Platform.platform
	return true
end)

phase("settings", false, function(report)
	local Store = IY.import("core/store")
	Store.load()
	report.persistent = Store.persistent
	if not Store.persistent then
		IY.import("core/notify").warn("Settings",
			"Your executor cannot write files, so settings, waypoints, keybinds and aliases will not be saved.")
	end
	return true
end)

phase("lifecycle", true, function()
	IY.import("core/character")
	IY.import("core/snapshot")
	IY.import("core/hooks")
	return true
end)

phase("commands", true, function(report)
	IY.import("cmd/api")
	local Registry = IY.import("cmd/registry")

	local packs = IY.manifest and IY.manifest.byPrefix("commands/") or {}
	local loaded, failures = IY:importAll(packs)
	report.packs = loaded
	report.packFailures = failures
	report.commands = Registry.count()

	if report.commands == 0 then
		error("no commands registered -- every command pack failed to load", 0)
	end
	return true
end)

phase("bindings", false, function()
	IY.import("cmd/aliases").load()
	IY.import("cmd/binds").load()
	return true
end)

phase("interface", false, function(report)
	local UI = IY.import("ui/init")
	UI.mount()
	report.ui = true
	return true
end)

phase("input", false, function()
	IY.import("cmd/input").attach()
	return true
end)

phase("plugins", false, function(report)
	local Plugins = IY.import("features/plugins")
	report.plugins = Plugins.loadSaved()
	return true
end)

phase("version", false, function()
	IY.import("features/version").check()
	return true
end)

-- ═══ runner ═════════════════════════════════════════════════════════════════

--[[ Run the phases. Returns a report table describing what happened, which is
     what ;iydiag prints and what the test suite asserts on. ]]
function M.start()
	local Log = IY.import("core/log")
	local Guard = IY.import("core/guard")

	local report = {
		version = IY.version,
		started = os.clock and os.clock() or 0,
		failed  = {},
		skipped = {},
	}

	for i = 1, #phases do
		local entry = phases[i]
		local ok, err = Guard.call("boot:" .. entry.name, entry.fn, report)
		if not ok then
			report.failed[#report.failed + 1] = { phase = entry.name, error = err }
			Log.error("boot", "phase '%s' failed: %s", entry.name, Guard.describe(err))
			if entry.required then
				report.fatal = entry.name
				break
			end
		end
	end

	report.elapsed = (os.clock and os.clock() or 0) - report.started
	report.modules = #IY.loadOrder
	-- Named bootReport so it cannot shadow the runtime's report() method.
	IY.bootReport = report

	if report.fatal then
		local Notify = IY.import("core/notify")
		Notify.error("Infinite Yield", "Failed to start: " .. tostring(report.fatal)
			.. " -- see the console for details.")
		return report
	end

	M.announce(report)
	return report
end

--[[ The "we are up" message. Deliberately quiet about internals unless
     something went wrong. ]]
function M.announce(report)
	local Notify = IY.import("core/notify")
	local Store = IY.import("core/store")
	local prefix = Store.get("prefix") or ";"

	local problems = #report.failed
	if problems > 0 then
		local names = {}
		for i = 1, #report.failed do names[#names + 1] = report.failed[i].phase end
		Notify.warn("Infinite Yield",
			"Loaded with " .. tostring(problems) .. " problem(s): " .. table.concat(names, ", ")
			.. "\nRun " .. prefix .. "iydiag for details.")
	end

	IY.ready = true
	if IY.readySignal then IY.readySignal:Fire(report) end
end

--[[ Everything ;iydiag prints. ]]
function M.diagnostics()
	local Env      = IY.import("core/env")
	local Platform = IY.import("core/platform")
	local Registry = IY.import("cmd/registry")
	local Feature  = IY.import("features/feature")
	local Sched    = IY.import("core/scheduler")
	local Store    = IY.import("core/store")
	local Snapshot = IY.import("core/snapshot")
	local Hooks    = IY.import("core/hooks")

	return {
		version     = IY.version,
		channel     = IY.channel,
		boot        = IY.bootReport,
		runtime     = IY:report(),
		executor    = Env.snapshot(),
		platform    = Platform.snapshot(),
		commands    = Registry.count(),
		audit       = Registry.audit(),
		features    = Feature.snapshot(),
		loops       = Sched.snapshot(),
		persistent  = Store.persistent,
		snapshots   = Snapshot.snapshot(),
		hooks       = Hooks.snapshot(),
		diagnostics = IY.diagnostics,
	}
end

return M
