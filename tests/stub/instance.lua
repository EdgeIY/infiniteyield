--[[ tests/stub/instance.lua --------------------------------------------------
  Roblox Instance stub: plain data, no rendering.

  Contract: Instance.newLibrary(ctx) -> lib
    ctx = { scheduler =, signal =, datatypes =, output = , options = }
    lib.new(className, parent)      create an instance
    lib.is(v)                       is v one of our instances
    lib.all()                       every live instance (getinstances)
    lib.data(inst)                  internal record (used by init.lua)
    lib.addMethods(inst, tbl)       per-instance methods (services, players)
    lib.addGetters(inst, tbl)       per-instance computed properties
    lib.classHierarchy              className -> parent className
    lib.defaults / lib.classDefaults / lib.signalNames

  Member lookup order (first hit wins):
    stored property -> Parent/ClassName -> per-instance getter -> per-instance
    method -> class method (walking the hierarchy) -> base method -> existing
    signal -> auto-created signal -> child by name -> class default -> generic
    default -> permissive no-op method.

  The last step is the deliberate compromise: a *property* that does not exist
  reads as nil, but a name that looks like a method (GetFoo, IsBar, Destroy, ...)
  returns a recorded no-op function so the script under test fails with a
  recorded coverage gap instead of "attempt to call a nil value".  Every such
  call is appended to output.unimplemented as { className =, name =, count = }.
--]]

local Instance = {}

-- className -> parent className.  Anything missing is treated as a direct
-- child of Instance, so :IsA("Instance") is always true.
local CLASS_PARENT = {
    PVInstance = "Instance",
    Model = "PVInstance",
    WorldRoot = "Model",
    Workspace = "WorldRoot",
    Actor = "Model",
    BasePart = "PVInstance",
    FormFactorPart = "BasePart",
    Part = "FormFactorPart",
    Seat = "Part",
    SpawnLocation = "Part",
    VehicleSeat = "BasePart",
    MeshPart = "BasePart",
    TriangleMeshPart = "BasePart",
    PartOperation = "TriangleMeshPart",
    UnionOperation = "PartOperation",
    NegateOperation = "PartOperation",
    IntersectOperation = "PartOperation",
    Terrain = "BasePart",
    TrussPart = "BasePart",
    WedgePart = "FormFactorPart",
    CornerWedgePart = "BasePart",
    CornerWedge = "BasePart",
    SpecialMesh = "FileMesh",
    FileMesh = "DataModelMesh",
    DataModelMesh = "Instance",
}

do -- GUI, values, scripts, joints, effects, services
    local more = {
        GuiBase = "Instance", GuiBase2d = "GuiBase", GuiObject = "GuiBase2d",
        GuiButton = "GuiObject", TextButton = "GuiButton", ImageButton = "GuiButton",
        GuiLabel = "GuiObject", TextLabel = "GuiLabel", ImageLabel = "GuiLabel",
        Frame = "GuiObject", ScrollingFrame = "GuiObject", TextBox = "GuiObject",
        VideoFrame = "GuiObject", ViewportFrame = "GuiObject", CanvasGroup = "GuiObject",
        LayerCollector = "GuiBase2d", ScreenGui = "LayerCollector",
        GuiMain = "ScreenGui", BillboardGui = "LayerCollector",
        SurfaceGui = "LayerCollector", SurfaceGuiBase = "LayerCollector",
        BasePlayerGui = "Instance", PlayerGui = "BasePlayerGui", CoreGui = "BasePlayerGui",
        UIBase = "Instance", UIComponent = "UIBase", UICorner = "UIComponent",
        UIScale = "UIComponent", UIPadding = "UIComponent", UIGradient = "UIComponent",
        UIStroke = "UIComponent", UIFlexItem = "UIComponent",
        UILayout = "UIComponent", UIGridStyleLayout = "UILayout",
        UIListLayout = "UIGridStyleLayout", UIGridLayout = "UIGridStyleLayout",
        UIPageLayout = "UIGridStyleLayout", UITableLayout = "UIGridStyleLayout",
        UIConstraint = "UIComponent", UIAspectRatioConstraint = "UIConstraint",
        UISizeConstraint = "UIConstraint", UITextSizeConstraint = "UIConstraint",
        ValueBase = "Instance", StringValue = "ValueBase", IntValue = "ValueBase",
        NumberValue = "ValueBase", BoolValue = "ValueBase", ObjectValue = "ValueBase",
        CFrameValue = "ValueBase", Vector3Value = "ValueBase", Color3Value = "ValueBase",
        BrickColorValue = "ValueBase", RayValue = "ValueBase",
        LuaSourceContainer = "Instance", BaseScript = "LuaSourceContainer",
        Script = "BaseScript", LocalScript = "BaseScript",
        ModuleScript = "LuaSourceContainer",
        Humanoid = "Instance", Animator = "Instance", Player = "Instance",
        Team = "Instance", Folder = "Instance", Configuration = "Instance",
        Camera = "Instance", Highlight = "Instance", Attachment = "Instance",
        ClickDetector = "Instance", ProximityPrompt = "Instance",
        TouchTransmitter = "Instance", Animation = "Instance",
        AnimationTrack = "Instance", KeyframeSequence = "Instance",
        HumanoidDescription = "Instance", Mouse = "Instance", PlayerMouse = "Mouse",
        Backpack = "Instance", StarterGear = "Instance", PlayerScripts = "Instance",
        Accoutrement = "Instance", Accessory = "Accoutrement", Hat = "Accoutrement",
        CharacterAppearance = "Instance", Clothing = "CharacterAppearance",
        Shirt = "Clothing", Pants = "Clothing", ShirtGraphic = "CharacterAppearance",
        BodyColors = "CharacterAppearance", CharacterMesh = "CharacterAppearance",
        BackpackItem = "Instance", Tool = "BackpackItem", HopperBin = "BackpackItem",
        Flag = "Tool",
        JointInstance = "Instance", Motor = "JointInstance", Motor6D = "Motor",
        Weld = "JointInstance", Snap = "JointInstance", Rotate = "JointInstance",
        WeldConstraint = "Instance", NoCollisionConstraint = "Instance",
        Constraint = "Instance", AlignPosition = "Constraint",
        AlignOrientation = "Constraint", LinearVelocity = "Constraint",
        AngularVelocity = "Constraint", VectorForce = "Constraint",
        Torque = "Constraint", RopeConstraint = "Constraint",
        BodyMover = "Instance", BodyVelocity = "BodyMover", BodyGyro = "BodyMover",
        BodyPosition = "BodyMover", BodyThrust = "BodyMover",
        BodyAngularVelocity = "BodyMover", RocketPropulsion = "BodyMover",
        Light = "Instance", PointLight = "Light", SpotLight = "Light",
        SurfaceLight = "Light",
        PostEffect = "Instance", BloomEffect = "PostEffect", BlurEffect = "PostEffect",
        ColorCorrectionEffect = "PostEffect", SunRaysEffect = "PostEffect",
        DepthOfFieldEffect = "PostEffect",
        Sky = "Instance", Atmosphere = "Instance", Clouds = "Instance",
        FaceInstance = "Instance", Decal = "FaceInstance", Texture = "Decal",
        Sound = "Instance", SoundEffect = "Instance", SoundGroup = "Instance",
        Beam = "Instance", Trail = "Instance", ParticleEmitter = "Instance",
        Explosion = "Instance", Fire = "Instance", Smoke = "Instance",
        Sparkles = "Instance", Debris = "Instance",
        RemoteEvent = "Instance", RemoteFunction = "Instance",
        UnreliableRemoteEvent = "Instance", BindableEvent = "Instance",
        BindableFunction = "Instance",
        TextChatService = "Instance", TextChannel = "Instance", TextSource = "Instance",
        TextChatCommand = "Instance", TextChatMessageProperties = "Instance",
        DataModel = "Instance", ServiceProvider = "Instance",
    }
    for k, v in pairs(more) do CLASS_PARENT[k] = v end
