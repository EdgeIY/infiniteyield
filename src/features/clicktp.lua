--[[═══════════════════════════════════════════════════════════════════════════
	features/clicktp · teleport to, or delete, whatever you click
	─────────────────────────────────────────────────────────────────────────
	    ClickTP.teleport()            one hop to the mouse's hit position
	    ClickTP.deleteTarget()        destroy the instance under the mouse
	    ClickTP.setMode("teleport", true)   arm the shared click handler
	    ClickTP.tool                  the ;tptool feature

	Legacy equivalent: source.ref.lua 6265-6310 plus the `mouseteleport`,
	`tptool` and `clickdelete` commands at 10313-10347.

	There, `clickteleport` and `clickdelete` were not commands at all -- they
	only printed "Go to Settings > Keybinds > Add to set up click teleport", and
	the real work hung off the keybind system's own global `Button1Down`
	handler, which re-scanned every saved bind on every single left click and
	called `UserInputService:IsKeyDown(Enum.KeyCode[input:sub(14)])` on strings
	that were not always key names.

	Here both are ordinary toggles sharing exactly one `Button1Down` connection,
	owned by a feature bin. `;clicktp` and `;clickdel` still exist as hidden
	one-shot commands so keybinds saved against those legacy names keep working.

	`mouseteleport`, `tptool` and `clicktp` all use the one primitive below --
	the legacy `clicktpFunc` body, which unseats you and lands you on top of the
	surface. The two mouse commands previously kept your rotation and used a
	flat three studs instead.
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Feature   = IY.import("features/feature")
local Character = IY.import("core/character")
local Services  = IY.import("core/services")
local Guard     = IY.import("core/guard")
local Inst      = IY.import("core/util/instances")

local M = {}

-- ── the mouse ───────────────────────────────────────────────────────────────

local cached = nil

--[[ The LocalPlayer's Mouse, memoised -- the legacy global `IYMouse` (line 96).
     The object outlives every respawn, so one lookup is enough. ]]
function M.mouse()
	if cached then return cached end
	local player = Services.Players.LocalPlayer
	if not player then return nil end
	local ok, result = pcall(function() return player:GetMouse() end)
	if ok then cached = result end
	return cached
end

function M.hit()
	local mouse = M.mouse()
	if not mouse then return nil end
	local ok, hit = pcall(function() return mouse.Hit end)
	if ok then return hit end
	return nil
end

-- ── the primitives ──────────────────────────────────────────────────────────

--[[ One hop to where the mouse is pointing, facing the surface you clicked.
     Ported from `clicktpFunc` (6265-6286) with the pcall-swallow-everything
     wrapper replaced by real guards. ]]
function M.teleport()
	local humanoid = Character.humanoid()
	if humanoid and humanoid.SeatPart then
		humanoid.Sit = false
		task.wait(0.1)
	end

	local hit = M.hit()
	if not hit then Guard.fail("your mouse is not pointing at anything") end

	-- Re-read after the unseat: that yield can outlive the character.
	local root = Character.requireRoot()
	humanoid = Character.humanoid()

	local rootPosition = root.Position
	local hitPosition = hit.Position
	local frame = CFrame.new(hitPosition,
		Vector3.new(rootPosition.X, hitPosition.Y, rootPosition.Z))
		* CFrame.Angles(0, math.pi, 0)

	local lift = 4
	if humanoid and humanoid.HipHeight > 0 then lift = humanoid.HipHeight + 1 end

	root.CFrame = frame + Vector3.new(0, lift, 0)
	Inst.breakVelocity(Character.get())
	return root.CFrame
end

--[[ Destroy the instance under the mouse (legacy line 6302). ]]
function M.deleteTarget()
	local mouse = M.mouse()
	local target = mouse and mouse.Target or nil
	if not target then Guard.fail("your mouse is not pointing at anything") end
	target:Destroy()
	return target
end

-- ── the shared click handler ────────────────────────────────────────────────

local actions = Feature.new("clickactions", {
	describe = "click teleport / click delete",

	start = function(self)
		local mouse = M.mouse()
		if not mouse then Guard.fail("your executor did not provide a mouse") end

		-- Exactly one connection, whichever combination of modes is armed.
		self.bin:connect(mouse.Button1Down, function()
			if self:option("teleport", false) then
				Guard.call("clicktp", M.teleport)
			end
			if self:option("delete", false) then
				Guard.call("clickdelete", M.deleteTarget)
			end
		end)
	end,
})

M.actions = actions

--[[ Arm or disarm one mode. The connection exists while either is armed. ]]
function M.setMode(mode, enabled)
	actions:configure({ [mode] = enabled == true })
	local wanted = actions:option("teleport", false) or actions:option("delete", false)
	if wanted then
		if not actions:isRunning() then actions:start(actions.opts) end
	else
		actions:stop()
	end
	return enabled == true
end

function M.mode(name)
	return actions:option(name, false) == true
end

-- ── the teleport tool ───────────────────────────────────────────────────────

--[[ Legacy `tptool` (10322) parented a Tool to the Backpack and connected
     Activated with no way to remove either -- the tool survived `;unloadiy`
     and a second `;tptool` gave you two. Both live in the bin now, and the
     tool is handed out again after a respawn replaces your Backpack. ]]
local tool = Feature.new("tptool", {
	command  = "tptool",
	reapply  = true,
	describe = "teleport tool",

	start = function(self)
		local player = Services.Players.LocalPlayer
		local backpack = player and player:FindFirstChildOfClass("Backpack")
		if not backpack then Guard.fail("you have no backpack right now") end

		local instance = self.bin:add(Instance.new("Tool"))
		instance.Name = "Teleport Tool"
		instance.RequiresHandle = false
		self.bin:connect(instance.Activated, function()
			Guard.call("tptool", M.teleport)
		end)
		instance.Parent = backpack
	end,
})

M.tool = tool

return M
