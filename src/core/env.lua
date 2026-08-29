--[[═══════════════════════════════════════════════════════════════════════════
	core/env · executor capability layer
	─────────────────────────────────────────────────────────────────────────
	The legacy script normalised exploit functions with a `missing()` helper
	that returned `nil` when a capability was absent, then called the result
	unguarded -- which is where a large share of "IY is broken on my executor"
	reports came from.

	Here every capability is looked up once, recorded, and exposed three ways:

	    Env.fn.hookfunction        -- the function, or nil
	    Env.has("hookfunction")    -- boolean
	    Env.need("hookfunction")   -- the function, or raises a clean error
	                                  that the dispatcher turns into a
	                                  "your executor cannot do this" notice

	Commands declare `requires = { capability = "hookfunction" }` and are
	blocked with an explanatory message instead of erroring mid-run.
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...

local M = {}

M.fn   = {}
M.caps = {}

-- Where injected globals can live, in priority order.
local scopes = {}
do
	local function push(t) if type(t) == "table" then scopes[#scopes + 1] = t end end
	local ok, fenv = pcall(function() return getfenv and getfenv(1) or nil end)
	if ok then push(fenv) end
	local ok2, genv = pcall(function() return getgenv and getgenv() or nil end)
	if ok2 then push(genv) end
	push(_G)
	local ok3, sh = pcall(function() return shared end)
	if ok3 then push(sh) end
end

--[[ Read a global by name from any environment table the executor might use. ]]
local function lookup(name)
	for i = 1, #scopes do
		local ok, value = pcall(function() return scopes[i][name] end)
		if ok and value ~= nil then return value end
	end
	return nil
end
M.lookup = lookup

--[[ First global from `names` that is a function. Returns exactly one value so
     it is safe to use as a trailing argument. ]]
local function pick(...)
	local names = { ... }
	for i = 1, #names do
		local value = lookup(names[i])
		if type(value) == "function" then return value end
	end
	return nil
end

--[[ Resolve `nested.field` style helpers such as syn.request. ]]
local function pickNested(pairsList)
	for i = 1, #pairsList do
		local holder = lookup(pairsList[i][1])
		if type(holder) == "table" then
			local ok, value = pcall(function() return holder[pairsList[i][2]] end)
			if ok and type(value) == "function" then return value end
		end
	end
	return nil
end

--[[ Register a capability. `alt` is an optional pure-Lua fallback; when a
     fallback is used the capability still reports as *emulated* so features
     that need the real thing can refuse. ]]
local function cap(key, fn, fallback)
	if fn then
		M.fn[key]   = fn
		M.caps[key] = true
	elseif fallback then
		M.fn[key]   = fallback
		M.caps[key] = "emulated"
	else
		M.fn[key]   = nil
		M.caps[key] = false
	end
	return M.fn[key]
end
M.cap = cap

function M.has(key)
	return M.caps[key] == true
end

function M.usable(key)
	local state = M.caps[key]
	return state == true or state == "emulated"
end

function M.need(key)
	local fn = M.fn[key]
	if not fn then
		error({ iyCapability = key }, 0)
	end
	return fn
end

--[[ Call a capability if present; returns ok, result... ]]
function M.call(key, ...)
	local fn = M.fn[key]
	if not fn then return false, "capability '" .. key .. "' unavailable" end
	return pcall(fn, ...)
end

-- ── identity ────────────────────────────────────────────────────────────────
do
	local id = pick("identifyexecutor", "getexecutorname")
	local name, version
	if id then
		local ok, a, b = pcall(id)
		if ok then name, version = a, b end
	end
	M.executor = tostring(name or "Unknown")
	M.executorVersion = version and tostring(version) or nil
end

-- ── instance & reflection ───────────────────────────────────────────────────
cap("cloneref", pick("cloneref"), function(...) return ... end)
cap("compareinstances", pick("compareinstances"), function(a, b) return a == b end)
cap("gethiddenproperty", pick("gethiddenproperty", "get_hidden_property", "get_hidden_prop"))
cap("sethiddenproperty", pick("sethiddenproperty", "set_hidden_property", "set_hidden_prop"))
cap("getinstances", pick("getinstances"))
cap("getnilinstances", pick("getnilinstances"))
cap("protectgui", pick("protectgui", "protect_gui", "syn_protect_gui"))
cap("unprotectgui", pick("unprotectgui", "unprotect_gui"))

-- ── hooking ─────────────────────────────────────────────────────────────────
cap("hookfunction", pick("hookfunction", "replaceclosure", "detour_function"))
cap("hookmetamethod", pick("hookmetamethod"))
cap("getrawmetatable", pick("getrawmetatable", "debug_getmetatable"))
cap("setreadonly", pick("setreadonly", "make_writeable"))
cap("isreadonly", pick("isreadonly"))
cap("getnamecallmethod", pick("getnamecallmethod", "get_namecall_method"))
cap("setnamecallmethod", pick("setnamecallmethod", "set_namecall_method"))
cap("newcclosure", pick("newcclosure"), function(f) return f end)
cap("checkcaller", pick("checkcaller"), function() return false end)
cap("getgc", pick("getgc", "get_gc_objects"))
cap("getconnections", pick("getconnections", "get_signal_cons"))
cap("getcallingscript", pick("getcallingscript"))
cap("setthreadidentity", pick("setthreadidentity", "set_thread_identity", "syn_context_set", "setthreadcontext")
	or pickNested({ { "syn", "set_thread_identity" } }))
cap("getthreadidentity", pick("getthreadidentity", "get_thread_identity", "getidentity"))
cap("replicatesignal", pick("replicatesignal"))
cap("getscriptclosure", pick("getscriptclosure", "getscriptfunction"))
cap("getsenv", pick("getsenv"))
cap("getgenv", pick("getgenv"))

-- ── input & interaction ─────────────────────────────────────────────────────
cap("firetouchinterest", pick("firetouchinterest"))
cap("fireclickdetector", pick("fireclickdetector"))
cap("fireproximityprompt", pick("fireproximityprompt"))
cap("mouse1click", pick("mouse1click"))
cap("mouse1press", pick("mouse1press"))
cap("mouse1release", pick("mouse1release"))
cap("mousemoverel", pick("mousemoverel"))
cap("keypress", pick("keypress"))
cap("keyrelease", pick("keyrelease"))

-- ── system ──────────────────────────────────────────────────────────────────
cap("setfpscap", pick("setfpscap", "set_fps_cap"))
cap("setclipboard", pick("setclipboard", "toclipboard", "set_clipboard")
	or pickNested({ { "Clipboard", "set" } }))
cap("queueteleport", pick("queue_on_teleport", "queueonteleport")
	or pickNested({ { "syn", "queue_on_teleport" }, { "fluxus", "queue_on_teleport" } }))
cap("request", pick("request", "http_request", "httprequest")
	or pickNested({ { "syn", "request" }, { "http", "request" }, { "fluxus", "request" } }))
cap("getcustomasset", pick("getcustomasset", "getsynasset", "get_custom_asset"))
cap("setsimulationradius", pick("setsimulationradius"))

-- ── filesystem (raw; core/fs wraps these) ───────────────────────────────────
cap("writefile", pick("writefile"))
cap("readfile", pick("readfile"))
cap("appendfile", pick("appendfile"))
cap("isfile", pick("isfile"))
cap("delfile", pick("delfile"))
cap("listfiles", pick("listfiles"))
cap("makefolder", pick("makefolder"))
cap("isfolder", pick("isfolder"))
cap("delfolder", pick("delfolder"))
cap("loadstring", pick("loadstring", "load"))

-- ── derived capability groups ───────────────────────────────────────────────
M.canPersist  = M.has("writefile") and M.has("readfile")
M.canHook     = M.has("hookfunction") or M.has("hookmetamethod")
M.canHttp     = M.has("request")
M.canProtect  = M.has("protectgui")

--[[ Human-readable reason a capability is missing, used in notifications. ]]
function M.explain(key)
	return "Your executor (" .. M.executor .. ") does not support '" .. tostring(key) .. "'."
end

--[[ Snapshot for the diagnostics panel / ;iydiag. ]]
function M.snapshot()
	local supported, emulated, missing = {}, {}, {}
	for key, state in pairs(M.caps) do
		if state == true then supported[#supported + 1] = key
		elseif state == "emulated" then emulated[#emulated + 1] = key
		else missing[#missing + 1] = key end
	end
	table.sort(supported); table.sort(emulated); table.sort(missing)
	return {
		executor  = M.executor,
		version   = M.executorVersion,
		supported = supported,
		emulated  = emulated,
		missing   = missing,
		canPersist = M.canPersist,
		canHook    = M.canHook,
		canHttp    = M.canHttp,
	}
end

IY.env = M
return M
