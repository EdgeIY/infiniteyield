--[[═══════════════════════════════════════════════════════════════════════════
	features/animation · one owner for every AnimationTrack IY plays
	─────────────────────────────────────────────────────────────────────────
	The legacy script kept its tracks in bare globals -- `danceTrack` (9843),
	`Spasm` and `SpasmAnim` (10103-10105), plus the local `k` in headthrow
	(10123) that nothing could reach afterwards -- and the off-commands used
	them unguarded:

	    addcmd('unspasm',{'nospasm'},function() Spasm:Stop() SpasmAnim:Destroy() end)

	so `;unspasm` before `;spasm` threw, a second `;dance` leaked the first
	track, and a respawn orphaned every one of them: the global still held a
	track belonging to a destroyed Animator, so `;dance` looked on and played
	nothing at all.

	One player instead. Each animation is a *request* living in its own branch
	of the feature bin:

	    local handle = Animation.play(id, { looped = true, speed = 2 })
	    Animation.stop(handle)        -- or stopAll(); safe when idle
	    Animation.setSpeed(2)         -- ;animspeed, on live tracks
	    Animation.freeze(true)        -- ;freezeanims (its command is in states)
	    Animation.tracks()            -- live handles, for diagnostics

	Requests outlive the character: the feature re-applies on respawn and
	rebuilds every track against the new Animator.

	Legacy equivalent: source.ref.lua 9835-9851, 10099-10129, 10131-10176,
	10235-10274, and the freezeanims pair at 9538-9552 whose command belongs to
	features/states.
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Feature   = IY.import("features/feature")
local Character = IY.import("core/character")
local Services  = IY.import("core/services")
local Snapshot  = IY.import("core/snapshot")
local Guard     = IY.import("core/guard")
local Inst      = IY.import("core/util/instances")

local M = {}

local TAG = "animation"

-- Legacy ids, speeds and fades, kept exactly (9837-9839, 10102, 10120).
local DANCES_R6  = { "27789359", "30196114", "248263260", "45834924", "33796059", "28488254", "52155728" }
local DANCES_R15 = { "3333432454", "4555808220", "4049037604", "4555782893", "10214311282",
	"10714010337", "10713981723", "10714372526", "10714076981", "10714392151", "11444443576" }
local SPASM_ID     = "33796059"
local SPASM_SPEED  = 99
local HEADTHROW_ID = "35154961"

-- ── the animation source ────────────────────────────────────────────────────

--[[ The Animator when the rig has one, else the Humanoid or AnimationController
     itself: all three answer LoadAnimation and GetPlayingAnimationTracks, and
     preferring the Animator is what makes custom rigs work. `Character.animator`
     is the same lookup for the local rig; this takes any character, which is
     what `;copyanimation` needs for its target. ]]
local function animationSource(character)
	character = character or Character.get()
	if not character then return nil end
	local controller = Inst.humanoid(character)
		or Guard.try(function() return character:FindFirstChildOfClass("AnimationController") end)
	if not controller then return nil end
	local animator = Guard.try(function() return controller:FindFirstChildOfClass("Animator") end)
	return animator or controller
end

M.source = animationSource

local function requireSource()
	local source = animationSource(Character.get())
	if not source then
		Guard.fail("your character has no humanoid to animate")
	end
	return source
end

--[[ Nil-safe: legacy indexed `Char:FindFirstChildOfClass("Humanoid")` straight
     into GetPlayingAnimationTracks (10173, 10182, 10204) and threw whenever the
     character or the humanoid was not there yet. ]]
function M.playingTracks(character)
	local source = animationSource(character)
	if not source then return {} end
	return Guard.try(function() return source:GetPlayingAnimationTracks() end) or {}
end

-- ── animation ids ───────────────────────────────────────────────────────────

local function idOf(value)
	if typeof(value) == "Instance" then
		local id = Guard.try(function() return value.AnimationId end)
		if not id or id == "" then Guard.fail("that Animation has no AnimationId") end
		return id
	end
	local text = tostring(value or "")
	if string.find(text, "://", 1, true) then return text end
	local digits = string.match(text, "%d+")
	if not digits then Guard.fail("'%s' is not an animation id", text) end
	return "rbxassetid://" .. digits
end

M.idOf = idOf

--[[ Some ids point at a container asset (an emote package) rather than at the
     Animation itself, which is what the legacy `anim2track` (10131-10139) was
     for. GetObjects yields and needs an elevated identity, so a failure just
     means "use the id as given". ]]
function M.resolveId(value)
	local url = idOf(value)
	local objects = Guard.try(function() return game:GetObjects(url) end)
	if type(objects) ~= "table" then return url end
	local resolved = url
	for i = 1, #objects do
		local object = objects[i]
		if resolved == url and Guard.try(function() return object:IsA("Animation") end) then
			resolved = Guard.try(function() return object.AnimationId end) or url
		end
		pcall(function() object:Destroy() end)
	end
	return resolved
end

-- ── the player ──────────────────────────────────────────────────────────────

local requests = {}      -- live handles, in the order they were started
local frozen   = false
local player             -- the Feature, defined below

local function indexOf(handle)
	for i = 1, #requests do
		if requests[i] == handle then return i end
	end
	return nil
end

local function loadTrack(source, animation)
	local ok, track = pcall(function() return source:LoadAnimation(animation) end)
	if not ok or not track then
		Guard.fail("this game would not load that animation onto your character")
	end
	return track
end

--[[ Build the track for one request against the current character. Each request
     owns a bin branch, so stopping one leaves the others playing -- the legacy
     globals could only ever hold the newest track of each kind. ]]
local function startTrack(self, handle)
	local source = requireSource()
	local branch = self.bin:branch("track")
	handle.bin = branch

	local animation = branch:add(Instance.new("Animation"))
	animation.Name = "IYAnimation"
	animation.AnimationId = handle.id

	local track = loadTrack(source, animation)
	handle.track = track
	branch:add(function()
		handle.track = nil
		pcall(function() track:Stop() end)
		pcall(function() track:Destroy() end)
	end)

	if handle.priority then
		pcall(function() track.Priority = handle.priority end)
	end
	-- Only when asked: an animation asset carries its own loop flag, and forcing
	-- Looped = false would cut `spasm` short, which legacy never did.
	if handle.looped ~= nil then
		pcall(function() track.Looped = handle.looped end)
	end
	track:Play(handle.fade, handle.weight, handle.speed)
	if handle.timePosition then
		pcall(function() track.TimePosition = handle.timePosition end)
	end
	if frozen then pcall(function() track:AdjustSpeed(0) end) end

	--[[ A one-shot that finishes on its own is dropped, so `tracks()` only ever
	     lists what is really playing. Added last so `bin:empty` disconnects it
	     before the cleanup above stops the track -- otherwise Stopped would
	     re-enter M.stop mid-teardown. ]]
	if handle.looped ~= true then
		branch:connect(track.Stopped, function() M.stop(handle) end)
	end
	return track
end

player = Feature.new("animation", {
	reapply  = true,
	describe = "playing custom animations",

	--[[ Every live request is (re)built here, which is what makes a respawn
	     transparent: legacy tracks belonged to the destroyed Animator and were
	     never rebuilt, so `;dance` stopped working after a death while
	     `danceTrack` still looked alive. ]]
	start = function(self)
		for i = 1, #requests do
			startTrack(self, requests[i])
		end
	end,

	--[[ ;unloadiy, ;panic and Feature.stopAll() come through here: forget the
	     requests too, or the next `play` would resurrect them. ]]
	stop = function(self)
		for i = #requests, 1, -1 do
			requests[i].track = nil
			requests[i].bin = nil
			requests[i] = nil
		end
	end,
})

M.feature = player

--[[ Play an animation id (or an Animation instance) and return a handle.
       opts.speed / looped / priority   the three the command set needs
       opts.fade / weight / timePosition passed straight to Play, for copyanim
       opts.resolve                     run the id through GetObjects first
     `looped` left nil keeps the asset's own loop flag. ]]
function M.play(idOrAnimation, opts)
	opts = opts or {}
	local handle = {
		id           = opts.resolve and M.resolveId(idOrAnimation) or idOf(idOrAnimation),
		speed        = opts.speed,
		looped       = opts.looped,
		priority     = opts.priority,
		fade         = opts.fade,
		weight       = opts.weight,
		timePosition = opts.timePosition,
		label        = opts.label,
	}
	requireSource()   -- fail before anything is recorded
	requests[#requests + 1] = handle

	local ok, err
	if player:isRunning() then
		ok, err = pcall(startTrack, player, handle)
	else
		-- start() plays every pending request, this one included.
		ok, err = pcall(player.start, player)
	end
	if not ok then
		local index = indexOf(handle)
		if index then table.remove(requests, index) end
		error(err, 0)
	end
	return handle
end

--[[ Stop one handle. Idempotent, and safe with a handle from a previous life. ]]
function M.stop(handle)
	if type(handle) ~= "table" then return false end
	local index = indexOf(handle)
	local bin = handle.bin
	handle.bin = nil
	handle.track = nil
	if bin then bin:destroy() end
	if index == nil then return false end
	table.remove(requests, index)

	-- The feature that asked for this animation is no longer doing anything, so
	-- `;toggledance` and the UI cannot disagree with what is actually playing.
	local owner = handle.owner
	if owner and owner:isRunning() then owner:stop() end
	if #requests == 0 and player:isRunning() then player:stop() end
	return true
end

--[[ Stop everything IY started. Safe when nothing is playing: `undance` (9849)
     and `unspasm` (10114) both threw in exactly that case. ]]
function M.stopAll()
	local count = #requests
	player:stop()
	return count
end

--[[ Stop every track on the character, ours or the game's -- what legacy
     `stopanimations` (10235-10242) did, and what people use it for. ]]
function M.stopPlaying()
	local tracks = M.playingTracks()
	for i = 1, #tracks do
		local track = tracks[i]
		pcall(function() track:Stop() end)
	end
	return #tracks
end

--[[ Live handles. Each carries id / speed / looped and a `track` that is nil
     while the character is being replaced. ]]
function M.tracks()
	local out = {}
	for i = 1, #requests do out[i] = requests[i] end
	return out
end

--[[ Stop `handle` when somebody else's `track` stops -- how `;copyanimation`
     follows the player it is mimicking. The connection belongs to the handle's
     branch, so it goes when the copy does; legacy parked a task.spawn on
     `Stopped:Wait()` (10190-10194) that never returned when the source outlived
     the copy. ]]
function M.follow(handle, track)
	local bin = type(handle) == "table" and handle.bin or nil
	if not bin or not track then return false end
	local signal = Guard.try(function() return track.Stopped end)
	if not signal then return false end
	bin:connect(signal, function() M.stop(handle) end)
	return true
end

function M.isRunning() return player:isRunning() end

--[[ ;animspeed. Legacy adjusted every playing track including the game's own
     (10169-10176) and passed `tostring(args[1])` into AdjustSpeed; both kept,
     minus the string. Recording the speed on our own handles is what makes it
     survive a respawn. ]]
function M.setSpeed(speed)
	-- A blanket AdjustSpeed is exactly what un-freezing does, so the flag has to
	-- follow the speed we just applied.
	frozen = speed == 0
	for i = 1, #requests do
		local handle = requests[i]
		handle.speed = speed
	end
	local tracks = M.playingTracks()
	for i = 1, #tracks do
		local track = tracks[i]
		pcall(function() track:AdjustSpeed(speed) end)
	end
	return #tracks
end

--[[ ;freezeanims. The command lives in features/states, which sweeps every
     playing track with AdjustSpeed(0/1); this keeps each of our handles' own
     speed, so unfreezing restores `spasm`'s 99x instead of resetting it to 1. ]]
function M.freeze(enabled)
	frozen = enabled == true
	for i = 1, #requests do
		local handle = requests[i]
		local track = handle.track
		if track then
			local speed = frozen and 0 or (handle.speed or 1)
			pcall(function() track:AdjustSpeed(speed) end)
		end
	end
	return frozen
end

function M.isFrozen() return frozen end

-- Mirror the state of the freezeanims feature so its blanket unfreeze does not
-- flatten the speeds of the tracks we own.
do
	local mirror = Feature.changed:Connect(function(name, running)
		if name == "freezeanims" then M.freeze(running == true) end
	end)
	IY.onUnload(function() mirror:Disconnect() end)
end

-- ── features that own one animation ─────────────────────────────────────────

--[[ Tie a feature to a handle in both directions: stopping the feature stops
     the track, and anything that stops the player (`;stopanimations`,
     `;unloadiy`) stops the feature. The connection goes in after the cleanup so
     `bin:empty` disconnects it first and cannot recurse. ]]
local function hold(feature, handle)
	handle.owner = feature
	feature.bin:add(function() M.stop(handle) end)
	feature.bin:connect(Feature.changed, function(name, running)
		if name == "animation" and running == false then feature:stop() end
	end)
	return handle
end

--[[ Not `reapply`: the player re-creates the track on the new character, and a
     second pass here would pick a different dance and fight with it. ]]
local dance = Feature.new("dance", {
	command  = "dance",
	describe = "dancing",

	start = function(self, opts)
		local character = Character.require()
		local list = Inst.isR15(character) and DANCES_R15 or DANCES_R6
		local id = (opts and opts.id) or list[math.random(1, #list)]
		self.state.id = id
		hold(self, M.play(id, { looped = true, speed = opts and opts.speed }))
	end,
})

local spasm = Feature.new("spasm", {
	command  = "spasm",
	describe = "spasming",

	start = function(self)
		if Inst.isR15(Character.require()) then
			Guard.fail("spasm needs the R6 rig type")
		end
		hold(self, M.play(SPASM_ID, { speed = SPASM_SPEED }))
	end,
})

--[[ A one-shot: the handle drops itself when the track ends (legacy 10118-10129
     kept no reference at all, so nothing could stop it early). ]]
local headthrow = Feature.new("headthrow", {
	command  = "headthrow",
	describe = "throwing your head",

	start = function(self)
		if Inst.isR15(Character.require()) then
			Guard.fail("headthrow needs the R6 rig type")
		end
		hold(self, M.play(HEADTHROW_ID, { fade = 0, speed = 1 }))
	end,
})

--[[ `loopanimation <id>` keeps that animation looping, across respawns. With no
     id it loops whatever is playing, which is what legacy did (10268-10274) --
     except legacy set Looped on tracks it never remembered and so had no way
     back. Only tracks that were *not* already looping are touched, so turning it
     off cannot break the game's own idle animation. ]]
local loopanimation = Feature.new("loopanimation", {
	command  = "loopanimation",
	describe = "looping animations",

	start = function(self, opts)
		local id = opts and opts.id
		if id then
			hold(self, M.play(id, { looped = true, speed = opts.speed, resolve = true }))
			return
		end
		local tracks = M.playingTracks()
		local touched = 0
		for i = 1, #tracks do
			local track = tracks[i]
			if Guard.try(function() return track.Looped end) == false then
				local ok = pcall(function() track.Looped = true end)
				if ok then
					touched = touched + 1
					self.bin:add(function() pcall(function() track.Looped = false end) end)
				end
			end
		end
		if touched == 0 then
			Guard.fail("nothing is playing that is not already looping -- pass an animation id")
		end
		self.state.tracks = touched
	end,
})

-- ── emotes ──────────────────────────────────────────────────────────────────

--[[ Legacy `emote` (10155-10158) could never have worked:

         local anim = humanoid:PlayEmoteAndGetAnimTrackById(args[1])

     `humanoid` is an undefined global on that line -- every other `humanoid` in
     the file is a local -- so the command threw on the first index, every time.
     Two things are fixed here: a real humanoid, and the return value. The API
     returns (didPlay, track), so even with a humanoid the legacy
     `anim:AdjustSpeed` would have indexed a boolean. The call is guarded
     because it errors outright for emote ids the player does not own. ]]
function M.emote(id, speed)
	local humanoid = Character.requireHumanoid()
	local numeric = tonumber(string.match(tostring(id), "%d+") or "")
	if not numeric then Guard.fail("'%s' is not an emote id", tostring(id)) end

	local ok, played, track = pcall(function()
		return humanoid:PlayEmoteAndGetAnimTrackById(numeric)
	end)
	if not ok or not played then
		Guard.fail("could not play emote %d -- you may not own it, or this client does not support emotes", numeric)
	end
	if speed and track then
		pcall(function() track:AdjustSpeed(speed) end)
	end
	-- The engine owns this track, not us; `;stopanimations` still stops it.
	return track
end

-- ── the Animate script ──────────────────────────────────────────────────────

local function requireAnimate()
	local character = Character.require()
	local animate = Guard.try(function() return character:FindFirstChild("Animate") end)
	if not animate then
		Guard.fail("this game replaced the default Animate script, so there is nothing to disable")
	end
	return animate
end

M.requireAnimate = requireAnimate

--[[ ;noanim / ;reanim. Through Snapshot, so `;unloadiy` re-enables the script
     even when the user never ran `;reanim` -- legacy (10161-10167) left it
     disabled for the rest of that life. ]]
function M.setAnimateDisabled(disabled)
	local animate = requireAnimate()
	if disabled then
		local ok, reason = Snapshot.set(animate, "Disabled", true, TAG)
		if not ok then Guard.fail("could not disable the Animate script (%s)", tostring(reason)) end
		return true
	end
	if Snapshot.isModified(animate, "Disabled") then
		Snapshot.restore(animate, "Disabled")
	else
		pcall(function() animate.Disabled = false end)
	end
	return true
end

--[[ ;refreshanimations: restart the Animate script so it reloads its ids.
     Legacy re-enabled it unconditionally (10255), quietly cancelling an active
     `;noanim`; the live value goes back exactly as it was. ]]
function M.refresh()
	local animate = requireAnimate()
	local was = Guard.try(function() return animate.Disabled end)
	pcall(function() animate.Disabled = true end)
	M.stopAll()
	local stopped = M.stopPlaying()
	if was ~= nil then pcall(function() animate.Disabled = was end) end
	return stopped
end

--[[ ;allowcustomanim. AllowCustomAnimations is not a scriptable property, so
     this needs the executor: legacy assigned it directly (10259) and silently
     did nothing on every client that rejects the write. ]]
function M.setAllowCustom(enabled)
	local starterPlayer = Services.get("StarterPlayer")
	if not starterPlayer then Guard.fail("StarterPlayer is unavailable on this client") end
	local set = Guard.need("sethiddenproperty")
	local ok = pcall(set, starterPlayer, "AllowCustomAnimations", enabled == true)
	if not ok then Guard.fail("this client would not let us write AllowCustomAnimations") end
	M.refresh()
	return true
end

-- ── exports ─────────────────────────────────────────────────────────────────

M.dance         = dance
M.spasm         = spasm
M.headthrow     = headthrow
M.loopanimation = loopanimation

return M