end

-- classes that IsA() should treat as the same thing
local CLASS_ALIAS = { PBInstance = "PVInstance", BasePart = "BasePart" }

-- === signal member detection ============================================
local SIGNAL_NAMES = {}
for _, n in ipairs({
    "MouseButton1Click", "MouseButton1Down", "MouseButton1Up", "MouseButton2Click",
    "MouseButton2Down", "MouseButton2Up", "MouseEnter", "MouseLeave", "MouseMoved",
    "MouseWheelForward", "MouseWheelBackward", "MouseDrag", "MouseHoverEnter",
    "MouseHoverLeave", "InputBegan", "InputEnded", "InputChanged", "FocusLost",
    "Focused", "Touched", "TouchEnded", "TouchTap", "TouchMoved", "ChildAdded",
    "ChildRemoved", "DescendantAdding", "DescendantRemoving", "AncestryChanged",
    "Died", "HealthChanged", "StateChanged", "Chatted", "CharacterAdded",
    "CharacterRemoving", "CharacterAppearanceLoaded", "PlayerAdded",
    "PlayerRemoving", "Heartbeat", "RenderStepped", "Stepped", "PreRender",
    "PreSimulation", "PostSimulation", "PreAnimation", "Activated", "Deactivated",
    "Equipped", "Unequipped", "PromptButtonHoldBegan", "PromptButtonHoldEnded",
    "PromptShown", "PromptHidden", "TriggerEnded", "Triggered", "TextBoxFocused",
    "TextBoxFocusReleased", "MessageReceived", "OnIncomingMessage",
    "CaptureBegan", "CaptureEnded", "Loaded", "Stopped", "Ended", "Began",
    "KeyDown", "KeyUp", "Button1Down", "Button1Up", "Button2Down", "Button2Up",
    "Move", "Idle", "WheelForward", "WheelBackward", "Completed",
    "DidLoop", "Changed", "Destroying", "SelectionChanged",
    "WindowFocused", "WindowFocusReleased", "JumpRequest", "GraphicsQualityChangeRequest",
    "OnClientEvent", "OnServerEvent",
    "TeleportInitFailed", "MemoryUsage", "Blocked", "Reached", "Paused",
    "Resumed", "PlaybackStateChanged", "PromptTriggered",
    -- Humanoid state signals and the player idle signal: connected by orbit,
    -- freezeanims, antiafk and the sit/stand features.
    "Seated", "Idled", "Jumping", "Running", "Climbing", "FreeFalling",
    "GettingUp", "PlatformStanding", "Swimming", "FallingDown", "Ragdoll",
    "MoveToFinished", "AnimationPlayed", "Strafing", "StateEnabledChanged",
    "ApplyDescription", "EmoteChanged", "OnTeleport",
}) do SIGNAL_NAMES[n] = true end

-- Roblox names several signals "On<Something>" (OnTeleport, OnClientEvent,
-- OnIncomingMessage); treat that prefix as a signal too.
local function isOnSignalName(k)
    return #k > 3 and string.sub(k, 1, 2) == "On"
        and string.match(string.sub(k, 3, 3), "%u") ~= nil
end

local SIGNAL_SUFFIXES = {
    "Changed", "Began", "Ended", "Added", "Removing", "Removed", "Clicked",
    "Click", "Fired", "Received", "Signal", "Event", "Died", "Touched",
    "Triggered", "Requested", "Completed", "Stopped", "Loaded", "Destroying",
}

local function isSignalName(k)
    if SIGNAL_NAMES[k] then return true end
    if isOnSignalName(k) then return true end
    local len = #k
    for i = 1, #SIGNAL_SUFFIXES do
        local s = SIGNAL_SUFFIXES[i]
        if len >= #s and k:sub(len - #s + 1) == s then return true end
    end
    return false
end

