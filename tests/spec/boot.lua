--[[ boot: the bundle came up, and nothing exploded on the way. ]]

local ctx = ...
local expect, IY, env = ctx.expect, ctx.IY, ctx.env

expect.ok(IY.ready, "IY reported ready")
expect.isType(IY.bootReport, "table", "boot produced a report")

local report = IY.bootReport or {}
expect.equal(report.fatal, nil, "no fatal boot phase")
expect.ok((report.modules or 0) >= 20, "at least 20 modules loaded")
expect.ok((report.commands or 0) >= 100, "at least 100 commands registered")

-- Any phase that failed is worth naming in the output rather than just counting.
for i = 1, #(report.failed or {}) do
	expect.ok(false, "boot phase failed: " .. tostring(report.failed[i].phase)
		.. " -- " .. tostring(report.failed[i].error))
end

-- Module-level diagnostics (name collisions, optional modules that failed).
for i = 1, #(IY.diagnostics or {}) do
	local entry = IY.diagnostics[i]
	expect.ok(false, "runtime diagnostic: " .. tostring(entry.kind) .. ": " .. tostring(entry.message))
end

-- Errors raised on scheduler threads during boot would be invisible in Roblox.
local schedulerErrors = env.scheduler.errors or {}
for i = 1, math.min(#schedulerErrors, 12) do
	expect.ok(false, "error on a background thread: " .. tostring(schedulerErrors[i].message))
end

expect.isType(IY.import, "function", "runtime exposes import")
expect.isType(IY.command, "function", "public command API exposed")
expect.isType(IY.exec, "function", "public exec API exposed")
expect.isType(IY.unload, "function", "public unload API exposed")

local Log = IY.import("core/log")
expect.equal(Log.counts.error, 0, "nothing logged at error level during boot")

local Env = IY.import("core/env")
expect.equal(Env.executor, "IYTestHarness", "executor identified")

local Platform = IY.import("core/platform")
expect.notOk(Platform.isMobile, "stub reports a desktop client")
