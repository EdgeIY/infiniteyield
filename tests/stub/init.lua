--[[ tests/stub/init.lua ------------------------------------------------------
  Headless Roblox environment emulator -- main entry point.

    local Stub = dofile("tests/stub/init.lua")
    local env  = Stub.new({ playerName = "TestPlayer", playerCount = 4 })
    local chunk = loadstring(source)
    setfenv(chunk, env.globals)
    chunk()
    env.scheduler.advance(2)          -- let spawned threads run
    assert(#env.scheduler.errors == 0)

  Returned environment:
    env.globals    sandbox globals (game, workspace, Instance, task, Enum, ...)
    env.scheduler  virtual clock + task scheduler (see scheduler.lua)
    env.fs         virtual filesystem behind writefile/readfile
    env.output     { prints, warns, errors, chat, clipboard, teleports,
                     notifications, unimplemented, writes, ... }
    env.game       the DataModel stub
    env.players    { localPlayer, add, remove, buildCharacter, respawn, list }
    env.reset()    clear captured output and scheduler queues

  Options: playerName, playerCount, files, http, executor, capabilities,
           echo (mirror print/warn to stdout), placeId, jobId, gravity.

  The only host-global mutation is `string.split`, added when missing so that
  Luau's `("a,b"):split(",")` works on plain Lua strings; it is a pure function
  and is only installed if the host does not already provide one.
--]]

local moduleDir = (function()
    local src = debug.getinfo(1, "S").source or ""
    src = src:gsub("^@", "")
    return src:match("^(.*[/\\])") or "tests/stub/"
end)()

local function loadModule(name)
    local path = moduleDir .. name .. ".lua"
    local chunk, err = loadfile(path)
    if not chunk then error("stub: cannot load " .. path .. ": " .. tostring(err), 0) end
    return chunk()
end

local Signal = loadModule("signal")
local Scheduler = loadModule("scheduler")
local Datatypes = loadModule("datatypes")
local InstanceLib = loadModule("instance")
local Exploit = loadModule("exploit")

local Stub = { _moduleDir = moduleDir }

-- === utf8 helpers ========================================================
local function encodeCodepoint(cp)
    if cp < 0x80 then return string.char(cp) end
    if cp < 0x800 then
        return string.char(0xC0 + math.floor(cp / 0x40), 0x80 + cp % 0x40)
    end
    if cp < 0x10000 then
        return string.char(0xE0 + math.floor(cp / 0x1000),
            0x80 + math.floor(cp / 0x40) % 0x40, 0x80 + cp % 0x40)
    end
    return string.char(0xF0 + math.floor(cp / 0x40000),
        0x80 + math.floor(cp / 0x1000) % 0x40,
        0x80 + math.floor(cp / 0x40) % 0x40, 0x80 + cp % 0x40)
end

-- === JSON ================================================================
local JSON = {}

local ESCAPES = {
    ['"'] = '\\"', ["\\"] = "\\\\", ["\b"] = "\\b", ["\f"] = "\\f",
    ["\n"] = "\\n", ["\r"] = "\\r", ["\t"] = "\\t",
}

local function quoteString(s)
    local out = s:gsub('[%c"\\]', function(c)
        local e = ESCAPES[c]
        if e then return e end
        return string.format("\\u%04x", string.byte(c))
    end)
    return '"' .. out .. '"'
end

local function isArray(t)
    local n = 0
    for k in pairs(t) do
        if type(k) ~= "number" or k < 1 or k % 1 ~= 0 then return false, 0 end
        if k > n then n = k end
    end
    return true, n
end

local function encodeNumber(v)
    if v ~= v or v == math.huge or v == -math.huge then
        error("cannot encode a non-finite number to JSON", 0)
    end
    if v % 1 == 0 and math.abs(v) < 2 ^ 53 then return string.format("%d", v) end
    return (string.format("%.14g", v))
end

-- Object keys are emitted in sorted order so saved JSON is comparable in tests.
local function encodeValue(v, seen, out)
    local t = type(v)
    if v == nil then
        out[#out + 1] = "null"
    elseif t == "boolean" then
        out[#out + 1] = v and "true" or "false"
    elseif t == "number" then
        out[#out + 1] = encodeNumber(v)
    elseif t == "string" then
        out[#out + 1] = quoteString(v)
    elseif t == "table" then
        if seen[v] then error("cannot encode a cyclic table to JSON", 0) end
        seen[v] = true
        local array, n = isArray(v)
        if array then
            out[#out + 1] = "["
            for i = 1, n do
                if i > 1 then out[#out + 1] = "," end
                encodeValue(v[i], seen, out)
            end
            out[#out + 1] = "]"
        else
            local keys = {}
            for k in pairs(v) do
                if type(k) == "string" or type(k) == "number" then
                    keys[#keys + 1] = k
                end
            end
            table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
            out[#out + 1] = "{"
            for i = 1, #keys do
                if i > 1 then out[#out + 1] = "," end
                out[#out + 1] = quoteString(tostring(keys[i]))
                out[#out + 1] = ":"
                encodeValue(v[keys[i]], seen, out)
            end
            out[#out + 1] = "}"
        end
        seen[v] = nil
    else
        error("cannot encode a " .. t .. " value to JSON", 0)
    end
    return out
end

function JSON.encode(value)
    if type(value) == "table" then
        local array, n = isArray(value)
        if array and n == 0 then return "[]" end
    end
    return table.concat(encodeValue(value, {}, {}))
end

local function skipWhitespace(s, i)
    local _, j = s:find("^[ \t\r\n]*", i)
    return (j or i - 1) + 1
end

local parseValue

local function parseString(s, i)
    -- s:sub(i) starts at the opening quote
    local buf = {}
    i = i + 1
    while true do
        local c = s:sub(i, i)
        if c == "" then error("unterminated string in JSON at " .. i, 0) end
        if c == '"' then return table.concat(buf), i + 1 end
        if c == "\\" then
            local e = s:sub(i + 1, i + 1)
            if e == "u" then
                local hex = s:sub(i + 2, i + 5)
                local cp = tonumber(hex, 16)
                if not cp then error("bad \\u escape in JSON at " .. i, 0) end
                i = i + 6
                if cp >= 0xD800 and cp <= 0xDBFF and s:sub(i, i + 1) == "\\u" then
                    local low = tonumber(s:sub(i + 2, i + 5), 16)
                    if low and low >= 0xDC00 and low <= 0xDFFF then
                        cp = 0x10000 + (cp - 0xD800) * 0x400 + (low - 0xDC00)
                        i = i + 6
                    end
                end
                buf[#buf + 1] = encodeCodepoint(cp)
            else
                local map = { b = "\b", f = "\f", n = "\n", r = "\r", t = "\t",
                    ['"'] = '"', ["\\"] = "\\", ["/"] = "/" }
                local rep = map[e]
                if not rep then error("bad escape \\" .. e .. " in JSON at " .. i, 0) end
                buf[#buf + 1] = rep
                i = i + 2
            end
        else
            local nextEscape = s:find('[\\"]', i)
            buf[#buf + 1] = s:sub(i, (nextEscape or #s + 1) - 1)
            i = nextEscape or (#s + 1)
        end
    end
end

parseValue = function(s, i)
    i = skipWhitespace(s, i)
    local c = s:sub(i, i)
    if c == "" then error("unexpected end of JSON input", 0) end
    if c == "{" then
        local obj = {}
        i = skipWhitespace(s, i + 1)
        if s:sub(i, i) == "}" then return obj, i + 1 end
        while true do
            i = skipWhitespace(s, i)
            if s:sub(i, i) ~= '"' then error("expected a JSON object key at " .. i, 0) end
            local key
            key, i = parseString(s, i)
            i = skipWhitespace(s, i)
            if s:sub(i, i) ~= ":" then error("expected ':' at " .. i, 0) end
            local value
            value, i = parseValue(s, i + 1)
            obj[key] = value
            i = skipWhitespace(s, i)
            local sep = s:sub(i, i)
            if sep == "," then i = i + 1
            elseif sep == "}" then return obj, i + 1
            else error("expected ',' or '}' at " .. i, 0) end
        end
    elseif c == "[" then
        local arr, n = {}, 0
        i = skipWhitespace(s, i + 1)
        if s:sub(i, i) == "]" then return arr, i + 1 end
        while true do
            local value
            value, i = parseValue(s, i)
            n = n + 1
            arr[n] = value
            i = skipWhitespace(s, i)
            local sep = s:sub(i, i)
            if sep == "," then i = i + 1
            elseif sep == "]" then return arr, i + 1
            else error("expected ',' or ']' at " .. i, 0) end
        end
    elseif c == '"' then
        return parseString(s, i)
    elseif s:sub(i, i + 3) == "true" then
        return true, i + 4
    elseif s:sub(i, i + 4) == "false" then
        return false, i + 5
    elseif s:sub(i, i + 3) == "null" then
        return nil, i + 4
    else
        local numStr = s:match("^%-?%d+%.?%d*[eE]?[-+]?%d*", i)
        local num = numStr and tonumber(numStr)
        if not num then error("unexpected character '" .. c .. "' in JSON at " .. i, 0) end
        return num, i + #numStr
    end
end

function JSON.decode(text)
    if type(text) ~= "string" then
        error("Unable to decode JSON: input is a " .. type(text), 0)
    end
    local value, i = parseValue(text, 1)
    i = skipWhitespace(text, i)
    if i <= #text then error("trailing characters in JSON at " .. i, 0) end
    return value
end
Stub.json = JSON

function Stub.new(opts)
    opts = opts or {}
    local echo = opts.echo
    if echo == nil then echo = os.getenv("STUB_ECHO") ~= nil end

    local output = {
        prints = {}, warns = {}, errors = {}, chat = {}, clipboard = {},
        teleports = {}, notifications = {}, kicks = {}, requests = {},
        hooks = {}, unimplemented = {}, queued = {}, remotes = {}, touches = {},
        clicks = {}, prompts = {}, replicated = {}, readonly = {}, input = {},
        rconsole = {}, messageboxes = {}, fpscaps = {}, core = {},
        protectedguis = {}, simulationradius = {}, saveinstance = {},
    }

    local scheduler = Scheduler.new({
        onError = function(rec)
            output.errors[#output.errors + 1] = rec.message
            if echo then io.stderr:write("[stub error] " .. rec.message .. "\n") end
        end,
    })

    local D = Datatypes.new()
    local Enum = D.Enum
    local V2, V3, CF, C3, UD, UD2 = D.Vector2, D.Vector3, D.CFrame, D.Color3, D.UDim, D.UDim2

    local fs = Exploit.newFilesystem(opts.files, output)

    local inst = InstanceLib.newLibrary({
        scheduler = scheduler, signal = Signal, datatypes = D,
        output = output, options = opts,
    })
    local newInstance = inst.new

    local G = {}       -- the sandbox globals

    -- === typeof ==========================================================
    local function typeof(v)
        local t = type(v)
        if t ~= "table" and t ~= "userdata" then return t end
        local mt = getmetatable(v)
        if type(mt) == "table" and mt.__type then return mt.__type end
        if t == "userdata" then return "userdata" end
        return "table"
    end

    -- === output helpers ==================================================
    local function join(...)
        local n = select("#", ...)
        local parts = {}
        for i = 1, n do parts[i] = tostring((select(i, ...))) end
        return table.concat(parts, " ")
    end

    local function stubPrint(...)
        local msg = join(...)
        output.prints[#output.prints + 1] = msg
        if echo then io.write(msg, "\n") end
    end

    local function stubWarn(...)
        local msg = join(...)
        output.warns[#output.warns + 1] = msg
        if echo then io.stderr:write("[warn] " .. msg .. "\n") end
    end

    -- === standard libraries (copies, so the host tables stay clean) ======
    if string.split == nil then
        -- Luau string method used as ("a,b"):split(",")
        string.split = function(s, sep)
            sep = sep or ","
            local out = {}
            if sep == "" then
                for i = 1, #s do out[i] = s:sub(i, i) end
                return out
            end
            local pos = 1
            while true do
                local a, b = s:find(sep, pos, true)
                if not a then
                    out[#out + 1] = s:sub(pos)
                    return out
                end
                out[#out + 1] = s:sub(pos, a - 1)
                pos = b + 1
            end
        end
    end

    local function copy(t, extra)
        local out = {}
        for k, v in pairs(t) do out[k] = v end
        if extra then for k, v in pairs(extra) do out[k] = v end end
        return out
    end

    local gstring = copy(string)

    local gtable = copy(table, {
        find = function(t, value, init)
            for i = (init or 1), #t do if t[i] == value then return i end end
            return nil
        end,
        clear = function(t)
            for i = #t, 1, -1 do t[i] = nil end
            for k in pairs(t) do t[k] = nil end
            return t
        end,
        create = function(count, value)
            local out = {}
            for i = 1, (count or 0) do out[i] = value end
            return out
        end,
        pack = function(...) return { n = select("#", ...), ... } end,
        unpack = function(t, i, j) return unpack(t, i or 1, j or (t.n or #t)) end,
        move = function(a1, f, e, t, a2)
            a2 = a2 or a1
            if e >= f then
                if t > f then
                    for i = e - f, 0, -1 do a2[t + i] = a1[f + i] end
                else
                    for i = 0, e - f do a2[t + i] = a1[f + i] end
                end
            end
            return a2
        end,
    })

    -- table.freeze cannot really freeze a Lua table without changing its
    -- identity, so it is tracked in a weak set and isfrozen reports it.
    local frozen = setmetatable({}, { __mode = "k" })
    gtable.freeze = function(t)
        frozen[t] = true
        return t
    end
    gtable.isfrozen = function(t) return frozen[t] == true end
    -- math ---------------------------------------------------------------
    local function noise3(x, y, z)
        x, y, z = x or 0, y or 0, z or 0
        local function h(i, j, k)
            local n = i * 374761393 + j * 668265263 + k * 2147483647
            n = (n % 2147483647)
            n = (n * (n * n * 15731 + 789221) + 1376312589) % 2147483647
            return (n / 2147483647) * 2 - 1
        end
        local function fade(t) return t * t * t * (t * (t * 6 - 15) + 10) end
        local xi, yi, zi = math.floor(x), math.floor(y), math.floor(z)
        local xf, yf, zf = x - xi, y - yi, z - zi
        local u, v, w = fade(xf), fade(yf), fade(zf)
        local function lerp(a, b, t) return a + (b - a) * t end
        local c000, c100 = h(xi, yi, zi), h(xi + 1, yi, zi)
        local c010, c110 = h(xi, yi + 1, zi), h(xi + 1, yi + 1, zi)
        local c001, c101 = h(xi, yi, zi + 1), h(xi + 1, yi, zi + 1)
        local c011, c111 = h(xi, yi + 1, zi + 1), h(xi + 1, yi + 1, zi + 1)
        local x00, x10 = lerp(c000, c100, u), lerp(c010, c110, u)
        local x01, x11 = lerp(c001, c101, u), lerp(c011, c111, u)
        return lerp(lerp(x00, x10, v), lerp(x01, x11, v), w)
    end

    local gmath = copy(math, {
        clamp = function(v, lo, hi)
            if lo > hi then error("max must be greater than or equal to min", 2) end
            if v < lo then return lo elseif v > hi then return hi end
            return v
        end,
        round = function(v)
            if v >= 0 then return math.floor(v + 0.5) end
            return -math.floor(-v + 0.5)
        end,
        sign = function(v)
            if v > 0 then return 1 elseif v < 0 then return -1 end
            return 0
        end,
        noise = noise3,
    })

    -- bit32 over LuaJIT's bit library, normalised to unsigned results ------
    local hostBit = rawget(_G, "bit")
    if hostBit == nil then
        local okBit, mod = pcall(require, "bit")
        if okBit then hostBit = mod end
    end
    local gbit32
    if hostBit then
        local function u32(v) return v % 4294967296 end
        gbit32 = {
            band = function(...) return u32(hostBit.band(...)) end,
            bor = function(...) return u32(hostBit.bor(...)) end,
            bxor = function(...) return u32(hostBit.bxor(...)) end,
            bnot = function(a) return u32(hostBit.bnot(a)) end,
            lshift = function(a, b) return u32(hostBit.lshift(a, b)) end,
            rshift = function(a, b) return u32(hostBit.rshift(a, b)) end,
            arshift = function(a, b) return u32(hostBit.arshift(a, b)) end,
            lrotate = function(a, b) return u32(hostBit.rol(a, b)) end,
            rrotate = function(a, b) return u32(hostBit.ror(a, b)) end,
            tobit = function(a) return hostBit.tobit(a) end,
            bswap = function(a) return u32(hostBit.bswap(a)) end,
        }
    else
        -- pure Lua fallback
        local function toBits(a)
            a = math.floor(a) % 4294967296
            local bits = {}
            for i = 1, 32 do
                bits[i] = a % 2
                a = math.floor(a / 2)
            end
            return bits
        end
        local function fromBits(bits)
            local v = 0
            for i = 32, 1, -1 do v = v * 2 + bits[i] end
            return v
        end
        local function bitwise(op)
            return function(...)
                local n = select("#", ...)
                local acc = toBits((select(1, ...)))
                for i = 2, n do
                    local b = toBits((select(i, ...)))
                    for j = 1, 32 do acc[j] = op(acc[j], b[j]) end
                end
                return fromBits(acc)
            end
        end
        gbit32 = {
            band = bitwise(function(a, b) return (a == 1 and b == 1) and 1 or 0 end),
            bor = bitwise(function(a, b) return (a == 1 or b == 1) and 1 or 0 end),
            bxor = bitwise(function(a, b) return (a ~= b) and 1 or 0 end),
            bnot = function(a) return (4294967295 - (math.floor(a) % 4294967296)) end,
            lshift = function(a, b)
                return math.floor(a * 2 ^ b) % 4294967296
            end,
            rshift = function(a, b) return math.floor((a % 4294967296) / 2 ^ b) end,
            arshift = function(a, b) return math.floor((a % 4294967296) / 2 ^ b) end,
            tobit = function(a) return math.floor(a) % 4294967296 end,
        }
        gbit32.lrotate = function(a, b)
            b = b % 32
            return gbit32.bor(gbit32.lshift(a, b), gbit32.rshift(a, 32 - b))
        end
        gbit32.rrotate = function(a, b) return gbit32.lrotate(a, 32 - (b % 32)) end
        gbit32.bswap = function(a) return a % 4294967296 end
    end
    gbit32.btest = function(...) return gbit32.band(...) ~= 0 end
    gbit32.extract = function(n, field, width)
        width = width or 1
        return gbit32.band(gbit32.rshift(n, field), 2 ^ width - 1)
    end
    gbit32.replace = function(n, v, field, width)
        width = width or 1
        local mask = gbit32.lshift(2 ^ width - 1, field)
        return gbit32.bor(gbit32.band(n, gbit32.bnot(mask)),
            gbit32.band(gbit32.lshift(v, field), mask))
    end
    gbit32.countlz = function(n)
        for i = 31, 0, -1 do
            if gbit32.band(n, gbit32.lshift(1, i)) ~= 0 then return 31 - i end
        end
        return 32
    end
    gbit32.countrz = function(n)
        for i = 0, 31 do
            if gbit32.band(n, gbit32.lshift(1, i)) ~= 0 then return i end
        end
        return 32
    end
    -- utf8 (minimal) ------------------------------------------------------
    local function utf8Decode(s, i)
        local b = s:byte(i)
        if not b then return nil end
        if b < 0x80 then return b, 1 end
        if b < 0xE0 then return (b - 0xC0) * 0x40 + (s:byte(i + 1) or 0) % 0x40, 2 end
        if b < 0xF0 then
            return (b - 0xE0) * 0x1000 + ((s:byte(i + 1) or 0) % 0x40) * 0x40
                + (s:byte(i + 2) or 0) % 0x40, 3
        end
        return (b - 0xF0) * 0x40000 + ((s:byte(i + 1) or 0) % 0x40) * 0x1000
            + ((s:byte(i + 2) or 0) % 0x40) * 0x40 + (s:byte(i + 3) or 0) % 0x40, 4
    end

    local gutf8 = {
        charpattern = "[%z\1-\127\194-\244][\128-\191]*",
        char = function(...)
            local parts = {}
            for i = 1, select("#", ...) do
                parts[i] = encodeCodepoint((select(i, ...)))
            end
            return table.concat(parts)
        end,
        codepoint = function(s, i, j)
            i = i or 1
            j = j or i
            local out, n = {}, 0
            local pos = i
            while pos <= j and pos <= #s do
                local cp, size = utf8Decode(s, pos)
                if not cp then break end
                n = n + 1
                out[n] = cp
                pos = pos + size
            end
            return unpack(out, 1, n)
        end,
        len = function(s, i, j)
            i, j = i or 1, j or #s
            local count, pos = 0, i
            while pos <= j do
                local cp, size = utf8Decode(s, pos)
                if not cp then return nil, pos end
                count = count + 1
                pos = pos + size
            end
            return count
        end,
        offset = function(s, n, i)
            i = i or (n >= 0 and 1 or #s + 1)
            if n == 0 then return i end
            local pos = i
            if n > 0 then
                n = n - 1
                while n > 0 and pos <= #s do
                    local _, size = utf8Decode(s, pos)
                    pos = pos + (size or 1)
                    n = n - 1
                end
                return pos
            end
            while n < 0 and pos > 1 do
                pos = pos - 1
                while pos > 1 and s:byte(pos) >= 0x80 and s:byte(pos) < 0xC0 do
                    pos = pos - 1
                end
                n = n + 1
            end
            return pos
        end,
        graphemes = function(s, i, j)
            i, j = i or 1, j or #s
            local pos = i
            return function()
                if pos > j then return nil end
                local _, size = utf8Decode(s, pos)
                local a = pos
                pos = pos + (size or 1)
                return a, pos - 1
            end
        end,
        nfcnormalize = function(s) return s end,
        nfdnormalize = function(s) return s end,
    }

    -- debug ---------------------------------------------------------------
    local gdebug = copy(debug, {
        profilebegin = function() end,
        profileend = function() end,
        setmemorycategory = function() end,
        resetmemorycategory = function() end,
        dumpheap = function() end,
    })
    gdebug.info = function(a, b, c)
        local target, spec
        if type(a) == "thread" then target, spec = b, c else target, spec = a, b end
        spec = tostring(spec or "sl")
        local info
        if type(target) == "function" then
            info = debug.getinfo(target, "nSluf")
        else
            info = debug.getinfo((tonumber(target) or 1) + 1, "nSluf")
        end
        if not info then return nil end
        local out, n = {}, 0
        for i = 1, #spec do
            local ch = spec:sub(i, i)
            n = n + 1
            if ch == "s" then out[n] = (info.source or ""):gsub("^@", "")
            elseif ch == "l" then out[n] = info.currentline or -1
            elseif ch == "n" then out[n] = info.name or ""
            elseif ch == "f" then out[n] = info.func
            elseif ch == "a" then
                out[n] = info.nparams or 0
                n = n + 1
                out[n] = info.isvararg and true or false
            else out[n] = nil end
        end
        return unpack(out, 1, n)
    end
    -- === time + task =====================================================
    local epoch = os.time()
    local function clock() return scheduler.clock() end
    local function tick() return epoch + scheduler.clock() end

    local gos = {
        time = function(t)
            if t ~= nil then return os.time(t) end
            return math.floor(epoch + scheduler.clock())
        end,
        clock = function() return scheduler.clock() end,
        date = function(fmt, t) return os.date(fmt, t or math.floor(epoch + scheduler.clock())) end,
        difftime = os.difftime,
        getenv = function() return nil end,
    }

    local task = {
        wait = function(t) return scheduler.wait(t) end,
        spawn = function(fn, ...) return scheduler.spawn(fn, ...) end,
        defer = function(fn, ...) return scheduler.defer(fn, ...) end,
        delay = function(t, fn, ...) return scheduler.delay(t, fn, ...) end,
        cancel = function(thread) return scheduler.cancel(thread) end,
        synchronize = function() end,
        desynchronize = function() end,
    }

    local gcoroutine = copy(coroutine, {
        close = function(co)
            scheduler.cancel(co)
            return true
        end,
        isyieldable = function() return coroutine.running() ~= nil end,
    })

    -- === globals =========================================================
    -- Roblox exposes the user's client settings through a global function that
    -- behaves like a service provider; `;volume` and `;guiscale` use it.
    do
        local userSettings = inst.new("UserSettings")
        local gameSettings = inst.new("UserGameSettings")
        gameSettings.MasterVolume = 0.5
        gameSettings.MouseSensitivity = 1
        gameSettings.SavedQualityLevel = Enum.SavedQualitySetting.Automatic
        gameSettings.Parent = userSettings
        inst.addMethods(userSettings, {
            GetService = function(_, name)
                if name == "UserGameSettings" then return gameSettings end
                return gameSettings
            end,
            Reset = function() end,
        })
        G.UserSettings = function() return userSettings end
        G.settings = function() return userSettings end
    end
    G._G = G
    G.shared = {}
    G.typeof = typeof
    G.type = type
    G.tostring = tostring
    G.tonumber = tonumber
    G.pairs = pairs
    G.ipairs = ipairs
    G.next = next
    G.select = select
    G.unpack = unpack
    G.rawget = rawget
    G.rawset = rawset
    G.rawequal = rawequal
    G.rawlen = function(t)
        if type(t) == "string" then return #t end
        return #t
    end
    G.setmetatable = setmetatable
    G.getmetatable = getmetatable
    G.assert = assert
    G.error = error
    G.pcall = pcall
    G.xpcall = xpcall
    G.print = stubPrint
    G.warn = stubWarn
    G.collectgarbage = function(what)
        if what == "count" then return collectgarbage("count") end
        return 0
    end
    G.newproxy = rawget(_G, "newproxy") or function(withMeta)
        local t = {}
        if withMeta then setmetatable(t, {}) end
        return t
    end
    G.string = gstring
    G.table = gtable
    G.math = gmath
    G.os = gos
    G.coroutine = gcoroutine
    G.debug = gdebug
    G.bit32 = gbit32
    G.bit = gbit32
    G.utf8 = gutf8
    G.task = task
    G.wait = task.wait
    G.spawn = function(fn, ...) return scheduler.defer(fn, ...) end
    G.delay = function(t, fn, ...) return scheduler.delay(t, fn, ...) end
    G.tick = tick
    G.time = clock
    G.elapsedTime = clock
    G.gcinfo = function() return math.floor(collectgarbage("count")) end
    G.getfenv = getfenv
    G.setfenv = setfenv
    G.require = function()
        error("require() is not supported inside the stub environment", 2)
    end
    G.loadstring = function(src, chunkname)
        local fn, err = loadstring(src, chunkname)
        if not fn then return nil, err end
        setfenv(fn, G)
        return fn
    end
    G.load = function(src, chunkname)
        if type(src) == "function" then
            local parts = {}
            while true do
                local piece = src()
                if piece == nil or piece == "" then break end
                parts[#parts + 1] = piece
            end
            src = table.concat(parts)
        end
        return G.loadstring(src, chunkname)
    end
    G.Enum = Enum
    G.Instance = {
        new = function(className, parent) return newInstance(className, parent) end,
        fromExisting = function(other) return other:Clone() end,
    }
    for _, name in ipairs({
        "Vector3", "Vector2", "CFrame", "Color3", "UDim", "UDim2", "Rect",
        "NumberRange", "NumberSequence", "NumberSequenceKeypoint", "ColorSequence",
        "ColorSequenceKeypoint", "TweenInfo", "BrickColor", "Ray", "Region3",
        "Random", "RaycastParams", "OverlapParams", "PhysicalProperties", "Font",
        "Faces", "Axes",
    }) do G[name] = D[name] end
    -- === DataModel and services ==========================================
    local httpFn = opts.http
    local function httpGet(url)
        output.requests[#output.requests + 1] = { url = tostring(url), method = "GET" }
        if httpFn then
            local ok, res = pcall(httpFn, url)
            if ok and type(res) == "string" then return res end
        end
        return ""
    end

    local game = newInstance("DataModel")
    game.Name = "Game"
    game.PlaceId = opts.placeId or 13822889
    game.GameId = opts.gameId or 4483381587
    game.JobId = opts.jobId or "00000000-0000-4000-8000-000000000000"
    game.CreatorId = opts.creatorId or 1
    game.CreatorType = Enum.CreatorType.User
    game.PrivateServerId = ""
    game.PrivateServerOwnerId = 0
    game.VIPServerId = ""

    local services = {}
    local serviceInit = {}

    local function createService(name)
        local existing = services[name]
        if existing then return existing end
        local service = newInstance(name)
        service.Name = name
        services[name] = service
        inst.setParent(service, game)
        local initFn = serviceInit[name]
        if initFn then initFn(service) end
        return service
    end

    inst.addMethods(game, {
        GetService = function(_, name) return createService(tostring(name)) end,
        service = function(_, name) return createService(tostring(name)) end,
        FindService = function(_, name) return services[tostring(name)] end,
        GetObjects = function() return {} end,
        HttpGet = function(_, url) return httpGet(url) end,
        HttpGetAsync = function(_, url) return httpGet(url) end,
        HttpPost = function(_, url) return httpGet(url) end,
        HttpPostAsync = function(_, url) return httpGet(url) end,
        IsLoaded = function() return true end,
        SetPlaceId = function(self, id) self.PlaceId = id end,
        SetUniverseId = function(self, id) self.GameId = id end,
        BindToClose = function() return nil end,
        Shutdown = function() return nil end,
        GetJobsInfo = function() return {} end,
    })
    -- game.Loaded exists as an auto-signal; fire it once so :Wait() callers that
    -- checked IsLoaded() first are not left hanging.
    scheduler.defer(function() inst.fire(game, "Loaded") end)
    -- === Workspace / Lighting / RunService ===============================
    serviceInit.Workspace = function(ws)
        ws.Gravity = opts.gravity or 196.2
        ws.DistributedGameTime = 0
        ws.StreamingEnabled = false
        ws.FallenPartsDestroyHeight = -500
        local terrain = newInstance("Terrain", ws)
        terrain.Name = "Terrain"
        local camera = newInstance("Camera", ws)
        camera.Name = "Camera"
        camera.CFrame = CF.new(0, 10, 20)
        camera.Focus = CF.new(0, 5, 0)
        camera.FieldOfView = 70
        camera.CameraType = Enum.CameraType.Custom
        camera.ViewportSize = V2.new(1920, 1080)
        ws.CurrentCamera = camera
        inst.addGetters(ws, {
            DistributedGameTime = function() return scheduler.clock() end,
        })
        inst.addMethods(ws, {
            Raycast = function() return nil end,
            Blockcast = function() return nil end,
            Spherecast = function() return nil end,
            Shapecast = function() return nil end,
            GetPartBoundsInBox = function() return {} end,
            GetPartBoundsInRadius = function() return {} end,
            GetPartsInPart = function() return {} end,
            FindPartOnRay = function() return nil, V3.new(), V3.new(0, 1, 0) end,
            FindPartOnRayWithIgnoreList = function() return nil, V3.new(), V3.new(0, 1, 0) end,
            FindPartOnRayWithWhitelist = function() return nil, V3.new(), V3.new(0, 1, 0) end,
            FindPartsInRegion3 = function() return {} end,
            FindPartsInRegion3WithIgnoreList = function() return {} end,
            GetRealPhysicsFPS = function() return 60 end,
            GetServerTimeNow = function() return epoch + scheduler.clock() end,
            SetPhysicsThrottleEnabled = function() return nil end,
            ZoomToExtents = function() return nil end,
            JoinToOutsiders = function() return nil end,
            UnjoinFromOutsiders = function() return nil end,
            BreakJoints = function() return nil end,
            MakeJoints = function() return nil end,
        })
    end
    local workspace = createService("Workspace")
    local camera = workspace.CurrentCamera

    serviceInit.Lighting = function(l)
        l.Ambient = C3.fromRGB(70, 70, 70)
        l.OutdoorAmbient = C3.fromRGB(128, 128, 128)
        l.Brightness = 2
        l.ClockTime = 14
        l.TimeOfDay = "14:00:00"
        l.GeographicLatitude = 41.7
        l.FogColor = C3.fromRGB(192, 192, 192)
        l.FogEnd = 100000
        l.FogStart = 0
        l.GlobalShadows = true
        l.ExposureCompensation = 0
        l.EnvironmentDiffuseScale = 0
        l.EnvironmentSpecularScale = 0
        l.ShadowSoftness = 0.2
        l.Technology = Enum.Technology.ShadowMap
        inst.addMethods(l, {
            GetMinutesAfterMidnight = function(self) return (self.ClockTime or 14) * 60 end,
            SetMinutesAfterMidnight = function(self, m) self.ClockTime = (m or 0) / 60 end,
            GetMoonDirection = function() return V3.new(0, 1, 0) end,
            GetSunDirection = function() return V3.new(0, 1, 0) end,
            GetMoonPhase = function() return 0 end,
        })
    end
    createService("Lighting")

    serviceInit.RunService = function(rs)
        inst.addMethods(rs, {
            IsStudio = function() return false end,
            IsClient = function() return true end,
            IsServer = function() return false end,
            IsRunning = function() return true end,
            IsRunMode = function() return false end,
            IsEdit = function() return false end,
            BindToRenderStep = function(_, name, priority, fn)
                scheduler.bindRenderStep(name, priority, fn)
            end,
            UnbindFromRenderStep = function(_, name) scheduler.unbindRenderStep(name) end,
            Pause = function() return nil end,
            Run = function() return nil end,
            Stop = function() return nil end,
        })
    end
    local runService = createService("RunService")

    -- RunService signals are driven from the scheduler step
    scheduler.addStepHook(function(dt, now)
        inst.fire(runService, "Stepped", now, dt)
        inst.fire(runService, "RenderStepped", dt)
        inst.fire(runService, "PreRender", dt)
        inst.fire(runService, "PreAnimation", dt)
        inst.fire(runService, "PreSimulation", dt)
        inst.fire(runService, "PostSimulation", dt)
        inst.fire(runService, "Heartbeat", dt)
    end)
    -- === HttpService / UserInputService / TweenService ===================
    serviceInit.HttpService = function(hs)
        hs.HttpEnabled = true
        local guidCounter = 0
        inst.addMethods(hs, {
            JSONEncode = function(_, value) return JSON.encode(value) end,
            JSONDecode = function(_, text) return JSON.decode(text) end,
            GenerateGUID = function(_, braces)
                guidCounter = guidCounter + 1
                local hex = string.format("%08x-%04x-4%03x-8%03x-%012x",
                    (guidCounter * 2654435761) % 4294967296, guidCounter % 65536,
                    guidCounter % 4096, (guidCounter * 7) % 4096,
                    (guidCounter * 2246822519) % 281474976710656)
                if braces == false then return hex end
                return "{" .. hex .. "}"
            end,
            UrlEncode = function(_, s)
                return (tostring(s):gsub("[^%w%-%.%_%~]", function(c)
                    return string.format("%%%02X", string.byte(c))
                end))
            end,
            UrlDecode = function(_, s)
                return (tostring(s):gsub("%%(%x%x)", function(h)
                    return string.char(tonumber(h, 16))
                end))
            end,
            GetAsync = function(_, url) return httpGet(url) end,
            PostAsync = function(_, url) return httpGet(url) end,
            RequestAsync = function(_, request)
                local url = type(request) == "table" and (request.Url or request.url) or ""
                return {
                    Success = true, StatusCode = 200, StatusMessage = "OK",
                    Headers = {}, Body = httpGet(url),
                }
            end,
        })
    end
    createService("HttpService")

    serviceInit.UserInputService = function(uis)
        uis.TouchEnabled = false
        uis.KeyboardEnabled = true
        uis.MouseEnabled = true
        uis.GamepadEnabled = false
        uis.AccelerometerEnabled = false
        uis.GyroscopeEnabled = false
        uis.VREnabled = false
        uis.MouseBehavior = Enum.MouseBehavior.Default
        uis.MouseDeltaSensitivity = 1
        uis.MouseIconEnabled = true
        uis.ModalEnabled = false
        uis.OnScreenKeyboardVisible = false
        inst.addMethods(uis, {
            GetPlatform = function() return Enum.Platform.Windows end,
            IsKeyDown = function() return false end,
            IsMouseButtonPressed = function() return false end,
            GetKeysPressed = function() return {} end,
            GetMouseButtonsPressed = function() return {} end,
            GetMouseLocation = function() return V2.new(960, 540) end,
            GetMouseDelta = function() return V2.new(0, 0) end,
            GetFocusedTextBox = function() return nil end,
            GetGamepadConnected = function() return false end,
            GetConnectedGamepads = function() return {} end,
            GetDeviceRotation = function() return CF.new(), V3.new() end,
            GetDeviceAcceleration = function() return V3.new() end,
            GetStringForKeyCode = function(_, code)
                return type(code) == "table" and code.Name or tostring(code)
            end,
            GetSupportedGamepadKeyCodes = function() return {} end,
            GamepadSupports = function() return false end,
            RecenterUserHeadCFrame = function() return nil end,
        })
    end
    createService("UserInputService")

    serviceInit.TweenService = function(ts)
        inst.addMethods(ts, {
            GetValue = function(_, alpha) return alpha end,
            Create = function(_, object, info, properties)
                local tween
                tween = {
                    Instance = object,
                    TweenInfo = info,
                    PlaybackState = Enum.PlaybackState.Begin,
                    Completed = Signal.new("Tween.Completed", scheduler),
                    Play = function()
                        if object ~= nil and properties ~= nil then
                            for key, value in pairs(properties) do object[key] = value end
                        end
                        tween.PlaybackState = Enum.PlaybackState.Completed
                        scheduler.delay(0, function()
                            tween.Completed:Fire(Enum.PlaybackState.Completed)
                        end)
                        return tween
                    end,
                    Cancel = function()
                        tween.PlaybackState = Enum.PlaybackState.Cancelled
                    end,
                    Pause = function()
                        tween.PlaybackState = Enum.PlaybackState.Paused
                    end,
                    Destroy = function() end,
                }
                return tween
            end,
        })
    end
    createService("TweenService")
    -- === Players, characters =============================================
    local playerList = {}
    local playersService
    local nextUserId = 1000

    local function newMouse()
        local mouse = newInstance("PlayerMouse")
        mouse.Name = "Mouse"
        mouse.Hit = CF.new(0, 0, 0)
        mouse.Origin = CF.new(0, 10, 20)
        mouse.Target = nil
        mouse.TargetFilter = nil
        mouse.X, mouse.Y = 960, 540
        mouse.ViewSizeX, mouse.ViewSizeY = 1920, 1080
        mouse.Icon = ""
        mouse.UnitRay = D.Ray.new(V3.new(0, 10, 20), V3.new(0, 0, -1))
        return mouse
    end

    local RIG_PARTS = {
        "HumanoidRootPart", "Head", "UpperTorso", "LowerTorso",
        "LeftUpperArm", "LeftLowerArm", "LeftHand",
        "RightUpperArm", "RightLowerArm", "RightHand",
        "LeftUpperLeg", "LeftLowerLeg", "LeftFoot",
        "RightUpperLeg", "RightLowerLeg", "RightFoot",
    }

    local function buildCharacter(player)
        local char = newInstance("Model")
        char.Name = player.Name
        char.Archivable = true

        local root
        for i = 1, #RIG_PARTS do
            local part = newInstance("Part", char)
            part.Name = RIG_PARTS[i]
            part.Size = V3.new(1, 1, 1)
            part.CFrame = CF.new(0, 5, 0)
            part.Anchored = false
            part.CanCollide = true
            part.Transparency = 0
            part.Material = Enum.Material.Plastic
            part.BrickColor = D.BrickColor.new("Medium stone grey")
            if RIG_PARTS[i] == "HumanoidRootPart" then
                root = part
                part.Size = V3.new(2, 2, 1)
            elseif RIG_PARTS[i] == "Head" then
                local face = newInstance("Decal", part)
                face.Name = "face"
                face.Texture = "rbxasset://textures/face.png"
            end
        end
        char.PrimaryPart = root

        local humanoid = newInstance("Humanoid", char)
        humanoid.Name = "Humanoid"
        humanoid.Health = 100
        humanoid.MaxHealth = 100
        humanoid.WalkSpeed = 16
        humanoid.JumpPower = 50
        humanoid.JumpHeight = 7.2
        humanoid.HipHeight = 2
        humanoid.RigType = Enum.HumanoidRigType.R15
        humanoid.DisplayName = player.Name
        humanoid.MoveDirection = V3.new(0, 0, 0)
        humanoid.FloorMaterial = Enum.Material.Plastic
        local animator = newInstance("Animator", humanoid)
        animator.Name = "Animator"

        local animate = newInstance("LocalScript", char)
        animate.Name = "Animate"

        local shirt = newInstance("Shirt", char)
        shirt.Name = "Shirt"
        shirt.ShirtTemplate = "rbxassetid://0"
        local pants = newInstance("Pants", char)
        pants.Name = "Pants"
        pants.PantsTemplate = "rbxassetid://0"
        local hat = newInstance("Accessory", char)
        hat.Name = "Hat"
        local handle = newInstance("Part", hat)
        handle.Name = "Handle"

        inst.setParent(char, workspace)
        player.Character = char
        inst.fire(player, "CharacterAdded", char)
        if playersService then inst.fire(playersService, "CharacterAdded", char) end
        return char
    end

    local function respawn(player)
        local old = player.Character
        if old then
            inst.fire(player, "CharacterRemoving", old)
            old:Destroy()
            player.Character = nil
        end
        return buildCharacter(player)
    end
    local function newPlayer(name, withCharacter)
        nextUserId = nextUserId + 1
        local player = newInstance("Player")
        player.Name = name
        player.DisplayName = name
        player.UserId = nextUserId
        player.AccountAge = 365
        player.CharacterAppearanceId = nextUserId
        player.Neutral = true
        player.TeamColor = D.BrickColor.new("White")
        player.CanLoadCharacterAppearance = true
        player.CameraMode = Enum.CameraMode.Classic
        player.CameraMaxZoomDistance = 128
        player.CameraMinZoomDistance = 0.5
        player.DevComputerMovementMode = Enum.DevComputerMovementMode.UserChoice
        player.ReplicationFocus = nil

        local gui = newInstance("PlayerGui", player)
        gui.Name = "PlayerGui"
        local backpack = newInstance("Backpack", player)
        backpack.Name = "Backpack"
        local starterGear = newInstance("StarterGear", player)
        starterGear.Name = "StarterGear"
        local playerScripts = newInstance("PlayerScripts", player)
        playerScripts.Name = "PlayerScripts"

        local mouse = newMouse()
        inst.addMethods(player, {
            GetMouse = function() return mouse end,
            Kick = function(_, reason)
                output.kicks[#output.kicks + 1] = { player = name, reason = reason }
            end,
            LoadCharacter = function(self) return respawn(self) end,
            DistanceFromCharacter = function() return 0 end,
            IsFriendsWith = function() return false end,
            GetFriendsOnline = function() return {} end,
            GetRankInGroup = function() return 0 end,
            GetRoleInGroup = function() return "Guest" end,
            IsInGroup = function() return false end,
            GetJoinData = function() return {} end,
            GetNetworkPing = function() return 0.045 end,
            ClearCharacterAppearance = function() return nil end,
            RequestStreamAroundAsync = function() return nil end,
            SetSuperSafeChat = function() return nil end,
            HasAppearanceLoaded = function() return true end,
        })

        inst.setParent(player, playersService)
        playerList[#playerList + 1] = player
        playersService.NumPlayers = #playerList
        if withCharacter ~= false then buildCharacter(player) end
        return player
    end

    serviceInit.Players = function(ps)
        ps.MaxPlayers = 12
        ps.PreferredPlayers = 12
        ps.NumPlayers = 0
        ps.CharacterAutoLoads = true
        ps.RespawnTime = 5
        ps.BubbleChat = false
        ps.ClassicChat = false
        inst.addMethods(ps, {
            GetPlayers = function()
                local out = {}
                for i = 1, #playerList do out[i] = playerList[i] end
                return out
            end,
            players = function()
                local out = {}
                for i = 1, #playerList do out[i] = playerList[i] end
                return out
            end,
            GetPlayerFromCharacter = function(_, character)
                for i = 1, #playerList do
                    if playerList[i].Character == character then return playerList[i] end
                end
                return nil
            end,
            GetPlayerByUserId = function(_, userId)
                for i = 1, #playerList do
                    if playerList[i].UserId == userId then return playerList[i] end
                end
                return nil
            end,
            FindFirstChildWhichIsA = inst.baseMethods.FindFirstChildWhichIsA,
            GetNameFromUserIdAsync = function(_, userId)
                for i = 1, #playerList do
                    if playerList[i].UserId == userId then return playerList[i].Name end
                end
                return "Player" .. tostring(userId)
            end,
            GetUserIdFromNameAsync = function(_, name)
                for i = 1, #playerList do
                    if playerList[i].Name == name then return playerList[i].UserId end
                end
                return 1
            end,
            GetUserThumbnailAsync = function(_, userId)
                return "rbxthumb://type=AvatarHeadShot&id=" .. tostring(userId)
                    .. "&w=420&h=420", true
            end,
            GetHumanoidDescriptionFromUserId = function()
                return newInstance("HumanoidDescription")
            end,
            GetCharacterAppearanceInfoAsync = function() return {} end,
            CreateLocalPlayer = function() return nil end,
            Chat = function(_, message)
                output.chat[#output.chat + 1] = { channel = "Legacy", message = message }
            end,
            SetChatStyle = function() return nil end,
            TeamChat = function() return nil end,
        })
    end
    playersService = createService("Players")

    local localPlayer = newPlayer(opts.playerName or "TestPlayer")
    playersService.LocalPlayer = localPlayer

    local dummyCount = opts.playerCount
    if dummyCount == nil then dummyCount = 3 end
    for i = 1, dummyCount do newPlayer("Dummy" .. i) end
    -- === remaining services ==============================================
    serviceInit.StarterGui = function(sg)
        sg.ResetPlayerGuiOnSpawn = true
        sg.ScreenOrientation = Enum.ScreenOrientation.LandscapeSensor
        sg.ShowDevelopmentGui = true
        local coreEnabled = {}
        inst.addMethods(sg, {
            SetCore = function(_, name, ...)
                local value = ...
                output.core[#output.core + 1] = { call = "SetCore", name = name, value = value }
                if name == "SendNotification" then
                    output.notifications[#output.notifications + 1] = value
                end
                return nil
            end,
            GetCore = function(_, name)
                output.core[#output.core + 1] = { call = "GetCore", name = name }
                if name == "PointsNotificationsActive" then return false end
                return nil
            end,
            SetCoreGuiEnabled = function(_, coreGuiType, enabled)
                local key = type(coreGuiType) == "table" and coreGuiType.Name
                    or tostring(coreGuiType)
                coreEnabled[key] = enabled and true or false
                output.core[#output.core + 1] =
                    { call = "SetCoreGuiEnabled", name = key, value = enabled }
                return nil
            end,
            GetCoreGuiEnabled = function(_, coreGuiType)
                local key = type(coreGuiType) == "table" and coreGuiType.Name
                    or tostring(coreGuiType)
                if coreEnabled[key] == nil then return true end
                return coreEnabled[key]
            end,
        })
    end
    createService("StarterGui")

    serviceInit.TextChatService = function(tcs)
        tcs.ChatVersion = Enum.ChatVersion.TextChatService
        local channels = newInstance("Folder", tcs)
        channels.Name = "TextChannels"
        local general = newInstance("TextChannel", channels)
        general.Name = "RBXGeneral"
        local system = newInstance("TextChannel", channels)
        system.Name = "RBXSystem"
        local commands = newInstance("Folder", tcs)
        commands.Name = "TextChatCommands"
        inst.addMethods(tcs, {
            DisplaySystemMessage = function(_, message)
                output.chat[#output.chat + 1] = { channel = "System", system = message }
            end,
        })
    end
    createService("TextChatService")

    serviceInit.TeleportService = function(tps)
        inst.addMethods(tps, {
            Teleport = function(_, placeId, player)
                output.teleports[#output.teleports + 1] =
                    { kind = "Teleport", placeId = placeId, player = player and player.Name }
            end,
            TeleportAsync = function(_, placeId)
                output.teleports[#output.teleports + 1] =
                    { kind = "TeleportAsync", placeId = placeId }
            end,
            TeleportToPlaceInstance = function(_, placeId, jobId, player)
                output.teleports[#output.teleports + 1] = {
                    kind = "TeleportToPlaceInstance", placeId = placeId,
                    jobId = jobId, player = player and player.Name,
                }
            end,
            TeleportToPrivateServer = function(_, placeId, code)
                output.teleports[#output.teleports + 1] =
                    { kind = "TeleportToPrivateServer", placeId = placeId, code = code }
            end,
            TeleportToSpawnByName = function(_, placeId, spawn)
                output.teleports[#output.teleports + 1] =
                    { kind = "TeleportToSpawnByName", placeId = placeId, spawn = spawn }
            end,
            GetPlayerPlaceInstanceAsync = function() return false, "stub", 0, "" end,
            SetTeleportGui = function() return nil end,
            GetTeleportSetting = function() return nil end,
            SetTeleportSetting = function() return nil end,
            GetArrivingTeleportGui = function() return nil end,
        })
    end
    createService("TeleportService")

    serviceInit.MarketplaceService = function(ms)
        inst.addMethods(ms, {
            GetProductInfo = function(_, assetId, infoType)
                return {
                    Name = "Stub Asset " .. tostring(assetId),
                    Description = "Stubbed product info",
                    AssetId = assetId, ProductId = assetId,
                    PriceInRobux = 0, IsForSale = false, Created = "2020-01-01T00:00:00Z",
                    Updated = "2020-01-01T00:00:00Z", Sales = 0,
                    Creator = { Id = 1, Name = "StubCreator", CreatorType = "User",
                        CreatorTargetId = 1 },
                    IsPublicDomain = true, AssetTypeId = 1,
                    InfoType = infoType and tostring(infoType) or "Asset",
                }
            end,
            PromptPurchase = function() return nil end,
            PromptGamePassPurchase = function() return nil end,
            PromptProductPurchase = function() return nil end,
            UserOwnsGamePassAsync = function() return false end,
            PlayerOwnsAsset = function() return false end,
            GetDeveloperProductsAsync = function() return {} end,
        })
    end
    createService("MarketplaceService")
    serviceInit.PathfindingService = function(pfs)
        inst.addMethods(pfs, {
            CreatePath = function()
                local path
                path = {
                    Status = Enum.PathStatus.Success,
                    Blocked = Signal.new("Path.Blocked", scheduler),
                    Unblocked = Signal.new("Path.Unblocked", scheduler),
                    ComputeAsync = function(_, from, to)
                        path.Status = Enum.PathStatus.Success
                        path._from = from
                        path._to = to
                        return path.Status
                    end,
                    GetWaypoints = function()
                        local from = path._from or V3.new(0, 0, 0)
                        local to = path._to or V3.new(0, 0, 10)
                        local mid = from:Lerp(to, 0.5)
                        return {
                            { Position = from, Action = Enum.PathWaypointAction.Walk, Label = "" },
                            { Position = mid, Action = Enum.PathWaypointAction.Walk, Label = "" },
                            { Position = to, Action = Enum.PathWaypointAction.Walk, Label = "" },
                        }
                    end,
                    CheckOcclusionAsync = function() return -1 end,
                    Destroy = function() end,
                }
                return path
            end,
            FindPathAsync = function(self) return self:CreatePath() end,
        })
    end
    createService("PathfindingService")

    serviceInit.CollectionService = function(cs)
        local tagged = {}
        inst.addMethods(cs, {
            GetTagged = function(_, tag)
                local out = {}
                for _, object in ipairs(tagged[tag] or {}) do
                    if not inst.isDestroyed(object) then out[#out + 1] = object end
                end
                return out
            end,
            AddTag = function(_, object, tag)
                tagged[tag] = tagged[tag] or {}
                table.insert(tagged[tag], object)
                if inst.is(object) then object:AddTag(tag) end
            end,
            RemoveTag = function(_, object, tag)
                for i = #(tagged[tag] or {}), 1, -1 do
                    if tagged[tag][i] == object then table.remove(tagged[tag], i) end
                end
                if inst.is(object) then object:RemoveTag(tag) end
            end,
            HasTag = function(_, object, tag)
                if inst.is(object) then return object:HasTag(tag) end
                return false
            end,
            GetTags = function(_, object)
                if inst.is(object) then return object:GetTags() end
                return {}
            end,
            GetAllTags = function()
                local out = {}
                for tag in pairs(tagged) do out[#out + 1] = tag end
                table.sort(out)
                return out
            end,
            GetInstanceAddedSignal = function(_, tag)
                return Signal.new("CollectionService.Added." .. tostring(tag), scheduler)
            end,
            GetInstanceRemovedSignal = function(_, tag)
                return Signal.new("CollectionService.Removed." .. tostring(tag), scheduler)
            end,
        })
    end
    createService("CollectionService")

    serviceInit.Stats = function(stats)
        stats.PerformanceStats = nil
        local function statItem(name, value)
            local item = newInstance("IntValue")
            item.Name = name
            inst.addMethods(item, {
                GetValue = function() return value end,
                GetValueString = function() return tostring(value) end,
            })
            return item
        end
        local network = newInstance("Folder", stats)
        network.Name = "Network"
        local serverStats = newInstance("Folder", network)
        serverStats.Name = "ServerStatsItem"
        inst.setParent(statItem("Data Ping", 45), serverStats)
        inst.setParent(statItem("Data Send", 8), serverStats)
        inst.setParent(statItem("Data Receive", 12), serverStats)
        inst.setParent(statItem("Physics Send", 4), serverStats)
        inst.addMethods(stats, {
            GetTotalMemoryUsageMb = function() return 512 end,
            GetMemoryUsageMbForTag = function() return 32 end,
        })
    end
    createService("Stats")

    serviceInit.Teams = function(teams)
        inst.addMethods(teams, {
            GetTeams = function(self)
                local out = {}
                for _, child in ipairs(self:GetChildren()) do
                    if child:IsA("Team") then out[#out + 1] = child end
                end
                return out
            end,
            RebalanceTeams = function() return nil end,
        })
    end
    createService("Teams")
    serviceInit.Debris = function(debris)
        inst.addMethods(debris, {
            AddItem = function(_, item, lifetime)
                scheduler.delay(tonumber(lifetime) or 10, function()
                    if inst.is(item) and not inst.isDestroyed(item) then item:Destroy() end
                end)
            end,
        })
    end
    createService("Debris")

    serviceInit.VirtualUser = function(vu)
        local function record(kind)
            return function() output.input[#output.input + 1] = kind end
        end
        inst.addMethods(vu, {
            CaptureController = record("CaptureController"),
            ClickButton1 = record("ClickButton1"),
            ClickButton2 = record("ClickButton2"),
            Button1Down = record("Button1Down"),
            Button1Up = record("Button1Up"),
            Button2Down = record("Button2Down"),
            Button2Up = record("Button2Up"),
            SetKeyDown = record("SetKeyDown"),
            SetKeyUp = record("SetKeyUp"),
            TypeKey = record("TypeKey"),
            MoveMouse = record("MoveMouse"),
            StartRecording = record("StartRecording"),
            StopRecording = record("StopRecording"),
        })
    end
    createService("VirtualUser")

    serviceInit.VirtualInputManager = function(vim)
        local function record(kind)
            return function() output.input[#output.input + 1] = kind end
        end
        inst.addMethods(vim, {
            SendKeyEvent = record("SendKeyEvent"),
            SendMouseButtonEvent = record("SendMouseButtonEvent"),
            SendMouseMoveEvent = record("SendMouseMoveEvent"),
            SendMouseWheelEvent = record("SendMouseWheelEvent"),
            SendTextInputCharacterEvent = record("SendTextInputCharacterEvent"),
        })
    end
    createService("VirtualInputManager")

    serviceInit.ContentProvider = function(cp)
        cp.RequestQueueSize = 0
        cp.BaseUrl = "https://www.roblox.com/"
        inst.addMethods(cp, {
            PreloadAsync = function(_, list, callback)
                if type(callback) == "function" and type(list) == "table" then
                    for _, asset in ipairs(list) do callback(asset, Enum.AssetFetchStatus.Success) end
                end
                return nil
            end,
            ListEncryptedAssets = function() return {} end,
            GetAssetFetchStatus = function() return Enum.AssetFetchStatus.Success end,
        })
    end
    createService("ContentProvider")

    serviceInit.GroupService = function(gs)
        inst.addMethods(gs, {
            GetGroupsAsync = function() return {} end,
            GetGroupInfoAsync = function(_, groupId)
                return {
                    Name = "Stub Group", Id = groupId, Owner = { Name = "StubOwner", Id = 1 },
                    EmblemUrl = "", Description = "", Roles = {},
                }
            end,
            GetAlliesAsync = function() return {} end,
            GetEnemiesAsync = function() return {} end,
        })
    end
    createService("GroupService")

    serviceInit.TextService = function(ts)
        inst.addMethods(ts, {
            GetTextSize = function(_, text, size)
                return V2.new(#tostring(text) * (size or 14) * 0.5, size or 14)
            end,
            FilterStringAsync = function(_, text)
                local result = { GetNonChatStringForBroadcastAsync = function() return text end }
                return result
            end,
        })
    end
    createService("TextService")

    serviceInit.SoundService = function(ss)
        inst.addMethods(ss, {
            PlayLocalSound = function(_, sound)
                output.input[#output.input + 1] = { "PlayLocalSound", sound and sound.SoundId }
            end,
            SetListener = function() return nil end,
            GetListener = function() return Enum.ListenerType.Camera, camera end,
        })
    end
    createService("SoundService")

    serviceInit.PhysicsService = function(ps)
        inst.addMethods(ps, {
            RegisterCollisionGroup = function() return nil end,
            UnregisterCollisionGroup = function() return nil end,
            CollisionGroupSetCollidable = function() return nil end,
            CollisionGroupsAreCollidable = function() return true end,
            GetRegisteredCollisionGroups = function() return {} end,
            SetPartCollisionGroup = function() return nil end,
            CreateCollisionGroup = function() return nil end,
        })
    end
    createService("PhysicsService")

    serviceInit.GuiService = function(gs)
        gs.TopbarInset = D.Rect.new(0, 36, 1920, 36)
        gs.MenuIsOpen = false
        gs.TouchControlsEnabled = true
        inst.addMethods(gs, {
            GetGuiInset = function() return V2.new(0, 36), V2.new(0, 0) end,
            GetEmotesMenuOpen = function() return false end,
            SetEmotesMenuOpen = function() return nil end,
            GetInspectMenuEnabled = function() return true end,
            SetInspectMenuEnabled = function() return nil end,
            InspectPlayerFromUserId = function() return nil end,
            OpenBrowserWindow = function(_, url)
                output.requests[#output.requests + 1] = { url = url, method = "BROWSER" }
            end,
            AddSelectionParent = function() return nil end,
            RemoveSelectionGroup = function() return nil end,
            Select = function() return nil end,
        })
    end
    createService("GuiService")

    serviceInit.SocialService = function(ss)
        inst.addMethods(ss, {
            PromptGameInvite = function()
                output.input[#output.input + 1] = "PromptGameInvite"
            end,
            CanSendGameInviteAsync = function() return true end,
        })
    end
    createService("SocialService")

    serviceInit.CaptureService = function(cs)
        inst.addMethods(cs, {
            CaptureScreenshot = function(_, callback)
                if type(callback) == "function" then callback("rbxtemp://stub") end
            end,
            SaveScreenshotCapture = function() return nil end,
            PromptShareCapture = function() return nil end,
        })
    end
    createService("CaptureService")
    serviceInit.ContextActionService = function(cas)
        local bound = {}
        inst.addMethods(cas, {
            BindAction = function(_, name, fn) bound[name] = fn end,
            BindActionAtPriority = function(_, name, fn) bound[name] = fn end,
            UnbindAction = function(_, name) bound[name] = nil end,
            UnbindAllActions = function() bound = {} end,
            GetBoundActionInfo = function(_, name)
                return bound[name] and { actionName = name } or nil
            end,
            GetAllBoundActionInfo = function() return {} end,
            SetTitle = function() return nil end,
            SetImage = function() return nil end,
            BindCoreAction = function(_, name, fn) bound[name] = fn end,
            UnbindCoreAction = function(_, name) bound[name] = nil end,
            FireActionEvent = function() return nil end,
            CallFunction = function(_, name, ...)
                if bound[name] then return bound[name](name, ...) end
            end,
        })
    end
    createService("ContextActionService")

    serviceInit.InsertService = function(is)
        inst.addMethods(is, {
            LoadAsset = function() return newInstance("Model") end,
            LoadAssetVersion = function() return newInstance("Model") end,
            GetLatestAssetVersionAsync = function() return 1 end,
            CreateMeshPartAsync = function() return newInstance("MeshPart") end,
        })
    end
    createService("InsertService")

    serviceInit.AvatarEditorService = function(aes)
        inst.addMethods(aes, {
            GetItemDetails = function(_, id) return { Id = id, Name = "Stub Item" } end,
            GetFavorite = function() return false end,
            SetFavorite = function() return nil end,
            PromptSaveAvatar = function() return nil end,
            SearchCatalog = function()
                return { GetCurrentPage = function() return {} end,
                    AdvanceToNextPageAsync = function() end, IsFinished = true }
            end,
        })
    end
    createService("AvatarEditorService")

    serviceInit.ExperienceService = function(es)
        inst.addMethods(es, {
            GetExperienceState = function() return nil end,
        })
    end
    createService("ExperienceService")

    serviceInit.MaterialService = function(ms)
        ms.Use2022Materials = true
        inst.addMethods(ms, {
            GetMaterialVariant = function() return nil end,
        })
    end
    createService("MaterialService")

    serviceInit.VoiceChatService = function(vcs)
        vcs.EnableDefaultVoice = false
        inst.addMethods(vcs, {
            IsVoiceEnabledForUserIdAsync = function() return false end,
        })
    end
    createService("VoiceChatService")

    serviceInit.ProximityPromptService = function() end
    createService("ProximityPromptService")

    serviceInit.AnalyticsService = function(as)
        inst.addMethods(as, {
            FireEvent = function() return nil end,
            FireCustomEvent = function() return nil end,
            FireLogEvent = function() return nil end,
            ReportCounter = function() return nil end,
        })
    end
    createService("AnalyticsService")

    serviceInit.Chat = function(chat)
        inst.addMethods(chat, {
            Chat = function(_, part, message)
                output.chat[#output.chat + 1] = { channel = "Legacy", message = message }
            end,
            FilterStringAsync = function(_, text) return text end,
            FilterStringForBroadcast = function(_, text) return text end,
            CanUserChatAsync = function() return true end,
            InvokeChatCallback = function() return nil end,
            RegisterChatCallback = function() return nil end,
        })
    end
    createService("Chat")

    serviceInit.CoreGui = function(cg)
        cg.Version = 10
        local robloxGui = newInstance("ScreenGui", cg)
        robloxGui.Name = "RobloxGui"
    end
    createService("CoreGui")

    serviceInit.StarterPlayer = function(sp)
        sp.CameraMaxZoomDistance = 128
        sp.CharacterWalkSpeed = 16
        sp.CharacterJumpPower = 50
        local scripts = newInstance("StarterPlayerScripts", sp)
        scripts.Name = "StarterPlayerScripts"
        local charScripts = newInstance("StarterCharacterScripts", sp)
        charScripts.Name = "StarterCharacterScripts"
    end
    createService("StarterPlayer")

    for _, name in ipairs({
        "ReplicatedStorage", "ReplicatedFirst", "ServerStorage", "ServerScriptService",
        "StarterPack", "SoundService", "JointsService", "TestService",
        "LocalizationService", "NetworkClient", "Selection", "Studio",
        "LogService", "ScriptContext", "KeyframeSequenceProvider",
        "BadgeService", "DataStoreService", "FriendService", "AssetService",
        "PolicyService", "HapticService", "GamepadService", "PluginGuiService",
        "TouchInputService", "MessagingService", "MemoryStoreService",
        "OpenCloudService", "SafetyService", "AppUpdateService", "PerformanceStatsService",
    }) do createService(name) end
    -- === finish the globals ==============================================
    G.game = game
    G.Game = game
    G.workspace = workspace
    G.Workspace = workspace

    -- === exploit environment =============================================
    local caps = opts.capabilities
    local defaultCap = true
    if type(caps) == "table" and caps.default ~= nil then defaultCap = caps.default end

    local exploitEnv = Exploit.new({
        fs = fs, output = output, options = opts, globals = G,
        instanceLib = inst, scheduler = scheduler, signal = Signal,
        datatypes = D, http = opts.http, realEnv = _G,
        localPlayer = function() return localPlayer end,
        hiddenUI = function() return services.CoreGui end,
    })

    local injected = {}
    for name, value in pairs(exploitEnv) do
        if type(value) == "function" then
            local allowed = defaultCap
            if type(caps) == "table" and caps[name] ~= nil then allowed = caps[name] end
            if allowed then
                G[name] = value
                injected[name] = true
            end
        end
    end
    if type(caps) == "table" then
        if caps.syn then
            G.syn = {
                request = exploitEnv.request,
                queue_on_teleport = exploitEnv.queue_on_teleport,
                protect_gui = exploitEnv.protectgui,
                set_thread_identity = exploitEnv.setthreadidentity,
            }
        end
        if caps.fluxus then
            G.fluxus = {
                request = exploitEnv.request,
                queue_on_teleport = exploitEnv.queue_on_teleport,
                setclipboard = exploitEnv.setclipboard,
            }
        end
        if caps.KRNL_LOADED then G.KRNL_LOADED = true end
    end
    -- === players facade ==================================================
    local players = {
        localPlayer = localPlayer,
        list = playerList,
        service = playersService,
        buildCharacter = buildCharacter,
        respawn = respawn,
        add = function(name)
            local player = newPlayer(name or ("Dummy" .. tostring(#playerList + 1)))
            inst.fire(playersService, "PlayerAdded", player)
            return player
        end,
        remove = function(name)
            for i = 1, #playerList do
                local player = playerList[i]
                if player.Name == name or player == name then
                    inst.fire(playersService, "PlayerRemoving", player)
                    table.remove(playerList, i)
                    playersService.NumPlayers = #playerList
                    if player.Character then player.Character:Destroy() end
                    player:Destroy()
                    return player
                end
            end
            return nil
        end,
        get = function(name)
            for i = 1, #playerList do
                if playerList[i].Name == name then return playerList[i] end
            end
            return nil
        end,
    }

    -- === environment =====================================================
    local function clearList(t)
        for i = #t, 1, -1 do t[i] = nil end
        for k in pairs(t) do t[k] = nil end
    end

    local env = {
        globals = G,
        scheduler = scheduler,
        fs = fs,
        output = output,
        game = game,
        players = players,
        services = services,
        datatypes = D,
        instance = inst,
        signal = Signal,
        json = JSON,
        exploit = exploitEnv,
        injected = injected,
        typeof = typeof,
        camera = camera,
        workspace = workspace,
        options = opts,
    }

    function env.reset()
        for _, list in pairs(output) do
            if type(list) == "table" then clearList(list) end
        end
        output.writes = fs.writes
        scheduler.reset()
        return env
    end

    function env.getService(name) return createService(tostring(name)) end
    function env.newInstance(className, parent) return newInstance(className, parent) end

    return env
end

return Stub


