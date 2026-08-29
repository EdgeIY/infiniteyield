--[[═══════════════════════════════════════════════════════════════════════════
	features/removeads · delete in-game billboard ads
	─────────────────────────────────────────────────────────────────────────
	Legacy source.ref.lua 12655-12670 was

	    while wait() do pcall(function() for i,v in pairs(workspace:GetDescendants())

	-- a full walk of every descendant of workspace, sixty times a second, on the
	command thread, with no flag, no off-command and a fresh loop for every
	invocation. `;breakloops` could not reach it, `;unloadiy` left it running,
	and running `;removeads` twice doubled the cost for the rest of the session.

	Two changes, both deliberate:

	  · the sweep is a 1s `Sched.interval` instead of a per-frame loop. Ads do
	    not appear sixty times a second, so this is the same result for about
	    1/60th of the work.
	  · `workspace.DescendantAdded` catches an ad the instant it streams in,
	    which is *faster* than the legacy loop was -- the interval is only a
	    backstop for parts whose marker children arrive after the PackageLink.

	`unremoveads` is new: legacy had no way to stop this at all.
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Feature = IY.import("features/feature")
local Sched   = IY.import("core/scheduler")

local M = {}

local SWEEP_INTERVAL = 1

--[[ Roblox's immersive ads are packages whose model contains either an "ADpart"
     or an "AdGuiAdornee". The first marker means the ad is the PackageLink's
     parent; the second means it is one level further up. Legacy indexed
     `v.Parent.Parent` with no nil check (12664). ]]
local function victimOf(link)
	local parent = link.Parent
	if not parent then return nil end
	if parent:FindFirstChild("ADpart") then return parent end
	if parent:FindFirstChild("AdGuiAdornee") then return parent.Parent end
	return nil
end

local function removeVia(link)
	local victim = victimOf(link)
	if not victim then return 0 end
	local ok = pcall(function() victim:Destroy() end)
	return ok and 1 or 0
end

local function sweep()
	local descendants = workspace:GetDescendants()
	local removed = 0
	for i = 1, #descendants do
		local instance = descendants[i]
		if instance:IsA("PackageLink") then
			removed = removed + removeVia(instance)
		end
	end
	return removed
end
M.sweep = sweep

--[[ A new descendant is worth checking either because it is the PackageLink or
     because it is the marker that identifies an already-present one. ]]
local function consider(instance)
	if instance:IsA("PackageLink") then return removeVia(instance) end
	local name = instance.Name
	if name ~= "ADpart" and name ~= "AdGuiAdornee" then return 0 end
	local parent = instance.Parent
	local link = parent and parent:FindFirstChildOfClass("PackageLink")
	if link then return removeVia(link) end
	return 0
end

local feature = Feature.new("removeads", {
	command  = "removeads",
	describe = "removing in-game ads",

	start = function(self)
		sweep()
		self.bin:add(Sched.interval("removeads.sweep", SWEEP_INTERVAL, sweep))
		self.bin:connect(workspace.DescendantAdded, consider)
	end,
})

M.feature = feature

function M.start() return feature:start() end
function M.stop() return feature:stop() end
function M.toggle() return feature:toggle() end
function M.isRunning() return feature:isRunning() end

return M
