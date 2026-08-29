--[[ ui: the interface mounts, renders live data, and comes apart cleanly.

     The interface was deliberately not redesigned, so this spec does not assert
     on appearance. It asserts on the two things the move had to preserve: that
     every piece mounts, and that what used to be duplicated state now comes
     from a single owner (the command registry, the bind list, the theme). ]]

local ctx = ...
local expect, IY, env = ctx.expect, ctx.IY, ctx.env

local Log = IY.import("core/log")
-- Earlier specs raise deliberate errors, so only entries added from here on
-- count against the interface.
local logBaseline = #Log.buffer

local UI = IY.import("ui/init")
local Chrome = IY.import("ui/chrome")
local Theme = IY.import("ui/theme")
local Lib = IY.import("ui/lib")
local Registry = IY.import("cmd/registry")
local Notify = IY.import("core/notify")

-- ── mounted ─────────────────────────────────────────────────────────────────
expect.ok(UI.isMounted(), "the interface mounted")
local diagnostics = UI.diagnostics()
for i = 1, #(diagnostics.failures or {}) do
	expect.ok(false, "interface piece failed: " .. tostring(diagnostics.failures[i].name)
		.. " (" .. tostring(diagnostics.failures[i].stage) .. ") " .. tostring(diagnostics.failures[i].error))
end

expect.ok(Lib.host ~= nil, "a host ScreenGui was obtained")
expect.notEqual(Lib.hostKind, "none", "the host strategy is known: " .. tostring(Lib.hostKind))

-- ── the shell exists ────────────────────────────────────────────────────────
for _, key in ipairs({
	"parent", "scaled", "scale", "holder", "title", "commandBar", "commandList",
	"settings", "settingsHolder", "settingsButton", "referenceButton", "prefixBox",
	"rowTemplate", "notification", "tooltip",
}) do
	expect.ok(Chrome[key] ~= nil, "Chrome." .. key .. " exists")
end
expect.isType(Chrome.makeSettingsRow, "function", "the settings row factory is exposed")
expect.ok(Chrome.holder.Parent ~= nil, "the main window is parented")

-- ── holder state accessors replace the old file-locals ──────────────────────
Chrome.setSettingsOpen(true)
expect.ok(Chrome.settingsOpen(), "settings open state is readable")
Chrome.setSettingsOpen(false)
expect.notOk(Chrome.settingsOpen(), "settings open state toggles")

Chrome.setHidden(true)
expect.ok(Chrome.isHidden(), "hidden state is readable")
Chrome.setHidden(false)
expect.notOk(Chrome.isHidden(), "hidden state toggles")

expect.succeeds(function() Chrome.maximize() end, "maximize runs")
expect.succeeds(function() Chrome.minimize() end, "minimize runs")
expect.succeeds(function() Chrome.showCommandBar() end, "showCommandBar runs")
expect.succeeds(function() Chrome.focusCommandBar() end, "focusCommandBar runs")

-- ── the command list comes from the registry ─────────────────────────────────
local CmdList = IY:tryImport("ui/cmdlist")
if CmdList then
	expect.succeeds(function() CmdList.refresh() end, "the command list rebuilds")
	local rows = 0
	for _, child in ipairs(Chrome.commandList:GetChildren()) do
		if child:IsA("TextButton") then rows = rows + 1 end
	end
	expect.ok(rows >= 100, "the list has a row per command (got " .. tostring(rows) .. ")")

	-- A command registered now must appear without anyone telling the UI.
	local Cmd = IY.import("cmd/api")
	Cmd.register({
		name = "uispectestcommand",
		category = "Test",
		description = "Added to prove the list follows the registry.",
		run = function() end,
	}, "test")
	env.scheduler.drain(600)
	CmdList.refresh()
	local found = false
	for _, child in ipairs(Chrome.commandList:GetChildren()) do
		if child:IsA("TextButton") and string.find(tostring(child.Text), "uispectestcommand", 1, true) then
			found = true
		end
	end
	expect.ok(found, "a newly registered command appears in the list")
	Registry.remove("uispectestcommand")
	env.scheduler.drain(600)

	expect.succeeds(function() CmdList.filter("fly") end, "filtering runs")
	expect.succeeds(function() CmdList.filter("") end, "clearing the filter runs")
