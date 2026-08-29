--[[═══════════════════════════════════════════════════════════════════════════
	entry · the shared bootstrap
	─────────────────────────────────────────────────────────────────────────
	Runs after the module registry is populated (bundle mode) or resolvable
	(remote mode). Both loader.lua and the built `source` execute this exact
	body, so there is one definition of "starting up" for the whole project.

	Responsibilities, in order:
	  1. refuse to run twice
	  2. wait for the DataModel
	  3. expose the public global surface (getgenv().IY)
	  4. attach manifest helpers
	  5. run boot phases
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...

-- ── 1. single instance ──────────────────────────────────────────────────────

local genv = _G
do
	local ok, resolved = pcall(function() return getgenv and getgenv() or nil end)
	if ok and type(resolved) == "table" then genv = resolved end
end

if genv.IY and genv.IY.ready and not genv.IY_DEBUG then
	local existing = genv.IY
	-- Re-running the loader is the most common way users "restart" IY. Rather
	-- than stacking a second copy (which the legacy script only half-prevented
	-- with an IY_LOADED flag it set before it could fail), surface the running
	-- instance and open its command bar.
	pcall(function() existing.focus() end)
	return existing
end

if genv.IY and genv.IY.unload then
	-- A previous instance exists but never finished booting, or debug mode is
	-- on: tear it down first so its connections do not double up.
	pcall(function() genv.IY.unload() end)
end

genv.IY_LOADED = true
genv.IY = IY

-- ── 2. DataModel ────────────────────────────────────────────────────────────

if not game:IsLoaded() then
	game.Loaded:Wait()
end

-- ── 3. manifest helpers ─────────────────────────────────────────────────────

local manifest = IY.manifest or { files = {} }
IY.manifest = manifest

--[[ Every module whose name starts with `prefix`, sorted. Used by boot to pick
     up command packs and UI panels without a hand-maintained list -- dropping a
     file into src/commands/ is all it takes to register it. ]]
function manifest.byPrefix(prefix)
	local out = {}
	local files = manifest.files or {}
	for i = 1, #files do
		local name = files[i]
		if string.sub(name, 1, #prefix) == prefix then out[#out + 1] = name end
	end
	table.sort(out)
	return out
end

function manifest.has(name)
	local files = manifest.files or {}
	for i = 1, #files do
		if files[i] == name then return true end
	end
	return false
end

-- ── 4. public surface ───────────────────────────────────────────────────────

local Signal = IY.import("core/signal")
IY.readySignal = Signal.new("iy.ready")

--[[ The stable API plugins and other scripts use. Everything else is internal.]]
function IY.command(definition)
	return IY.import("cmd/api").register(definition, "external")
end

function IY.exec(line)
	return IY.import("cmd/dispatch").run(line)
end

function IY.notify(title, text, duration)
	return IY.import("core/notify").send(title, text, duration)
end

function IY.focus()
	local ok, UI = pcall(function() return IY.import("ui/init") end)
	if ok and UI and UI.focus then return UI.focus() end
	return false
end

--[[ The runtime's own teardown, captured before we shadow the name: `IY.unload`
     below is the public API, and calling `IY:unload()` from inside it would
     recurse into itself. ]]
local runtimeUnload = IY.unload

function IY.unload()
	local errors = runtimeUnload()
	genv.IY_LOADED = nil
	if genv.IY == IY then genv.IY = nil end
	return errors
end

--[[ `IY.diagnostics` is the runtime's own list of load-time problems, so the
     report accessor is named differently to avoid shadowing it. ]]
function IY.diagnose()
	return IY.import("boot").diagnostics()
end

-- ── 5. boot ─────────────────────────────────────────────────────────────────

local Boot = IY.import("boot")
local report = Boot.start()

return IY
