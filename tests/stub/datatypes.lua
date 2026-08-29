--[[ tests/stub/datatypes.lua ------------------------------------------------
  Roblox datatypes (Vector3, CFrame, Color3, UDim2, Enum, ...) in plain Lua.

  Contract: Datatypes.new() -> table of constructors, one fresh set per
  environment so that auto-created EnumItems never leak between environments.
  Every value carries a metatable with a `__type` field, which is what the
  sandbox `typeof()` reads; `Datatypes.typeName(v)` exposes the same lookup.

  Deliberate simplifications (documented, not accidental):
    * CFrame keeps a plain 3x3 row-major rotation matrix.  Translation math is
      exact; :Lerp() interpolates the position and snaps the rotation to
      whichever operand is closer (no slerp).
    * Enum is permissive: any Enum.Category.Item auto-creates a stable EnumItem.
      Seeded categories get the real Roblox values where they are well known
      (KeyCode) and 0..n-1 otherwise.
    * BrickColor exposes a small palette, not all 1024 colours.
--]]

local Datatypes = {}

local floor, sqrt, sin, cos, atan2 = math.floor, math.sqrt, math.sin, math.cos, math.atan2
local abs, min, max, pi = math.abs, math.min, math.max, math.pi

local function nfmt(n)
    if type(n) ~= "number" then return tostring(n) end
    return string.format("%g", n)
end

local function clampn(v, lo, hi)
    if v < lo then return lo elseif v > hi then return hi end
    return v
end

function Datatypes.typeName(v)
    if type(v) ~= "table" and type(v) ~= "userdata" then return nil end
    local mt = getmetatable(v)
    if type(mt) == "table" then return mt.__type end
    return nil
end

local DIGITS = { "Zero", "One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine" }

-- === seeded enums ========================================================
-- Array form -> values 0..n-1.  Map form -> explicit values.
local ENUM_SEEDS = {
    UserInputType = { "MouseButton1", "MouseButton2", "MouseButton3", "MouseWheel",
        "MouseMovement", "Touch", "Keyboard", "Focus", "Accelerometer", "Gyro",
        "Gamepad1", "Gamepad2", "Gamepad3", "Gamepad4", "TextInput", "InputMethod",
        "None", "Unknown" },
    HumanoidStateType = { "FallingDown", "Running", "RunningNoPhysics", "Climbing",
        "StrafingNoPhysics", "Ragdoll", "GettingUp", "Jumping", "Landed", "Flying",
        "Freefall", "Seated", "PlatformStanding", "Dead", "Swimming", "Physics", "None" },
    HumanoidRigType = { "R6", "R15" },
    HumanoidDisplayDistanceType = { "Viewer", "Subject", "None" },
    Material = { "Plastic", "Wood", "Slate", "Concrete", "CorrodedMetal", "DiamondPlate",
        "Foil", "Grass", "Ice", "Marble", "Granite", "Brick", "Pebble", "Sand",
        "Fabric", "SmoothPlastic", "Metal", "WoodPlanks", "Cobblestone", "Air",
        "Water", "Rock", "Glacier", "Snow", "Sandstone", "Mud", "Basalt", "Ground",
        "CrackedLava", "Neon", "Glass", "Asphalt", "LeafyGrass", "Salt", "Limestone",
        "Pavement", "ForceField" },
    Font = { "Legacy", "Arial", "ArialBold", "SourceSans", "SourceSansBold",
        "SourceSansSemibold", "SourceSansLight", "SourceSansItalic", "Bodoni",
        "Garamond", "Cartoon", "Code", "Highway", "SciFi", "Arcade", "Fantasy",
        "Antique", "Gotham", "GothamMedium", "GothamBold", "GothamBlack", "Unknown" },
    EasingStyle = { "Linear", "Sine", "Back", "Quad", "Quart", "Quint", "Bounce",
        "Elastic", "Exponential", "Circular", "Cubic" },
    EasingDirection = { "In", "Out", "InOut" },
    NormalId = { "Right", "Top", "Back", "Left", "Bottom", "Front" },
    ChatVersion = { "LegacyChatService", "TextChatService" },
    Platform = { "Windows", "OSX", "IOS", "Android", "XBoxOne", "PS4", "PS3",
        "XBox360", "WiiU", "NX", "Ouya", "AndroidTV", "Chromecast", "Linux",
        "SteamOS", "WebOS", "DOS", "BeOS", "UWP", "None" },
    ThumbnailType = { "HeadShot", "AvatarBust", "AvatarThumbnail" },
    ThumbnailSize = { "Size48x48", "Size180x180", "Size420x420", "Size60x60",
        "Size100x100", "Size150x150", "Size352x352" },
    TextXAlignment = { "Left", "Right", "Center" },
    TextYAlignment = { "Top", "Center", "Bottom" },
    ScrollBarInset = { "None", "ScrollBar", "Always" },
    AutomaticSize = { "None", "X", "Y", "XY" },
    ApplyStrokeMode = { "Contextual", "Border" },
    ZIndexBehavior = { "Global", "Sibling" },
    SizeConstraint = { "RelativeXY", "RelativeXX", "RelativeYY" },
    DevComputerMovementMode = { "UserChoice", "KeyboardMouse", "ClickToMove",
        "Scriptable" },
    MouseBehavior = { "Default", "LockCenter", "LockCurrentPosition" },
    CameraType = { "Fixed", "Attach", "Watch", "Track", "Follow", "Custom",
        "Scriptable", "Orbital" },
    RejectCharacterDeletions = { "Default", "Disabled", "Enabled" },
    TextChatMessageStatus = { "Unknown", "Success", "Sending", "TextFilterFailed",
        "Floodchecked", "InvalidPrivacySettings", "InvalidTextChannelPermissions",
        "MessageTooLong" },
    CoreGuiType = { "PlayerList", "Health", "Backpack", "Chat", "All",
        "EmotesMenu", "SelfView", "Captures" },
    PathStatus = { "Success", "ClosestNoPath", "ClosestOutOfRange",
        "FailStartNotEmpty", "FailFinishNotEmpty", "NoPath" },
    PathWaypointAction = { "Walk", "Jump", "Custom" },
    ProximityPromptStyle = { "Default", "Custom" },
    ProximityPromptInputType = { "Gamepad", "Touch", "Keyboard" },
    TweenStatus = { "Canceled", "Completed" },
    PlaybackState = { "Begin", "Delayed", "Playing", "Paused", "Completed",
        "Cancelled" },
    RaycastFilterType = { "Exclude", "Include" },
    CreatorType = { "User", "Group" },
    TeleportState = { "RequestedFromServer", "Started", "WaitingForServer",
        "Failed", "InProgress" },
    Limb = { "Unknown", "Head", "Torso", "LeftArm", "RightArm", "LeftLeg", "RightLeg" },
    BodyPartR15 = { "Head", "UpperTorso", "LowerTorso", "LeftFoot", "LeftLowerLeg",
        "LeftUpperLeg", "RightFoot", "RightLowerLeg", "RightUpperLeg", "LeftHand",
        "LeftLowerArm", "LeftUpperArm", "RightHand", "RightLowerArm",
        "RightUpperArm", "RootPart", "Unknown" },
    FillDirection = { "Horizontal", "Vertical" },
    SortOrder = { "Name", "Custom", "LayoutOrder" },
    HorizontalAlignment = { "Center", "Left", "Right" },
    VerticalAlignment = { "Center", "Top", "Bottom" },
    ScaleType = { "Stretch", "Slice", "Tile", "Fit", "Crop" },
    FrameStyle = { "Custom", "ChatBlue", "RobloxSquare", "RobloxRound",
        "ChatGreen", "ChatRed", "DropShadow" },
    ButtonStyle = { "Custom", "RobloxButtonDefault", "RobloxButton",
        "RobloxRoundButton", "RobloxRoundDefaultButton", "RobloxRoundDropdownButton" },
    AnimationPriority = { "Core", "Idle", "Movement", "Action", "Action2",
        "Action3", "Action4" },
    DevTouchMovementMode = { "UserChoice", "Thumbstick", "DPad", "Thumbpad",
        "ClickToMove", "Scriptable", "DynamicThumbstick" },
    ControlMode = { "Classic", "MouseLockSwitch" },
    CameraMode = { "Classic", "LockFirstPerson" },
    Technology = { "Legacy", "Voxel", "Compatibility", "ShadowMap", "Future" },
    HighlightDepthMode = { "AlwaysOnTop", "Occluded" },
}

