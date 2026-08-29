--[[═══════════════════════════════════════════════════════════════════════════
	features/teleport · the shared teleport primitives
	─────────────────────────────────────────────────────────────────────────
	Every teleport command funnels through here, so there is exactly one answer
	to "where do I put the player, and what do I do about the seat, the velocity
	and the tween".

	    Teleport.to(cframeOrVector, { tween = 1, offset = Vector3, vehicle = true })
	    Teleport.toTarget(target, { distance = 3, stream = true })
	    Teleport.bring(target)                  -- move them to you (clientbring)
	    Teleport.pulse(target, { seconds = 1 }) -- hop over, hop back

	Legacy equivalent: the same CFrame assignment repeated in twenty `addcmd`
	bodies between source.ref.lua 9083 and 11022, each with a different subset
	of the guards. What they collectively got wrong:

	  · `getRoot(speaker.Character).CFrame = ...` with no nil check, so all of
	    them threw while the character was loading, dead, or streamed out.
	  · the seat dance (`humanoid.Sit = false; wait(.1)`) was copied into some
	    commands and forgotten in others, so `;tppos` in a vehicle snapped you
	    straight back and looked like the command had done nothing.
	  · `vehiclegoto` / `vehiclenoclip` walked `seat.Parent` upward in a
	    `repeat` with no nil test, which threw when you were not sitting at all.
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Services  = IY.import("core/services")
local Character = IY.import("core/character")
local Guard     = IY.import("core/guard")
local Inst      = IY.import("core/util/instances")

local TweenService = Services.TweenService

local M = {}

-- Legacy's "beside them, not inside them" nudge, used by every command that
-- teleports you to a player except `goto` (see M.targetFrame).
local SIDE_STEP = Vector3.new(3, 1, 0)

local DEFAULT_TWEEN_SPEED = 1

--[[ The tween duration `tweengoto` and friends use. `;tweenspeed` belongs to
     the waypoints pack, which owns the setting, so it is read from there and
     falls back to the legacy default of 1 when that pack is not loaded. ]]
function M.tweenSpeed()
	local ok, Waypoints = pcall(function() return IY.import("features/waypoints") end)
	if ok and Waypoints then
		local value = Waypoints.tweenSpeed
		if type(value) == "function" then
			local okCall, result = pcall(value)
			if okCall and type(result) == "number" then return result end
		elseif type(value) == "number" then
			return value
		end
	end
	return DEFAULT_TWEEN_SPEED
end

-- ── destinations ────────────────────────────────────────────────────────────

local function toCFrame(value)
	if value == nil then return nil end
	local kind = typeof(value)
	if kind == "CFrame" then return value end
	if kind == "Vector3" then return CFrame.new(value) end
	if kind == "Instance" then
		if value:IsA("BasePart") then return value.CFrame end
		if value:IsA("Model") then return value:GetPivot() end
	end
	return nil
end
M.toCFrame = toCFrame

--[[ The legacy "next to them" offset: Vector3(distance, 1, 0) beside a frame. ]]
function M.beside(frame, distance)
	return frame + Vector3.new(distance or SIDE_STEP.X, SIDE_STEP.Y, SIDE_STEP.Z)
end

-- ── seats and vehicles ──────────────────────────────────────────────────────

--[[ Stand up before teleporting -- a seat weld drags you straight back
     otherwise. Returns true when it actually had to unseat you, in which case
     it also yielded for a tenth of a second and any cached root part is
     stale. ]]
function M.unseat()
	local humanoid = Character.humanoid()
	if not humanoid or not humanoid.SeatPart then return false end
	humanoid.Sit = false
	task.wait(0.1)
	return true
end

--[[ The model of the vehicle you are sitting in, or a message telling you to
     sit in one. Replaces the unguarded upward `repeat` walk at 9182-9188. ]]
function M.vehicleModel()
	local humanoid = Character.humanoid()
	local seat = humanoid and humanoid.SeatPart
	if not seat then Guard.fail("sit in a vehicle first") end
	local model = seat:FindFirstAncestorWhichIsA("Model")
	if not model then Guard.fail("the seat you are in is not part of a model") end
	return model
end

-- ── moving ──────────────────────────────────────────────────────────────────

local function tween(part, frame, seconds)
	local animation = TweenService:Create(part,
		TweenInfo.new(seconds, Enum.EasingStyle.Linear), { CFrame = frame })
	animation:Play()
	return animation
end

--[[ PivotTo moves the whole rig rigidly, which is what legacy `goto` did; a
     bare root.CFrame assignment lets welded accessories stretch behind you.
     Characters without a PrimaryPart have no meaningful pivot, so those fall
     back to the root part. ]]
local function place(character, root, frame)
	if character.PrimaryPart then
		local ok = pcall(function() character:PivotTo(frame) end)
		if ok then return end
	end
	root.CFrame = frame
end

--[[ Move the local character (or the vehicle it is in) to a destination.
     opts.tween          seconds, or `true` for the shared tween speed
     opts.offset         Vector3 added to the destination
     opts.unseat         stand up first (legacy did this in some commands only)
     opts.vehicle        move the seat's model instead of the character
     opts.breakVelocity  default true ]]
function M.to(destination, opts)
	opts = opts or {}
	local frame = toCFrame(destination)
	if not frame then Guard.fail("there is nothing there to teleport to") end
	if opts.offset then frame = frame + opts.offset end

	local seconds = opts.tween
	if seconds == true then seconds = M.tweenSpeed() end

	if opts.vehicle then
		local model = M.vehicleModel()
		if seconds then
			local part = model.PrimaryPart or Inst.root(model)
			if not part then Guard.fail("that vehicle has no part to tween") end
			tween(part, frame, seconds)
		else
			model:PivotTo(frame)
		end
		if opts.breakVelocity ~= false then Inst.breakVelocity(model) end
		return frame
	end

	if opts.unseat then M.unseat() end

	local character = Character.require()
	local root = Character.requireRoot()

	if seconds then
		tween(root, frame, seconds)
	else
		place(character, root, frame)
	end
	if opts.breakVelocity ~= false then Inst.breakVelocity(character) end
	return frame
end

--[[ Zero your velocity, the legacy `breakvelocity`. ]]
function M.breakVelocity()
	local character = Character.get()
	if not character then return false end
	return Inst.breakVelocity(character)
end

-- ── players ─────────────────────────────────────────────────────────────────

--[[ Where to stand relative to `target`.

     `goto` (9105) put you three studs *in front* of them, facing them, and the
     tween / loop / bring commands used a flat Vector3(3, 1, 0) *beside* them
     with `distance` overriding the 3. The two look different in game and users
     are used to both, so passing `distance` selects the second form. ]]
function M.targetFrame(target, opts)
	opts = opts or {}
	local root = target:requireRoot()
	if opts.distance then
		return M.beside(root:GetPivot(), opts.distance)
	end
	local character = target.character
	local pivot = character and character:GetPivot() or root:GetPivot()
	local position = pivot.Position
	return CFrame.new(position + (pivot.LookVector * 3), position)
end

--[[ Streaming-enabled places unload distant geometry, so arriving before the
     server has streamed it means falling through the world. ]]
function M.requestStream(position, timeout)
	if not workspace.StreamingEnabled then return false end
	local player = Services.Players.LocalPlayer
	if not player or not position then return false end
	task.spawn(function()
		pcall(function() player:RequestStreamAroundAsync(position, timeout or 5) end)
	end)
	return true
end

function M.toTarget(target, opts)
	opts = opts or {}
	-- Stand up first so the destination is computed from where they are *now*
	-- rather than from where they were before the unseat's tenth of a second.
	-- The second call inside M.to is then a no-op.
	if opts.unseat then M.unseat() end
	if opts.stream then
		local root = target.root
		if root then
			M.requestStream(root.Position)
			local character = target.character
			if character then Inst.waitFor(character, "HumanoidRootPart", 5) end
		end
	end
	return M.to(M.targetFrame(target, opts), opts)
end

--[[ Legacy `clientbring` (9211): move *them* next to *you*, client side. ]]
function M.bring(target, opts)
	opts = opts or {}
	local humanoid = target.humanoid
	if humanoid and humanoid.SeatPart then
		humanoid.Sit = false
		task.wait()
	end
	-- Re-read both roots: the yield above can outlive either character.
	local myRoot = Character.requireRoot()
	local root = target:requireRoot()
	local frame = M.beside(myRoot.CFrame, opts.distance)
	root.CFrame = frame
	if opts.breakVelocity ~= false then Inst.breakVelocity(target.character) end
	return frame
end

--[[ Legacy `pulsetp` (9161): hop to them, wait, hop back. ]]
function M.pulse(target, opts)
	opts = opts or {}
	target:requireRoot()
	M.unseat()
	local start = Character.requireRoot().CFrame
	M.to(M.targetFrame(target, { distance = opts.distance or SIDE_STEP.X }),
		{ breakVelocity = false })
	task.wait(opts.seconds or 1)
	-- You may have died or respawned while we waited, in which case there is
	-- nothing left to bring back.
	if Character.root() then M.to(start) end
	return true
end

return M
