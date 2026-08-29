# Architecture

Infinite Yield used to be one 13,412-line file: a single Lua scope holding 377
globals, 430 commands, 4,900 lines of interface code and every piece of state in
between. This document describes what replaced it and why each boundary is where
it is.

## The shape

```
loader.lua        remote loader (fetches modules one by one, for development)
source            the built bundle everyone actually loads
src/
  runtime.lua     module registry — embedded verbatim in both of the above
  entry.lua       shared bootstrap — embedded verbatim in both of the above
  boot.lua        ordered startup phases
  manifest.lua    generated list of modules
  core/           runtime services with no knowledge of commands or UI
  cmd/            the command framework
  features/       stateful subsystems commands drive
  commands/       declarative command packs
  ui/             the interface (moved, not redesigned)
  compat/         backward compatibility for legacy plugins
tools/            build, static checks, analysis
tests/            headless Roblox emulator + specs
docs/
```

Dependencies point one way: `commands → features → core`, and `ui → core` plus
the specific owners it renders (`cmd/registry`, `cmd/binds`, `features/waypoints`,
…). Nothing in `core/` imports `cmd/` or `ui/`, and nothing in `features/`
imports `ui/`. That is what lets the command set work when the interface fails to
mount.

## One loader

`src/runtime.lua` is the only module resolver in the project. It is inlined into
`loader.lua` and into `source` by `tools/build.py`, so both paths have identical
semantics — memoised singletons, cycle detection with the import chain in the
error, per-module timing, and LIFO teardown.

Every module is a chunk whose only vararg is the runtime:

```lua
local IY = ...
local Log = IY.import("core/log")
local M = {}
...
return M
```

In remote mode the chunk *is* the factory. In bundle mode the builder wraps the
identical body in `IY.define("name", function(...) <body> end)`. No source
rewriting, no runtime string compilation, one set of semantics. A module that
forgets `return M` fails loudly at import instead of mysteriously later.

Adding a file to `src/` is all it takes to register it: the build generates the
manifest, and `boot` picks up anything under `commands/` by prefix.

## core/

| Module | Responsibility |
|---|---|
| `env` | Every executor function looked up once, with `has`/`usable`/`need`. Commands declare `requires = { capability = "hookfunction" }` and get "your executor does not support this" instead of a nil-call. |
| `services` | Cached, `cloneref`'d service access; `Services.get(name)` is nil-safe for services older clients lack. |
| `platform` | Mobile/console/desktop, legacy-chat detection, place and job id. |
| `signal` | Pure-Lua emitter. Handlers are isolated, disconnecting during a fire is safe, and every connection remembers where it was made. |
| `bin` | The cleanup contract. Connections, instances, threads, functions and nested bins go in; `empty()` takes them all out. |
| `scheduler` | Named loops. Starting a loop whose label is already running *replaces* it, and a loop that throws five times in a row is stopped and logged once instead of erroring every frame forever. |
| `guard` | Error classification: user error, missing capability, or real bug. Each gets a different treatment. |
| `log` | Levelled logging into a ring buffer, so failures are recorded even when console output is off. |
| `notify` | User-facing messages, available from the first module onward; buffered and replayed when the UI mounts. |
| `json`, `fs`, `store` | Persistence. `fs` has a coalescing single-writer queue and atomic writes; `store` is a typed, versioned, validated settings document with change notification. |
| `hooks` | **One** `__namecall`/`__index`/`__newindex` dispatcher for the whole script, with registration by id so a command run twice cannot stack a second layer. |
| `snapshot` | Records the original value the first time anything touches a property, so restore is exact and `;unloadiy` can put the world back. |
| `character` | The local character lifecycle: one `CharacterAdded` connection, a `spawned` signal that fires *after* the root part exists, and `reapply(label, fn)` — the mechanism that replaces thirteen bespoke respawn handlers. |
| `target` | What a command operates on. Wraps a Player or an NPC model; `character`, `root`, `humanoid`, `alive` are looked up on access, so a target held across a respawn points at the new character. |
| `players` | The target query engine: `all`, `others`, `%team`, `#3`, `nearest`, `rad50`, `bob,jim`, `all-bob`, `@name`, user ids. |

## cmd/

The framework that makes a command a piece of data.

```lua
group{
    name        = "speed",
    aliases     = { "ws", "walkspeed" },
    description = "Sets how fast a player walks.",
    args = {
        { name = "players", type = "players" },
        { name = "speed",   type = "number", default = 16, min = 0 },
    },
    run = function(ctx)
        ctx:each(function(target)
            target:requireHumanoid().WalkSpeed = ctx.args.speed
        end)
    end,
}
```

Everything else is derived from that table:

