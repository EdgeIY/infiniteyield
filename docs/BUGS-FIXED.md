# Defects found in the 6.4.2 source, and what the rewrite does about them

Every entry cites the line in the original 13,412-line file, which is preserved
at `tools/_analysis/source.ref.lua` for reference.

Most of these are not individually interesting. What matters is that the same
handful of shapes recur dozens of times, and the rewrite removes the shapes
rather than patching the instances.

## Structural: four bug classes, ~60 occurrences

| Shape | Why it happened | Structural fix |
|---|---|---|
| Running an on-command twice started a second loop | the flag was set before the guard, or there was no guard | `Feature:start` stops a running feature first |
| An `un<x>` command threw when `<x>` had never run | `X:Disconnect()` on a nil module global | `Feature:stop` on an idle feature is a no-op |
| A feature broke silently after a respawn | the character, humanoid or part was captured in a closure | `reapply = true` re-runs `start` on `core/character`'s `spawned` signal |
| `;unloadiy` left everything running | only one table of UI connections was tracked | every feature owns a `Bin`; the runtime runs LIFO teardown |

Concrete instances of the "off-command throws" class: `unpartesp` (8214),
`unteleportwalk` (12093), `unalignmentkeys` (12705), `unlistento` (12754),
`unantigameplaypaused` (7939), `undance` (9849), `unspasm` (10114), `visible`
(9710 — a nil *function* call), `unfloat` (7474), `unreach` (11701), `unbang`
(10867).

Concrete instances of the "breaks on respawn" class: `cframefly` (7362 — keeps
CFraming a destroyed Head forever), mobile fly (7247 — re-parents to a stale
root), `walltp` (12236), `grabtools` (11107), `teleportwalk` (12080),
`loopnobgui` (10090), `reach` (11644), `spoofspeed`/`spoofjumppower`
(10402/10453), `swim` (7501), `xray` (12188), `hatspin` (11244), `spin` (12164).

## Commands that could not work at all

| Command | Line | Problem |
|---|---|---|
| `god` | 9562–9585 | References undefined globals `char` and `pos` (the locals are `Char`/`Pos`). It destroys your real Humanoid, sets `speaker.Character = nil`, then errors — leaving you character-less. |
| `emote` | 10156 | `humanoid:PlayEmoteAndGetAnimTrackById(...)` where `humanoid` is an undefined global. Always errors. |
| `inviteprompt` | 7018 | Resolves players into `plrs` then reads `plr[1].UserId`. Always errors. |
| `unhatspin` | 11270 | `for i,c in pairs(v.Handle)` — iterating an Instance. Throws, so the forces are never removed and hats stay detached. |
| `npcs` selector | 5503 | Builds fake players with `Instance.new("Player")` (not creatable in modern Roblox) and then intersects them with the real player list, which is always empty. |
| `locate` alone | 8250 | Defaults to you, then skips you. Silently does nothing. |
| `light <n>` | 11174 | `Brightness = args[2]` with `args[2]` nil. Raises. |
| `unpartesp` | 8214 | `:Disconnect()` on nil when never enabled. |

## Operator-precedence bugs

`a == b and m == "X" or m == "x"` parses as `(a == b and m == "X") or (m == "x")`.

| Line | Effect |
|---|---|
| 7949 | Anti-kick intercepted `:kick(...)` on **every** object in the game, not just the LocalPlayer. |
| 8005 | Anti-teleport intercepted the teleport family on every object. |
| 11037 | `fireclickdetectors` passed non-matching instances to `fireclickdetector`, which errors. |
| 11066 | Same for `fireproximityprompts`. |
| 11471 | Same for `touchinterests`. |
| 12404 | `stareat` bailed only when the *local* root was missing and the target's existed, so a rootless target fell into the loop and threw. |

## Data loss

* **The save file was destroyed on a parse error.** `saves()` (3062–3131) responded
  to unparseable JSON by calling `writefile("IY_FE.iy", defaults)` — one bad byte
  and your waypoints, keybinds, aliases and theme were gone. `core/store` now
  copies the file to `IY_FE.iy.corrupt`, keeps the original untouched, and runs on
  defaults.
* **`clearwaypoints` saved before clearing** (7730), so everything you deleted came
  back on the next rejoin.
* **`writefileCooldown` (2192–2204)** released the write lock three seconds after
  *re-queueing*, so two concurrent writers to `IY_FE.iy` were possible. Compounded
  by 4240: every keystroke in the prefix box triggered a save. Replaced by a
  coalescing single-writer queue with atomic writes.
* **Settings from a newer build were dropped** on save. The store now preserves
  unknown keys verbatim.

## Unstoppable and unbounded work

| Line | What |
|---|---|
| 12655 | `removeads`: `while wait() do workspace:GetDescendants() ... end` — no flag, no off-command, immune to `;breakloops`, and a new loop per invocation. |
| 12783 | `jerk`: an unbounded `while task.wait() do` loop that survives death, unequip and unload. |
| 8096 | `setfpscap` fallback: `while true do end` burning a core, cancellable only by re-running the command. |
| 12205 | `loopxray`: a full `workspace:GetDescendants()` walk every RenderStepped. |
| 4941 | `checkTT`: `CoreGui:GetGuiObjectsAtPosition` — a full-tree hit test — on every mouse move. |
| 9228 | `loopbring`: one task per target, each looping over *all* targets, so N targets meant N² teleports per tick — while mutating the table it was iterating. |

## Connection leaks

