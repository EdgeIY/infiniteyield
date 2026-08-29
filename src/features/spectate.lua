--[[═══════════════════════════════════════════════════════════════════════════
	features/spectate · watch someone else's camera
	─────────────────────────────────────────────────────────────────────────
	One subject at a time -- a player's humanoid, or a part by name for
	`;viewpart`. That is not a reduction in capability: the legacy `view` looped
	over every matched player and created a `viewDied` / `viewChanged` connection
	pair per iteration while keeping only the last, so `;view all` leaked N-1
	connections and silently only ever watched the last player in the list.

	Three more legacy problems fixed:

	  · `unview` restored `CameraSubject` to `speaker.Character` -- a Model, where
	    the property wants a Humanoid or a BasePart -- so ending a spectate could
	    leave the camera adrift. The original subject comes back through
	    core/snapshot, and if what was recorded has since been destroyed (you
	    respawned while spectating) the camera is re-pointed at your humanoid.
	  · the respawn handler did `repeat wait() until Players[v].Character` inside
	    a connection, which spun forever if the player never respawned, and then
	    assigned the character model rather than the new humanoid.
	  · nothing stopped when the player you were watching left the server.
	    `PlayerRemoving` ends the spectate now.

	Legacy equivalent: source.ref.lua lines 8277-8323.
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Feature   = IY.import("features/feature")
local Services  = IY.import("core/services")
local Character = IY.import("core/character")
local Snapshot  = IY.import("core/snapshot")
local Guard     = IY.import("core/guard")
local Inst      = IY.import("core/util/instances")
local Str       = IY.import("core/util/strings")
local Camera    = IY.import("features/camera")

local Players = Services.Players

local M = {}

local TAG = "spectate"

--[[ First BasePart in the workspace with this name. The legacy `viewpart`
     assigned every match in turn with a 0.1s wait between them, so the one you
     ended up watching was whichever happened to be last. ]]
function M.findPart(name)
	local needle = Str.lower(Str.trim(tostring(name or "")))
	if needle == "" then return nil end
	local ok, descendants = pcall(function() return workspace:GetDescendants() end)
	if not ok then return nil end
	for i = 1, #descendants do
		local instance = descendants[i]
		if Str.lower(instance.Name) == needle and instance:IsA("BasePart") then
			return instance
		end
	end
	return nil
end

-- ── feature ─────────────────────────────────────────────────────────────────

local function subjectOf(opts)
	if opts.part then
		local part = opts.part
		if not part.Parent then Guard.fail("that part no longer exists") end
		return part, part.Name
	end

	local target = opts.target
	if not target then Guard.fail("nobody to spectate") end
	local subject = target.humanoid or target.root
	if not subject then Guard.fail("%s has no character right now", target.name) end
	return subject, target:label()
end

local feature = Feature.new("spectate", {
	command   = "view",
	exclusive = { "freecam" },
	describe  = "spectating",

	start = function(self, opts)
		local subject, label = subjectOf(opts)
		local session = { subject = subject, label = label }
		self.state.session = session

		-- One branch per camera instance, so swapping cameras restores the old
		-- one and rebinds to the new one without touching the rest of the bin.
		local cameraBin = self.bin:branch("camera")

		local function attach(camera)
			cameraBin:empty()
			if not camera or not session.subject or not session.subject.Parent then return end

			Snapshot.set(camera, "CameraSubject", session.subject, TAG)
			cameraBin:add(function()
				Snapshot.restore(camera, "CameraSubject")
				local restored = camera.CameraSubject
				if not restored or not restored.Parent then
					pcall(function() camera.CameraSubject = Character.humanoid() end)
				end
			end)

			-- Games (and your own respawn) re-point the camera at you; put it back.
			cameraBin:onChange(camera, "CameraSubject", function()
				local wanted = session.subject
				if wanted and wanted.Parent and camera.CameraSubject ~= wanted then
					camera.CameraSubject = wanted
				end
			end)
		end

		attach(Camera.require())

		self.bin:onChange(workspace, "CurrentCamera", function()
			attach(Camera.get())
		end)

		local player = opts.target and opts.target.player or nil
		if player then
			self.bin:connect(player.CharacterAdded, function(character)
				local humanoid = Inst.waitFor(character, "Humanoid", 10)
					or Inst.waitFor(character, "HumanoidRootPart", 10)
				if not humanoid or not self:isRunning() then return end
				session.subject = humanoid
				attach(Camera.get())
			end)

			self.bin:connect(Players.PlayerRemoving, function(leaving)
				if leaving ~= player then return end
				self:stop()
			end)
		elseif opts.part then
			self.bin:connect(opts.part.AncestryChanged, function()
				if not opts.part:IsDescendantOf(game) then self:stop() end
			end)
		end
	end,
})

M.feature = feature

--[[ `opts.target` is a Target to watch; `opts.part` a BasePart. ]]
function M.start(opts) return feature:start(opts or {}) end
function M.stop() return feature:stop() end
function M.isRunning() return feature:isRunning() end

function M.startTarget(target) return feature:start({ target = target }) end

--[[ Spectate the first workspace part with this name. ]]
function M.startPart(name)
	local part = M.findPart(name)
	if not part then Guard.fail("no part in the workspace is called '%s'", tostring(name)) end
	feature:start({ part = part })
	return part
end

--[[ What is being watched, for the notification -- nil when idle. ]]
function M.label()
	local session = feature:isRunning() and feature.state.session or nil
	return session and session.label or nil
end

return M
