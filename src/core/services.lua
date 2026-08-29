--[[═══════════════════════════════════════════════════════════════════════════
	core/services · cached, cloneref'd service access
	─────────────────────────────────────────────────────────────────────────
	    local Services = IY.import("core/services")
	    Services.Players.LocalPlayer
	    Services.RunService.RenderStepped

	Lazily resolved, memoised, and passed through cloneref so anti-cheats that
	compare service references cannot fingerprint us. Unknown service names
	raise immediately with the name in the message (the legacy version raised
	"Invalid Service" with no context).

	`Services.get(name)` never throws -- it returns nil for services missing on
	older clients (ExperienceService, CaptureService, ...), which is what lets
	features degrade instead of crashing at import time.
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Env = IY.import("core/env")

local cloneref = Env.fn.cloneref or function(...) return ... end

local cache = {}
local missing = {}

local function resolve(name)
	if cache[name] ~= nil then return cache[name] end
	if missing[name] then return nil end
	local ok, service = pcall(function() return cloneref(game:GetService(name)) end)
	if ok and service then
		cache[name] = service
		return service
	end
	missing[name] = true
	return nil
end

local M = setmetatable({}, {
	__index = function(self, name)
		if type(name) ~= "string" then return nil end
		local service = resolve(name)
		if not service then
			error("[iy] unknown or unavailable service: " .. tostring(name), 2)
		end
		rawset(self, name, service)
		return service
	end,
})

--[[ Nil-safe lookup for services that may not exist on every client. ]]
function M.get(name)
	return resolve(name)
end

--[[ True when the client exposes this service. ]]
function M.available(name)
	return resolve(name) ~= nil
end

--[[ Names that were requested but do not exist -- shown in ;iydiag. ]]
function M.unavailable()
	local out = {}
	for name in pairs(missing) do out[#out + 1] = name end
	table.sort(out)
	return out
end

rawset(M, "__isServices", true)

IY.services = M
return M
