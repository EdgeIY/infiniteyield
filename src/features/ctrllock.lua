--[[═══════════════════════════════════════════════════════════════════════════
	features/ctrllock · move shift lock onto Left Control
	─────────────────────────────────────────────────────────────────────────
	The default camera scripts keep the shift-lock key in a StringValue called
	`BoundKeys` inside PlayerModule.CameraModule.MouseLockController, and watch
	it for changes -- so writing a new key rebinds it live.

	Two fixes over the legacy pair (12708-12734):

	  · `unctrllock` wrote a hard-coded "LeftShift". Any game that shipped a
	    different key, or a player who had already rebound it, got the Roblox
	    default handed back instead of what was there. Snapshot records the
	    original once and restores exactly that.
	  · the whole PlayerModule path was a `WaitForChild` chain with no timeout,
	    so in the many games that replace the camera scripts the command thread
	    simply never returned. Every step is checked, and a missing one is a
	    clean message.

	Legacy equivalent: source.ref.lua 12708-12734.
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Feature   = IY.import("features/feature")
local Character = IY.import("core/character")
local Snapshot  = IY.import("core/snapshot")
local Guard     = IY.import("core/guard")
local Inst      = IY.import("core/util/instances")

local M = {}

local TAG = "ctrllock"
local KEY = "LeftControl"

local function mouseLockController()
	local player = Character.player
	if not player then Guard.fail("there is no local player") end
	local scripts    = Inst.waitFor(player, "PlayerScripts", 2)
	local module     = scripts and Inst.waitFor(scripts, "PlayerModule", 2)
	local cameras    = module and Inst.waitFor(module, "CameraModule", 2)
	local controller = cameras and Inst.waitFor(cameras, "MouseLockController", 2)
	if not controller then
		Guard.fail("this game replaced the default camera scripts, so there is no shift-lock key to rebind")
	end
	return controller
end

M.controller = mouseLockController

local feature = Feature.new("ctrllock", {
	command  = "ctrllock",
	describe = "shift lock bound to Left Control",

	start = function(self)
		local controller = mouseLockController()
		local boundKeys = Guard.try(function() return controller:FindFirstChild("BoundKeys") end)

		if boundKeys then
			local ok, reason = Snapshot.set(boundKeys, "Value", KEY, TAG)
			if not ok then
				Guard.fail("could not rebind the shift-lock key (%s)", tostring(reason))
			end
			self.state.previous = Snapshot.original(boundKeys, "Value")
			self.bin:add(function() Snapshot.restore(boundKeys, "Value") end)
			return
		end

		--[[ No BoundKeys at all: legacy created one (12715-12719) and so do we,
		     except the bin owns it, so stopping removes it again rather than
		     leaving a "LeftShift" value behind in a game that never had one.
		     The controller only reads a value it did not see at init if it
		     re-runs, which is the legacy behaviour kept as-is. ]]
		self.bin:instance("StringValue", {
			Name = "BoundKeys",
			Value = KEY,
			Parent = controller,
		})
	end,
})

M.feature = feature

function M.start() return feature:start() end
function M.stop() return feature:stop() end
function M.toggle() return feature:toggle() end
function M.isRunning() return feature:isRunning() end

return M
