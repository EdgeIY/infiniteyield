# Porting brief (internal, for the rewrite)

You are porting commands out of the legacy Infinite Yield monolith into the new
modular source tree. Read this whole file, then `docs/ADDING-COMMANDS.md`, then
the two reference files:

* `src/commands/movement.lua` — the command-pack template
* `src/features/fly.lua` and `src/features/noclip.lua` — the feature template

Legacy source (read-only reference, with stable line numbers):
`tools/_analysis/source.ref.lua`

## Hard rules

1. **Lua 5.1 syntax only.** Must parse under `luajit`. No `+=`/`-=`, no
   `continue`, no `::labels::`/`goto`, no type annotations (`local x: T`), no
   backtick interpolation. Convert any of these you find in the legacy code.
2. **Every file starts with `local IY = ...`** and ends with `return M` (feature
   modules) or `return true` (command packs).
3. **Tabs** for indentation. Comments explain *why*, and only where a reader
   would otherwise wonder. Do not narrate every line. Match the density of the
   reference files. A `--[[═══ ... ═══]]` header per file stating what it covers
   and which legacy lines it replaces.
4. **No globals.** Everything `local`. No `_G` writes.
5. **No `wait()`, `spawn()`, `delay()`** — use `task.wait/task.spawn/task.delay`,
   or better, `Sched` (see below).
6. **All persistent state goes in a feature** (`src/features/*.lua`) built with
   `Feature.new`. Command files hold no mutable state beyond simple settings
   like a speed multiplier.
7. **Preserve behaviour and names.** Every legacy command name and alias must
   still work, and the observable effect must match — unless the legacy
   behaviour was a bug listed below, in which case fix it and say so in a
   comment.
8. Do not touch files you were not assigned. Do not edit `src/core/*`,
   `src/cmd/*`, `docs/*`, `tools/*`, or another agent's pack.

## What already exists (use these; do not reimplement)

```lua
local Cmd       = IY.import("cmd/api")        -- register / group / run / runSync / isActive
local Feature   = IY.import("features/feature")
local Character = IY.import("core/character")
local Players   = IY.import("core/players")
local Target    = IY.import("core/target")
local Services  = IY.import("core/services")
local Platform  = IY.import("core/platform")
local Store     = IY.import("core/store")
local Notify    = IY.import("core/notify")
local Sched     = IY.import("core/scheduler")
local Snapshot  = IY.import("core/snapshot")
local Hooks     = IY.import("core/hooks")
local Bin       = IY.import("core/bin")
local Guard     = IY.import("core/guard")
local Log       = IY.import("core/log")
local Inst      = IY.import("core/util/instances")
local Str       = IY.import("core/util/strings")
local Tbl       = IY.import("core/util/tables")
local FS        = IY.import("core/fs")
local Json      = IY.import("core/json")
```

Key APIs (read the file if you need more):

* `Cmd.group{ category = "X" }` → registrar function. `Cmd.runSync(line, speaker)`
  runs another command inline. `Cmd.isActive(name)`.
* `Feature.new(name, { command = "x", reapply = true, exclusive = {"y"},
  start = function(self, opts) ... end, stop = function(self) end })`.
  Instance: `:start(opts)`, `:stop()`, `:toggle(opts)`, `:isRunning()`,
  `:configure(patch)`, `:option(key, default)`, `self.bin`, `self.state`,
  `self.log`.
* `self.bin`: `:add(x)` (connection / instance / thread / function / nested bin),
  `:connect(signal, fn)`, `:onChange(inst, prop, fn)`, `:spawn(fn)`,
  `:delay(s, fn)`, `:instance(class, props)`, `:branch(label)`, `:empty()`.
  **Everything a feature creates goes in the bin.**
* `Character`: `.get()`, `.root()`, `.humanoid()`, `.animator()`, `.position()`,
  `.cframe()`, `.alive()`, `.player`, `.require()`, `.requireRoot()`,
  `.requireHumanoid()`, `.wait(timeout)`, `.spawned` / `.died` / `.removing`
  signals, `.onSpawn(fn)`, `.reapply(label, fn)`, `.lastDeath`, `.respawn()`,
  `.refresh()`.
* `Sched`: `.frameLoop(label, fn, "render"|"heartbeat"|"stepped")`,
  `.interval(label, seconds, fn, immediate)`, `.after(seconds, fn)`,
  `.spawn(label, fn)`, `.debounce(label, delay, fn)`, `.throttle(label, period, fn)`,
  `.waitUntil(predicate, timeout)`, `.stop(label)`. Handles have `:stop()` and go
  in a bin. **Starting a loop with a label that is already running replaces it.**
* `Snapshot`: `.set(instance, property, value, tag)` records the original once
  then assigns; `.restore(instance, property)`; `.restoreTag(tag)`;
  `.capture(instance, property, tag)`. Use this for anything you change on
  `workspace`, `Lighting`, the camera, or another player — never remember the
  old value in a module variable.
