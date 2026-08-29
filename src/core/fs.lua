--[[═══════════════════════════════════════════════════════════════════════════
	core/fs · guarded filesystem with a coalescing writer
	─────────────────────────────────────────────────────────────────────────
	Legacy IY wrote through `writefileCooldown`: every call spawned a task that
	slept three seconds and then wrote *its own* payload, so a burst of saves
	produced a burst of threads and whichever one finished sleeping last won --
	frequently not the newest. Settings themselves went out through a plain
	writefile, so a crash mid-write left a truncated IY_FE.iy, which the legacy
	script "recovered" from by deleting the user's settings.

	Three fixes, one module:

	  · one round-trip probe at load decides whether persistence works at all,
	    so no other module has to guess (M.available, M.status)
	  · M.queueWrite coalesces by filename -- three saves inside the flush
	    window become one write of the newest payload -- and M.flush(), which
	    also runs on unload, guarantees the last one lands
	  · M.writeAtomic writes a .tmp, reads it back, and only then replaces the
	    real file, so a crash can no longer truncate anything that matters

	Every path goes through M.path, which rejects `..`, absolute paths, drive
	letters and backslashes. The executor already confines us to its workspace
	folder; M.path makes sure no command or plugin can walk out of it.

	Nothing here raises when the executor cannot do files: calls return
	nil, "filesystem unavailable" and the reason is logged exactly once.
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Env   = IY.import("core/env")
local Log   = IY.import("core/log")
local Guard = IY.import("core/guard")
local Sched = IY.import("core/scheduler")
local Json  = IY.import("core/json")

local log = Log.scope("core/fs")

local concat, sort = table.concat, table.sort
local find, gsub, sub = string.find, string.gsub, string.sub

local M = {}

local fn = Env.fn
local UNAVAILABLE = "filesystem unavailable"

M.root          = "infiniteyield"
M.flushInterval = 1
M.available     = false
M.status        = { read = false, write = false, folder = false, reason = nil }
M.stats         = { writes = 0, coalesced = 0, failures = 0 }

-- ── paths ───────────────────────────────────────────────────────────────────

--[[ One place decides what a legal path looks like, so no command and no
     plugin can hand the executor "../../Documents/x" or "C:\Windows\y". ]]
local function checkSegment(segment)
	if type(segment) == "number" then segment = tostring(segment) end
	if type(segment) ~= "string" or segment == "" then
		Guard.fail("invalid path segment: %s", tostring(segment))
	end
	if find(segment, "\\", 1, true) then
		Guard.fail("path '%s' contains a backslash -- use '/'", segment)
	end
	if sub(segment, 1, 1) == "/" then
		Guard.fail("path '%s' is absolute", segment)
	end
	if find(segment, "%.%.") then
		Guard.fail("path '%s' walks out of the workspace with '..'", segment)
	end
	if find(segment, "^%a:") then
		Guard.fail("path '%s' names a drive", segment)
	end
	return segment
end

function M.path(...)
	local parts, count = {}, 0
	for i = 1, select("#", ...) do
		local segment = select(i, ...)
		if segment ~= nil then
			count = count + 1
			parts[count] = checkSegment(segment)
		end
	end
	if count == 0 then Guard.fail("empty path") end
	return (gsub(concat(parts, "/"), "//+", "/"))
end

--[[ A path inside the IY folder. The settings file deliberately does not use
     this -- it stays at the workspace root as IY_FE.iy so that IY and the
     legacy script keep reading each other's settings. ]]
function M.rootPath(...)
	return M.path(M.root, ...)
end

-- ── raw executor calls ──────────────────────────────────────────────────────

local function rawWrite(path, data)
	if not fn.writefile then return false, "writefile unsupported" end
	local ok, err = pcall(fn.writefile, path, data)
	if not ok then return false, tostring(err) end
	return true
end

local function rawRead(path)
	if not fn.readfile then return nil, "readfile unsupported" end
	local ok, contents = pcall(fn.readfile, path)
	if not ok then return nil, tostring(contents) end
	if type(contents) ~= "string" then
		return nil, "readfile returned a " .. type(contents)
	end
	return contents
end

local function rawDelete(path)
	if not fn.delfile then return false, "delfile unsupported" end
	local ok, err = pcall(fn.delfile, path)
	if not ok then return false, tostring(err) end
	return true
end

--[[ Idempotent: some executors throw when the folder already exists. ]]
function M.ensureFolder(name)
	if not fn.makefolder then return nil, "makefolder unsupported" end
	local path = M.path(name)
	if fn.isfolder then
		local ok, exists = pcall(fn.isfolder, path)
		if ok and exists then return true end
	end
	local ok, err = pcall(fn.makefolder, path)
	if not ok then return false, tostring(err) end
	return true
end

-- ── availability ────────────────────────────────────────────────────────────

--[[ Executors that expose writefile and then throw on use, or that write into a
     sandbox readfile cannot see, are common. The only trustworthy test is an
     actual round trip, so do exactly one at load; everything else reads
     M.status instead of guessing. ]]
local function probe()
	local status = M.status
	if not (fn.writefile and fn.readfile) then
		status.reason = "executor does not expose writefile/readfile"
		return
	end
	status.folder = M.ensureFolder(M.root) == true
	local payload = "iy-probe-" .. tostring(os.time and os.time() or 0)
		.. "-" .. tostring(math.random(100000, 999999))
	-- Inside the IY folder first; if makefolder is broken, fall back to the
	-- workspace root, which is where the settings file lives anyway.
	local candidates = {}
	if status.folder then candidates[#candidates + 1] = M.root .. "/.probe" end
	candidates[#candidates + 1] = "iy_probe.tmp"
	for i = 1, #candidates do
		local path = candidates[i]
		local written, writeErr = rawWrite(path, payload)
		if written then
			status.write = true
			local contents, readErr = rawRead(path)
			if contents == payload then
				status.read = true
			else
				status.reason = readErr
					or "readfile returned different bytes than writefile stored"
			end
			rawDelete(path)
			if status.read then return end
		else
			status.reason = writeErr
		end
	end
end

do
	local ok, err = pcall(probe)
	if not ok then
		M.status.reason = "probe failed: " .. tostring(err)
	end
	M.available = M.status.read == true and M.status.write == true
	if not M.available and not M.status.reason then
		M.status.reason = "unknown filesystem failure"
	end
end

--[[ Logged once, not once per call: an executor without files would otherwise
     produce a line of console spam for every setting the user changes. Reads
     and writes are gated separately because a broken makefolder or a read-only
     sandbox leaves one half working, and half is better than nothing. ]]
local warned = false
local function unavailable()
	if not warned then
		warned = true
		log.warn("persistence is disabled (%s) -- settings, waypoints and plugins will not survive a rejoin",
			M.status.reason or UNAVAILABLE)
	end
	return nil, UNAVAILABLE
end

-- ── coalescing writer ───────────────────────────────────────────────────────

local pending = {}          -- validated path -> newest payload
local pendingCount = 0
local flushScheduled = false

local function flushPath(path)
	local data = pending[path]
	if data == nil then return true end
	pending[path] = nil
	pendingCount = pendingCount - 1
	return M.write(path, data)
end

--[[ Saves of the same file inside the flush window collapse into a single write
     of the newest payload; different files never wait for each other. ]]
function M.queueWrite(name, data)
	if not M.status.write then return unavailable() end
	local path = M.path(name)
	if type(data) ~= "string" then data = tostring(data) end
	if pending[path] ~= nil then
		M.stats.coalesced = M.stats.coalesced + 1
	else
		pendingCount = pendingCount + 1
	end
	pending[path] = data
	if not flushScheduled then
		flushScheduled = true
		-- One timer per batch instead of a permanent loop: nothing ticks while
		-- nothing is queued.
		Sched.after(M.flushInterval, function()
			flushScheduled = false
			M.flush()
		end, "fs.flush")
	end
	return true
end

--[[ Write pending payloads now. Runs on unload, so the newest save still lands
     when the window has not elapsed. ]]
function M.flush(name)
	if name ~= nil then
		return flushPath(M.path(name))
	end
	if pendingCount == 0 then return true, 0 end
	local paths = {}
	for path in pairs(pending) do paths[#paths + 1] = path end
	sort(paths)              -- deterministic order keeps failures reproducible
	local failures = 0
	for i = 1, #paths do
		if not flushPath(paths[i]) then failures = failures + 1 end
	end
	return failures == 0, failures
end

function M.queued()
	return pendingCount
end

-- ── files ───────────────────────────────────────────────────────────────────

function M.read(name)
	if not M.status.read then return unavailable() end
	local path = M.path(name)
	-- A queued write must never be invisible to the next read of that file.
	if pending[path] ~= nil then flushPath(path) end
	return rawRead(path)
end

function M.write(name, data)
	if not M.status.write then return unavailable() end
	if type(data) ~= "string" then data = tostring(data) end
	local path = M.path(name)
	local ok, err = rawWrite(path, data)
	if not ok then
		M.stats.failures = M.stats.failures + 1
		log.warn("write to %s failed: %s", path, tostring(err))
		return false, err
	end
	M.stats.writes = M.stats.writes + 1
	return true
end

--[[ appendfile is missing on several executors and refuses new files on others,
     so fall back to read-modify-write rather than losing the line. ]]
function M.append(name, data)
	if not M.status.write then return unavailable() end
	local path = M.path(name)
	if pending[path] ~= nil then flushPath(path) end
	if type(data) ~= "string" then data = tostring(data) end
	if fn.appendfile then
		local ok = pcall(fn.appendfile, path, data)
		if ok then
			M.stats.writes = M.stats.writes + 1
			return true
		end
	end
	return M.write(path, (rawRead(path) or "") .. data)
end

function M.exists(name)
	if not M.status.read then return unavailable() end
	local path = M.path(name)
	if pending[path] ~= nil then return true end
	if fn.isfile then
		local ok, result = pcall(fn.isfile, path)
		if ok then return result == true end
	end
	-- No isfile: a read is the only portable existence test.
	return rawRead(path) ~= nil
end

function M.delete(name)
	if not M.status.write then return unavailable() end
	local path = M.path(name)
	pending[path] = nil          -- do not resurrect a deleted file from the queue
	return rawDelete(path)
end

function M.list(folder)
	if not M.status.read then return unavailable() end
	if not fn.listfiles then return nil, "listfiles unsupported" end
	local ok, entries = pcall(fn.listfiles, M.path(folder or M.root))
	if not ok then return nil, tostring(entries) end
	if type(entries) ~= "table" then return {} end
	return entries
end

function M.copy(from, to)
	local contents, err = M.read(from)
	if contents == nil then return nil, err end
	return M.write(to, contents)
end

function M.backup(name)
	local ok, err = M.copy(name, name .. ".bak")
	if not ok then return nil, err end
	return true, M.path(name) .. ".bak"
end

function M.restoreBackup(name)
	local contents, err = M.read(name .. ".bak")
	if contents == nil then return nil, err end
	return M.write(name, contents)
end

--[[ Write, verify, then replace. Nothing touches the real file until the temp
     copy has been read back byte for byte, so an executor that dies mid-write
     can leave a bad .tmp but never a bad settings file. ]]
function M.writeAtomic(name, data)
	if not M.status.write then return unavailable() end
	if type(data) ~= "string" then data = tostring(data) end
	local path = M.path(name)
	local temp = path .. ".tmp"
	local written, writeErr = rawWrite(temp, data)
	if not written then
		M.stats.failures = M.stats.failures + 1
		return false, "temp write failed: " .. tostring(writeErr)
	end
	local contents, readErr = rawRead(temp)
	if contents ~= data then
		M.stats.failures = M.stats.failures + 1
		rawDelete(temp)
		return false, "verification failed: "
			.. (readErr or "the temp file read back different bytes")
	end
	local ok, err = rawWrite(path, data)
	if not ok then
		M.stats.failures = M.stats.failures + 1
		return false, tostring(err)
	end
	rawDelete(temp)              -- best effort; a leftover .tmp is harmless
	M.stats.writes = M.stats.writes + 1
	return true
end

-- ── JSON documents ──────────────────────────────────────────────────────────

--[[ Never throws: a hand-mangled file comes back as nil plus a reason with the
     character offset, which is what lets the settings store preserve it instead
     of deleting it. ]]
function M.readJSON(name)
	local contents, err = M.read(name)
	if contents == nil then return nil, err end
	local value, parseErr = Json.decode(contents)
	if parseErr then return nil, parseErr end
	return value
end

--[[ Pretty by default -- these files get opened and edited by hand. ]]
function M.writeJSON(name, value, pretty)
	if not M.status.write then return unavailable() end
	local ok, encoded = pcall(Json.encode, value, pretty ~= false)
	if not ok then return false, Guard.describe(encoded) end
	return M.write(name, encoded)
end

-- Anything still queued when IY unloads is written now, not lost.
IY.onUnload(function()
	M.flush()
end, "core/fs")

IY.fs = M
return M

