--[[═══════════════════════════════════════════════════════════════════════════
	tests/loader_test · the remote loader path
	─────────────────────────────────────────────────────────────────────────
	    luajit tests/loader_test.lua

	`loader.lua` fetches the manifest and then every module individually, rather
	than running a bundle. That is a genuinely different code path from `source`
	-- different resolution, different failure modes -- so it gets its own test:
	we boot it inside the same Roblox stub with `game:HttpGet` wired to the local
	filesystem, and assert it comes up with the same command set.
═══════════════════════════════════════════════════════════════════════════]]

local ROOT = "."

local function readFile(path)
	local handle = io.open(path, "r")
	if not handle then return nil end
	local contents = handle:read("*a")
	handle:close()
	return contents
end

local Stub = dofile(ROOT .. "/tests/stub/init.lua")

local fetched, missed = 0, {}

--[[ Serve raw.githubusercontent-style URLs out of the working tree. ]]
local function serve(url)
	-- Only our own repository paths matter here; the interface also downloads
	-- image assets from a separate repo, which a sandbox cannot reach and which
	-- ui/assets already falls back from.
	local path = string.match(url, "/[%w%-%.]+/infiniteyield/[^/]+/(.+)$")
	if not path then return "" end
	-- Matched before the file read so `src/features/version.lua` is served as
	-- Lua and the bare `version` manifest as JSON.
	if path == "version" then
		return '{"Version":"7.0.0","Announcement":""}'
	end
	local contents = readFile(ROOT .. "/" .. path)
	if not contents then
		missed[#missed + 1] = path
		return ""
	end
	fetched = fetched + 1
	return contents
end

local env = Stub.new({
	playerName = "LoaderTest",
	playerCount = 2,
	executor = "IYLoaderHarness",
	http = serve,
})

local loader = readFile(ROOT .. "/loader.lua")
if not loader then
	io.write("FAIL loader.lua missing\n")
	os.exit(1)
end

local chunk, err = loadstring(loader, "@loader.lua")
if not chunk then
	io.write("FAIL loader.lua does not compile: " .. tostring(err) .. "\n")
	os.exit(1)
end
setfenv(chunk, env.globals)

local ok, result = pcall(chunk)
if not ok then
	io.write("FAIL the loader raised: " .. tostring(result) .. "\n")
	os.exit(1)
end

env.scheduler.drain(20000)
env.scheduler.advance(3)
env.scheduler.drain(20000)

local IY = env.globals.IY
local failures = {}

local function check(condition, message)
	if not condition then failures[#failures + 1] = message end
end

check(IY ~= nil, "the loader did not expose a runtime")
if IY then
	check(IY.ready == true, "the loader did not finish booting")
	check(IY.channel == "remote", "channel should be 'remote', got " .. tostring(IY.channel))
	check(#(IY.loadOrder or {}) >= 20,
		"only " .. tostring(#(IY.loadOrder or {})) .. " modules loaded")

	local Registry = IY.import("cmd/registry")
	check(Registry.count() >= 400,
		"only " .. tostring(Registry.count()) .. " commands registered")
	check(Registry.find("fly") ~= nil, "fly is missing")
	check(Registry.find("unfly") ~= nil, "generated off command is missing")

	local report = IY.bootReport or {}
	check(report.fatal == nil, "fatal boot phase: " .. tostring(report.fatal))
	local Guard = IY.import("core/guard")
	for i = 1, #(report.failed or {}) do
		failures[#failures + 1] = "boot phase failed: " .. tostring(report.failed[i].phase)
			.. " -- " .. Guard.describe(report.failed[i].error)
	end

	-- Every module must have come over HTTP, not from a bundle.
	check(fetched >= 20, "only " .. tostring(fetched) .. " files were fetched")
end

for i = 1, #missed do
	failures[#failures + 1] = "could not serve " .. tostring(missed[i])
end

local schedulerErrors = env.scheduler.errors or {}
for i = 1, math.min(#schedulerErrors, 10) do
	failures[#failures + 1] = "background error: " .. tostring(schedulerErrors[i].message)
end

if #failures > 0 then
	io.write(string.format("FAIL  remote loader: %d problem(s)\n", #failures))
	for i = 1, #failures do io.write("  " .. failures[i] .. "\n") end
	os.exit(1)
end

io.write(string.format("PASS  remote loader booted %d modules from %d fetched files, %d commands\n",
	#IY.loadOrder, fetched, IY.import("cmd/registry").count()))
os.exit(0)
