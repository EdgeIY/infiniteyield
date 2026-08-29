--[[═══════════════════════════════════════════════════════════════════════════
	tests/run · the test runner
	─────────────────────────────────────────────────────────────────────────
	Boots the *built bundle* inside the headless Roblox stub and runs every spec
	against it, so the suite exercises the exact artifact users load rather than
	a hand-assembled subset of modules.

	    luajit tests/run.lua                 every spec
	    luajit tests/run.lua registry parser only those
	    luajit tests/run.lua --list          show the spec names

	Exit code is non-zero when any assertion fails, so CI can gate on it.
═══════════════════════════════════════════════════════════════════════════]]

local ROOT = "."

local SPECS = {
	"boot",
	"core",
	"parser",
	"types",
	"registry",
	"coverage",
	"players",
	"store",
	"dispatch",
	"features",
	"ui",
	"smoke",
	"unload",
}

local expect = dofile(ROOT .. "/tests/support/expect.lua")

local function readFile(path)
	local handle = io.open(path, "r")
	if not handle then return nil end
	local contents = handle:read("*a")
	handle:close()
	return contents
end

local function selected(args)
	local wanted = {}
	for i = 1, #args do
		if string.sub(args[i], 1, 2) ~= "--" then wanted[args[i]] = true end
	end
	if next(wanted) == nil then return SPECS end
	local out = {}
	for i = 1, #SPECS do
		if wanted[SPECS[i]] then out[#out + 1] = SPECS[i] end
	end
	return out
end

-- ── boot the bundle in the stub ──────────────────────────────────────────────

local function boot()
	local Stub = dofile(ROOT .. "/tests/stub/init.lua")
	local env = Stub.new({
		playerName  = "TestPlayer",
		playerCount = 4,
		executor    = "IYTestHarness",
		http = function(url)
			if string.find(url, "version", 1, true) then
				return '{"Version":"7.0.0","Announcement":""}'
			end
			return ""
		end,
	})

	local source = readFile(ROOT .. "/source")
	if not source then
		error("source bundle missing -- run python3 tools/build.py first")
	end

	local chunk, err = loadstring(source, "@source")
	if not chunk then error("bundle does not compile: " .. tostring(err)) end
	setfenv(chunk, env.globals)

	local ok, result = pcall(chunk)
	if not ok then
		return env, nil, result
	end

	-- Startup work happens on scheduler threads; let them finish.
	env.scheduler.drain(20000)
	env.scheduler.advance(3)
	env.scheduler.drain(20000)

	return env, env.globals.IY or result, nil
end

-- ── run ─────────────────────────────────────────────────────────────────────

local args = { ... }
for i = 1, #args do
	if args[i] == "--list" then
		for j = 1, #SPECS do print(SPECS[j]) end
		os.exit(0)
	end
end

io.write("booting bundle in stub environment...\n")
local env, IY, bootError = boot()

if bootError then
	io.write("FATAL: the bundle raised while loading:\n  " .. tostring(bootError) .. "\n")
	os.exit(1)
end
if not IY then
	io.write("FATAL: the bundle did not expose a runtime (getgenv().IY is nil)\n")
	os.exit(1)
end

io.write(string.format("booted: %d modules, %s\n",
	#(IY.loadOrder or {}), tostring(IY.version)))

local specs = selected(args)
local totalAssertions, allFailures = 0, {}

for i = 1, #specs do
	local name = specs[i]
	local path = ROOT .. "/tests/spec/" .. name .. ".lua"
	local chunk = loadfile(path)
	if not chunk then
		io.write(string.format("  %-10s SKIP (no %s)\n", name, path))
	else
		-- Specs need the stub's Roblox globals (Enum, typeof, workspace, Color3)
		-- as well as the host's standard library.
		setfenv(chunk, setmetatable({}, {
			__index = function(_, key)
				local value = env.globals[key]
				if value ~= nil then return value end
				return _G[key]
			end,
		}))
		expect.reset()
		expect.setContext(name)
		local ok, err = pcall(chunk, { env = env, IY = IY, expect = expect, root = ROOT })
		local failures = expect.failures
		if not ok then
			failures[#failures + 1] = { context = name, message = "spec crashed: " .. tostring(err) }
		end
		totalAssertions = totalAssertions + expect.assertions
		io.write(string.format("  %-10s %4d assertions, %d failed\n",
			name, expect.assertions, #failures))
		for f = 1, #failures do
			allFailures[#allFailures + 1] = failures[f]
		end
	end
end

io.write("\n")
if #allFailures > 0 then
	io.write(string.format("FAIL  %d of %d assertions failed\n", #allFailures, totalAssertions))
	for i = 1, math.min(#allFailures, 60) do
		io.write("  [" .. allFailures[i].context .. "] " .. allFailures[i].message .. "\n")
	end
	if #allFailures > 60 then
		io.write("  ... and " .. tostring(#allFailures - 60) .. " more\n")
	end
	os.exit(1)
end

io.write(string.format("PASS  %d assertions across %d specs\n", totalAssertions, #specs))
os.exit(0)