* **117 raw `:Connect(` calls in the UI region against 6 that were tracked.**
  `;unloadiy` (6950) left over a hundred live handlers, including
  `UserInputService` ones that outlive the destroyed GUI. `dragGUI` alone
  connected `InputChanged` unconditionally, eight times at load.
* **`notify` connected the close button on every call** (3267) and never
  disconnected: after N notifications, one click fired N handlers.
* **One connection per target, only the last stored** — `carpet` (10888),
  `headsit` (10650), `stareat` (12417), `hatspin` (11256, one per accessory),
  `view` (8292). Everything but the last leaked for the session.
* **`float` stacked five connections and a part per invocation** (7409), because
  the random part name was regenerated before the "already floating?" guard.

## State corruption

* **`StayOpen` is a TextLabel *and* a boolean.** Declared as an instance at line
  170, overwritten with a boolean at 2940/2963/3070. After `saves()` runs, the
  label is unreachable by name.
* **`table.remove(list, nil)` removes the last element.** The log tab handlers
  (3952, duplicated at 11746 and 11760) look for `selectChat` in `shade3` when it
  is registered in `shade2`; `table.find` returns nil, and clicking the tab you
  are already on silently deletes an unrelated instance from two theme registries.
* **Four writers, one snapshot.** `workspace.FallenPartsDestroyHeight` was written
  by `antivoid`, `destroyheight`, `fakeout` and `respawn` against a single
  load-time snapshot, so `fakeout` restored the wrong value.
* **Freecam saves the camera FOV and restores a hard-coded 70** (8520 vs 8537).
* **`reach` shares two scalars across all tools** (11642), so with several tools
  every handle was restored to the last one's geometry — and `unreach` before
  `reach` assigned the empty string to `Handle.Size`.
* **`spoofspeed` returns a string** (10407): game code reading `WalkSpeed` got
  `"100"`, breaking any arithmetic on it.
* **`toggleflyfling` reads the wrong flag** (11850): it checks `flinging` while
  `flyfling` is built from `walkfling`, whose flag is `walkflinging`.
* **`loopjumppower` writes `JumpHeight` but listens on `JumpPower`** (10483 vs
  10488), so on R15 rigs it never re-fires.
* **`alignmentkeys` corrupts its own restore value** on the second run, leaving
  the Emotes menu permanently off.
* **`ctrllock` restores a hard-coded `"LeftShift"`** rather than whatever the game
  had.
* **`unmuteboombox` un-mutes every stopped sound**, including ones the game paused
  itself.
* **`setwaypoint` is both a command name and an alias of `waypointpos`** (7550,
  7564), so one of them was unreachable depending on table order.

## Unguarded failure on shared threads

Each of these ran inside a signal handler, so one failure killed the handler for
the rest of the session:

* `CreateJoinLabel` (3387): bare `game:HttpGet` + `JSONDecode` + `:sub` on a
  player-join thread — and it ran *before* the chat-log and ESP hookups in the
  same handler, so one failed request aborted all of them.
* `sendChatWebhook` (3981): unprotected `httprequest` on the chat thread.
* Colour picker (3467): `game:GetObjects("rbxassetid://...")[1]` unguarded — a
  network failure left `colorpickerOpen` true and permanently broke the button.
* `pcall(task.spawn(...))` (2289): `pcall` receives the *thread*, not a function,
  so the body ran unprotected and errors in event-bound commands vanished.
* `CamViewport` (4246): returns nil with no camera, and the caller does
  `Holder.Position.X.Offset < -CamViewport()`.

## Silent failure by design

The dispatcher was:

```lua
local success, err = pcall(cmd.FUNC, args, speaker)
if not success and _G.IY_DEBUG then warn("Command Error:", cmdName, err) end
```

Unless the user had set a debug global, a failing command was indistinguishable
from a command that did nothing. This is the root cause of most "IY is broken"
reports, and it is why the list above could grow this long without anyone
noticing. Every failure mode now reports: bad arguments show the usage, missing
executor capabilities explain themselves, internal errors notify once and log a
traceback, and unknown commands suggest the closest match.

## Deliberate behaviour changes

Not bugs, but places where the rewrite does something different on purpose:

* **ESP and chams can run at the same time.** The legacy versions were made
  mutually exclusive with a user-facing error purely because they fought over the
  same CoreGui folder names.
* **Noclip re-applies after a respawn.** The legacy spawn handler explicitly
  turned it off, even though its loop read the character dynamically and would
  have kept working.
* **Player queries de-duplicate.** `;kill me,all` fired twice on you before.
* **An exact name match beats a prefix match**, so `;kill bob` cannot hit bobby
  while bob is in the server.
* **`loopxray` is throttled** rather than sweeping the whole workspace every
  frame.
* **Aliases can carry arguments.** `;alias zoom fov 100` works; before, only
  `;alias zoom fov` did, and the argument was dropped.
* **Plugins can be unloaded.** Commands are tagged with an owner.
* **`removeads` and `jerk` have off-commands.** They had none.
* **`unrolewatch` now stops rolewatch.** In 6.4.2 it was an alias of
  `rolewatchleave`, so it toggled kick-on-detect and left the watch running.
  `un<name>` means "off" for every other command in the set, and the registry
  derives it automatically, so this one alias was re-pointed; `rolewatchleave`
  and `rolewatchstop` both still exist and keep their original meanings.
* **`whisper` takes one player.** The legacy version accepted a list
  (`;pm all hi`); `pmspam` is the multi-target path.
