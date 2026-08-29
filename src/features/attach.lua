--[[═══════════════════════════════════════════════════════════════════════════
	features/attach · riding another player
	─────────────────────────────────────────────────────────────────────────
	One primitive behind every "attach yourself to a player" command:

	    Attach.to(target, { offset = CFrame.new(0, 2, 0), animation = assetId })
	    Attach.release()

	and the four features built on it -- `bang`, `carpet`, `headsit`, `jerk`.

	The legacy versions each duplicated the whole thing and each leaked the same
	way: the follow connection was created *inside* the loop over matched players
	and only the last one was stored in a global (`carpet` 10888, `headsit`
	10650), so `;carpet all` in a four-player server left three live Heartbeat
	connections fighting over one root part for the rest of the session, and
	`uncarpet` could only ever stop the fourth. One connection, one current
	target, in a bin.

	Other legacy behaviour deliberately not reproduced:

	  · `bang` assigned `bangLoop` only when a player had been named (10851), so
	    `;bang` on its own followed by a death -- or by `;unbang` -- called
	    `:Disconnect()` on a nil (10844, 10867). Feature-based stop is safe by
	    construction, and the no-target case is now an explicit branch.
	  · `jerk` was `while task.wait() do ... end` with no flag and no off
	    command (12783): two invocations meant two loops and neither
	    `;breakloops` nor `;unloadiy` could reach either. `;unjerk` is new.
	  · animations were loaded through the deprecated `Humanoid:LoadAnimation`
	    and every command destroyed its own Animation instance by hand from
	    inside a Died handler. They go through the Animator and the bin now.

	Legacy equivalent: source.ref.lua 10645-10658, 10826-10906, 11979-12006,
	12757-12802.
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Feature   = IY.import("features/feature")
local Character = IY.import("core/character")
local Snapshot  = IY.import("core/snapshot")
local Sched     = IY.import("core/scheduler")
local Guard     = IY.import("core/guard")
local Inst      = IY.import("core/util/instances")

local M = {}

local BANG_R6,   BANG_R15   = "rbxassetid://148840371", "rbxassetid://5918726674"
local CARPET_R6              = "rbxassetid://282574440"
local JERK_R6,   JERK_R15   = "rbxassetid://72042024",  "rbxassetid://698251653"
local DEFAULT_BANG_SPEED     = 3

-- ═══ shared primitives ══════════════════════════════════════════════════════

--[[ Legacy `getTorso` (10826): a torso if the rig has one, else the root. ]]
local function torso(character)
	if not character then return nil end
	return character:FindFirstChild("Torso")
		or character:FindFirstChild("UpperTorso")
		or character:FindFirstChild("LowerTorso")
		or Inst.root(character)
end
M.torso = torso

--[[ Load and play a looping animation, cleaned up by the bin it is given.
     Prefers the Animator, which is the supported path; `Humanoid:LoadAnimation`
     is deprecated and already refused by some games. ]]
local function playAnimation(bin, humanoid, assetId, speed)
	local animation = bin:add(Instance.new("Animation"))
	animation.AnimationId = assetId

	local animator = humanoid:FindFirstChildOfClass("Animator")
	local loader = animator or humanoid
	local ok, track = pcall(function() return loader:LoadAnimation(animation) end)
	if not ok or not track then
		Guard.fail("this game does not let scripts play animations")
	end

	-- Added after the Animation, so the bin stops the track *before* destroying
	-- what it was playing.
	bin:add(function() pcall(function() track:Stop() end) end)
	pcall(function() track:Play(0.1, 1, 1) end)
	if speed then pcall(function() track:AdjustSpeed(speed) end) end
	return track
end
M.playAnimation = playAnimation

--[[ The legacy `attach` helper (11979), which `kill`, `bring` and `teleport`
     are built on: swap in a cloned Humanoid so the server stops correcting your
     CFrame, then move a Tool into the character. Games with tool welds then
     treat the tool -- and whatever it is touching -- as part of your rig.

     Destructive by nature: the original Humanoid is destroyed, so the only way
     back is a respawn. Legacy renamed the live Humanoid to "1" before cloning
     it and left it named that on any failure in between; the rename happens
     immediately before the clone here, with nothing that can yield between. ]]
local function weldSetup(bin)
	local character = Character.require()
	local humanoid = Character.requireHumanoid()
	local tool = Inst.tools(Character.player)[1]
	if not tool then
		Guard.fail("you need an item in your inventory to use this")
	end

	humanoid.Name = "1"
	local replacement = humanoid:Clone()
	replacement.Parent = character
	replacement.Name = "Humanoid"
	task.wait()
	humanoid:Destroy()
	pcall(function()
		replacement.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end)

	local camera = workspace.CurrentCamera
	if camera then
		Snapshot.set(camera, "CameraSubject", character, "attach")
		bin:add(function() Snapshot.restore(camera, "CameraSubject") end)
	end
	tool.Parent = character
	return tool
end
M.weld = weldSetup

--[[ The follow loop. `self` is any feature; everything created lands in its
     bin, so one `:stop()` -- or a respawn, or `;unloadiy` -- undoes all of it.

     opts: target, offset, anchor ("torso"|"root"), event, animation, speed,
           sit, requireR6, weld, label ]]
local function bind(self, opts)
	local target = opts.target
	local label = opts.label or self.name
	if not target then Guard.fail("%s needs a player", label) end

	local character = Character.require()
	local humanoid = Character.requireHumanoid()
	Character.requireRoot()
	target:requireRoot()

	if opts.requireR6 and Inst.isR15(character) then
		Guard.fail("%s needs the R6 rig type", label)
	end

	if opts.weld then weldSetup(self.bin) end
	if opts.animation then
		playAnimation(self.bin, humanoid, opts.animation, opts.speed)
	end
	if opts.sit then pcall(function() humanoid.Sit = true end) end

	local offset = opts.offset
	local useTorso = opts.anchor == "torso"

	self.bin:add(Sched.frameLoop("attach." .. self.name, function()
		local root = Character.root()
		if not root then return end

		local anchor = useTorso and torso(target.character) or target.root
		if not anchor then
			-- Legacy wrapped this write in a pcall and so kept trying against a
			-- destroyed part forever once the target left.
			if opts.stopWhenGone then self:stop() end
			return
		end

		if opts.sit then
			-- Standing up is how you get off someone's head (10651).
			local current = Character.humanoid()
			if not current or current.Sit ~= true then
				self:stop()
				return
			end
		end

		root.CFrame = offset and (anchor.CFrame * offset) or anchor.CFrame
	end, opts.event or "heartbeat"))

	--[[ Legacy hung teardown off Humanoid.Died and then dereferenced a loop
	     that might never have been assigned (10840). ]]
	self.bin:connect(Character.died, function() self:stop() end)
end
M.bind = bind

-- ═══ features ═══════════════════════════════════════════════════════════════

--[[ Every one of these writes your root CFrame every frame, so exactly one may
     run at a time -- `exclusive` enforces what the legacy `execCmd('unbang')`
     preamble only did for the same command. ]]
local bang = Feature.new("bang", {
	command   = "bang",
	exclusive = { "attach", "carpet", "headsit" },
	describe  = "attached to a player",

	start = function(self, opts)
		local humanoid = Character.requireHumanoid()
		local assetId = Inst.isR15(Character.get()) and BANG_R15 or BANG_R6
		local speed = opts.speed or DEFAULT_BANG_SPEED

		if not opts.target then
			-- No player named: the animation and nothing else, as legacy did
			-- (10846) -- minus the nil `bangLoop` its teardown then touched.
			playAnimation(self.bin, humanoid, assetId, speed)
			self.bin:connect(Character.died, function() self:stop() end)
			return
		end

		bind(self, {
			target    = opts.target,
			label     = "bang",
			animation = assetId,
			speed     = speed,
			offset    = CFrame.new(0, 0, 1.1),
			anchor    = "torso",
			event     = "stepped",
		})
	end,
})

local carpet = Feature.new("carpet", {
	command   = "carpet",
	exclusive = { "attach", "bang", "headsit" },
	describe  = "carpeting a player",

	start = function(self, opts)
		bind(self, {
			target    = opts.target,
			label     = "carpet",
			animation = CARPET_R6,
			requireR6 = true,
			event     = "heartbeat",
		})
	end,
})

local headsit = Feature.new("headsit", {
	command   = "headsit",
	exclusive = { "attach", "bang", "carpet" },
	describe  = "sitting on a player's head",

	start = function(self, opts)
		bind(self, {
			target       = opts.target,
			label        = "headsit",
			offset       = CFrame.new(0, 1.6, 0.4),
			sit          = true,
			event        = "heartbeat",
			stopWhenGone = true,
		})
	end,
})

--[[ The generic primitive, for anything that wants a custom offset or the
     legacy tool weld: `Attach.to(target, { weld = true })`. ]]
local attach = Feature.new("attach", {
	exclusive = { "bang", "carpet", "headsit" },
	describe  = "attached to a player",
	start     = function(self, opts) bind(self, opts) end,
})

-- ── jerk ────────────────────────────────────────────────────────────────────

local JERK_TOOLTIP = "in the stripped club. straight up \"jorking it\" ."
	.. " and by \"it\" , haha, well. let's justr say. My peanits."

--[[ The animation is replayed from a fixed time position in short slices, which
     is what produces the motion; legacy did it with a nested
     `while track.TimePosition < limit do task.wait(0.1) end` inside an outer
     `while task.wait()` and a Luau `continue`. One 0.1s interval and two bits
     of state say the same thing in Lua 5.1. ]]
local jerk = Feature.new("jerk", {
	command  = "jerk",
	reapply  = true,
	describe = "holding the jerk tool",

	start = function(self)
		local player = Character.player
		Character.requireHumanoid()
		local backpack = player and player:FindFirstChildOfClass("Backpack")
		if not backpack then Guard.fail("you have no backpack right now") end

		local isR15  = Inst.isR15(Character.get())
		local assetId = isR15 and JERK_R15 or JERK_R6
		local speed   = isR15 and 0.7 or 0.65
		local limit   = isR15 and 0.7 or 0.65

		local tool = self.bin:instance("Tool", {
			Name           = "Jerk Off",
			ToolTip        = JERK_TOOLTIP,
			RequiresHandle = false,
			Parent         = backpack,
		})

		-- The track lives in a branch so unequipping drops it without tearing
		-- down the tool or the loop.
		local trackBin = self.bin:branch("track")
		local function release()
			trackBin:empty()
			self.state.track = nil
		end

		self.bin:connect(tool.Equipped, function() self.state.equipped = true end)
		self.bin:connect(tool.Unequipped, function()
			self.state.equipped = false
			release()
		end)

		self.bin:add(Sched.interval("jerk.step", 0.1, function()
			if not self.state.equipped or not Character.alive() then
				if self.state.track then release() end
				return
			end
			local track = self.state.track
			if not track then
				local humanoid = Character.humanoid()
				if not humanoid then return end
				track = playAnimation(trackBin, humanoid, assetId, speed)
				self.state.track = track
				pcall(function() track.TimePosition = 0.6 end)
				return
			end
			local position = Guard.try(function() return track.TimePosition end)
			if type(position) ~= "number" or position >= limit then release() end
		end))
	end,
})

-- ═══ module API ═════════════════════════════════════════════════════════════

M.bang    = bang
M.carpet  = carpet
M.headsit = headsit
M.jerk    = jerk
M.attach  = attach

local family = { attach, bang, carpet, headsit }

--[[ Attach with an explicit option table. Returns true when it started. ]]
function M.to(target, opts)
	local merged = {}
	if opts then
		for key, value in pairs(opts) do merged[key] = value end
	end
	merged.target = target
	return attach:start(merged)
end

--[[ Undo any attachment, whichever command made it. ]]
function M.release()
	local stopped = false
	for i = 1, #family do
		if family[i]:stop() then stopped = true end
	end
	return stopped
end

function M.isAttached()
	for i = 1, #family do
		if family[i]:isRunning() then return true end
	end
	return false
end

--[[ The target of whatever is currently attached, or nil. ]]
function M.target()
	for i = 1, #family do
		if family[i]:isRunning() then return family[i]:option("target", nil) end
	end
	return nil
end

return M
