#!/usr/bin/env python3
"""Mechanical inventory of the legacy IY source: globals, commands, sections."""
import re, sys, json, collections

SRC = sys.argv[1] if len(sys.argv) > 1 else "tools/_analysis/source.ref.lua"
lines = open(SRC, encoding="utf-8", errors="replace").read().split("\n")
text = "\n".join(lines)

LUA_KEYWORDS = set("""and break do else elseif end false for function if in local nil not or repeat
return then true until while""".split())

# ---------- commands ----------
cmd_re = re.compile(r"""addcmd\(\s*(['"])(.+?)\1\s*,\s*(\{.*?\})\s*,""", re.S)
cmds = []
for m in cmd_re.finditer(text):
    name = m.group(2)
    aliases_raw = m.group(3)
    aliases = re.findall(r"""['"](.+?)['"]""", aliases_raw)
    line = text[: m.start()].count("\n") + 1
    cmds.append({"name": name, "aliases": aliases, "line": line})

# ---------- global assignments (top-level `function name(` and `name =` at col 0) ----------
gfun = re.compile(r"^function\s+([A-Za-z_][\w]*)\s*\(")
gassign = re.compile(r"^([A-Za-z_][\w]*)\s*=[^=]")
gmulti = re.compile(r"^([A-Za-z_][\w, ]*?)\s*=[^=]")
globals_def = collections.OrderedDict()
for i, ln in enumerate(lines, 1):
    m = gfun.match(ln)
    if m:
        globals_def.setdefault(m.group(1), []).append(("function", i))
        continue
    m = gassign.match(ln)
    if m and m.group(1) not in LUA_KEYWORDS:
        globals_def.setdefault(m.group(1), []).append(("var", i))

# nested global function defs (indented `function name(`) - these are globals too in Lua
nested_fun = re.compile(r"^\s+function\s+([A-Za-z_][\w]*)\s*\(")
for i, ln in enumerate(lines, 1):
    m = nested_fun.match(ln)
    if m:
        globals_def.setdefault(m.group(1), []).append(("nested-function", i))

# indented global assignments: `\tName = ...` where Name is not local anywhere before -> heuristic
locals_declared = set(re.findall(r"local\s+([A-Za-z_][\w]*)", text))
indent_assign = re.compile(r"^\s+([A-Za-z_][\w]*)\s*=[^=]")
implicit = collections.Counter()
for i, ln in enumerate(lines, 1):
    m = indent_assign.match(ln)
    if m:
        n = m.group(1)
        if n not in locals_declared and n not in LUA_KEYWORDS:
            implicit[n] += 1

# ---------- usage counts ----------
usage = {}
for name in list(globals_def.keys()):
    usage[name] = len(re.findall(r"\b" + re.escape(name) + r"\b", text))

# ---------- sections by density ----------
out = {
    "total_lines": len(lines),
    "command_count": len(cmds),
    "commands": cmds,
    "globals": [
        {"name": n, "defs": d, "uses": usage[n]} for n, d in globals_def.items()
    ],
    "implicit_globals": implicit.most_common(),
}
json.dump(out, open("tools/_analysis/inventory.json", "w"), indent=1)

print("lines:", len(lines))
print("commands:", len(cmds))
names = [c["name"] for c in cmds]
dupes = [n for n, c in collections.Counter(names).items() if c > 1]
print("duplicate command names:", dupes)
allal = [a for c in cmds for a in c["aliases"]]
adupes = [n for n, c in collections.Counter(allal).items() if c > 1]
print("duplicate aliases:", adupes)
clash = sorted(set(names) & set(allal))
print("alias/name clashes:", clash)
print("globals defined:", len(globals_def))
print("top implicit globals:", implicit.most_common(25))
print("\n--- first 40 globals ---")
for n, d in list(globals_def.items())[:40]:
    print(f"  {n:32s} {d[0][0]:16s} line {d[0][1]:6d} uses {usage[n]}")
