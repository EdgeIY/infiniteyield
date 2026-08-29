--[[ tests/stub/selftest.lua --------------------------------------------------
  Self-test for the headless Roblox emulator.  Run from anywhere:

      luajit tests/stub/selftest.lua

  Prints "PASS <n>/<n>" and exits 0 when every assertion holds, otherwise
  prints each failure, then "FAILED <bad>/<n>" and exits 1.
--]]

local here = (function()
    local src = debug.getinfo(1, "S").source or ""
    src = src:gsub("^@", "")
    return src:match("^(.*[/\\])") or "tests/stub/"
end)()

local Stub = assert(loadfile(here .. "init.lua"))()

local passed, failures = 0, {}

local function ok(cond, label)
    if cond then
        passed = passed + 1
    else
        failures[#failures + 1] = label
    end
    return cond
end

local function eq(actual, expected, label)
    return ok(actual == expected,
        label .. " (got " .. tostring(actual) .. ", expected " .. tostring(expected) .. ")")
end

local function near(actual, expected, label, epsilon)
    epsilon = epsilon or 1e-6
    local good = type(actual) == "number" and math.abs(actual - expected) <= epsilon
    return ok(good,
        label .. " (got " .. tostring(actual) .. ", expected ~" .. tostring(expected) .. ")")
end

local function fails(fn, label)
    local success = pcall(fn)
    return ok(not success, label .. " (expected an error)")
end

-- =========================================================================
local env = Stub.new({
    playerName = "TestPlayer",
    playerCount = 3,
    files = { ["preloaded.txt"] = "hello" },
    http = function(url) return '{"url":"' .. tostring(url) .. '"}' end,
    executor = "StubExecutor",
})
local G = env.globals
local Instance, Enum = G.Instance, G.Enum
local Vector3, CFrame, Color3, UDim2 = G.Vector3, G.CFrame, G.Color3, G.UDim2
local sched = env.scheduler

-- === 1. instances: properties, parenting, child lookup ===================
do
    local model = Instance.new("Model")
    model.Name = "Rig"
    eq(model.ClassName, "Model", "ClassName")
    eq(model.Name, "Rig", "Name assignment")
    eq(tostring(model), "Rig", "tostring(instance) is its Name")
    eq(model.Parent, nil, "new instance has no parent")

    local part = Instance.new("Part", model)
    part.Name = "Torso"
    eq(part.Parent, model, "constructor parent argument")
    eq(#model:GetChildren(), 1, "GetChildren count")
    eq(model:FindFirstChild("Torso"), part, "FindFirstChild")
    eq(model.Torso, part, "__index child lookup")
    eq(model:FindFirstChildOfClass("Part"), part, "FindFirstChildOfClass")
    eq(model:FindFirstChildWhichIsA("BasePart"), part, "FindFirstChildWhichIsA")
    eq(part:GetFullName(), "Rig.Torso", "GetFullName")

    local nested = Instance.new("Folder", part)
    nested.Name = "Deep"
    eq(model:FindFirstChild("Deep"), nil, "FindFirstChild is not recursive by default")
    eq(model:FindFirstChild("Deep", true), nested, "FindFirstChild recursive")
    eq(#model:GetDescendants(), 2, "GetDescendants")
    eq(nested:IsDescendantOf(model), true, "IsDescendantOf")
    eq(model:IsAncestorOf(nested), true, "IsAncestorOf")
    eq(nested:FindFirstAncestor("Rig"), model, "FindFirstAncestor")
    eq(nested:FindFirstAncestorOfClass("Model"), model, "FindFirstAncestorOfClass")
    eq(nested:FindFirstAncestorWhichIsA("PVInstance"), part,
        "FindFirstAncestorWhichIsA finds the nearest match")

    -- property defaults and unknown members
    local frame = Instance.new("Frame")
    eq(env.typeof(frame.Position), "UDim2", "GuiObject Position defaults to UDim2")
    eq(env.typeof(part.Position), "Vector3", "BasePart Position defaults to Vector3")
    eq(frame.Visible, true, "default Visible")
    eq(part.Transparency, 0, "default Transparency")
    eq(part.CanCollide, true, "CanCollide is a property, not a method")
    eq(frame.TotallyMadeUpProperty, nil, "unknown property reads nil")
    eq(type(part.GetMadeUpThing), "function", "unknown method returns a no-op function")
    eq(part:GetMadeUpThing(), nil, "no-op method returns nil")
    local recorded = false
    for _, entry in ipairs(env.output.unimplemented) do
        if entry.name == "GetMadeUpThing" and entry.className == "Part" then recorded = true end
    end
    ok(recorded, "unimplemented method call is recorded")

    -- attributes
    part:SetAttribute("Speed", 42)
    eq(part:GetAttribute("Speed"), 42, "SetAttribute/GetAttribute")
    eq(part:GetAttributes().Speed, 42, "GetAttributes")

    -- reparenting maintains both lists
    local other = Instance.new("Folder")
    part.Parent = other
    eq(#model:GetChildren(), 0, "old parent loses the child")
    eq(#other:GetChildren(), 1, "new parent gains the child")
    part.Parent = nil
    eq(part.Parent, nil, "Parent = nil detaches")
    eq(#other:GetChildren(), 0, "detached child leaves the list")
end

-- === 2. Destroy semantics ================================================
do
    local root = Instance.new("Folder")
    local child = Instance.new("Part", root)
    local grandchild = Instance.new("Decal", child)
    local removedFired = 0
    root.ChildRemoved:Connect(function() removedFired = removedFired + 1 end)

    child:Destroy()
    eq(child.Parent, nil, "Destroy clears Parent")
    eq(#root:GetChildren(), 0, "Destroy removes the child from the parent")
    eq(removedFired, 1, "Destroy fires ChildRemoved")
    eq(grandchild.Parent, nil, "Destroy recurses into descendants")

    child.Name = "ShouldBeIgnored"
    eq(child.Name, "Part", "property writes on a destroyed instance are ignored")
    child.Parent = root
    eq(child.Parent, nil, "reparenting a destroyed instance is ignored")

    local signalStillWorks = 0
    local victim = Instance.new("TextButton")
    victim.MouseButton1Click:Connect(function() signalStillWorks = 1 end)
    victim:Destroy()
    victim.MouseButton1Click:Fire()
    eq(signalStillWorks, 0, "Destroy disconnects existing connections")

    local model = Instance.new("Model")
    Instance.new("Part", model)
    Instance.new("Part", model)
    model:ClearAllChildren()
    eq(#model:GetChildren(), 0, "ClearAllChildren")
end

-- === 3. IsA hierarchy ====================================================
do
    local mesh = Instance.new("MeshPart")
    eq(mesh:IsA("MeshPart"), true, "IsA self")
    eq(mesh:IsA("BasePart"), true, "MeshPart IsA BasePart")
    eq(mesh:IsA("PVInstance"), true, "BasePart IsA PVInstance")
    eq(mesh:IsA("PBInstance"), true, "PBInstance alias")
    eq(mesh:IsA("Instance"), true, "everything IsA Instance")
    eq(mesh:IsA("Humanoid"), false, "IsA rejects unrelated classes")
    eq(Instance.new("TextButton"):IsA("GuiObject"), true, "TextButton IsA GuiObject")
    eq(Instance.new("TextButton"):IsA("GuiButton"), true, "TextButton IsA GuiButton")
    eq(Instance.new("ScreenGui"):IsA("LayerCollector"), true, "ScreenGui IsA LayerCollector")
    eq(Instance.new("StringValue"):IsA("ValueBase"), true, "StringValue IsA ValueBase")
    eq(Instance.new("StringValue").Value, "", "StringValue default Value")
    eq(Instance.new("IntValue").Value, 0, "IntValue default Value")
    eq(Instance.new("Accessory"):IsA("Accoutrement"), true, "Accessory IsA Accoutrement")
    eq(Instance.new("LocalScript"):IsA("BaseScript"), true, "LocalScript IsA BaseScript")
    eq(env.workspace:IsA("Model"), true, "Workspace IsA Model")
    eq(Instance.new("UICorner"):IsA("UIComponent"), true, "UICorner IsA UIComponent")
end

-- === 4. signals ==========================================================
do
    local button = Instance.new("TextButton")
    local calls = {}
    local conn = button.MouseButton1Click:Connect(function(arg)
        calls[#calls + 1] = arg or "nil"
    end)
    button.MouseButton1Click:Fire("a")
    eq(#calls, 1, "Connect + Fire")
    eq(calls[1], "a", "Fire forwards arguments")
    eq(env.typeof(conn), "RBXScriptConnection", "typeof(connection)")
    eq(conn.Connected, true, "connection starts connected")
    conn:Disconnect()
    eq(conn.Connected, false, "Disconnect flips Connected")
    button.MouseButton1Click:Fire("b")
    eq(#calls, 1, "disconnected handler no longer runs")

    local onceCount = 0
    button.MouseButton1Click:Once(function() onceCount = onceCount + 1 end)
    button.MouseButton1Click:Fire()
    button.MouseButton1Click:Fire()
    eq(onceCount, 1, "Once fires exactly once")

    -- auto-created signal members
    eq(env.typeof(button.SomethingChanged), "RBXScriptSignal", "*Changed auto-signal")
    eq(env.typeof(button.WeirdEnded), "RBXScriptSignal", "*Ended auto-signal")
    eq(env.typeof(button.ThingAdded), "RBXScriptSignal", "*Added auto-signal")
    eq(button.SomethingChanged, button.SomethingChanged, "auto-signals are memoised")

    -- Changed / GetPropertyChangedSignal
    local changedProps, propSignalHits = {}, 0
    local label = Instance.new("TextLabel")
    label.Changed:Connect(function(prop) changedProps[#changedProps + 1] = prop end)
    label:GetPropertyChangedSignal("Text"):Connect(function()
        propSignalHits = propSignalHits + 1
    end)
    label.Text = "hi"
    label.Visible = false
    eq(#changedProps, 2, "Changed fires for every property set")
    eq(changedProps[1], "Text", "Changed passes the property name")
    eq(propSignalHits, 1, "GetPropertyChangedSignal only fires for its property")
    eq(label:GetPropertyChangedSignal("Text"), label:GetPropertyChangedSignal("Text"),
        "GetPropertyChangedSignal is memoised")

    -- Wait inside a scheduler thread
    local waited
    sched.spawn(function() waited = label.SomeEvent:Wait() end)
    label.SomeEvent:Fire("resumed")
    eq(waited, "resumed", "signal:Wait() resumes the waiting thread")

    -- a handler that errors must not stop the other handlers
    local afterError = false
    local sig = Instance.new("Folder").ChildAdded
    sig:Connect(function() error("handler blew up") end)
    sig:Connect(function() afterError = true end)
    local before = #sched.errors
    sig:Fire()
    ok(afterError, "an erroring handler does not block later handlers")
    eq(#sched.errors, before + 1, "handler errors are recorded")
end

-- === 5. scheduler ========================================================
do
    env.reset()
    local order = {}
    local startClock = sched.clock()

    G.task.spawn(function()
        order[#order + 1] = "spawn-immediate"
        G.task.wait(0.5)
        order[#order + 1] = "wait-0.5"
    end)
    G.task.spawn(function()
        G.task.wait(0.25)
        order[#order + 1] = "wait-0.25"
    end)
    G.task.defer(function() order[#order + 1] = "deferred" end)
    G.task.delay(0.75, function() order[#order + 1] = "delay-0.75" end)

    eq(order[1], "spawn-immediate", "task.spawn runs immediately")
    eq(#order, 1, "defer/delay do not run before a step")
    ok(sched.pending() >= 3, "pending() counts waiting threads")

    sched.advance(1)
    eq(table.concat(order, ","),
        "spawn-immediate,deferred,wait-0.25,wait-0.5,delay-0.75",
        "wait/delay resume in time order")
    near(sched.clock() - startClock, 1, "advance() moves the clock exactly")
    eq(sched.pending(), 0, "no threads pending once everything resumed")

    -- cancel
    local cancelled = false
    local thread = G.task.delay(0.2, function() cancelled = true end)
    eq(type(thread), "thread", "task.delay returns a thread")
    G.task.cancel(thread)
    sched.advance(0.5)
    eq(cancelled, false, "task.cancel prevents the thread from running")

    -- error capture keeps the rest of the run alive
    env.reset()
    local afterError = false
    G.task.spawn(function() error("scheduled boom") end)
    G.task.spawn(function() afterError = true end)
    eq(#sched.errors, 1, "one error captured")
    ok(sched.errors[1].message:find("scheduled boom") ~= nil, "error message is kept")
    ok(sched.errors[1].traceback:find("traceback") ~= nil, "error traceback is captured")
    eq(sched.errors[1].source, "thread", "error source is recorded")
    ok(afterError, "an erroring thread does not abort the run")
    eq(env.output.errors[1], sched.errors[1].message, "errors are mirrored into output")

    -- RunService signals fire once per step
    env.reset()
    local RunService = G.game:GetService("RunService")
    local heartbeats, rendered, stepped = 0, 0, 0
    local dtSeen
    local c1 = RunService.Heartbeat:Connect(function(dt)
        heartbeats = heartbeats + 1
        dtSeen = dt
    end)
    local c2 = RunService.RenderStepped:Connect(function() rendered = rendered + 1 end)
    local c3 = RunService.Stepped:Connect(function() stepped = stepped + 1 end)
    sched.step(1 / 60)
    eq(heartbeats, 1, "Heartbeat fires once per step")
    eq(rendered, 1, "RenderStepped fires once per step")
    eq(stepped, 1, "Stepped fires once per step")
    near(dtSeen, 1 / 60, "Heartbeat receives the delta time")
    sched.step(1 / 60)
    eq(heartbeats, 2, "Heartbeat keeps firing")
    c1:Disconnect(); c2:Disconnect(); c3:Disconnect()

    -- BindToRenderStep
    local bound = 0
    RunService:BindToRenderStep("stub", 100, function() bound = bound + 1 end)
    sched.step()
    eq(bound, 1, "BindToRenderStep runs on the next step")
    RunService:UnbindFromRenderStep("stub")
    sched.step()
    eq(bound, 1, "UnbindFromRenderStep stops the callback")

    -- drain() bounds itself
    env.reset()
    local drained = false
    G.task.delay(0.1, function() drained = true end)
    local steps = sched.drain(1000)
    ok(drained, "drain() runs pending timers")
    ok(steps > 0 and steps < 1000, "drain() stops once nothing is pending")

    -- wait() on the main thread advances virtual time instead of erroring
    local mainBefore = sched.clock()
    local elapsed = G.wait(0.25)
    near(sched.clock() - mainBefore, 0.25, "main-thread wait advances the clock")
    near(elapsed, 0.25, "wait returns the elapsed time", 0.02)
end

-- === 6. JSON ============================================================
do
    local HttpService = G.game:GetService("HttpService")
    eq(HttpService:JSONEncode({}), "[]", "empty table encodes as an array")
    eq(HttpService:JSONEncode({ 1, 2, 3 }), "[1,2,3]", "array encoding")
    eq(HttpService:JSONEncode({ b = 2, a = "x" }), '{"a":"x","b":2}',
        "object encoding with sorted keys")
    eq(HttpService:JSONEncode({ nested = { { k = true } } }), '{"nested":[{"k":true}]}',
        "nested encoding")
    eq(HttpService:JSONEncode("tab\there\nline \"quoted\" \\ back"),
        '"tab\\there\\nline \\"quoted\\" \\\\ back"', "string escapes")
    eq(HttpService:JSONEncode({ n = 1.5 }), '{"n":1.5}', "float encoding")
    eq(HttpService:JSONEncode({ n = -42 }), '{"n":-42}', "integer encoding")

    local decoded = HttpService:JSONDecode(
        '{"a":[1,2,{"deep":"\\u00e9"}],"t":true,"f":false,"z":null,"e":-1.5e2}')
    eq(#decoded.a, 3, "decoded array length")
    eq(decoded.a[3].deep, "\195\169", "decoded \\u escape becomes UTF-8")
    eq(decoded.t, true, "decoded true")
    eq(decoded.f, false, "decoded false")
    eq(decoded.z, nil, "decoded null is nil")
    eq(decoded.e, -150, "decoded exponent")

    local roundTrip = { list = { 1, 2, 3 }, text = "a\nb", flag = false, num = 0.25 }
    local again = HttpService:JSONDecode(HttpService:JSONEncode(roundTrip))
    eq(again.text, "a\nb", "round trip keeps escapes")
    eq(again.list[3], 3, "round trip keeps arrays")
    eq(again.flag, false, "round trip keeps false")
    eq(again.num, 0.25, "round trip keeps floats")
    fails(function() HttpService:JSONDecode("{oops}") end, "malformed JSON errors")
    fails(function()
        local cyclic = {}
        cyclic.self = cyclic
        HttpService:JSONEncode(cyclic)
    end, "cyclic table errors")

    local guid = HttpService:GenerateGUID()
    eq(guid:sub(1, 1), "{", "GenerateGUID has braces by default")
    eq(#HttpService:GenerateGUID(false), 36, "GenerateGUID(false) is 36 chars")
end

-- === 7. Vector3 / CFrame math ===========================================
do
    local a = Vector3.new(1, 2, 3)
    local b = Vector3.new(4, 5, 6)
    eq(tostring(a), "1, 2, 3", "Vector3 tostring")
    ok(a + b == Vector3.new(5, 7, 9), "Vector3 addition")
    ok(b - a == Vector3.new(3, 3, 3), "Vector3 subtraction")
    ok(a * 2 == Vector3.new(2, 4, 6), "Vector3 scalar multiply")
    ok(b / 2 == Vector3.new(2, 2.5, 3), "Vector3 scalar divide")
    ok(-a == Vector3.new(-1, -2, -3), "Vector3 unary minus")
    near(Vector3.new(3, 4, 0).Magnitude, 5, "Vector3 Magnitude")
    near(Vector3.new(0, 3, 0).Unit.Y, 1, "Vector3 Unit")
    near(a:Dot(b), 32, "Vector3 Dot")
    ok(Vector3.new(1, 0, 0):Cross(Vector3.new(0, 1, 0)) == Vector3.new(0, 0, 1), "Vector3 Cross")
    ok(a:Lerp(b, 0.5) == Vector3.new(2.5, 3.5, 4.5), "Vector3 Lerp")
    ok(a:FuzzyEq(Vector3.new(1, 2, 3.0000001)), "Vector3 FuzzyEq")
    ok(Vector3.zero == Vector3.new(0, 0, 0), "Vector3.zero")
    ok(Vector3.one == Vector3.new(1, 1, 1), "Vector3.one")
    ok(Vector3.xAxis == Vector3.new(1, 0, 0), "Vector3.xAxis")

    -- translation math must be exact
    local origin = CFrame.new(10, 20, 30)
    eq(origin.Position, Vector3.new(10, 20, 30), "CFrame.new(x,y,z).Position")
    eq(origin.p, origin.Position, "CFrame.p alias")
    eq((origin * CFrame.new(1, 2, 3)).Position, Vector3.new(11, 22, 33),
        "CFrame * CFrame translates")
    eq(origin * Vector3.new(1, 2, 3), Vector3.new(11, 22, 33), "CFrame * Vector3 translates")
    eq((origin + Vector3.new(1, 1, 1)).Position, Vector3.new(11, 21, 31), "CFrame + Vector3")
    eq((origin - Vector3.new(1, 1, 1)).Position, Vector3.new(9, 19, 29), "CFrame - Vector3")
    eq((origin:Inverse() * origin).Position, Vector3.new(0, 0, 0), "CFrame Inverse round trip")
    eq(origin:ToObjectSpace(CFrame.new(11, 22, 33)).Position, Vector3.new(1, 2, 3),
        "ToObjectSpace")
    eq(origin:ToWorldSpace(CFrame.new(1, 2, 3)).Position, Vector3.new(11, 22, 33),
        "ToWorldSpace")
    eq(select(1, CFrame.new(4, 5, 6):GetComponents()), 4, "GetComponents returns position first")
    eq(CFrame.new(Vector3.new(7, 8, 9)).Position, Vector3.new(7, 8, 9), "CFrame.new(Vector3)")
    eq(CFrame.identity.Position, Vector3.new(0, 0, 0), "CFrame.identity")
    local rx, ry, rz = CFrame.Angles(0.25, 0.5, 0.75):ToEulerAnglesXYZ()
    near(rx, 0.25, "ToEulerAnglesXYZ x")
    near(ry, 0.5, "ToEulerAnglesXYZ y")
    near(rz, 0.75, "ToEulerAnglesXYZ z")
    local look = CFrame.new(Vector3.new(0, 0, 0), Vector3.new(0, 0, -10)).LookVector
    near(look.Z, -1, "CFrame.new(pos, lookAt) LookVector")
    near(CFrame.new(1, 2, 3):Lerp(CFrame.new(3, 4, 5), 0.5).Position.X, 2, "CFrame Lerp position")
end

-- === 8. Color3, UDim2, misc datatypes ===================================
do
    local red = Color3.new(1, 0, 0)
    eq(tostring(red), "1, 0, 0", "Color3 tostring")
    ok(Color3.fromRGB(255, 0, 0) == red, "Color3.fromRGB")
    near(Color3.fromRGB(128, 128, 128).R, 128 / 255, "fromRGB scaling")
    local h, s, v = red:ToHSV()
    near(h, 0, "ToHSV hue")
    near(s, 1, "ToHSV saturation")
    near(v, 1, "ToHSV value")
    ok(Color3.fromHSV(h, s, v) == red, "fromHSV round trip")
    ok(Color3.fromHex("#FF0000") == red, "Color3.fromHex")
    eq(Color3.fromRGB(255, 128, 0):ToHex(), "FF8000", "Color3 ToHex")
    ok(red:Lerp(Color3.new(0, 0, 1), 0.5) == Color3.new(0.5, 0, 0.5), "Color3 Lerp")

    local ud2 = UDim2.new(0.5, 10, 1, -20)
    eq(ud2.X.Scale, 0.5, "UDim2 X.Scale")
    eq(ud2.X.Offset, 10, "UDim2 X.Offset")
    eq(ud2.Y.Offset, -20, "UDim2 Y.Offset")
    eq(tostring(ud2), "{0.5, 10}, {1, -20}", "UDim2 tostring")
    ok(UDim2.new(0, 1, 0, 1) + UDim2.new(0, 2, 0, 3) == UDim2.new(0, 3, 0, 4), "UDim2 addition")
    eq(UDim2.fromScale(1, 1).X.Scale, 1, "UDim2.fromScale")
    eq(UDim2.fromOffset(5, 6).Y.Offset, 6, "UDim2.fromOffset")
    eq(G.UDim.new(0.5, 4).Scale, 0.5, "UDim.new")

    eq(env.typeof(G.TweenInfo.new(1)), "TweenInfo", "typeof(TweenInfo)")
    eq(G.TweenInfo.new(2).Time, 2, "TweenInfo.Time")
    eq(G.BrickColor.new("Really red").Name, "Really red", "BrickColor by name")
    eq(env.typeof(G.BrickColor.Random().Color), "Color3", "BrickColor.Color is a Color3")
    eq(G.NumberRange.new(1, 5).Max, 5, "NumberRange")
    eq(#G.NumberSequence.new(0, 1).Keypoints, 2, "NumberSequence keypoints")
    eq(#G.ColorSequence.new(Color3.new(), Color3.new(1, 1, 1)).Keypoints, 2,
        "ColorSequence keypoints")
    eq(G.Rect.new(0, 0, 10, 20).Height, 20, "Rect.Height")
    eq(env.typeof(G.Ray.new(Vector3.new(), Vector3.new(0, 0, 1))), "Ray", "typeof(Ray)")
    eq(env.typeof(G.Region3.new(Vector3.new(), Vector3.new(2, 2, 2))), "Region3", "typeof(Region3)")
    eq(env.typeof(G.RaycastParams.new()), "RaycastParams", "typeof(RaycastParams)")
    eq(env.typeof(G.OverlapParams.new()), "OverlapParams", "typeof(OverlapParams)")
    eq(env.typeof(G.PhysicalProperties.new(1, 1, 1)), "PhysicalProperties",
        "typeof(PhysicalProperties)")
    eq(env.typeof(G.Font.new("x")), "Font", "typeof(Font)")
    eq(G.Faces.new(Enum.NormalId.Top).Top, true, "Faces.new")
    eq(G.Axes.new(Enum.Axis and Enum.Axis.X or "X").X, true, "Axes.new")
    local rng = G.Random.new(1234)
    local n = rng:NextNumber()
    ok(n >= 0 and n <= 1, "Random:NextNumber in range")
    local i = rng:NextInteger(5, 10)
    ok(i >= 5 and i <= 10, "Random:NextInteger in range")
    eq(G.Random.new(99):NextNumber(), G.Random.new(99):NextNumber(), "Random is seed-stable")
    eq(env.typeof(G.Vector2.new(1, 2)), "Vector2", "typeof(Vector2)")
    near(G.Vector2.new(3, 4).Magnitude, 5, "Vector2 Magnitude")
end

-- === 9. Enum ============================================================
do
    eq(tostring(Enum.KeyCode.A), "Enum.KeyCode.A", "EnumItem tostring")
    eq(env.typeof(Enum.KeyCode.A), "EnumItem", "typeof(EnumItem)")
    eq(env.typeof(Enum.KeyCode), "Enum", "typeof(Enum category)")
    eq(env.typeof(Enum), "Enums", "typeof(Enum)")
    ok(Enum.KeyCode.A == Enum.KeyCode.A, "EnumItem identity is stable")
    ok(Enum.KeyCode.A ~= Enum.KeyCode.B, "different items are not equal")
    eq(Enum.KeyCode.A.Name, "A", "EnumItem.Name")
    eq(Enum.KeyCode.A.Value, 97, "KeyCode.A has the real Roblox value")
    eq(Enum.KeyCode.Space.Value, 32, "KeyCode.Space value")
    eq(Enum.KeyCode.F1.Value, 282, "KeyCode.F1 value")
    eq(Enum.KeyCode.Zero.Value, 48, "KeyCode.Zero value")
    eq(Enum.KeyCode.A.EnumType, Enum.KeyCode, "EnumItem.EnumType")
    eq(Enum.KeyCode.A.EnumType.Name, "KeyCode", "EnumType.Name")
    ok(#Enum.KeyCode:GetEnumItems() > 100, "seeded KeyCode has the standard set")
    ok(Enum.KeyCode.LeftControl ~= nil, "KeyCode.LeftControl exists")
    ok(Enum.KeyCode.KeypadEnter ~= nil, "KeyCode.KeypadEnter exists")
    eq(#Enum.HumanoidRigType:GetEnumItems(), 2, "HumanoidRigType has two items")
    eq(Enum.ChatVersion.TextChatService.Name, "TextChatService", "ChatVersion seeded")
    -- permissive: unknown categories and items are created on demand
    local made = Enum.MadeUpCategory.MadeUpItem
    eq(tostring(made), "Enum.MadeUpCategory.MadeUpItem", "unknown enum auto-creates")
    ok(made == Enum.MadeUpCategory.MadeUpItem, "auto-created items are stable")
    eq(#Enum.MadeUpCategory:GetEnumItems(), 1, "auto-created items show up in GetEnumItems")
    eq(Enum.EasingStyle.Quad.EnumType.Name, "EasingStyle", "EasingStyle seeded")
end

-- === 10. virtual filesystem =============================================
do
    eq(G.readfile("preloaded.txt"), "hello", "preloaded files option")
    eq(G.isfile("preloaded.txt"), true, "isfile true")
    eq(G.isfile("missing.txt"), false, "isfile false")
    eq(G.writefile("IY/settings.json", '{"a":1}'), true, "writefile")
    eq(env.fs.read("IY/settings.json"), '{"a":1}', "env.fs.read sees the write")
    eq(env.fs.files["IY/settings.json"], '{"a":1}', "env.fs.files raw table")
    G.appendfile("IY/settings.json", "!")
    eq(G.readfile("IY/settings.json"), '{"a":1}!', "appendfile")
    local logged = false
    for _, entry in ipairs(env.fs.writes) do
        if entry.path == "IY/settings.json" and entry.data == '{"a":1}' then logged = true end
    end
    ok(logged, "every write is logged for assertions")
    eq(G.makefolder("IY/sub"), true, "makefolder")
    eq(G.isfolder("IY"), true, "isfolder for an implied folder")
    eq(G.isfolder("nope"), false, "isfolder false")
    local listed = G.listfiles("IY")
    eq(#listed, 2, "listfiles returns direct children")
    G.delfile("IY/settings.json")
    eq(G.isfile("IY/settings.json"), false, "delfile")
    eq(G.getcustomasset("a/b.png"), "rbxasset://stub/a/b.png", "getcustomasset")

    fails(function() G.writefile("../escape.txt", "x") end, "writefile rejects ..")
    fails(function() G.writefile("/etc/passwd", "x") end, "writefile rejects absolute paths")
    fails(function() G.writefile("a\\..\\b.txt", "x") end, "writefile rejects backslash ..")
    fails(function() G.writefile("C:/x.txt", "x") end, "writefile rejects drive letters")
    fails(function() G.readfile("definitely/missing.txt") end, "readfile errors when missing")
end

-- === 11. players and characters ==========================================
do
    local Players = G.game:GetService("Players")
    eq(Players.LocalPlayer, env.players.localPlayer, "env.players.localPlayer")
    eq(Players.LocalPlayer.Name, "TestPlayer", "playerName option")
    eq(#Players:GetPlayers(), 4, "playerCount option adds dummies")
    eq(Players:GetPlayerByUserId(Players.LocalPlayer.UserId), Players.LocalPlayer,
        "GetPlayerByUserId")
    eq(Players:GetPlayerFromCharacter(Players.LocalPlayer.Character), Players.LocalPlayer,
        "GetPlayerFromCharacter")
    eq(Players:GetNameFromUserIdAsync(Players.LocalPlayer.UserId), "TestPlayer",
        "GetNameFromUserIdAsync")
    eq(Players:GetUserIdFromNameAsync("TestPlayer"), Players.LocalPlayer.UserId,
        "GetUserIdFromNameAsync")
    ok(select(2, Players:GetUserThumbnailAsync(1, Enum.ThumbnailType.HeadShot,
        Enum.ThumbnailSize.Size420x420)), "GetUserThumbnailAsync returns ok")
    eq(env.typeof(Players.LocalPlayer:GetMouse()), "Instance", "GetMouse returns an instance")
    eq(Players.LocalPlayer:FindFirstChildWhichIsA("PlayerGui").ClassName, "PlayerGui",
        "PlayerGui child")
    ok(Players.LocalPlayer:FindFirstChild("Backpack") ~= nil, "Backpack child")

    local char = Players.LocalPlayer.Character
    ok(char ~= nil, "LocalPlayer has a character")
    eq(char.Name, "TestPlayer", "character is named after the player")
    eq(char.Parent, env.workspace, "character is parented to workspace")
    ok(char:FindFirstChild("HumanoidRootPart") ~= nil, "rig has a HumanoidRootPart")
    ok(char.HumanoidRootPart:IsA("BasePart"), "HumanoidRootPart IsA BasePart")
    for _, partName in ipairs({ "Head", "UpperTorso", "LowerTorso", "LeftHand",
        "RightHand", "LeftFoot", "RightFoot" }) do
        ok(char:FindFirstChild(partName) ~= nil, "rig has " .. partName)
    end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    ok(humanoid ~= nil, "rig has a Humanoid")
    eq(humanoid.Health, 100, "Humanoid.Health")
    eq(humanoid.MaxHealth, 100, "Humanoid.MaxHealth")
    eq(humanoid.WalkSpeed, 16, "Humanoid.WalkSpeed")
    eq(humanoid.JumpPower, 50, "Humanoid.JumpPower")
    eq(humanoid.RigType, Enum.HumanoidRigType.R15, "Humanoid.RigType")
    ok(humanoid:FindFirstChildOfClass("Animator") ~= nil, "Humanoid has an Animator")
    ok(char:FindFirstChild("Animate") ~= nil, "character has an Animate script")
    ok(char:FindFirstChildOfClass("Shirt") ~= nil, "character has a Shirt")
    ok(char:FindFirstChildOfClass("Pants") ~= nil, "character has Pants")
    eq(#humanoid:GetAccessories(), 1, "GetAccessories finds the hat")
    eq(#humanoid:GetPlayingAnimationTracks(), 0, "GetPlayingAnimationTracks starts empty")
    eq(humanoid:GetState(), Enum.HumanoidStateType.Running, "Humanoid:GetState")
    eq(humanoid:GetStateEnabled(Enum.HumanoidStateType.Jumping), true, "GetStateEnabled default")
    humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
    eq(humanoid:GetStateEnabled(Enum.HumanoidStateType.Jumping), false, "SetStateEnabled")
    local track = humanoid:LoadAnimation(Instance.new("Animation"))
    eq(track.ClassName, "AnimationTrack", "LoadAnimation returns an AnimationTrack")
    track:Play()
    eq(#humanoid:GetPlayingAnimationTracks(), 1, "a playing track is listed")

    local stateSeen
    humanoid.StateChanged:Connect(function(_, new) stateSeen = new end)
    humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
    eq(stateSeen, Enum.HumanoidStateType.Jumping, "ChangeState fires StateChanged")

    local damaged, died = nil, false
    humanoid.HealthChanged:Connect(function(h) damaged = h end)
    humanoid.Died:Connect(function() died = true end)
    humanoid:TakeDamage(40)
    eq(damaged, 60, "TakeDamage fires HealthChanged")
    humanoid:TakeDamage(100)
    eq(humanoid.Health, 0, "Health floors at zero")
    ok(died, "Died fires when health hits zero")

    -- respawn
    local removingSeen, addedSeen = nil, nil
    Players.LocalPlayer.CharacterRemoving:Connect(function(c) removingSeen = c end)
    Players.LocalPlayer.CharacterAdded:Connect(function(c) addedSeen = c end)
    local fresh = env.players.respawn(Players.LocalPlayer)
    eq(removingSeen, char, "respawn fires CharacterRemoving with the old rig")
    eq(addedSeen, fresh, "respawn fires CharacterAdded with the new rig")
    ok(fresh ~= char, "respawn builds a new rig")
    eq(Players.LocalPlayer.Character, fresh, "player.Character points at the new rig")
    eq(fresh:FindFirstChildOfClass("Humanoid").Health, 100, "the new rig is healthy")

    -- add / remove
    local addedPlayer
    Players.PlayerAdded:Connect(function(p) addedPlayer = p end)
    local extra = env.players.add("Newcomer")
    eq(addedPlayer, extra, "players.add fires PlayerAdded")
    eq(#Players:GetPlayers(), 5, "players.add appends to GetPlayers")
    local removedPlayer
    Players.PlayerRemoving:Connect(function(p) removedPlayer = p end)
    env.players.remove("Newcomer")
    eq(removedPlayer, extra, "players.remove fires PlayerRemoving")
    eq(#Players:GetPlayers(), 4, "players.remove shrinks GetPlayers")
end

-- === 12. TweenService, WaitForChild, services ============================
do
    local TweenService = G.game:GetService("TweenService")
    local frame = Instance.new("Frame")
    frame.BackgroundTransparency = 0
    local tween = TweenService:Create(frame, G.TweenInfo.new(0.5),
        { BackgroundTransparency = 1, Visible = false })
    eq(env.typeof(tween.Completed), "RBXScriptSignal", "tween.Completed is a signal")
    tween:Play()
    eq(frame.BackgroundTransparency, 1, "Tween:Play applies properties immediately")
    eq(frame.Visible, false, "Tween:Play applies every property")
    local completed = false
    tween.Completed:Connect(function() completed = true end)
    local tween2 = TweenService:Create(frame, G.TweenInfo.new(0.1), { Rotation = 45 })
    tween2.Completed:Connect(function() completed = true end)
    tween2:Play()
    sched.step()
    ok(completed, "tween Completed fires on the next step")
    eq(frame.Rotation, 45, "second tween applied")

    -- TweenPosition / TweenSize apply immediately and call back next step
    local tweened = false
    eq(frame:TweenPosition(UDim2.new(1, 0, 1, 0), nil, nil, 0.3, true,
        function() tweened = true end), true, "TweenPosition returns true")
    eq(tostring(frame.Position), "{1, 0}, {1, 0}", "TweenPosition applies the target")
    sched.step()
    ok(tweened, "TweenPosition callback runs on the next step")
    eq(frame:TweenSize(UDim2.new(0, 50, 0, 50)), true, "TweenSize returns true")
    eq(tostring(frame.Size), "{0, 50}, {0, 50}", "TweenSize applies the target")
    eq(frame:TweenSizeAndPosition(UDim2.new(0, 1, 0, 1), UDim2.new(0, 2, 0, 2)), true,
        "TweenSizeAndPosition returns true")
    eq(tostring(frame.Size), "{0, 1}, {0, 1}", "TweenSizeAndPosition applies size")

    -- WaitForChild: immediate, deferred and timeout
    local holder = Instance.new("Folder")
    local now = Instance.new("Part", holder)
    now.Name = "Immediate"
    eq(holder:WaitForChild("Immediate"), now, "WaitForChild returns an existing child")
    local late
    sched.spawn(function() late = holder:WaitForChild("Late", 5) end)
    sched.delay(0.2, function()
        local child = Instance.new("Part", holder)
        child.Name = "Late"
    end)
    sched.advance(1)
    ok(late ~= nil and late.Name == "Late", "WaitForChild resumes when the child appears")
    eq(holder:WaitForChild("NeverArrives", 0.2), nil, "WaitForChild times out to nil")

    -- services
    eq(G.game:GetService("Players"), G.game.Players, "GetService and child access agree")
    eq(G.game:GetService("Workspace"), env.workspace, "workspace is the Workspace service")
    eq(G.workspace, G.Workspace, "workspace and Workspace globals match")
    eq(G.game:GetService("MadeUpService").ClassName, "MadeUpService",
        "unknown services are auto-created")
    eq(G.game:FindService("MadeUpService"), G.game:GetService("MadeUpService"),
        "FindService returns the cached service")
    eq(G.game:GetService("RunService"):IsStudio(), false, "RunService:IsStudio")
    eq(G.game:GetService("RunService"):IsClient(), true, "RunService:IsClient")
    eq(G.game:GetService("UserInputService"):GetPlatform(), Enum.Platform.Windows,
        "UserInputService:GetPlatform")
    eq(G.game:GetService("UserInputService"):IsKeyDown(Enum.KeyCode.A), false, "IsKeyDown")
    eq(env.typeof(G.game:GetService("UserInputService"):GetMouseLocation()), "Vector2",
        "GetMouseLocation")
    eq(env.workspace:Raycast(Vector3.new(), Vector3.new(0, -1, 0)), nil, "Workspace:Raycast is nil")
    eq(#env.workspace:GetPartBoundsInBox(CFrame.new(), Vector3.new(1, 1, 1)), 0,
        "GetPartBoundsInBox is empty")
    eq(#env.workspace:GetPartsInPart(Instance.new("Part")), 0, "GetPartsInPart is empty")
    ok(env.workspace:FindFirstChildOfClass("Terrain") ~= nil, "Workspace has Terrain")
    eq(env.workspace.CurrentCamera.ClassName, "Camera", "Workspace.CurrentCamera")
    near(env.workspace.Gravity, 196.2, "Workspace.Gravity")

    local tcs = G.game:GetService("TextChatService")
    eq(tcs.ChatVersion, Enum.ChatVersion.TextChatService, "TextChatService.ChatVersion")
    local channel = tcs:WaitForChild("TextChannels"):WaitForChild("RBXGeneral")
    eq(channel.ClassName, "TextChannel", "RBXGeneral channel exists")
    local before = #env.output.chat
    channel:SendAsync("hello world")
    eq(#env.output.chat, before + 1, "SendAsync is recorded")
    eq(env.output.chat[#env.output.chat].message, "hello world", "chat message text")

    local StarterGui = G.game:GetService("StarterGui")
    StarterGui:SetCore("SendNotification", { Title = "T", Text = "B" })
    eq(env.output.notifications[#env.output.notifications].Title, "T",
        "SetCore SendNotification is recorded")
    StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, false)
    eq(StarterGui:GetCoreGuiEnabled(Enum.CoreGuiType.Chat), false, "Set/GetCoreGuiEnabled")

    G.game:GetService("TeleportService"):TeleportToPlaceInstance(1, "job", G.game.Players.LocalPlayer)
    eq(env.output.teleports[#env.output.teleports].kind, "TeleportToPlaceInstance",
        "teleports are recorded")
    eq(type(G.game:GetService("MarketplaceService"):GetProductInfo(1)), "table",
        "GetProductInfo returns a table")
    local path = G.game:GetService("PathfindingService"):CreatePath()
    path:ComputeAsync(Vector3.new(0, 0, 0), Vector3.new(0, 0, 10))
    eq(path.Status, Enum.PathStatus.Success, "path status")
    ok(#path:GetWaypoints() >= 2, "path waypoints")
    eq(#G.game:GetService("CollectionService"):GetTagged("nothing"), 0, "GetTagged is empty")
    eq(#G.game:GetService("GroupService"):GetGroupsAsync(1), 0, "GetGroupsAsync is empty")
    eq(#G.game:GetService("Teams"):GetTeams(), 0, "GetTeams is empty")
end

-- === 13. globals and exploit environment =================================
do
    eq(G._G, G, "_G points at the sandbox")
    eq(type(G.shared), "table", "shared table")
    eq(G.NeverDefinedGlobal, nil, "unresolved globals read as nil")
    eq(G.typeof(nil), "nil", "typeof(nil)")
    eq(G.typeof(1), "number", "typeof(number)")
    eq(G.typeof("s"), "string", "typeof(string)")
    eq(G.typeof(true), "boolean", "typeof(boolean)")
    eq(G.typeof(print), "function", "typeof(function)")
    eq(G.typeof({}), "table", "typeof(table)")
    eq(G.typeof(coroutine.create(function() end)), "thread", "typeof(thread)")
    eq(G.typeof(G.newproxy(false)), "userdata", "typeof(userdata)")

    eq(G.getgenv(), G, "getgenv returns the sandbox globals")
    eq(G.identifyexecutor(), "StubExecutor", "identifyexecutor honours the option")
    eq(G.checkcaller(), false, "checkcaller is false")
    eq(type(G.getreg()), "table", "getreg returns a table")
    eq(type(G.getgc()), "table", "getgc returns a table")
    local sample = Instance.new("Part")
    eq(G.cloneref(sample), sample, "cloneref is identity")
    eq(G.compareinstances(sample, sample), true, "compareinstances")
    local target = function() return "original" end
    eq(G.hookfunction(target, function() return "hooked" end), target,
        "hookfunction returns the original")
    ok(#env.output.hooks > 0, "hookfunction is recorded")
    eq(type(G.hookmetamethod({}, "__index", function() end)), "function",
        "hookmetamethod returns a function")
    eq(G.newcclosure(function(x) return x * 2 end)(21), 42, "newcclosure forwards calls")
    G.setclipboard("copied")
    eq(env.output.clipboard[#env.output.clipboard], "copied", "setclipboard is recorded")
    local response = G.request({ Url = "https://example.com" })
    eq(response.StatusCode, 200, "request StatusCode")
    eq(response.Success, true, "request Success")
    eq(response.Body, '{"url":"https://example.com"}', "request Body uses the http option")
    eq(G.getthreadidentity(), 8, "getthreadidentity default")
    G.setthreadidentity(2)
    eq(G.getthreadidentity(), 2, "setthreadidentity")
    eq(G.syn, nil, "syn is absent by default")
    eq(G.fluxus, nil, "fluxus is absent by default")
    eq(G.KRNL_LOADED, nil, "KRNL_LOADED is absent by default")
    eq(#G.getnilinstances(), 0, "getnilinstances is empty")
    ok(#G.getinstances() > 0, "getinstances lists live instances")

    -- getconnections over a real stub signal
    local folder = Instance.new("Folder")
    local hits = 0
    folder.ChildAdded:Connect(function() hits = hits + 1 end)
    local conns = G.getconnections(folder.ChildAdded)
    eq(#conns, 1, "getconnections returns the live connections")
    eq(type(conns[1].Function), "function", "connection exposes Function")
    conns[1]:Fire()
    eq(hits, 1, "connection Fire invokes the handler")
    conns[1]:Disconnect()
    folder.ChildAdded:Fire()
    eq(hits, 1, "connection Disconnect works through getconnections")
    eq(#G.getconnections("not a signal"), 0, "getconnections tolerates non-signals")

    -- firetouchinterest / fireproximityprompt
    local touched = 0
    local partA, partB = Instance.new("Part"), Instance.new("Part")
    partB.Touched:Connect(function() touched = touched + 1 end)
    G.firetouchinterest(partA, partB, 0)
    eq(touched, 1, "firetouchinterest fires Touched")
    local prompted = false
    local prompt = Instance.new("ProximityPrompt")
    prompt.Triggered:Connect(function() prompted = true end)
    G.fireproximityprompt(prompt)
    ok(prompted, "fireproximityprompt fires Triggered")
    local clicked = false
    local detector = Instance.new("ClickDetector")
    detector.MouseClick:Connect(function() clicked = true end)
    G.fireclickdetector(detector)
    ok(clicked, "fireclickdetector fires MouseClick")

    -- capabilities gate the exploit globals
    local limited = Stub.new({ capabilities = { default = false, writefile = true } })
    eq(type(limited.globals.writefile), "function", "capabilities keep the allowed globals")
    eq(limited.globals.hookfunction, nil, "capabilities remove the rest")
    eq(type(limited.globals.game), "table", "the core sandbox survives capability gating")

    -- loadstring runs inside the sandbox
    local chunk = G.loadstring("return typeof(Vector3.new(1,2,3))")
    eq(type(chunk), "function", "loadstring returns a function")
    eq(chunk(), "Vector3", "loadstring inherits the sandbox environment")
    eq(select(2, G.loadstring("this is not lua")) ~= nil, true, "loadstring reports errors")
    fails(function() G.require(1) end, "require errors")
end

-- === 14. the property/method heuristic does not eat real properties =======
do
    local propertyNames = {
        "Name", "Text", "Visible", "Transparency", "Position", "Size", "ZIndex",
        "Enabled", "Value", "Health", "MaxHealth", "WalkSpeed", "JumpPower",
        "CFrame", "Anchored", "CanCollide", "CanQuery", "CanTouch", "MoveDirection",
        "PlayOnRemove", "Playing", "IsPlaying", "IsPaused", "IsLoaded", "Sit",
        "Jump", "Scale", "Focus", "ClearTextOnFocus", "ResetOnSpawn",
        "BreakJointsOnDeath", "ApplyStrokeMode", "PivotOffset", "ScaleType",
        "TouchEnabled", "KeyboardEnabled", "Selected", "Selectable", "Material",
        "BrickColor", "Color", "Orientation", "Velocity", "Rotation", "Style",
        "Font", "LayoutOrder", "AnchorPoint", "CornerRadius", "Padding",
        "Thickness", "FieldOfView", "ViewportSize", "CameraType", "Brightness",
        "Range", "Shadows", "Texture", "SoundId", "Volume", "Looped",
        "TimePosition", "PlaybackSpeed", "AnimationId", "Length", "Speed",
        "Priority", "ActionText", "HoldDuration", "MaxActivationDistance",
        "RequiresLineOfSight", "RequiresHandle", "CanBeDropped", "CollisionGroup",
        "Archivable", "Locked", "Massless", "Reflectance", "AutomaticSize",
        "CanvasSize", "CanvasPosition", "Settings", "Description", "Grip", "ToolTip",
    }
    local classNames = {
        "Part", "Frame", "TextLabel", "TextButton", "TextBox", "Humanoid", "Player",
        "Sound", "Camera", "ScreenGui", "ScrollingFrame", "UIStroke", "UICorner",
        "Model", "ProximityPrompt", "AnimationTrack", "Tool", "Highlight", "Decal",
        "PointLight",
    }
    local hijacked = {}
    for _, className in ipairs(classNames) do
        local object = Instance.new(className)
        for _, property in ipairs(propertyNames) do
            if type(object[property]) == "function" then
                hijacked[#hijacked + 1] = className .. "." .. property
            end
        end
    end
    eq(#hijacked, 0, "no known property resolves to a method (" ..
        table.concat(hijacked, ", ") .. ")")

    local notCallable = {}
    for _, className in ipairs(classNames) do
        local object = Instance.new(className)
        for _, method in ipairs({ "GetChildren", "FindFirstChild", "IsA", "Destroy",
            "Clone", "WaitForChild", "GetDescendants", "TweenPosition", "SetAttribute",
            "GetPropertyChangedSignal", "ClearAllChildren", "IsDescendantOf",
            "GetFullName", "Play", "Stop", "Pause", "Resume", "AdjustSpeed", "MoveTo",
            "GetPivot", "PivotTo", "CaptureFocus", "ReleaseFocus", "IsFocused",
            "FireServer", "InvokeServer", "GetTouchingParts", "GetMass", "ScaleTo",
            "GetWeirdThing", "IsWeirdThing", "SetWeirdThing", "FetchStuffAsync" }) do
            if type(object[method]) ~= "function" then
                notCallable[#notCallable + 1] = className .. ":" .. method
            end
        end
    end
    eq(#notCallable, 0, "every method-shaped member is callable (" ..
        table.concat(notCallable, ", ") .. ")")
end

-- === 15. reset ===========================================================
do
    G.print("noise")
    G.warn("more noise")
    G.task.delay(5, function() end)
    ok(#env.output.prints > 0, "print is captured")
    ok(#env.output.warns > 0, "warn is captured")
    env.reset()
    eq(#env.output.prints, 0, "reset clears prints")
    eq(#env.output.warns, 0, "reset clears warns")
    eq(#env.output.errors, 0, "reset clears errors")
    eq(#sched.errors, 0, "reset clears scheduler errors")
    eq(sched.pending(), 0, "reset clears the scheduler queues")
end

-- =========================================================================
local total = passed + #failures
if #failures == 0 then
    print("PASS " .. passed .. "/" .. total)
    os.exit(0)
end
for _, message in ipairs(failures) do
    io.stderr:write("FAIL: " .. message .. "\n")
end
io.stderr:write("FAILED " .. #failures .. "/" .. total .. "\n")
print("FAILED " .. #failures .. "/" .. total)
os.exit(1)









