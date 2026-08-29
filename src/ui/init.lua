--[[═══════════════════════════════════════════════════════════════════════════
	ui/init · mounting the interface
	─────────────────────────────────────────────────────────────────────────
	The interface is optional. That is the whole point of this file: the command
	set, the keybinds and the chat hook all work whether or not the UI mounts,
	so a single broken panel -- or an executor that will not give us a ScreenGui
	-- degrades instead of taking the script down. In the legacy single-chunk
	script, any error in the 4,800 lines of interface code aborted everything
	after it, which included the entire command set.

	Each piece is imported optionally and mounted inside a contained call. What
	fails is recorded and reported by `;iydiag`.
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Log    = IY.import("core/log")
local Guard  = IY.import("core/guard")
local Notify = IY.import("core/notify")
local Bin    = IY.import("core/bin")

local M = {}

M.mounted = false
M.failures = {}
M.parts = {}

local bin = Bin.new("ui")

--[[ Mount one optional piece. Returns the module, or nil after recording why. ]]
local function piece(name, mount)
	local module, importError = IY:tryImport(name)
	if not module then
		M.failures[#M.failures + 1] = { name = name, error = importError, stage = "import" }
		return nil
	end
	local ok, err = Guard.call("ui:" .. name, function()
		if mount then return mount(module) end
		if type(module.mount) == "function" then return module.mount() end
		return true
	end)
	if not ok then
		M.failures[#M.failures + 1] = { name = name, error = err, stage = "mount" }
		return nil
	end
	M.parts[name] = module
	return module
end

--[[ Build the interface. Safe to call twice; returns true when the shell is up. ]]
function M.mount()
	if M.mounted then return true end
	M.failures = {}

	-- The shell is the one piece everything else needs.
	local Chrome = IY.import("ui/chrome")
	Chrome.mount()
	M.chrome = Chrome
	M.parts["ui/chrome"] = Chrome

	-- Colours before content, so nothing flashes in its default palette. The
	-- legacy script applied the theme once at line 13151, after all 13,000
	-- lines of construction.
	local Theme = IY.import("ui/theme")
	Guard.call("ui:theme", Theme.applyAll)
	M.parts["ui/theme"] = Theme

	-- Notifications: hand the renderer to core/notify, which has been buffering
	-- everything raised during boot.
	piece("ui/notify", function(module)
		module.mount(Chrome)
		Notify.setSink(module.render)
		return true
	end)

	piece("ui/cmdlist", function(module) return module.mount(Chrome) end)
	piece("ui/logs", function(module) return module.mount(Chrome) end)
	piece("ui/picker", function(module) return module.mount(Chrome) end)

	for _, name in ipairs({
		"ui/panels/keybinds",
		"ui/panels/aliases",
		"ui/panels/waypoints",
		"ui/panels/plugins",
		"ui/panels/topart",
		"ui/panels/reference",
		"ui/panels/events",
	}) do
		piece(name, function(module) return module.mount(Chrome) end)
	end

	-- Tell the input layer which TextBox is ours, so typing a command in it is
	-- not also treated as a chat message.
	local Input = IY:tryImport("cmd/input")
	if Input then Input.commandBar = Chrome.commandBar end

	bin:add(function()
		for name, module in pairs(M.parts) do
			if type(module.unmount) == "function" then
				Guard.call("ui:unmount:" .. name, module.unmount)
			end
		end
		M.parts = {}
	end)

	IY.onUnload(function() M.unmount() end)

	M.mounted = true

	if #M.failures > 0 then
		local names = {}
		for i = 1, #M.failures do names[#names + 1] = M.failures[i].name end
		Log.warn("ui", "%d interface piece(s) did not mount: %s",
			#M.failures, table.concat(names, ", "))
	end

	Guard.call("ui:intro", function()
		if type(Chrome.runIntro) == "function" then Chrome.runIntro() end
	end)

	return true
end

function M.unmount()
	if not M.mounted then return false end
	M.mounted = false
	Notify.setSink(nil)
	bin:empty()
	if M.chrome and type(M.chrome.unmount) == "function" then
		Guard.call("ui:chrome.unmount", M.chrome.unmount)
	end
	return true
end

--[[ Open the interface and focus the command bar. `;iy` and re-running the
     loader both land here. ]]
function M.focus()
	if not M.mounted then return false end
	if M.chrome and type(M.chrome.focusCommandBar) == "function" then
		M.chrome.focusCommandBar()
		return true
	end
	return false
end

function M.isMounted()
	return M.mounted
end

--[[ What did not load, for ;iydiag. ]]
function M.diagnostics()
	local out = {}
	for i = 1, #M.failures do
		out[#out + 1] = {
			name  = M.failures[i].name,
			stage = M.failures[i].stage,
			error = Guard.describe(M.failures[i].error),
		}
	end
	return { mounted = M.mounted, failures = out }
end

return M
