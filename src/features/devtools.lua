--[[═══════════════════════════════════════════════════════════════════════════
	features/devtools · the external developer tools
	─────────────────────────────────────────────────────────────────────────
	Replaces source.ref.lua 10554-10608: console, oldconsole, explorer, moondex,
	remotespy, simplespy and audiologger.

	**These commands download and run third-party code, by design.** IY does not
	ship a Dex, a remote spy or an audio logger -- it fetches the community ones.
	The trust boundary is therefore the URL, so the list is a constant in this
	file, nothing can add to it at run time, and the URLs are byte-identical to
	the legacy script's.

	What changed:

	  · one fetch per URL per session, cached, so re-running a tool is instant
	    instead of re-downloading a few hundred kilobytes
	  · every failure names the stage that failed. `oldconsole` pcall'd the
	    download, fed the result to `loadstring` without checking it, and pushed a
	    run-time error to the executor console where the user never saw it; the
	    other five let the error escape as a raw traceback and notified nothing.
	  · `request` is preferred over `game:HttpGet` where the executor has it,
	    because it reports a status code -- a 404 HTML page is not a script.
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Env      = IY.import("core/env")
local Guard    = IY.import("core/guard")
local Log      = IY.import("core/log")
local Notify   = IY.import("core/notify")
local Services = IY.import("core/services")

local log = Log.scope("features/devtools")

local M = {}

--[[ key -> { name, url, after }. `after` is a follow-up notification, which is
     how the legacy oldconsole told you about F9. ]]
local TOOLS = {
	oldconsole = {
		name = "Console",
		url  = "https://raw.githubusercontent.com/infyiff/backup/main/console.lua",
		after = "Press F9 to open the console",
	},
	explorer = {
		name = "Explorer",
		url  = "https://github.com/AZYsGithub/DexPlusPlus/releases/latest/download/out.lua",
	},
	moondex = {
		name = "Moon Dex",
		url  = "https://raw.githubusercontent.com/infyiff/backup/main/dex.lua",
	},
	-- Full credit to notpoiu, creator of Cobalt.
	remotespy = {
		name = "Remote Spy",
		url  = "https://gitlab.com/upio/cobalt/-/releases/permalink/latest/downloads/Cobalt.luau",
	},
	-- Full credit to exx, creator of SimpleSpy; thanks to Amity for fixing it.
	simplespy = {
		name = "Simple Spy",
		url  = "https://raw.githubusercontent.com/infyiff/backup/main/SimpleSpyV3/main.lua",
	},
	audiologger = {
		name = "Audio Logger",
		url  = "https://raw.githubusercontent.com/infyiff/backup/main/audiologger.lua",
	},
}

M.tools = TOOLS

local cache = {}          -- url -> source text

function M.cached(key)
	local tool = TOOLS[key]
	return tool ~= nil and cache[tool.url] ~= nil
end

--[[ Download the source, once per session. Raises a user-facing error naming
     what went wrong instead of handing an empty string to loadstring. ]]
local function fetch(url)
	local hit = cache[url]
	if hit then return hit end

	local body
	if Env.usable("request") then
		local ok, response = Guard.call("devtools.request", Env.fn.request, {
			Url = url, Method = "GET",
		})
		if not ok then
			Guard.fail("the download failed (%s)", Guard.describe(response))
		end
		if type(response) ~= "table" then
			Guard.fail("your executor's request() returned a %s", type(response))
		end
		local status = tonumber(response.StatusCode or response.Status) or 0
		if status >= 400 then
			Guard.fail("the download failed with HTTP %d", status)
		end
		body = response.Body
	else
		local ok, result = Guard.call("devtools.httpget", function()
			return game:HttpGet(url, true)
		end)
		if not ok then
			Guard.fail("the download failed (%s)", Guard.describe(result))
		end
		body = result
	end

	if type(body) ~= "string" or body == "" then
		Guard.fail("the download was empty -- the host may be blocked in this game")
	end
	cache[url] = body
	return body
end

--[[ Not every loadstring implementation accepts a chunk name, so a named
     compile is tried first and an unnamed one second. ]]
local function compile(key, source)
	local load = Env.need("loadstring")
	local chunk, err
	pcall(function() chunk, err = load(source, "=iy/devtools/" .. key) end)
	if type(chunk) ~= "function" then
		pcall(function() chunk, err = load(source) end)
	end
	if type(chunk) ~= "function" then
		Guard.fail("it did not compile: %s", tostring(err or "unknown error"))
	end
	return chunk
end

--[[ Fetch, compile and run one tool. Every stage reports separately. ]]
function M.run(key)
	local tool = TOOLS[key]
	if not tool then Guard.fail("there is no developer tool called '%s'", tostring(key)) end

	Notify.send("Loading", "Hold on a sec")
	local source = fetch(tool.url)
	local chunk = compile(key, source)

	local ok, err = Guard.call("devtools:" .. key, chunk)
	if not ok then
		Guard.fail("%s failed to start: %s", tool.name, Guard.describe(err))
	end

	log.info("loaded %s (%d bytes)", tool.name, #source)
	if tool.after then Notify.send(tool.name, tool.after) end
	return true
end

--[[ Roblox's own developer console (;console). SetCore raises on clients where
     the console is unavailable, which the legacy version called bare. ]]
function M.devConsole(visible)
	local ok, err = Guard.call("devtools.devconsole", function()
		Services.StarterGui:SetCore("DevConsoleVisible", visible ~= false)
	end)
	if not ok then
		Guard.fail("this client will not open the developer console (%s)", Guard.describe(err))
	end
	return true
end

return M
