--[[═══════════════════════════════════════════════════════════════════════════
	features/states · humanoid state and posture overrides
	─────────────────────────────────────────────────────────────────────────
	`stun`, `norotate`, `nosit`, `enablestate`, `disablestate`, `freezeanims`
	and `sitwalk` all reach for the same two or three humanoid controls, and in
	the legacy script each of them did it alone:

	  · nosit, unnosit, enablestate, disablestate and swim all called
	    SetStateEnabled with no record of what the value had been, so whichever
	    ran last won and nothing could be put back. `;swim` followed by
	    `;unswim` re-enabled *every* state, silently undoing an earlier
	    `;nosit`.
	  · enablestate and disablestate never worked at all: the body read
	        local x = args[1]
	        if not tonumber(x) then local x = Enum.HumanoidStateType[ args[1] ] end
	    which declares a second `x` inside the `if`, so the outer one stayed the
	    raw argument string (lines 11575-11589).
	  · stun, norotate, freezeanims and sitwalk had no way back after a
	    respawn, and sitwalk overwrote four AnimationIds it never remembered.

	One override registry: the first writer records the original, overrides are
	re-applied to the new humanoid after a respawn, and `;unloadiy` puts
	everything back.

	Legacy equivalent: source.ref.lua 9538-9552, 9931-9947, 11559-11589.
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Feature   = IY.import("features/feature")
local Character = IY.import("core/character")
local Snapshot  = IY.import("core/snapshot")
local Guard     = IY.import("core/guard")
local Inst      = IY.import("core/util/instances")

local M = {}

-- ── state overrides ─────────────────────────────────────────────────────────

local desired  = {}   -- HumanoidStateType -> the value we want
local original = {}   -- HumanoidStateType -> { value = boolean } before we touched it

local function setEnabled(humanoid, state, enabled)
	if not humanoid then return false end
	return pcall(function() humanoid:SetStateEnabled(state, enabled) end)
end

--[[ An unreadable state is assumed enabled, which is the engine default for
     everything except Physics. ]]
local function readEnabled(humanoid, state)
	local ok, value = pcall(function() return humanoid:GetStateEnabled(state) end)
	if not ok then return true end
	return value == true
end

--[[ Restore on the humanoid the override was applied to while it still exists.
     Reading `Character.humanoid()` instead would put the value back on the wrong
     rig whenever something else has swapped the character out -- `invisible`
     hands control to a clone, and on unload its restore may not have run yet. ]]
local function targetOf(record)
	local recorded = record and record.humanoid
	if recorded then
		local ok, parent = pcall(function() return recorded.Parent end)
		if ok and parent ~= nil then return recorded end
	end
	return Character.humanoid()
end

--[[ Record the original once, then apply -- core/snapshot's rule, for something
     that is a method call rather than a property. ]]
function M.set(state, enabled)
	local humanoid = Character.requireHumanoid()
	if original[state] == nil then
		original[state] = { value = readEnabled(humanoid, state), humanoid = humanoid }
	end
	desired[state] = enabled == true
	setEnabled(humanoid, state, desired[state])
	return true
end

--[[ Drop an override and put the recorded value back. Safe when the state was
     never overridden -- which is what makes `;unnosit` on a fresh session a
     no-op instead of an error. ]]
function M.clear(state)
	local record = original[state]
	desired[state] = nil
	original[state] = nil
	if not record then return false end
	setEnabled(targetOf(record), state, record.value)
	return true
end

function M.clearAll()
	local states = {}
	for state in pairs(original) do states[#states + 1] = state end
	for i = 1, #states do M.clear(states[i]) end
	return #states
end

function M.isOverridden(state)
	return desired[state] ~= nil
end

--[[ A fresh humanoid arrives with engine defaults, so every override has to be
     re-applied. One named pass for the whole module, not one CharacterAdded
     connection per command. ]]
Character.reapply("features/states", function(character)
	local humanoid = Inst.humanoid(character)
	if not humanoid then return end
	for state, enabled in pairs(desired) do
		setEnabled(humanoid, state, enabled)
		local record = original[state]
		if record then record.humanoid = humanoid end
	end
end)

IY.onUnload(function() M.clearAll() end)

-- ── stun · PlatformStand ────────────────────────────────────────────────────

--[[ Deliberately not `reapply`: dying is the one escape a stunned player has,
     and re-applying PlatformStand on the new rig would take it away. The
     feature ends itself on death instead of claiming to still be on. ]]
local stun = Feature.new("stun", {
	command  = "stun",
	describe = "platform-standing",

	start = function(self)
		local humanoid = Character.requireHumanoid()
		Snapshot.set(humanoid, "PlatformStand", true, "states")
		self.bin:add(function() Snapshot.restore(humanoid, "PlatformStand") end)
		self.bin:connect(Character.died, function() M.stun:stop() end)
	end,
})

-- ── norotate · AutoRotate ───────────────────────────────────────────────────

local norotate = Feature.new("norotate", {
	command  = "norotate",
	reapply  = true,
	describe = "auto-rotate disabled",

	start = function(self)
		local humanoid = Character.requireHumanoid()
		Snapshot.set(humanoid, "AutoRotate", false, "states")
		self.bin:add(function() Snapshot.restore(humanoid, "AutoRotate") end)
	end,
})

-- ── freezeanims ─────────────────────────────────────────────────────────────

--[[ The Animator when there is one, else the Humanoid or AnimationController
     itself; all three expose GetPlayingAnimationTracks and AnimationPlayed. ]]
local function animationSource(character)
	if not character then return nil end
	local controller = Inst.humanoid(character)
	if not controller then
		controller = Guard.try(function() return character:FindFirstChildOfClass("AnimationController") end)
	end
	if not controller then return nil end
	local animator = Guard.try(function() return controller:FindFirstChildOfClass("Animator") end)
	return animator or controller
end

local function playingTracks(source)
	if not source then return {} end
	return Guard.try(function() return source:GetPlayingAnimationTracks() end) or {}
end

local function adjustAll(source, speed)
	local tracks = playingTracks(source)
	for i = 1, #tracks do
		pcall(function() tracks[i]:AdjustSpeed(speed) end)
	end
	return #tracks
end

--[[ Legacy froze only the tracks that happened to be playing when the command
     ran, so the next animation to start played at full speed and there was no
     un-command at all. Listening on AnimationPlayed freezes what comes next. ]]
local freezeanims = Feature.new("freezeanims", {
	command  = "freezeanims",
	reapply  = true,
	describe = "animations frozen",

	start = function(self)
		local source = animationSource(Character.require())
		if not source then Guard.fail("your character has no animator") end

		adjustAll(source, 0)
		--[[ Animator, Humanoid and AnimationController all expose this, but a
		     custom rig may hand back something that does not; freeze what is
		     playing and leave it there rather than failing outright. ]]
		local played = Guard.try(function() return source.AnimationPlayed end)
		if played then
			self.bin:connect(played, function(track)
				pcall(function() track:AdjustSpeed(0) end)
			end)
		end
		self.bin:add(function()
			adjustAll(animationSource(Character.get()), 1)
		end)
	end,
})

-- ── sitwalk ─────────────────────────────────────────────────────────────────

local SITWALK_SLOTS = { "idle", "walk", "run", "jump" }

local function animationIn(folder)
	if not folder then return nil end
	return Guard.try(function() return folder:FindFirstChildWhichIsA("Animation") end)
end

--[[ Swap the sit animation into every other slot of the default Animate script.
     Legacy wrote the four AnimationIds with no record of the originals, so it
     could only be undone by respawning; Snapshot gives it an off switch. ]]
local sitwalk = Feature.new("sitwalk", {
	command  = "sitwalk",
	reapply  = true,
	describe = "walking while seated",

	start = function(self)
		local character = Character.require()
		local humanoid = Character.requireHumanoid()
		local animate = character:FindFirstChild("Animate")
		if not animate then Guard.fail("this game replaced the default Animate script") end

		local seated = animationIn(animate:FindFirstChild("sit"))
		if not seated then Guard.fail("the default sit animation is missing") end
		local id = seated.AnimationId

		for i = 1, #SITWALK_SLOTS do
			local animation = animationIn(animate:FindFirstChild(SITWALK_SLOTS[i]))
			if animation then Snapshot.set(animation, "AnimationId", id, "sitwalk") end
		end
		-- R6 sits lower than its hip height suggests; R15 sits higher.
		Snapshot.set(humanoid, "HipHeight", Inst.isR15(character) and 0.5 or -1.5, "sitwalk")
		self.bin:add(function() Snapshot.restoreTag("sitwalk") end)
	end,
})

-- ── exports ─────────────────────────────────────────────────────────────────

M.stun        = stun
M.norotate    = norotate
M.freezeanims = freezeanims
M.sitwalk     = sitwalk

return M
