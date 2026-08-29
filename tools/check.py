#!/usr/bin/env python3
"""
Static checks for the Infinite Yield source tree.

Run before every build:

    python3 tools/check.py            # report problems, exit 1 if any
    python3 tools/check.py --fix-list # print only the offending file list

What it checks
  1. every module parses under luajit
  2. module shape: `local IY = ...` first statement, a trailing `return`
  3. banned syntax that Lua 5.1 (and therefore our test harness) rejects,
     or that we have a better replacement for
  4. `IY.import("x")` targets that do not exist
  5. accidental globals (assignment at statement level with no `local`)
  6. command packs actually register something
"""

import argparse
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "src")

# (pattern, message). Applied to source with strings and comments stripped.
BANNED = [
    (re.compile(r"[%\w\)\]]\s(?:\+=|-=|\*=|/=|\.\.=|%=)\s"), "compound assignment is Luau-only; write `x = x + 1`"),
    (re.compile(r"^\s*continue\s*$", re.M), "`continue` is Luau-only; restructure the loop"),
    (re.compile(r"\bgoto\s+\w+"), "`goto` is not available in Luau"),
    (re.compile(r"::\w+::"), "labels are not available in Luau"),
    (re.compile(r"^\s*local\s+\w+\s*:\s*\w"), "type annotations are Luau-only and break the test harness"),
    (re.compile(r"(?<![\w.:])wait\s*\("), "use task.wait()"),
    (re.compile(r"(?<![\w.:])spawn\s*\("), "use task.spawn()"),
    (re.compile(r"(?<![\w.:])delay\s*\("), "use task.delay()"),
    (re.compile(r"\bhookmetamethod\s*\("), "go through core/hooks"),
    (re.compile(r"\bgetgenv\s*\(\s*\)\s*\."), "do not write to the shared global table outside entry.lua"),
]

BANNED_EXEMPT = {
    # env probes executor globals by name; entry owns the global surface.
    "core/env": ["getgenv"],
    "entry": ["getgenv"],
    "core/hooks": ["hookmetamethod"],
    "compat/legacy": ["wait", "spawn", "delay"],
}

STRING_OR_COMMENT = re.compile(
    r"--\[(=*)\[.*?\]\1\]"      # long comment
    r"|--[^\n]*"                 # line comment
    r"|\[(=*)\[.*?\]\2\]"        # long string
    r"|\"(?:\\.|[^\"\\\n])*\""   # double-quoted
    r"|'(?:\\.|[^'\\\n])*'",     # single-quoted
    re.S,
)


def strip_noise(text):
    """Replace strings and comments with same-length blanks (keeps line numbers)."""
    def blank(match):
        return re.sub(r"[^\n]", " ", match.group(0))
    return STRING_OR_COMMENT.sub(blank, text)


def module_name(path):
    rel = os.path.relpath(path, SRC).replace(os.sep, "/")
    return rel[:-4]


def modules():
    out = []
    for base, dirs, files in os.walk(SRC):
        dirs.sort()
        for name in sorted(files):
            if name.endswith(".lua"):
                out.append(os.path.join(base, name))
    return sorted(out)


def check_syntax(path, problems):
    try:
        result = subprocess.run(
            ["luajit", "-e",
             "local f,e=loadfile(%r) if not f then io.stderr:write(tostring(e)) os.exit(1) end" % path],
            capture_output=True, text=True, timeout=60)
    except FileNotFoundError:
        return
    if result.returncode != 0:
        problems.append((path, 0, "syntax: " + result.stderr.strip()))


def check_shape(path, name, text, problems):
    if name in ("runtime", "manifest"):
        return
    body = strip_noise(text)
    statements = [line.strip() for line in body.split("\n") if line.strip()]
    if not statements:
        problems.append((path, 0, "empty module"))
        return
    if statements[0] != "local IY = ...":
        problems.append((path, 1, "first statement must be `local IY = ...`"))
    if not re.search(r"^return\s+\S", body, re.M):
        problems.append((path, len(text.split("\n")),
                         "module must end with a `return` (a table, or `true` for command packs)"))


def check_banned(path, name, text, problems):
    body = strip_noise(text)
    exempt = BANNED_EXEMPT.get(name, [])
    for pattern, message in BANNED:
        for match in pattern.finditer(body):
            snippet = match.group(0).strip()
            if any(word in snippet for word in exempt):
                continue
            line = body[:match.start()].count("\n") + 1
            problems.append((path, line, "%s (`%s`)" % (message, snippet)))


