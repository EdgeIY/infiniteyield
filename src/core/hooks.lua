--[[═══════════════════════════════════════════════════════════════════════════
	core/hooks · one owned metamethod dispatcher
	─────────────────────────────────────────────────────────────────────────
	The legacy script installed four independent metamethod layers, none of
	which could ever be taken back off:

	  · clientantikick       hookmetamethod(game, "__namecall")   line 7947
	  · clientantiteleport   a *second* __namecall layer           line 8003
	  · spoofspeed           __index + __newindex, per invocation  line 10404
	  · spoofjumppower       __index + __newindex, per invocation  line 10455

	Four consequences, all of which arrived as bug reports:

	  1. `;spoofspeed 100` five times left five __index layers, each running on
	     every property read in the game -- an unbounded tax on the hottest
	     code path in the client, with no `;unspoofspeed` possible because the
	     layers were unaddressable
	  2. both namecall hooks shared one precedence bug:
	         if select(1, ...) == LocalPlayer and method == "Kick" or method == "kick"
	     which Lua reads as `(a == b and m == "Kick") or (m == "kick")`, so
	     *every* object's :kick() call was swallowed, from any script
	  3. the anti-kick had no checkcaller() test, so IY's own `rejoin` -- which
	     kicks the player on purpose -- was blocked by IY itself
	  4. an error inside any layer broke every instance access in the client,
	     which is not recoverable without rejoining

	This module owns exactly one hook per metamethod and multiplexes named
	handlers over it:

	    Hooks.namecall("antikick", function(self, method, ...)
	        if self == lp and method == "Kick" then return true end  -- swallow
	    end)                                    -- return nothing to pass through
	    Hooks.unregister("antikick")            -- the hook stays installed but
	                                            -- becomes a pass-through
	    local release = Hooks.exempt("rejoin")  -- stand down for one deliberate
	    ...                                     -- call, then release()

	Registering an id twice replaces it, so a command run twice cannot stack a
	second layer. A handler that errors is logged once and dropped. There is no
	`unhookmetamethod` in any executor, which is exactly why the dispatcher has
	to be able to go inert rather than be removed.

	Handlers must not yield: they run inside a metamethod, across a C boundary.
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Env = IY.import("core/env")
local Log = IY.import("core/log")

local log = Log.scope("core/hooks")
local unpack = table.unpack or unpack
local pack = table.pack or function(...) return { n = select("#", ...), ... } end

local M = {}

-- One slot per metamethod. `original` is whatever hookmetamethod handed back,
-- `order` is the handler list in registration order, `busy` is the re-entrancy
-- latch described at dispatch().
local function newSlot(metamethod)
	return {
		metamethod = metamethod,
		order      = {},
		byId       = {},
		installed  = false,
		original   = nil,
		busy       = false,
		dirty      = false,
	}
end

local slots = {
	namecall = newSlot("__namecall"),
	index    = newSlot("__index"),
	newindex = newSlot("__newindex"),
}

local functionHooks = {}   -- id -> { target, original, replacement }
local retired = false      -- set by the unload hook: dispatchers go inert
local exemptions = 0       -- >0 while a deliberate call is exempt (see M.exempt)

function M.canHook()
	return Env.has("hookmetamethod")
end

--[[ Did this call come from our own script? Env emulates checkcaller as
     `return false` when the executor lacks it, so `skipSelf` degrades to "run
     anyway" -- the legacy behaviour -- rather than "never run", which would
     silently disable every handler. ]]
local function fromSelf()
	local checkcaller = Env.fn.checkcaller
	if not checkcaller then return false end
	local ok, result = pcall(checkcaller)
	return ok and result == true
end

--[[ Disable an entry. Removal is deferred to compact() so a handler that
     unregisters itself (or errors) cannot shift the array we are iterating. ]]
local function detach(slot, entry, reason)
	entry.enabled = false
	if slot.byId[entry.id] == entry then slot.byId[entry.id] = nil end
	slot.dirty = true
	if reason ~= nil then
		log.error("%s handler '%s' errored and was removed: %s",
			slot.metamethod, tostring(entry.id), Log.stringify(reason))
	end
end

local function compact(slot)
	slot.dirty = false
	local order = slot.order
	local kept = 0
	for i = 1, #order do
		local entry = order[i]
		if entry.enabled then
			kept = kept + 1
			order[kept] = entry
		end
	end
	for i = #order, kept + 1, -1 do order[i] = nil end
end

--[[ Run the handler list in registration order. Returns the packed pcall
     result of the handler that intercepted (its values start at index 3), or
     nil to fall through to the original metamethod. First to intercept wins. ]]
local function runList(slot, ...)
	local order = slot.order
	local selfCall = nil          -- checkcaller() result, resolved at most once
	for i = 1, #order do
		local entry = order[i]
		if entry and entry.enabled then
			local skip = false
			if entry.skipSelf then
				if selfCall == nil then selfCall = fromSelf() end
				skip = selfCall
			end
			if not skip then
				entry.calls = entry.calls + 1
				local result = pack(pcall(entry.fn, ...))
				if not result[1] then
					detach(slot, entry, result[2])
				elseif result[2] then
					return result
				end
			end
		end
	end
	return nil
end

-- Resolved once: Env.fn is fixed after boot, and this is read on every
-- namecall in the game.
local getnamecallmethod = Env.fn.getnamecallmethod

--[[ Every dispatcher has the same shape:

       · inert while retired, or while nothing is registered -- straight to the
         original, which is what makes unregister() safe without an
         unhookmetamethod that does not exist
       · re-entrant calls go straight to the original too. A handler that reads
         `self.Parent` or calls `self:IsA(...)` re-enters the very metamethod it
         is running inside; without this latch the first such handler hangs the
         client
       · the handler loop is pcall'd, so a bug in *this* module falls through to
         the original instead of throwing into game code ]]
local function dispatchNamecall(...)
	local slot = slots.namecall
	local original = slot.original
	if not original then return end
	if retired or exemptions > 0 or slot.busy or #slot.order == 0 then return original(...) end
	slot.busy = true
	local method = ""
	if getnamecallmethod then
		local okMethod, name = pcall(getnamecallmethod)
		if okMethod and name ~= nil then method = name end
	end
	local ok, result = pcall(runList, slot, (select(1, ...)), method, select(2, ...))
	if slot.dirty then compact(slot) end
	slot.busy = false
	if ok and result then return unpack(result, 3, result.n) end
	return original(...)
end

--[[ __index and __newindex differ only in arity, and both pass their arguments
     to handlers untouched: handler(self, key) / handler(self, key, value). ]]
local function plainDispatcher(slot)
	return function(...)
		local original = slot.original
		if not original then return end
		if retired or exemptions > 0 or slot.busy or #slot.order == 0 then return original(...) end
		slot.busy = true
		local ok, result = pcall(runList, slot, ...)
		if slot.dirty then compact(slot) end
		slot.busy = false
		if ok and result then return unpack(result, 3, result.n) end
		return original(...)
	end
end

local dispatchers = {
	namecall = dispatchNamecall,
	index    = plainDispatcher(slots.index),
	newindex = plainDispatcher(slots.newindex),
}

--[[ Install a dispatcher, once, on first registration. Never re-installed:
     hookmetamethod stacks, so a second install would be a second layer -- the
     exact leak this module exists to prevent. ]]
local function ensureInstalled(kind)
	local slot = slots[kind]
	if slot.installed then return true end
	local hookmetamethod = Env.fn.hookmetamethod
	if not hookmetamethod then
		return false, Env.explain("hookmetamethod")
	end
	local dispatcher = dispatchers[kind]
	local wrapped = dispatcher
	local newcclosure = Env.fn.newcclosure
	if newcclosure then
		-- Executors that check for a Lua closure in the metatable reject a bare
		-- function here; Env's fallback is the identity, so this is safe either way.
		local okWrap, closure = pcall(newcclosure, dispatcher)
		if okWrap and type(closure) == "function" then wrapped = closure end
	end
	local ok, original = pcall(hookmetamethod, game, slot.metamethod, wrapped)
	if not ok or type(original) ~= "function" then
		local reason = ok
			and ("hookmetamethod returned a " .. type(original))
			or Log.stringify(original)
		log.debug("could not install %s: %s", slot.metamethod, reason)
		return false, reason
	end
	slot.original  = original
	slot.installed = true
	log.debug("installed the %s dispatcher", slot.metamethod)
	if kind == "namecall" and not getnamecallmethod then
		log.debug("no getnamecallmethod: namecall handlers see an empty method name")
	end
	return true
end

local function register(kind, id, handler, opts)
	if type(id) ~= "string" and type(id) ~= "number" then
		error("[iy] Hooks." .. kind .. " needs an id, got " .. type(id), 3)
	end
	if type(handler) ~= "function" then
		error("[iy] Hooks." .. kind .. "('" .. tostring(id) .. "') needs a function", 3)
	end
	local ok, reason = ensureInstalled(kind)
	if not ok then
		log.debug("'%s' cannot hook %s: %s", tostring(id), kind, tostring(reason))
		return false, reason
	end
	local slot = slots[kind]
	local previous = slot.byId[id]
	if previous then detach(slot, previous) end
	if slot.dirty and not slot.busy then compact(slot) end
	local skipSelf = true
	if opts and opts.skipSelf ~= nil then skipSelf = opts.skipSelf == true end
	local entry = {
		id = id, fn = handler, kind = kind,
		skipSelf = skipSelf, enabled = true, calls = 0,
	}
	slot.order[#slot.order + 1] = entry
	slot.byId[id] = entry
	return true
end

--[[ handler(self, method, ...) -> nothing to pass through, or `true, value...`
     to intercept and hand `value...` back to the caller.

     opts.skipSelf (default true) skips the handler when the call came from our
     own script. The legacy anti-kick omitted this, which is why IY's own
     `rejoin` command threw once anti-kick was on. ]]
function M.namecall(id, handler, opts)
	return register("namecall", id, handler, opts)
end

--[[ handler(self, key) -- same return contract as namecall. ]]
function M.index(id, handler, opts)
	return register("index", id, handler, opts)
end

--[[ handler(self, key, value) -- return true to swallow the assignment. ]]
function M.newindex(id, handler, opts)
	return register("newindex", id, handler, opts)
end

--[[ Ids are unique per kind, but unregister sweeps all three so a feature that
     registered an __index and an __newindex under one name (spoofspeed did
     exactly that) tears both down with one call. Pass `kind` to narrow. ]]
function M.unregister(id, kind)
	local removed = 0
	for name, slot in pairs(slots) do
		if kind == nil or kind == name then
			local entry = slot.byId[id]
			if entry then
				detach(slot, entry)
				if not slot.busy then compact(slot) end
				removed = removed + 1
			end
		end
	end
	return removed > 0, removed
end

function M.isRegistered(id, kind)
	for name, slot in pairs(slots) do
		if kind == nil or kind == name then
			if slot.byId[id] then return true, name end
		end
	end
	return false
end

--[[ Env.fn.hookfunction with bookkeeping. The legacy anti-kick and
     anti-teleport threw the returned original away (lines 7954, 7991), so no
     `;unclientantikick` could exist; keeping it is the whole difference. ]]
function M.hookFunction(id, target, replacement)
	if type(target) ~= "function" then return false, "hook target is not a function" end
	if type(replacement) ~= "function" then return false, "replacement is not a function" end
	local hookfunction = Env.fn.hookfunction
	if not hookfunction then return false, Env.explain("hookfunction") end
	if functionHooks[id] then M.unhookFunction(id) end

	local wrapped = replacement
	local newcclosure = Env.fn.newcclosure
	if newcclosure then
		local okWrap, closure = pcall(newcclosure, replacement)
		if okWrap and type(closure) == "function" then wrapped = closure end
	end

	local ok, original = pcall(hookfunction, target, wrapped)
	if not ok then return false, Log.stringify(original) end
	functionHooks[id] = {
		target      = target,
		replacement = wrapped,
		original    = type(original) == "function" and original or nil,
	}
	if type(original) ~= "function" then
		-- The hook is live, but there is nothing to put back. Say so instead of
		-- handing back `target`, which now *is* the replacement.
		return false, "hookfunction did not return the original; this hook cannot be undone"
	end
	return original
end

function M.unhookFunction(id)
	local record = functionHooks[id]
	if not record then return false, "no function hook registered as '" .. tostring(id) .. "'" end
	functionHooks[id] = nil
	if not record.original then
		return false, "the original of '" .. tostring(id) .. "' was never handed back"
	end
	local hookfunction = Env.fn.hookfunction
	if not hookfunction then return false, Env.explain("hookfunction") end
	-- The target closure is still the one that was patched in place, so hooking
	-- it back to the stored original undoes the patch.
	local ok, err = pcall(hookfunction, record.target, record.original)
	if not ok then return false, Log.stringify(err) end
	return true
end

--[[ Stand every handler down for one deliberate call. IY's own `rejoin` kicks
     the player on purpose, and on executors where checkcaller is only emulated
     `skipSelf` cannot tell that call apart from a game script's. Returns a
     release function; overlapping exemptions are counted, and releasing twice
     is a no-op rather than an unbalanced decrement. ]]
function M.exempt(label)
	exemptions = exemptions + 1
	log.debug("handlers exempt for '%s'", tostring(label or "?"))
	local released = false
	return function()
		if released then return false end
		released = true
		exemptions = exemptions - 1
		if exemptions < 0 then exemptions = 0 end
		return true
	end
end

--[[ What is registered, per kind, for the diagnostics panel. ]]
function M.snapshot()
	local out = { canHook = M.canHook(), exempt = exemptions > 0, functions = {} }
	for name, slot in pairs(slots) do
		local ids = {}
		for i = 1, #slot.order do
			local entry = slot.order[i]
			if entry.enabled then
				ids[#ids + 1] = tostring(entry.id)
			end
		end
		table.sort(ids)
		out[name] = {
			metamethod = slot.metamethod,
			installed  = slot.installed,
			handlers   = ids,
		}
	end
	for id in pairs(functionHooks) do out.functions[#out.functions + 1] = tostring(id) end
	table.sort(out.functions)
	return out
end

IY.onUnload(function()
	retired = true
	exemptions = 0
	for _, slot in pairs(slots) do
		for i = 1, #slot.order do slot.order[i].enabled = false end
		slot.order = {}
		slot.byId  = {}
		slot.dirty = false
	end
	local ids = {}
	for id in pairs(functionHooks) do ids[#ids + 1] = id end
	for i = 1, #ids do M.unhookFunction(ids[i]) end
end, "core/hooks")

IY.hooks = M
return M