* **`types`** — 17 argument types that parse, validate, describe themselves for
  the usage line, and provide autocomplete. `;speed all fast` now says
  `speed: 'fast' is not a number` and does not run; before, it assigned the
  string.
* **`parser`** — the legacy command-line grammar (`\` chains, `5^`, `5^0.5^`,
  `inf^`, `!name`) plus quoting, and token offsets so a greedy argument gets the
  exact remainder of the line.
* **`registry`** — indexing, collision rejection, and generation of `un<name>`,
  `no<name>` and `toggle<name>` from a single `off` handler. That last part
  removed about a third of the legacy command count, and those siblings can no
  longer drift out of sync.
* **`dispatch`** — guards, then argument parsing, then the run loop. Every
  failure mode reports: user errors show the message and the usage, missing
  capabilities explain themselves, internal errors notify once and log a
  traceback, and an unknown command suggests the closest match.
* **`context`** — what `run` receives, including `ctx:each` which attempts every
  target and isolates failures. The legacy `for i,v in pairs(players)` loop
  aborted on the first failure, so `;kill all` stopped at the first player who
  had just died.
* **`aliases`, `binds`, `history`, `input`** — user aliases (which can now carry
  arguments), keybinds (keyed index rather than a linear scan), command history,
  and the chat/keyboard entry points.

## features/

A feature is anything that stays on until told otherwise. `features/feature.lua`
is the base class, and it exists because the analysis of the legacy code found
the same four bugs in cluster after cluster:

1. running the on-command twice started a second loop
2. the off-command threw when the feature had never been started
3. death broke the feature but left its connections alive
4. `;unloadiy` left everything running

```lua
local feature = Feature.new("fly", {
    command = "fly",      -- keeps ;togglefly's state honest
    reapply = true,       -- re-arm after a respawn
    start = function(self, opts)
        self.bin:connect(RunService.RenderStepped, step)
        self.bin:add(Instance.new("BodyVelocity"))
    end,
})
```

`start` on a running feature stops it first. `stop` on an idle feature is a
no-op. Everything created goes in `self.bin`. Respawn re-application is one flag.
`Feature.stopAll()` and the unload hook are automatic. All four bug classes stop
being possible rather than being fixed one at a time.

## ui/

The interface is deliberately *unchanged* — same layout, colours, tweens and
behaviour. What changed is that it is a set of modules with explicit imports
instead of 4,900 lines in the shared scope, and that it is **optional**: `boot`
mounts it in a contained phase, so a broken panel or a hostile CoreGui degrades
to "commands work, no window" instead of taking the script down.

Two things the interface no longer owns:

* the command list is built from `Registry.all()` instead of a hard-coded
  436-row table that had to be edited alongside every command
* chat and join logging live in `features/chatlogs`, so logging works whether or
  not the log window exists

`ui/theme.lua` keeps the six colour registries, but with `register`/`unregister`
— the legacy registries only ever grew, so `text1` held 440+ entries immediately
after boot and every list refresh added more.

## Startup

`boot.lua` runs ordered phases, each contained:

```
environment → settings → lifecycle → commands → bindings
            → interface → input → plugins → version
```

Only `environment`, `lifecycle` and `commands` are required. Everything else can
fail without stopping the rest, and what failed is reported by `;iydiag`.

## Verification

Because the source is plain Lua 5.1 (no Luau-only syntax), the whole bundle can
be loaded and run headlessly.

* `tools/check.py` — syntax, module shape, banned constructs, unknown imports,
  accidental globals, command-pack conventions.
* `tests/stub/` — a Roblox emulator: instances, signals, a cooperative scheduler
  over a virtual clock, datatypes, services, a character rig, and a virtual
  filesystem.
* `tests/run.lua` — boots the **built bundle** in that emulator and runs the
  specs: parser, types, registry integrity, player queries, settings migration,
  the dispatch pipeline, feature semantics, a smoke sweep that runs every
  command, and an unload spec that asserts nothing is left behind.

The smoke sweep is the one that matters most: it executes every registered
command and fails the build if any of them raises an *internal* error. A user
error is a pass — that is the framework doing its job.

## Extending it

Adding a command: one table in a file under `src/commands/`. See
`docs/ADDING-COMMANDS.md`.

Adding a feature: `Feature.new(name, { start = ... })` in `src/features/`.

Adding an argument type: `Cmd.defineType(name, { parse, complete, describe })`.

Plugins: the same API. `IY.command{...}` from any external script, or the legacy
`addcmd(name, aliases, fn)` surface through `compat/legacy.lua` so existing `.iy`
plugins keep working. Plugin commands are tagged with an owner, so a plugin can
now be unloaded — the legacy loader could not remove what it had added.
