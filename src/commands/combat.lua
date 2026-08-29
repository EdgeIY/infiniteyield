--[[═══════════════════════════════════════════════════════════════════════════
	commands/combat · flinging, anti-fling and touch damage
	─────────────────────────────────────────────────────────────────────────
	fling / walkfling / flyfling / invisfling, antifling, handlekill, trip and
	scare. All the state is in features/fling and features/antifling; declaring
	`off` here is what generates `un<name>`, `no<name>` and `toggle<name>`, so
	the nine legacy `addcmd` blocks that existed only to flip a global are gone.

	`handlekill` is the exception: it is a single loop with no state beyond
	itself, so its Feature is declared in this file rather than given a module of
	its own. What matters is that it *is* a Feature -- the loop lives in a bin,
	`Feature.stopAll()` and `;unloadiy` reach it, and the generated
	`;unhandlekill` is safe before it has ever run.

	Legacy equivalent: source.ref.lua 11779-11977 (the fling family),
	12036-12065 (handlekill), 12646-12653 and 12672-12689 (trip and scare).
═══════════════════════════════════════════════════════════════════════════]]

local IY = ...
local Cmd       = IY.import("cmd/api")
local Feature   = IY.import("features/feature")
local Character = IY.import("core/character")
local Sched     = IY.import("core/scheduler")
local Guard     = IY.import("core/guard")
local Inst      = IY.import("core/util/instances")
local Fling     = IY.import("features/fling")
local Antifling = IY.import("features/antifling")

local group = Cmd.group{ category = "Combat" }

-- ── the fling family ────────────────────────────────────────────────────────

group{
	name = "fling",
	description = "Spins your character so anything that touches you is thrown.",
	examples = { "fling", "unfling", "togglefling" },
	requires = { character = true, root = true },
	run = function(ctx)
		Fling.fling:start()
		if not ctx:quiet() then ctx:reply("Flinging -- walk into people") end
	end,
	off = function(ctx)
		Fling.fling:stop()
		if not ctx:quiet() then ctx:reply("Stopped flinging") end
	end,
}

group{
	name = "walkfling",
	description = "Flings anyone you walk into, without spinning you.",
	examples = { "walkfling", "unwalkfling" },
	requires = { character = true, root = true },
	run = function(ctx)
		Fling.walkfling:start()
		if not ctx:quiet() then ctx:reply("Walk-flinging") end
	end,
	off = function(ctx)
		Fling.walkfling:stop()
		if not ctx:quiet() then ctx:reply("Stopped walk-flinging") end
	end,
}

group{
	name = "flyfling",
	description = "Flies you around flinging everyone you touch.",
	args = {
		{ name = "speed", type = "number", optional = true, min = 0, max = 100 },
	},
	examples = { "flyfling", "flyfling 3", "unflyfling" },
	requires = { character = true, root = true },
	offArgs = {},
	run = function(ctx)
		Fling.flyfling:start({ speed = ctx.args.speed })
		if not ctx:quiet() then ctx:reply("Fly-flinging") end
	end,
	off = function(ctx)
		Fling.flyfling:stop()
		if not ctx:quiet() then ctx:reply("Stopped fly-flinging") end
	end,
}

group{
	name = "invisfling",
	description = "Strips you to an invisible root part that flings on contact. Takes six seconds and only a respawn undoes it.",
	examples = { "invisfling", "uninvisfling" },
	requires = { character = true, root = true, alive = true },
	-- Restarting a six-second destructive sequence from a toggle is not a
	-- useful thing to be able to do by accident.
	toggle = false,
	run = function(ctx)
		if not ctx:quiet() then
			ctx:notify("Invisible Fling", "Setting up -- this takes about six seconds")
		end
		Fling.invisfling:start()
	end,
	off = function(ctx)
		Fling.invisfling:stop()
		if not ctx:quiet() then
			ctx:notify("Invisible Fling", "Stopped -- respawn to get your body back")
		end
	end,
}

-- ── antifling ───────────────────────────────────────────────────────────────

group{
	name = "antifling",
	description = "Turns off collisions on everyone else so they cannot fling you.",
	examples = { "antifling", "unantifling", "toggleantifling" },
	run = function(ctx)
		Antifling.start()
		if not ctx:quiet() then ctx:reply("Other players can no longer touch you") end
	end,
	off = function(ctx)
		Antifling.stop()
		if not ctx:quiet() then ctx:reply("Collisions restored") end
	end,
}

-- ── handlekill ──────────────────────────────────────────────────────────────