IMPORT = re.compile(r'IY\.import\(\s*"([^"]+)"\s*\)')
TOP_LEVEL_IMPORT = re.compile(r'^local\s+\w+\s*=\s*IY\.import\(\s*"([^"]+)"\s*\)', re.M)


def check_imports(path, text, known, problems):
    body = strip_noise(text)
    for match in IMPORT.finditer(body):
        target = match.group(1)
        if target not in known:
            line = body[:match.start()].count("\n") + 1
            problems.append((path, line, "imports unknown module '%s'" % target))


def check_cycles(graph, problems):
    """Report import cycles among *top-level* imports, which deadlock at load.

    An import inside a function body is lazy and therefore fine -- that is the
    documented way to break a cycle -- so only statement-level imports count.
    """
    state = {}
    stack = []
    reported = set()

    def visit(node):
        state[node] = "open"
        stack.append(node)
        for target in graph.get(node, ()):
            if state.get(target) == "open":
                cycle = stack[stack.index(target):] + [target]
                key = tuple(sorted(set(cycle)))
                if key not in reported:
                    reported.add(key)
                    problems.append((os.path.join(SRC, node + ".lua"), 1,
                                     "import cycle: " + " -> ".join(cycle)))
            elif target not in state:
                visit(target)
        stack.pop()
        state[node] = "done"

    for node in sorted(graph):
        if node not in state:
            visit(node)


ASSIGN = re.compile(r"^([A-Za-z_][\w]*)\s*=[^=]", re.M)
NESTED_ASSIGN = re.compile(r"^\t+([A-Za-z_][\w]*)\s*=[^=]", re.M)


def check_globals(path, name, text, problems):
    body = strip_noise(text)
    declared = set(re.findall(r"local\s+([A-Za-z_][\w]*)", body))
    declared |= set(re.findall(r"local\s+function\s+([A-Za-z_][\w]*)", body))
    for match in ASSIGN.finditer(body):
        identifier = match.group(1)
        if identifier in declared:
            continue
        line = body[:match.start()].count("\n") + 1
        problems.append((path, line, "assignment to global '%s' -- add `local`" % identifier))
    for match in re.finditer(r"^\s*function\s+([A-Za-z_][\w]*)\s*\(", body, re.M):
        identifier = match.group(1)
        # `local f` followed by `function f()` assigns the local, which is the
        # normal way to write mutually recursive helpers.
        if identifier in declared:
            continue
        line = body[:match.start()].count("\n") + 1
        problems.append((path, line,
                         "global function '%s' -- use `local function` or `function M.%s`"
                         % (identifier, identifier)))


def check_command_pack(path, name, text, problems):
    if not name.startswith("commands/"):
        return
    if "Cmd.group" not in text and "Cmd.register" not in text and "Cmd.add" not in text:
        problems.append((path, 0, "command pack registers nothing"))
    for match in re.finditer(r"\bname\s*=\s*\"([^\"]+)\"", text):
        command = match.group(1)
        if command != command.lower():
            line = text[:match.start()].count("\n") + 1
            problems.append((path, line, "command name '%s' must be lowercase" % command))
    # Every command should carry a description.
    blocks = text.count("\trun = function")
    described = text.count("\tdescription =")
    if blocks > 0 and described < blocks * 0.6:
        problems.append((path, 0, "only %d description(s) for %d run handlers" % (described, blocks)))


# Globals that legitimately exist at runtime: Lua, Luau, Roblox, and the
# executor surface that core/env probes by name.
ALLOWED_GLOBALS = set("""
_G _VERSION assert collectgarbage dofile error getfenv getmetatable ipairs load
loadfile loadstring next pairs pcall print rawequal rawget rawlen rawset require
select setfenv setmetatable tonumber tostring type unpack xpcall
coroutine debug io math os string table utf8 bit32 bit os
task typeof warn tick time elapsedTime spawn delay wait newproxy gcinfo
game workspace Workspace Game script shared plugin Enum Instance
Vector2 Vector3 Vector2int16 Vector3int16 CFrame Color3 Color3uint8 BrickColor
UDim UDim2 Rect Region3 Region3int16 Ray RaycastParams RaycastResult
OverlapParams PhysicalProperties NumberRange NumberSequence NumberSequenceKeypoint
ColorSequence ColorSequenceKeypoint TweenInfo Random Faces Axes Font FontFace
DateTime PathWaypoint DockWidgetPluginGuiInfo CatalogSearchParams FloatCurveKey
RotationCurveKey SharedTable buffer os
getgenv getrenv getreg getgc getinstances getnilinstances identifyexecutor
writefile readfile appendfile isfile delfile listfiles makefolder isfolder
delfolder getcustomasset setclipboard toclipboard request http_request
queue_on_teleport hookfunction hookmetamethod getnamecallmethod setnamecallmethod
checkcaller newcclosure getrawmetatable setreadonly isreadonly cloneref
compareinstances firetouchinterest fireclickdetector fireproximityprompt
gethiddenproperty sethiddenproperty setthreadidentity getthreadidentity
replicatesignal getscriptclosure getsenv setfpscap setsimulationradius
getconnections protectgui unprotectgui syn fluxus http Clipboard
setconstant getconstants getconstant debug_setconstant
IY_LOADED IY_DEBUG IY_CONFIG
settings UserSettings stats PluginManager printidentity version Version
""".split())

