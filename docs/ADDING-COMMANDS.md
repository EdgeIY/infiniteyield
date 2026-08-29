# Adding commands

A command is one table. Everything else — usage text, the entry in the command
list, autocomplete, the `un`/`toggle` siblings, the docs page — is derived from
it.

```lua
local IY = ...
local Cmd = IY.import("cmd/api")

local group = Cmd.group{ category = "Character" }

group{
    name        = "speed",
    aliases     = { "ws", "walkspeed" },
    description = "Sets how fast a player walks.",
    args = {
        { name = "players", type = "players" },
        { name = "speed",   type = "number", default = 16, min = 0, max = 1000 },
    },
    examples = { "speed", "speed all 100" },
    requires = { character = true },
    run = function(ctx)
        ctx:each(function(target)
            target:requireHumanoid().WalkSpeed = ctx.args.speed
        end)
    end,
}
```

That is the whole contract. `;speed`, `;ws all 100`, `;speed bob,jim 0` and the
autocomplete entry all work, and `;speed all fast` tells the user
`speed: 'fast' is not a number` with the usage line instead of silently
assigning a string.

## Definition fields

| Field | Required | Meaning |
|---|---|---|
| `name` | yes | Canonical name, lowercase, alphanumeric |
| `run(ctx)` | yes | The implementation |
| `aliases` | | Extra names. Collisions are rejected with a diagnostic |
| `description` | | One sentence, shown in the tooltip and docs |
| `category` | | Grouping for the UI and docs. Usually set once via `Cmd.group` |
| `args` | | Argument specs, in order |
| `off(ctx)` | | Turns the feature off. Generates `un<name>`, `no<name>`, `toggle<name>` |
| `offArgs` | | Argument specs for the generated off command. Defaults to `args` |
| `offAliases` | | Extra aliases for the generated off command |
| `offDescription` | | Overrides the generated description |
| `toggle = false` | | Suppresses the generated `toggle<name>` |
| `requires` | | Preconditions, checked before `run` (see below) |
| `examples` | | Strings shown in help and the docs |
| `cooldown` | | Minimum seconds between runs |
| `singleton` | | Refuse to start a second concurrent run |
| `hidden` | | Keep out of the command list (debug/internal commands) |
| `tags` | | Free-form labels for filtering |

## Argument specs

```lua
{ name = "speed", type = "number", default = 16, min = 0, max = 500 }
```

| Field | Meaning |
|---|---|
| `name` | Key in `ctx.args`, and the label in the usage string |
| `type` | One of the types below, or one you registered |
| `optional` | May be omitted. Implied by `default` |
| `default` | Value when omitted. Strings and numbers are parsed *through the type*, so `default = "me"` on a `players` argument arrives as a Target list |
| `min`, `max` | Numeric bounds, enforced with a readable error |
| `values` | For `enum`: the allowed values |
| `enum`, `enumName` | For `enumitem`: the Roblox `Enum` to accept |

Rules the registry enforces at load time (so a mistake is a build failure, not a
runtime surprise):

* a required argument may not follow an optional one
* a greedy argument (`text`, `command`, `waypoint`, `tool`, `raw`) must be last
* the type must exist

An **optional `players` argument defaults to you**, matching the legacy
`getPlayer(nil, speaker)` behaviour. Write `default = "all"` when the command
should hit everyone instead.

## Built-in types

| Type | Accepts | `ctx.args.x` is |
|---|---|---|
| `players` | `bob`, `all`, `others`, `%team`, `#3`, `nearest`, `rad50`, `bob,jim`, `all-bob`, `@exactname`, a user id | array of Targets |
| `player` | same | one Target |
| `number` | `5`, `-2.5`, `1e3`, `50%`, `inf` | number |
| `integer` | whole numbers | number |
| `boolean` | `on/off/true/false/1/0/yes/no/enable/disable` | boolean |
| `string` | one token (quotes group words) | string |
| `text` | the rest of the line, verbatim | string |
| `enum` | one of `values`, prefix-matched | the matched value |
| `enumitem` | a name from `spec.enum` | EnumItem |
| `keycode` | `f`, `LeftShift`, `KeypadEnter` | `Enum.KeyCode` |
| `vector3` | `1,2,3` | Vector3 |
| `color` | `red`, `#ff8800`, `255,0,0`, `1,0.5,0` | Color3 |
| `time` | `5`, `500ms`, `1m30s` | number of seconds |
| `class` | a Roblox class name, validated | string |
| `command` | a command name, autocompleted | string |
| `waypoint` | a saved waypoint name, autocompleted | string |
| `tool` | a tool in your inventory, autocompleted | string |
| `raw` | anything, unvalidated | string |

