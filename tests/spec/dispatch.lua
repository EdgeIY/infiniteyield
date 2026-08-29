--[[ dispatch: the execution pipeline end to end, including the failure paths
     that the legacy dispatcher swallowed. ]]

local ctx = ...
local expect, IY, env = ctx.expect, ctx.IY, ctx.env
local Dispatch = IY.import("cmd/dispatch")
local Registry = IY.import("cmd/registry")
local Cmd = IY.import("cmd/api")
local Notify = IY.import("core/notify")
local History = IY.import("cmd/history")
local Aliases = IY.import("cmd/aliases")

-- Capture notifications so we can assert on what the user was told.
local messages = {}
local sink = Notify.sent:Connect(function(entry)
	messages[#messages + 1] = entry
end)
local function lastMessage()
	return messages[#messages]
end
local function clearMessages()
	for i = #messages, 1, -1 do messages[i] = nil end
end

-- ── test commands ───────────────────────────────────────────────────────────
local calls = { plain = 0, args = {}, iterations = 0, offCount = 0, onCount = 0 }

Cmd.register({
	name = "spectest",
	category = "Test",
	description = "Records that it ran.",
	hidden = true,
	run = function() calls.plain = calls.plain + 1 end,
}, "test")

Cmd.register({
	name = "spectestargs",
	category = "Test",
	description = "Records its arguments.",
	hidden = true,
	args = {
		{ name = "players", type = "players" },
		{ name = "amount", type = "number", default = 7, min = 0, max = 100 },
		{ name = "message", type = "text", optional = true },
	},
	run = function(c)
		calls.args = { players = c.args.players, amount = c.args.amount, message = c.args.message }
	end,
}, "test")

Cmd.register({
	name = "spectestloop",
	category = "Test",
	description = "Counts iterations.",
	hidden = true,
	run = function() calls.iterations = calls.iterations + 1 end,
}, "test")

Cmd.register({
	name = "spectesttoggle",
	category = "Test",
	description = "A toggleable test command.",
	hidden = true,
	run = function() calls.onCount = calls.onCount + 1 end,
	off = function() calls.offCount = calls.offCount + 1 end,
}, "test")

Cmd.register({
	name = "spectestfail",
	category = "Test",
	description = "Always raises an internal error.",
	hidden = true,
	run = function() local x = nil return x.y end,
}, "test")

Cmd.register({
	name = "spectestuserfail",
	category = "Test",
	description = "Always raises a user error.",
	hidden = true,
	run = function(c) c:fail("you cannot do that here") end,
}, "test")

Cmd.register({
	name = "spectestneeds",
	category = "Test",
	description = "Needs a capability nothing provides.",
	hidden = true,
	requires = { capability = "definitelynotacapability" },
	run = function() calls.plain = calls.plain + 1 end,
}, "test")

-- ── basic execution ─────────────────────────────────────────────────────────
Dispatch.runSync("spectest")
expect.equal(calls.plain, 1, "a command runs")

Dispatch.runSync("SPECTEST")
expect.equal(calls.plain, 2, "command names are case-insensitive")

-- ── argument handling ───────────────────────────────────────────────────────
Dispatch.runSync("spectestargs")
expect.isType(calls.args.players, "table", "an optional players argument defaults to a target list")
expect.count(calls.args.players, 1, "the default players argument is you")
expect.equal(calls.args.amount, 7, "a numeric default is applied")
expect.equal(calls.args.message, nil, "an optional argument with no default stays nil")

Dispatch.runSync("spectestargs all 42 hello there")
expect.ok(#calls.args.players >= 4, "players argument resolved")
expect.equal(calls.args.amount, 42, "number parsed from the line")
expect.equal(calls.args.message, "hello there", "greedy text captured the remainder")

clearMessages()
Dispatch.runSync("spectestargs me notanumber")
expect.ok(lastMessage() ~= nil, "a bad argument notifies the user")
expect.contains(lastMessage().text, "not a number", "the message says what was wrong")
expect.contains(lastMessage().text, "usage", "the message includes the usage line")

clearMessages()
Dispatch.runSync("spectestargs me 500")
expect.contains(lastMessage().text, "at most", "an out-of-range number reports the bound")

-- ── repeats and delays ──────────────────────────────────────────────────────
calls.iterations = 0
Dispatch.runSync("3^spectestloop")
expect.equal(calls.iterations, 3, "repeat count honoured")

calls.iterations = 0
Dispatch.runSync("spectestloop\\spectestloop")
expect.equal(calls.iterations, 2, "backslash runs both commands")

-- ── error reporting ─────────────────────────────────────────────────────────
clearMessages()
Dispatch.runSync("spectestfail")
expect.ok(lastMessage() ~= nil, "an internal error is reported, not swallowed")
expect.contains(lastMessage().text, "error", "the message is marked as an error")
expect.equal(lastMessage().level, "error", "the notification is at error level")

clearMessages()
Dispatch.runSync("spectestuserfail")
expect.ok(lastMessage() ~= nil, "a user error is reported")
expect.contains(lastMessage().text, "cannot do that", "the user's message is shown verbatim")
expect.notEqual(lastMessage().level, "error", "a user error is not logged as a crash")

clearMessages()
Dispatch.runSync("spectestneeds")
expect.ok(lastMessage() ~= nil, "a missing capability is reported")
expect.contains(lastMessage().text, "does not support", "the message names the limitation")

-- A repeated failing command must not spam: it stops after the first failure.
clearMessages()
Dispatch.runSync("5^spectestfail")
expect.count(messages, 1, "a repeated failing command reports once, not five times")

-- ── unknown commands ────────────────────────────────────────────────────────
clearMessages()
Dispatch.runSync("spectst")
expect.ok(lastMessage() ~= nil, "an unknown command is reported")
expect.contains(lastMessage().text, "did you mean", "a close match is suggested")

clearMessages()
Dispatch.runSync("zzzzqqqqwwww")
expect.contains(lastMessage().title, "Unknown", "an unrecognisable command still reports")

-- ── toggles ─────────────────────────────────────────────────────────────────
expect.ok(Registry.find("unspectesttoggle") ~= nil, "un<name> was generated")
expect.ok(Registry.find("togglespectesttoggle") ~= nil, "toggle<name> was generated")

Dispatch.runSync("spectesttoggle")
expect.ok(Dispatch.isActive("spectesttoggle"), "running marks the command active")
Dispatch.runSync("togglespectesttoggle")
expect.equal(calls.offCount, 1, "toggle turned it off")
expect.notOk(Dispatch.isActive("spectesttoggle"), "state cleared after the off half")
Dispatch.runSync("togglespectesttoggle")
expect.equal(calls.onCount, 2, "toggle turned it back on")

-- ── history ─────────────────────────────────────────────────────────────────
History.clear()
Dispatch.run("spectest", nil, { record = true })
env.scheduler.drain(500)
expect.ok(#History.all() >= 1, "run records history")
expect.equal(History.previous(), "spectest", "history navigates backwards")

-- ── aliases ─────────────────────────────────────────────────────────────────
expect.succeeds(function() Aliases.set("spectestalias", "spectestargs me 11") end,
	"an alias to a real command is accepted")
calls.args = {}
Dispatch.runSync("spectestalias")
expect.equal(calls.args.amount, 11, "the alias expanded with its arguments")
calls.args = {}
Dispatch.runSync("spectestalias")
expect.equal(calls.args.amount, 11, "the alias is reusable")
expect.raises(function() Aliases.set("spectestbadalias", "nosuchcommand") end,
	"is not a command", "an alias to nothing is rejected")
expect.raises(function() Aliases.set("spectest", "spectestargs") end,
	"already a command", "an alias cannot shadow a command")
Aliases.remove("spectestalias")

-- ── prefix handling ─────────────────────────────────────────────────────────
local Store = IY.import("core/store")
Store.set("prefix", ";")
calls.plain = 0
expect.ok(Dispatch.handleInput(";spectest"), "a prefixed line is treated as a command")
env.scheduler.drain(500)
expect.equal(calls.plain, 1, "the prefixed command ran")
expect.notOk(Dispatch.handleInput("spectest"), "an unprefixed line is ignored")
expect.ok(Dispatch.handleInput("/e ;spectest"), "the /e prefix is stripped")
env.scheduler.drain(500)

-- ── breakloops ──────────────────────────────────────────────────────────────
calls.iterations = 0
Dispatch.breakLoops()
Dispatch.runSync("20^spectestloop")
expect.ok(calls.iterations <= 20, "breakloops does not prevent later commands")

-- ── cleanup ─────────────────────────────────────────────────────────────────
sink:Disconnect()
for _, name in ipairs({ "spectest", "spectestargs", "spectestloop", "spectesttoggle",
	"spectestfail", "spectestuserfail", "spectestneeds" }) do
	Registry.remove(name)
end
expect.equal(Registry.find("spectest"), nil, "test commands removed")
expect.equal(Registry.find("unspectesttoggle"), nil, "generated siblings removed with their parent")
