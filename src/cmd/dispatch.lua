--[[═══════════════════════════════════════════════════════════════════════════
	cmd/dispatch · the execution pipeline
	─────────────────────────────────────────────────────────────────────────
	    line -> parse -> lookup -> guards -> arguments -> run -> report

	Every stage can fail cleanly. The legacy dispatcher was:

	    local success,err = pcall(cmd.FUNC,args,speaker)
	    if not success and _G.IY_DEBUG then warn("Command Error:",cmdName,err) end

	so unless the user had turned on a debug global, a failing command was
	indistinguishable from a command that did nothing -- the single biggest
	source of "IY is broken" reports. Here:

	  · a user error (bad argument, no target) shows the message and the usage
	  · a missing executor capability explains which feature the executor lacks
	  · an internal error notifies once and logs a full traceback
	  · an unknown command suggests the closest match

	Repeat / delay / infinite modifiers and `;breakloops` behave exactly as
	before, and `Dispatch.isActive` gives generated `toggle<name>` commands a
	single source of truth for on/off state.
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Guard    = IY.import("core/guard")
local Log      = IY.import("core/log")
local Notify   = IY.import("core/notify")
local Signal   = IY.import("core/signal")
local Env      = IY.import("core/env")
local Str      = IY.import("core/util/strings")
local Parser   = IY.import("cmd/parser")
local Registry = IY.import("cmd/registry")
local Context  = IY.import("cmd/context")
local Target   = IY.import("core/target")

local M = {}

local active   = {}    -- command name -> boolean (toggle state)
local running  = {}    -- command name -> count of in-flight invocations
local cooldowns = {}   -- command name -> clock of last run
local lastByName = {}  -- command name -> the full line last used, for `!name`

local breakAt = 0      -- clock of the last ;breakloops

M.executed = Signal.new("dispatch.executed")
M.failed   = Signal.new("dispatch.failed")
M.active   = active

local function clock()
	if os and os.clock then return os.clock() end
	return tick and tick() or 0
end

-- ═══ toggle state ═══════════════════════════════════════════════════════════

function M.isActive(name)
	return active[Str.lower(name)] == true
end

function M.setActive(name, value)
	active[Str.lower(name)] = value == true
	return value
end

--[[ Stop every repeat/infinite loop, exactly like the legacy ;breakloops. ]]
function M.breakLoops()
	breakAt = clock()
	return breakAt
end

-- ═══ guards ═════════════════════════════════════════════════════════════════

--[[ Check a command's `requires` table before touching its arguments, so the
     failure message is about the real problem rather than a nil index inside
     the command body. ]]
local function checkRequirements(definition, ctx)
	local requires = definition.requires
	if not requires then return true end

	if requires.capability then
		local list = type(requires.capability) == "table" and requires.capability or { requires.capability }
		for i = 1, #list do
			if not Env.usable(list[i]) then
				Guard.fail("%s", Env.explain(list[i]))
			end
		end
	end

	if requires.persist and not (IY.import("core/fs").available) then
		Guard.fail("this needs file access, which your executor does not provide")
	end

	if requires.character or requires.alive or requires.root then
		local character = ctx.speaker.character
		if not character then Guard.fail("you have no character right now") end
		if requires.root and not ctx.speaker.root then
			Guard.fail("your character is still loading") end
		if requires.alive and not ctx.speaker.alive then
			Guard.fail("you are dead") end
	end

	if requires.tool then
		local Inst = IY.import("core/util/instances")
		local player = ctx.speaker.player
		if not player or #Inst.tools(player) == 0 then
			Guard.fail("you need a tool for this")
		end
	end

	if requires.desktop and IY.import("core/platform").isMobile then
		Guard.fail("this only works on a computer")
	end

	if requires.check then
		local ok, reason = requires.check(ctx)
		if not ok then Guard.fail("%s", reason or "unavailable right now") end
	end

	return true
end

-- ═══ one invocation ═════════════════════════════════════════════════════════

local function reportFailure(definition, ctx, err, kind)
	local message = Guard.describe(err)
	if kind == "internal" then
		Notify.error(definition.name, "error: " .. message)
		Log.error("cmd:" .. definition.name, "%s", tostring(err))
	else
		Notify.send(definition.name, message)
	end
	M.failed:Fire(definition, err, kind)
end

--[[ Execute one parsed invocation, honouring its repeat modifiers.
     Runs on the calling thread; callers decide whether to spawn. ]]
function M.execute(invocation, speaker, opts)
	opts = opts or {}
	local definition = Registry.find(invocation.name)

	if not definition then
		-- A user alias can expand to a whole command line, so it is tried
		-- before we give up on the name.
		local Aliases = IY.import("cmd/aliases")
		local expanded = Guard.try(function() return Aliases.expand(invocation.raw) end)
		if expanded then
			local replayed = Parser.parseSegment(expanded)
			if replayed then
				replayed.repeats  = invocation.repeats
				replayed.delay    = invocation.delay
				replayed.infinite = invocation.infinite
				return M.execute(replayed, speaker, opts)
			end
		end
	end

	if not definition then
		if opts.silentUnknown then return false end
		local suggestion = Registry.closest(invocation.name)
		if suggestion then
			Notify.send("Unknown command", invocation.name .. " -- did you mean " .. suggestion .. "?")
		else
			Notify.send("Unknown command", tostring(invocation.name))
		end
		return false
	end

	if definition.disabled then
		Notify.send(definition.name, definition.disabledReason or "this command is disabled")
		return false
	end

	local ctx = Context.new(definition, invocation, speaker, opts.context)
	ctx.silent = opts.silent

	-- Guards and argument parsing happen once, outside the repeat loop: a
	-- typo should report immediately instead of once per iteration.
	local okGuards, guardErr, guardKind = Guard.call("cmd:" .. definition.name, function()
		checkRequirements(definition, ctx)
		local named, positional = Context.parseArgs(definition, invocation, ctx)
		ctx.args = named
		ctx.positional = positional
	end)
	if not okGuards then
		reportFailure(definition, ctx, guardErr, guardKind)
		return false
	end

	if definition.cooldown then
		local last = cooldowns[definition.name]
		local now = clock()
		if last and (now - last) < definition.cooldown then
			return false
		end
		cooldowns[definition.name] = now
	end

	if definition.singleton and (running[definition.name] or 0) > 0 then
		Notify.send(definition.name, "already running")
		return false
	end

	running[definition.name] = (running[definition.name] or 0) + 1
	local startedAt = clock()
	local iterations = invocation.infinite and math.huge or math.max(1, invocation.repeats or 1)
	local completed, failed = 0, 0

	local iteration = 1
	while iteration <= iterations do
		if breakAt > startedAt then break end
		ctx.iteration = iteration
		local ok, err, kind = Guard.call("cmd:" .. definition.name, definition.run, ctx)
		if ok then
			completed = completed + 1
		else
			failed = failed + 1
			reportFailure(definition, ctx, err, kind)
			-- A repeated command that fails once will fail every time; stop
			-- instead of spamming the user (the legacy loop kept going).
			break
		end
		if invocation.delay and invocation.delay > 0 and iteration < iterations then
			task.wait(invocation.delay)
		elseif invocation.infinite then
			task.wait(invocation.delay or 1)
		end
		iteration = iteration + 1
	end

	running[definition.name] = math.max(0, (running[definition.name] or 1) - 1)

	if completed > 0 and failed == 0 then
		-- Toggle bookkeeping: `fly` marks itself active, the generated `unfly`
		-- marks the original inactive.
		if definition.generatedFrom then
			if string.sub(definition.name, 1, 2) == "un" then
				M.setActive(definition.generatedFrom, false)
			end
		elseif type(definition.off) == "function" then
			M.setActive(definition.name, true)
		end
		M.executed:Fire(definition, ctx)
	end

	return failed == 0, ctx
end

-- ═══ full lines ═════════════════════════════════════════════════════════════

--[[ Run a whole command line. Always returns immediately; the work happens on
     its own thread so a command that yields cannot block the caller (chat
     handler, keybind, UI button). ]]
function M.run(line, speaker, opts)
	opts = opts or {}
	if type(line) ~= "string" or Str.trim(line) == "" then return end

	local invocations = Parser.parse(line)
	if #invocations == 0 then return end

	local History = IY.import("cmd/history")
	if opts.record ~= false then History.push(line) end

	task.spawn(function()
		for i = 1, #invocations do
			local invocation = invocations[i]

			-- `!name` replays the last line that used that command.
			if invocation.recall then
				local previous = lastByName[Str.lower(invocation.recall)]
				if previous then
					local replayed = Parser.parseSegment(previous)
					if replayed then
						replayed.repeats = invocation.repeats
						replayed.delay = invocation.delay
						replayed.infinite = invocation.infinite
						invocation = replayed
					end
				end
			end

			lastByName[Str.lower(invocation.name)] = invocation.raw
			M.execute(invocation, speaker, opts)
		end
	end)
end

--[[ Run a command line on the current thread and return whether it succeeded.
     Used by features that compose commands (`fling` toggling noclip) and by
     the test suite, where deterministic ordering matters. ]]
function M.runSync(line, speaker, opts)
	opts = opts or {}
	opts.record = false
	local invocations = Parser.parse(line)
	local allOk = true
	for i = 1, #invocations do
		local ok = M.execute(invocations[i], speaker, opts)
		allOk = allOk and ok
	end
	return allOk
end

--[[ Handle a raw chat / textbox string: strips the prefix, ignores anything
     that is not a command. ]]
function M.handleInput(text, speaker)
	local Store = IY.import("core/store")
	local prefix = Store.get("prefix") or ";"
	local stripped = Parser.stripPrefix(string.gsub(tostring(text), "^/e ", ""), prefix)
	if not stripped then return false end
	M.run(stripped, speaker)
	return true
end

function M.stats()
	local activeList = {}
	for name, value in pairs(active) do
		if value then activeList[#activeList + 1] = name end
	end
	table.sort(activeList)
	return {
		commands = Registry.count(),
		active   = activeList,
		running  = running,
	}
end

return M