Register your own with `Cmd.defineType(name, { parse = ..., complete = ..., describe = ... })`.
`parse` raises through `Guard.fail` for bad input; the dispatcher turns that into
a user-facing message.

## `requires`

Checked before arguments are parsed, so the message is about the real problem:

```lua
requires = {
    character  = true,          -- you have a character
    root       = true,          -- ...and its root part exists
    alive      = true,          -- ...and you are not dead
    tool       = true,          -- you are holding or carrying a tool
    capability = "hookfunction",-- your executor supports this (string or list)
    persist    = true,          -- file access works
    desktop    = true,          -- not mobile
    check      = function(ctx) return cond, "why not" end,
}
```

A missing capability produces
`Your executor (Foo) does not support 'hookfunction'.` rather than an error from
inside the command.

## The context object

| Member | What it is |
|---|---|
| `ctx.args.<name>` | Parsed arguments |
| `ctx.speaker` | Target who ran the command |
| `ctx.raw`, `ctx.rawArgs` | The original text |
| `ctx.iteration` | Which repeat this is (`;5^jump`) |
| `ctx:each(fn)` | Run `fn(target, index)` for each target, isolating failures |
| `ctx:targets(name?)` | The resolved target list |
| `ctx:target(name?)` | The first target |
| `ctx:reply(text)` | Notification titled with the command name |
| `ctx:notify(title, text)` | Notification with an explicit title |
| `ctx:fail(fmt, ...)` | Abort with a message the user sees |
| `ctx:assert(cond, fmt, ...)` | `fail` unless `cond` |
| `ctx:quiet()` | True when invoked with `nonotify` |
| `ctx.log` | Scoped logger: `.debug/.info/.warn/.error` |

`ctx:each` matters: it attempts every target and reports a summary, where the
legacy `for i,v in pairs(players)` loop aborted on the first failure — which is
why `;kill all` used to stop at the first player who had just died.

## Targets

`players` and `player` arguments produce Targets, not names. A Target's
character-related fields are looked up on access, so a Target held across a
respawn points at the *new* character.

| Member | Notes |
|---|---|
| `target.name`, `target.displayName`, `target.userId` | |
| `target.player` | Player instance, or nil for an NPC |
| `target.character`, `target.root`, `target.humanoid` | nil-safe |
| `target.alive`, `target.health`, `target.position`, `target.cframe` | |
| `target.team`, `target.backpack`, `target.tools`, `target.isLocal` | |
| `target:requireCharacter()` / `requireRoot()` / `requireHumanoid()` | raise `"X has no character right now"` |
| `target:requirePlayer()` | raise when the target is an NPC |
| `target:distanceTo(position)`, `target:label()` | |

## State goes in a feature

Anything that stays on after the command returns belongs in `src/features/`, not
in the command file:

```lua
local Feature = IY.import("features/feature")

local feature = Feature.new("spin", {
    command  = "spin",     -- keeps ;togglespin in sync
    reapply  = true,       -- re-arm automatically after a respawn
    start = function(self, opts)
        local root = Character.requireRoot()
        local force = self.bin:add(Instance.new("BodyAngularVelocity"))
        force.AngularVelocity = Vector3.new(0, opts.speed or 25, 0)
        force.Parent = root
        self.bin:connect(SomeSignal, handler)
    end,
})
```

Everything in `self.bin` is cleaned up when the feature stops, when the player
respawns before it re-applies, and when IY unloads. That is why `un<anything>`
is always safe to run, even when the feature was never started — the single most
common crash in the legacy command set.

Available on a feature: `:start(opts)`, `:stop()`, `:toggle(opts)`,
`:isRunning()`, `:configure(patch)`, `:option(key, default)`, `self.bin`,
`self.state`, `self.log`.

Bin helpers: `bin:add(x)`, `bin:connect(signal, fn)`, `bin:onChange(inst, prop, fn)`,
`bin:spawn(fn)`, `bin:delay(s, fn)`, `bin:instance(class, props)`,
`bin:branch(label)`, `bin:empty()`.

## Composing commands

Call another command when you genuinely want its user-visible behaviour:

```lua
Cmd.runSync("noclip nonotify", ctx.speaker)
```

Otherwise import the feature and call its API directly — it is faster and does
not depend on the other command's name.

## Checklist

* `luajit -e 'assert(loadfile("src/commands/yours.lua"))'` parses
* `python3 tools/check.py` passes (naming, collisions, arg specs, no globals)
* Every command has a `description`
* Every stateful command has an `off`, and its feature cleans up in the bin
* No `wait()` — use `task.wait()`
* No direct `Instance.new` without a bin or an explicit owner
* Numbers come from `ctx.args`, never from `tonumber(args[1])`