* `Hooks`: `.namecall(id, handler, opts)`, `.index(id, handler)`,
  `.newindex(id, handler)`, `.unregister(id)`, `.hookFunction(id, target, fn)`,
  `.unhookFunction(id)`, `.canHook()`. One shared dispatcher — never call
  `hookmetamethod` directly.
* `Inst`: `.root(char)`, `.humanoid(char)`, `.alive(char)`, `.tools(player)`,
  `.equippedTool(player)`, `.isR15(char)`, `.ofClass(parent, class, deep)`,
  `.waitFor(parent, name, timeout)`, `.breakVelocity(model)`,
  `.setAnchored(model, bool)`, `.path(instance)`, `.protect(gui)`,
  `.destroyWhere(parent, predicate)`.
* `Store`: `.get(key)`, `.set(key, value)`, `.watch(key, fn)`. Keys:
  `prefix`, `stayOpen`, `guiScale`, `keepIY`, `espTransparency`, `logsEnabled`,
  `joinLogsEnabled`, `logsWebhook`, `aliases`, `binds`, `spawnCommands`,
  `waypoints`, `plugins`, `theme.shade1..3`, `theme.text1..2`, `theme.scroll`,
  `eventBinds`.
* `Guard.fail("message %s", x)` aborts with a user-facing message.
  `Guard.call(label, fn, ...)` contains an error. `Guard.try(fn)` returns nil on
  error. `Env.usable("capability")` before using an executor function.

## Translating legacy idioms

| Legacy | New |
|---|---|
| `addcmd('x',{'y'},function(args,speaker)` | `group{ name = "x", aliases = {"y"}, run = function(ctx)` |
| `getPlayer(args[1], speaker)` then `Players[v]` | `args = {{name="players",type="players"}}` then `ctx:each(function(target)` |
| `tonumber(args[2]) or 16` | `{ name = "amount", type = "number", default = 16 }` |
| `getstring(1, args)` | `{ name = "message", type = "text" }` |
| `parseBoolean(args[1], true)` | `{ name = "enabled", type = "boolean", default = true }` |
| `notify("Title","Body")` | `ctx:notify("Title", "Body")` or `ctx:reply("Body")` |
| `if args[1] == "nonotify" then return end` | `if not ctx:quiet() then ctx:reply(...) end` |
| `getRoot(char)` | `Inst.root(char)` / `target.root` / `Character.root()` |
| `speaker.Character` | `Character.get()` (local) or `target.character` |
| `execCmd('clip')` | `Cmd.runSync("unnoclip nonotify", ctx.speaker)` or the feature API |
| a module-level flag + connection | a `Feature` with `self.bin` |
| `X:Disconnect()` in an un-command | `feature:stop()` (safe when never started) |
| `hookmetamethod(game, "__namecall", ...)` | `Hooks.namecall("id", handler)` |
| remembering an old property value | `Snapshot.set(...)` / `Snapshot.restore(...)` |
| `workspace.CurrentCamera` used unguarded | check for nil; it can be nil for a frame after a respawn |

`;breakloops` works through the dispatcher's repeat modifiers; long-running
loops must be `Sched` loops or feature bins so `;unloadiy` and
`Feature.stopAll()` can stop them.

## Bugs to fix while porting (do not faithfully reproduce these)

* An `un<x>` command that throws when `<x>` was never run. `Feature:stop()` is
  already safe; make sure your off-handler goes through it.
* A connection created inside a `for` loop over targets, with only the last one
  stored (legacy `carpet`, `headsit`, `stareat`, `hatspin`, `view`). Give each
  target its own `bin:branch()` or store a table of connections in the bin.
* `A and B or C` precedence mistakes: legacy
  `if x == y and m == "Kick" or m == "kick"` matched *any* object. Parenthesise.
* Values read straight from `args` and written to engine properties as strings
  (legacy `spoofspeed` returned `"100"`). Types handle this now.
* Anything that indexes `.Character`, `.Humanoid`, `.Handle` or `.Parent` without
  a nil check. Use the `Inst`/`Target`/`Character` helpers, or check.
* Unbounded `while wait() do` loops with no off-switch (legacy `removeads`,
  `jerk`). Give every loop a feature and an off-command.
* Features that break after a respawn: set `reapply = true` on the feature
  instead of capturing a character/humanoid/part in a closure.
* `math.random(1, 0)` on an empty list, and `table.remove(t, nil)` when
  `table.find` returned nil.

## Verification before you finish

```bash
cd /home/david/Documents/GitHub/infiniteyield
for f in <your files>; do luajit -e "assert(loadfile('$f'))" || echo "SYNTAX $f"; done
python3 tools/build.py --check
python3 tools/check.py            # if it exists yet
```

Report: files written, command count, which legacy bugs you fixed, anything you
could not port and why.