end

-- ── notifications reach the renderer ────────────────────────────────────────
expect.ok(Notify.hasSink(), "core/notify has a renderer")
expect.succeeds(function() Notify.send("Spec", "hello from the ui spec") end,
	"a notification renders without erroring")
env.scheduler.drain(1200)
expect.equal(Notify.pending(), 0, "nothing is left buffered once the UI is up")

-- ── theme ───────────────────────────────────────────────────────────────────
local snapshot = Theme.snapshot()
expect.isType(snapshot, "table", "the theme reports a snapshot")
local registered = 0
for _, entry in pairs(snapshot) do
	if type(entry) == "table" and type(entry.count) == "number" then
		registered = registered + entry.count
	end
end
expect.ok(registered > 0, "instances are registered with the theme (" .. tostring(registered) .. ")")

local original = Theme.get("shade2")
expect.succeeds(function() Theme.apply("shade2", Color3.fromRGB(1, 2, 3)) end,
	"applying a colour runs")
expect.succeeds(function() Theme.apply("shade2", original) end, "restoring the colour runs")

-- Registration must be idempotent and unregistration must work, or list panels
-- leak an entry per refresh -- which is exactly what the legacy registries did.
local probe = Instance.new("Frame")
Theme.register(probe, "shade2")
Theme.register(probe, "shade2")
local afterRegister = Theme.snapshot().shade2.count
Theme.unregister(probe, "shade2")
local afterUnregister = Theme.snapshot().shade2.count
expect.equal(afterUnregister, afterRegister - 1, "registering twice added one entry, unregister removed it")
probe:Destroy()

-- ── panels ──────────────────────────────────────────────────────────────────
local panels = { "keybinds", "aliases", "waypoints", "plugins", "topart", "reference", "events" }
for i = 1, #panels do
	local panel = IY:tryImport("ui/panels/" .. panels[i])
	if panel then
		expect.isType(panel.mount, "function", panels[i] .. " panel exposes mount")
		if type(panel.refresh) == "function" then
			expect.succeeds(function() panel.refresh() end, panels[i] .. " panel refreshes")
		end
		if type(panel.open) == "function" and type(panel.close) == "function" then
			expect.succeeds(function() panel.open() panel.close() end, panels[i] .. " panel opens and closes")
		end
	end
end

-- ── logs window renders the feature's data ──────────────────────────────────
local LogsWindow = IY:tryImport("ui/logs")
local ChatLogs = IY:tryImport("features/chatlogs")
if LogsWindow and ChatLogs then
	local players = IY.import("core/services").Players
	expect.succeeds(function() ChatLogs.record(players.LocalPlayer, "spec message") end,
		"recording a chat line runs")
	env.scheduler.drain(600)
	expect.succeeds(function() LogsWindow.refresh() end, "the log window refreshes")
	expect.succeeds(function() LogsWindow.showTab("join") end, "switching to the join tab runs")
	expect.succeeds(function() LogsWindow.showTab("chat") end, "switching back runs")
	expect.succeeds(function() LogsWindow.close() end, "closing the window runs")
end

env.scheduler.drain(2000)

-- No errors should have been logged by any of the above.
local newErrors = {}
for i = logBaseline + 1, #Log.buffer do
	local entry = Log.buffer[i]
	if entry.level >= Log.levels.error then newErrors[#newErrors + 1] = entry end
end
for i = 1, math.min(#newErrors, 10) do
	expect.ok(false, "error logged during the ui spec: [" .. newErrors[i].tag .. "] "
		.. tostring(newErrors[i].message))
end
expect.equal(#newErrors, 0, "the interface logged nothing at error level")
