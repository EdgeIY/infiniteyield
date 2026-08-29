--[[ coverage: every command name and alias that existed in 6.4.2 still resolves.

     This is the completeness check on the port. The list in
     tests/support/legacy-commands.lua was extracted mechanically from the
     original 13,412-line source, so it cannot flatter the rewrite: 430 commands
     and 816 total names/aliases. Anything a user typed before must still work,
     even if it now reaches a different implementation. ]]

local ctx = ...
local expect, IY, root = ctx.expect, ctx.IY, ctx.root
local Registry = IY.import("cmd/registry")
local Aliases = IY.import("cmd/aliases")

local legacy = dofile((root or ".") .. "/tests/support/legacy-commands.lua")

local function resolves(name)
	if Registry.find(name) then return true end
	if Aliases.resolve(name) then return true end
	return false
end

local missingCommands, missingAliases = {}, {}
local totalNames, resolved = 0, 0

for i = 1, #legacy do
	local group = legacy[i]
	local canonical = group[1]
	for n = 1, #group do
		totalNames = totalNames + 1
		if resolves(group[n]) then
			resolved = resolved + 1
		elseif n == 1 then
			missingCommands[#missingCommands + 1] = canonical
		else
			missingAliases[#missingAliases + 1] = canonical .. " -> " .. group[n]
		end
	end
end

io.write(string.format("    coverage: %d/%d legacy names resolve (%d commands, %d aliases missing)\n",
	resolved, totalNames, #missingCommands, #missingAliases))

for i = 1, math.min(#missingCommands, 40) do
	expect.ok(false, "legacy command no longer exists: ;" .. missingCommands[i])
end
expect.equal(#missingCommands, 0, "every 6.4.2 command name still resolves")

for i = 1, math.min(#missingAliases, 40) do
	expect.ok(false, "legacy alias no longer exists: " .. missingAliases[i])
end
expect.equal(#missingAliases, 0, "every 6.4.2 alias still resolves")

-- The rewrite should also be a superset: generated off/toggle siblings and the
-- handful of new commands mean the count goes up, not down.
expect.ok(Registry.count() >= 430,
	"the command set did not shrink (" .. tostring(Registry.count()) .. " registered)")