DECLARE = re.compile(r"\blocal\s+(?:function\s+)?([%\w_,\s]+?)(?:\s*=|\s*\()", re.S)
FUNCTION_PARAMS = re.compile(r"\bfunction\s*[\w_.:]*\s*\(([^)]*)\)")
FOR_NUMERIC = re.compile(r"\bfor\s+([\w_]+)\s*=")
FOR_GENERIC = re.compile(r"\bfor\s+([\w_,\s]+?)\s+in\b")
USED_CALL = re.compile(r"(?<![\w.:])([A-Za-z_][\w]*)\s*[\(\{]")
USED_INDEX = re.compile(r"(?<![\w.:])([A-Za-z_][\w]*)\s*[.:]")

LUA_WORDS = set("""and break do else elseif end false for function if in local nil not or
repeat return then true until while self""".split())


def check_unknown_globals(path, name, text, problems):
    """Flag identifiers that are called or indexed but never declared.

    This is what catches a helper that was renamed in one file and not another,
    or a typo like `report(...)` -- the shape of bug that only shows up when a
    command is actually run.
    """
    body = strip_noise(text)

    declared = set()
    for match in DECLARE.finditer(body):
        for piece in match.group(1).split(","):
            piece = piece.strip()
            if piece and re.match(r"^[A-Za-z_][\w]*$", piece):
                declared.add(piece)
    for match in re.finditer(r"\blocal\s+function\s+([\w_]+)", body):
        declared.add(match.group(1))
    for match in re.finditer(r"\blocal\s+([\w_][\w_,\s]*)$", body, re.M):
        for piece in match.group(1).split(","):
            piece = piece.strip()
            if piece:
                declared.add(piece)
    for match in FUNCTION_PARAMS.finditer(body):
        for piece in match.group(1).split(","):
            piece = piece.strip()
            if piece and piece != "...":
                declared.add(piece)
    for match in FOR_NUMERIC.finditer(body):
        declared.add(match.group(1))
    for match in FOR_GENERIC.finditer(body):
        for piece in match.group(1).split(","):
            declared.add(piece.strip())
    # Fields of the module table are reached through it, never bare.
    declared |= LUA_WORDS | ALLOWED_GLOBALS

    seen = {}
    for pattern in (USED_CALL, USED_INDEX):
        for match in pattern.finditer(body):
            identifier = match.group(1)
            if identifier in declared:
                continue
            line = body[:match.start()].count("\n") + 1
            if identifier not in seen:
                seen[identifier] = line

    for identifier, line in sorted(seen.items(), key=lambda item: item[1]):
        problems.append((path, line,
                         "'%s' is not declared in this file and is not a known global"
                         % identifier))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--quiet", action="store_true")
    args = parser.parse_args()

    paths = modules()
    known = {module_name(path) for path in paths}
    problems = []
    graph = {}

    for path in paths:
        name = module_name(path)
        with open(path, "r", encoding="utf-8") as handle:
            text = handle.read()
        check_syntax(path, problems)
        check_shape(path, name, text, problems)
        check_banned(path, name, text, problems)
        check_imports(path, text, known, problems)
        check_globals(path, name, text, problems)
        check_command_pack(path, name, text, problems)
        check_unknown_globals(path, name, text, problems)
        graph[name] = [target for target in TOP_LEVEL_IMPORT.findall(strip_noise(text))
                       if target in known]

    check_cycles(graph, problems)

    if problems:
        by_file = {}
        for path, line, message in problems:
            by_file.setdefault(path, []).append((line, message))
        for path in sorted(by_file):
            print(os.path.relpath(path, ROOT))
            for line, message in sorted(by_file[path]):
                print("  %4d  %s" % (line, message))
        print("\n%d problem(s) in %d file(s), %d modules checked"
              % (len(problems), len(by_file), len(paths)))
        return 1

    if not args.quiet:
        print("check.py: %d modules, no problems" % len(paths))
    return 0


if __name__ == "__main__":
    sys.exit(main())
