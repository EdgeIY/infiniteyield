--[[═══════════════════════════════════════════════════════════════════════════
	features/performance · frame rate, rendering and network throttles
	─────────────────────────────────────────────────────────────────────────
	antilag, fpscap, norender, datalimit, replicationlag and wallwalk. Legacy
	equivalents: source.ref.lua 8030-8073 (antilag), 8075-8104 (setfpscap),
	8883-8894 (datalimit, replicationlag), 8923-8925 (wallwalk), 9059-9065
	(norender / render).

	What each one fixes:

	  antilag  had no off-command and no record of anything it changed, connected
	           a fresh `workspace.DescendantAdded` handler on every invocation
	           (8063) and spawned a thread per new descendant. Every property it
	           writes is a core/snapshot record under the "antilag" tag now, so
	           `;unantilag` genuinely puts the game's look back, and the one-off
	           sweep of the whole DataModel yields every few thousand instances
	           instead of freezing the client for seconds. Effect instances it
	           deletes are gone for good -- that part cannot be undone.
	  setfpscap fell back to `while true do end` on executors with no setfpscap
	           (8094-8102), a busy loop that pinned a core and could only be
	           stopped by running the command again. The real function is required
	           now and its absence is reported.
	  norender  left the screen black with no restore path at all: `;unloadiy`
	           after `;norender` needed a rejoin. Rendering comes back when the
	           feature stops, and the feature stops on unload.
	  datalimit / replicationlag wrote engine settings once and never put them
	           back, and replicationlag assigned the raw argument string (8892).
	  wallwalk  loadstring'd an external script with no state, so a second
	           `;wallwalk` started a second copy of a loop IY does not own.
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Feature  = IY.import("features/feature")
local Env      = IY.import("core/env")
local Guard    = IY.import("core/guard")
local Inst     = IY.import("core/util/instances")
local Sched    = IY.import("core/scheduler")
local Services = IY.import("core/services")
local Snapshot = IY.import("core/snapshot")

local Lighting   = Services.Lighting
local RunService = Services.RunService
local Workspace  = Services.Workspace

local M = {}

local ANTILAG_TAG = "antilag"
local NETWORK_TAG = "network"

-- Legacy's stand-in for "no cap" (8082), and an int-safe stand-in for "no
-- outgoing limit". Both are far above anything a client can actually reach.
local UNCAPPED = 1e6

--[[ `settings()` is an environment global rather than a service, and writing to
     it needs an elevated thread identity, so it is resolved per call and
     contained. `alias` is the GlobalSettings property the legacy code used
     (`settings().Rendering`), tried when GetService does not answer. ]]
local function engineSettings(name, alias)
	local ok, service = pcall(function() return settings():GetService(name) end)
	if ok and service then return service end
	if alias then
		local okAlias, viaAlias = pcall(function() return settings()[alias] end)
		if okAlias and viaAlias then return viaAlias end
	end
	return nil
end

local function isA(instance, className)
	local ok, matched = pcall(function() return instance:IsA(className) end)
	return ok and matched == true
end

-- ── antilag ─────────────────────────────────────────────────────────────────

-- The six surface properties legacy flattened (8045-8050).
local SURFACES = {
	"BackSurface", "BottomSurface", "FrontSurface",
	"LeftSurface", "RightSurface", "TopSurface",
}

-- Deleted on sight as they appear (8065). Not restorable, by nature.
local EFFECTS = { "ForceField", "Sparkles", "Smoke", "Fire", "Beam" }

local SWEEP_CHUNK = 2000   -- instances handled between yields

local function isEffect(instance)
	for i = 1, #EFFECTS do
		if isA(instance, EFFECTS[i]) then return true end
	end
	return false
end

--[[ Record-then-write, skipping anything already holding the target value: every
     write becomes a permanent snapshot record and a large map has tens of
     thousands of parts, so the skip is what keeps the registry a sane size. ]]
local function apply(instance, property, value)
	local ok, current = pcall(function() return instance[property] end)
	if ok and current == value then return false end
	return Snapshot.set(instance, property, value, ANTILAG_TAG)
end

local function flatten(instance)
	if isA(instance, "BasePart") then
		apply(instance, "CastShadow", false)
		apply(instance, "Material", Enum.Material.Plastic)
		apply(instance, "Reflectance", 0)
		for i = 1, #SURFACES do
			apply(instance, SURFACES[i], Enum.SurfaceType.SmoothNoOutlines)
		end
	elseif isA(instance, "Decal") then
		apply(instance, "Transparency", 1)
		apply(instance, "Texture", "")
	elseif isA(instance, "ParticleEmitter") or isA(instance, "Trail") then
		apply(instance, "Lifetime", NumberRange.new(0))
	end
end

local function worldSettings()
	local terrain = Workspace:FindFirstChildWhichIsA("Terrain")
	if terrain then
		apply(terrain, "WaterWaveSize", 0)
		apply(terrain, "WaterWaveSpeed", 0)
		apply(terrain, "WaterReflectance", 0)
		apply(terrain, "WaterTransparency", 1)
	end
	apply(Lighting, "GlobalShadows", false)
	apply(Lighting, "FogEnd", 9e9)
	apply(Lighting, "FogStart", 9e9)

	local rendering = engineSettings("RenderSettings", "Rendering")
	if rendering then apply(rendering, "QualityLevel", Enum.QualityLevel.Level01) end

	local effects = Inst.ofClass(Lighting, "PostEffect", true)
	for i = 1, #effects do apply(effects[i], "Enabled", false) end
end

local antilag = Feature.new("antilag", {
	command  = "antilag",
	describe = "graphics stripped back",

	start = function(self)
		-- Registered before anything is written, so a sweep that throws part way
		-- through still has a restore path.
		self.bin:add(function() Snapshot.restoreTag(ANTILAG_TAG) end)
		worldSettings()

		-- Legacy walked game:GetDescendants() in one synchronous loop (8040).
		self.bin:spawn(function()
			local descendants = game:GetDescendants()
			for i = 1, #descendants do
				flatten(descendants[i])
				if i % SWEEP_CHUNK == 0 then task.wait() end
			end
			self.state.swept = #descendants
		end)

		local pending = {}
		self.bin:connect(Workspace.DescendantAdded, function(child)
			if isEffect(child) then
				pending[#pending + 1] = child
			elseif isA(child, "BasePart") then
				apply(child, "CastShadow", false)
			end
		end)

		--[[ Legacy spawned a thread per descendant that waited one Heartbeat before
		     destroying it (8064-8071), so a game spawning effects in bulk spawned
		     thousands of untracked threads. One tracked loop drains the queue on
		     the same frame boundary instead. ]]
		self.bin:add(Sched.frameLoop("antilag.reap", function()
			for i = #pending, 1, -1 do
				local child = pending[i]
				pending[i] = nil
				pcall(function() child:Destroy() end)
			end
		end, "heartbeat"))
	end,
})

-- ── frame rate ──────────────────────────────────────────────────────────────

local fpscap = Feature.new("fpscap", {
	command  = "setfpscap",
	describe = "frame rate capped",

	start = function(self)
		local setter = Env.fn.setfpscap
		if not setter then Guard.fail("%s", Env.explain("setfpscap")) end
		local cap = self:option("fps", UNCAPPED)
		if cap == math.huge then cap = UNCAPPED end
		local ok, err = pcall(setter, cap)
		if not ok then
			Guard.fail("your executor refused a cap of %s (%s)", tostring(cap), tostring(err))
		end
		self.state.cap = cap
		self.bin:add(function() pcall(setter, UNCAPPED) end)
	end,
})

-- ── 3D rendering ────────────────────────────────────────────────────────────

local norender = Feature.new("norender", {
	command  = "norender",
	describe = "3D rendering off",

	start = function(self)
		local ok, err = pcall(function() RunService:Set3dRenderingEnabled(false) end)
		if not ok then
			Guard.fail("your client will not switch 3D rendering off (%s)", tostring(err))
		end
		-- The restore is what makes `;render` and `;unloadiy` safe. Legacy had
		-- neither, so unloading IY with rendering off left a black screen.
		self.bin:add(function()
			pcall(function() RunService:Set3dRenderingEnabled(true) end)
		end)
	end,
})

-- ── network ─────────────────────────────────────────────────────────────────

--[[ SetOutgoingKBPSLimit is a method with no readable counterpart, so there is
     nothing for core/snapshot to record: "off" means "no limit" rather than "the
     limit you had", which is still a restore where legacy had none. ]]
local datalimit = Feature.new("datalimit", {
	command  = "datalimit",
	describe = "outgoing data throttled",

	start = function(self)
		local client = Services.get("NetworkClient")
		if not client then Guard.fail("your client has no NetworkClient") end
		local limit = self:option("kbps", 50)
		local ok, err = pcall(function() client:SetOutgoingKBPSLimit(limit) end)
		if not ok then
			Guard.fail("could not set the outgoing data limit (%s)", tostring(err))
		end
		self.state.kbps = limit
		self.bin:add(function()
			pcall(function() client:SetOutgoingKBPSLimit(UNCAPPED) end)
		end)
	end,
})

local replicationlag = Feature.new("replicationlag", {
	command  = "replicationlag",
	describe = "incoming replication delayed",

	start = function(self)
		local network = engineSettings("NetworkSettings", "Network")
		if not network then Guard.fail("your executor cannot reach NetworkSettings") end
		local seconds = self:option("seconds", 0)
		local ok, reason = Snapshot.set(network, "IncomingReplicationLag", seconds, NETWORK_TAG)
		if not ok then Guard.fail("could not set the replication lag (%s)", tostring(reason)) end
		self.state.seconds = seconds
		self.bin:add(function() Snapshot.restore(network, "IncomingReplicationLag") end)
	end,
})

-- ── wall walking ────────────────────────────────────────────────────────────

local WALLWALK_URL = "https://raw.githubusercontent.com/infyiff/backup/main/wallwalker.lua"

--[[ The external script owns its own loop, so this cannot be stopped cleanly:
     stopping the feature only releases the latch below, and the fetched script
     keeps running until you rejoin. `ignoreRestart` is the point of wrapping it
     at all -- legacy `;wallwalk` twice meant two copies of that loop fighting
     over your character. ]]
local wallwalk = Feature.new("wallwalk", {
	command       = "wallwalk",
	describe      = "external wall-walk script running",
	ignoreRestart = true,

	start = function(self)
		local load = Env.fn.loadstring
		if not load then Guard.fail("%s", Env.explain("loadstring")) end

		local ok, body = Guard.call("wallwalk.fetch", function()
			return game:HttpGet(WALLWALK_URL)
		end)
		if not ok or type(body) ~= "string" or body == "" then
			Guard.fail("could not download the wall-walk script")
		end

		local chunk, err = load(body)
		if type(chunk) ~= "function" then
			Guard.fail("the wall-walk script did not compile (%s)", tostring(err))
		end
		local ran, runError = Guard.call("wallwalk.run", chunk)
		if not ran then
			Guard.fail("the wall-walk script errored (%s)", Guard.describe(runError))
		end
	end,
})

-- ── exports ─────────────────────────────────────────────────────────────────

M.antilag        = antilag
M.fpscap         = fpscap
M.norender       = norender
M.datalimit      = datalimit
M.replicationlag = replicationlag
M.wallwalk       = wallwalk

--[[ `;removeterrain` and `;clearnilinstances` are one-shot and hold no state, so
     they live in the command pack; these two only exist here because the value
     they report is worth keeping next to the rest of the sweep. ]]
function M.clearTerrain()
	local terrain = Workspace:FindFirstChildWhichIsA("Terrain")
	if not terrain then Guard.fail("this game has no terrain") end
	local ok, err = pcall(function() terrain:Clear() end)
	if not ok then Guard.fail("the terrain could not be cleared (%s)", tostring(err)) end
	return true
end

function M.clearNilInstances()
	local getnilinstances = Env.fn.getnilinstances
	if not getnilinstances then Guard.fail("%s", Env.explain("getnilinstances")) end
	local ok, list = pcall(getnilinstances)
	if not ok or type(list) ~= "table" then
		Guard.fail("your executor would not list the parentless instances")
	end
	local destroyed = 0
	for i = 1, #list do
		if pcall(function() list[i]:Destroy() end) then destroyed = destroyed + 1 end
	end
	return destroyed, #list
end

return M
