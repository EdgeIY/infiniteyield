--[[═══════════════════════════════════════════════════════════════════════════
	cmd/context · what a command's `run` receives
	─────────────────────────────────────────────────────────────────────────
	    run = function(ctx)
	        ctx.args.players     -- list of Targets, already resolved
	        ctx.args.speed        -- a number, already validated
	        ctx:each(function(target) ... end)   -- per-target error isolation
	        ctx:reply("done")     -- notification titled with the command name
	        ctx:fail("nope")      -- abort with a user-facing message
	    end

	Two behaviours matter more than the rest:

	  · **Argument defaults are resolved through the type**, so `default = "me"`
	    on a `players` argument arrives as a real Target list, and `default = 16`
	    on a number arrives as a number.
	  · **`ctx:each` isolates per target.** Legacy command loops aborted on the
	    first failure, so `;kill all` stopped at the first player who had just
	    died. Here every target is attempted and the caller gets a summary.
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Guard  = IY.import("core/guard")
local Log    = IY.import("core/log")
local Notify = IY.import("core/notify")
local Str    = IY.import("core/util/strings")
local Tbl    = IY.import("core/util/tables")
local Types  = IY.import("cmd/types")
local Parser = IY.import("cmd/parser")
local Target = IY.import("core/target")

local M = {}

local Context = {}
Context.__index = Context

-- ═══ argument resolution ════════════════════════════════════════════════════

local function resolveDefault(spec, ctx)
	local default = spec.default
	if default == nil then return nil end
	if type(default) == "function" then
		return default(ctx)
	end
	if type(default) == "string" or type(default) == "number" then
		-- Defaults go through the type, so `default = "me"` on a players
		-- argument arrives as a Target list. A default that cannot be parsed is
		-- reported rather than passed through raw: an implicit "me" against
		-- `excludeSelf = true` has to say "that only matched you", not hand the
		-- command the string "me".
		local definition = Types.get(spec.type)
		return definition.parse(default, spec, ctx)
	end
	return default
end

--[[ Parse the raw tokens of an invocation into named values. Raises a user
     error (caught by the dispatcher, shown with the usage line) on bad input. ]]
function M.parseArgs(definition, invocation, ctx)
	local named, positional = {}, {}
	local specs = definition.args

	for index = 1, #specs do
		local spec = specs[index]
		local raw

		if spec.greedy then
			raw = Parser.remainder(invocation, index)
			if raw == "" then raw = nil end
		else
			raw = invocation.args[index]
		end

		local value
		if raw == nil or raw == "" then
			if not spec.optional then
				Guard.fail("missing <%s>\nusage: %s", spec.name, definition.usage)
			end
			value = resolveDefault(spec, ctx)
		else
			local typeDefinition = Types.get(spec.type)
			local ok, result = pcall(typeDefinition.parse, raw, spec, ctx)
			if not ok then
				local kind, message = Guard.classify(result)
				if kind == "user" then
					Guard.fail("%s: %s\nusage: %s", spec.name, message, definition.usage)
				end
				error(result, 0)
			end
			value = result
		end

		named[spec.name] = value
		positional[index] = value
	end

	return named, positional
end

-- ═══ context ════════════════════════════════════════════════════════════════

function M.new(definition, invocation, speaker, extra)
	local ctx = setmetatable({
		cmd        = definition,
		name       = definition.name,
		invocation = invocation,
		raw        = invocation and invocation.raw or definition.name,
		rawArgs    = invocation and Parser.remainder(invocation, 1) or "",
		tokens     = invocation and invocation.args or {},
		speaker    = speaker or Target.localTarget(),
		iteration  = 1,
		startedAt  = os.clock and os.clock() or 0,
		log        = Log.scope("cmd:" .. definition.name),
	}, Context)

	if extra then Tbl.merge(ctx, extra) end
	return ctx
end

--[[ Notification titled with the command name -- the convention the whole
     command set follows, so users can tell what spoke. ]]
function Context:reply(text, duration)
	return Notify.send(self.name, tostring(text), duration)
end

function Context:notify(title, text, duration)
	if text == nil then return Notify.send(self.name, tostring(title), duration) end
	return Notify.send(title, text, duration)
end

--[[ Abort with a message the user sees. Never logged as an internal error. ]]
function Context:fail(message, ...)
	return Guard.fail(message, ...)
end

function Context:assert(condition, message, ...)
	if not condition then Guard.fail(message, ...) end
	return condition
end

--[[ The resolved value of an argument by name, with an optional fallback. ]]
function Context:get(name, fallback)
	local value = self.args and self.args[name]
	if value == nil then return fallback end
	return value
end

--[[ The list of targets for a players argument (defaults to the first one). ]]
function Context:targets(name)
	local value = self.args and (name and self.args[name] or nil)
	if value == nil and self.args then
		for i = 1, #self.cmd.args do
			local spec = self.cmd.args[i]
			if spec.multi then
				value = self.args[spec.name]
				break
			end
		end
	end
	if value == nil then return {} end
	if Target.is(value) then return { value } end
	if type(value) ~= "table" then return {} end
	-- Only real targets: a malformed value must not make `each` call its
	-- callback with nil.
	local out = {}
	for i = 1, #value do
		if Target.is(value[i]) then out[#out + 1] = value[i] end
	end
	return out
end

--[[ Run `fn` for every target, isolating failures.
     Returns succeeded, failed, and a list of {target, error}. ]]
function Context:each(fn, name)
	local targets = self:targets(name)
	local succeeded, failures = 0, {}
	for i = 1, #targets do
		local target = targets[i]
		local ok, err, kind = Guard.call("cmd:" .. self.name, fn, target, i)
		if ok then
			succeeded = succeeded + 1
		else
			failures[#failures + 1] = { target = target, error = err, kind = kind }
		end
	end

	-- One aggregated message beats N notifications when a batch partly fails.
	-- An internal error is re-raised as-is: laundering it into a user error
	-- would hide a real bug behind a friendly message.
	if #failures > 0 and succeeded == 0 then
		local first = failures[1]
		if first.kind == "internal" then
			error(first.error, 0)
		end
		Guard.fail("%s", Guard.describe(first.error))
	elseif #failures > 0 then
		local names = Tbl.map(failures, function(entry) return entry.target.name end)
		self.log.debug("failed for %s", table.concat(names, ", "))
	end

	return succeeded, #failures, failures
end

--[[ Convenience: the single target of a `player` argument, or the first of a
     `players` argument. ]]
function Context:target(name)
	local targets = self:targets(name)
	return targets[1]
end

--[[ True when the command was invoked with `nonotify` anywhere in its raw
     arguments. The legacy command set used this string as an ad-hoc flag when
     one command called another; keeping it means those call sites port over
     unchanged. ]]
function Context:quiet()
	if self.silent then return true end
	return string.find(Str.lower(self.raw or ""), "nonotify", 1, true) ~= nil
end

function Context:elapsed()
	return (os.clock and os.clock() or 0) - (self.startedAt or 0)
end

M.class = Context
return M
