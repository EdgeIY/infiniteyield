--[[═══════════════════════════════════════════════════════════════════════════
	features/walkto · walk (don't teleport) to a player or a point
	─────────────────────────────────────────────────────────────────────────
	One feature covers all three legacy follow commands, because they were the
	same loop with a different destination and a different flag:

	    Walkto.follow(target)                      -- ;walkto  / ;follow
	    Walkto.follow(target, { pathfind = true }) -- ;pathfindwalkto
	    Walkto.walkTo(position)                    -- ;pathfindwalktowaypoint

	Legacy equivalent: source.ref.lua 9268-9393. Fixed here:

	  · the loop ran *inside* the command, so `;walkto` never returned and the
	    dispatcher's repeat/`;breakloops` machinery could not touch it. It is a
	    bin-owned thread now, which is also what makes `;unloadiy` able to stop
	    it.
	  · two module flags (`walkto`, `waypointwalkto`) meant `;unwalkto` had to
	    clear both and `;pathfindwalkto` had to clear the other one on entry.
	  · `hum.Parent.PrimaryPart.Position` and `speaker.Character:FindFirst...`
	    were indexed unguarded every frame, so a respawn mid-follow threw.
	  · the per-waypoint `repeat until distance <= 5` had no timeout: one
	    waypoint you could not reach stalled the follow forever with no way out
	    but rejoining.
	  · `ComputeAsync` failures were swallowed by a bare pcall, so "there is no
	    path" was indistinguishable from the command doing nothing.
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Feature   = IY.import("features/feature")
local Character = IY.import("core/character")
local Services  = IY.import("core/services")
local Guard     = IY.import("core/guard")
local Notify    = IY.import("core/notify")
local Teleport  = IY.import("features/teleport")

local M = {}

local WAYPOINT_RADIUS  = 5      -- legacy's "close enough" distance
local WAYPOINT_TIMEOUT = 5      -- seconds before we give up on one waypoint

local function clock()
	if os and os.clock then return os.clock() end
	return tick and tick() or 0
end

--[[ The loop ends by stopping the feature, but it is running *inside* the bin
     that stop() empties, so the stop is deferred onto another thread rather
     than cancelling the thread that asked for it. ]]
local function finish(self)
	task.defer(function() self:stop() end)
end

-- ── direct walk ─────────────────────────────────────────────────────────────

local function startDirect(self, goal)
	self.bin:spawn(function()
		while true do
			local position = goal()
			if not position then break end
			local humanoid = Character.humanoid()
			-- A missing humanoid is a respawn gap, not a reason to give up.
			if humanoid then humanoid:MoveTo(position) end
			task.wait()
		end
		finish(self)
	end)
end

-- ── pathfinding ─────────────────────────────────────────────────────────────

local function walkWaypoint(position)
	local humanoid = Character.humanoid()
	if not humanoid then return end
	humanoid:MoveTo(position)
	local deadline = clock() + WAYPOINT_TIMEOUT
	while true do
		task.wait()
		local root = Character.root()
		if not root then return end
		if (position - root.Position).Magnitude <= WAYPOINT_RADIUS then return end
		if clock() > deadline then return end
	end
end

local function startPathfinding(self, goal)
	-- Not every client ships PathfindingService; fail with a sentence rather
	-- than an "unknown service" error out of core/services.
	local service = Services.get("PathfindingService")
	if not service then Guard.fail("your client has no PathfindingService") end

	self.bin:spawn(function()
		local path = service:CreatePath()
		local warned = false

		while true do
			local position = goal()
			local root = Character.root()
			if not position then break end

			if root then
				local ok, reachable = Guard.call("walkto.compute", function()
					path:ComputeAsync(root.Position, position)
					return path.Status == Enum.PathStatus.Success
				end)

				local waypoints
				if ok and reachable then
					local okPoints, list = Guard.call("walkto.waypoints", function()
						return path:GetWaypoints()
					end)
					if okPoints then waypoints = list end
				end

				if waypoints and #waypoints > 0 then
					for index = 1, #waypoints do
						if not self:isRunning() then return end
						walkWaypoint(waypoints[index].Position)
					end
				else
					if not warned then
						warned = true
						Notify.send("Pathfind", "No path found -- walking straight there instead")
					end
					local humanoid = Character.humanoid()
					if humanoid then humanoid:MoveTo(position) end
				end
			end
			task.wait()
		end
		finish(self)
	end)
end

-- ── feature ─────────────────────────────────────────────────────────────────

local feature = Feature.new("walkto", {
	command  = "walkto",
	reapply  = true,
	describe = "walking to a destination",

	start = function(self, opts)
		local goal
		if opts.position then
			local position = opts.position
			goal = function() return position end
		else
			local target = opts.target
			if not target then Guard.fail("there is nobody to follow") end
			target:requireRoot()
			-- Read through the Target every tick: it follows them across their
			-- own respawns, and returning nil is how we notice they left.
			goal = function()
				if not target:exists() then return nil end
				local root = target.root
				return root and root.Position or nil
			end
		end

		Character.requireHumanoid()
		Teleport.unseat()

		if opts.pathfind then
			return startPathfinding(self, goal)
		end
		return startDirect(self, goal)
	end,
})

M.feature = feature

function M.follow(target, opts)
	opts = opts or {}
	return feature:start({ target = target, pathfind = opts.pathfind == true })
end

--[[ Pathfind to a fixed point (`;pathfindwalktowaypoint`). ]]
function M.walkTo(position, opts)
	opts = opts or {}
	return feature:start({ position = position, pathfind = opts.pathfind ~= false })
end

function M.stop() return feature:stop() end
function M.isRunning() return feature:isRunning() end

return M
