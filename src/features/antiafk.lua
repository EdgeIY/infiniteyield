--[[═══════════════════════════════════════════════════════════════════════════
	features/antiafk · stay in the game while you are idle
	─────────────────────────────────────────────────────────────────────────
	Replaces source.ref.lua 8862-8881 (antiafk / antiidle), which had no
	off-command at all and started by walking `getconnections(speaker.Idled)`
	calling `Disable()` *and then* `Disconnect()` on every listener it found
	(8866-8867). Disconnecting the client's own idle handlers cannot be undone
	for the session, and it took the game's handlers with it.

	The order here is reversible-first:

	  1. a `VirtualUser` nudge on Player.Idled -- the part that actually defeats
	     the twenty-minute idle kick. Held in the bin, so it goes when the
	     feature stops.
	  2. every *other* Idled listener that exposes Disable/Enable is disabled,
	     and re-enabled on stop. Ours is connected afterwards so it is never in
	     that list.
	  3. only a listener with no Disable, on a client with no VirtualUser to nudge
	     with, is disconnected -- and then `report()` says so, because that part
	     is permanent.
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Feature  = IY.import("features/feature")
local Env      = IY.import("core/env")
local Guard    = IY.import("core/guard")
local Services = IY.import("core/services")

local Players = Services.Players

local M = {}

local last = { disabled = 0, disconnected = 0, nudge = false }

--[[ Connection objects differ per executor: some expose Disable/Enable, some
     only Disconnect, and indexing a missing field can throw. ]]
local function method(connection, name)
	local ok, value = pcall(function() return connection[name] end)
	if ok and type(value) == "function" then return value end
	return nil
end

local feature = Feature.new("antiafk", {
	command  = "antiafk",
	describe = "idle kick suppressed",

	start = function(self)
		local player = Players.LocalPlayer
		if not player then Guard.fail("there is no local player") end
		-- Read once and nil-check: a client that does not expose Idled cannot be
		-- helped by this command, and an unguarded read would surface as an
		-- internal error rather than as a message.
		local idled = Guard.try(function() return player.Idled end)
		if not idled then Guard.fail("your client does not expose Player.Idled") end

		local virtualUser = Services.get("VirtualUser")
		local disabled, disconnected = 0, 0

		local getconnections = Env.fn.getconnections
		if getconnections then
			local ok, connections = pcall(getconnections, idled)
			if ok and type(connections) == "table" then
				for i = 1, #connections do
					local connection = connections[i]
					local disable = method(connection, "Disable")
					local enable  = method(connection, "Enable")
					if disable and enable then
						if pcall(disable, connection) then
							disabled = disabled + 1
							self.bin:add(function() pcall(enable, connection) end)
						end
					elseif not virtualUser then
						-- Nothing reversible available and no nudge to fall back on:
						-- this is the only case where legacy's Disconnect is the
						-- lesser evil, and report() tells the user it is permanent.
						local disconnect = method(connection, "Disconnect")
						if disconnect and pcall(disconnect, connection) then
							disconnected = disconnected + 1
						end
					end
				end
			end
		end

		if virtualUser then
			self.bin:connect(idled, function()
				pcall(function()
					virtualUser:CaptureController()
					virtualUser:ClickButton2(Vector2.new(0, 0))
				end)
			end)
		end

		if not virtualUser and disabled == 0 and disconnected == 0 then
			Guard.fail("your client has no VirtualUser and no way to quiet the idle handlers")
		end

		last = { disabled = disabled, disconnected = disconnected, nudge = virtualUser ~= nil }
		self.state.report = last
	end,
})

M.feature = feature

--[[ What the last start managed to do, for the command's notification. ]]
function M.report()
	return last
end

function M.start(opts) return feature:start(opts or {}) end
function M.stop() return feature:stop() end
function M.toggle(opts) return feature:toggle(opts or {}) end
function M.isRunning() return feature:isRunning() end

return M
