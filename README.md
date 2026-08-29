# Infinite Yield

The best command line script for roblox.

[![](https://dcbadge.limes.pink/api/server/https://discord.gg/78ZuWSq)](https://discord.gg/78ZuWSq)

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/CarlDV/infiniteyield/master/source"))()
```

 - 560 commands
 - Open Source
 - 8+ years of development

## Developers

### Creator: [Edge](https://github.com/EdgeIY)
### Developers: [Moon](https://github.com/LorekeeperZinnia), [Zwolf](https://github.com/luatsuki), [Sleaze](https://github.com/sleaze5), [Toon](https://github.com/Toon-arch), [Peyton](https://github.com/peyton2465), [ATP](https://github.com/ionizedparticle)

## Usage

You can learn how to use all the features of this script in
[the wiki](https://github.com/EdgeIY/infiniteyield/wiki).

Useful once you are in: `;help`, `;help <command>`, and `;iydiag` if something
looks wrong.

## For contributors

`source` is **generated**. Edit `src/` and rebuild.

```bash
python3 tools/check.py         # static checks: syntax, module shape, globals, imports, cycles
python3 tools/build.py         # regenerate source, loader.lua and src/manifest.lua
luajit tests/stub/selftest.lua # the headless Roblox emulator's own tests
luajit tests/run.lua           # boot the built bundle headlessly and run the specs
luajit tests/loader_test.lua   # boot the remote loader path
luajit tools/gendocs.lua       # regenerate docs/COMMANDS.md from the registry
```

Adding a command is one table in a file under `src/commands/`:

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

Usage text, the entry in the in-game command list, autocomplete, argument
validation and the `unspeed`/`togglespeed` siblings (when you provide an `off`
handler) are all derived from that.

| Read this | For |
|---|---|
| [docs/ADDING-COMMANDS.md](docs/ADDING-COMMANDS.md) | the command API in full |
| [docs/COMMANDS.md](docs/COMMANDS.md) | every command, generated from the registry |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | how the project fits together |
| [docs/BUGS-FIXED.md](docs/BUGS-FIXED.md) | defects found in 6.4.2 and what replaced them |
| [docs/UI-CONTRACT.md](docs/UI-CONTRACT.md) | the interface module boundaries |

Developing against a branch without rebuilding the bundle:

```lua
getgenv().IY_CONFIG = { branch = "my-branch", debug = true }
loadstring(game:HttpGet("https://raw.githubusercontent.com/CarlDV/infiniteyield/master/loader.lua"))()
```

Plugins written against the old `addcmd` API still work — `src/compat/legacy.lua`
provides that surface — but new plugins should use `IY.command{...}`.

## Contributing

There are no strict rules; open a
[pull request](https://github.com/CarlDV/infiniteyield/pulls) and if it checks
out we will merge it. Two asks: run `python3 tools/check.py` and
`luajit tests/run.lua` first, and edit `src/` rather than `source`.
