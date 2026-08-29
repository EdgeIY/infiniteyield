--[[═══════════════════════════════════════════════════════════════════════════
	features/autokeypress · hold a key down for you
	─────────────────────────────────────────────────────────────────────────
	Legacy source.ref.lua 12960-13065: a table of Windows virtual key codes and
	a `repeat wait() keypress(code) ... until` loop on the command thread. Kept:
	the key names, the two delays and the [backspace]+[=] cancel chord. Changed:

	  · the loop is a Sched loop in the feature bin, so `;breakloops` and
	    `;unloadiy` stop it. Legacy could only be stopped by the chord or by
	    `;unautokeypress` setting a global the loop happened to re-read.
	  · the key is released on the way out no matter how the feature ends.
	    Legacy released it only on the chord path (13056) -- so
	    `;unautokeypress` left the key held down.
	  · executors without `keypress` fall back to VirtualInputManager rather
	    than refusing outright.
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Feature  = IY.import("features/feature")
local Env      = IY.import("core/env")
local Services = IY.import("core/services")
local Sched    = IY.import("core/scheduler")
local Guard    = IY.import("core/guard")
local Str      = IY.import("core/util/strings")

local UserInputService = Services.UserInputService

local M = {}

--[[ The legacy keycodeMap (12960), verbatim, plus the five spellings at the
     bottom that it was missing and that people kept trying. ]]
local VK = {
	["0"] = 0x30, ["1"] = 0x31, ["2"] = 0x32, ["3"] = 0x33, ["4"] = 0x34,
	["5"] = 0x35, ["6"] = 0x36, ["7"] = 0x37, ["8"] = 0x38, ["9"] = 0x39,
	a = 0x41, b = 0x42, c = 0x43, d = 0x44, e = 0x45, f = 0x46, g = 0x47,
	h = 0x48, i = 0x49, j = 0x4A, k = 0x4B, l = 0x4C, m = 0x4D, n = 0x4E,
	o = 0x4F, p = 0x50, q = 0x51, r = 0x52, s = 0x53, t = 0x54, u = 0x55,
	v = 0x56, w = 0x57, x = 0x58, y = 0x59, z = 0x5A,
	enter = 0x0D, shift = 0x10, ctrl = 0x11, alt = 0x12, pause = 0x13,
	capslock = 0x14, spacebar = 0x20, space = 0x20, pageup = 0x21,
	pagedown = 0x22, ["end"] = 0x23, home = 0x24, left = 0x25, up = 0x26,
	right = 0x27, down = 0x28, insert = 0x2D, delete = 0x2E,
	f1 = 0x70, f2 = 0x71, f3 = 0x72, f4 = 0x73, f5 = 0x74, f6 = 0x75,
	f7 = 0x76, f8 = 0x77, f9 = 0x78, f10 = 0x79, f11 = 0x7A, f12 = 0x7B,
	["return"] = 0x0D, control = 0x11, tab = 0x09, backspace = 0x08,
	escape = 0x1B,
}
M.codes = VK
--[[ VirtualInputManager wants an Enum.KeyCode, not a virtual key code. Most of
     the names above capitalise straight onto one; these are the ones that do
     not. ]]
local ENUM_NAMES = {
	["0"] = "Zero", ["1"] = "One", ["2"] = "Two", ["3"] = "Three",
	["4"] = "Four", ["5"] = "Five", ["6"] = "Six", ["7"] = "Seven",
	["8"] = "Eight", ["9"] = "Nine",
	enter = "Return", spacebar = "Space", ctrl = "LeftControl",
	control = "LeftControl", alt = "LeftAlt", shift = "LeftShift",
	capslock = "CapsLock", pageup = "PageUp", pagedown = "PageDown",
}

--[[ The canonical lowercase name for a key, or nil when we cannot press it. ]]
function M.normalise(name)
	if type(name) ~= "string" then return nil end
	local key = Str.lower(Str.trim(name))
	if VK[key] then return key end
	return nil
end

function M.codeFor(name)
	local key = M.normalise(name)
	if not key then return nil end
	return VK[key]
end

local function keyCodeFor(key)
	local enumName = ENUM_NAMES[key]
	if not enumName then
		enumName = string.upper(string.sub(key, 1, 1)) .. string.sub(key, 2)
	end
	local ok, item = pcall(function() return Enum.KeyCode[enumName] end)
	if ok then return item end
	return nil
end

--[[ A press and a release function taking the virtual key code, or nil. ]]
local function presser(key)
	local press, release = Env.fn.keypress, Env.fn.keyrelease
	if press and release then
		return function(code) press(code) end,
			function(code) release(code) end,
			"keypress"
	end

	local manager = Services.get("VirtualInputManager")
	local keyCode = manager and keyCodeFor(key)
	if manager and keyCode then
		-- SendKeyEvent needs an elevated thread on most executors; when it is
		-- refused the loop's own error containment reports it once.
		return function() manager:SendKeyEvent(true, keyCode, false, game) end,
			function() manager:SendKeyEvent(false, keyCode, false, game) end,
			"VirtualInputManager"
	end
	return nil
end
M.presser = presser
function M.available(key)
	return (presser(key or "space")) ~= nil
end

--[[ [backspace] + [=] together, the legacy panic chord (13044). ]]
local function isCancelChord(input)
	local code = input.KeyCode
	if code == Enum.KeyCode.Backspace then
		return UserInputService:IsKeyDown(Enum.KeyCode.Equals)
	end
	if code == Enum.KeyCode.Equals then
		return UserInputService:IsKeyDown(Enum.KeyCode.Backspace)
	end
	return false
end

local feature = Feature.new("autokeypress", {
	command  = "autokeypress",
	describe = "auto-pressing a key",

	start = function(self, opts)
		local key = M.normalise(opts.key)
		if not key then
			Guard.fail("'%s' is not a key I know", tostring(opts.key))
		end
		local code = VK[key]
		local press, release, backend = presser(key)
		if not press then Guard.fail("%s", Env.explain("keypress")) end
		self.state.key, self.state.backend = key, backend

		local downDelay = opts.delay or 0.1
		local upDelay = opts.hold or 0.1

		-- First in, last out: the key comes up however the feature ends.
		self.bin:add(function() pcall(release, code) end)

		self.bin:connect(UserInputService.InputBegan, function(input, processed)
			if processed then return end
			if isCancelChord(input) then self:stop() end
		end)

		self.bin:add(Sched.interval("autokeypress.loop", downDelay, function()
			press(code)
			task.wait(upDelay)
			release(code)
		end))
	end,
})

M.feature = feature

function M.start(opts) return feature:start(opts or {}) end
function M.stop() return feature:stop() end
function M.toggle(opts) return feature:toggle(opts or {}) end
function M.isRunning() return feature:isRunning() end

function M.key()
	return feature.state and feature.state.key or nil
end

return M