-- KeyCode uses the real Roblox (SDL 1.2 derived) values where they matter.
do
    local kc = {
        Unknown = 0, Backspace = 8, Tab = 9, Clear = 12, Return = 13, Pause = 19,
        Escape = 27, Space = 32, QuotedDouble = 34, Hash = 35, Dollar = 36,
        Percent = 37, Ampersand = 38, Quote = 39, LeftParenthesis = 40,
        RightParenthesis = 41, Asterisk = 42, Plus = 43, Comma = 44, Minus = 45,
        Period = 46, Slash = 47, Colon = 58, Semicolon = 59, LessThan = 60,
        Equals = 61, GreaterThan = 62, Question = 63, At = 64, LeftBracket = 91,
        BackSlash = 92, RightBracket = 93, Caret = 94, Underscore = 95,
        Backquote = 96, Tilde = 126, Delete = 127,
        KeypadPeriod = 266, KeypadDivide = 267, KeypadMultiply = 268,
        KeypadMinus = 269, KeypadPlus = 270, KeypadEnter = 271, KeypadEquals = 272,
        Up = 273, Down = 274, Right = 275, Left = 276, Insert = 277, Home = 278,
        End = 279, PageUp = 280, PageDown = 281,
        NumLock = 300, CapsLock = 301, ScrollLock = 302, RightShift = 303,
        LeftShift = 304, RightControl = 305, LeftControl = 306, RightAlt = 307,
        LeftAlt = 308, RightMeta = 309, LeftMeta = 310, LeftSuper = 311,
        RightSuper = 312, Mode = 313, Compose = 314, Help = 315, Print = 316,
        SysReq = 317, Break = 318, Menu = 319, Power = 320, Euro = 321, Undo = 322,
        ButtonX = 1000, ButtonY = 1001, ButtonA = 1002, ButtonB = 1003,
        ButtonR1 = 1004, ButtonL1 = 1005, ButtonR2 = 1006, ButtonL2 = 1007,
        ButtonR3 = 1008, ButtonL3 = 1009, ButtonStart = 1010, ButtonSelect = 1011,
        DPadLeft = 1012, DPadRight = 1013, DPadUp = 1014, DPadDown = 1015,
        Thumbstick1 = 1016, Thumbstick2 = 1017,
    }
    for i = 1, 10 do
        kc[DIGITS[i]] = 47 + i                    -- Zero..Nine -> 48..57
        kc["Keypad" .. DIGITS[i]] = 255 + i       -- KeypadZero..KeypadNine
    end
    for i = 1, 26 do kc[string.char(64 + i)] = 96 + i end   -- A..Z -> 97..122
    for i = 1, 15 do kc["F" .. i] = 281 + i end             -- F1..F15
    ENUM_SEEDS.KeyCode = kc
end

