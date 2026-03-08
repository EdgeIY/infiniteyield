const fs = require('fs');

let code = fs.readFileSync('attached_assets/source_1772930031930.txt', 'utf8');

// 1. Change UI Title
code = code.replace(
  'Title.Text = "Infinite Yield FE v" .. currentVersion',
  'Title.Text = "Infinite Yield+ (Studio Edition) v" .. currentVersion'
);

// 2. Add UICorner for better UI
const uiCornerPatch = `
local function ApplyRoundedCorners(parent)
    if not parent then return end
    for _, v in pairs(parent:GetDescendants()) do
        if v:IsA("Frame") or v:IsA("TextButton") or v:IsA("TextBox") or v:IsA("ScrollingFrame") or v:IsA("ImageLabel") then
            -- Avoid adding multiple corners
            if not v:FindFirstChildOfClass("UICorner") then
                local corner = Instance.new("UICorner")
                corner.CornerRadius = UDim.new(0, 6)
                corner.Parent = v
            end
        end
    end
end
pcall(function()
    ApplyRoundedCorners(Holder)
    ApplyRoundedCorners(Notification)
    ApplyRoundedCorners(Tooltip)
    ApplyRoundedCorners(KeybindEditor)
    ApplyRoundedCorners(PluginEditor)
    ApplyRoundedCorners(ToPartFrame)
end)
`;

code = code.replace('Title.TextColor3 = Color3.new(1, 1, 1)', uiCornerPatch + '\nTitle.TextColor3 = Color3.new(1, 1, 1)');

// 3. Change currentVersion
code = code.replace('currentVersion = "6.4"', 'currentVersion = "6.4+"');

// 4. Add the downloadgame command
const downloadCmd = `
addcmd('downloadgame', {'savegame'}, function(args, speaker)
    notify('Download', 'Starting to download the game... This may take a moment.')
    
    if saveinstance then
        local success, err = pcall(function()
            -- saveinstance automatically saves the .rbxl to the executor's workspace folder
            saveinstance({
                Decompile = true,
                DecompileTimeout = 15,
                Noscripts = false,
                ShowStatus = true
            })
        end)
        
        if success then
            notify('Success', 'Game downloaded! Check your executor\\'s "workspace" folder for the .rbxl file.')
        else
            notify('Error', 'saveinstance() encountered an error: ' .. tostring(err))
        end
    else
        notify('Warning', 'Your executor lacks saveinstance() support. Copying browser download link to clipboard instead...')
        if setclipboard then
            -- This link allows downloading the .rbxl file directly from the browser if it's uncopylocked
            setclipboard("https://assetdelivery.roblox.com/v1/asset/?id=" .. tostring(game.PlaceId))
            notify('Clipboard', 'Paste the link in your browser to download the place file!')
        end
    end
end, 'Downloads the game (.rbxl) directly to your executor\\'s workspace folder or provides a browser link')
`;

code = code.replace("addcmd('addalias',{},function(args, speaker)", downloadCmd + "\n\naddcmd('addalias',{},function(args, speaker)");

// 5. Change some UI colors to make it look "better" (Modern Dark Theme)
code = code.replace(/Color3\.fromRGB\(36,\s*36,\s*37\)/g, 'Color3.fromRGB(15, 15, 20)');
code = code.replace(/Color3\.fromRGB\(46,\s*46,\s*47\)/g, 'Color3.fromRGB(30, 30, 35)');
code = code.replace(/Color3\.fromRGB\(78,\s*78,\s*79\)/g, 'Color3.fromRGB(50, 50, 60)');

fs.writeFileSync('InfiniteYieldPlus.lua', code);
console.log("Successfully created InfiniteYieldPlus.lua");
