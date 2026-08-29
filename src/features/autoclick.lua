--[[═══════════════════════════════════════════════════════════════════════════
	features/autoclick · hold the mouse button down for you
	─────────────────────────────────────────────────────────────────────────
	Legacy source.ref.lua 12246-12277. The loop and the cancel chord are the
	same -- press, wait, release, wait, and [backspace]+[=] together to stop --
	with three differences:

	  · the loop ran on the command thread as `repeat wait() ... until
	    autoclicking == false`, so `;breakloops` could not reach it and
	    `;unloadiy` left it clicking. It is a Sched loop in the feature bin now.
	  · a cancelled or unloaded autoclicker used to leave the button *held*,
	    because the flag was only read between a press and its release. The bin
	    releases on the way out.
	  · legacy required `mouse1press` and `mouse1release` and refused to run
	    otherwise. Three back ends are tried in order of fidelity, ending with
	    VirtualUser -- the same injector legacy used for its anti-AFK click
	    (8876), which needs the window focused but is available everywhere.
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Feature  = IY.import("features/feature")
local Env      = IY.import("core/env")
local Services = IY.import("core/services")
local Sched    = IY.import("core/scheduler")
local Guard    = IY.import("core/guard")

local UserInputService = Services.UserInputService

local M = {}

local ORIGIN = Vector2.new(0, 0)

--[[ A press function and a release function, or nil when the client cannot
     click at all. ]]
local function clicker()
	local press, release = Env.fn.mouse1press, Env.fn.mouse1release
	if press and release then
		return function() press() end, function() release() end, "mouse1press"
	end

	-- One-shot click: nothing to release, so the "hold" delay is ignored.
	local click = Env.fn.mouse1click
	if click then
		return function() click() end, function() end, "mouse1click"
	end

	local virtual = Services.get("VirtualUser")
	if virtual then
		return function()
			virtual:CaptureController()
			virtual:Button1Down(ORIGIN)
		end, function()
			virtual:Button1Up(ORIGIN)
		end, "VirtualUser"
	end
	return nil
end
M.clicker = clicker

function M.available()
	return (clicker()) ~= nil
end

--[[ [backspace] + [=] together, the legacy panic chord (12257). Shared, by
     copy, with features/autokeypress: two lines is not worth a dependency
     between two otherwise unrelated features. ]]
local function isCancelChord(input)
	local key = input.KeyCode
	if key == Enum.KeyCode.Backspace then
		return UserInputService:IsKeyDown(Enum.KeyCode.Equals)
	end
	if key == Enum.KeyCode.Equals then
		return UserInputService:IsKeyDown(Enum.KeyCode.Backspace)
	end
	return false
end
M.isCancelChord = isCancelChord

local feature = Feature.new("autoclick", {
	command  = "autoclick",
	describe = "auto-clicking",

	start = function(self, opts)
		local press, release, backend = clicker()
		if not press then Guard.fail("%s", Env.explain("mouse1click")) end
		self.state.backend = backend

		local downDelay = opts.delay or 0.1
		local upDelay = opts.hold or 0.1

		-- First in, last out: whatever happens, the button is not left held.
		self.bin:add(function() pcall(release) end)

		self.bin:connect(UserInputService.InputBegan, function(input, processed)
			if processed then return end
			if isCancelChord(input) then self:stop() end
		end)

		self.bin:add(Sched.interval("autoclick.loop", downDelay, function()
			press()
			task.wait(upDelay)
			release()
		end))
	end,
})

M.feature = feature

function M.start(opts) return feature:start(opts or {}) end
function M.stop() return feature:stop() end
function M.toggle(opts) return feature:toggle(opts or {}) end
function M.isRunning() return feature:isRunning() end

function M.backend()
	return feature.state and feature.state.backend or nil
end

return M
