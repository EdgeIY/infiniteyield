--[[═══════════════════════════════════════════════════════════════════════════
	features/walltp · climb whatever you walk into
	─────────────────────────────────────────────────────────────────────────
	Touch a part above your feet and you get put on top of it.

	Legacy equivalent: source.ref.lua 12217-12243. The connection was made
	against the torso that existed when the command ran and stored in the module
	global `walltpTouch`, so:

	  · it stopped working after a respawn, silently, with `;walltp` still
	    "on" as far as the user could tell
	  · running it twice stacked a second Touched handler on the same torso and
	    only the second could be disconnected
	  · `speaker.Character.UpperTorso` / `.Torso` were indexed directly, so a
	    custom rig with neither threw

	The handler now lives in the feature bin and re-arms on the new torso after
	every respawn.
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Feature   = IY.import("features/feature")
local Character = IY.import("core/character")
local Inst      = IY.import("core/util/instances")

local M = {}

--[[ The part legacy hung the Touched handler on: UpperTorso on R15, Torso on
     R6, and the root part for anything else. ]]
local function torsoOf(character)
	local name = Inst.isR15(character) and "UpperTorso" or "Torso"
	local part = character:FindFirstChild(name)
	if part and part:IsA("BasePart") then return part end
	return Inst.root(character)
end

local function onTouched(hit)
	if not hit or not hit:IsA("BasePart") then return end

	local root = Character.root()
	local humanoid = Character.humanoid()
	if not root or not humanoid then return end

	local hipHeight = humanoid.HipHeight
	-- Only climb things whose surface is above our feet; anything lower is the
	-- floor we are already standing on.
	if hit.Position.Y <= root.Position.Y - hipHeight then return end

	local look = root.CFrame.LookVector
	-- Legacy measured off the *root part* of whatever it hit when that thing was
	-- a character (Size.Z, because a torso is deeper than it is tall) and off the
	-- part itself otherwise.
	local parent = hit.Parent
	local other = parent and Inst.humanoid(parent) and Inst.root(parent) or nil
	local rise = other and (other.Size.Z / 2) or (hit.Size.Y / 2)

	root.CFrame = hit.CFrame * CFrame.new(look.X, rise + hipHeight, look.Z)
end

local feature = Feature.new("walltp", {
	command  = "walltp",
	reapply  = true,
	describe = "wall teleporting",

	start = function(self)
		local character = Character.require()
		-- No torso means no root either, so requireRoot raises the clean
		-- "your character is still loading" message instead of indexing nil.
		local torso = torsoOf(character) or Character.requireRoot()
		self.bin:connect(torso.Touched, onTouched)
	end,
})

M.feature = feature

function M.start(opts) return feature:start(opts or {}) end
function M.stop() return feature:stop() end
function M.toggle(opts) return feature:toggle(opts) end
function M.isRunning() return feature:isRunning() end

return M
