--[[ parser: the command-line grammar, which every other layer depends on. ]]

local ctx = ...
local expect, IY = ctx.expect, ctx.IY
local Parser = IY.import("cmd/parser")

-- ── prefix ──────────────────────────────────────────────────────────────────
expect.equal(Parser.stripPrefix(";fly", ";"), "fly", "prefix stripped")
expect.equal(Parser.stripPrefix("fly", ";"), nil, "non-command rejected")
expect.equal(Parser.stripPrefix("!!fly", "!!"), "fly", "multi-character prefix")

-- ── separators ──────────────────────────────────────────────────────────────
local segments = Parser.splitCommands("fly\\speed 100")
expect.count(segments, 2, "backslash splits commands")
expect.equal(segments[1], "fly", "first segment")
expect.equal(segments[2], "speed 100", "second segment")

local escaped = Parser.splitCommands("chat hello \\\\ world")
expect.count(escaped, 1, "escaped backslash does not split")
expect.contains(escaped[1], "\\", "escaped backslash survives")

-- ── modifiers ───────────────────────────────────────────────────────────────
local text, repeats, delay, infinite = Parser.parseModifiers("5^jump")
expect.equal(text, "jump", "repeat count stripped")
expect.equal(repeats, 5, "repeat count parsed")
expect.equal(delay, 0, "no delay")
expect.notOk(infinite, "not infinite")

text, repeats, delay = Parser.parseModifiers("5^0.5^jump")
expect.equal(text, "jump", "count and delay stripped")
expect.equal(repeats, 5, "count with delay")
expect.near(delay, 0.5, 1e-9, "delay parsed")

text, repeats, delay, infinite = Parser.parseModifiers("inf^jump")
expect.equal(text, "jump", "inf stripped")
expect.ok(infinite, "infinite flagged")
expect.equal(delay, 1, "infinite defaults to a one second delay")

text, _, delay, infinite = Parser.parseModifiers("inf^0.25^jump")
expect.equal(text, "jump", "inf with delay stripped")
expect.ok(infinite, "infinite flagged with delay")
expect.near(delay, 0.25, 1e-9, "infinite delay parsed")

-- A zero delay on an infinite loop would spin the client; the parser floors it.
text, _, delay = Parser.parseModifiers("inf^0^jump")
expect.equal(delay, 1, "zero infinite delay is floored to 1")

-- ── tokens and quoting ─────────────────────────────────────────────────────
local tokens = Parser.tokenise('speed all 100')
expect.count(tokens, 3, "three tokens")
expect.equal(tokens[2].value, "all", "second token")

tokens = Parser.tokenise('alias "big jump" jpower 500')
expect.count(tokens, 4, "quoted token counts once")
expect.equal(tokens[2].value, "big jump", "quotes group words")

tokens = Parser.tokenise("chat 'single quoted'")
expect.equal(tokens[2].value, "single quoted", "single quotes work too")

tokens = Parser.tokenise('chat "unterminated')
expect.equal(tokens[2].value, "unterminated", "unterminated quote takes the rest")

-- ── invocations ─────────────────────────────────────────────────────────────
local invocation = Parser.parseSegment("speed all 100")
expect.equal(invocation.name, "speed", "command name")
expect.count(invocation.args, 2, "two arguments")
expect.equal(invocation.args[1], "all", "first argument")

expect.equal(Parser.remainder(invocation, 2), "100", "remainder from the second argument")
local greedy = Parser.parseSegment("chat hello there   friend")
expect.equal(Parser.remainder(greedy, 1), "hello there   friend",
	"greedy remainder keeps original spacing")

local recall = Parser.parseSegment("!goto")
expect.equal(recall.recall, "goto", "recall target parsed")

local all = Parser.parse("fly\\3^0.2^jump\\chat hi")
expect.count(all, 3, "three invocations from one line")
expect.equal(all[2].repeats, 3, "modifiers survive the split")
expect.equal(all[3].name, "chat", "third invocation")

expect.count(Parser.parse(""), 0, "empty line parses to nothing")
expect.count(Parser.parse("   "), 0, "whitespace parses to nothing")

-- ── completion context ─────────────────────────────────────────────────────
local completion = Parser.completionContext("fl")
expect.equal(completion.argIndex, 0, "typing the command name")
expect.equal(completion.partial, "fl", "partial command name")

completion = Parser.completionContext("speed ")
expect.equal(completion.argIndex, 1, "trailing space moves to the first argument")
expect.equal(completion.partial, "", "no partial yet")

completion = Parser.completionContext("speed al")
expect.equal(completion.argIndex, 1, "typing the first argument")
expect.equal(completion.partial, "al", "partial argument")

completion = Parser.completionContext("speed all 1")
expect.equal(completion.argIndex, 2, "typing the second argument")
expect.equal(completion.partial, "1", "partial second argument")

completion = Parser.completionContext("fly\\spe")
expect.equal(completion.name, "spe", "completion applies to the last segment")
