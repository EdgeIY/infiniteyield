--[[═══════════════════════════════════════════════════════════════════════════
	cmd/input · run commands from chat and keybinds
	─────────────────────────────────────────────────────────────────────────
	Two ways in, besides the command bar (which the UI owns):

	  · chat -- typing ";fly" in the game chat runs it
	  · keybinds -- see cmd/binds

	The legacy chat path had to work around Roblox filtering: `Player.Chatted`
	delivers the *filtered* message, so the script watched
	`UserInputService.TextBoxFocused`, recorded the raw text of whatever textbox
	you were typing in, and replayed it when `Chatted` fired. That hack is still
	needed for the legacy chat service, so it is ported here -- with the
	connections owned by a bin, and with the command bar itself excluded so
	typing a command there does not double-execute.

	On the modern TextChatService, `MessageReceived` gives us our own unfiltered
	text directly, so the hack is not used.
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Log      = IY.import("core/log")
local Bin      = IY.import("core/bin")
local Services = IY.import("core/services")
local Platform = IY.import("core/platform")
local Guard    = IY.import("core/guard")

local Players          = Services.Players
local UserInputService = Services.UserInputService

local M = {}

local bin = Bin.new("input")
local attached = false

-- Raw text of the textbox the user is typing in, and the last value that was
-- present when Return was pressed. Only used on the legacy chat path.
local lastTextBoxText = nil
local lastTextBoxConnection = nil
local lastEnteredText = nil

--[[ The textbox the UI uses for its own command bar, so we never treat its
     contents as a chat message. Set by the UI when it mounts. ]]
M.commandBar = nil

local function execute(text)
	local Dispatch = IY.import("cmd/dispatch")
	return Dispatch.handleInput(text, nil)
end

local function attachLegacyChat()
	bin:connect(UserInputService.TextBoxFocused, function(textbox)
		if lastTextBoxConnection then
			lastTextBoxConnection:Disconnect()
			lastTextBoxConnection = nil
		end
		if textbox == M.commandBar then
			lastTextBoxText = nil
			return
		end
		lastTextBoxText = textbox.Text
		lastTextBoxConnection = textbox:GetPropertyChangedSignal("Text"):Connect(function()
			-- Ignore the change caused by pressing Return, which clears the box.
			if not (UserInputService:IsKeyDown(Enum.KeyCode.Return)
				or UserInputService:IsKeyDown(Enum.KeyCode.KeypadEnter)) then
				lastTextBoxText = textbox.Text
			end
		end)
	end)
	bin:add(function()
		if lastTextBoxConnection then lastTextBoxConnection:Disconnect() end
		lastTextBoxConnection = nil
	end)

	bin:connect(UserInputService.InputBegan, function(input, gameProcessed)
		if not gameProcessed then return end
		if input.KeyCode == Enum.KeyCode.Return or input.KeyCode == Enum.KeyCode.KeypadEnter then
			lastEnteredText = lastTextBoxText
		end
	end)

	bin:connect(Players.LocalPlayer.Chatted, function()
		task.wait()
		local message = lastEnteredText
		lastEnteredText = nil
		if message then execute(message) end
	end)
end

local function attachModernChat()
	local TextChatService = Services.get("TextChatService")
	if not TextChatService then return end
	bin:connect(TextChatService.MessageReceived, function(message)
		local source = message.TextSource
		if not source then return end
		if source.UserId ~= Players.LocalPlayer.UserId then return end
		execute(message.Text)
	end)
end

--[[ Attach every input path. Safe to call twice. ]]
function M.attach()
	if attached then return false end
	attached = true

	if Platform.isLegacyChat then
		attachLegacyChat()
	else
		attachModernChat()
	end

	IY.import("cmd/binds").attach()

	IY.onUnload(function()
		bin:destroy()
		attached = false
	end)
	return true
end

function M.detach()
	bin:empty()
	attached = false
end

return M