-- === "does this name look like a method?" ================================
-- Used only for members that are neither a known property nor a signal.  A
-- prefix match also requires the next character to be upper case, so
-- `Settings` is not mistaken for a Set* method and `CanCollide` (Can*) is
-- excluded outright -- known properties are additionally covered by DEFAULTS.
local METHOD_PREFIX = {
    "Get", "Set", "Is", "Find", "Wait", "Add", "Remove", "Clear", "To", "From",
    "Fire", "Invoke", "Load", "Unload", "Update", "Apply", "Toggle", "Enable",
    "Disable", "Break", "Make", "Create", "Compute", "Bind", "Unbind", "Tween",
    "Adjust", "Rotate", "Translate", "Send", "Kick", "Query", "Raycast", "Pivot",
    "Take", "Give", "Request", "Register", "Unregister", "Reset", "Refresh",
    "Select", "Capture", "Release", "Emit", "Change", "Replace", "Insert",
    "Filter", "Build", "Preload", "Prompt", "Teleport", "Generate", "Draw",
    "Show", "Hide", "Open", "Close", "Start", "Stop", "Init", "Do", "Run",
    "Equip", "Unequip", "Activate", "Deactivate", "Attach", "Detach", "Weld",
    "Scale", "Notify", "Destroy", "Clone", "Pause", "Resume", "Cancel",
    "Confirm", "Subscribe", "Unsubscribe", "Pan", "Zoom", "Step", "Unpause",
    "Play",
}
local METHOD_EXACT = {}
for _, n in ipairs({
    "Destroy", "Clone", "Remove", "Play", "Stop", "Pause", "Resume", "Cancel",
    "Confirm", "Reset", "Refresh", "Update", "Fire", "Invoke", "Emit", "Step",
    "Activate", "Deactivate", "Equip", "Unequip", "Enable", "Disable", "Toggle",
    "Load", "Unload", "Notify", "Show", "Hide", "Open", "Close", "Start", "Run",
    "Init", "Draw", "Clear", "Kick", "Send", "Query", "Raycast", "Compute",
    "Bind", "Unbind", "Tween", "Adjust", "Apply", "Break", "Make", "Create",
    "Build", "Preload", "Prompt", "Teleport", "Generate", "Insert", "Filter",
    "Replace", "Take", "Give", "Request", "Register", "Unregister", "Capture",
    "Release", "Attach", "Detach", "Weld", "Subscribe", "Unsubscribe", "Pan",
    "Zoom", "Wait", "Find", "Add", "Set", "Get",
}) do METHOD_EXACT[n] = true end

local function looksLikeMethod(k)
    if type(k) ~= "string" or k == "" then return false end
    local first = k:sub(1, 1)
    if first:lower() == first then return false end     -- must start upper case
    if METHOD_EXACT[k] then return true end
    if #k > 5 and k:sub(-5) == "Async" then return true end
    for i = 1, #METHOD_PREFIX do
        local p = METHOD_PREFIX[i]
        local n = #p
        if #k > n and k:sub(1, n) == p then
            local nxt = k:sub(n + 1, n + 1)
            if nxt:lower() ~= nxt then return true end   -- next char upper case
        end
    end
    return false
end

