--[[═══════════════════════════════════════════════════════════════════════════
	features/xray · see through the map
	─────────────────────────────────────────────────────────────────────────
	Legacy source.ref.lua 12179-12215. The same effect --
	LocalTransparencyModifier 0.5 on every world BasePart, character rigs left
	alone -- with two changes:

	  · originals go through core/snapshot instead of being assumed to be 0.
	    Legacy `unxray` wrote 0 to everything it touched (12183), so any part the
	    game itself had made partly transparent came back wrong; now `unxray`,
	    `unloopxray` and `;unloadiy` restore exactly what was there.
	  · `loopxray` re-applied on *every* RenderStepped (12205), walking every
	    descendant of workspace sixty times a second, which is why it wrecked the
	    frame rate. The sweep is a 0.25s `Sched.interval` now: it still catches
	    parts that stream in, at roughly 1/240th of the work, and parts already
	    holding the target value are skipped before anything is written.
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Feature  = IY.import("features/feature")
local Sched    = IY.import("core/scheduler")
local Snapshot = IY.import("core/snapshot")

local M = {}

local TAG = "xray"
local SWEEP_INTERVAL = 0.25
local AMOUNT = 0.5

--[[ True for anything belonging to a character rig. Legacy indexed
     `v.Parent.Parent` unguarded (12182), which threw on any part parented
     straight into workspace. ]]
local function isRigPart(part)
	local parent = part.Parent
	if not parent then return true end
	if parent:FindFirstChildWhichIsA("Humanoid") then return true end
	local grandparent = parent.Parent
	return grandparent ~= nil and grandparent:FindFirstChildWhichIsA("Humanoid") ~= nil
end

local function sweep(amount)
	local descendants = workspace:GetDescendants()
	local touched = 0
	for i = 1, #descendants do
		local part = descendants[i]
		if part:IsA("BasePart") and part.LocalTransparencyModifier ~= amount
			and not isRigPart(part) then
			Snapshot.set(part, "LocalTransparencyModifier", amount, TAG)
			touched = touched + 1
		end
	end
	return touched
end

local feature = Feature.new("xray", {
	command  = "xray",
	describe = "x-ray vision",

	start = function(self)
		local amount = self:option("amount", AMOUNT)

		-- Registered before the first sweep, so the restore exists even if the
		-- sweep throws part way through.
		self.bin:add(function() Snapshot.restoreTag(TAG) end)
		sweep(amount)

		if self:option("loop", false) then
			self.bin:add(Sched.interval("xray.sweep", SWEEP_INTERVAL, function()
				sweep(amount)
			end))
		end
	end,
})

M.feature = feature

function M.start(opts) return feature:start(opts or {}) end
function M.stop() return feature:stop() end
function M.toggle(opts) return feature:toggle(opts or {}) end
function M.isRunning() return feature:isRunning() end
function M.isLooping() return feature:isRunning() and feature:option("loop", false) == true end

return M
