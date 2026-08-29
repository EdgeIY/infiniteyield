--[[═══════════════════════════════════════════════════════════════════════════
	features/chatlogs · the chat / join log data model and the webhook
	─────────────────────────────────────────────────────────────────────────
	Replaces the data half of source.ref.lua 3287-3392 (CreateLabel,
	CreateJoinLabel), 3975-4055 (sendChatWebhook, ChatLog, JoinLog, CleanFileName
	and the save-to-file button) and 13217-13249 (the PlayerAdded and
	TextChatService hookups). The window itself is ui/logs' job; this module owns
	the data and knows nothing about frames.

	The legacy code mixed the two, and paid for it four times:

	  · `CreateLabel` built a GUI row *and* was the only place a message was
	    recorded, so logging could not exist without the interface -- and every
	    row it built was appended to the theme's `text1` registry.
	  · at 2546 rows it called `scroll:ClearAllChildren()`, throwing away the
	    whole history and leaving those destroyed labels in that registry
	    forever. Both buffers here are capped by dropping the oldest entry.
	  · `sendChatWebhook` ran an unprotected `httprequest` on the chat thread, so
	    one network error propagated out of the `Chatted` handler and Roblox
	    dropped the connection: that player stopped being logged for the rest of
	    the session, silently. It is off-thread and contained now, and gives up
	    after MAX_FAILURES with one warning instead of retrying forever.
	  · `CreateJoinLabel` did a bare `game:HttpGet` plus `JSONDecode` plus
	    `json["created"]:sub(1,10)` -- and it ran *before* the chat-log and ESP
	    hookups inside the same `PlayerAdded` handler (13221-13230), so one failed
	    request aborted all of them. The account-age lookup is asynchronous and
	    non-fatal; the entry simply keeps `created = nil`.

	    ChatLogs.chat    -- { time, player, message, count }
	    ChatLogs.joins   -- { time, player, userId, accountAge, action, created }
	    ChatLogs.changed -- (kind, entry, updated) for the window to subscribe to
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Bin      = IY.import("core/bin")
local Env      = IY.import("core/env")
local FS       = IY.import("core/fs")
local Guard    = IY.import("core/guard")
local Json     = IY.import("core/json")
local Log      = IY.import("core/log")
local Notify   = IY.import("core/notify")
local Platform = IY.import("core/platform")
local Sched    = IY.import("core/scheduler")
local Services = IY.import("core/services")
local Signal   = IY.import("core/signal")
local Store    = IY.import("core/store")
local Str      = IY.import("core/util/strings")

local Players = Services.Players

local log = Log.scope("features/chatlogs")

local M = {}

-- Both buffers hold this many entries; the oldest goes when a new one arrives.
local LIMIT = 2500

-- Consecutive webhook failures before the sender switches itself off.
local MAX_FAILURES = 5

local FALLBACK_AVATAR = "https://files.catbox.moe/i968v2.jpg"
local USER_API        = "https://users.roblox.com/v1/users/"
local HEADSHOT_API    = "https://thumbnails.roblox.com/v1/users/avatar-headshot"
	.. "?userIds=%s&size=420x420&format=Png&isCircular=false"

M.chat    = {}
M.joins   = {}
M.limit   = LIMIT
M.changed = Signal.new("chatlogs.changed")

local bin = Bin.new("chatlogs")
M.bin = bin

local avatarCache = {}    -- userId -> image url
local playerBins  = {}    -- Player -> Bin (one legacy-chat Chatted connection)
local failures    = 0
local stopped     = false
local attached    = false

-- Resolved once: the enum is missing on clients old enough to predate it, and
-- probing it per message would cost a pcall on every line of chat.
local INVALID_CHANNEL = Guard.try(function()
	return Enum.TextChatMessageStatus.InvalidTextChannelPermissions
end)

-- ── helpers ─────────────────────────────────────────────────────────────────

local function push(buffer, entry)
	buffer[#buffer + 1] = entry
	while #buffer > LIMIT do table.remove(buffer, 1) end
	return entry
end

--[[ Legacy formatUsername (5607): "Name (DisplayName)" when they differ. ]]
local function formatUsername(player)
	local name = tostring(player.Name)
	local display = Guard.try(function() return player.DisplayName end)
	if display and display ~= name then
		return string.format("%s (%s)", name, display)
	end
	return name
end
M.formatUsername = formatUsername

--[[ Legacy CleanFileName (4018-4020), plus `/` -- a place name containing one
     made the legacy save silently write into a folder that does not exist. ]]
local function cleanFileName(name)
	local text = string.gsub(tostring(name), "[*\\/?:<>|]+", "")
	return string.sub(text, 1, 175)
end
M.cleanFileName = cleanFileName

-- GetProductInfo is a web call and yields; ask once per session.
local productName = nil

local function placeName()
	if productName then return productName end
	local info = Guard.try(function()
		return Services.MarketplaceService:GetProductInfo(game.PlaceId)
	end)
	if type(info) == "table" and info.Name then
		productName = cleanFileName(info.Name)
	else
		productName = "Place " .. tostring(Platform.placeId)
	end
	return productName
end
M.placeName = placeName

-- ── settings ────────────────────────────────────────────────────────────────

function M.chatEnabled()
	return Store.get("logsEnabled") == true
end

function M.joinEnabled()
	return Store.get("joinLogsEnabled") == true
end

function M.setChatEnabled(on)
	local value = on == true
	Store.set("logsEnabled", value)
	M.changed:Fire("settings")
	return value
end

function M.setJoinEnabled(on)
	local value = on == true
	Store.set("joinLogsEnabled", value)
	M.changed:Fire("settings")
	return value
end

function M.webhook()
	local url = Store.get("logsWebhook")
	if type(url) ~= "string" or url == "" then return nil end
	return url
end

--[[ True when a message would actually be delivered: a URL is set, the executor
     can make requests, and the sender has not switched itself off. ]]
function M.webhookEnabled()
	return M.webhook() ~= nil and Env.usable("request") and not stopped
end

--[[ nil or "" clears it. Re-arms the failure counter, so fixing a bad URL works
     without a rejoin. ]]
function M.setWebhook(url)
	local value = nil
	if type(url) == "string" and Str.trim(url) ~= "" then value = Str.trim(url) end
	if value and not string.match(Str.lower(value), "^https?://") then
		Guard.fail("a webhook has to be an http(s) URL")
	end
	local ok, reason = Store.set("logsWebhook", value)
	if not ok then Guard.fail("%s", tostring(reason)) end
	failures, stopped = 0, false
	M.changed:Fire("settings")
	return value
end

-- ── the Discord webhook ─────────────────────────────────────────────────────

--[[ Legacy 3979-3987 indexed `d[1].state` without checking that `d[1]` existed,
     so a throttled thumbnail response threw inside the chat handler. ]]
local function avatarFor(request, userId)
	local cached = avatarCache[userId]
	if cached then return cached end

	local url = FALLBACK_AVATAR
	local ok, response = Guard.call("chatlogs.avatar", request, {
		Url = string.format(HEADSHOT_API, tostring(userId)), Method = "GET",
	})
	if ok and type(response) == "table" and type(response.Body) == "string" then
		local decoded = Json.decode(response.Body)
		local data = type(decoded) == "table" and decoded.data or nil
		local first = type(data) == "table" and data[1] or nil
		if type(first) == "table" and first.state == "Completed"
			and type(first.imageUrl) == "string" then
			url = first.imageUrl
		end
	end
	avatarCache[userId] = url
	return url
end

local function giveUp()
	stopped = true
	local prefix = Store.get("prefix") or ";"
	Notify.warn("Chat Logs", "The chat log webhook failed " .. tostring(failures)
		.. " times, so it has been switched off.\nCheck the URL and run "
		.. prefix .. "chatlogswebhook <url> again.")
	log.warn("webhook disabled after %d consecutive failures", failures)
end

--[[ Fire and forget, off the chat thread. Independent of `logsEnabled`: the
     legacy TextChatService path sent the webhook regardless (13246) while the
     legacy-chat path only sent it while the window was logging (4005), for no
     stated reason. A configured webhook now always fires. ]]
local function sendWebhook(player, message)
	local url = M.webhook()
	if not url or stopped or not Env.usable("request") then return false end

	local request = Env.fn.request
	local userId = Guard.try(function() return player.UserId end) or 0
	local username = formatUsername(player)

	Sched.spawn("chatlogs.webhook", function()
		if stopped then return end
		local body = Json.encode({
			content    = message,
			avatar_url = avatarFor(request, userId),
			username   = username,
			-- A plain {} encodes as a JSON object; Discord wants an array here.
			allowed_mentions = { parse = Json.emptyArray },
		})
		local ok, response = Guard.call("chatlogs.webhook", request, {
			Url = url, Method = "POST",
			Headers = { ["Content-Type"] = "application/json" },
			Body = body,
		})
		local status = 0
		if ok and type(response) == "table" then
			status = tonumber(response.StatusCode or response.Status) or 0
		end
		if ok and status >= 200 and status < 400 then
			failures = 0
			return
		end
		failures = failures + 1
		log.debug("webhook POST failed (status %d, attempt %d)", status, failures)
		if failures >= MAX_FAILURES then giveUp() end
	end)
	return true
end

-- ── recording ───────────────────────────────────────────────────────────────

--[[ "Joined Roblox", fetched after the row exists so a blocked or throttled
     request costs one missing field and nothing else. ]]
local function lookupCreated(entry, userId)
	Sched.spawn("chatlogs.created", function()
		local ok, body = Guard.call("chatlogs.created", function()
			return game:HttpGet(USER_API .. tostring(userId), true)
		end)
		if not ok or type(body) ~= "string" then return end
		local info = Json.decode(body)
		local created = type(info) == "table" and info.created or nil
		if type(created) ~= "string" then return end
		local year, month, day = string.match(created, "^(%d+)%-(%d+)%-(%d+)")
		if not year then return end
		entry.created = month .. "/" .. day .. "/" .. year
		M.changed:Fire("join", entry, true)
	end)
end

--[[ Record one chat message and mirror it to the webhook. `player` is a Player
     instance; the entry keeps only the name, so nothing here pins a Player. ]]
function M.record(player, message)
	if not player then return nil end
	local text = tostring(message or "")
	local name = tostring(player.Name)
	local entry = nil

	if M.chatEnabled() then
		local last = M.chat[#M.chat]
		if last and last.player == name and last.message == text then
			-- Legacy CreateLabel rewrote the previous row as "... (xN)" instead of
			-- adding another; the count lives on the entry now, so the window can
			-- render it however it likes.
			last.count = (last.count or 1) + 1
			last.time = Str.clockTime()
			entry = last
			M.changed:Fire("chat", entry, true)
		else
			entry = push(M.chat, {
				time = Str.clockTime(), player = name, message = text, count = 1,
			})
			M.changed:Fire("chat", entry, false)
		end
	end

	sendWebhook(player, text)
	return entry
end

local function recordPresence(player, action)
	if not player or not M.joinEnabled() then return nil end
	local userId = Guard.try(function() return player.UserId end) or 0
	local entry = push(M.joins, {
		time       = Str.clockTime(),
		player     = tostring(player.Name),
		userId     = userId,
		accountAge = Guard.try(function() return player.AccountAge end) or 0,
		action     = action,
		created    = nil,
	})
	M.changed:Fire("join", entry, false)
	if action == "join" and userId > 0 then lookupCreated(entry, userId) end
	return entry
end

function M.recordJoin(player)
	return recordPresence(player, "join")
end

--[[ New: the legacy JoinLog only ever recorded arrivals. ]]
function M.recordLeave(player)
	return recordPresence(player, "leave")
end

function M.counts()
	return #M.chat, #M.joins
end

function M.clearChat()
	local count = #M.chat
	for i = count, 1, -1 do M.chat[i] = nil end
	M.changed:Fire("chat-cleared")
	return count
end

function M.clearJoins()
	local count = #M.joins
	for i = count, 1, -1 do M.joins[i] = nil end
	M.changed:Fire("join-cleared")
	return count
end

-- ── export ──────────────────────────────────────────────────────────────────

--[[ One row in the legacy label format: "03:14:15 PM - [Name]: message". ]]
function M.line(entry)
	local text = entry.time .. " - [" .. entry.player .. "]: " .. entry.message
	if (entry.count or 1) > 1 then
		text = text .. " (x" .. tostring(entry.count) .. ")"
	end
	return text
end

--[[ The plain text the save path writes, byte for byte the legacy format
     (4027-4030) -- rebuilt from the data instead of read back out of the GUI. ]]
function M.export()
	local lines = { '-- Infinite Yield Chat logs for "' .. placeName() .. '"' }
	for i = 1, #M.chat do
		lines[#lines + 1] = M.line(M.chat[i])
	end
	return table.concat(lines, "\n")
end

--[[ Write the logs next to the executor's workspace folder, as
     "<place> Chat Logs (n).txt". Returns the file name.

     Legacy nameFile() recursed once per existing file with no bound, so a folder
     with a few hundred saves overflowed the stack. ]]
function M.saveToFile()
	if not FS.available then
		Guard.fail("your executor cannot write files, so chat logs cannot be saved")
	end
	if #M.chat == 0 then Guard.fail("there are no chat logs to save yet") end

	local base = placeName() .. " Chat Logs"
	local name = nil
	for index = 0, 999 do
		local candidate = base .. " (" .. tostring(index) .. ").txt"
		if FS.exists(candidate) ~= true then
			name = candidate
			break
		end
	end
	if not name then name = base .. " (" .. Str.random(6) .. ").txt" end

	local ok, err = FS.write(name, M.export())
	if not ok then Guard.fail("could not write %s: %s", name, tostring(err)) end
	log.info("saved %d chat log line(s) to %s", #M.chat, name)
	return name
end

-- ── listeners ───────────────────────────────────────────────────────────────

--[[ Legacy chat has no single message signal, so it needs one `Chatted`
     connection per player. Legacy connected it inside `PlayerAdded` and never
     disconnected it, so a player who rejoined ten times left ten live handlers
     behind, each recording the same message. Each player owns a bin instead.

     The bins are held in `playerBins` rather than as bin:branch children,
     because the parent's item list would otherwise grow by one dead entry for
     every player who has ever joined. ]]
local function attachPlayer(player)
	if not Platform.isLegacyChat then return end
	local existing = playerBins[player]
	if existing then existing:destroy() end
	local branch = Bin.new("chatlogs/" .. tostring(player.Name))
	playerBins[player] = branch
	branch:connect(player.Chatted, function(message)
		M.record(player, message)
	end)
end

local function detachPlayer(player)
	local branch = playerBins[player]
	if branch then branch:destroy() end
	playerBins[player] = nil
end

--[[ Legacy 13235-13237: ignore a message the channel rejected, and one whose
     source is not a player in this server. ]]
local function sourceOf(message)
	if not message then return nil end
	local source = Guard.try(function() return message.TextSource end)
	if not source then return nil end
	if INVALID_CHANNEL and message.Status == INVALID_CHANNEL then return nil end
	return Guard.try(function() return Players:GetPlayerByUserId(source.UserId) end)
end

--[[ Attach once, at load. The connections stay up whether logging is on or not,
     so `;chatlogs` takes effect on the very next message rather than on the next
     rejoin. ]]
function M.attach()
	if attached then return false end
	attached = true

	bin:connect(Players.PlayerAdded, function(player)
		M.recordJoin(player)
		attachPlayer(player)
	end)

	bin:connect(Players.PlayerRemoving, function(player)
		M.recordLeave(player)
		detachPlayer(player)
	end)

	if Platform.isLegacyChat then
		local players = Players:GetPlayers()
		for i = 1, #players do attachPlayer(players[i]) end
		bin:add(function()
			for player, branch in pairs(playerBins) do
				branch:destroy()
				playerBins[player] = nil
			end
		end)
	else
		local service = Services.get("TextChatService")
		if service then
			bin:connect(service.MessageReceived, function(message)
				local player = sourceOf(message)
				if player then M.record(player, message.Text) end
			end)
		else
			log.warn("no TextChatService and no legacy chat: chat logging is unavailable")
		end
	end

	IY.onUnload(function()
		bin:destroy()
		attached = false
	end, "features/chatlogs")
	return true
end

Guard.call("features/chatlogs.attach", M.attach)

return M
