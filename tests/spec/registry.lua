--[[ registry: the command set is complete, consistent and self-describing.
     This spec is the guard rail on 400+ hand-ported commands. ]]

local ctx = ...
local expect, IY = ctx.expect, ctx.IY
local Registry = IY.import("cmd/registry")
local Types = IY.import("cmd/types")

local all = Registry.all(true)
expect.ok(#all >= 400, "at least 400 commands registered (got " .. tostring(#all) .. ")")

-- ── no collisions ───────────────────────────────────────────────────────────
local seenName, seenAlias = {}, {}
local nameCollisions, aliasCollisions = 0, 0
for i = 1, #all do
	local definition = all[i]
	if seenName[definition.name] then
		nameCollisions = nameCollisions + 1
		expect.ok(false, "duplicate command name: " .. definition.name)
	end
	seenName[definition.name] = definition
	for a = 1, #definition.aliases do
		local alias = definition.aliases[a]
		if seenAlias[alias] or seenName[alias] then
			aliasCollisions = aliasCollisions + 1
			expect.ok(false, "alias '" .. alias .. "' on '" .. definition.name
				.. "' collides with " .. tostring(seenAlias[alias] and seenAlias[alias].name
					or (seenName[alias] and seenName[alias].name)))
		end
		seenAlias[alias] = definition
	end
end
expect.equal(nameCollisions, 0, "no duplicate names")
expect.equal(aliasCollisions, 0, "no colliding aliases")

-- Aliases must not shadow a command name either.
for alias, owner in pairs(seenAlias) do
	if seenName[alias] and seenName[alias] ~= owner then
		expect.ok(false, "alias '" .. alias .. "' shadows the command of the same name")
	end
end

-- ── metadata completeness ───────────────────────────────────────────────────
local missingDescription, badCategory = {}, {}
for i = 1, #all do
	local definition = all[i]
	if not definition.generated and (definition.description == nil or definition.description == "") then
		missingDescription[#missingDescription + 1] = definition.name
	end
	if definition.category == nil or definition.category == "" then
		badCategory[#badCategory + 1] = definition.name
	end
end
expect.equal(#missingDescription, 0, "every authored command has a description"
	.. (#missingDescription > 0 and (": " .. table.concat(missingDescription, ", ", 1,
		math.min(12, #missingDescription))) or ""))
expect.equal(#badCategory, 0, "every command has a category")

-- ── argument specs are valid ────────────────────────────────────────────────
local argProblems = {}
for i = 1, #all do
	local definition = all[i]
	local seenOptional = false
	for a = 1, #definition.args do
		local spec = definition.args[a]
		if not Types.exists(spec.type) then
			argProblems[#argProblems + 1] = definition.name .. ": unknown type " .. tostring(spec.type)
		end
		if spec.optional then
			seenOptional = true
		elseif seenOptional then
			argProblems[#argProblems + 1] = definition.name .. ": required arg after optional"
		end
		if spec.greedy and a ~= #definition.args then
			argProblems[#argProblems + 1] = definition.name .. ": greedy arg is not last"
		end
		if spec.name == nil or spec.name == "" then
			argProblems[#argProblems + 1] = definition.name .. ": unnamed argument"
		end
	end
end
for i = 1, math.min(#argProblems, 20) do
	expect.ok(false, "argument spec: " .. argProblems[i])
end
expect.equal(#argProblems, 0, "all argument specs are well formed")

-- ── derived text ────────────────────────────────────────────────────────────
for i = 1, #all do
	local definition = all[i]
	if definition.usage == nil or definition.usage == "" then
		expect.ok(false, definition.name .. " has no usage string")
	end
	if definition.signature == nil or definition.signature == "" then
		expect.ok(false, definition.name .. " has no signature")
	end
end
expect.ok(true, "usage and signature generated for every command")

local speed = Registry.find("speed")
if speed then
	expect.contains(speed.usage, "speed", "usage starts with the command name")
	expect.contains(Registry.listText(speed), "speed", "list text includes the name")
end

-- ── lookup ──────────────────────────────────────────────────────────────────
expect.ok(Registry.find("fly") ~= nil, "fly exists")
expect.ok(Registry.find("FLY") ~= nil, "lookup is case-insensitive")
expect.ok(Registry.find("unfly") ~= nil, "generated off command exists")
expect.ok(Registry.find("nofly") ~= nil, "generated off alias exists")
expect.ok(Registry.find("togglefly") ~= nil, "generated toggle exists")
expect.ok(Registry.find("clip") ~= nil, "explicit off alias kept (clip)")
expect.equal(Registry.find("definitelynotacommand"), nil, "unknown lookup returns nil")

-- ── generated siblings are consistent ───────────────────────────────────────
local generated, orphans = 0, 0
for i = 1, #all do
	local definition = all[i]
	if definition.generated then
		generated = generated + 1
		if not seenName[definition.generatedFrom] then
			orphans = orphans + 1
			expect.ok(false, definition.name .. " was generated from a command that no longer exists")
		end
	end
end
expect.ok(generated >= 20, "off/toggle generation is being used (" .. tostring(generated) .. " commands)")
expect.equal(orphans, 0, "no orphaned generated commands")

-- ── suggestions ─────────────────────────────────────────────────────────────
local suggestions = Registry.suggest("fl", 10)
expect.ok(#suggestions >= 1, "suggest returns matches for a prefix")
expect.equal(Registry.closest("fyl"), "fly", "closest match fixes a transposition")
expect.equal(Registry.closest("qqqqqqqq"), nil, "closest gives up on nonsense")

-- ── categories ──────────────────────────────────────────────────────────────
local categories = Registry.categories()
expect.ok(#categories >= 5, "commands are spread across categories")
local counted = 0
for i = 1, #categories do
	counted = counted + #Registry.byCategory(categories[i])
end
expect.ok(counted > 0, "byCategory returns commands")

-- ── audit ───────────────────────────────────────────────────────────────────
local issues = Registry.audit()
for i = 1, math.min(#issues, 15) do
	expect.ok(false, "audit: " .. tostring(issues[i].kind) .. " on " .. tostring(issues[i].name))
end
expect.equal(#issues, 0, "registry audit is clean")

-- ── export shape (used to generate docs) ────────────────────────────────────
local exported = Registry.export()
expect.equal(#exported, #all, "export covers every command")
expect.isType(exported[1].name, "string", "export entries have names")
expect.isType(exported[1].args, "table", "export entries have argument tables")