function Datatypes.new()
    local D = {}

    -- === Enum ============================================================
    local Enum
    do
        local categories = {}

        local itemMt = { __type = "EnumItem" }
        itemMt.__tostring = function(self)
            return "Enum." .. self.EnumType.Name .. "." .. self.Name
        end
        itemMt.__index = function(self, k)
            if k == "IsA" then
                return function(_, n) return n == rawget(self.EnumType, "_name") end
            end
            return nil
        end

        local catMethods = {}
        local catMt = { __type = "Enum" }
        catMt.__tostring = function(self) return "Enum." .. rawget(self, "_name") end

        local function makeItem(cat, name, value)
            local items, order = rawget(cat, "_items"), rawget(cat, "_order")
            if value == nil then value = rawget(cat, "_next") end
            local item = setmetatable({ Name = name, Value = value, EnumType = cat }, itemMt)
            items[name] = item
            order[#order + 1] = item
            if value >= rawget(cat, "_next") then rawset(cat, "_next", value + 1) end
            return item
        end

        catMt.__index = function(self, k)
            local m = catMethods[k]
            if m ~= nil then return m end
            if k == "Name" then return rawget(self, "_name") end
            if type(k) ~= "string" or k:sub(1, 1) == "_" then return nil end
            local item = rawget(self, "_items")[k]
            if item ~= nil then return item end
            return makeItem(self, k)
        end

        function catMethods.GetEnumItems(self)
            local out = {}
            local order = rawget(self, "_order")
            for i = 1, #order do out[i] = order[i] end
            table.sort(out, function(a, b) return a.Value < b.Value end)
            return out
        end
        catMethods.getEnumItems = catMethods.GetEnumItems

        function catMethods.FromName(self, name) return rawget(self, "_items")[name] end
        function catMethods.FromValue(self, value)
            local order = rawget(self, "_order")
            for i = 1, #order do if order[i].Value == value then return order[i] end end
            return nil
        end

        local function makeCategory(name)
            local cat = setmetatable({}, catMt)
            rawset(cat, "_name", name)
            rawset(cat, "_items", {})
            rawset(cat, "_order", {})
            rawset(cat, "_next", 0)
            categories[name] = cat
            local seed = ENUM_SEEDS[name]
            if seed then
                if seed[1] ~= nil then
                    for i = 1, #seed do makeItem(cat, seed[i], i - 1) end
                else
                    local names = {}
                    for k in pairs(seed) do names[#names + 1] = k end
                    table.sort(names, function(a, b) return seed[a] < seed[b] end)
                    for i = 1, #names do makeItem(cat, names[i], seed[names[i]]) end
                end
            end
            return cat
        end

        Enum = setmetatable({}, {
            __type = "Enums",
            __tostring = function() return "Enum" end,
            __index = function(_, name)
                if type(name) ~= "string" then return nil end
                if name == "GetEnums" then
                    return function()
                        local out = {}
                        for _, c in pairs(categories) do out[#out + 1] = c end
                        return out
                    end
                end
                return categories[name] or makeCategory(name)
            end,
        })

        -- create the categories the seeds describe up front so GetEnumItems()
        -- works without touching an item first
        for name in pairs(ENUM_SEEDS) do makeCategory(name) end
    end
    D.Enum = Enum

    -- === Vector3 =========================================================
    local v3mt = { __type = "Vector3" }
    local v3methods = {}
    local function v3(x, y, z)
        return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, v3mt)
    end
    local function v3mag(a) return sqrt(a.X * a.X + a.Y * a.Y + a.Z * a.Z) end

    v3mt.__index = function(self, k)
        if k == "Magnitude" then return v3mag(self) end
        if k == "Unit" then
            local m = v3mag(self)
            if m == 0 then return v3(0, 0, 0) end
            return v3(self.X / m, self.Y / m, self.Z / m)
        end
        if k == "x" then return self.X end
        if k == "y" then return self.Y end
        if k == "z" then return self.Z end
        return v3methods[k]
    end
    v3mt.__add = function(a, b) return v3(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
    v3mt.__sub = function(a, b) return v3(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
    v3mt.__unm = function(a) return v3(-a.X, -a.Y, -a.Z) end
    v3mt.__mul = function(a, b)
        if type(a) == "number" then return v3(a * b.X, a * b.Y, a * b.Z) end
        if type(b) == "number" then return v3(a.X * b, a.Y * b, a.Z * b) end
        return v3(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
    end
    v3mt.__div = function(a, b)
        if type(b) == "number" then return v3(a.X / b, a.Y / b, a.Z / b) end
        if type(a) == "number" then return v3(a / b.X, a / b.Y, a / b.Z) end
        return v3(a.X / b.X, a.Y / b.Y, a.Z / b.Z)
    end
    v3mt.__eq = function(a, b) return a.X == b.X and a.Y == b.Y and a.Z == b.Z end
    v3mt.__tostring = function(a)
        return nfmt(a.X) .. ", " .. nfmt(a.Y) .. ", " .. nfmt(a.Z)
    end

    function v3methods.Dot(a, b) return a.X * b.X + a.Y * b.Y + a.Z * b.Z end
    function v3methods.Cross(a, b)
        return v3(a.Y * b.Z - a.Z * b.Y, a.Z * b.X - a.X * b.Z, a.X * b.Y - a.Y * b.X)
    end
    function v3methods.Lerp(a, b, t)
        return v3(a.X + (b.X - a.X) * t, a.Y + (b.Y - a.Y) * t, a.Z + (b.Z - a.Z) * t)
    end
    function v3methods.FuzzyEq(a, b, epsilon)
        epsilon = epsilon or 1e-5
        return abs(a.X - b.X) <= epsilon and abs(a.Y - b.Y) <= epsilon
            and abs(a.Z - b.Z) <= epsilon
    end
    function v3methods.Abs(a) return v3(abs(a.X), abs(a.Y), abs(a.Z)) end
    function v3methods.Floor(a) return v3(floor(a.X), floor(a.Y), floor(a.Z)) end
    function v3methods.Ceil(a) return v3(math.ceil(a.X), math.ceil(a.Y), math.ceil(a.Z)) end
    function v3methods.Sign(a)
        local function s(n) if n > 0 then return 1 elseif n < 0 then return -1 end return 0 end
        return v3(s(a.X), s(a.Y), s(a.Z))
    end
    function v3methods.Max(a, b) return v3(max(a.X, b.X), max(a.Y, b.Y), max(a.Z, b.Z)) end
    function v3methods.Min(a, b) return v3(min(a.X, b.X), min(a.Y, b.Y), min(a.Z, b.Z)) end
    function v3methods.Angle(a, b)
        local m = v3mag(a) * v3mag(b)
        if m == 0 then return 0 end
        return math.acos(clampn(v3methods.Dot(a, b) / m, -1, 1))
    end

    D.Vector3 = {
        new = v3, zero = v3(0, 0, 0), one = v3(1, 1, 1),
        xAxis = v3(1, 0, 0), yAxis = v3(0, 1, 0), zAxis = v3(0, 0, 1),
        FromNormalId = function(id)
            local n = type(id) == "table" and id.Name or tostring(id)
            local map = { Right = v3(1, 0, 0), Left = v3(-1, 0, 0), Top = v3(0, 1, 0),
                Bottom = v3(0, -1, 0), Front = v3(0, 0, -1), Back = v3(0, 0, 1) }
            return map[n] or v3(0, 0, 0)
        end,
    }

    -- === Vector2 =========================================================
    local v2mt = { __type = "Vector2" }
    local v2methods = {}
    local function v2(x, y) return setmetatable({ X = x or 0, Y = y or 0 }, v2mt) end
    local function v2mag(a) return sqrt(a.X * a.X + a.Y * a.Y) end

    v2mt.__index = function(self, k)
        if k == "Magnitude" then return v2mag(self) end
        if k == "Unit" then
            local m = v2mag(self)
            if m == 0 then return v2(0, 0) end
            return v2(self.X / m, self.Y / m)
        end
        if k == "x" then return self.X end
        if k == "y" then return self.Y end
        return v2methods[k]
    end
    v2mt.__add = function(a, b) return v2(a.X + b.X, a.Y + b.Y) end
    v2mt.__sub = function(a, b) return v2(a.X - b.X, a.Y - b.Y) end
    v2mt.__unm = function(a) return v2(-a.X, -a.Y) end
    v2mt.__mul = function(a, b)
        if type(a) == "number" then return v2(a * b.X, a * b.Y) end
        if type(b) == "number" then return v2(a.X * b, a.Y * b) end
        return v2(a.X * b.X, a.Y * b.Y)
    end
    v2mt.__div = function(a, b)
        if type(b) == "number" then return v2(a.X / b, a.Y / b) end
        if type(a) == "number" then return v2(a / b.X, a / b.Y) end
        return v2(a.X / b.X, a.Y / b.Y)
    end
    v2mt.__eq = function(a, b) return a.X == b.X and a.Y == b.Y end
    v2mt.__tostring = function(a) return nfmt(a.X) .. ", " .. nfmt(a.Y) end

    function v2methods.Dot(a, b) return a.X * b.X + a.Y * b.Y end
    function v2methods.Cross(a, b) return a.X * b.Y - a.Y * b.X end
    function v2methods.Lerp(a, b, t)
        return v2(a.X + (b.X - a.X) * t, a.Y + (b.Y - a.Y) * t)
    end
    function v2methods.FuzzyEq(a, b, e)
        e = e or 1e-5
        return abs(a.X - b.X) <= e and abs(a.Y - b.Y) <= e
    end
    D.Vector2 = { new = v2, zero = v2(0, 0), one = v2(1, 1),
        xAxis = v2(1, 0), yAxis = v2(0, 1) }

    -- === CFrame ==========================================================
    -- rotation is a row-major 3x3: { r00,r01,r02, r10,r11,r12, r20,r21,r22 }
    local IDENT = { 1, 0, 0, 0, 1, 0, 0, 0, 1 }
    local function matMul(a, b)
        return {
            a[1] * b[1] + a[2] * b[4] + a[3] * b[7],
            a[1] * b[2] + a[2] * b[5] + a[3] * b[8],
            a[1] * b[3] + a[2] * b[6] + a[3] * b[9],
            a[4] * b[1] + a[5] * b[4] + a[6] * b[7],
            a[4] * b[2] + a[5] * b[5] + a[6] * b[8],
            a[4] * b[3] + a[5] * b[6] + a[6] * b[9],
            a[7] * b[1] + a[8] * b[4] + a[9] * b[7],
            a[7] * b[2] + a[8] * b[5] + a[9] * b[8],
            a[7] * b[3] + a[8] * b[6] + a[9] * b[9],
        }
    end
    local function matVec(m, x, y, z)
        return m[1] * x + m[2] * y + m[3] * z,
               m[4] * x + m[5] * y + m[6] * z,
               m[7] * x + m[8] * y + m[9] * z
    end
    local function matT(m)
        return { m[1], m[4], m[7], m[2], m[5], m[8], m[3], m[6], m[9] }
    end

    local cfmt = { __type = "CFrame" }
    local cfmethods = {}
    local function cf(x, y, z, r)
        return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0, R = r or IDENT }, cfmt)
    end

    cfmt.__index = function(self, k)
        if k == "Position" or k == "p" then return v3(self.X, self.Y, self.Z) end
        local r = self.R
        if k == "LookVector" then return v3(-r[3], -r[6], -r[9]) end
        if k == "RightVector" or k == "XVector" then return v3(r[1], r[4], r[7]) end
        if k == "UpVector" or k == "YVector" then return v3(r[2], r[5], r[8]) end
        if k == "ZVector" then return v3(r[3], r[6], r[9]) end
        if k == "Rotation" then return cf(0, 0, 0, r) end
        if k == "x" then return self.X end
        if k == "y" then return self.Y end
        if k == "z" then return self.Z end
        return cfmethods[k]
    end
    cfmt.__mul = function(a, b)
        if getmetatable(b) == cfmt then
            local x, y, z = matVec(a.R, b.X, b.Y, b.Z)
            return cf(a.X + x, a.Y + y, a.Z + z, matMul(a.R, b.R))
        end
        if getmetatable(b) == v3mt then
            local x, y, z = matVec(a.R, b.X, b.Y, b.Z)
            return v3(a.X + x, a.Y + y, a.Z + z)
        end
        error("bad operand to CFrame * (expected CFrame or Vector3)", 2)
    end
    cfmt.__add = function(a, b) return cf(a.X + b.X, a.Y + b.Y, a.Z + b.Z, a.R) end
    cfmt.__sub = function(a, b) return cf(a.X - b.X, a.Y - b.Y, a.Z - b.Z, a.R) end
    cfmt.__eq = function(a, b)
        if a.X ~= b.X or a.Y ~= b.Y or a.Z ~= b.Z then return false end
        for i = 1, 9 do if a.R[i] ~= b.R[i] then return false end end
        return true
    end
    cfmt.__tostring = function(a)
        local out = { nfmt(a.X), nfmt(a.Y), nfmt(a.Z) }
        for i = 1, 9 do out[#out + 1] = nfmt(a.R[i]) end
        return table.concat(out, ", ")
    end

    local function eulerMatrix(rx, ry, rz)
        local cx, sx, cy, sy, cz, sz = cos(rx), sin(rx), cos(ry), sin(ry), cos(rz), sin(rz)
        -- Rx * Ry * Rz (Roblox CFrame.Angles order)
        return {
            cy * cz, -cy * sz, sy,
            cx * sz + sx * sy * cz, cx * cz - sx * sy * sz, -sx * cy,
            sx * sz - cx * sy * cz, sx * cz + cx * sy * sz, cx * cy,
        }
    end

    local function lookAtMatrix(fromV, toV, upV)
        upV = upV or v3(0, 1, 0)
        local dir = toV - fromV
        if v3mag(dir) < 1e-9 then dir = v3(0, 0, -1) end
        local zAxis = -(dir.Unit)                      -- Roblox: -look
        local xAxis = upV:Cross(zAxis)
        if v3mag(xAxis) < 1e-9 then
            xAxis = v3(1, 0, 0):Cross(zAxis)
            if v3mag(xAxis) < 1e-9 then xAxis = v3(1, 0, 0) end
        end
        xAxis = xAxis.Unit
        local yAxis = zAxis:Cross(xAxis).Unit
        return { xAxis.X, yAxis.X, zAxis.X, xAxis.Y, yAxis.Y, zAxis.Y,
                 xAxis.Z, yAxis.Z, zAxis.Z }
    end

    local function quatMatrix(qx, qy, qz, qw)
        local n = sqrt(qx * qx + qy * qy + qz * qz + qw * qw)
        if n == 0 then return { 1, 0, 0, 0, 1, 0, 0, 0, 1 } end
        qx, qy, qz, qw = qx / n, qy / n, qz / n, qw / n
        return {
            1 - 2 * (qy * qy + qz * qz), 2 * (qx * qy - qz * qw), 2 * (qx * qz + qy * qw),
            2 * (qx * qy + qz * qw), 1 - 2 * (qx * qx + qz * qz), 2 * (qy * qz - qx * qw),
            2 * (qx * qz - qy * qw), 2 * (qy * qz + qx * qw), 1 - 2 * (qx * qx + qy * qy),
        }
    end

    function cfmethods.Inverse(self)
        local rt = matT(self.R)
        local x, y, z = matVec(rt, self.X, self.Y, self.Z)
        return cf(-x, -y, -z, rt)
    end
    cfmethods.inverse = cfmethods.Inverse

    function cfmethods.ToWorldSpace(self, other) return self * other end
    function cfmethods.ToObjectSpace(self, other) return self:Inverse() * other end
    function cfmethods.PointToWorldSpace(self, p) return self * p end
    function cfmethods.PointToObjectSpace(self, p) return self:Inverse() * p end
    function cfmethods.VectorToWorldSpace(self, vec)
        local x, y, z = matVec(self.R, vec.X, vec.Y, vec.Z)
        return v3(x, y, z)
    end
    function cfmethods.VectorToObjectSpace(self, vec)
        local x, y, z = matVec(matT(self.R), vec.X, vec.Y, vec.Z)
        return v3(x, y, z)
    end
    function cfmethods.GetComponents(self)
        local r = self.R
        return self.X, self.Y, self.Z, r[1], r[2], r[3], r[4], r[5], r[6], r[7], r[8], r[9]
    end
    cfmethods.components = cfmethods.GetComponents

    function cfmethods.ToEulerAnglesXYZ(self)
        local r = self.R
        local ry = math.asin(clampn(r[3], -1, 1))
        local rx = atan2(-r[6], r[9])
        local rz = atan2(-r[2], r[1])
        return rx, ry, rz
    end
    cfmethods.toEulerAnglesXYZ = cfmethods.ToEulerAnglesXYZ
    cfmethods.ToEulerAngles = cfmethods.ToEulerAnglesXYZ
    function cfmethods.ToOrientation(self)
        local rx, ry, rz = cfmethods.ToEulerAnglesXYZ(self)
        return rx, ry, rz
    end
    cfmethods.ToEulerAnglesYXZ = cfmethods.ToOrientation

    function cfmethods.ToAxisAngle(self)
        local r = self.R
        local trace = r[1] + r[5] + r[9]
        local angle = math.acos(clampn((trace - 1) / 2, -1, 1))
        local s = sin(angle)
        if abs(s) < 1e-9 then return v3(0, 1, 0), angle end
        return v3((r[8] - r[6]) / (2 * s), (r[3] - r[7]) / (2 * s),
                  (r[4] - r[2]) / (2 * s)), angle
    end

    -- Position is interpolated exactly; rotation snaps to the nearer operand.
    function cfmethods.Lerp(self, goal, alpha)
        local x = self.X + (goal.X - self.X) * alpha
        local y = self.Y + (goal.Y - self.Y) * alpha
        local z = self.Z + (goal.Z - self.Z) * alpha
        return cf(x, y, z, alpha < 0.5 and self.R or goal.R)
    end
    cfmethods.lerp = cfmethods.Lerp
    function cfmethods.Orthonormalize(self) return self end
    function cfmethods.FuzzyEq(self, other, epsilon)
        epsilon = epsilon or 1e-5
        return abs(self.X - other.X) <= epsilon and abs(self.Y - other.Y) <= epsilon
            and abs(self.Z - other.Z) <= epsilon
    end

    local CFrameLib = {}
    CFrameLib.new = function(a, b, c, ...)
        local n = select("#", ...)
        if a == nil then return cf(0, 0, 0, IDENT) end
        if type(a) == "table" then
            if b == nil then return cf(a.X, a.Y, a.Z, IDENT) end
            return cf(a.X, a.Y, a.Z, lookAtMatrix(a, b, c))
        end
        if n == 0 then return cf(a, b or 0, c or 0, IDENT) end
        if n == 4 then
            local qx, qy, qz, qw = ...
            return cf(a, b, c, quatMatrix(qx, qy, qz, qw))
        end
        if n == 9 then
            local r = { ... }
            return cf(a, b, c, r)
        end
        return cf(a, b or 0, c or 0, IDENT)
    end
    CFrameLib.lookAt = function(fromV, toV, upV)
        return cf(fromV.X, fromV.Y, fromV.Z, lookAtMatrix(fromV, toV, upV))
    end
    CFrameLib.Angles = function(rx, ry, rz) return cf(0, 0, 0, eulerMatrix(rx, ry, rz)) end
    CFrameLib.fromEulerAnglesXYZ = CFrameLib.Angles
    CFrameLib.fromEulerAngles = CFrameLib.Angles
    CFrameLib.fromEulerAnglesYXZ = CFrameLib.Angles
    CFrameLib.fromOrientation = CFrameLib.Angles
    CFrameLib.fromAxisAngle = function(axis, angle)
        local u = axis.Unit
        local s, c1 = sin(angle / 2), cos(angle / 2)
        return cf(0, 0, 0, quatMatrix(u.X * s, u.Y * s, u.Z * s, c1))
    end
    CFrameLib.fromMatrix = function(pos, vx, vy, vz)
        vz = vz or vx:Cross(vy).Unit
        return cf(pos.X, pos.Y, pos.Z,
            { vx.X, vy.X, vz.X, vx.Y, vy.Y, vz.Y, vx.Z, vy.Z, vz.Z })
    end
    CFrameLib.identity = cf(0, 0, 0, IDENT)
    D.CFrame = CFrameLib

    -- === Color3 ==========================================================
    local c3mt = { __type = "Color3" }
    local c3methods = {}
    local function c3(r, g, b)
        return setmetatable({ R = r or 0, G = g or 0, B = b or 0 }, c3mt)
    end
    c3mt.__index = function(self, k)
        if k == "r" then return self.R end
        if k == "g" then return self.G end
        if k == "b" then return self.B end
        return c3methods[k]
    end
    c3mt.__eq = function(a, b) return a.R == b.R and a.G == b.G and a.B == b.B end
    c3mt.__tostring = function(a)
        return nfmt(a.R) .. ", " .. nfmt(a.G) .. ", " .. nfmt(a.B)
    end

    function c3methods.Lerp(a, b, t)
        return c3(a.R + (b.R - a.R) * t, a.G + (b.G - a.G) * t, a.B + (b.B - a.B) * t)
    end
    function c3methods.ToHSV(self)
        local r, g, b = self.R, self.G, self.B
        local mx, mn = max(r, g, b), min(r, g, b)
        local d = mx - mn
        local h = 0
        if d > 0 then
            if mx == r then h = ((g - b) / d) % 6
            elseif mx == g then h = (b - r) / d + 2
            else h = (r - g) / d + 4 end
            h = h / 6
        end
        local s = mx == 0 and 0 or d / mx
        return h, s, mx
    end
    c3methods.toHSV = c3methods.ToHSV
    function c3methods.ToHex(self)
        local function ch(v) return string.format("%02X", floor(clampn(v, 0, 1) * 255 + 0.5)) end
        return ch(self.R) .. ch(self.G) .. ch(self.B)
    end

    local function fromHSV(h, s, v)
        h = (h or 0) % 1
        s, v = clampn(s or 0, 0, 1), clampn(v or 0, 0, 1)
        local i = floor(h * 6)
        local f = h * 6 - i
        local p, q, t = v * (1 - s), v * (1 - f * s), v * (1 - (1 - f) * s)
        local m = i % 6
        if m == 0 then return c3(v, t, p) end
        if m == 1 then return c3(q, v, p) end
        if m == 2 then return c3(p, v, t) end
        if m == 3 then return c3(p, q, v) end
        if m == 4 then return c3(t, p, v) end
        return c3(v, p, q)
    end

    D.Color3 = {
        new = c3,
        fromRGB = function(r, g, b)
            return c3((r or 0) / 255, (g or 0) / 255, (b or 0) / 255)
        end,
        fromHSV = fromHSV,
        toHSV = function(col) return c3methods.ToHSV(col) end,
        fromHex = function(hex)
            hex = tostring(hex):gsub("^#", "")
            if #hex == 3 then
                hex = hex:sub(1, 1):rep(2) .. hex:sub(2, 2):rep(2) .. hex:sub(3, 3):rep(2)
            end
            local r = tonumber(hex:sub(1, 2), 16) or 0
            local g = tonumber(hex:sub(3, 4), 16) or 0
            local b = tonumber(hex:sub(5, 6), 16) or 0
            return c3(r / 255, g / 255, b / 255)
        end,
    }

    -- === UDim / UDim2 ====================================================
    local udmt = { __type = "UDim" }
    local function ud(scale, offset)
        return setmetatable({ Scale = scale or 0, Offset = offset or 0 }, udmt)
    end
    udmt.__index = function(self, k)
        if k == "Lerp" then
            return function(a, b, t)
                return ud(a.Scale + (b.Scale - a.Scale) * t,
                          a.Offset + (b.Offset - a.Offset) * t)
            end
        end
        return nil
    end
    udmt.__add = function(a, b) return ud(a.Scale + b.Scale, a.Offset + b.Offset) end
    udmt.__sub = function(a, b) return ud(a.Scale - b.Scale, a.Offset - b.Offset) end
    udmt.__unm = function(a) return ud(-a.Scale, -a.Offset) end
    udmt.__eq = function(a, b) return a.Scale == b.Scale and a.Offset == b.Offset end
    udmt.__tostring = function(a) return nfmt(a.Scale) .. ", " .. nfmt(a.Offset) end
    D.UDim = { new = ud }

    local ud2mt = { __type = "UDim2" }
    local ud2methods = {}
    local function ud2(x, y) return setmetatable({ X = x, Y = y }, ud2mt) end
    local function ud2new(a, b, c, d)
        if type(a) == "table" then return ud2(a, b or ud(0, 0)) end
        return ud2(ud(a or 0, b or 0), ud(c or 0, d or 0))
    end
    ud2mt.__index = function(self, k)
        if k == "Width" then return self.X end
        if k == "Height" then return self.Y end
        return ud2methods[k]
    end
    ud2mt.__add = function(a, b) return ud2(a.X + b.X, a.Y + b.Y) end
    ud2mt.__sub = function(a, b) return ud2(a.X - b.X, a.Y - b.Y) end
    ud2mt.__unm = function(a) return ud2(-a.X, -a.Y) end
    ud2mt.__mul = function(a, b)
        if type(b) == "number" then
            return ud2(ud(a.X.Scale * b, a.X.Offset * b), ud(a.Y.Scale * b, a.Y.Offset * b))
        end
        if type(a) == "number" then return ud2mt.__mul(b, a) end
        return ud2(ud(a.X.Scale * b.X.Scale, a.X.Offset * b.X.Offset),
                   ud(a.Y.Scale * b.Y.Scale, a.Y.Offset * b.Y.Offset))
    end
    ud2mt.__eq = function(a, b) return a.X == b.X and a.Y == b.Y end
    ud2mt.__tostring = function(a)
        return "{" .. tostring(a.X) .. "}, {" .. tostring(a.Y) .. "}"
    end
    function ud2methods.Lerp(a, b, t)
        return ud2(a.X:Lerp(b.X, t), a.Y:Lerp(b.Y, t))
    end
    D.UDim2 = {
        new = ud2new,
        fromScale = function(x, y) return ud2(ud(x or 0, 0), ud(y or 0, 0)) end,
        fromOffset = function(x, y) return ud2(ud(0, x or 0), ud(0, y or 0)) end,
    }

    -- === simple records ==================================================
    local function simple(typeName, tostr, methods)
        local mt = { __type = typeName }
        mt.__index = methods and function(_, k) return methods[k] end or nil
        mt.__tostring = tostr
        return mt, function(t) return setmetatable(t, mt) end
    end

    local rectMethods = {}
    local rectMt, mkRect = simple("Rect", function(a)
        return tostring(a.Min) .. ", " .. tostring(a.Max)
    end, rectMethods)
    rectMt.__index = function(self, k)
        if k == "Width" then return self.Max.X - self.Min.X end
        if k == "Height" then return self.Max.Y - self.Min.Y end
        return rectMethods[k]
    end
    D.Rect = {
        new = function(a, b, c, d)
            if type(a) == "table" then return mkRect({ Min = a, Max = b }) end
            return mkRect({ Min = v2(a, b), Max = v2(c, d) })
        end,
    }

    local _, mkRange = simple("NumberRange", function(a)
        return nfmt(a.Min) .. " " .. nfmt(a.Max)
    end)
    D.NumberRange = {
        new = function(a, b) return mkRange({ Min = a or 0, Max = b or a or 0 }) end,
    }

    local _, mkNSK = simple("NumberSequenceKeypoint", function(a)
        return nfmt(a.Time) .. " " .. nfmt(a.Value) .. " " .. nfmt(a.Envelope)
    end)
    D.NumberSequenceKeypoint = {
        new = function(t, v, e)
            return mkNSK({ Time = t or 0, Value = v or 0, Envelope = e or 0 })
        end,
    }

    local _, mkNS = simple("NumberSequence", function() return "NumberSequence" end)
    D.NumberSequence = {
        new = function(a, b)
            local kps
            if type(a) == "table" and a[1] ~= nil then
                kps = a
            elseif b ~= nil then
                kps = { D.NumberSequenceKeypoint.new(0, a), D.NumberSequenceKeypoint.new(1, b) }
            else
                kps = { D.NumberSequenceKeypoint.new(0, a or 0),
                        D.NumberSequenceKeypoint.new(1, a or 0) }
            end
            return mkNS({ Keypoints = kps })
        end,
    }

    local _, mkCSK = simple("ColorSequenceKeypoint", function(a)
        return nfmt(a.Time) .. " " .. tostring(a.Value)
    end)
    D.ColorSequenceKeypoint = {
        new = function(t, v) return mkCSK({ Time = t or 0, Value = v or c3(1, 1, 1) }) end,
    }

    local _, mkCS = simple("ColorSequence", function() return "ColorSequence" end)
    D.ColorSequence = {
        new = function(a, b)
            local kps
            if type(a) == "table" and a[1] ~= nil then
                kps = a
            elseif b ~= nil then
                kps = { D.ColorSequenceKeypoint.new(0, a), D.ColorSequenceKeypoint.new(1, b) }
            else
                kps = { D.ColorSequenceKeypoint.new(0, a or c3(1, 1, 1)),
                        D.ColorSequenceKeypoint.new(1, a or c3(1, 1, 1)) }
            end
            return mkCS({ Keypoints = kps })
        end,
    }

    local _, mkTween = simple("TweenInfo", function() return "TweenInfo" end)
    D.TweenInfo = {
        new = function(time, style, dir, repeatCount, reverses, delayTime)
            return mkTween({
                Time = time or 1,
                EasingStyle = style or Enum.EasingStyle.Quad,
                EasingDirection = dir or Enum.EasingDirection.Out,
                RepeatCount = repeatCount or 0,
                Reverses = reverses and true or false,
                DelayTime = delayTime or 0,
            })
        end,
    }

    -- === BrickColor (small palette) =======================================
    local PALETTE = {
        { 1, "White", 242, 243, 243 }, { 194, "Bright red", 196, 40, 28 },
        { 21, "Really red", 255, 0, 0 }, { 23, "Bright blue", 13, 105, 172 },
        { 24, "Bright yellow", 245, 205, 48 }, { 26, "Really black", 27, 42, 53 },
        { 28, "Dark green", 40, 127, 71 }, { 37, "Bright green", 75, 151, 75 },
        { 106, "Bright orange", 218, 133, 65 }, { 107, "Teal", 0, 255, 255 },
        { 119, "Br. yellowish green", 164, 189, 71 }, { 141, "Earth green", 39, 70, 45 },
        { 199, "Dark stone grey", 99, 95, 98 }, { 194, "Medium stone grey", 163, 162, 165 },
        { 208, "Light stone grey", 229, 228, 223 }, { 1004, "Really blue", 0, 0, 255 },
        { 21, "Crimson", 151, 0, 0 }, { 102, "Medium blue", 110, 153, 202 },
        { 9, "Light reddish violet", 232, 186, 200 }, { 11, "Pastel Blue", 128, 187, 219 },
    }
    local _, mkBrick = simple("BrickColor", function(a) return a.Name end)
    local function brickFromEntry(e)
        return mkBrick({
            Number = e[1], Name = e[2], Color = c3(e[3] / 255, e[4] / 255, e[5] / 255),
            r = e[3] / 255, g = e[4] / 255, b = e[5] / 255,
        })
    end
    local function brickNew(a, b, c)
        if type(a) == "string" then
            for i = 1, #PALETTE do
                if PALETTE[i][2] == a then return brickFromEntry(PALETTE[i]) end
            end
            return brickFromEntry(PALETTE[1])
        end
        if type(a) == "number" and b == nil then
            for i = 1, #PALETTE do
                if PALETTE[i][1] == a then return brickFromEntry(PALETTE[i]) end
            end
            return brickFromEntry(PALETTE[1])
        end
        if type(a) == "table" then      -- Color3
            return mkBrick({ Number = 1, Name = "White", Color = a,
                r = a.R, g = a.G, b = a.B })
        end
        local col = c3(a or 0, b or 0, c or 0)
        return mkBrick({ Number = 1, Name = "White", Color = col,
            r = col.R, g = col.G, b = col.B })
    end
    D.BrickColor = {
        new = brickNew,
        Random = function() return brickFromEntry(PALETTE[math.random(#PALETTE)]) end,
        palette = function(n) return brickFromEntry(PALETTE[(n % #PALETTE) + 1]) end,
        White = function() return brickNew("White") end,
        Black = function() return brickNew("Really black") end,
        Red = function() return brickNew("Bright red") end,
        Green = function() return brickNew("Dark green") end,
        Blue = function() return brickNew("Bright blue") end,
        Gray = function() return brickNew("Medium stone grey") end,
        DarkGray = function() return brickNew("Dark stone grey") end,
        Yellow = function() return brickNew("Bright yellow") end,
    }

    -- === Ray / Region3 ===================================================
    local rayMethods = {}
    local _, mkRay = simple("Ray", function(a)
        return tostring(a.Origin) .. " -> " .. tostring(a.Direction)
    end, rayMethods)
    function rayMethods.ClosestPoint(self, point)
        local dir = self.Direction
        local m = v3mag(dir)
        if m == 0 then return self.Origin end
        local u = dir / m
        local t = (point - self.Origin):Dot(u)
        if t < 0 then t = 0 end
        return self.Origin + u * t
    end
    function rayMethods.Distance(self, point)
        return (point - rayMethods.ClosestPoint(self, point)).Magnitude
    end
    D.Ray = {
        new = function(origin, direction)
            local r = mkRay({ Origin = origin or v3(), Direction = direction or v3() })
            r.Unit = mkRay({ Origin = r.Origin, Direction = r.Direction.Unit })
            return r
        end,
    }

    local region3Methods = {}
    local _, mkRegion = simple("Region3", function() return "Region3" end, region3Methods)
    function region3Methods.ExpandToGrid(self) return self end
    D.Region3 = {
        new = function(minV, maxV)
            minV, maxV = minV or v3(), maxV or v3()
            local size = maxV - minV
            local center = (minV + maxV) * 0.5
            return mkRegion({ CFrame = cf(center.X, center.Y, center.Z, IDENT),
                Size = size, Min = minV, Max = maxV })
        end,
    }

    -- === Random ===========================================================
    local randMethods = {}
    local _, mkRandom = simple("Random", function() return "Random" end, randMethods)
    local function nextRaw(self)
        -- deterministic 32-bit LCG so the host math.random state is untouched
        self._state = (1103515245 * self._state + 12345) % 2147483648
        return self._state / 2147483648
    end
    function randMethods.NextNumber(self, a, b)
        local r = nextRaw(self)
        if a == nil then return r end
        if b == nil then b, a = a, 0 end
        return a + r * (b - a)
    end
    function randMethods.NextInteger(self, a, b)
        a, b = a or 0, b or 1
        return a + floor(nextRaw(self) * (b - a + 1) - 1e-12)
    end
    function randMethods.NextUnitVector(self)
        local z = randMethods.NextNumber(self, -1, 1)
        local t = randMethods.NextNumber(self, 0, 2 * pi)
        local r = sqrt(1 - z * z)
        return v3(r * cos(t), r * sin(t), z)
    end
    function randMethods.Clone(self)
        local c = mkRandom({ _state = self._state })
        return c
    end
    function randMethods.Shuffle(self, t)
        for i = #t, 2, -1 do
            local j = randMethods.NextInteger(self, 1, i)
            t[i], t[j] = t[j], t[i]
        end
        return t
    end
    D.Random = {
        new = function(seed)
            return mkRandom({ _state = (tonumber(seed) or os.time()) % 2147483648 })
        end,
    }

    -- === mutable parameter objects ========================================
    local rcMethods = {}
    local rcMt = { __type = "RaycastParams", __index = function(_, k) return rcMethods[k] end }
    function rcMethods.AddToFilter(self, inst)
        local list = self.FilterDescendantsInstances
        if type(inst) == "table" and inst[1] ~= nil then
            for i = 1, #inst do list[#list + 1] = inst[i] end
        else
            list[#list + 1] = inst
        end
    end
    D.RaycastParams = {
        new = function()
            return setmetatable({
                FilterDescendantsInstances = {},
                FilterType = Enum.RaycastFilterType.Exclude,
                IgnoreWater = false,
                CollisionGroup = "Default",
                RespectCanCollide = false,
                BruteForceAllSlow = false,
            }, rcMt)
        end,
    }

    local opMt = { __type = "OverlapParams", __index = function(_, k) return rcMethods[k] end }
    D.OverlapParams = {
        new = function()
            return setmetatable({
                FilterDescendantsInstances = {},
                FilterType = Enum.RaycastFilterType.Exclude,
                MaxParts = 0,
                CollisionGroup = "Default",
                RespectCanCollide = false,
                BruteForceAllSlow = false,
            }, opMt)
        end,
    }

    local _, mkPhys = simple("PhysicalProperties", function() return "PhysicalProperties" end)
    D.PhysicalProperties = {
        new = function(density, friction, elasticity, fw, ew)
            return mkPhys({
                Density = density or 0.7, Friction = friction or 0.3,
                Elasticity = elasticity or 0.5, FrictionWeight = fw or 1,
                ElasticityWeight = ew or 1,
            })
        end,
    }

    -- === Font / Faces / Axes ==============================================
    local _, mkFont = simple("Font", function(a) return a.Family end)
    local function fontNew(family, weight, style)
        return mkFont({
            Family = family or "rbxasset://fonts/families/SourceSansPro.json",
            Weight = weight or Enum.FontWeight.Regular,
            Style = style or Enum.FontStyle.Normal,
            Bold = false,
        })
    end
    D.Font = {
        new = fontNew,
        fromEnum = function(e) return fontNew(tostring(e and e.Name or "SourceSans")) end,
        fromName = function(name, weight, style)
            return fontNew("rbxasset://fonts/families/" .. tostring(name) .. ".json", weight, style)
        end,
        fromId = function(id, weight, style)
            return fontNew("rbxassetid://" .. tostring(id), weight, style)
        end,
    }

    local _, mkFaces = simple("Faces", function() return "Faces" end)
    D.Faces = {
        new = function(...)
            local f = { Top = false, Bottom = false, Left = false, Right = false,
                Front = false, Back = false }
            for i = 1, select("#", ...) do
                local id = select(i, ...)
                local name = type(id) == "table" and id.Name or tostring(id)
                if f[name] ~= nil then f[name] = true end
            end
            return mkFaces(f)
        end,
    }

    local _, mkAxes = simple("Axes", function() return "Axes" end)
    D.Axes = {
        new = function(...)
            local a = { X = false, Y = false, Z = false, Top = false, Bottom = false,
                Left = false, Right = false, Front = false, Back = false }
            for i = 1, select("#", ...) do
                local id = select(i, ...)
                local name = type(id) == "table" and id.Name or tostring(id)
                if a[name] ~= nil then a[name] = true end
            end
            return mkAxes(a)
        end,
    }

    -- === predicates used by typeof() and the instance stub =================
    D.typeName = Datatypes.typeName
    function D.isVector3(v) return getmetatable(v) == v3mt end
    function D.isVector2(v) return getmetatable(v) == v2mt end
    function D.isCFrame(v) return getmetatable(v) == cfmt end
    function D.isColor3(v) return getmetatable(v) == c3mt end
    function D.isUDim2(v) return getmetatable(v) == ud2mt end
    function D.isEnumItem(v) return Datatypes.typeName(v) == "EnumItem" end

    return D
end

return Datatypes














