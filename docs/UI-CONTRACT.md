# UI contract

The interface is **not** being redesigned. It must look and behave exactly as it
does today. What changes is only that it lives in modules with explicit
dependencies instead of a single scope full of globals.

Legacy source of truth: `tools/_analysis/source.ref.lua`.

## Layout

```
src/ui/
  assets.lua      asset ids + getcustomasset fallback          (legacy 109-152)
  lib.lua         create(), ViewportTextBox, dragGUI, host gui  (306-333, 1969-2058, 2206-2241)
  theme.lua       the six colour registries + updateColors      (335-340, 2930-2935, 3420-3455)
  picker.lua      the colour picker window                      (3457-3885)
  chrome.lua      the shell: holder, title, command bar,        (342-750, 3198-3237,
                  command list frame, settings panel shell,      3394-3418, 4246-4331,
                  notification, tooltip, intro, scale, mobile    13111-13156, 13396-13412)
  notify.lua      notification driver + popups + announcement   (2976-3058, 3239-3285, 13300-13394)
  cmdlist.lua     command list rows, filtering, autocomplete,   (4333-4478, 4918-4977)
                  tooltips
  logs.lua        the logs window and chat/join logging          (1751-1967, 3186-3196,
                                                                 3287-3392, 3911-4055, 4077-4087)
  panels/
    keybinds.lua  keybind list + editor                         (783-1156, 5977-6262)
    aliases.lua   alias list                                    (1279-1368, 1593-1606, 6101-6127)
    waypoints.lua waypoint list                                 (1158-1277, 1623-1636, 6041-6099)
    plugins.lua   plugin list + editor                          (1370-1591, 1608-1621, 6367-6398)
    topart.lua    teleport-to-part picker                       (1638-1749, 4143-4228)
    reference.lua the help window                               (2776-2928)
    events.lua    the event editor                              (2248-2774)
  init.lua        mount / unmount orchestration
```

## `ui/chrome.lua` — the shared shell

Every other UI module builds against this. Exports:

| Export | What it is |
|---|---|
| `Chrome.parent` | the host ScreenGui (legacy `PARENT`) |
| `Chrome.scaled` | the `UIScale` container every floating window parents to (legacy `ScaledHolder`) |
| `Chrome.scale` | the `UIScale` instance (legacy `Scale`) |
| `Chrome.holder` | the main window frame (legacy `Holder`) |
| `Chrome.title` | the title bar (legacy `Title`) |
| `Chrome.commandBar` | the command bar TextBox, already wrapped by `ViewportTextBox` (legacy `Cmdbar`) |
| `Chrome.commandList` | the ScrollingFrame the list rows go in (legacy `CMDsF`) |
| `Chrome.commandListLayout` | its `UIListLayout` |
| `Chrome.rowTemplate` | the hidden TextButton cloned per command row (legacy `Example`) |
| `Chrome.settings` | the settings panel frame (legacy `Settings`) |
| `Chrome.settingsHolder` | the scrolling body panels add rows to (legacy `SettingsHolder`) |
| `Chrome.settingsButton`, `Chrome.referenceButton` | the gear and `?` buttons |
| `Chrome.prefixBox` | the prefix TextBox (legacy `PrefixBox`) |
| `Chrome.stayOpenToggle` | the "keep menu open" checkbox frame (legacy `On`) |
| `Chrome.notification` | the notification frame plus `.title`, `.body`, `.close`, `.pin` |
| `Chrome.tooltip` | the tooltip frame plus `.title`, `.body` |
| `Chrome.makeSettingsRow(name, iconId, offset)` | the icon+label row factory (legacy `makeSettingsButton`, 518-554) |
| `Chrome.maximize()`, `Chrome.minimize()`, `Chrome.showCommandBar()` | holder slide states (legacy `maximizeHolder`/`minimizeHolder`/`cmdbarHolder`) |
| `Chrome.setSettingsOpen(bool)`, `Chrome.settingsOpen()` | replaces the `SettingsOpen` file-local |
| `Chrome.setHidden(bool)`, `Chrome.isHidden()` | replaces the `isHidden` file-local, used by `;hideiy` |
| `Chrome.focusCommandBar()` | focus the command bar (used by the prefix key and the mobile button) |
| `Chrome.runIntro()` | the intro animation (13396-13412) |
| `Chrome.bin` | the UI bin; everything created goes in it |
| `Chrome.mounted` | boolean |

## Rules for every UI module

1. Module conventions are the same as everywhere else: `local IY = ...` first,
   `return M` last, Lua 5.1 syntax, tabs, no globals. See
   `tools/_analysis/PORTING-BRIEF.md`.
2. **Every instance you create goes in a bin** (`Chrome.bin`, or your own bin
   held by it) so `;unloadiy` removes the whole interface. The legacy script
   only destroyed the top-level ScreenGui and leaked more than a hundred
   connections.
3. **Register colours with the theme, never hard-code them after boot.**
   `Theme.register(instance, "shade2")` replaces `table.insert(shade2, instance)`.
   `Theme.unregister(instance)` exists because the legacy registries only ever
   grew — `text1` held 440+ entries immediately after boot and every list
   refresh added more.
4. Instance names must stay randomised the way the legacy code did it
   (`randomString()` → `Str.random(n)`), so CoreGui scanners cannot fingerprint
   the interface by name.
5. Read data from the new modules, not from globals:
   `Store.get("prefix")`, `Registry.all()`, `Binds.list()`, `Aliases.list()`,
   `Waypoints.list()`, `Plugins.list()`, `Log.recent()`, `Dispatch.run(line)`,
   `History.previous()/next()`.
6. Anything the UI used to compute itself that now has an owner must come from
   the owner. In particular the command list is built from
   `Registry.all()` + `Registry.listText(definition)` — **delete the hard-coded
   436-row `CMDs` table** (legacy 4480-4916) and the separate `addcmdtext`
   path; those existed only because there was no registry to ask.
7. Use `Sched`, `Guard.call` and `Bin` instead of raw `task.spawn`, bare pcall
   and manual `:Disconnect()` bookkeeping.
8. Do not change any size, position, colour, font, text, tween duration,
   easing style or ZIndex. This is a move, not a redesign.
9. Panels expose `M.mount(context)`, `M.open()`, `M.close()`, `M.refresh()` and
   `M.frame`. `mount` is called once by `ui/init`; `refresh` is wired to the
   owning module's `changed` signal (for example `Binds.changed`) so a panel
   never has to be refreshed manually by a command.
