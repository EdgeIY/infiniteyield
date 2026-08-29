--[[═══════════════════════════════════════════════════════════════════════════
	core/character · one lifecycle for the local character
	─────────────────────────────────────────────────────────────────────────
	The legacy script had a single CharacterAdded handler (lines 5051-5069)
	with a hard-coded body: NOFLY(), clear `floating`, re-run `clip`, wait for
	the root, restore the spawn point, re-arm onDied(). Anything not on that
	list either opened its own duplicate CharacterAdded connection or simply
	broke on the first death. The analysis counted 13 that broke: cframefly
	kept CFraming a destroyed Head, mobile fly re-parented to a stale root,
	walltp's Touched connection died with the old torso, grabtools equipped
	onto a destroyed Humanoid, and so on. The handler also ran its work inline,
	so when NOFLY() threw, the spawn-point restore below it never ran.

	One hub instead:

	    Character.onSpawn(function(char) ... end)   -- returns a connection
	    Character.reapply("fly", reapplyFly)        -- named, replaces, contained
	    Character.died:Connect(function(char, cf) ... end)
	    Character.requireRoot()                    -- user-facing error

	`spawned` fires *after* the root part exists. CharacterAdded fires when
	Player.Character is assigned, which is before the rig is assembled -- that
	race is why so many legacy re-apply handlers only worked on a fast client.

	There is exactly one CharacterAdded and one CharacterRemoving connection
	for the session, and exactly one Humanoid.Died connection per character,
	all held in bins that are emptied (never appended to) on each respawn.
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Log      = IY.import("core/log")
local Guard    = IY.import("core/guard")
local Signal   = IY.import("core/signal")
local Bin      = IY.import("core/bin")
local Sched    = IY.import("core/scheduler")
local Services = IY.import("core/services")
local Inst     = IY.import("core/util/instances")
local Tables   = IY.import("core/util/tables")
local Snapshot = IY.import("core/snapshot")
local log = Log.scope("core/character")

local Players   = Services.Players
local Workspace = Services.Workspace

local ROOT_TIMEOUT  = 10   -- seconds to wait for a rig to assemble
local DEATH_TIMEOUT = 5    -- seconds to wait for a forced death to land

local M = {}

M.player   = Players.LocalPlayer
M.spawned  = Signal.new("character.spawned")
M.died     = Signal.new("character.died")
M.removing = Signal.new("character.removing")

M.lastDeath     = nil   -- CFrame of the last death; powers `flashback`
M.lastDeathTime = nil

local bin     = Bin.new("core/character")
local charBin = bin:branch("current")

local current       = nil   -- the character we are bound to
local spawnFiredFor = nil   -- the character `spawned` has already fired for
local refreshUntil  = nil   -- deadline of an in-flight refresh
local reapplyOrder  = {}    -- labels, in registration order
local reapplyFns    = {}    -- label -> function

local function now()
	if os and os.clock then return os.clock() end
	return 0
end

local function readField(object, key) return object[key] end
local function writeField(object, key, value) object[key] = value end
local function findByClass(object, className) return object:FindFirstChildOfClass(className) end

-- ── accessors (all nil-safe) ────────────────────────────────────────────────

function M.get()
	local player = M.player
	if not player then return nil end
	local ok, character = pcall(readField, player, "Character")
	if ok then return character end
	return nil
end

function M.root()     return Inst.root(M.get()) end
function M.humanoid() return Inst.humanoid(M.get()) end
function M.alive()    return Inst.alive(M.get()) end

function M.position()
	local root = M.root()
	if root then return root.Position end
	return nil
end

function M.cframe()
	local root = M.root()
	if root then return root.CFrame end
	return nil
end

function M.animator()
	local humanoid = M.humanoid()
	if not humanoid then return nil end
	local ok, animator = pcall(findByClass, humanoid, "Animator")
	if ok then return animator end
	return nil
end

-- ── requirements (raise a user-facing error) ────────────────────────────────

function M.require()
	local character = M.get()
	if not character then Guard.fail("you have no character right now") end
	return character
end

function M.requireRoot()
	local root = M.root()
	if not root then Guard.fail("you have no character right now") end
	return root
end

function M.requireHumanoid()
	local humanoid = M.humanoid()
	if not humanoid then Guard.fail("you have no humanoid right now") end
	return humanoid
end

local function rootedCharacter()
	local character = M.get()
	if character and Inst.root(character) then return character end
	return nil
end

--[[ Yield until a character with a root part exists. Returns immediately when
     one already does; nil on timeout. ]]
function M.wait(timeout)
	local existing = rootedCharacter()
	if existing then return existing end
	local ok, character = Sched.waitUntil(rootedCharacter, timeout or ROOT_TIMEOUT)
	if ok then return character end
	return nil
end

-- ── spawn subscriptions ─────────────────────────────────────────────────────

--[[ The mechanism every feature uses to survive a respawn, replacing 13
     bespoke CharacterAdded handlers. `opts.immediate` (default true) also runs
     fn now when a character is already up -- but only once `spawned` has fired
     for it, otherwise the pending fire would call fn a second time.

     Returns a connection, so a feature's Bin can hold it. ]]
function M.onSpawn(fn, opts)
	if type(fn) ~= "function" then
		error("[iy] Character.onSpawn needs a function, got " .. type(fn), 2)
	end
	local connection = M.spawned:Connect(fn)
	local immediate = true
	if opts and opts.immediate ~= nil then immediate = opts.immediate == true end
	if immediate and spawnFiredFor ~= nil and spawnFiredFor == M.get() then
		Guard.call("character.onSpawn", fn, spawnFiredFor)
	end
	return connection
end

--[[ A named re-application pass. Re-registering a label replaces it, so a
     command run twice cannot stack two passes. Registration does not apply
     anything now: the feature has just applied itself, and this is only about
     the next respawn. ]]
function M.reapply(label, fn)
	if type(label) ~= "string" then
		error("[iy] Character.reapply needs a label, got " .. type(label), 2)
	end
	if type(fn) ~= "function" then
		error("[iy] Character.reapply('" .. label .. "') needs a function", 2)
	end
	if reapplyFns[label] == nil then reapplyOrder[#reapplyOrder + 1] = label end
	reapplyFns[label] = fn
	return label
end

function M.cancelReapply(label)
	if reapplyFns[label] == nil then return false end
	reapplyFns[label] = nil
	Tables.removeValue(reapplyOrder, label)
	return true
end

--[[ Each pass is contained: the legacy handler ran its resets inline, so one
     error -- NOFLY() on a character with no root, most often -- skipped
     everything after it, including the spawn-point restore. ]]
local function runReapply(character)
	local labels = Tables.slice(reapplyOrder)
	for i = 1, #labels do
		local fn = reapplyFns[labels[i]]
		if fn then
			Guard.call("character.reapply:" .. labels[i], fn, character)
		end
	end
end

-- ── lifecycle ───────────────────────────────────────────────────────────────

local function waitForRoot(character)
	local deadline = now() + ROOT_TIMEOUT
	local root = Inst.root(character)
	while not root do
		if current ~= character then return nil end
		if now() >= deadline then return nil end
		task.wait()
		root = Inst.root(character)
	end
	return root
end

local function onDied(character)
	local root = Inst.root(character)
	local cframe = root and Guard.try(readField, root, "CFrame") or nil
	if cframe then
		M.lastDeath = cframe
		M.lastDeathTime = now()
	end
	M.died:Fire(character, cframe)
end

--[[ Bind to a new character. The per-character bin is emptied rather than added
     to, so the Died connection is replaced on every respawn instead of the
     legacy pattern where onDied() re-armed itself and stacked. ]]
local function bind(character)
	if character == nil then return end
	charBin:empty()
	current = character
	spawnFiredFor = nil
	charBin:spawn(function()
		local root = waitForRoot(character)
		if current ~= character then return end
		if not root then
			log.warn("no root part after %ds -- spawn handlers skipped this life", ROOT_TIMEOUT)
			return
		end
		local humanoid = Inst.humanoid(character)
		if humanoid then
			local ok = pcall(function()
				charBin:connect(humanoid.Died, function() onDied(character) end)
			end)
			if not ok then log.debug("could not connect Humanoid.Died") end
		else
			log.debug("character has a root but no humanoid; `died` will not fire")
		end
		spawnFiredFor = character
		runReapply(character)
		M.spawned:Fire(character)
	end)
end

local function unbind(character)
	M.removing:Fire(character)
	if current ~= nil and current ~= character then return end
	current = nil
	spawnFiredFor = nil
	charBin:empty()
end

-- ── respawn / refresh ───────────────────────────────────────────────────────

local function dead(character, humanoid)
	if current ~= character then return true end            -- already replaced
	if not Inst.isAlive(character) then return true end      -- model removed
	if humanoid then
		local okParent, parent = pcall(readField, humanoid, "Parent")
		if okParent and parent == nil then return true end
		local okHealth, health = pcall(readField, humanoid, "Health")
		if okHealth and type(health) == "number" and health <= 0 then return true end
	end
	return false
end

--[[ Bounded, unlike the legacy `repeat task.wait() until ...`, which hung the
     command thread forever in games that reject the writes below. ]]
local function waitForDeath(character, humanoid, timeout)
	local deadline = now() + (timeout or DEATH_TIMEOUT)
	while not dead(character, humanoid) do
		if now() >= deadline then return false end
		task.wait()
	end
	return true
end

local function networkPing()
	local player = M.player
	if player then
		local ok, ping = pcall(function() return player:GetNetworkPing() end)
		if ok and type(ping) == "number" and ping == ping then
			return math.max(ping, 1 / 30)
		end
	end
	return 0.1
end

--[[ The legacy void drop (respawn(), lines 4996-5011): switch part destruction
     off with a NaN FallenPartsDestroyHeight, drop the root to the old height,
     then put the height back so the engine destroys the rig server-side. It is
     the only kill that works in games which reject Humanoid.Health writes.

     The height goes through core/snapshot so an aborted drop cannot leave the
     void switched off, and the live value is re-applied afterwards: legacy
     restored a load-time global here, which is why `fakeout` handed back the
     wrong height once anyone had run `;dh`. ]]
local function voidDrop(root)
	local okRead, live = pcall(readField, Workspace, "FallenPartsDestroyHeight")
	if not okRead or type(live) ~= "number" or live ~= live then
		return false, "FallenPartsDestroyHeight is not readable"
	end
	local ok, reason = Snapshot.set(Workspace, "FallenPartsDestroyHeight", 0 / 0, "workspace")
	if not ok then return false, reason end

	pcall(writeField, root, "Position", Vector3.new(0, live, 0))
	task.wait(networkPing())
	Snapshot.restore(Workspace, "FallenPartsDestroyHeight")

	local okNow, height = pcall(readField, Workspace, "FallenPartsDestroyHeight")
	if okNow and height ~= live then
		-- Someone had changed it before we started (`;dh`); keep their value
		-- while leaving the game's own original in the registry.
		Snapshot.set(Workspace, "FallenPartsDestroyHeight", live, "workspace")
	end
	return true
end

--[[ Break the character, escalating through whatever the game leaves available:
     void drop, then Humanoid.Health, then BreakJoints. Returns true once the
     character is dead (or already was), else false plus a reason. ]]
function M.respawn(options)
	options = options or {}
	local character = M.get()
	if not character then return false, "you have no character right now" end
	local humanoid = Inst.humanoid(character)
	if not Inst.alive(character) then
		-- Already dead: the engine is going to hand us a new character anyway.
		return true, "already dead"
	end

	-- Games that disable the Dead state block every kill path below. Legacy
	-- re-enabled it *after* waiting for the death, where it could only ever
	-- help the next respawn.
	if humanoid then
		pcall(function() humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, true) end)
	end

	-- The camera goes Scriptable so it does not plunge with the body, and comes
	-- back through core/snapshot -- legacy read CameraType into a local and
	-- then never restored it (line 5001).
	local camera = nil
	if options.camera ~= false then
		local okCamera, found = pcall(readField, Workspace, "CurrentCamera")
		if okCamera and found then
			camera = found
			Snapshot.set(camera, "CameraType", Enum.CameraType.Scriptable, "camera")
		end
	end

	local root = Inst.root(character)
	if root then
		voidDrop(root)
		waitForDeath(character, humanoid, options.timeout or DEATH_TIMEOUT)
	end
	if not dead(character, humanoid) and humanoid then
		pcall(writeField, humanoid, "Health", 0)
		waitForDeath(character, humanoid, 1)
	end
	if not dead(character, humanoid) then
		pcall(function() character:BreakJoints() end)
		waitForDeath(character, humanoid, 1)
	end

	if camera then Snapshot.restore(camera, "CameraType") end
	if not dead(character, humanoid) then
		return false, "could not break your character (this game may block respawns)"
	end
	return true
end

--[[ Respawn, then put the character and the camera back where they were.

     `isRefreshing()` is a deadline rather than legacy's `refreshCmd` boolean:
     that flag was cleared at the end of a task.spawn that indexed
     `humanoid.RootPart` unguarded first (line 5027), so a refresh into a rig
     without a root left it stuck true and the spawn-point re-apply disabled
     for the rest of the session. ]]
function M.refresh(options)
	options = options or {}
	local character = M.get()
	if not character then return false, "you have no character right now" end

	local root = Inst.root(character)
	local cframe = root and Guard.try(readField, root, "CFrame") or nil
	local camera = Guard.try(readField, Workspace, "CurrentCamera")
	local cameraCFrame = camera and Guard.try(readField, camera, "CFrame") or nil
	local timeout = options.timeout or ROOT_TIMEOUT

	refreshUntil = now() + timeout + DEATH_TIMEOUT
	local ok, reason = M.respawn(options)
	if not ok then
		refreshUntil = nil
		return false, reason
	end

	-- Wait for a *different* character: the old one is still around while it
	-- dies, so waiting for "any rooted character" would match it immediately.
	local arrived, fresh = Sched.waitUntil(function()
		local candidate = M.get()
		if candidate and candidate ~= character and Inst.root(candidate) then
			return candidate
		end
		return nil
	end, timeout)
	refreshUntil = nil
	if not arrived then return false, "your character did not come back" end

	if cframe then
		local newRoot = Inst.root(fresh)
		local placed = newRoot ~= nil and pcall(writeField, newRoot, "CFrame", cframe)
		if not placed then
			-- Leave them at the spawn point rather than retrying: a half-applied
			-- CFrame is how the legacy refresh left people anchored mid-air.
			log.warn("refresh could not restore your position")
		end
	end
	if camera and cameraCFrame then
		task.wait()   -- the camera is re-pointed at the new rig on the next frame
		pcall(writeField, camera, "CFrame", cameraCFrame)
	end
	return true
end

--[[ True while a refresh is in flight. Features that re-apply a position on
     spawn (the spawn-point restore) stand down while it is. ]]
function M.isRefreshing()
	return refreshUntil ~= nil and now() < refreshUntil
end

-- ── wiring ──────────────────────────────────────────────────────────────────

do
	local player = M.player
	if not player then
		log.warn("no LocalPlayer: character tracking is disabled")
	else
		bin:connect(player.CharacterAdded, function(character) bind(character) end)
		bin:connect(player.CharacterRemoving, function(character) unbind(character) end)
		-- A character usually already exists by the time IY loads; without this
		-- every feature would wait for the first death to work at all.
		local existing = M.get()
		if existing then bind(existing) end
	end
end

IY.onUnload(function()
	reapplyOrder = {}
	reapplyFns = {}
	current, spawnFiredFor, refreshUntil = nil, nil, nil
	M.spawned:DisconnectAll()
	M.died:DisconnectAll()
	M.removing:DisconnectAll()
	bin:destroy()
end, "core/character")

IY.character = M
return M
