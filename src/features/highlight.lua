--[[═══════════════════════════════════════════════════════════════════════════
	features/highlight · the shared per-player adornment engine
	─────────────────────────────────────────────────────────────────────────
	ESP, chams and locate are one job done three ways: attach adornments to a
	player's character, keep them updated, re-attach when that player respawns,
	remove them when they leave, and take everything down on stop. The legacy
	script wrote that out three times (source.ref.lua 5728-5822, 5824-5883,
	5885-5975) and paid for it three times:

	  · when the character had no Head (5758, 5911) the adornment folder was
	    created with no cleanup connections at all, so those adornments were
	    unreachable and permanent
	  · ESP and chams were made mutually exclusive with a user-facing error
	    (8117, 8226) purely because both wrote CoreGui folders named after the
	    player and each cleaned up by searching for that name
	  · the per-player RenderStepped loop was only disconnected when the folder
	    happened to be destroyed first -- `noesp` did that, a player leaving did
	    not, so the loop kept running against a dead character
	  · nothing was registered for unload, and the PlayerRemoving cleanup lived
	    inline in the UI region (4057-4075), so it went with the UI if the UI
	    failed to load

	    local session = Highlight.create("esp", {
	        suffix = "ESP",                              -- <player>_ESP folder
	        filter = function(player, opts) ... end,     -- who to adorn
	        build  = function(bin, target, folder, opts) ... end,
	        update = function(state, target, opts) ... end,   -- optional
	    })
	    session:start{ team = true }
	    session:stop()   session:isRunning()   session:refresh()

	One render loop per session drives every adorned player, each player owns a
	`bin:branch()` so one respawn or one departure tears down only their own
	adornments, and all of it hangs off the feature bin -- which is what makes
	`;unloadiy` and `Feature.stopAll()` reach it.

	Because ownership decides cleanup instead of a folder name, esp, chams and
	locate now run at the same time; the artificial mutual exclusion is gone.
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Feature   = IY.import("features/feature")
local Character = IY.import("core/character")
local Services  = IY.import("core/services")
local Sched     = IY.import("core/scheduler")
local Store     = IY.import("core/store")
local Guard     = IY.import("core/guard")
local Log       = IY.import("core/log")
local Env       = IY.import("core/env")
local Inst      = IY.import("core/util/instances")
local Target    = IY.import("core/target")

local Players = Services.Players

local M = {}

-- How long to wait for a character to become adornable before giving up. The
-- legacy `repeat wait(1) until ...` never gave up at all.
local SPAWN_TIMEOUT = 10

-- Consecutive update failures before one player's adornments are dropped, so a
-- single broken entry cannot keep costing the shared loop every frame.
local MAX_ENTRY_ERRORS = 5

-- ── where adornments live ───────────────────────────────────────────────────

local host

--[[ `gethui()` when the executor provides it (hidden from the game's own
     scripts), CoreGui next, PlayerGui last. PVAdornments and BillboardGuis
     render from any of the three. ]]
function M.host()
	if host and Inst.isAlive(host) then return host end
	local gethui = Env.lookup("gethui")
	if type(gethui) == "function" then
		local ok, container = pcall(gethui)
		if ok and container then
			host = container
			return host
		end
	end
	host = Services.get("CoreGui")
	if host then return host end
	local player = Players.LocalPlayer
	host = player and player:FindFirstChildOfClass("PlayerGui") or nil
	if not host then Guard.fail("there is nowhere to put adornments on this client") end
	return host
end

-- ── espTransparency ─────────────────────────────────────────────────────────

function M.transparency()
	local value = Store.get("espTransparency")
	if type(value) ~= "number" then return 0.3 end
	return value
end

--[[ Live updates for the setting. Legacy `esptransparency` (8151) re-ran `esp`
     and `chams` from scratch, rebuilding every adornment in the server to
     change one number. Returns a connection, for a bin. ]]
function M.onTransparency(fn)
	local primed = false
	return Store.watch("espTransparency", function(value)
		-- watch() fires once immediately; there is nothing to update yet.
		if not primed then
			primed = true
			return
		end
		fn(value)
	end)
end

--[[ Push a transparency onto every adornment under `container`. ]]
function M.applyTransparency(container, value)
	if not container or not Inst.isAlive(container) then return end
	value = value or M.transparency()
	for _, item in ipairs(container:GetDescendants()) do
		if item:IsA("BoxHandleAdornment") then item.Transparency = value end
	end
end

--[[ The same, for adornments held in a plain list: partesp parents its boxes to
     the parts themselves, so there is no one container to walk. ]]
function M.setTransparency(list, value)
	value = value or M.transparency()
	for i = #list, 1, -1 do
		if Inst.isAlive(list[i]) then
			list[i].Transparency = value
		else
			table.remove(list, i)
		end
	end
end

-- ── the adornments themselves ───────────────────────────────────────────────

--[[ Legacy 5752-5755: team mode paints your own team green and everyone else
     red, plain mode uses the player's own TeamColor. ]]
function M.playerColour(player, teamMode)
	if teamMode then
		local me = Players.LocalPlayer
		local ally = me ~= nil and player.TeamColor == me.TeamColor
		return BrickColor.new(ally and "Bright green" or "Bright red")
	end
	return player.TeamColor
end

--[[ One BoxHandleAdornment per BasePart child of the character, exactly as
     legacy 5741-5756 / 5837-5848 / 5898-5909 built them. ]]
function M.boxes(bin, folder, target, colour)
	local character = target.character
	if not character then return 0 end
	local transparency = M.transparency()
	local count = 0
	for _, part in ipairs(character:GetChildren()) do
		if part:IsA("BasePart") then
			local box = bin:add(Instance.new("BoxHandleAdornment"))
			box.Name = target.name
			box.Adornee = part
			box.AlwaysOnTop = true
			box.ZIndex = 10
			box.Size = part.Size
			box.Transparency = transparency
			box.Color = colour
			box.Parent = folder
			count = count + 1
		end
	end
	return count
end

--[[ The billboard name/health/distance label (legacy 5759-5777). Returns nil
     when the character has no Head; the caller carries on regardless, where the
     legacy version skipped its whole cleanup wiring in that case. ]]
function M.nameplate(bin, folder, target)
	local character = target.character
	local head = character and character:FindFirstChild("Head")
	if not head then return nil end

	local billboard = bin:add(Instance.new("BillboardGui"))
	billboard.Name = target.name
	billboard.Adornee = head
	billboard.Size = UDim2.new(0, 100, 0, 150)
	billboard.StudsOffset = Vector3.new(0, 1, 0)
	billboard.AlwaysOnTop = true

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Position = UDim2.new(0, 0, 0, -50)
	label.Size = UDim2.new(0, 100, 0, 100)
	label.Font = Enum.Font.SourceSansSemibold
	label.TextSize = 20
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0
	label.TextYAlignment = Enum.TextYAlignment.Bottom
	label.Text = "Name: " .. target.name
	label.ZIndex = 10
	label.Parent = billboard

	billboard.Parent = folder
	return label
end

local function round1(value)
	return math.floor(value * 10 + 0.5) / 10
end

--[[ 'Name: X | Health: 82.5 | Studs: 41' -- the legacy format at 5810, keeping
     its one-decimal health and floored stud distance. nil means "leave the
     label alone", which is what the legacy loop did when either character was
     incomplete. ]]
function M.nameplateText(target)
	if not target.humanoid or not Character.humanoid() then return nil end
	local origin, position = Character.position(), target.position
	if not origin or not position then return nil end
	return "Name: " .. target.name
		.. " | Health: " .. tostring(round1(target.health))
		.. " | Studs: " .. tostring(math.floor((origin - position).Magnitude))
end

--[[ The `update` body esp and locate share. ]]
function M.refreshNameplate(state, target)
	local label = state and state.label
	if not label then return end
	local text = M.nameplateText(target)
	if text then label.Text = text end
end

-- ── sessions ────────────────────────────────────────────────────────────────

local Session = {}
Session.__index = Session

--[[ All three legacy renderers skipped the local player outright, so the engine
     does too. `teamOnly` is the engine's own filter shorthand; ESP's team
     *colouring* is a build-time option, not this. ]]
function Session:eligible(player)
	if not player or player == Players.LocalPlayer then return false end
	if player.Parent == nil then return false end
	if self.spec.teamOnly or self.opts.teamOnly then
		local me = Players.LocalPlayer
		if not me or player.Team ~= me.Team then return false end
	end
	local filter = self.spec.filter
	if not filter then return true end
	local ok, allowed = pcall(filter, player, self.opts)
	return ok and allowed == true
end

function Session:detach(player)
	local entry = self.entries[player]
	if not entry then return false end
	self.entries[player] = nil
	entry.bin:destroy()
	return true
end

--[[ Give one player their own branch, then fill it. Called again on respawn and
     on a team colour change; because it detaches first, a player can never end
     up wearing two sets of adornments. ]]
function Session:attach(player)
	if not self.feature.running or not self:eligible(player) then return false end
	self:detach(player)

	local branch = self.feature.bin:branch("player:" .. tostring(player.UserId))
	local entry = { player = player, target = Target.fromPlayer(player), bin = branch, errors = 0 }
	self.entries[player] = entry
	branch:add(function()
		if self.entries[player] == entry then self.entries[player] = nil end
	end)

	-- Both connections exist before anything is built. That is the fix for the
	-- headless-character case: teardown no longer depends on the build having
	-- got far enough to create it.
	branch:connect(player.CharacterAdded, function() self:attach(player) end)
	branch:connect(player:GetPropertyChangedSignal("TeamColor"), function() self:attach(player) end)

	branch:spawn(function()
		local ready = Sched.waitUntil(function()
			local character = player.Character
			return character ~= nil and Inst.root(character) ~= nil
				and Inst.humanoid(character) ~= nil
		end, SPAWN_TIMEOUT)
		-- Legacy blocked here forever; CharacterAdded brings us back instead.
		if not ready then return end

		local folder = branch:add(Instance.new("Folder"))
		folder.Name = player.Name .. "_" .. (self.spec.suffix or "IY")
		folder.Parent = self.host
		entry.folder = folder

		local ok, state = Guard.call("highlight:" .. self.name .. ".build",
			self.spec.build, branch, entry.target, folder, self.opts)
		entry.state = (ok and state) or {}
		entry.ready = ok == true
	end)
	return true
end

--[[ One loop for the whole session, not one per player. A single player's
     update failing is contained, and if it keeps failing it costs only that
     player's adornments. ]]
function Session:step()
	local update = self.spec.update
	if not update then return end
	for player, entry in pairs(self.entries) do
		if entry.ready then
			local ok, err = pcall(update, entry.state, entry.target, self.opts)
			if ok then
				entry.errors = 0
			else
				entry.errors = entry.errors + 1
				if entry.errors >= MAX_ENTRY_ERRORS then
					self.log.debug("dropped %s: %s", tostring(player), tostring(err))
					self:detach(player)
				end
			end
		end
	end
end

--[[ Adorn anyone newly eligible, drop anyone who no longer is. Used by locate
     when its player set changes, without disturbing the players already lit. ]]
function Session:refresh()
	if not self.feature.running then return false end
	local players = Players:GetPlayers()
	for i = 1, #players do
		local player = players[i]
		if self:eligible(player) then
			if not self.entries[player] then self:attach(player) end
		elseif self.entries[player] then
			self:detach(player)
		end
	end
	return true
end

function Session:count()
	local total = 0
	for _ in pairs(self.entries) do total = total + 1 end
	return total
end

function Session:start(opts) return self.feature:start(opts or {}) end
function Session:stop() return self.feature:stop() end
function Session:toggle(opts) return self.feature:toggle(opts or {}) end
function Session:isRunning() return self.feature:isRunning() end
function Session:configure(patch) return self.feature:configure(patch) end
function Session:option(key, fallback) return self.feature:option(key, fallback) end

--[[ Define a session. `build` is the only required field; `filter`, `update`,
     `suffix`, `teamOnly`, `command`, `describe`, `forget` (a player left) and
     `stopped` (the session stopped) are optional. ]]
function M.create(name, spec)
	local session = setmetatable({
		name    = name,
		spec    = spec,
		entries = {},
		opts    = {},
		log     = Log.scope("highlight:" .. name),
	}, Session)

	session.feature = Feature.new("highlight." .. name, {
		command  = spec.command,
		describe = spec.describe,

		start = function(feature, opts)
			session.opts = opts or {}
			session.host = M.host()
			local bin = feature.bin

			bin:connect(Players.PlayerAdded, function(player) session:attach(player) end)
			-- The engine owns leave-cleanup now. Legacy did it inline in the UI
			-- region (4057-4075), and only for the folder names it knew about.
			bin:connect(Players.PlayerRemoving, function(player)
				session:detach(player)
				if spec.forget then Guard.try(function() spec.forget(player, session) end) end
			end)

			bin:add(M.onTransparency(function(value)
				for _, entry in pairs(session.entries) do
					M.applyTransparency(entry.folder, value)
				end
			end))

			if spec.update then
				bin:add(Sched.frameLoop("highlight:" .. name, function() session:step() end))
			end

			local players = Players:GetPlayers()
			for i = 1, #players do session:attach(players[i]) end
		end,

		stop = function()
			for player in pairs(session.entries) do session.entries[player] = nil end
			if spec.stopped then Guard.try(function() spec.stopped(session) end) end
		end,
	})

	return session
end

M.Session = Session
return M
