--[[═══════════════════════════════════════════════════════════════════════════
	commands/attach · riding players, and the accessory tricks
	─────────────────────────────────────────────────────────────────────────
	bang, carpet, headsit, jerk, hatspin, clearhats, creeper, friend and
	unfriend. The state is in features/attach and features/hatspin; this file is
	arguments and messages.

	`creeper` is here because it belongs with the body-mangling commands, not
	because it attaches to anybody -- it never did.

	Each of bang / carpet / headsit writes your root CFrame every frame, so the
	features are mutually exclusive: starting one stops the others. Legacy left
	that to a `execCmd('unbang')` line at the top of each command, which only
	ever cleared its own.

	Legacy equivalent: source.ref.lua 10645-10658, 10812-10920, 11240-11318,
	12757-12802.
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Cmd       = IY.import("cmd/api")
local Character = IY.import("core/character")
local Sched     = IY.import("core/scheduler")
local Guard     = IY.import("core/guard")
local Inst      = IY.import("core/util/instances")
local Attach    = IY.import("features/attach")
local Hatspin   = IY.import("features/hatspin")

local group = Cmd.group{ category = "Fun" }

-- ── attaching ───────────────────────────────────────────────────────────────

group{
	name = "bang",
	aliases = { "rape" },
	description = "Attaches you to a player with an animation. With no player, plays the animation only.",
	args = {
		--[[ A function default resolves to nil, which is what keeps the
		     no-target branch reachable: an optional `player` argument otherwise
		     defaults to you. ]]
		{ name = "player", type = "player", default = function() return nil end },
		{ name = "speed",  type = "number", default = 3, min = 0, max = 20 },
	},
	examples = { "bang bob", "bang bob 5", "bang", "unbang" },
	requires = { character = true, root = true, alive = true },
	offAliases = { "unrape" },
	run = function(ctx)
		Attach.bang:start({ target = ctx.args.player, speed = ctx.args.speed })
	end,
	off = function() Attach.bang:stop() end,
}

group{
	name = "carpet",
	description = "Lies you flat under a player and follows them. R6 only.",
	args = {
		{ name = "player", type = "player", default = function() return nil end },
	},
	examples = { "carpet bob", "uncarpet" },
	requires = { character = true, root = true, alive = true },
	-- A no-argument toggle cannot know who to carpet, and legacy had no
	-- togglecarpet either.
	toggle = false,
	offArgs = {},
	run = function(ctx)
		ctx:assert(ctx.args.player, "who should I carpet?")
		Attach.carpet:start({ target = ctx.args.player })
	end,
	off = function() Attach.carpet:stop() end,
}

group{
	name = "headsit",
	description = "Sits you on a player's head. Stand up to get off.",
	args = {
		{ name = "player", type = "player", default = function() return nil end },
	},
	examples = { "headsit bob", "unheadsit" },
	requires = { character = true, root = true, alive = true },
	toggle = false,
	offArgs = {},
	offDescription = "Gets you off a player's head.",
	run = function(ctx)
		ctx:assert(ctx.args.player, "whose head should I sit on?")
		Attach.headsit:start({ target = ctx.args.player })
	end,
	-- Legacy had no way off other than standing up, which its own loop watched
	-- for; the feature keeps that and adds the command.
	off = function() Attach.headsit:stop() end,
}

group{
	name = "jerk",
	description = "Adds a tool to your inventory that plays an animation while equipped.",
	examples = { "jerk", "unjerk" },
	requires = { character = true, alive = true },
	run = function(ctx)
		Attach.jerk:start()
		if not ctx:quiet() then ctx:reply("Equip the tool in your inventory") end
	end,
	-- New: legacy's loop had no off switch at all (12783).
	off = function() Attach.jerk:stop() end,
}

-- ── accessories ─────────────────────────────────────────────────────────────

group{
	name = "hatspin",
	aliases = { "spinhats" },
	description = "Detaches your accessories and spins them around your head.",
	args = {
		{ name = "speed", type = "number", default = 100, min = 0 },
	},
	examples = { "hatspin", "hatspin 250", "unhatspin" },
	requires = { character = true, alive = true },
	offAliases = { "unspinhats" },
	offArgs = {},
	run = function(ctx)
		Hatspin.start({ speed = ctx.args.speed })
	end,
	off = function() Hatspin.stop() end,
}

group{
	name = "clearhats",
	aliases = { "cleanhats" },
	description = "Picks up every accessory lying loose in the map and deletes it, then respawns you where you were.",
	examples = { "clearhats" },
	requires = { character = true, root = true, capability = "firetouchinterest" },
	run = function(ctx)
		local touch = Guard.need("firetouchinterest")
		local character = Character.require()
		local humanoid = Character.requireHumanoid()

		--[[ `Accoutrement` rather than legacy's `Accessory` (11288), which is one
		     subclass of it -- the old `Hat` class is the other, and every hat in
		     a pre-2018 map is one. ]]
		local loose = Inst.ofClass(workspace, "Accoutrement")
		if #loose == 0 then ctx:fail("there are no loose accessories in this map") end

		for _, worn in ipairs(humanoid:GetAccessories()) do
			pcall(function() worn:Destroy() end)
		end

		local collected = 0
		for i = 1, #loose do
			local accessory = loose[i]
			local handle = accessory.Parent and accessory:FindFirstChild("Handle")
			local root = Character.root()
			if handle and root then
				touch(handle, root, 0)
				--[[ Legacy waited on three unbounded `repeat Heartbeat:wait()
				     until ...` loops (11298-11302), so one accessory that could
				     not be picked up hung the command thread for good. ]]
				local arrived = Sched.waitUntil(function()
					return character:FindFirstChildWhichIsA("Accoutrement")
				end, 1)
				if arrived then
					local picked = character:FindFirstChildWhichIsA("Accoutrement")
					if picked then pcall(function() picked:Destroy() end) end
					Sched.waitUntil(function()
						return character:FindFirstChildWhichIsA("Accoutrement") == nil
					end, 1)
					collected = collected + 1
				end
			end
		end

		if not ctx:quiet() then
			ctx:notify("Clear Hats", string.format("Removed %d of %d", collected, #loose))
		end
		-- Replaces legacy's `reset` + CharacterAdded:Wait + a 20-frame loop that
		-- rewrote the CFrame through `getRoot(...).Humanoid.RootPart` (11312).
		Character.refresh()
	end,
}

-- ── body ────────────────────────────────────────────────────────────────────

group{
	name = "creeper",
	description = "Removes your arms and your head's mesh.",
	examples = { "creeper" },
	requires = { character = true },
	run = function(ctx)
		--[[ Legacy indexed `Head:FindFirstChildOfClass("SpecialMesh"):Destroy()`
		     and `Character["Left Arm"]` straight (10814-10821), both of which
		     throw on any rig missing them -- and the error was swallowed, so the
		     command "did nothing" on every custom character. ]]
		local character = Character.require()
		local humanoid = Character.requireHumanoid()

		local head = character:FindFirstChild("Head")
		local mesh = head and head:FindFirstChildOfClass("SpecialMesh")
		if mesh then pcall(function() mesh:Destroy() end) end

		local arms = Inst.isR15(character)
			and { "LeftUpperArm", "RightUpperArm" }
			or { "Left Arm", "Right Arm" }
		for i = 1, #arms do
			local limb = character:FindFirstChild(arms[i])
			if limb then pcall(function() limb:Destroy() end) end
		end

		pcall(function() humanoid:RemoveAccessories() end)
	end,
}

-- ── friends ─────────────────────────────────────────────────────────────────

--[[ `friend` and `unfriend` were two legacy commands; declaring `off` makes them
     one pair, which is also how `;unfriend` stops being a command that resolves
     an optional player list to *you* and then asks the server to unfriend
     yourself (10915). ]]
local function friendship(ctx, method, blocked)
	local me = ctx.speaker:requirePlayer()
	ctx:each(function(target)
		local player = target:requirePlayer()
		local ok = pcall(function() me[method](me, player) end)
		if not ok then Guard.fail("%s", blocked) end
	end)
end

group{
	name = "friend",
	description = "Sends a friend request to players.",
	args = {
		--[[ Pinned to nil: `players` is optional by default and resolves to you,
		     and asking the server to friend yourself is never what was meant. ]]
		{ name = "players", type = "players", excludeSelf = true,
			default = function() return nil end },
	},
	examples = { "friend bob", "unfriend bob" },
	toggle = false,
	offDescription = "Removes players from your friends list.",
	run = function(ctx)
		ctx:assert(ctx.args.players, "who should I add?")
		friendship(ctx, "RequestFriendship", "this game does not allow friend requests from scripts")
	end,
	off = function(ctx)
		ctx:assert(ctx.args.players, "who should I remove?")
		friendship(ctx, "RevokeFriendship", "this game does not allow friend changes from scripts")
	end,
}

return true
