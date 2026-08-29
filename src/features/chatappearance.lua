--[[═══════════════════════════════════════════════════════════════════════════
	features/chatappearance · bubble chat, the chat window, and dark chat
	─────────────────────────────────────────────────────────────────────────
	Replaces source.ref.lua 10732-10754 (bubblechat / unbubblechat / chatwindow /
	unchatwindow) and 10756-10785 (darkchat).

	Two problems being fixed here:

	  · `chatwindow` wrote `TextChatService.ChatWindowConfiguration.Enabled`
	    (10749) with no lookup. Under the legacy chat pipeline that child does
	    not exist, so the command threw -- and the throw was swallowed, so the
	    user saw nothing happen. Every configuration object is resolved with
	    FindFirstChildOfClass and a missing one is reported.
	  · `darkchat` rewrote nineteen colour and transparency properties across
	    three configuration objects and had **no** off command: the only way back
	    to the game's own chat colours was to rejoin. Every write goes through
	    core/snapshot under the "darkchat" tag, so `undarkchat` (and ;unloadiy,
	    through snapshot's own unload hook) restores exactly what was there.

	bubblechat and chatwindow are deliberately *not* snapshotted: `unbubblechat`
	means "off", not "back to whatever the game wanted", which is what legacy did
	and what the name promises.
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Feature  = IY.import("features/feature")
local Guard    = IY.import("core/guard")
local Platform = IY.import("core/platform")
local Services = IY.import("core/services")
local Snapshot = IY.import("core/snapshot")

local M = {}

local TAG = "darkchat"
M.TAG = TAG

local BLACK = Color3.fromRGB(0, 0, 0)
local WHITE = Color3.fromRGB(255, 255, 255)

--[[ A TextChatService configuration object, or nil in a game on the legacy
     pipeline (where none of them exist). ]]
local function configOf(className)
	local service = Services.get("TextChatService")
	if not service then return nil end
	return Guard.try(function() return service:FindFirstChildOfClass(className) end)
end
M.configOf = configOf

-- ── bubble chat ─────────────────────────────────────────────────────────────

--[[ Bubble chat lives in two places: the Chat service's deprecated flag on the
     legacy pipeline (10733) and BubbleChatConfiguration under TextChatService
     (10736). ]]
function M.setBubbles(enabled)
	local value = enabled == true

	if Platform.isLegacyChat then
		local chat = Services.get("Chat")
		if not chat then Guard.fail("this game's chat cannot be used") end
		if not Guard.call("chatappearance.bubbles", function()
			chat.BubbleChatEnabled = value
		end) then
			Guard.fail("this game does not allow bubble chat to be changed")
		end
		return value
	end

	local config = configOf("BubbleChatConfiguration")
	if not config then
		Guard.fail("this game's chat has no bubble chat setting to change")
	end
	if not Guard.call("chatappearance.bubbles", function()
		config.Enabled = value
	end) then
		Guard.fail("this game does not allow bubble chat to be changed")
	end
	return value
end

-- ── the chat window ─────────────────────────────────────────────────────────

--[[ TextChatService only. Legacy had no legacy-chat branch here at all, so the
     command threw on the old pipeline instead of saying why. ]]
function M.setWindow(enabled)
	local value = enabled == true
	local config = configOf("ChatWindowConfiguration")
	if not config then
		Guard.fail("this game's chat has no chat window setting to change")
	end
	if not Guard.call("chatappearance.window", function()
		config.Enabled = value
	end) then
		Guard.fail("this game does not allow the chat window to be changed")
	end
	return value
end

-- ── dark chat ───────────────────────────────────────────────────────────────

--[[ Legacy 10756-10785, same objects, same properties, same order.
     `Color3.fromRGB()` with no arguments is black; written out here. ]]
local DARK = {
	{ "BubbleChatConfiguration", {
		{ "Enabled", true },
		{ "BackgroundColor3", BLACK },
		{ "BackgroundTransparency", 0.3 },
		{ "TailVisible", true },
		{ "TextColor3", WHITE },
	} },
	{ "ChatWindowConfiguration", {
		{ "Enabled", true },
		{ "BackgroundColor3", BLACK },
		{ "BackgroundTransparency", 0.3 },
		{ "TextColor3", WHITE },
		{ "TextStrokeColor3", BLACK },
		{ "TextStrokeTransparency", 0.5 },
	} },
	{ "ChatInputBarConfiguration", {
		{ "Enabled", true },
		{ "BackgroundColor3", BLACK },
		{ "BackgroundTransparency", 0.5 },
		{ "PlaceholderColor3", WHITE },
		{ "TextColor3", WHITE },
		{ "TextStrokeColor3", BLACK },
		{ "TextStrokeTransparency", 0.5 },
	} },
}

local dark = Feature.new("darkchat", {
	command  = "darkchat",
	describe = "dark chat colours",

	start = function(self)
		-- Registered before the first write, so a partial application is undone
		-- even if the feature fails half way through.
		self.bin:add(function() Snapshot.restoreTag(TAG) end)

		local changed, found = 0, 0
		for i = 1, #DARK do
			local config = configOf(DARK[i][1])
			if config then
				found = found + 1
				local properties = DARK[i][2]
				for j = 1, #properties do
					if Snapshot.set(config, properties[j][1], properties[j][2], TAG) then
						changed = changed + 1
					end
				end
			end
		end
		if found == 0 then
			Guard.fail("this game has no TextChatService chat to restyle")
		end
		self.state.changed = changed
	end,
})

M.darkFeature = dark

--[[ Returns how many properties were actually restyled, which is the honest
     number to report: a client missing one of the three configuration objects
     still gets the other two. ]]
function M.startDark()
	dark:start()
	return dark.state.changed or 0
end

function M.stopDark() return dark:stop() end
function M.darkRunning() return dark:isRunning() end

return M
