--[[═══════════════════════════════════════════════════════════════════════════
	features/prompts_interact · ClickDetectors and ProximityPrompts
	─────────────────────────────────────────────────────────────────────────
	Legacy source.ref.lua 11024-11100.

	  · both "no limits" commands (11024, 11053) wrote math.huge over every
	    MaxActivationDistance in the world and kept no record of what had been
	    there. The writes go through core/snapshot under the "interact" tag now,
	    so `;unloadiy` hands the game's own distances back.
	  · both name filters read
	        IsA(class) and Name:lower() == name or Parent.Name:lower() == name
	    (11037, 11066). `and` binds tighter than `or`, so *any* instance whose
	    parent happened to match was handed to fireclickdetector /
	    fireproximityprompt, which then errored on something that was not a
	    detector -- and `descendant.Parent` was indexed with no nil check, which
	    throws for anything sitting directly under the DataModel. Parenthesised
	    and nil-checked here, and the prompt search is case-insensitive like the
	    detector one rather than case-sensitive (11064) by accident.
	  · `instantproximityprompts` was the one legacy toggle whose off-command
	    nil-checked its connection before disconnecting (11096). Keeping the
	    connection in a feature bin makes that structural: `;uninstantpp` is safe
	    before, after, and without ever running the on-command -- and the
	    `execCmd("uninstantproximityprompts")` + `wait(0.1)` restart dance at
	    11085 is gone, because Feature:start stops first.
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Feature  = IY.import("features/feature")
local Parts    = IY.import("features/parts")
local Snapshot = IY.import("core/snapshot")
local Services = IY.import("core/services")
local Guard    = IY.import("core/guard")
local Str      = IY.import("core/util/strings")

local M = {}

local TAG = "interact"
M.TAG = TAG

--[[ Every ClickDetector / ProximityPrompt of `className`, or only those matching
     `name`. A prompt is usually called "ProximityPrompt" and sits inside the
     part you actually want, which is why the parent's name counts too. ]]
function M.matching(className, name)
	local needle = nil
	if name ~= nil and Str.trim(name) ~= "" then needle = Str.lower(Str.trim(name)) end
	return Parts.find(function(instance)
		if not instance:IsA(className) then return false end
		if not needle then return true end
		if Str.lower(instance.Name) == needle then return true end
		local parent = instance.Parent
		return parent ~= nil and Str.lower(parent.Name) == needle
	end)
end

--[[ MaxActivationDistance = infinity on every one of them. Returns how many
     were changed and how many exist. ]]
local function removeLimits(className)
	local found = M.matching(className, nil)
	local changed = 0
	for i = 1, #found do
		if Snapshot.set(found[i], "MaxActivationDistance", math.huge, TAG) then
			changed = changed + 1
		end
	end
	return changed, #found
end

function M.removeClickLimits()  return removeLimits("ClickDetector") end
function M.removePromptLimits() return removeLimits("ProximityPrompt") end

--[[ Hand the recorded distances back. There was no legacy command for this and
     none is registered, but core/snapshot's unload hook calls it for us. ]]
function M.restoreLimits()
	return Snapshot.restoreTag(TAG)
end

local function fireAll(className, capability, name)
	local fire = Guard.need(capability)
	local found = M.matching(className, name)
	local fired = 0
	for i = 1, #found do
		-- Contained per detector: a detector whose part has just been streamed
		-- out makes the executor function throw, and legacy let that kill the
		-- rest of the sweep.
		if pcall(fire, found[i]) then fired = fired + 1 end
	end
	return fired, #found
end

function M.fireClickDetectors(name)
	return fireAll("ClickDetector", "fireclickdetector", name)
end

function M.fireProximityPrompts(name)
	return fireAll("ProximityPrompt", "fireproximityprompt", name)
end

-- ── instantproximityprompts ─────────────────────────────────────────────────

local instant = Feature.new("instantproximityprompts", {
	command  = "instantproximityprompts",
	describe = "prompts fire the moment their key goes down",

	start = function(self)
		local fire = Guard.need("fireproximityprompt")
		-- Services.get rather than Services.ProximityPromptService: the service
		-- is missing on old clients, and a feature should refuse rather than
		-- throw at import time.
		local service = Services.get("ProximityPromptService")
		if not service then Guard.fail("this client has no ProximityPromptService") end

		self.bin:connect(service.PromptButtonHoldBegan, Guard.wrap("instantpp", function(prompt)
			-- The signal can hand us a prompt whose part has already gone.
			if prompt then pcall(fire, prompt) end
		end))
	end,
})

M.instant = instant

function M.startInstant() return instant:start() end
function M.stopInstant()  return instant:stop() end
function M.isInstant()    return instant:isRunning() end

return M
