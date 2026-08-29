--[[═══════════════════════════════════════════════════════════════════════════
	features/prompts · the Roblox client's own prompts and overlays
	─────────────────────────────────────────────────────────────────────────
	Three things the client puts on screen that IY commands take over:

	  purchase prompts   noprompts / showprompts, source.ref.lua 8896-8902
	  the rig prompt     promptr6 / promptr15, source.ref.lua 8904-8921
	  the network pause  antigameplaypaused, source.ref.lua 7928-7940

	  · both prompt commands wrote `COREGUI.PurchasePromptApp.Enabled` directly.
	    Indexing it raises on a client where the app has not loaded, and there was
	    no record of the original, so `;showprompts` guessed `true`. The value goes
	    through core/snapshot and the lookup is nil-checked.
	  · `promptNewRig` (8904) indexed `speaker.Character:FindFirstChildWhichIsA`
	    with no character check, then blocked on `PromptSaveAvatarCompleted:Wait()`
	    forever when the prompt was dismissed without a result. Bounded wait,
	    contained connection, real character check.
	  · `antigameplaypaused` kept its connection in a global, so the off-command
	    threw when the on-command had never run, and line 7935 destroyed the
	    existing overlay with an unguarded index -- which raised whenever the
	    client was *not* paused, i.e. almost always, leaving the handler connected
	    while the command reported failure. It is a feature with a bin now.
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Feature   = IY.import("features/feature")
local Bin       = IY.import("core/bin")
local Character = IY.import("core/character")
local Guard     = IY.import("core/guard")
local Sched     = IY.import("core/scheduler")
local Services  = IY.import("core/services")
local Snapshot  = IY.import("core/snapshot")

local TAG = "coregui"
local PAUSE_NAME = "CoreScripts/NetworkPause"
local PROMPT_TIMEOUT = 60

local M = {}

local function coreGui()
	local service = Services.get("CoreGui")
	if not service then Guard.fail("your client does not expose CoreGui") end
	return service
end

-- ── purchase prompts ────────────────────────────────────────────────────────

local function purchaseApp()
	local app = coreGui():FindFirstChild("PurchasePromptApp")
	if not app then Guard.fail("this client has not loaded the purchase prompt UI") end
	return app
end

--[[ Off records the original and writes false; on prefers the recorded value and
     only falls back to `true` when nothing was ever recorded. ]]
function M.setPurchasePrompts(enabled)
	local app = purchaseApp()
	if not enabled then
		local ok, reason = Snapshot.set(app, "Enabled", false, TAG)
		if not ok then
			Guard.fail("could not switch the purchase prompts off (%s)", tostring(reason))
		end
		return true
	end
	if Snapshot.isModified(app, "Enabled") then
		local ok, reason = Snapshot.restore(app, "Enabled")
		if not ok then
			Guard.fail("could not put the purchase prompts back (%s)", tostring(reason))
		end
		return true
	end
	if not pcall(function() app.Enabled = true end) then
		Guard.fail("the purchase prompt UI would not re-enable")
	end
	return true
end

-- ── the rig prompt ──────────────────────────────────────────────────────────

--[[ Ask Roblox to save the avatar under a different rig, and respawn when it
     says yes. Returns true, or false plus a reason the command can report. ]]
function M.promptRig(rigName)
	local service = Services.get("AvatarEditorService")
	if not service then Guard.fail("your client has no AvatarEditorService") end
	local okRig, rig = pcall(function() return Enum.HumanoidRigType[rigName] end)
	if not okRig or not rig then Guard.fail("'%s' is not a rig type", tostring(rigName)) end

	local humanoid = Character.requireHumanoid()
	local description = Guard.try(function() return humanoid.HumanoidDescription end)
	if not description then
		Guard.fail("your character has no HumanoidDescription to save")
	end
	local completed = Guard.try(function() return service.PromptSaveAvatarCompleted end)
	if not completed then Guard.fail("your client cannot report the prompt result") end

	local bin = Bin.new("prompts.rig")
	local outcome = nil
	bin:connect(completed, function(result) outcome = result end)

	local okPrompt, err = pcall(function() service:PromptSaveAvatar(description, rig) end)
	if not okPrompt then
		bin:destroy()
		Guard.fail("Roblox refused the avatar prompt (%s)", tostring(err))
	end

	local answered = Sched.waitUntil(function() return outcome ~= nil end, PROMPT_TIMEOUT)
	bin:destroy()
	if not answered then return false, "you did not answer the prompt" end
	if outcome ~= Enum.AvatarPromptResult.Success then
		return false, "the prompt was not accepted"
	end

	-- Legacy ran `reset` here (8910): the respawn is what puts the new rig on.
	local respawned, reason = Character.respawn()
	if not respawned then return false, tostring(reason) end
	return true
end

-- ── the network pause overlay ───────────────────────────────────────────────

local gameplayPaused = Feature.new("antigameplaypaused", {
	command  = "antigameplaypaused",
	describe = "the network pause overlay removed",

	start = function(self)
		local robloxGui = coreGui():FindFirstChild("RobloxGui")
		if not robloxGui then Guard.fail("this client has no RobloxGui to watch") end

		self.bin:connect(robloxGui.ChildAdded, function(child)
			if child.Name == PAUSE_NAME then
				pcall(function() child:Destroy() end)
			end
		end)

		-- Whatever is already on screen, if anything: legacy indexed this child
		-- directly and raised when it was absent.
		local existing = robloxGui:FindFirstChild(PAUSE_NAME)
		if existing then
			pcall(function() existing:Destroy() end)
			self.state.removed = true
		end
	end,
})

M.gameplayPaused = gameplayPaused

return M