-- === library =============================================================
function Instance.newLibrary(ctx)
    local sched = ctx.scheduler
    local Signal = ctx.signal
    local D = ctx.datatypes
    local output = ctx.output or {}
    local options = ctx.options or {}
    local Enum, V3, CF, C3, UD2, UD, V2 =
        D.Enum, D.Vector3, D.CFrame, D.Color3, D.UDim2, D.UDim, D.Vector2

    output.unimplemented = output.unimplemented or {}

    local lib = {}
    local registry = setmetatable({}, { __mode = "k" })
    local instMt = { __type = "Instance" }
    local classChains = {}
    local baseMethods, classMethods, classDefaults = {}, {}, {}
    local DEFAULTS

    lib.classHierarchy = CLASS_PARENT
    lib.classMethods = classMethods
    lib.classDefaults = classDefaults
    lib.signalNames = SIGNAL_NAMES
    lib.looksLikeMethod = looksLikeMethod
    lib.isSignalName = isSignalName

    local function chainFor(className)
        local cached = classChains[className]
        if cached then return cached end
        local chain, set = {}, {}
        local c = className
        local guard = 0
        while c and guard < 64 do
            chain[#chain + 1] = c
            set[c] = true
            if CLASS_ALIAS[c] then set[CLASS_ALIAS[c]] = true end
            if c == "Instance" then break end
            c = CLASS_PARENT[c]
            guard = guard + 1
        end
        if not set.Instance then
            chain[#chain + 1] = "Instance"
            set.Instance = true
        end
        local entry = { chain = chain, set = set }
        classChains[className] = entry
        return entry
    end
    lib.chainFor = chainFor

    function lib.is(v) return registry[v] ~= nil end
    function lib.data(v) return registry[v] end
    function lib.all()
        local out = {}
        for obj in pairs(registry) do out[#out + 1] = obj end
        return out
    end

    -- === defaults ========================================================
    -- Functions are called on read so every instance gets its own value.
    DEFAULTS = {
        Name = "", Text = "", PlaceholderText = "", Visible = true, Active = false,
        Selectable = false, Selected = false, Modal = false, Archivable = true,
        Transparency = 0, ZIndex = 0, LayoutOrder = 0, DisplayOrder = 0,
        Enabled = true, Value = 0, Disabled = false, Locked = false,
        Health = 100, MaxHealth = 100, WalkSpeed = 16, JumpPower = 50,
        JumpHeight = 7.2, HipHeight = 2, MaxSlopeAngle = 89, AutoRotate = true,
        UseJumpPower = true, RequiresNeck = true, BreakJointsOnDeath = true,
        PlatformStand = false, Sit = false, Jump = false, EvaluateStateMachine = true,
        Anchored = false, CanCollide = true, CanQuery = true, CanTouch = true,
        Massless = false, CastShadow = true, Reflectance = 0, Mass = 1,
        CollisionGroup = "Default", LocalTransparencyModifier = 0,
        Rotation = 0, BackgroundTransparency = 0, BorderSizePixel = 1,
        ClipsDescendants = false, AutoButtonColor = true, TextSize = 14,
        TextWrapped = false, TextScaled = false, TextTransparency = 0,
        TextStrokeTransparency = 1, RichText = false, MultiLine = false,
        TextEditable = true, ClearTextOnFocus = true, ResetOnSpawn = true,
        Image = "", ImageTransparency = 0, SoundId = "", Volume = 0.5,
        Playing = false, Looped = false, TimePosition = 0, PlaybackSpeed = 1,
        IsPlaying = false, IsPaused = false, IsLoaded = true, IsGrounded = true,
        PlayOnRemove = false, RollOffMaxDistance = 10000, Brightness = 1,
        Range = 8, Shadows = false, Texture = "", Thickness = 1, Scale = 1,
        Speed = 1, Length = 1, Weight = 1, WeightCurrent = 1, Priority = 0,
        AnimationId = "", ActionText = "Interact", ObjectText = "", HoldDuration = 0,
        MaxActivationDistance = 32, RequiresLineOfSight = false,
        RequiresHandle = true, CanBeDropped = true, ToolTip = "",
        AlwaysOnTop = false, LightInfluence = 0, ScrollBarThickness = 12,
        ScrollingEnabled = true, FieldOfView = 70, HeadLocked = true,
        NearPlaneZ = -0.5, Gravity = 196.2, StreamingEnabled = false,
        AutoAssignable = true, Neutral = true, AccountAge = 365,
        FilterDescendantsInstances = false, Bold = false, Border = false,
        NumPlayers = 0, MaxPlayers = 12, PreferredPlayers = 12,
        RequestQueueSize = 0, DistributedGameTime = 0, StartCorner = false,
        Border = false,
        TeamColor = function() return D.BrickColor.new("White") end,
        ChatVersion = function() return Enum.ChatVersion.TextChatService end,
        FilterDescendantsInstances = function() return {} end,
        -- datatype-valued defaults
        Position = function() return V3.new(0, 0, 0) end,
        Size = function() return V3.new(1, 1, 1) end,
        CFrame = function() return CF.new() end,
        Focus = function() return CF.new() end,
        Orientation = function() return V3.new(0, 0, 0) end,
        Velocity = function() return V3.new(0, 0, 0) end,
        RotVelocity = function() return V3.new(0, 0, 0) end,
        AssemblyLinearVelocity = function() return V3.new(0, 0, 0) end,
        MoveDirection = function() return V3.new(0, 0, 0) end,
        WalkToPoint = function() return V3.new(0, 0, 0) end,
        PivotOffset = function() return CF.new() end,
        Color = function() return C3.fromRGB(163, 162, 165) end,
        Color3 = function() return C3.new(1, 1, 1) end,
        TextColor3 = function() return C3.new(0, 0, 0) end,
        BackgroundColor3 = function() return C3.new(1, 1, 1) end,
        BorderColor3 = function() return C3.fromRGB(27, 42, 53) end,
        ImageColor3 = function() return C3.new(1, 1, 1) end,
        TextStrokeColor3 = function() return C3.new(0, 0, 0) end,
        FillColor = function() return C3.new(1, 1, 1) end,
        OutlineColor = function() return C3.new(1, 1, 1) end,
        AnchorPoint = function() return V2.new(0, 0) end,
        AbsolutePosition = function() return V2.new(0, 0) end,
        AbsoluteSize = function() return V2.new(100, 100) end,
        -- UIListLayout/UIGridLayout report the size of their laid-out
        -- content; the command list reads it to size its canvas.
        AbsoluteContentSize = function() return V2.new(100, 100) end,
        CanvasPosition = function() return V2.new(0, 0) end,
        Offset = function() return V2.new(0, 0) end,
        CanvasSize = function() return UD2.new(0, 0, 0, 0) end,
        CornerRadius = function() return UD.new(0, 8) end,
        Padding = function() return UD.new(0, 0) end,
        Material = function() return Enum.Material.Plastic end,
        FloorMaterial = function() return Enum.Material.Plastic end,
        Font = function() return Enum.Font.SourceSans end,
        RigType = function() return Enum.HumanoidRigType.R15 end,
        Face = function() return Enum.NormalId.Front end,
        ScaleType = function() return Enum.ScaleType.Stretch end,
        ApplyStrokeMode = function() return Enum.ApplyStrokeMode.Contextual end,
        AutomaticSize = function() return Enum.AutomaticSize.None end,
        SizeConstraint = function() return Enum.SizeConstraint.RelativeXY end,
        ZIndexBehavior = function() return Enum.ZIndexBehavior.Sibling end,
        TextXAlignment = function() return Enum.TextXAlignment.Center end,
        TextYAlignment = function() return Enum.TextYAlignment.Center end,
        VerticalScrollBarInset = function() return Enum.ScrollBarInset.None end,
        FillDirection = function() return Enum.FillDirection.Vertical end,
        SortOrder = function() return Enum.SortOrder.LayoutOrder end,
        HorizontalAlignment = function() return Enum.HorizontalAlignment.Center end,
        VerticalAlignment = function() return Enum.VerticalAlignment.Top end,
        CameraType = function() return Enum.CameraType.Custom end,
        DepthMode = function() return Enum.HighlightDepthMode.AlwaysOnTop end,
        Style = function() return Enum.ProximityPromptStyle.Default end,
        KeyboardKeyCode = function() return Enum.KeyCode.E end,
        ViewportSize = function() return V2.new(1920, 1080) end,
    }
    lib.defaults = DEFAULTS

    -- class specific defaults win over the generic table above
    classDefaults.GuiObject = {
        Position = function() return UD2.new(0, 0, 0, 0) end,
        Size = function() return UD2.new(0, 100, 0, 100) end,
        Visible = true, Active = false, ZIndex = 1,
    }
    classDefaults.GuiBase2d = {
        AbsolutePosition = function() return V2.new(0, 0) end,
        AbsoluteSize = function() return V2.new(100, 100) end,
    }
    classDefaults.ScrollingFrame = {
        CanvasSize = function() return UD2.new(0, 0, 2, 0) end,
        AutomaticCanvasSize = function() return Enum.AutomaticSize.None end,
    }
    classDefaults.StringValue = { Value = "" }
    classDefaults.BoolValue = { Value = false }
    classDefaults.CFrameValue = { Value = function() return CF.new() end }
    classDefaults.Vector3Value = { Value = function() return V3.new() end }
    classDefaults.Color3Value = { Value = function() return C3.new() end }
    classDefaults.Camera = {
        ViewportSize = function() return V2.new(1920, 1080) end,
        FieldOfView = 70,
    }
    classDefaults.UIScale = { Scale = 1 }
    classDefaults.Attachment = {
        Position = function() return V3.new(0, 0, 0) end,
        WorldPosition = function() return V3.new(0, 0, 0) end,
    }
    classDefaults.Player = { DisplayName = "", UserId = 0 }

    -- === unimplemented member bookkeeping ================================
    local unknownCache = {}
    local function recordUnimplemented(className, name)
        local key = className .. "." .. name
        local list = output.unimplemented
        local entry = list[key]
        if entry then
            entry.count = entry.count + 1
            return
        end
        entry = { className = className, name = name, count = 1, key = key }
        list[key] = entry
        list[#list + 1] = entry
    end
    lib.recordUnimplemented = recordUnimplemented

    local function unknownMethod(className, name)
        local key = className .. "." .. name
        local fn = unknownCache[key]
        if fn then return fn end
        fn = function()
            recordUnimplemented(className, name)
            return nil
        end
        unknownCache[key] = fn
        return fn
    end

    -- === signals =========================================================
    local function getSignal(d, name)
        local s = d.signals[name]
        if not s then
            s = Signal.new(d.className .. "." .. name, sched)
            d.signals[name] = s
        end
        return s
    end

    local function fireSignal(d, name, ...)
        local s = d.signals[name]
        if s then s:Fire(...) end
    end

    -- === parenting =======================================================
    local function descendantsOf(inst, out)
        out = out or {}
        local d = registry[inst]
        for i = 1, #d.children do
            local c = d.children[i]
            out[#out + 1] = c
            descendantsOf(c, out)
        end
        return out
    end

    local function eachAncestor(inst, fn)
        local d = registry[inst]
        local p = d.parent
        local guard = 0
        while p and guard < 512 do
            fn(p)
            local pd = registry[p]
            if not pd then break end
            p = pd.parent
            guard = guard + 1
        end
    end

    local function setParent(inst, newParent)
        local d = registry[inst]
        local old = d.parent
        if old == newParent then return end
        if newParent ~= nil and not registry[newParent] then
            error("Attempt to set Parent to a non-Instance value", 3)
        end
        if newParent == inst then error("Attempt to set an instance as its own parent", 3) end

        local moving = { inst }
        descendantsOf(inst, moving)

        if old then
            local od = registry[old]
            if od then
                for i = 1, #od.children do
                    if od.children[i] == inst then
                        table.remove(od.children, i)
                        break
                    end
                end
                fireSignal(od, "ChildRemoved", inst)
                eachAncestor(inst, function(a)
                    local ad = registry[a]
                    for j = 1, #moving do fireSignal(ad, "DescendantRemoving", moving[j]) end
                end)
                fireSignal(od, "DescendantRemoving", inst)
            end
        end

        d.parent = newParent

        if newParent then
            local nd = registry[newParent]
            nd.children[#nd.children + 1] = inst
            fireSignal(nd, "ChildAdded", inst)
            local a = newParent
            local guard = 0
            while a and guard < 512 do
                local ad = registry[a]
                if not ad then break end
                for j = 1, #moving do fireSignal(ad, "DescendantAdding", moving[j]) end
                a = ad.parent
                guard = guard + 1
            end
        end

        fireSignal(d, "AncestryChanged", inst, newParent)
        for j = 2, #moving do
            local md = registry[moving[j]]
            fireSignal(md, "AncestryChanged", moving[j], registry[moving[j]].parent)
        end
        fireSignal(d, "Changed", "Parent")
        local ps = d.propSignals.Parent
        if ps then ps:Fire() end
    end
    lib.setParent = setParent

    -- === property access =================================================
    local function resolveDefault(v)
        if type(v) == "function" then return v() end
        return v
    end

    local function findChildByName(d, name)
        local children = d.children
        for i = 1, #children do
            local cd = registry[children[i]]
            if cd and cd.props.Name == name then return children[i] end
        end
        return nil
    end

    instMt.__index = function(self, k)
        local d = registry[self]
        if d == nil then return nil end
        local v = d.props[k]
        if v ~= nil then return v end
        if k == "Parent" then return d.parent end
        if k == "ClassName" then return d.className end
        if d.getters then
            local g = d.getters[k]
            if g then return g(self) end
        end
        if d.methods then
            local m = d.methods[k]
            if m ~= nil then return m end
        end
        local chain = d.chain
        for i = 1, #chain do
            local t = classMethods[chain[i]]
            if t then
                local m = t[k]
                if m ~= nil then return m end
            end
        end
        local bm = baseMethods[k]
        if bm ~= nil then return bm end
        local sig = d.signals[k]
        if sig ~= nil then return sig end
        if isSignalName(k) then return getSignal(d, k) end
        local child = findChildByName(d, k)
        if child ~= nil then return child end
        for i = 1, #chain do
            local t = classDefaults[chain[i]]
            if t then
                local dv = t[k]
                if dv ~= nil then return resolveDefault(dv) end
            end
        end
        local dv = DEFAULTS[k]
        if dv ~= nil then return resolveDefault(dv) end
        if looksLikeMethod(k) then return unknownMethod(d.className, k) end
        return nil
    end

    instMt.__newindex = function(self, k, v)
        local d = registry[self]
        if d == nil then return end
        if d.destroyed then return end          -- Roblox locks destroyed instances
        if k == "Parent" then return setParent(self, v) end
        if k == "ClassName" then return end     -- read-only in Roblox
        local props = d.props
        if props[k] == v then
            -- still fire for datatypes compared by value, but skip identical scalars
            local t = type(v)
            if t == "number" or t == "string" or t == "boolean" or v == nil then return end
        end
        props[k] = v
        -- keep Position/CFrame in sync for part-like instances
        if k == "CFrame" and D.isCFrame(v) then
            props.Position = v.Position
        elseif k == "Position" and D.isVector3(v) then
            local cf = props.CFrame
            if cf == nil or D.isCFrame(cf) then props.CFrame = CF.new(v.X, v.Y, v.Z) end
        elseif k == "Health" and d.set.Humanoid then
            fireSignal(d, "HealthChanged", v)
            if type(v) == "number" and v <= 0 then fireSignal(d, "Died") end
        end
        local ps = d.propSignals[k]
        if ps then ps:Fire() end
        fireSignal(d, "Changed", k)
    end

    instMt.__tostring = function(self)
        local d = registry[self]
        if not d then return "Instance" end
        return tostring(d.props.Name)
    end

    -- === base methods (available on every instance) =======================
    local function isA(self, className)
        local d = registry[self]
        if not d or type(className) ~= "string" then return false end
        if d.set[className] then return true end
        if CLASS_ALIAS[className] and d.set[CLASS_ALIAS[className]] then return true end
        return false
    end
    baseMethods.IsA = isA
    baseMethods.isA = isA

    function baseMethods.GetChildren(self)
        local d = registry[self]
        local out = {}
        for i = 1, #d.children do out[i] = d.children[i] end
        return out
    end
    baseMethods.children = baseMethods.GetChildren

    function baseMethods.GetDescendants(self) return descendantsOf(self) end

    function baseMethods.FindFirstChild(self, name, recursive)
        local d = registry[self]
        if not d then return nil end
        name = tostring(name)
        local direct = findChildByName(d, name)
        if direct then return direct end
        if recursive then
            for i = 1, #d.children do
                local found = baseMethods.FindFirstChild(d.children[i], name, true)
                if found then return found end
            end
        end
        return nil
    end
    baseMethods.findFirstChild = baseMethods.FindFirstChild

    function baseMethods.FindFirstChildOfClass(self, className, recursive)
        local d = registry[self]
        for i = 1, #d.children do
            local c = d.children[i]
            if registry[c].className == className then return c end
        end
        if recursive then
            for i = 1, #d.children do
                local f = baseMethods.FindFirstChildOfClass(d.children[i], className, true)
                if f then return f end
            end
        end
        return nil
    end

    function baseMethods.FindFirstChildWhichIsA(self, className, recursive)
        local d = registry[self]
        for i = 1, #d.children do
            if isA(d.children[i], className) then return d.children[i] end
        end
        if recursive then
            for i = 1, #d.children do
                local f = baseMethods.FindFirstChildWhichIsA(d.children[i], className, true)
                if f then return f end
            end
        end
        return nil
    end

    function baseMethods.FindFirstDescendant(self, name)
        return baseMethods.FindFirstChild(self, name, true)
    end

    function baseMethods.FindFirstAncestor(self, name)
        local found
        eachAncestor(self, function(a)
            if not found and registry[a].props.Name == name then found = a end
        end)
        return found
    end

    function baseMethods.FindFirstAncestorOfClass(self, className)
        local found
        eachAncestor(self, function(a)
            if not found and registry[a].className == className then found = a end
        end)
        return found
    end

    function baseMethods.FindFirstAncestorWhichIsA(self, className)
        local found
        eachAncestor(self, function(a)
            if not found and isA(a, className) then found = a end
        end)
        return found
    end

    -- Polls through the scheduler, so it also works when called from the main
    -- thread (there wait() advances the virtual clock instead of yielding).
    function baseMethods.WaitForChild(self, name, timeout)
        name = tostring(name)
        local existing = baseMethods.FindFirstChild(self, name)
        if existing then return existing end
        local budget = tonumber(timeout) or (options.waitForChildTimeout or 30)
        local deadline = sched.clock() + budget
        local warned = false
        while sched.clock() < deadline do
            sched.wait(1 / 60)
            local child = baseMethods.FindFirstChild(self, name)
            if child then return child end
            local d = registry[self]
            if d and d.destroyed then return nil end
            if not warned and not timeout and sched.clock() > 5 + deadline - budget then
                warned = true
                if output.warns then
                    output.warns[#output.warns + 1] = "Infinite yield possible on '"
                        .. tostring(self) .. ":WaitForChild(\"" .. name .. "\")'"
                end
            end
        end
        if not timeout then
            recordUnimplemented(registry[self].className, "WaitForChild:" .. name)
        end
        return nil
    end
    baseMethods.waitForChild = baseMethods.WaitForChild

    function baseMethods.IsDescendantOf(self, other)
        local found = false
        eachAncestor(self, function(a) if a == other then found = true end end)
        return found
    end

    function baseMethods.IsAncestorOf(self, other)
        if not registry[other] then return false end
        return baseMethods.IsDescendantOf(other, self)
    end

    function baseMethods.GetFullName(self)
        local parts = {}
        local cur = self
        local guard = 0
        while cur and guard < 512 do
            local d = registry[cur]
            if not d then break end
            if d.className == "DataModel" then break end
            table.insert(parts, 1, tostring(d.props.Name))
            cur = d.parent
            guard = guard + 1
        end
        return table.concat(parts, ".")
    end

    function baseMethods.GetPropertyChangedSignal(self, prop)
        local d = registry[self]
        prop = tostring(prop)
        local s = d.propSignals[prop]
        if not s then
            s = Signal.new(d.className .. "." .. prop .. "Changed", sched)
            d.propSignals[prop] = s
        end
        return s
    end

    function baseMethods.GetAttributeChangedSignal(self, name)
        local d = registry[self]
        name = tostring(name)
        local s = d.attributeSignals[name]
        if not s then
            s = Signal.new("Attribute." .. name, sched)
            d.attributeSignals[name] = s
        end
        return s
    end

    function baseMethods.SetAttribute(self, name, value)
        local d = registry[self]
        if d.destroyed then return end
        d.attributes[tostring(name)] = value
        local s = d.attributeSignals[tostring(name)]
        if s then s:Fire(value) end
        fireSignal(d, "AttributeChanged", tostring(name))
    end

    function baseMethods.GetAttribute(self, name)
        return registry[self].attributes[tostring(name)]
    end

    function baseMethods.GetAttributes(self)
        local out = {}
        for k, v in pairs(registry[self].attributes) do out[k] = v end
        return out
    end

    function baseMethods.ClearAllChildren(self)
        local d = registry[self]
        local kids = {}
        for i = 1, #d.children do kids[i] = d.children[i] end
        for i = 1, #kids do baseMethods.Destroy(kids[i]) end
    end

    function baseMethods.Destroy(self)
        local d = registry[self]
        if not d or d.destroyed then return end
        local kids = {}
        for i = 1, #d.children do kids[i] = d.children[i] end
        for i = 1, #kids do baseMethods.Destroy(kids[i]) end
        fireSignal(d, "Destroying")
        setParent(self, nil)
        d.destroyed = true
        d.children = {}
        for _, s in pairs(d.signals) do s:DisconnectAll() end
        for _, s in pairs(d.propSignals) do s:DisconnectAll() end
        for _, s in pairs(d.attributeSignals) do s:DisconnectAll() end
    end
    baseMethods.destroy = baseMethods.Destroy

    function baseMethods.Remove(self)          -- deprecated Roblox API
        setParent(self, nil)
    end

    function baseMethods.GetDebugId(self)
        local d = registry[self]
        if not d.debugId then
            d.debugId = string.format("%08X", math.random(0, 2 ^ 30))
        end
        return d.debugId
    end

    function baseMethods.AddTag(self, tag)
        local d = registry[self]
        d.tags[tostring(tag)] = true
    end
    function baseMethods.RemoveTag(self, tag) registry[self].tags[tostring(tag)] = nil end
    function baseMethods.HasTag(self, tag) return registry[self].tags[tostring(tag)] == true end
    function baseMethods.GetTags(self)
        local out = {}
        for t in pairs(registry[self].tags) do out[#out + 1] = t end
        table.sort(out)
        return out
    end

    -- Tweens apply their target immediately; the callback runs on the next step.
    local function tweenApply(self, props, args)
        local d = registry[self]
        if d.destroyed then return true end
        for k, v in pairs(props) do self[k] = v end
        local cb
        for i = 1, #args do
            if type(args[i]) == "function" then cb = args[i] end
        end
        if cb then sched.delay(0, cb, Enum.TweenStatus.Completed) end
        return true
    end

    function baseMethods.TweenPosition(self, endPos, ...)
        return tweenApply(self, { Position = endPos }, { ... })
    end
    function baseMethods.TweenSize(self, endSize, ...)
        return tweenApply(self, { Size = endSize }, { ... })
    end
    function baseMethods.TweenSizeAndPosition(self, endSize, endPos, ...)
        return tweenApply(self, { Size = endSize, Position = endPos }, { ... })
    end

    -- model / part helpers, permissive but non-erroring
    function baseMethods.GetPivot(self)
        local props = registry[self].props
        if props.PrimaryPart then return props.PrimaryPart.CFrame end
        return props.CFrame or CF.new()
    end
    function baseMethods.PivotTo(self, cf)
        local props = registry[self].props
        if props.PrimaryPart then props.PrimaryPart.CFrame = cf end
        self.CFrame = cf
        return nil
    end
    function baseMethods.SetPrimaryPartCFrame(self, cf) return baseMethods.PivotTo(self, cf) end
    function baseMethods.GetPrimaryPartCFrame(self) return baseMethods.GetPivot(self) end
    function baseMethods.GetModelCFrame(self) return baseMethods.GetPivot(self) end
    function baseMethods.MoveTo(self, pos)
        if D.isVector3(pos) then baseMethods.PivotTo(self, CF.new(pos.X, pos.Y, pos.Z)) end
        return nil
    end
    function baseMethods.TranslateBy(self, delta)
        local cf = baseMethods.GetPivot(self)
        return baseMethods.PivotTo(self, cf + delta)
    end
    function baseMethods.GetExtentsSize(self) return V3.new(4, 5, 1) end
    function baseMethods.GetBoundingBox(self) return baseMethods.GetPivot(self), V3.new(4, 5, 1) end
    function baseMethods.GetScale(self) return registry[self].props.Scale or 1 end
    function baseMethods.ScaleTo(self, scale) self.Scale = scale end
    function baseMethods.BreakJoints(self) return nil end
    function baseMethods.MakeJoints(self) return nil end
    function baseMethods.GetMass(self) return 1 end
    function baseMethods.GetTouchingParts(self) return {} end
    function baseMethods.GetConnectedParts(self) return {} end
    function baseMethods.GetJoints(self) return {} end
    function baseMethods.GetRootPart(self)
        return baseMethods.FindFirstChild(self, "HumanoidRootPart")
    end
    function baseMethods.GetNetworkOwner(self) return nil end
    function baseMethods.SetNetworkOwner(self) return nil end
    function baseMethods.SetNetworkOwnershipAuto(self) return nil end
    function baseMethods.CanSetNetworkOwnership(self) return true end
    function baseMethods.ApplyImpulse(self) return nil end
    function baseMethods.ApplyAngularImpulse(self) return nil end
    function baseMethods.Resize(self) return nil end
    function baseMethods.GetVelocityAtPosition(self) return V3.new() end
    function baseMethods.GetRenderCFrame(self) return baseMethods.GetPivot(self) end

    -- gui / sound / animation
    function baseMethods.CaptureFocus(self) registry[self].focused = true end
    function baseMethods.ReleaseFocus(self)
        registry[self].focused = false
        fireSignal(registry[self], "FocusLost", "", true)
    end
    function baseMethods.IsFocused(self) return registry[self].focused == true end
    function baseMethods.Play(self)
        self.Playing = true
        self.IsPlaying = true
        return nil
    end
    function baseMethods.Stop(self)
        self.Playing = false
        self.IsPlaying = false
        fireSignal(registry[self], "Stopped")
        return nil
    end
    function baseMethods.Pause(self) self.Playing = false end
    function baseMethods.Resume(self) self.Playing = true end
    function baseMethods.AdjustSpeed(self, speed) self.Speed = speed or 1 end
    function baseMethods.AdjustWeight(self, weight) self.WeightCurrent = weight or 1 end
    function baseMethods.GetTimeOfKeyframe(self) return 0 end
    function baseMethods.GetMarkerReachedSignal(self, name)
        return baseMethods.GetPropertyChangedSignal(self, "Marker." .. tostring(name))
    end

    -- remotes / bindables: record instead of replicating
    local function recordRemote(self, kind, ...)
        output.remotes = output.remotes or {}
        output.remotes[#output.remotes + 1] = {
            instance = self, path = baseMethods.GetFullName(self), kind = kind,
            args = { n = select("#", ...), ... },
        }
    end
    function baseMethods.FireServer(self, ...) recordRemote(self, "FireServer", ...) end
    function baseMethods.FireAllClients(self, ...) recordRemote(self, "FireAllClients", ...) end
    function baseMethods.FireClient(self, ...) recordRemote(self, "FireClient", ...) end
    function baseMethods.InvokeServer(self, ...)
        recordRemote(self, "InvokeServer", ...)
        return nil
    end
    function baseMethods.InvokeClient(self, ...)
        recordRemote(self, "InvokeClient", ...)
        return nil
    end
    function baseMethods.Fire(self, ...)
        recordRemote(self, "Fire", ...)
        fireSignal(registry[self], "Event", ...)
    end
    function baseMethods.Invoke(self, ...)
        recordRemote(self, "Invoke", ...)
        return nil
    end

    function baseMethods.Clone(self)
        local d = registry[self]
        if d.props.Archivable == false then return nil end
        local copy = lib.new(d.className)
        local cd = registry[copy]
        for k, v in pairs(d.props) do cd.props[k] = v end
        for k, v in pairs(d.attributes) do cd.attributes[k] = v end
        for k in pairs(d.tags) do cd.tags[k] = true end
        if d.methods then
            cd.methods = {}
            for k, v in pairs(d.methods) do cd.methods[k] = v end
        end
        if d.getters then
            cd.getters = {}
            for k, v in pairs(d.getters) do cd.getters[k] = v end
        end
        for i = 1, #d.children do
            local child = baseMethods.Clone(d.children[i])
            if child then setParent(child, copy) end
        end
        return copy
    end
    baseMethods.clone = baseMethods.Clone

    -- === class specific methods ==========================================
    local function newTrack(anim)
        local track = lib.new("AnimationTrack")
        track.Name = "AnimationTrack"
        track.Animation = anim
        track.Length = 1
        track.Speed = 1
        track.IsPlaying = false
        track.Looped = false
        track.Priority = Enum.AnimationPriority.Core
        return track
    end

    classMethods.Humanoid = {
        GetState = function(self)
            return registry[self].props.State or Enum.HumanoidStateType.Running
        end,
        ChangeState = function(self, state)
            local d = registry[self]
            local old = d.props.State or Enum.HumanoidStateType.Running
            d.props.State = state
            fireSignal(d, "StateChanged", old, state)
        end,
        SetStateEnabled = function(self, state, enabled)
            local d = registry[self]
            d.stateEnabled = d.stateEnabled or {}
            local name = type(state) == "table" and state.Name or tostring(state)
            d.stateEnabled[name] = enabled and true or false
        end,
        GetStateEnabled = function(self, state)
            local d = registry[self]
            local name = type(state) == "table" and state.Name or tostring(state)
            if d.stateEnabled and d.stateEnabled[name] ~= nil then
                return d.stateEnabled[name]
            end
            return true
        end,
        MoveTo = function(self, pos, part)
            local d = registry[self]
            d.props.WalkToPoint = pos
            d.props.WalkToPart = part
            return nil
        end,
        Move = function(self, dir) self.MoveDirection = dir end,
        TakeDamage = function(self, amount)
            local h = registry[self].props.Health or 100
            local newHealth = h - (tonumber(amount) or 0)
            if newHealth < 0 then newHealth = 0 end
            self.Health = newHealth
        end,
        LoadAnimation = function(self, anim)
            local d = registry[self]
            d.tracks = d.tracks or {}
            local track = newTrack(anim)
            d.tracks[#d.tracks + 1] = track
            return track
        end,
        GetPlayingAnimationTracks = function(self)
            local d = registry[self]
            local out = {}
            for _, t in ipairs(d.tracks or {}) do
                if t.IsPlaying then out[#out + 1] = t end
            end
            return out
        end,
        GetAccessories = function(self)
            local parent = registry[self].parent
            local out = {}
            if parent then
                for _, c in ipairs(baseMethods.GetChildren(parent)) do
                    if isA(c, "Accoutrement") then out[#out + 1] = c end
                end
            end
            return out
        end,
        RemoveAccessories = function(self)
            for _, a in ipairs(classMethods.Humanoid.GetAccessories(self)) do
                baseMethods.Destroy(a)
            end
        end,
        AddAccessory = function(self, accessory)
            local parent = registry[self].parent
            if parent and registry[accessory] then setParent(accessory, parent) end
        end,
        EquipTool = function(self, tool)
            local parent = registry[self].parent
            if parent and registry[tool] then setParent(tool, parent) end
        end,
        UnequipTools = function(self) return nil end,
        GetLimb = function(self) return Enum.Limb.Unknown end,
        GetBodyPartR15 = function(self) return Enum.BodyPartR15.Head end,
        ReplaceBodyPartR15 = function(self) return true end,
        BuildRigFromAttachments = function(self) return nil end,
        ApplyDescription = function(self) return nil end,
        ApplyDescriptionReset = function(self) return nil end,
        GetAppliedDescription = function(self)
            local d = registry[self]
            if not d.description then d.description = lib.new("HumanoidDescription") end
            return d.description
        end,
        CacheDefaults = function(self) return nil end,
        GetMoveVelocity = function(self) return V3.new(0, 0, 0) end,
    }
    classMethods.Animator = {
        LoadAnimation = classMethods.Humanoid.LoadAnimation,
        GetPlayingAnimationTracks = classMethods.Humanoid.GetPlayingAnimationTracks,
        StepAnimations = function() return nil end,
        ApplyJointVelocities = function() return nil end,
    }

    classMethods.Camera = {
        WorldToScreenPoint = function(self, p)
            return V3.new(960 + (p and p.X or 0), 540 + (p and p.Y or 0), 10), true
        end,
        WorldToViewportPoint = function(self, p)
            return V3.new(960 + (p and p.X or 0), 540 + (p and p.Y or 0), 10), true
        end,
        ScreenPointToRay = function(self, x, y)
            return D.Ray.new(V3.new(x or 0, y or 0, 0), V3.new(0, 0, -1))
        end,
        ViewportPointToRay = function(self, x, y)
            return D.Ray.new(V3.new(x or 0, y or 0, 0), V3.new(0, 0, -1))
        end,
        GetPartsObscuringTarget = function() return {} end,
        GetLargestCutoffDistance = function() return 0 end,
    }

    classMethods.TextChannel = {
        SendAsync = function(self, message, metadata)
            output.chat = output.chat or {}
            output.chat[#output.chat + 1] = {
                channel = tostring(self), message = message, metadata = metadata,
            }
            local msg = lib.new("TextChatMessage")
            msg.Text = message
            msg.Status = Enum.TextChatMessageStatus.Success
            fireSignal(registry[self], "MessageReceived", msg)
            return msg
        end,
        DisplaySystemMessage = function(self, message)
            output.chat = output.chat or {}
            output.chat[#output.chat + 1] = { channel = tostring(self), system = message }
            return nil
        end,
        AddUserAsync = function() return nil end,
        SetDirectChatRequester = function() return nil end,
    }

    classMethods.Terrain = {
        Clear = function() return nil end,
        FillBlock = function() return nil end,
        FillBall = function() return nil end,
        FillRegion = function() return nil end,
        ReadVoxels = function() return {}, {} end,
        WriteVoxels = function() return nil end,
        WorldToCell = function(_, v) return v or V3.new() end,
        CellCenterToWorld = function(_, x, y, z) return V3.new(x, y, z) end,
    }

    -- === construction ====================================================
    function lib.new(className, parent)
        className = tostring(className or "Instance")
        local entry = chainFor(className)
        local obj = setmetatable({}, instMt)
        registry[obj] = {
            className = className,
            chain = entry.chain,
            set = entry.set,
            props = { Name = className },
            children = {},
            parent = nil,
            signals = {},
            propSignals = {},
            attributes = {},
            attributeSignals = {},
            tags = {},
            destroyed = false,
        }
        registry[obj].signals.Changed = Signal.new(className .. ".Changed", sched)
        if parent ~= nil then setParent(obj, parent) end
        return obj
    end

    function lib.addMethods(inst, tbl)
        local d = registry[inst]
        d.methods = d.methods or {}
        for k, v in pairs(tbl) do d.methods[k] = v end
        return inst
    end

    function lib.addGetters(inst, tbl)
        local d = registry[inst]
        d.getters = d.getters or {}
        for k, v in pairs(tbl) do d.getters[k] = v end
        return inst
    end

    function lib.isDestroyed(inst)
        local d = registry[inst]
        return d == nil or d.destroyed
    end

    function lib.signal(inst, name) return getSignal(registry[inst], name) end
    function lib.fire(inst, name, ...) return fireSignal(registry[inst], name, ...) end
    lib.baseMethods = baseMethods
    lib.metatable = instMt

    return lib
end

return Instance














