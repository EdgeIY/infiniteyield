--[[═══════════════════════════════════════════════════════════════════════════
	features/tools · tool and accessory primitives
	─────────────────────────────────────────────────────────────────────────
	Everything ;tools, ;notools, ;equiptools, ;droptools, ;usetools, ;btools,
	;grippos, ;drophats and ;dupetools actually do. The command pack only
	declares arguments and reports counts.

	Legacy equivalent: source.ref.lua 10511-10552, 11364-11448, 11591-11640,
	11706-11732 and 8845-8852. Nearly every one of those bodies opened with
	`speaker:FindFirstChildOfClass("Backpack"):GetChildren()` or
	`speaker.Character:FindFirstChildOfClass('Humanoid'):GetAccessories()`, so a
	player with no backpack, no character or no humanoid got a thrown error that
	the dispatcher swallowed -- most of the "the command does nothing" reports.

	`dupetools` is the only real state here: a multi-second procedure that
	destroys and respawns your character, so it is a Feature. One run at a time,
	and ;unloadiy cancels it instead of leaving you anchored at y = 200000.
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Feature   = IY.import("features/feature")
local Character = IY.import("core/character")
local Sched     = IY.import("core/scheduler")
local Guard     = IY.import("core/guard")
local Env       = IY.import("core/env")
local Notify    = IY.import("core/notify")
local Services  = IY.import("core/services")
local Inst      = IY.import("core/util/instances")
local Str       = IY.import("core/util/strings")

local Workspace = Services.Workspace

local M = {}

-- ── inventory ───────────────────────────────────────────────────────────────

--[[ The Backpack, or nil. Legacy indexed the result of this straight. ]]
local function backpackOf(player)
	if not player then return nil end
	local ok, backpack = pcall(function() return player:FindFirstChildOfClass("Backpack") end)
	if ok then return backpack end
	return nil
end
M.backpack = backpackOf

--[[ Every Tool / HopperBin with a Handle -- legacy GetHandleTools (11380-11394),
     which read `p.Backpack` directly and so threw for anybody without one. ]]
function M.withHandle(player)
	local out = {}
	local tools = Inst.tools(player)
	for i = 1, #tools do
		if tools[i]:FindFirstChild("Handle") then out[#out + 1] = tools[i] end
	end
	return out
end

-- ── copying and clearing ────────────────────────────────────────────────────

--[[ Clone every BackpackItem under `container` into `into`. `;tools` runs this
     over Lighting and ReplicatedStorage, the two places games habitually leave
     their gear. ]]
function M.copyFrom(container, into)
	if not container or not into then return 0 end
	local ok, descendants = pcall(function() return container:GetDescendants() end)
	if not ok then return 0 end
	local copied = 0
	for i = 1, #descendants do
		local item = descendants[i]
		if item:IsA("BackpackItem") then
			-- Clone returns nil for a non-Archivable instance, and legacy then
			-- assigned `.Parent` on that nil.
			local clone = Guard.try(function() return item:Clone() end)
			if clone and pcall(function() clone.Parent = into end) then
				copied = copied + 1
			end
		end
	end
	return copied
end

--[[ Destroy every tool a player owns. ]]
function M.destroy(player)
	local tools = Inst.tools(player)
	local removed = 0
	for i = 1, #tools do
		if pcall(function() tools[i]:Destroy() end) then removed = removed + 1 end
	end
	return removed
end

--[[ Destroy only what is in the character -- the equipped tool(s). ]]
function M.destroyEquipped(player)
	local character = player and player.Character
	if not character then return 0 end
	local removed = 0
	local held = Inst.ofClass(character, "BackpackItem")
	for i = 1, #held do
		if pcall(function() held[i]:Destroy() end) then removed = removed + 1 end
	end
	return removed
end

-- ── equipping and dropping ──────────────────────────────────────────────────

--[[ Move everything into the character, which is what "equipped" means for a
     Tool. ]]
function M.equipAll(player)
	local character = player and player.Character
	if not character then Guard.fail("you have no character right now") end
	local tools = Inst.tools(player)
	local equipped = 0
	for i = 1, #tools do
		if pcall(function() tools[i].Parent = character end) then equipped = equipped + 1 end
	end
	return equipped
end

function M.unequipAll(player)
	local humanoid = Inst.humanoid(player and player.Character)
	if not humanoid then Guard.fail("you have no humanoid right now") end
	return pcall(function() humanoid:UnequipTools() end)
end

--[[ Drop everything. A tool only becomes a world model once it has been in the
     character, which is what the legacy bare `wait()` in the middle was for.
     Legacy also read `Players.LocalPlayer.Backpack` instead of the speaker's,
     so a plugin calling `;droptools` for somebody else dropped your own. ]]
function M.drop(player)
	local character = player and player.Character
	if not character then Guard.fail("you have no character right now") end
	local tools = Inst.tools(player)
	if #tools == 0 then return 0 end
	for i = 1, #tools do pcall(function() tools[i].Parent = character end) end
	task.wait()
	local dropped = 0
	for i = 1, #tools do
		if pcall(function() tools[i].Parent = Workspace end) then dropped = dropped + 1 end
	end
	return dropped
end

--[[ CanBeDropped on everything, so the backspace key works on gear the game
     locked down. ]]
function M.droppable(player)
	local tools = Inst.tools(player)
	local changed = 0
	for i = 1, #tools do
		if pcall(function() tools[i].CanBeDropped = true end) then changed = changed + 1 end
	end
	return changed
end

--[[ Activate every tool `amount` times, `pause` seconds apart, then put each
     one back where it came from. Legacy spawned a thread per tool and returned
     all of them to the Backpack afterwards regardless of where they started;
     one contained thread does the same work and cannot outlive an error. ]]
function M.use(player, amount, pause)
	local character = player and player.Character
	if not character then Guard.fail("you have no character right now") end
	local tools = Inst.tools(player)
	if #tools == 0 then Guard.fail("you have no tools to use") end

	local home = {}
	for i = 1, #tools do
		home[i] = tools[i].Parent
		pcall(function() tools[i].Parent = character end)
	end

	Sched.spawn("tools.use", function()
		for _ = 1, amount do
			for i = 1, #tools do
				pcall(function() tools[i]:Activate() end)
			end
			if pause and pause > 0 then task.wait(pause) end
		end
		for i = 1, #tools do
			local tool, parent = tools[i], home[i]
			-- Never write a nil parent: that would take the tool out of the game
			-- rather than putting it back.
			if parent then pcall(function() tool.Parent = parent end) end
		end
	end)
	return #tools
end

-- ── grip ────────────────────────────────────────────────────────────────────

--[[ GripPos only takes effect when a tool is re-equipped, hence the round trip
     through the Backpack (legacy 11706-11714). Written as a plain property and
     not a Snapshot record: it is a deliberate lasting adjustment, and `;unreach`
     must not silently undo it. ]]
function M.setGrip(player, position)
	local character = player and player.Character
	if not character then Guard.fail("you have no character right now") end
	local backpack = backpackOf(player)
	local tools = Inst.ofClass(character, "Tool")
	if #tools == 0 then Guard.fail("equip a tool first") end
	local changed = 0
	for i = 1, #tools do
		local tool = tools[i]
		local ok = pcall(function()
			if backpack then tool.Parent = backpack end
			tool.GripPos = position
			tool.Parent = character
		end)
		if ok then changed = changed + 1 end
	end
	return changed
end

-- ── building tools ──────────────────────────────────────────────────────────

--[[ The four HopperBin build tools (legacy 8845-8852). HopperBin has been
     deprecated for years and some clients refuse `Instance.new` for it, so each
     bin is attempted on its own and the caller reports how many landed.
     Deliberately not bin-owned: the Backpack is the owner, and the whole point
     is that the tools stay behind after IY unloads. ]]
function M.buildTools(player)
	local into = backpackOf(player)
	if not into then Guard.fail("you have no backpack right now") end
	local made = 0
	for binType = 1, 4 do
		local ok = pcall(function()
			local tool = Instance.new("HopperBin")
			tool.BinType = binType
			tool.Name = Str.random(10)
			tool.Parent = into
		end)
		if ok then made = made + 1 end
	end
	if made == 0 then
		Guard.fail("this client no longer supports HopperBin build tools")
	end
	return made
end

-- ── accessories ─────────────────────────────────────────────────────────────

--[[ Hats and accessories on a character. GetAccessories needs a live Humanoid,
     which is precisely what the legacy
     `:FindFirstChildOfClass('Humanoid'):GetAccessories()` chain assumed; the
     class sweep is the fallback. ]]
function M.accessories(character)
	if not character then return {} end
	local humanoid = Inst.humanoid(character)
	if humanoid then
		local ok, list = pcall(function() return humanoid:GetAccessories() end)
		if ok and type(list) == "table" and #list > 0 then return list end
	end
	return Inst.ofClass(character, "Accoutrement", true)
end

--[[ Re-parent every accessory into the workspace so it drops (legacy 11591). ]]
function M.dropHats(character)
	local list = M.accessories(character)
	local dropped = 0
	for i = 1, #list do
		if pcall(function() list[i].Parent = Workspace end) then dropped = dropped + 1 end
	end
	return dropped
end

--[[ `deletehats` never deleted anything: it destroys the Weld inside each
     accessory so the hat falls off (legacy 11599-11609). Kept as it was, with
     the descendant walk guarded -- an accessory that is still streaming in has
     no Handle and no Weld yet. ]]
function M.unweldHats(character)
	local list = M.accessories(character)
	local broken = 0
	for i = 1, #list do
		local ok, descendants = pcall(function() return list[i]:GetDescendants() end)
		if ok then
			for j = 1, #descendants do
				local part = descendants[j]
				if part:IsA("Weld") and pcall(function() part:Destroy() end) then
					broken = broken + 1
				end
			end
		end
	end
	return broken
end

-- ── dupetools ───────────────────────────────────────────────────────────────

local RESPAWN_TIMEOUT = 10
local PARK_RANGE = 2e5

--[[ Hand the dropped handles back. With firetouchinterest we can fake the
     pickup outright; without it the handles are dragged through the root part
     for ten frames and the engine's own Touched does the work. ]]
local function pickUp(self, handles, root)
	local fire = Env.fn.firetouchinterest
	for i = 1, #handles do
		local handle = handles[i]
		if fire then
			Guard.call("dupetools.touch", function()
				fire(handle, root, 0)
				fire(handle, root, 1)
				handle.Anchored = false
			end)
		else
			self.bin:spawn(function()
				Guard.call("dupetools.drag", function()
					local collide = handle.CanCollide
					handle.CanCollide = false
					handle.Anchored = false
					for _ = 1, 10 do
						handle.CFrame = root.CFrame
						task.wait()
					end
					handle.CanCollide = collide
				end)
			end)
		end
	end
end

--[[ Legacy 11395-11447, step for step.

     Park the character where nobody else is, anchor it, flick every handled
     tool between the character and the workspace so the server keeps
     replicating the copy while the client lets go of the handle, then destroy
     the character. The handles stay in the world, and the fresh character walks
     back and collects them -- on the last round, and every fifth one so a long
     run does not accumulate thousands of parts.

     Each step is its own Guard.call. Legacy chained its side effects through
     argument lists (`wait(.1, Human.Parent:MoveTo(TempPos))`,
     `speaker:ClearCharacterAppearance(wait(.1)) or true`), so a game that
     rejects any single one of them left you anchored at y = 200000 with no
     tools and no way back. The flick loop is also bounded: legacy looped
     `while #t > 0`, which never ends in a game that hands the tool back. ]]
local function dupeRun(self, opts)
	local player = Character.player
	local loops = math.max(1, math.floor(opts.loops or 1))
	local origin = Character.requireRoot().Position
	local park = Vector3.new(math.random(-PARK_RANGE, PARK_RANGE), PARK_RANGE,
		math.random(-PARK_RANGE, PARK_RANGE))
	local handles, duped, rounds = {}, 0, 0

	for round = 1, loops do
		local character = Character.get()
		if not character then break end

		Guard.call("dupetools.park", function() character:MoveTo(park) end)
		task.wait(0.1)
		Guard.call("dupetools.appearance", function() player:ClearCharacterAppearance() end)
		task.wait(0.1)
		local root = Inst.root(character)
		if root then Guard.call("dupetools.anchor", function() root.Anchored = true end) end

		local pending = M.withHandle(player)
		local sweeps = 0
		while #pending > 0 and sweeps < 8 do
			sweeps = sweeps + 1
			for i = 1, #pending do
				local tool = pending[i]
				Guard.call("dupetools.flick", function()
					local handle = tool:FindFirstChild("Handle")
					if not handle then return end
					for _ = 1, 25 do
						tool.Parent = character
						handle.Anchored = true
					end
					for _ = 1, 5 do
						tool.Parent = Workspace
					end
					handles[#handles + 1] = handle
					duped = duped + 1
				end)
			end
			pending = M.withHandle(player)
		end
		task.wait(0.1)

		-- `Player.Character` keeps pointing at the destroyed model until the
		-- server hands over a new one, so waiting for "a rooted character" would
		-- match the corpse immediately.
		Guard.call("dupetools.destroy", function() character:Destroy() end)
		local arrived, fresh = Sched.waitUntil(function()
			local candidate = Character.get()
			if candidate and candidate ~= character and Inst.root(candidate) then
				return candidate
			end
			return nil
		end, RESPAWN_TIMEOUT)
		if not arrived then
			self.log.warn("your character did not come back -- stopped at round %d", rounds)
			break
		end
		rounds = round

		Guard.call("dupetools.return", function()
			fresh:MoveTo(round == loops and origin or park)
		end)
		task.wait(0.1)

		if round == loops or round % 5 == 0 then
			local hrp = Inst.root(Character.get())
			if hrp then pickUp(self, handles, hrp) end
			task.wait(0.1)
			handles = {}
		end
		park = park + Vector3.new(10, math.random(-5, 5), 0)
	end

	Notify.send("dupetools",
		string.format("Dropped %d tool(s) over %d round(s)", duped, rounds))
	return duped
end

local dupe = Feature.new("dupetools", {
	describe = "duplicating tools",
	-- A second ;dupetools mid-run must not restart the procedure: the first one
	-- still owns your character.
	ignoreRestart = true,

	start = function(self, opts)
		self.bin:spawn(function()
			local ok, err = Guard.call("dupetools", dupeRun, self, opts)
			if not ok then Notify.error("dupetools", Guard.describe(err)) end
			-- Deferred: stopping empties the bin this thread lives in.
			task.defer(function() self:stop() end)
		end)
	end,
})

M.dupe = dupe

--[[ Start a run. Returns false when one is already in flight. ]]
function M.startDupe(loops)
	return dupe:start({ loops = loops or 1 })
end

function M.dupeRunning()
	return dupe:isRunning()
end

return M