--[[ Fire the touch interest on your tool's handle against every target, which
     makes the server apply the tool's damage without you having to swing it.

     Legacy re-resolved `getPlayer(args[1])` on every frame inside the loop
     (12050), so `;handlekill all` picked up players who joined afterwards. The
     target list is resolved once here; re-running the command is how you pick up
     new joiners. Everything else is the same, including the order of the two
     `firetouchinterest` calls and the "tool left your character" stop. ]]
local handlekill = Feature.new("handlekill", {
	command  = "handlekill",
	describe = "touch-killing with a tool handle",

	start = function(self, opts)
		local touch = Guard.need("firetouchinterest")
		Character.require()
		local targets = opts.targets or {}
		local range = opts.range or math.huge

		local tool = Inst.equippedTool(Character.player)
		local handle = tool and tool:FindFirstChild("Handle")
		if not handle then
			Guard.fail('hold a Tool that damages on touch -- a sword, for example')
		end
		self.state.tool = tool

		self.bin:add(Sched.frameLoop("handlekill.step", function()
			if tool.Parent ~= Character.get() or not handle.Parent then
				self:stop()
				return
			end
			local origin = Character.position()
			for i = 1, #targets do
				local target = targets[i]
				local root = target.root
				local humanoid = target.humanoid
				if root and humanoid and not target.isLocal and humanoid.Health > 0
					and humanoid:GetState() ~= Enum.HumanoidStateType.Dead
					and (range == math.huge or target:distanceTo(origin) <= range)
				then
					touch(handle, root, 1)
					touch(handle, root, 0)
				end
			end
		end, "heartbeat"))

		self.bin:connect(Character.died, function() self:stop() end)
	end,
})

group{
	name = "handlekill",
	aliases = { "hkill" },
	description = "Repeatedly touches your tool's handle against players, so its damage applies to them.",
	args = {
		--[[ A `players` argument is optional by default and resolves to *you*.
		     Combined with `excludeSelf` that default cannot parse, and
		     cmd/context falls back to handing the command the raw string, so the
		     default is pinned to nil and asked for explicitly instead. ]]
		{ name = "players", type = "players", excludeSelf = true,
			default = function() return nil end },
		{ name = "range",   type = "number", optional = true, min = 0 },
	},
	examples = { "handlekill all", "hkill bob 50", "unhandlekill" },
	requires = { character = true, tool = true, capability = "firetouchinterest" },
	offArgs = {},
	run = function(ctx)
		ctx:assert(ctx.args.players, "who should I kill?")
		handlekill:start({ targets = ctx.args.players, range = ctx.args.range })
		if not ctx:quiet() then
			local range = ctx.args.range
			ctx:notify("Handle Kill", range
				and string.format("Started -- radius %s", tostring(range))
				or "Started")
		end
	end,
	off = function(ctx)
		handlekill:stop()
		if not ctx:quiet() then ctx:notify("Handle Kill", "Stopped") end
	end,
}

-- ── one-shot ────────────────────────────────────────────────────────────────

group{
	name = "trip",
	description = "Makes you fall flat on your face.",
	examples = { "trip" },
	requires = { character = true, root = true, alive = true },
	run = function(ctx)
		-- Legacy read `speaker.Character and ...` twice and then did nothing at
		-- all when either was missing; `requires` reports the reason instead.
		local humanoid = Character.requireHumanoid()
		local root = Character.requireRoot()
		humanoid:ChangeState(Enum.HumanoidStateType.FallingDown)
		local push = root.CFrame.LookVector * 30
		if not pcall(function() root.AssemblyLinearVelocity = push end) then
			pcall(function() root.Velocity = push end)
		end
	end,
}

group{
	name = "scare",
	aliases = { "spook" },
	description = "Teleports you nose-to-nose with a player for half a second, then puts you back.",
	args = {
		{ name = "players", type = "players", excludeSelf = true,
			default = function() return nil end },
	},
	examples = { "scare bob", "spook all" },
	requires = { character = true, root = true },
	run = function(ctx)
		ctx:assert(ctx.args.players, "who should I scare?")

		--[[ Captured once, before anything moves. Legacy re-read the position
		     at the top of each iteration (12682) -- correct only as long as
		     every restore succeeded, so one target who left mid-jump parked you
		     in front of the previous one permanently. The restore below runs
		     whatever happens. ]]
		local home = Character.requireRoot().CFrame

		local ok, err = Guard.call("cmd:scare", function()
			ctx:each(function(target)
				local frame = target:requireRoot().CFrame
				local root = Character.requireRoot()
				root.CFrame = frame + frame.LookVector * 2
				root.CFrame = CFrame.new(root.Position, frame.Position)
				task.wait(0.5)
			end)
		end)

		local root = Character.root()
		if root then pcall(function() root.CFrame = home end) end
		if not ok then error(err, 0) end
	end,
}

return true
