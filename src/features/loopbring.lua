--[[═══════════════════════════════════════════════════════════════════════════
	features/loopbring · keep dragging players to you
	─────────────────────────────────────────────────────────────────────────
	    Loopbring.add(targets, { distance = 3, delay = 0 })
	    Loopbring.remove(targets)

	Legacy equivalent: source.ref.lua 9224-9266. The old shape was one spawned
	thread *per target*, and each of those threads looped over the *whole*
	target list:

	    for i,v in pairs(players) do task.spawn(function()
	        repeat for i,c in pairs(players) do ... end until ...

	so `;loopbring all` in a twenty player server ran four hundred teleports a
	tick, twenty threads deep, and each one removed entries from `bringT` while
	another was iterating it. `;unloopbring` with no argument resolved to
	yourself -- and the speaker was never in `bringT` -- so it did nothing at
	all.

	Here there is one loop, it reads the live list each tick, and targets can be
	added or removed underneath it. The list is the feature's state, so
	`;unloadiy` and a respawn both leave nothing behind.
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Feature   = IY.import("features/feature")
local Character = IY.import("core/character")
local Guard     = IY.import("core/guard")
local Teleport  = IY.import("features/teleport")

local M = {}

local DEFAULT_DISTANCE = 3

local function entryList(self)
	self.state.entries = self.state.entries or {}
	return self.state.entries
end

local function indexOf(list, target)
	for i = 1, #list do
		if list[i].target.identityKey == target.identityKey then return i end
	end
	return nil
end

local feature = Feature.new("loopbring", {
	command  = "loopbring",
	reapply  = true,
	describe = "repeatedly bringing players",

	start = function(self, opts)
		self.state.entries = opts.entries or self.state.entries or {}

		self.bin:spawn(function()
			while true do
				local list = entryList(self)
				if #list == 0 then break end

				local myRoot = Character.root()
				-- Backwards so removing a departed player cannot skip the next.
				for index = #list, 1, -1 do
					local entry = list[index]
					if not entry.target:exists() then
						table.remove(list, index)
					elseif myRoot then
						local root = entry.target.root
						if root then
							root.CFrame = Teleport.beside(myRoot.CFrame, entry.distance)
						end
					end
				end

				task.wait(self:option("delay", 0) or 0)
			end
			-- Deferred: stopping empties the bin this thread lives in.
			task.defer(function() self:stop() end)
		end)
	end,
})

M.feature = feature

--[[ Start bringing `targets`, or add them to a run already in progress.
     Returns how many were newly added. ]]
function M.add(targets, opts)
	opts = opts or {}
	local distance = opts.distance or DEFAULT_DISTANCE

	local pending = {}
	for i = 1, #targets do
		-- Bringing yourself to yourself is a no-op; legacy skipped the speaker.
		if not targets[i].isLocal then pending[#pending + 1] = targets[i] end
	end
	if #pending == 0 then Guard.fail("pick somebody other than yourself") end

	if feature:isRunning() then
		local list = entryList(feature)
		local added = 0
		for i = 1, #pending do
			if not indexOf(list, pending[i]) then
				list[#list + 1] = { target = pending[i], distance = distance }
				added = added + 1
			end
		end
		if opts.delay then feature:configure({ delay = opts.delay }) end
		return added
	end

	-- Populate before starting: the loop thread runs its first tick inside
	-- start() and would stop itself over an empty list.
	local list = {}
	for i = 1, #pending do
		list[#list + 1] = { target = pending[i], distance = distance }
	end
	feature:start({ delay = opts.delay or 0, entries = list })
	return #list
end

--[[ Stop bringing `targets`; stops the loop entirely when none are left. ]]
function M.remove(targets)
	if not feature:isRunning() then return 0 end
	local list = entryList(feature)
	local removed = 0
	for i = 1, #targets do
		local index = indexOf(list, targets[i])
		if index then
			table.remove(list, index)
			removed = removed + 1
		end
	end
	if #list == 0 then feature:stop() end
	return removed
end

function M.stop() return feature:stop() end
function M.isRunning() return feature:isRunning() end

--[[ The players currently being brought, for `;unloopbring` reporting. ]]
function M.targets()
	if not feature:isRunning() then return {} end
	local out = {}
	local list = entryList(feature)
	for i = 1, #list do out[i] = list[i].target end
	return out
end

return M
