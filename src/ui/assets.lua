--[[═══════════════════════════════════════════════════════════════════════════
	ui/assets · icon ids, their on-disk copies, and getcustomasset
	─────────────────────────────────────────────────────────────────────────
	Legacy source.ref.lua 109-152 (the `iyassets` table, the download loop and
	`getcustomasset`).

	Every icon exists twice: as a Roblox asset id, and as a PNG the script
	downloads into `infiniteyield/assets/` so executors that support
	`getcustomasset` can render it without a moderation round trip. Nothing here
	is required -- `M.get` walks down to the asset id when the executor has no
	filesystem, no getcustomasset, or the file simply is not there yet, so the
	interface looks the same either way.

	    Assets.get("infiniteyield/assets/logo.png")   -- content string
	    Assets.ids                                    -- path -> rbxassetid

	The download is still synchronous at load, exactly as in the legacy script,
	so the first paint already has the local files. Unlike the legacy version a
	single failed request no longer aborts the remaining eleven.
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Env      = IY.import("core/env")
local Fs       = IY.import("core/fs")
local Guard    = IY.import("core/guard")
local Log      = IY.import("core/log")
local Platform = IY.import("core/platform")

local log = Log.scope("ui/assets")

local M = {}

M.root   = "infiniteyield"
M.folder = "infiniteyield/assets"
M.source = "https://raw.githubusercontent.com/infyiff/backup/refs/heads/main/"

-- xylex & europa
M.ids = {
	["infiniteyield/assets/bindsandplugins.png"] = "rbxassetid://5147695474",
	["infiniteyield/assets/close.png"]           = "rbxassetid://5054663650",
	["infiniteyield/assets/editaliases.png"]     = "rbxassetid://5147488658",
	["infiniteyield/assets/editkeybinds.png"]    = "rbxassetid://129697930",
	["infiniteyield/assets/edittheme.png"]       = "rbxassetid://4911962991",
	["infiniteyield/assets/editwaypoints.png"]   = "rbxassetid://5147488592",
	["infiniteyield/assets/imgstudiopluginlogo.png"] = "rbxassetid://4113050383",
	["infiniteyield/assets/logo.png"]            = "rbxassetid://1352543873",
	["infiniteyield/assets/minimize.png"]        = "rbxassetid://2406617031",
	["infiniteyield/assets/pin.png"]             = "rbxassetid://6234691350",
	["infiniteyield/assets/reference.png"]       = "rbxassetid://3523243755",
	["infiniteyield/assets/settings.png"]        = "rbxassetid://1204397029",
}

M.status  = "pending"     -- pending | unavailable | ready
M.missing = 0             -- files that were not on disk when we looked
M.fetched = 0             -- files this session actually downloaded

local resolved = {}       -- path -> content string handed to Image properties

--[[ Sorted so a run is reproducible; the legacy loop iterated the hash part of
     the table and downloaded in whatever order Luau felt like. ]]
local function paths()
	local out = {}
	for path in pairs(M.ids) do out[#out + 1] = path end
	table.sort(out)
	return out
end
M.paths = paths

-- ── download ────────────────────────────────────────────────────────────────

--[[ Mirror the asset folder to disk. Returns true when the folder is usable.
     `makefolder` is the only capability that has no fallback -- existence is
     tested through core/fs, which falls back to a read when `isfile` is
     missing, so this is slightly more permissive than the legacy gate. ]]
function M.download()
	if not (Fs.available and Env.has("makefolder")) then
		M.status = "unavailable"
		return false, "filesystem unavailable"
	end

	Fs.ensureFolder(M.root)
	Fs.ensureFolder(M.folder)

	local list = paths()
	for i = 1, #list do
		local path = list[i]
		if Fs.exists(path) ~= true then
			M.missing = M.missing + 1
			local url = (string.gsub(path, "infiniteyield/", M.source))
			-- Contained per file: one dead URL used to abort the whole loop and
			-- leave every later icon without its local copy.
			local ok, body = pcall(function() return game:HttpGet(url) end)
			if ok and type(body) == "string" and body ~= "" then
				if Fs.write(path, body) then M.fetched = M.fetched + 1 end
			else
				log.warn("could not download %s (%s)", path, tostring(body))
			end
		end
	end

	-- honestly just blame your phone if the assets appear in your gallery
	if Platform.isMobile then Fs.write(M.folder .. "/.nomedia", "") end

	M.status = "ready"
	return true
end

-- ── lookup ──────────────────────────────────────────────────────────────────

--[[ The value to assign to an Image property. Prefers the local file through
     getcustomasset and falls back to the Roblox asset id, which is what makes
     the interface identical on an executor with no filesystem at all. ]]
function M.get(path)
	local cached = resolved[path]
	if cached then return cached end

	local id = M.ids[path]
	if id == nil then
		log.warn("unknown asset '%s'", tostring(path))
	end

	local getcustomasset = Env.fn.getcustomasset
	if getcustomasset then
		local ok, result = pcall(getcustomasset, path)
		if ok and type(result) == "string" and result ~= "" then
			resolved[path] = result
			return result
		end
	end

	-- Empty string rather than nil: an Image property rejects nil outright, and
	-- a missing icon must not be able to abort building the window.
	resolved[path] = id or ""
	return resolved[path]
end

function M.has(path)
	return M.ids[path] ~= nil
end

--[[ Forget the resolved strings so a later download() is picked up. ]]
function M.clearCache()
	resolved = {}
end

Guard.call("ui/assets.download", M.download)

return M
