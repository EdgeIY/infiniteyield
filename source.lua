if not game:IsLoaded() then
	local notLoaded = Instance.new("Message",workspace)
	notLoaded.Text = 'Infinite Yield is waiting for the game to load'
	game.Loaded:Wait()
	notLoaded:Destroy()
end

ver = '3.7'

Players = game:GetService("Players")

Holder = Instance.new("Frame")
Title = Instance.new("TextLabel")
Dark = Instance.new("Frame")
Cmdbar = Instance.new("TextBox")
Dark_2 = Instance.new("Frame")
CMDsF = Instance.new("ScrollingFrame")
SettingsButton = Instance.new("ImageButton")
ColorsButton = Instance.new("ImageButton")
Settings = Instance.new("Frame")
Prefix = Instance.new("TextLabel")
PrefixBox = Instance.new("TextBox")
Keybinds = Instance.new("TextLabel")
Select = Instance.new("TextButton")
StayOpen = Instance.new("TextLabel")
Button = Instance.new("Frame")
On = Instance.new("TextButton")
Positions = Instance.new("TextLabel")
Select_8 = Instance.new("TextButton")
SpawnC = Instance.new("TextLabel")
Select_2 = Instance.new("TextButton")
Plugins = Instance.new("TextLabel")
Select_9 = Instance.new("TextButton")
Example = Instance.new("TextButton")
Notification = Instance.new("Frame")
Title_2 = Instance.new("TextLabel")
Text_2 = Instance.new("TextLabel")
CloseButton = Instance.new("ImageButton")
Tooltip = Instance.new("Frame")
Title_3 = Instance.new("TextLabel")
Description = Instance.new("TextLabel")
IntroBackground = Instance.new("Frame")
Logo = Instance.new("ImageLabel")
Credits = Instance.new("TextBox")
KeybindsFrame = Instance.new("Frame")
Close = Instance.new("TextButton")
SpawnCFrame = Instance.new("Frame")
Holder_6 = Instance.new("ScrollingFrame")
Close_5 = Instance.new("TextButton")
Add = Instance.new("TextButton")
Delete = Instance.new("TextButton")
Holder_2 = Instance.new("ScrollingFrame")
Example_2 = Instance.new("Frame")
Text_3 = Instance.new("TextLabel")
Delete_2 = Instance.new("TextButton")
KeybindEditor = Instance.new("Frame")
background_2 = Instance.new("Frame")
Dark_4 = Instance.new("Frame")
Directions = Instance.new("TextLabel")
BindTo = Instance.new("TextButton")
Add_2 = Instance.new("TextButton")
Cmdbar_2 = Instance.new("TextBox")
Toggles = Instance.new("ScrollingFrame")
Fly = Instance.new("TextLabel")
Select_3 = Instance.new("TextButton")
Noclip = Instance.new("TextLabel")
Select_4 = Instance.new("TextButton")
Float = Instance.new("TextLabel")
Select_5 = Instance.new("TextButton")
ClickTP = Instance.new("TextLabel")
Select_6 = Instance.new("TextButton")
ClickDelete = Instance.new("TextLabel")
Select_13 = Instance.new("TextButton") 
Xray = Instance.new("TextLabel")
Select_10 = Instance.new("TextButton")
Swim = Instance.new("TextLabel")
Select_11 = Instance.new("TextButton")
Fling = Instance.new("TextLabel")
Select_12 = Instance.new("TextButton")
shadow_2 = Instance.new("Frame")
PopupText_2 = Instance.new("TextLabel")
Exit_2 = Instance.new("ImageButton")
SpawnCEditor = Instance.new("Frame")
background_4 = Instance.new("Frame")
Cmdbar_3 = Instance.new("TextBox")
Add_5 = Instance.new("TextButton")
DelayNum = Instance.new("TextBox")
DelayT = Instance.new("TextLabel")
Directions_3 = Instance.new("TextLabel")
Dark_11 = Instance.new("Frame")
shadow_4 = Instance.new("Frame")
PopupText_4 = Instance.new("TextLabel")
Exit_4 = Instance.new("ImageButton")
PositionsFrame = Instance.new("Frame")
Close_3 = Instance.new("TextButton")
Delete_5 = Instance.new("TextButton")
Part = Instance.new("TextButton")
Holder_4 = Instance.new("ScrollingFrame")
Example_4 = Instance.new("Frame")
Text_5 = Instance.new("TextLabel")
Delete_6 = Instance.new("TextButton")
TP = Instance.new("TextButton")
AliasesFrame = Instance.new("Frame")
Close_2 = Instance.new("TextButton")
Delete_3 = Instance.new("TextButton")
Holder_3 = Instance.new("ScrollingFrame")
Example_3 = Instance.new("Frame")
Text_4 = Instance.new("TextLabel")
Delete_4 = Instance.new("TextButton")
Aliases = Instance.new("TextLabel")
Select_7 = Instance.new("TextButton")
PluginsFrame = Instance.new("Frame")
Close_4 = Instance.new("TextButton")
Add_4 = Instance.new("TextButton")
Delete_8 = Instance.new("TextButton")
Add_3 = Instance.new("TextButton")
Holder_5 = Instance.new("ScrollingFrame")
Example_5 = Instance.new("Frame")
Text_6 = Instance.new("TextLabel")
Delete_7 = Instance.new("TextButton")
PluginEditor = Instance.new("Frame")
background_3 = Instance.new("Frame")
Dark_9 = Instance.new("Frame")
Img = Instance.new("ImageButton")
AddPlugin = Instance.new("TextButton")
FileName = Instance.new("TextBox")
About = Instance.new("TextLabel")
Directions_2 = Instance.new("TextLabel")
shadow_3 = Instance.new("Frame")
PopupText_3 = Instance.new("TextLabel")
Exit_3 = Instance.new("ImageButton")
logsDrag = Instance.new("Frame")
shadow = Instance.new("Frame")
Hide = Instance.new("ImageButton")
PopupText = Instance.new("TextLabel")
Exit = Instance.new("ImageButton")
background = Instance.new("Frame")
Clear = Instance.new("TextButton")
Toggle = Instance.new("TextButton")
SaveChatlogs = Instance.new("TextButton")
scrollCL = Instance.new("ScrollingFrame")
AliasHint = Instance.new("TextLabel")
PluginsHint = Instance.new("TextLabel")
PositionsHint = Instance.new("TextLabel")
ToPartFrame = Instance.new("Frame")
background_5 = Instance.new("Frame")
ChoosePart = Instance.new("TextButton")
CopyPath = Instance.new("TextButton")
Directions_4 = Instance.new("TextLabel")
Path = Instance.new("TextLabel")
shadow_5 = Instance.new("Frame")
PopupText_5 = Instance.new("TextLabel")
Exit_5 = Instance.new("ImageButton")

PARENT = nil
if game:GetService("CoreGui"):FindFirstChild('RobloxGui') then
	PARENT = game:GetService("CoreGui").RobloxGui
else
	PARENT = game:GetService("CoreGui")
end

function randomString()
	local length = math.random(10,20)
	local array = {}
	for i = 1, length do
		array[i] = string.char(math.random(32, 126))
	end
	return table.concat(array)
end

shade1 = {}
shade2 = {}
shade3 = {}
text1 = {}
text2 = {}
scroll = {}

Holder.Name = randomString()
Holder.Parent = PARENT
Holder.Active = true
Holder.BackgroundColor3 = Color3.fromRGB(46, 46, 47)
Holder.BackgroundTransparency = 0.2
Holder.BorderSizePixel = 0
Holder.Position = UDim2.new(1, -250, 1, -220)
Holder.Size = UDim2.new(0, 250, 0, 220)
Holder.ZIndex = 10
table.insert(shade2,Holder)

Title.Name = "Title"
Title.Parent = Holder
Title.Active = true
Title.BackgroundTransparency = 1
Title.BorderSizePixel = 0
Title.Size = UDim2.new(0, 250, 0, 20)
Title.Font = Enum.Font.SourceSans
Title.TextSize = 20
Title.Text = "Infinite Yield FE v"..ver
Title.TextColor3 = Color3.new(1, 1, 1)
Title.ZIndex = 10
table.insert(text1,Title)

Dark.Name = "Dark"
Dark.Parent = Holder
Dark.Active = true
Dark.BackgroundColor3 = Color3.fromRGB(36, 36, 37)
Dark.BorderSizePixel = 0
Dark.Position = UDim2.new(0, 0, 0, 45)
Dark.Size = UDim2.new(0, 250, 0, 175)
Dark.ZIndex = 10
table.insert(shade1,Dark)

Cmdbar.Name = "Cmdbar"
Cmdbar.Parent = Holder
Cmdbar.BackgroundTransparency = 1
Cmdbar.BorderSizePixel = 0
Cmdbar.Position = UDim2.new(0, 0, 0, 25)
Cmdbar.Size = UDim2.new(0, 250, 0, 20)
Cmdbar.Font = Enum.Font.SourceSans
Cmdbar.TextSize = 20
Cmdbar.Text = "Command Bar"
Cmdbar.TextColor3 = Color3.new(1, 1, 1)
Cmdbar.TextScaled = true
Cmdbar.TextWrapped = true
Cmdbar.ZIndex = 10
table.insert(text1,Cmdbar)

Dark_2.Name = "Dark"
Dark_2.Parent = Holder
Dark_2.Active = true
Dark_2.BackgroundColor3 = Color3.fromRGB(36, 36, 37)
Dark_2.BorderSizePixel = 0
Dark_2.Position = UDim2.new(0, 0, 0, 20)
Dark_2.Size = UDim2.new(0, 250, 0, 5)
Dark_2.ZIndex = 10
table.insert(shade1,Dark_2)

CMDsF.Name = "CMDs"
CMDsF.Parent = Holder
CMDsF.BackgroundTransparency = 1
CMDsF.BorderSizePixel = 0
CMDsF.Position = UDim2.new(0, 0, 0, 45)
CMDsF.Size = UDim2.new(0, 250, 0, 175)
CMDsF.ScrollBarImageColor3 = Color3.fromRGB(78,78,79)
CMDsF.BottomImage = "rbxasset://textures/ui/Scroll/scroll-middle.png"
CMDsF.CanvasSize = UDim2.new(0, 0, 0, 0)
CMDsF.MidImage = "rbxasset://textures/ui/Scroll/scroll-middle.png"
CMDsF.ScrollBarThickness = 8
CMDsF.TopImage = "rbxasset://textures/ui/Scroll/scroll-middle.png"
CMDsF.VerticalScrollBarInset = 'Always'
CMDsF.ZIndex = 10
table.insert(scroll,CMDsF)

SettingsButton.Name = "SettingsButton"
SettingsButton.Parent = Holder
SettingsButton.BackgroundTransparency = 1
SettingsButton.Position = UDim2.new(0, 230, 0, 0)
SettingsButton.Size = UDim2.new(0, 20, 0, 20)
SettingsButton.Image = "rbxassetid://1204397029"
SettingsButton.ZIndex = 10

ColorsButton.Name = "ColorsButton"
ColorsButton.Parent = Holder
ColorsButton.BackgroundTransparency = 1
ColorsButton.Position = UDim2.new(0, 212, 0, 2)
ColorsButton.Size = UDim2.new(0, 16, 0, 16)
ColorsButton.Image = "rbxassetid://4911962991"
ColorsButton.ZIndex = 10

Settings.Name = "Settings"
Settings.Parent = Holder
Settings.Active = true
Settings.BackgroundColor3 = Color3.fromRGB(36, 36, 37)
Settings.BorderSizePixel = 0
Settings.Position = UDim2.new(0, 0, 0, 220)
Settings.Size = UDim2.new(0, 250, 0, 175)
Settings.ZIndex = 10
table.insert(shade1,Settings)

Prefix.Name = "Prefix"
Prefix.Parent = Settings
Prefix.BackgroundColor3 = Color3.fromRGB(46, 46, 47)
Prefix.BorderSizePixel = 0
Prefix.Position = UDim2.new(0, 0, 0, 5)
Prefix.Size = UDim2.new(0, 250, 0, 20)
Prefix.Font = Enum.Font.SourceSans
Prefix.TextSize = 14
Prefix.Text = "    Prefix"
Prefix.TextColor3 = Color3.new(1, 1, 1)
Prefix.TextXAlignment = Enum.TextXAlignment.Left
Prefix.ZIndex = 10
table.insert(shade2,Prefix)
table.insert(text1,Prefix)

PrefixBox.Name = "PrefixBox"
PrefixBox.Parent = Prefix
PrefixBox.BackgroundColor3 = Color3.fromRGB(78, 78, 79)
PrefixBox.BorderSizePixel = 0
PrefixBox.Position = UDim2.new(0, 230, 0, 0)
PrefixBox.Size = UDim2.new(0, 20, 0, 20)
PrefixBox.Font = Enum.Font.SourceSansBold
PrefixBox.TextSize = 14
PrefixBox.Text = ''
PrefixBox.TextColor3 = Color3.new(0, 0, 0)
PrefixBox.ZIndex = 10
table.insert(shade3,PrefixBox)
table.insert(text2,PrefixBox)

Keybinds.Name = "Keybinds"
Keybinds.Parent = Settings
Keybinds.BackgroundColor3 = Color3.fromRGB(46, 46, 47)
Keybinds.BorderSizePixel = 0
Keybinds.Position = UDim2.new(0, 0, 0, 55)
Keybinds.Size = UDim2.new(0, 250, 0, 20)
Keybinds.Font = Enum.Font.SourceSans
Keybinds.TextSize = 14
Keybinds.Text = "    Keybinds"
Keybinds.TextColor3 = Color3.new(1, 1, 1)
Keybinds.TextXAlignment = Enum.TextXAlignment.Left
Keybinds.ZIndex = 10
table.insert(shade2,Keybinds)
table.insert(text1,Keybinds)

Select.Name = "Select"
Select.Parent = Keybinds
Select.BackgroundColor3 = Color3.fromRGB(78, 78, 79)
Select.BorderSizePixel = 0
Select.Position = UDim2.new(0, 200, 0, 0)
Select.Size = UDim2.new(0, 50, 0, 20)
Select.Font = Enum.Font.SourceSans
Select.TextSize = 14
Select.Text = "Edit"
Select.TextColor3 = Color3.new(0, 0, 0)
Select.ZIndex = 10
table.insert(shade3,Select)
table.insert(text2,Select)

Aliases.Name = "Aliases"
Aliases.Parent = Settings
Aliases.BackgroundColor3 = Color3.fromRGB(46, 46, 47)
Aliases.BorderSizePixel = 0
Aliases.Position = UDim2.new(0, 0, 0, 80)
Aliases.Size = UDim2.new(0, 250, 0, 20)
Aliases.Font = Enum.Font.SourceSans
Aliases.TextSize = 14
Aliases.Text = "    Aliases"
Aliases.TextColor3 = Color3.new(1, 1, 1)
Aliases.TextXAlignment = Enum.TextXAlignment.Left
Aliases.ZIndex = 10
table.insert(shade2,Aliases)
table.insert(text1,Aliases)

Select_7.Name = "Select"
Select_7.Parent = Aliases
Select_7.BackgroundColor3 = Color3.fromRGB(78, 78, 79)
Select_7.BorderSizePixel = 0
Select_7.Position = UDim2.new(0, 200, 0, 0)
Select_7.Size = UDim2.new(0, 50, 0, 20)
Select_7.Font = Enum.Font.SourceSans
Select_7.TextSize = 14
Select_7.Text = "Edit"
Select_7.TextColor3 = Color3.new(0, 0, 0)
Select_7.ZIndex = 10
table.insert(shade3,Select_7)
table.insert(text2,Select_7)

StayOpen.Name = "StayOpen"
StayOpen.Parent = Settings
StayOpen.BackgroundColor3 = Color3.fromRGB(46, 46, 47)
StayOpen.BorderSizePixel = 0
StayOpen.Position = UDim2.new(0, 0, 0, 30)
StayOpen.Size = UDim2.new(0, 250, 0, 20)
StayOpen.Font = Enum.Font.SourceSans
StayOpen.TextSize = 14
StayOpen.Text = "    Keep Menu Open"
StayOpen.TextColor3 = Color3.new(1, 1, 1)
StayOpen.TextXAlignment = Enum.TextXAlignment.Left
StayOpen.ZIndex = 10
table.insert(shade2,StayOpen)
table.insert(text1,StayOpen)

Button.Name = "Button"
Button.Parent = StayOpen
Button.BackgroundColor3 = Color3.fromRGB(78, 78, 79)
Button.BorderSizePixel = 0
Button.Position = UDim2.new(0, 230, 0, 0)
Button.Size = UDim2.new(0, 20, 0, 20)
Button.ZIndex = 10
table.insert(shade3,Button)

On.Name = "On"
On.Parent = Button
On.BackgroundColor3 = Color3.fromRGB(150, 150, 151)
On.BackgroundTransparency = 1
On.BorderSizePixel = 0
On.Position = UDim2.new(0, 2, 0, 2)
On.Size = UDim2.new(0, 16, 0, 16)
On.Font = Enum.Font.SourceSans
On.FontSize = Enum.FontSize.Size14
On.Text = ""
On.TextColor3 = Color3.new(0, 0, 0)
On.ZIndex = 10

Positions.Name = "Positions"
Positions.Parent = Settings
Positions.BackgroundColor3 = Color3.fromRGB(46, 46, 47)
Positions.BorderSizePixel = 0
Positions.Position = UDim2.new(0, 0, 0, 105)
Positions.Size = UDim2.new(0, 250, 0, 20)
Positions.Font = Enum.Font.SourceSans
Positions.TextSize = 14
Positions.Text = "    Waypoints / Positions / Part TP"
Positions.TextColor3 = Color3.new(1, 1, 1)
Positions.TextXAlignment = Enum.TextXAlignment.Left
Positions.ZIndex = 10
table.insert(shade2,Positions)
table.insert(text1,Positions)

Select_8.Name = "Select"
Select_8.Parent = Positions
Select_8.BackgroundColor3 = Color3.fromRGB(78, 78, 79)
Select_8.BorderSizePixel = 0
Select_8.Position = UDim2.new(0, 200, 0, 0)
Select_8.Size = UDim2.new(0, 50, 0, 20)
Select_8.Font = Enum.Font.SourceSans
Select_8.TextSize = 14
Select_8.Text = "Edit / TP"
Select_8.TextColor3 = Color3.new(0, 0, 0)
Select_8.ZIndex = 10
table.insert(shade3,Select_8)
table.insert(text2,Select_8)

SpawnC.Name = "SpawnC"
SpawnC.Parent = Settings
SpawnC.BackgroundColor3 = Color3.fromRGB(46, 46, 47)
SpawnC.BorderSizePixel = 0
SpawnC.Position = UDim2.new(0, 0, 0, 155)
SpawnC.Size = UDim2.new(0, 250, 0, 20)
SpawnC.Font = Enum.Font.SourceSans
SpawnC.TextSize = 14
SpawnC.Text = "    Spawn Commands"
SpawnC.TextColor3 = Color3.new(1, 1, 1)
SpawnC.TextXAlignment = Enum.TextXAlignment.Left
SpawnC.ZIndex = 10
table.insert(shade2,SpawnC)
table.insert(text1,SpawnC)

Select_2.Name = "Select"
Select_2.Parent = SpawnC
Select_2.BackgroundColor3 = Color3.fromRGB(78, 78, 79)
Select_2.BorderSizePixel = 0
Select_2.Position = UDim2.new(0, 200, 0, 0)
Select_2.Size = UDim2.new(0, 50, 0, 20)
Select_2.Font = Enum.Font.SourceSans
Select_2.TextSize = 14
Select_2.Text = "Edit"
Select_2.TextColor3 = Color3.new(0, 0, 0)
Select_2.ZIndex = 10
table.insert(shade3,Select_2)
table.insert(text2,Select_2)

Plugins.Name = "Plugins"
Plugins.Parent = Settings
Plugins.BackgroundColor3 = Color3.fromRGB(46, 46, 47)
Plugins.BorderSizePixel = 0
Plugins.Position = UDim2.new(0, 0, 0, 130)
Plugins.Size = UDim2.new(0, 250, 0, 20)
Plugins.Font = Enum.Font.SourceSans
Plugins.TextSize = 14
Plugins.Text = "    Plugins"
Plugins.TextColor3 = Color3.new(1, 1, 1)
Plugins.TextXAlignment = Enum.TextXAlignment.Left
Plugins.ZIndex = 10
table.insert(shade2,Plugins)
table.insert(text1,Plugins)

Select_9.Name = "Select"
Select_9.Parent = Plugins
Select_9.BackgroundColor3 = Color3.fromRGB(78, 78, 79)
Select_9.BorderSizePixel = 0
Select_9.Position = UDim2.new(0, 200, 0, 0)
Select_9.Size = UDim2.new(0, 50, 0, 20)
Select_9.Font = Enum.Font.SourceSans
Select_9.TextSize = 14
Select_9.Text = "Edit"
Select_9.TextColor3 = Color3.new(0, 0, 0)
Select_9.ZIndex = 10
table.insert(shade3,Select_9)
table.insert(text2,Select_9)

Example.Name = "Example"
Example.Parent = Holder
Example.BackgroundTransparency = 1
Example.BorderSizePixel = 0
Example.Size = UDim2.new(0, 190, 0, 20)
Example.Visible = false
Example.Font = Enum.Font.SourceSans
Example.TextSize = 18
Example.Text = "Example"
Example.TextColor3 = Color3.new(1, 1, 1)
Example.TextXAlignment = Enum.TextXAlignment.Left
Example.ZIndex = 10
table.insert(text1,Example)

Notification.Name = randomString()
Notification.Parent = PARENT
Notification.BackgroundColor3 = Color3.fromRGB(36, 36, 37)
Notification.BorderSizePixel = 0
Notification.Position = UDim2.new(1, -500, 1, 20)
Notification.Size = UDim2.new(0, 250, 0, 100)
Notification.ZIndex = 10
table.insert(shade1,Notification)

Title_2.Name = "Title"
Title_2.Parent = Notification
Title_2.BackgroundColor3 = Color3.fromRGB(46, 46, 47)
Title_2.BorderSizePixel = 0
Title_2.Size = UDim2.new(0, 250, 0, 20)
Title_2.Font = Enum.Font.SourceSans
Title_2.TextSize = 14
Title_2.Text = "Notification Title"
Title_2.TextColor3 = Color3.new(1, 1, 1)
Title_2.ZIndex = 10
table.insert(shade2,Title_2)
table.insert(text1,Title_2)

Text_2.Name = "Text"
Text_2.Parent = Notification
Text_2.BackgroundTransparency = 1
Text_2.BorderSizePixel = 0
Text_2.Position = UDim2.new(0, 5, 0, 25)
Text_2.Size = UDim2.new(0, 240, 0, 75)
Text_2.Font = Enum.Font.SourceSans
Text_2.TextSize = 16
Text_2.Text = "Notification Text"
Text_2.TextColor3 = Color3.new(1, 1, 1)
Text_2.TextWrapped = true
Text_2.ZIndex = 10
table.insert(text1,Text_2)

CloseButton.Name = "CloseButton"
CloseButton.Parent = Notification
CloseButton.BackgroundTransparency = 1
CloseButton.Position = UDim2.new(0, 0, 0, 0)
CloseButton.Size = UDim2.new(0, 20, 0, 20)
CloseButton.Image = "rbxassetid://2132544126"
CloseButton.ZIndex = 10

Tooltip.Name = randomString()
Tooltip.Parent = PARENT
Tooltip.Active = true
Tooltip.BackgroundColor3 = Color3.fromRGB(36, 36, 37)
Tooltip.BackgroundTransparency = 0.1
Tooltip.BorderSizePixel = 0
Tooltip.Size = UDim2.new(0, 200, 0, 96)
Tooltip.Visible = false
Tooltip.ZIndex = 10
table.insert(shade1,Tooltip)

Title_3.Name = "Title"
Title_3.Parent = Tooltip
Title_3.BackgroundColor3 = Color3.fromRGB(46, 46, 47)
Title_3.BackgroundTransparency = 0.1
Title_3.BorderSizePixel = 0
Title_3.Size = UDim2.new(0, 200, 0, 20)
Title_3.Font = Enum.Font.SourceSans
Title_3.TextSize = 14
Title_3.Text = ""
Title_3.TextColor3 = Color3.new(1, 1, 1)
Title_3.TextTransparency = 0.1
Title_3.ZIndex = 10
table.insert(shade2,Title_3)
table.insert(text1,Title_3)

Description.Name = "Description"
Description.Parent = Tooltip
Description.BackgroundTransparency = 1
Description.BorderSizePixel = 0
Description.Size = UDim2.new(0,180,0,72)
Description.Position = UDim2.new(0,10,0,18)
Description.Font = Enum.Font.SourceSans
Description.TextSize = 16
Description.Text = ""
Description.TextColor3 = Color3.new(1, 1, 1)
Description.TextTransparency = 0.1
Description.TextWrapped = true
Description.ZIndex = 10
table.insert(text1,Description)

IntroBackground.Name = "IntroBackground"
IntroBackground.Parent = Holder
IntroBackground.Active = true
IntroBackground.BackgroundColor3 = Color3.fromRGB(36, 36, 37)
IntroBackground.BorderSizePixel = 0
IntroBackground.Position = UDim2.new(0, 0, 0, 45)
IntroBackground.Size = UDim2.new(0, 250, 0, 175)
IntroBackground.ZIndex = 10

Logo.Name = "Logo"
Logo.Parent = Holder
Logo.BackgroundTransparency = 1
Logo.BorderSizePixel = 0
Logo.Position = UDim2.new(0, 125, 0, 127)
Logo.Size = UDim2.new(0, 10, 0, 10)
Logo.Image = "rbxassetid://1352543873"
Logo.ImageTransparency = 0
Logo.ZIndex = 10

Credits.Name = "Credits"
Credits.Parent = Holder
Credits.BackgroundTransparency = 1
Credits.BorderSizePixel = 0
Credits.Position = UDim2.new(0, 0, 0.9, 30)
Credits.Size = UDim2.new(0, 250, 0, 20)
Credits.Font = Enum.Font.SourceSansLight
Credits.FontSize = Enum.FontSize.Size18
Credits.Text = "Edge // Zwolf // Moon"
Credits.TextColor3 = Color3.new(1, 1, 1)
Credits.ZIndex = 10

KeybindsFrame.Name = "KeybindsFrame"
KeybindsFrame.Parent = Settings
KeybindsFrame.Active = true
KeybindsFrame.BackgroundColor3 = Color3.fromRGB(36, 36, 37)
KeybindsFrame.BorderSizePixel = 0
KeybindsFrame.Position = UDim2.new(0, 0, 0, 175)
KeybindsFrame.Size = UDim2.new(0, 250, 0, 175)
KeybindsFrame.ZIndex = 10
table.insert(shade1,KeybindsFrame)

Close.Name = "Close"
Close.Parent = KeybindsFrame
Close.BackgroundColor3 = Color3.fromRGB(46, 46, 47)
Close.BorderSizePixel = 0
Close.Position = UDim2.new(0, 205, 0, 150)
Close.Size = UDim2.new(0, 40, 0, 20)
Close.Font = Enum.Font.SourceSans
Close.TextSize = 14
Close.Text = "Close"
Close.TextColor3 = Color3.new(1, 1, 1)
Close.ZIndex = 10
table.insert(shade2,Close)
table.insert(text1,Close)

Add.Name = "Add"
Add.Parent = KeybindsFrame
Add.BackgroundColor3 = Color3.fromRGB(46, 46, 47)
Add.BorderSizePixel = 0
Add.Position = UDim2.new(0, 5, 0, 150)
Add.Size = UDim2.new(0, 40, 0, 20)
Add.Font = Enum.Font.SourceSans
Add.TextSize = 14
Add.Text = "Add"
Add.TextColor3 = Color3.new(1, 1, 1)
Add.ZIndex = 10
table.insert(shade2,Add)
table.insert(text1,Add)

Delete.Name = "Delete"
Delete.Parent = KeybindsFrame
Delete.BackgroundColor3 = Color3.fromRGB(46, 46, 47)
Delete.BorderSizePixel = 0
Delete.Position = UDim2.new(0, 50, 0, 150)
Delete.Size = UDim2.new(0, 40, 0, 20)
Delete.Font = Enum.Font.SourceSans
Delete.TextSize = 14
Delete.Text = "Clear"
Delete.TextColor3 = Color3.new(1, 1, 1)
Delete.ZIndex = 10
table.insert(shade2,Delete)
table.insert(text1,Delete)

Holder_2.Name = "Holder"
Holder_2.Parent = KeybindsFrame
Holder_2.BackgroundTransparency = 1
Holder_2.BorderSizePixel = 0
Holder_2.Position = UDim2.new(0, 0, 0, 0)
Holder_2.Size = UDim2.new(0, 250, 0, 145)
Holder_2.ScrollBarImageColor3 = Color3.fromRGB(78,78,79)
Holder_2.BottomImage = "rbxasset://textures/ui/Scroll/scroll-middle.png"
Holder_2.CanvasSize = UDim2.new(0, 0, 0, 0)
Holder_2.MidImage = "rbxasset://textures/ui/Scroll/scroll-middle.png"
Holder_2.ScrollBarThickness = 0
Holder_2.TopImage = "rbxasset://textures/ui/Scroll/scroll-middle.png"
Holder_2.VerticalScrollBarInset = 'Always'
Holder_2.ZIndex = 10

Example_2.Name = "Example"
Example_2.Parent = KeybindsFrame
Example_2.BackgroundColor3 = Color3.fromRGB(46, 46, 47)
Example_2.BorderSizePixel = 0
Example_2.Size = UDim2.new(0, 10, 0, 20)
Example_2.Visible = false
Example_2.ZIndex = 10
table.insert(shade2,Example_2)

Text_3.Name = "Text"
Text_3.Parent = Example_2
Text_3.BackgroundColor3 = Color3.fromRGB(46, 46, 47)
Text_3.BorderSizePixel = 0
Text_3.Position = UDim2.new(0, 10, 0, 0)
Text_3.Size = UDim2.new(0, 240, 0, 20)
Text_3.Font = Enum.Font.SourceSans
Text_3.TextSize = 14
Text_3.Text = "nom"
Text_3.TextColor3 = Color3.new(1, 1, 1)
Text_3.TextXAlignment = Enum.TextXAlignment.Left
Text_3.ZIndex = 10
table.insert(shade2,Text_3)
table.insert(text1,Text_3)

Delete_2.Name = "Delete"
Delete_2.Parent = Text_3
Delete_2.BackgroundColor3 = Color3.fromRGB(78, 78, 79)
Delete_2.BorderSizePixel = 0
Delete_2.Position = UDim2.new(0, 200, 0, 0)
Delete_2.Size = UDim2.new(0, 40, 0, 20)
Delete_2.Font = Enum.Font.SourceSans
Delete_2.TextSize = 14
Delete_2.Text = "Delete"
Delete_2.TextColor3 = Color3.new(0, 0, 0)
Delete_2.ZIndex = 10
table.insert(shade3,Delete_2)
table.insert(text2,Delete_2)

KeybindEditor.Name = randomString()
KeybindEditor.Parent = PARENT
KeybindEditor.Active = true
KeybindEditor.BackgroundTransparency = 1
KeybindEditor.Position = UDim2.new(0.5, -180, 0, -400)
KeybindEditor.Size = UDim2.new(0, 360, 0, 20)
KeybindEditor.ZIndex = 10

background_2.Name = "background"
background_2.Parent = KeybindEditor
background_2.Active = true
background_2.BackgroundColor3 = Color3.fromRGB(36, 36, 37)
background_2.BorderSizePixel = 0
background_2.Position = UDim2.new(0, 0, 0, 20)
background_2.Size = UDim2.new(0, 360, 0, 185)
background_2.ZIndex = 10
table.insert(shade1,background_2)

Dark_4.Name = "Dark"
Dark_4.Parent = background_2
Dark_4.Active = true
Dark_4.BackgroundColor3 = Color3.fromRGB(46, 46, 47)
Dark_4.BorderSizePixel = 0
Dark_4.Position = UDim2.new(0, 135, 0, 0)
Dark_4.Size = UDim2.new(0, 2, 0, 185)
Dark_4.ZIndex = 10
table.insert(shade2,Dark_4)

Directions.Name = "Directions"
Directions.Parent = background_2
Directions.BackgroundTransparency = 1
Directions.BorderSizePixel = 0
Directions.Position = UDim2.new(0, 10, 0, 15)
Directions.Size = UDim2.new(0, 115, 0, 90)
Directions.Font = Enum.Font.SourceSans
Directions.TextSize = 14
Directions.Text = "Click the button below and press a key/mouse button. Then select what you want to bind it to."
Directions.TextColor3 = Color3.new(1, 1, 1)
Directions.TextWrapped = true
Directions.TextYAlignment = Enum.TextYAlignment.Top
Directions.ZIndex = 10
table.insert(text1,Directions)

BindTo.Name = "BindTo"
BindTo.Parent = background_2
BindTo.BackgroundColor3 = Color3.fromRGB(46, 46, 47)
BindTo.BorderSizePixel = 0
BindTo.Position = UDim2.new(0, 10, 0, 95)
BindTo.Size = UDim2.new(0, 115, 0, 75)
BindTo.Font = Enum.Font.SourceSans
BindTo.TextSize = 16
BindTo.Text = "Click to bind"
BindTo.TextColor3 = Color3.new(1, 1, 1)
BindTo.ZIndex = 10
table.insert(shade2,BindTo)
table.insert(text1,BindTo)

Add_2.Name = "Add"
Add_2.Parent = background_2
Add_2.BackgroundColor3 = Color3.fromRGB(46, 46, 47)
Add_2.BorderSizePixel = 0
Add_2.Position = UDim2.new(0, 310, 0, 20)
Add_2.Size = UDim2.new(0, 40, 0, 20)
Add_2.Font = Enum.Font.SourceSans
Add_2.TextSize = 14
Add_2.Text = "Add"
Add_2.TextColor3 = Color3.new(1, 1, 1)
Add_2.ZIndex = 10
table.insert(shade2,Add_2)
table.insert(text1,Add_2)

Cmdbar_2.Name = "Cmdbar"
Cmdbar_2.Parent = background_2
Cmdbar_2.BackgroundColor3 = Color3.fromRGB(46, 46, 47)
Cmdbar_2.BorderSizePixel = 0
Cmdbar_2.Position = UDim2.new(0, 150, 0, 20)
Cmdbar_2.Size = UDim2.new(0, 150, 0, 20)
Cmdbar_2.Font = Enum.Font.SourceSans
Cmdbar_2.TextSize = 14
Cmdbar_2.Text = "Command"
Cmdbar_2.TextColor3 = Color3.new(1, 1, 1)
Cmdbar_2.TextScaled = true
Cmdbar_2.TextWrapped = true
Cmdbar_2.ZIndex = 10
table.insert(shade2,Cmdbar_2)
table.insert(text1,Cmdbar_2)

Toggles.Name = "Toggles"
Toggles.Parent = background_2
Toggles.BackgroundTransparency = 1
Toggles.BorderSizePixel = 0
Toggles.Position = UDim2.new(0, 150, 0, 50)
Toggles.Size = UDim2.new(0, 200, 0, 125)
Toggles.ScrollBarImageColor3 = Color3.fromRGB(78,78,79)
Toggles.BottomImage = "rbxasset://textures/ui/Scroll/scroll-middle.png"
Toggles.CanvasSize = UDim2.new(0, 0, 0, 195)
Toggles.MidImage = "rbxasset://textures/ui/Scroll/scroll-middle.png"
Toggles.ScrollBarThickness = 8
Toggles.TopImage = "rbxasset://textures/ui/Scroll/scroll-middle.png"
Toggles.VerticalScrollBarInset = 'Always'
Toggles.ZIndex = 10
table.insert(scroll,Toggles)

Fly.Name = "Fly"
Fly.Parent = Toggles
Fly.BackgroundColor3 = Color3.fromRGB(46, 46, 47)
Fly.BorderSizePixel = 0
Fly.Size = UDim2.new(0, 192, 0, 20)
Fly.Font = Enum.Font.SourceSans
Fly.TextSize = 14
Fly.Text = "    Toggle Fly"
Fly.TextColor3 = Color3.new(1, 1, 1)
Fly.TextXAlignment = Enum.TextXAlignment.Left
Fly.ZIndex = 10
table.insert(shade2,Fly)
table.insert(text1,Fly)

Select_3.Name = "Select"
Select_3.Parent = Fly
Select_3.BackgroundColor3 = Color3.fromRGB(78, 78, 79)
Select_3.BorderSizePixel = 0
Select_3.Position = UDim2.new(0, 152, 0, 0)
Select_3.Size = UDim2.new(0, 40, 0, 20)
Select_3.Font = Enum.Font.SourceSans
Select_3.TextSize = 14
Select_3.Text = "Add"
Select_3.TextColor3 = Color3.new(0, 0, 0)
Select_3.ZIndex = 10
table.insert(shade3,Select_3)
table.insert(text2,Select_3)

Noclip.Name = "Noclip"
Noclip.Parent = Toggles
Noclip.BackgroundColor3 = Color3.fromRGB(46, 46, 47)
Noclip.BorderSizePixel = 0
Noclip.Position = UDim2.new(0, 0, 0, 25)
Noclip.Size = UDim2.new(0, 192, 0, 20)
Noclip.Font = Enum.Font.SourceSans
Noclip.TextSize = 14
Noclip.Text = "    Toggle Noclip"
Noclip.TextColor3 = Color3.new(1, 1, 1)
Noclip.TextXAlignment = Enum.TextXAlignment.Left
Noclip.ZIndex = 10
table.insert(shade2,Noclip)
table.insert(text1,Noclip)

Select_4.Name = "Select"
Select_4.Parent = Noclip
Select_4.BackgroundColor3 = Color3.fromRGB(78, 78, 79)
Select_4.BorderSizePixel = 0
Select_4.Position = UDim2.new(0, 152, 0, 0)
Select_4.Size = UDim2.new(0, 40, 0, 20)
Select_4.Font = Enum.Font.SourceSans
Select_4.TextSize = 14
Select_4.Text = "Add"
Select_4.TextColor3 = Color3.new(0, 0, 0)
Select_4.ZIndex = 10
table.insert(shade3,Select_4)
table.insert(text2,Select_4)

Float.Name = "Float"
Float.Parent = Toggles
Float.BackgroundColor3 = Color3.fromRGB(46, 46, 47)
Float.BorderSizePixel = 0
Float.Position = UDim2.new(0, 0, 0, 50)
Float.Size = UDim2.new(0, 192, 0, 20)
Float.Font = Enum.Font.SourceSans
Float.TextSize = 14
Float.Text = "    Toggle Float"
Float.TextColor3 = Color3.new(1, 1, 1)
Float.TextXAlignment = Enum.TextXAlignment.Left
Float.ZIndex = 10
table.insert(shade2,Float)
table.insert(text1,Float)

Select_5.Name = "Select"
Select_5.Parent = Float
Select_5.BackgroundColor3 = Color3.fromRGB(78, 78, 79)
Select_5.BorderSizePixel = 0
Select_5.Position = UDim2.new(0, 152, 0, 0)
Select_5.Size = UDim2.new(0, 40, 0, 20)
Select_5.Font = Enum.Font.SourceSans
Select_5.TextSize = 14
Select_5.Text = "Add"
Select_5.TextColor3 = Color3.new(0, 0, 0)
Select_5.ZIndex = 10
table.insert(shade3,Select_5)
table.insert(text2,Select_5)

ClickTP.Name = "Click TP"
ClickTP.Parent = Toggles
ClickTP.BackgroundColor3 = Color3.fromRGB(46, 46, 47)
ClickTP.BorderSizePixel = 0
ClickTP.Position = UDim2.new(0, 0, 0, 75)
ClickTP.Size = UDim2.new(0, 192, 0, 20)
ClickTP.Font = Enum.Font.SourceSans
ClickTP.TextSize = 14
ClickTP.Text = "    Click TP (Hold Key & Click)"
ClickTP.TextColor3 = Color3.new(1, 1, 1)
ClickTP.TextXAlignment = Enum.TextXAlignment.Left
ClickTP.ZIndex = 10
table.insert(shade2,ClickTP)
table.insert(text1,ClickTP)

Select_6.Name = "Select"
Select_6.Parent = ClickTP
Select_6.BackgroundColor3 = Color3.fromRGB(78, 78, 79)
Select_6.BorderSizePixel = 0
Select_6.Position = UDim2.new(0, 152, 0, 0)
Select_6.Size = UDim2.new(0, 40, 0, 20)
Select_6.Font = Enum.Font.SourceSans
Select_6.TextSize = 14
Select_6.Text = "Add"
Select_6.TextColor3 = Color3.new(0, 0, 0)
Select_6.ZIndex = 10
table.insert(shade3,Select_6)
table.insert(text2,Select_6)

ClickDelete.Name = "Click Delete"
ClickDelete.Parent = Toggles
ClickDelete.BackgroundColor3 = Color3.fromRGB(46, 46, 47)
ClickDelete.BorderSizePixel = 0
ClickDelete.Position = UDim2.new(0, 0, 0, 100)
ClickDelete.Size = UDim2.new(0, 192, 0, 20)
ClickDelete.Font = Enum.Font.SourceSans
ClickDelete.TextSize = 14
ClickDelete.Text = "    Click Delete (Hold Key & Click)"
ClickDelete.TextColor3 = Color3.new(1, 1, 1)
ClickDelete.TextXAlignment = Enum.TextXAlignment.Left
ClickDelete.ZIndex = 10
table.insert(shade2,ClickDelete)
table.insert(text1,ClickDelete)

Select_13.Name = "Select"
Select_13.Parent = ClickDelete
Select_13.BackgroundColor3 = Color3.fromRGB(78, 78, 79)
Select_13.BorderSizePixel = 0
Select_13.Position = UDim2.new(0, 152, 0, 0)
Select_13.Size = UDim2.new(0, 40, 0, 20)
Select_13.Font = Enum.Font.SourceSans
Select_13.TextSize = 14
Select_13.Text = "Add"
Select_13.TextColor3 = Color3.new(0, 0, 0)
Select_13.ZIndex = 10
table.insert(shade3,Select_13)
table.insert(text2,Select_13) 

Xray.Name = "Xray"
Xray.Parent = Toggles
Xray.BackgroundColor3 = Color3.fromRGB(46, 46, 47)
Xray.BorderSizePixel = 0
Xray.Position = UDim2.new(0, 0, 0, 125)
Xray.Size = UDim2.new(0, 192, 0, 20)
Xray.Font = Enum.Font.SourceSans
Xray.TextSize = 14
Xray.Text = "    Toggle Xray"
Xray.TextColor3 = Color3.new(1, 1, 1)
Xray.TextXAlignment = Enum.TextXAlignment.Left
Xray.ZIndex = 10
table.insert(shade2,Xray)
table.insert(text1,Xray)

Select_10.Name = "Select"
Select_10.Parent = Xray
Select_10.BackgroundColor3 = Color3.fromRGB(78, 78, 79)
Select_10.BorderSizePixel = 0
Select_10.Position = UDim2.new(0, 152, 0, 0)
Select_10.Size = UDim2.new(0, 40, 0, 20)
Select_10.Font = Enum.Font.SourceSans
Select_10.TextSize = 14
Select_10.Text = "Add"
Select_10.TextColor3 = Color3.new(0, 0, 0)
Select_10.ZIndex = 10
table.insert(shade3,Select_10)
table.insert(text2,Select_10)

Swim.Name = "Swim"
Swim.Parent = Toggles
Swim.BackgroundColor3 = Color3.fromRGB(46, 46, 47)
Swim.BorderSizePixel = 0
Swim.Position = UDim2.new(0, 0, 0, 150)
Swim.Size = UDim2.new(0, 192, 0, 20)
Swim.Font = Enum.Font.SourceSans
Swim.TextSize = 14
Swim.Text = "    Toggle Swim"
Swim.TextColor3 = Color3.new(1, 1, 1)
Swim.TextXAlignment = Enum.TextXAlignment.Left
Swim.ZIndex = 10
table.insert(shade2,Swim)
table.insert(text1,Swim)

Select_11.Name = "Select"
Select_11.Parent = Swim
Select_11.BackgroundColor3 = Color3.fromRGB(78, 78, 79)
Select_11.BorderSizePixel = 0
Select_11.Position = UDim2.new(0, 152, 0, 0)
Select_11.Size = UDim2.new(0, 40, 0, 20)
Select_11.Font = Enum.Font.SourceSans
Select_11.TextSize = 14
Select_11.Text = "Add"
Select_11.TextColor3 = Color3.new(0, 0, 0)
Select_11.ZIndex = 10
table.insert(shade3,Select_11)
table.insert(text2,Select_11)

Fling.Name = "Fling"
Fling.Parent = Toggles
Fling.BackgroundColor3 = Color3.fromRGB(46, 46, 47)
Fling.BorderSizePixel = 0
Fling.Position = UDim2.new(0, 0, 0, 175)
Fling.Size = UDim2.new(0, 192, 0, 20)
Fling.Font = Enum.Font.SourceSans
Fling.TextSize = 14
Fling.Text = "    Toggle Fling"
Fling.TextColor3 = Color3.new(1, 1, 1)
Fling.TextXAlignment = Enum.TextXAlignment.Left
Fling.ZIndex = 10
table.insert(shade2,Fling)
table.insert(text1,Fling)

Select_12.Name = "Select"
Select_12.Parent = Fling
Select_12.BackgroundColor3 = Color3.fromRGB(78, 78, 79)
Select_12.BorderSizePixel = 0
Select_12.Position = UDim2.new(0, 152, 0, 0)
Select_12.Size = UDim2.new(0, 40, 0, 20)
Select_12.Font = Enum.Font.SourceSans
Select_12.TextSize = 14
Select_12.Text = "Add"
Select_12.TextColor3 = Color3.new(0, 0, 0)
Select_12.ZIndex = 10
table.insert(shade3,Select_12)
table.insert(text2,Select_12)

shadow_2.Name = "shadow"
shadow_2.Parent = KeybindEditor
shadow_2.BackgroundColor3 = Color3.fromRGB(46, 46, 47)
shadow_2.BorderSizePixel = 0
shadow_2.Size = UDim2.new(0, 360, 0, 20)
shadow_2.ZIndex = 10
table.insert(shade2,shadow_2)

PopupText_2.Name = "PopupText"
PopupText_2.Parent = shadow_2
PopupText_2.BackgroundTransparency = 1
PopupText_2.Position = UDim2.new(0, 51, 0, 0)
PopupText_2.Size = UDim2.new(0.76, -16, 0.95, 0)
PopupText_2.ZIndex = 10
PopupText_2.Font = Enum.Font.SourceSans
PopupText_2.TextSize = 14
PopupText_2.Text = "Set Keybinds"
PopupText_2.TextColor3 = Color3.new(1, 1, 1)
PopupText_2.TextWrapped = true
table.insert(text1,PopupText_2)

Exit_2.Name = "Exit"
Exit_2.Parent = shadow_2
Exit_2.BackgroundTransparency = 1
Exit_2.Size = UDim2.new(0, 20, 0, 20)
Exit_2.ZIndex = 10
Exit_2.Image = "rbxassetid://2132544126"

SpawnCFrame.Name = "SpawnCFrame"
SpawnCFrame.Parent = Settings
SpawnCFrame.Active = true
SpawnCFrame.BackgroundColor3 = Color3.fromRGB(36, 36, 37)
SpawnCFrame.BorderSizePixel = 0
SpawnCFrame.Position = UDim2.new(0, 0, 0, 175)
SpawnCFrame.Size = UDim2.new(0, 250, 0, 175)
SpawnCFrame.ZIndex = 10
table.insert(shade1,SpawnCFrame)

Holder_6.Name = "Holder"
Holder_6.Parent = SpawnCFrame
Holder_6.BackgroundTransparency = 1
Holder_6.BorderSizePixel = 0
Holder_6.Position = UDim2.new(0, 0, 0, 0)
Holder_6.Selectable = false
Holder_6.Size = UDim2.new(0, 250, 0, 145)
Holder_6.ScrollBarImageColor3 = Color3.fromRGB(78,78,79)
Holder_6.BottomImage = "rbxasset://textures/ui/Scroll/scroll-middle.png"
Holder_6.CanvasSize = UDim2.new(0, 0, 0, 0)
Holder_6.MidImage = "rbxasset://textures/ui/Scroll/scroll-middle.png"
Holder_6.ScrollBarThickness = 8
Holder_6.TopImage = "rbxasset://textures/ui/Scroll/scroll-middle.png"
Holder_6.VerticalScrollBarInset = 'Always'
Holder_6.ZIndex = 10

Close_5.Name = "Close"
Close_5.Parent = SpawnCFrame
Close_5.BackgroundColor3 = Color3.fromRGB(46, 46, 47)
Close_5.BorderSizePixel = 0
Close_5.Position = UDim2.new(0, 205, 0, 150)
Close_5.Size = UDim2.new(0, 40, 0, 20)
Close_5.Font = Enum.Font.SourceSans
Close_5.TextSize = 14
Close_5.Text = "Close"
Close_5.TextColor3 = Color3.new(1, 1, 1)
Close_5.ZIndex = 10
table.insert(shade2,Close_5)
table.insert(text1,Close_5)

Add_4.Name = "Add"
Add_4.Parent = SpawnCFrame
Add_4.BackgroundColor3 = Color3.fromRGB(46, 46, 47)
Add_4.BorderSizePixel = 0
Add_4.Position = UDim2.new(0, 5, 0, 150)
Add_4.Size = UDim2.new(0, 40, 0, 20)
Add_4.Font = Enum.Font.SourceSans
Add_4.TextSize = 14
Add_4.Text = "Add"
Add_4.TextColor3 = Color3.new(1, 1, 1)
Add_4.ZIndex = 10
table.insert(shade2,Add_4)
table.insert(text1,Add_4)

Delete_8.Name = "Delete"
Delete_8.Parent = SpawnCFrame
Delete_8.BackgroundColor3 = Color3.fromRGB(46, 46, 47)
Delete_8.BorderSizePixel = 0
Delete_8.Position = UDim2.new(0, 50, 0, 150)
Delete_8.Size = UDim2.new(0, 40, 0, 20)
Delete_8.Font = Enum.Font.SourceSans
Delete_8.TextSize = 14
Delete_8.Text = "Clear"
Delete_8.TextColor3 = Color3.new(1, 1, 1)
Delete_8.ZIndex = 10
table.insert(shade2,Delete_8)
table.insert(text1,Delete_8)

SpawnCEditor.Name = randomString()
SpawnCEditor.Parent = PARENT
SpawnCEditor.Active = true
SpawnCEditor.BackgroundTransparency = 1
SpawnCEditor.Position = UDim2.new(0.5, -180, 0, -400)
SpawnCEditor.Size = UDim2.new(0, 360, 0, 20)
SpawnCEditor.ZIndex = 10

background_4.Name = "background"
background_4.Parent = SpawnCEditor
background_4.Active = true
background_4.BackgroundColor3 = Color3.fromRGB(36, 36, 37)
background_4.BorderSizePixel = 0
background_4.Position = UDim2.new(0, 0, 0, 20)
background_4.Size = UDim2.new(0, 360, 0, 75)
background_4.ZIndex = 10
table.insert(shade1,background_4)

Cmdbar_3.Name = "Cmdbar"
Cmdbar_3.Parent = background_4
Cmdbar_3.BackgroundColor3 = Color3.fromRGB(46, 46, 47)
Cmdbar_3.BorderSizePixel = 0
Cmdbar_3.Position = UDim2.new(0, 150, 0, 45)
Cmdbar_3.Size = UDim2.new(0, 150, 0, 20)
Cmdbar_3.Font = Enum.Font.SourceSans
Cmdbar_3.TextSize = 16
Cmdbar_3.Text = "Command"
Cmdbar_3.TextColor3 = Color3.new(1, 1, 1)
Cmdbar_3.TextScaled = true
Cmdbar_3.TextWrapped = true
Cmdbar_3.ZIndex = 10
table.insert(shade2,Cmdbar_3)
table.insert(text1,Cmdbar_3)

Add_5.Name = "Add"
Add_5.Parent = background_4
Add_5.BackgroundColor3 = Color3.fromRGB(46, 46, 47)
Add_5.BorderSizePixel = 0
Add_5.Position = UDim2.new(0, 310, 0, 45)
Add_5.Size = UDim2.new(0, 40, 0, 20)
Add_5.Font = Enum.Font.SourceSans
Add_5.TextSize = 14
Add_5.Text = "Add"
Add_5.TextColor3 = Color3.new(1, 1, 1)
Add_5.ZIndex = 10
table.insert(shade2,Add_5)
table.insert(text1,Add_5)

DelayNum.Name = "DelayNum"
DelayNum.Parent = background_4
DelayNum.BackgroundColor3 = Color3.fromRGB(46, 46, 47)
DelayNum.BorderSizePixel = 0
DelayNum.Position = UDim2.new(0, 310, 0, 15)
DelayNum.Size = UDim2.new(0, 40, 0, 20)
DelayNum.Font = Enum.Font.SourceSans
DelayNum.TextSize = 14
DelayNum.Text = "0"
DelayNum.TextColor3 = Color3.new(1, 1, 1)
DelayNum.TextScaled = true
DelayNum.TextWrapped = true
DelayNum.ZIndex = 10
table.insert(shade2,DelayNum)
table.insert(text1,DelayNum)

DelayT.Name = "Delay"
DelayT.Parent = background_4
DelayT.BackgroundTransparency = 1
DelayT.BorderSizePixel = 0
DelayT.Position = UDim2.new(0, 150, 0, 15)
DelayT.Size = UDim2.new(0, 150, 0, 20)
DelayT.Font = Enum.Font.SourceSans
DelayT.TextSize = 14
DelayT.Text = "Delay (seconds) (0 for none)"
DelayT.TextColor3 = Color3.new(1, 1, 1)
DelayT.TextWrapped = true
DelayT.ZIndex = 10
table.insert(text1,DelayT)

Directions_3.Name = "Directions"
Directions_3.Parent = background_4
Directions_3.BackgroundTransparency = 1
Directions_3.BorderSizePixel = 0
Directions_3.Position = UDim2.new(0, 20, 0, 10)
Directions_3.Size = UDim2.new(0, 98, 0, 60)
Directions_3.Font = Enum.Font.SourceSans
Directions_3.TextSize = 14
Directions_3.Text = "Spawn commands automatically get executed when you spawn."
Directions_3.TextColor3 = Color3.new(1, 1, 1)
Directions_3.TextWrapped = true
Directions_3.TextYAlignment = Enum.TextYAlignment.Top
Directions_3.ZIndex = 10
table.insert(text1,Directions_3)

Dark_11.Name = "Dark"
Dark_11.Parent = background_4
Dark_11.Active = true
Dark_11.BackgroundColor3 = Color3.fromRGB(46, 46, 47)
Dark_11.BorderSizePixel = 0
Dark_11.Position = UDim2.new(0.378, 0, 0, 0)
Dark_11.Size = UDim2.new(0, 2, 0, 75)
Dark_11.ZIndex = 10
table.insert(shade2,Dark_11)

shadow_4.Name = "shadow"
shadow_4.Parent = SpawnCEditor
shadow_4.BackgroundColor3 = Color3.fromRGB(46, 46, 47)
shadow_4.BorderSizePixel = 0
shadow_4.Size = UDim2.new(0, 360, 0, 20)
shadow_4.ZIndex = 10
table.insert(shade2,shadow_4)

PopupText_4.Name = "PopupText"
PopupText_4.Parent = shadow_4
PopupText_4.BackgroundTransparency = 1
PopupText_4.Position = UDim2.new(0, 51, 0, 0)
PopupText_4.Size = UDim2.new(0.760355055, -16, 0.949999988, 0)
PopupText_4.ZIndex = 10
PopupText_4.Font = Enum.Font.SourceSans
PopupText_4.TextSize = 14
PopupText_4.Text = "Set Spawn Commands"
PopupText_4.TextColor3 = Color3.new(1, 1, 1)
PopupText_4.TextWrapped = true
table.insert(text1,PopupText_4)

Exit_4.Name = "Exit"
Exit_4.Parent = shadow_4
Exit_4.BackgroundTransparency = 1
Exit_4.Size = UDim2.new(0, 20, 0, 20)
Exit_4.ZIndex = 10
Exit_4.Image = "rbxassetid://2132544126"

PositionsFrame.Name = "PositionsFrame"
PositionsFrame.Parent = Settings
PositionsFrame.Active = true
PositionsFrame.BackgroundColor3 = Color3.fromRGB(36, 36, 37)
PositionsFrame.BorderSizePixel = 0
PositionsFrame.Size = UDim2.new(0, 250, 0, 175)
PositionsFrame.Position = UDim2.new(0, 0, 0, 175)
PositionsFrame.ZIndex = 10
table.insert(shade1,PositionsFrame)

Close_3.Name = "Close"
Close_3.Parent = PositionsFrame
Close_3.BackgroundColor3 = Color3.fromRGB(46, 46, 47)
Close_3.BorderSizePixel = 0
Close_3.Position = UDim2.new(0, 205, 0, 150)
Close_3.Size = UDim2.new(0, 40, 0, 20)
Close_3.Font = Enum.Font.SourceSans
Close_3.TextSize = 14
Close_3.Text = "Close"
Close_3.TextColor3 = Color3.new(1, 1, 1)
Close_3.ZIndex = 10
table.insert(shade2,Close_3)
table.insert(text1,Close_3)

Delete_5.Name = "Delete"
Delete_5.Parent = PositionsFrame
Delete_5.BackgroundColor3 = Color3.fromRGB(46, 46, 47)
Delete_5.BorderSizePixel = 0
Delete_5.Position = UDim2.new(0, 50, 0, 150)
Delete_5.Size = UDim2.new(0, 40, 0, 20)
Delete_5.Font = Enum.Font.SourceSans
Delete_5.TextSize = 14
Delete_5.Text = "Clear"
Delete_5.TextColor3 = Color3.new(1, 1, 1)
Delete_5.ZIndex = 10
table.insert(shade2,Delete_5)
table.insert(text1,Delete_5)

Part.Name = "PartGoto"
Part.Parent = PositionsFrame
Part.BackgroundColor3 = Color3.fromRGB(46, 46, 47)
Part.BorderSizePixel = 0
Part.Position = UDim2.new(0, 5, 0, 150)
Part.Size = UDim2.new(0, 40, 0, 20)
Part.Font = Enum.Font.SourceSans
Part.TextSize = 14
Part.Text = "Part"
Part.TextColor3 = Color3.new(1, 1, 1)
Part.ZIndex = 10
table.insert(shade2,Part)
table.insert(text1,Part)

Holder_4.Name = "Holder"
Holder_4.Parent = PositionsFrame
Holder_4.BackgroundTransparency = 1
Holder_4.BorderSizePixel = 0
Holder_4.Position = UDim2.new(0, 0, 0, 0)
Holder_4.Selectable = false
Holder_4.Size = UDim2.new(0, 250, 0, 145)
Holder_4.ScrollBarImageColor3 = Color3.fromRGB(78,78,79)
Holder_4.BottomImage = "rbxasset://textures/ui/Scroll/scroll-middle.png"
Holder_4.CanvasSize = UDim2.new(0, 0, 0, 0)
Holder_4.MidImage = "rbxasset://textures/ui/Scroll/scroll-middle.png"
Holder_4.ScrollBarThickness = 8
Holder_4.TopImage = "rbxasset://textures/ui/Scroll/scroll-middle.png"
Holder_4.VerticalScrollBarInset = 'Always'
Holder_4.ZIndex = 10

Example_4.Name = "Example"
Example_4.Parent = PositionsFrame
Example_4.BackgroundColor3 = Color3.fromRGB(46, 46, 47)
Example_4.BorderSizePixel = 0
Example_4.Size = UDim2.new(0, 10, 0, 20)
Example_4.Visible = false
Example_4.Position = UDim2.new(0, 0, 0, -5)
Example_4.ZIndex = 10
table.insert(shade2,Example_4)

Text_5.Name = "Text"
Text_5.Parent = Example_4
Text_5.BackgroundColor3 = Color3.fromRGB(46, 46, 47)
Text_5.BorderSizePixel = 0
Text_5.Position = UDim2.new(0, 10, 0, 0)
Text_5.Size = UDim2.new(0, 240, 0, 20)
Text_5.Font = Enum.Font.SourceSans
Text_5.TextSize = 14
Text_5.Text = "Position"
Text_5.TextColor3 = Color3.new(1, 1, 1)
Text_5.TextXAlignment = Enum.TextXAlignment.Left
Text_5.ZIndex = 10
table.insert(shade2,Text_5)
table.insert(text1,Text_5)

Delete_6.Name = "Delete"
Delete_6.Parent = Text_5
Delete_6.BackgroundColor3 = Color3.fromRGB(78, 78, 79)
Delete_6.BorderSizePixel = 0
Delete_6.Position = UDim2.new(0, 200, 0, 0)
Delete_6.Size = UDim2.new(0, 40, 0, 20)
Delete_6.Font = Enum.Font.SourceSans
Delete_6.TextSize = 14
Delete_6.Text = "Delete"
Delete_6.TextColor3 = Color3.new(0, 0, 0)
Delete_6.ZIndex = 10
table.insert(shade3,Delete_6)
table.insert(text2,Delete_6)

TP.Name = "TP"
TP.Parent = Text_5
TP.BackgroundColor3 = Color3.fromRGB(78, 78, 79)
TP.BorderSizePixel = 0
TP.Position = UDim2.new(0, 155, 0, 0)
TP.Size = UDim2.new(0, 40, 0, 20)
TP.Font = Enum.Font.SourceSans
TP.TextSize = 14
TP.Text = "Goto"
TP.TextColor3 = Color3.new(0, 0, 0)
TP.ZIndex = 10
table.insert(shade3,TP)
table.insert(text2,TP)

AliasesFrame.Name = "AliasesFrame"
AliasesFrame.Parent = Settings
AliasesFrame.Active = true
AliasesFrame.BackgroundColor3 = Color3.fromRGB(36, 36, 37)
AliasesFrame.BorderSizePixel = 0
AliasesFrame.Position = UDim2.new(0, 0, 0, 175)
AliasesFrame.Size = UDim2.new(0, 250, 0, 175)
AliasesFrame.ZIndex = 10
table.insert(shade1,AliasesFrame)

Close_2.Name = "Close"
Close_2.Parent = AliasesFrame
Close_2.BackgroundColor3 = Color3.fromRGB(46, 46, 47)
Close_2.BorderSizePixel = 0
Close_2.Position = UDim2.new(0, 205, 0, 150)
Close_2.Size = UDim2.new(0, 40, 0, 20)
Close_2.Font = Enum.Font.SourceSans
Close_2.TextSize = 14
Close_2.Text = "Close"
Close_2.TextColor3 = Color3.new(1, 1, 1)
Close_2.ZIndex = 10
table.insert(shade2,Close_2)
table.insert(text1,Close_2)

Delete_3.Name = "Delete"
Delete_3.Parent = AliasesFrame
Delete_3.BackgroundColor3 = Color3.fromRGB(46, 46, 47)
Delete_3.BorderSizePixel = 0
Delete_3.Position = UDim2.new(0, 5, 0, 150)
Delete_3.Size = UDim2.new(0, 40, 0, 20)
Delete_3.Font = Enum.Font.SourceSans
Delete_3.TextSize = 14
Delete_3.Text = "Clear"
Delete_3.TextColor3 = Color3.new(1, 1, 1)
Delete_3.ZIndex = 10
table.insert(shade2,Delete_3)
table.insert(text1,Delete_3)

Holder_3.Name = "Holder"
Holder_3.Parent = AliasesFrame
Holder_3.BackgroundTransparency = 1
Holder_3.BorderSizePixel = 0
Holder_3.Position = UDim2.new(0, 0, 0, 0)
Holder_3.Size = UDim2.new(0, 250, 0, 145)
Holder_3.ScrollBarImageColor3 = Color3.fromRGB(78,78,79)
Holder_3.BottomImage = "rbxasset://textures/ui/Scroll/scroll-middle.png"
Holder_3.CanvasSize = UDim2.new(0, 0, 0, 0)
Holder_3.MidImage = "rbxasset://textures/ui/Scroll/scroll-middle.png"
Holder_3.ScrollBarThickness = 0
Holder_3.TopImage = "rbxasset://textures/ui/Scroll/scroll-middle.png"
Holder_3.VerticalScrollBarInset = 'Always'
Holder_3.ZIndex = 10

Example_3.Name = "Example"
Example_3.Parent = AliasesFrame
Example_3.BackgroundColor3 = Color3.fromRGB(46, 46, 47)
Example_3.BorderSizePixel = 0
Example_3.Size = UDim2.new(0, 10, 0, 20)
Example_3.Visible = false
Example_3.ZIndex = 10
table.insert(shade2,Example_3)

Text_4.Name = "Text"
Text_4.Parent = Example_3
Text_4.BackgroundColor3 = Color3.fromRGB(46, 46, 47)
Text_4.BorderSizePixel = 0
Text_4.Position = UDim2.new(0, 10, 0, 0)
Text_4.Size = UDim2.new(0, 240, 0, 20)
Text_4.Font = Enum.Font.SourceSans
Text_4.TextSize = 14
Text_4.Text = "honk"
Text_4.TextColor3 = Color3.new(1, 1, 1)
Text_4.TextXAlignment = Enum.TextXAlignment.Left
Text_4.ZIndex = 10
table.insert(shade2,Text_4)
table.insert(text1,Text_4)

Delete_4.Name = "Delete"
Delete_4.Parent = Text_4
Delete_4.BackgroundColor3 = Color3.fromRGB(78, 78, 79)
Delete_4.BorderSizePixel = 0
Delete_4.Position = UDim2.new(0, 200, 0, 0)
Delete_4.Size = UDim2.new(0, 40, 0, 20)
Delete_4.Font = Enum.Font.SourceSans
Delete_4.TextSize = 14
Delete_4.Text = "Delete"
Delete_4.TextColor3 = Color3.new(0, 0, 0)
Delete_4.ZIndex = 10
table.insert(shade3,Delete_4)
table.insert(text2,Delete_4)

PluginsFrame.Name = "PluginsFrame"
PluginsFrame.Parent = Settings
PluginsFrame.Active = true
PluginsFrame.BackgroundColor3 = Color3.fromRGB(36, 36, 37)
PluginsFrame.BorderSizePixel = 0
PluginsFrame.Position = UDim2.new(0, 0, 0, 175)
PluginsFrame.Size = UDim2.new(0, 250, 0, 175)
PluginsFrame.ZIndex = 10
table.insert(shade1,PluginsFrame)

Close_4.Name = "Close"
Close_4.Parent = PluginsFrame
Close_4.BackgroundColor3 = Color3.fromRGB(46, 46, 47)
Close_4.BorderSizePixel = 0
Close_4.Position = UDim2.new(0, 205, 0, 150)
Close_4.Size = UDim2.new(0, 40, 0, 20)
Close_4.Font = Enum.Font.SourceSans
Close_4.TextSize = 14
Close_4.Text = "Close"
Close_4.TextColor3 = Color3.new(1, 1, 1)
Close_4.ZIndex = 10
table.insert(shade2,Close_4)
table.insert(text1,Close_4)

Add_3.Name = "Add"
Add_3.Parent = PluginsFrame
Add_3.BackgroundColor3 = Color3.fromRGB(46, 46, 47)
Add_3.BorderSizePixel = 0
Add_3.Position = UDim2.new(0, 5, 0, 150)
Add_3.Size = UDim2.new(0, 40, 0, 20)
Add_3.Font = Enum.Font.SourceSans
Add_3.TextSize = 14
Add_3.Text = "Add"
Add_3.TextColor3 = Color3.new(1, 1, 1)
Add_3.ZIndex = 10
table.insert(shade2,Add_3)
table.insert(text1,Add_3)

Holder_5.Name = "Holder"
Holder_5.Parent = PluginsFrame
Holder_5.BackgroundTransparency = 1
Holder_5.BorderSizePixel = 0
Holder_5.Position = UDim2.new(0, 0, 0, 0)
Holder_5.Selectable = false
Holder_5.Size = UDim2.new(0, 250, 0, 140)
Holder_5.ScrollBarImageColor3 = Color3.fromRGB(78,78,79)
Holder_5.BottomImage = "rbxasset://textures/ui/Scroll/scroll-middle.png"
Holder_5.CanvasSize = UDim2.new(0, 0, 0, 0)
Holder_5.MidImage = "rbxasset://textures/ui/Scroll/scroll-middle.png"
Holder_5.ScrollBarThickness = 0
Holder_5.TopImage = "rbxasset://textures/ui/Scroll/scroll-middle.png"
Holder_5.VerticalScrollBarInset = 'Always'
Holder_5.ZIndex = 10

Example_5.Name = "Example"
Example_5.Parent = PluginsFrame
Example_5.BackgroundColor3 = Color3.fromRGB(46, 46, 47)
Example_5.BorderSizePixel = 0
Example_5.Size = UDim2.new(0, 10, 0, 20)
Example_5.Visible = false
Example_5.ZIndex = 10
table.insert(shade2,Example_5)

Text_6.Name = "Text"
Text_6.Parent = Example_5
Text_6.BackgroundColor3 = Color3.fromRGB(46, 46, 47)
Text_6.BorderSizePixel = 0
Text_6.Position = UDim2.new(0, 10, 0, 0)
Text_6.Size = UDim2.new(0, 240, 0, 20)
Text_6.Font = Enum.Font.SourceSans
Text_6.TextSize = 14
Text_6.Text = "F4 > Toggle Fly"
Text_6.TextColor3 = Color3.new(1, 1, 1)
Text_6.TextXAlignment = Enum.TextXAlignment.Left
Text_6.ZIndex = 10
table.insert(shade2,Text_6)
table.insert(text1,Text_6)

Delete_7.Name = "Delete"
Delete_7.Parent = Text_6
Delete_7.BackgroundColor3 = Color3.fromRGB(78, 78, 79)
Delete_7.BorderSizePixel = 0
Delete_7.Position = UDim2.new(0, 200, 0, 0)
Delete_7.Size = UDim2.new(0, 40, 0, 20)
Delete_7.Font = Enum.Font.SourceSans
Delete_7.TextSize = 14
Delete_7.Text = "Delete"
Delete_7.TextColor3 = Color3.new(0, 0, 0)
Delete_7.ZIndex = 10
table.insert(shade3,Delete_7)
table.insert(text2,Delete_7)

PluginEditor.Name = randomString()
PluginEditor.Parent = PARENT
PluginEditor.BorderSizePixel = 0
PluginEditor.Active = true
PluginEditor.BackgroundTransparency = 1
PluginEditor.Position = UDim2.new(0.5, -180, 0, -400)
PluginEditor.Size = UDim2.new(0, 360, 0, 20)
PluginEditor.ZIndex = 10

background_3.Name = "background"
background_3.Parent = PluginEditor
background_3.Active = true
background_3.BackgroundColor3 = Color3.fromRGB(36, 36, 37)
background_3.BorderSizePixel = 0
background_3.Position = UDim2.new(0, 0, 0, 20)
background_3.Size = UDim2.new(0, 360, 0, 160)
background_3.ZIndex = 10
table.insert(shade1,background_3)

Dark_9.Name = "Dark"
Dark_9.Parent = background_3
Dark_9.Active = true
Dark_9.BackgroundColor3 = Color3.fromRGB(46, 46, 47)
Dark_9.BackgroundTransparency = 0
Dark_9.BorderSizePixel = 0
Dark_9.Position = UDim2.new(0, 222, 0, 0)
Dark_9.Size = UDim2.new(0, 2, 0, 160)
Dark_9.ZIndex = 10
table.insert(shade2,Dark_9)

Img.Name = "Img"
Img.Parent = background_3
Img.BackgroundTransparency = 1
Img.Position = UDim2.new(0, 242, 0, 3)
Img.Size = UDim2.new(0, 100, 0, 95)
Img.Image = "rbxassetid://4113050383"
Img.ZIndex = 10

AddPlugin.Name = "AddPlugin"
AddPlugin.Parent = background_3
AddPlugin.BackgroundColor3 = Color3.fromRGB(46, 46, 47)
AddPlugin.BorderSizePixel = 0
AddPlugin.Position = UDim2.new(0, 235, 0, 100)
AddPlugin.Size = UDim2.new(0, 115, 0, 50)
AddPlugin.Font = Enum.Font.SourceSans
AddPlugin.TextSize = 14
AddPlugin.Text = "Add Plugin"
AddPlugin.TextColor3 = Color3.new(1, 1, 1)
AddPlugin.ZIndex = 10
table.insert(shade2,AddPlugin)
table.insert(text1,AddPlugin)

FileName.Name = "FileName"
FileName.Parent = background_3
FileName.BackgroundColor3 = Color3.fromRGB(46, 46, 47)
FileName.BorderSizePixel = 0
FileName.Position = UDim2.new(0.028, 0, 0.625, 0)
FileName.Size = UDim2.new(0, 200, 0, 50)
FileName.Font = Enum.Font.SourceSans
FileName.TextSize = 14
FileName.Text = "Plugin File Name"
FileName.TextColor3 = Color3.new(1, 1, 1)
FileName.ZIndex = 10
table.insert(shade2,FileName)
table.insert(text1,FileName)

About.Name = "About"
About.Parent = background_3
About.BackgroundTransparency = 1
About.BorderSizePixel = 0
About.Position = UDim2.new(0, 17, 0, 10)
About.Size = UDim2.new(0, 187, 0, 49)
About.Font = Enum.Font.SourceSans
About.TextSize = 14
About.Text = "Plugins are .iy files and should be located in the 'workspace' folder of your exploit."
About.TextColor3 = Color3.fromRGB(255, 255, 255)
About.TextWrapped = true
About.TextYAlignment = Enum.TextYAlignment.Top
About.ZIndex = 10
table.insert(text1,About)

Directions_2.Name = "Directions"
Directions_2.Parent = background_3
Directions_2.BackgroundTransparency = 1
Directions_2.BorderSizePixel = 0
Directions_2.Position = UDim2.new(0, 17, 0, 60)
Directions_2.Size = UDim2.new(0, 187, 0, 49)
Directions_2.Font = Enum.Font.SourceSans
Directions_2.TextSize = 14
Directions_2.Text = "Type the name of the plugin file you want to add below."
Directions_2.TextColor3 = Color3.fromRGB(255, 255, 255)
Directions_2.TextWrapped = true
Directions_2.TextYAlignment = Enum.TextYAlignment.Top
Directions_2.ZIndex = 10
table.insert(text1,Directions_2)

shadow_3.Name = "shadow"
shadow_3.Parent = PluginEditor
shadow_3.BackgroundColor3 = Color3.fromRGB(46, 46, 47)
shadow_3.BorderSizePixel = 0
shadow_3.Size = UDim2.new(0, 360, 0, 20)
shadow_3.ZIndex = 10
table.insert(shade2,shadow_3)

PopupText_3.Name = "PopupText"
PopupText_3.Parent = shadow_3
PopupText_3.BackgroundTransparency = 1
PopupText_3.Position = UDim2.new(0, 51, 0, 0)
PopupText_3.Size = UDim2.new(0.76, -16, 0.95, 0)
PopupText_3.ZIndex = 10
PopupText_3.Font = Enum.Font.SourceSans
PopupText_3.TextSize = 14
PopupText_3.Text = "Add Plugins"
PopupText_3.TextColor3 = Color3.new(1, 1, 1)
PopupText_3.TextWrapped = true
table.insert(text1,PopupText_3)

Exit_3.Name = "Exit"
Exit_3.Parent = shadow_3
Exit_3.BackgroundTransparency = 1
Exit_3.Size = UDim2.new(0, 20, 0, 20)
Exit_3.ZIndex = 10
Exit_3.Image = "rbxassetid://2132544126"

logsDrag.Name = randomString()
logsDrag.Parent = PARENT
logsDrag.Active = true
logsDrag.BackgroundTransparency = 1
logsDrag.Position = UDim2.new(0, 0, 1, 10)
logsDrag.Size = UDim2.new(0, 338, 0, 20)
logsDrag.ZIndex = 10

shadow.Name = "shadow"
shadow.Parent = logsDrag
shadow.BackgroundColor3 = Color3.fromRGB(46, 46, 47)
shadow.BorderSizePixel = 0
shadow.Position = UDim2.new(0, 0, 0.01, 0)
shadow.Size = UDim2.new(0, 338, 0, 20)
shadow.ZIndex = 10
table.insert(shade2,shadow)

Hide.Name = "Hide"
Hide.Parent = shadow
Hide.BackgroundTransparency = 1
Hide.Position = UDim2.new(0, 20, 0, 0)
Hide.Size = UDim2.new(0, 20, 0, 20)
Hide.ZIndex = 10
Hide.Image = "rbxassetid://2406617031"
Hide.ImageTransparency = 0.5

PopupText.Name = "PopupText"
PopupText.Parent = shadow
PopupText.BackgroundTransparency = 1
PopupText.Position = UDim2.new(0, 48, 0, 0)
PopupText.Size = UDim2.new(0.76, -16, 0.95, 0)
PopupText.ZIndex = 10
PopupText.Font = Enum.Font.SourceSans
PopupText.TextSize = 14
PopupText.Text = "Chat Logs"
PopupText.TextColor3 = Color3.new(1, 1, 1)
PopupText.TextWrapped = true
table.insert(text1,PopupText)

Exit.Name = "Exit"
Exit.Parent = shadow
Exit.BackgroundTransparency = 1
Exit.Size = UDim2.new(0, 20, 0, 20)
Exit.ZIndex = 10
Exit.Image = "rbxassetid://2132544126"

background.Name = "background"
background.Parent = logsDrag
background.Active = true
background.BackgroundColor3 = Color3.fromRGB(36, 36, 37)
background.BorderSizePixel = 0
background.Position = UDim2.new(0, 0, 1, 0)
background.Size = UDim2.new(0, 338, 0, 225)
background.ZIndex = 10
table.insert(shade1,background)

Clear.Name = "Clear"
Clear.Parent = background
Clear.BackgroundColor3 = Color3.fromRGB(46, 46, 47)
Clear.BorderSizePixel = 0
Clear.Position = UDim2.new(0, 5, 0, 200)
Clear.Size = UDim2.new(0, 50, 0, 20)
Clear.ZIndex = 10
Clear.Font = Enum.Font.SourceSans
Clear.TextSize = 14
Clear.Text = "Clear"
Clear.TextColor3 = Color3.new(1, 1, 1)
table.insert(shade2,Clear)
table.insert(text1,Clear)

Toggle.Name = "Toggle"
Toggle.Parent = background
Toggle.BackgroundColor3 = Color3.fromRGB(46, 46, 47)
Toggle.BorderSizePixel = 0
Toggle.Position = UDim2.new(0, 60, 0, 200)
Toggle.Size = UDim2.new(0, 66, 0, 20)
Toggle.ZIndex = 10
Toggle.Font = Enum.Font.SourceSans
Toggle.TextSize = 14
Toggle.Text = "Disabled"
Toggle.TextColor3 = Color3.new(1, 1, 1)
table.insert(shade2,Toggle)
table.insert(text1,Toggle)

SaveChatlogs.Name = "SaveChatlogs"
SaveChatlogs.Parent = background
SaveChatlogs.BackgroundColor3 = Color3.fromRGB(46, 46, 47)
SaveChatlogs.BorderSizePixel = 0
SaveChatlogs.Position = UDim2.new(0, 258, 0, 200)
SaveChatlogs.Size = UDim2.new(0, 75, 0, 20)
SaveChatlogs.ZIndex = 10
SaveChatlogs.Font = Enum.Font.SourceSans
SaveChatlogs.TextSize = 14
SaveChatlogs.Text = "Save To .txt"
SaveChatlogs.TextColor3 = Color3.new(1, 1, 1)
table.insert(shade2,SaveChatlogs)
table.insert(text1,SaveChatlogs)

scrollCL.Name = "scroll"
scrollCL.Parent = logsDrag
scrollCL.BackgroundColor3 = Color3.fromRGB(46, 46, 47)
scrollCL.BorderSizePixel = 0
scrollCL.Position = UDim2.new(0, 5, 0, 25)
scrollCL.Size = UDim2.new(0, 328, 0, 190)
scrollCL.ZIndex = 10
scrollCL.ScrollBarImageColor3 = Color3.fromRGB(78,78,79)
scrollCL.BottomImage = "rbxasset://textures/ui/Scroll/scroll-middle.png"
scrollCL.CanvasSize = UDim2.new(0, 0, 0, 10)
scrollCL.MidImage = "rbxasset://textures/ui/Scroll/scroll-middle.png"
scrollCL.ScrollBarThickness = 8
scrollCL.TopImage = "rbxasset://textures/ui/Scroll/scroll-middle.png"
scrollCL.VerticalScrollBarInset = 'Always'
table.insert(scroll,scrollCL)
table.insert(shade2,scrollCL)

AliasHint.Name = "AliasHint"
AliasHint.Parent = AliasesFrame
AliasHint.BackgroundTransparency = 1
AliasHint.BorderSizePixel = 0
AliasHint.Position = UDim2.new(0, 25, 0, 40)
AliasHint.Size = UDim2.new(0, 200, 0, 50)
AliasHint.Font = Enum.Font.SourceSansItalic
AliasHint.TextSize = 16
AliasHint.Text = "Add aliases by using the 'addalias' command"
AliasHint.TextColor3 = Color3.new(1, 1, 1)
AliasHint.TextStrokeColor3 = Color3.new(1, 1, 1)
AliasHint.TextWrapped = true
AliasHint.ZIndex = 10
table.insert(text1,AliasHint)

PluginsHint.Name = "PluginsHint"
PluginsHint.Parent = PluginsFrame
PluginsHint.BackgroundTransparency = 1
PluginsHint.BorderSizePixel = 0
PluginsHint.Position = UDim2.new(0, 25, 0, 40)
PluginsHint.Size = UDim2.new(0, 200, 0, 50)
PluginsHint.Font = Enum.Font.SourceSansItalic
PluginsHint.TextSize = 16
PluginsHint.Text = "Download plugins from the IY Discord (discord.io/infiniteyield)"
PluginsHint.TextColor3 = Color3.new(1, 1, 1)
PluginsHint.TextStrokeColor3 = Color3.new(1, 1, 1)
PluginsHint.TextWrapped = true
PluginsHint.ZIndex = 10
table.insert(text1,PluginsHint)

PositionsHint.Name = "PositionsHint"
PositionsHint.Parent = PositionsFrame
PositionsHint.BackgroundTransparency = 1
PositionsHint.BorderSizePixel = 0
PositionsHint.Position = UDim2.new(0, 25, 0, 40)
PositionsHint.Size = UDim2.new(0, 200, 0, 70)
PositionsHint.Font = Enum.Font.SourceSansItalic
PositionsHint.TextSize = 16
PositionsHint.Text = "Use the 'spos' or 'setwaypoint' command to add a position using your character (NOTE: Part teleports will not save)"
PositionsHint.TextColor3 = Color3.new(1, 1, 1)
PositionsHint.TextStrokeColor3 = Color3.new(1, 1, 1)
PositionsHint.TextWrapped = true
PositionsHint.ZIndex = 10
table.insert(text1,PositionsHint)

ToPartFrame.Name = randomString()
ToPartFrame.Parent = PARENT
ToPartFrame.Active = true
ToPartFrame.BackgroundTransparency = 1
ToPartFrame.Position = UDim2.new(0.5, -180, 0, -400)
ToPartFrame.Size = UDim2.new(0, 360, 0, 20)
ToPartFrame.ZIndex = 10

background_5.Name = "background"
background_5.Parent = ToPartFrame
background_5.Active = true
background_5.BackgroundColor3 = Color3.fromRGB(36, 36, 37)
background_5.BorderSizePixel = 0
background_5.Position = UDim2.new(0, 0, 0, 20)
background_5.Size = UDim2.new(0, 360, 0, 117)
background_5.ZIndex = 10
table.insert(shade1,background_5)

ChoosePart.Name = "ChoosePart"
ChoosePart.Parent = background_5
ChoosePart.BackgroundColor3 = Color3.fromRGB(46, 46, 47)
ChoosePart.BorderSizePixel = 0
ChoosePart.Position = UDim2.new(0, 100, 0, 55)
ChoosePart.Size = UDim2.new(0, 75, 0, 30)
ChoosePart.Font = Enum.Font.SourceSans
ChoosePart.TextSize = 14
ChoosePart.Text = "Select Part"
ChoosePart.TextColor3 = Color3.new(1, 1, 1)
ChoosePart.ZIndex = 10
table.insert(shade2,ChoosePart)
table.insert(text1,ChoosePart)

CopyPath.Name = "CopyPath"
CopyPath.Parent = background_5
CopyPath.BackgroundColor3 = Color3.fromRGB(46, 46, 47)
CopyPath.BorderSizePixel = 0
CopyPath.Position = UDim2.new(0, 185, 0, 55)
CopyPath.Size = UDim2.new(0, 75, 0, 30)
CopyPath.Font = Enum.Font.SourceSans
CopyPath.TextSize = 14
CopyPath.Text = "Copy Path"
CopyPath.TextColor3 = Color3.new(1, 1, 1)
CopyPath.ZIndex = 10
table.insert(shade2,CopyPath)
table.insert(text1,CopyPath)

Directions_4.Name = "Directions"
Directions_4.Parent = background_5
Directions_4.BackgroundTransparency = 1
Directions_4.BorderSizePixel = 0
Directions_4.Position = UDim2.new(0, 51, 0, 17)
Directions_4.Size = UDim2.new(0, 257, 0, 32)
Directions_4.Font = Enum.Font.SourceSans
Directions_4.TextSize = 14
Directions_4.Text = 'Click on a part and then click the "Select Part" button below to set it as a teleport location'
Directions_4.TextColor3 = Color3.new(1, 1, 1)
Directions_4.TextWrapped = true
Directions_4.TextYAlignment = Enum.TextYAlignment.Top
Directions_4.ZIndex = 10
table.insert(text1,Directions_4)

Path.Name = "Path"
Path.Parent = background_5
Path.BackgroundTransparency = 1
Path.BorderSizePixel = 0
Path.Position = UDim2.new(0, 0, 0, 94)
Path.Size = UDim2.new(0, 360, 0, 16)
Path.Font = Enum.Font.SourceSansItalic
Path.TextSize = 14
Path.Text = ""
Path.TextColor3 = Color3.new(1, 1, 1)
Path.TextScaled = true
Path.TextWrapped = true
Path.TextYAlignment = Enum.TextYAlignment.Top
Path.ZIndex = 10
table.insert(text1,Path)

shadow_5.Name = "shadow"
shadow_5.Parent = ToPartFrame
shadow_5.BackgroundColor3 = Color3.fromRGB(46, 46, 47)
shadow_5.BorderSizePixel = 0
shadow_5.Size = UDim2.new(0, 360, 0, 20)
shadow_5.ZIndex = 10
table.insert(shade2,shadow_5)

PopupText_5.Name = "PopupText"
PopupText_5.Parent = shadow_5
PopupText_5.BackgroundTransparency = 1
PopupText_5.Position = UDim2.new(0, 51, 0, 0)
PopupText_5.Size = UDim2.new(0.760355055, -16, 0.949999988, 0)
PopupText_5.ZIndex = 10
PopupText_5.Font = Enum.Font.SourceSans
PopupText_5.TextSize = 14
PopupText_5.Text = "Teleport to Part"
PopupText_5.TextColor3 = Color3.new(1, 1, 1)
PopupText_5.TextWrapped = true
table.insert(text1,PopupText_5)

Exit_5.Name = "Exit"
Exit_5.Parent = shadow_5
Exit_5.BackgroundTransparency = 1
Exit_5.Size = UDim2.new(0, 20, 0, 20)
Exit_5.ZIndex = 10
Exit_5.Image = "rbxassetid://2132544126"

function writefileExploit()
	if writefile then
		return true
	end
end

function isNumber(str)
	return tonumber(str) ~= nil
end

function tools(plr)
	if plr.Backpack:FindFirstChildOfClass('Tool') or plr.Character:FindFirstChildOfClass('Tool') then
		return true
	end
end

function r15(plr)
	if plr.Character:FindFirstChildOfClass('Humanoid').RigType == Enum.HumanoidRigType.R15 then
		return true
	end
end

function toClipboard(String)
	if not pcall(function() CB = setclipboard or Clipboard.set CB(String) notify('Clipboard','Copied to clipboard') end) then
		notify('Clipboard',"Your exploit doesn't have the ability to use the clipboard")
	end
end

function getHierarchy(obj)
	local fullname
	local period
	
	if string.find(obj.Name,' ') then
		fullname = '["'..obj.Name..'"]'
		period = false
	else
		fullname = obj.Name
		period = true
	end

	local getS = obj
	local parent = obj
	local service = ''
	
	if getS.Parent ~= game then
		repeat
			getS = getS.Parent
			service = getS.ClassName
		until getS.Parent == game
	end
	
	if parent.Parent ~= getS then
		repeat
			parent = parent.Parent
			if string.find(tostring(parent),' ') then
				if period then
					fullname = '["'..parent.Name..'"].'..fullname
				else
					fullname = '["'..parent.Name..'"]'..fullname
				end
				period = false
			else
				if period then
					fullname = parent.Name..'.'..fullname
				else
					fullname = parent.Name..''..fullname
				end
				period = true
			end
		until parent.Parent == getS
	elseif string.find(tostring(parent),' ') then
		fullname = '["'..parent.Name..'"]'
		period = false
	end
	
	if period then
		return 'game:GetService("'..service..'").'..fullname
	else
		return 'game:GetService("'..service..'")'..fullname
	end
end

AllWaypoints = {}

cooldown = false
function writefileCooldown(name,data)
	spawn(function()
		if not cooldown then
			cooldown = true
			writefile(name, data)
		else
			repeat wait() until cooldown == false
			writefileCooldown(name,data)
		end
		wait(3)
		cooldown = false
	end)
end

currentShade1 = Color3.fromRGB(36, 36, 37)
currentShade2 = Color3.fromRGB(46, 46, 47)
currentShade3 = Color3.fromRGB(78, 78, 79)
currentText1 = Color3.new(1, 1, 1)
currentText2 = Color3.new(0, 0, 0)
currentScroll = Color3.fromRGB(78,78,79)

defaultsettings = {
	prefix = ';';
	StayOpen = false;
	logsEnabled = false;
	aliases = {};
	binds = {};
	spawnCmds = {};
	WayPoints = {};
	PluginsTable = {}
}

defaults = game:GetService("HttpService"):JSONEncode(defaultsettings)

nosaves = false

function saves()
	if writefileExploit() then
		if pcall(function() readfile("IY_FE.iy") end) then
			if readfile("IY_FE.iy") ~= nil then
				local json = game:GetService("HttpService"):JSONDecode(readfile("IY_FE.iy"))
				if json.prefix ~= nil then prefix = json.prefix else prefix = ';' end
				if json.StayOpen ~= nil then StayOpen = json.StayOpen else StayOpen = false end
				if json.logsEnabled ~= nil then logsEnabled = json.logsEnabled else logsEnabled = false end
				if json.aliases ~= nil then aliases = json.aliases else aliases = {} end
				if json.binds ~= nil then binds = json.binds else binds = {} end
				if json.spawnCmds ~= nil then spawnCmds = json.spawnCmds else spawnCmds = {} end
				if json.WayPoints ~= nil then AllWaypoints = json.WayPoints else WayPoints = {} AllWaypoints = {} end
				if json.PluginsTable ~= nil then PluginsTable = json.PluginsTable else PluginsTable = {} end
				if json.currentShade1 ~= nil then currentShade1 = Color3.new(json.currentShade1[1],json.currentShade1[2],json.currentShade1[3]) end
				if json.currentShade2 ~= nil then currentShade2 = Color3.new(json.currentShade2[1],json.currentShade2[2],json.currentShade2[3]) end
				if json.currentShade3 ~= nil then currentShade3 = Color3.new(json.currentShade3[1],json.currentShade3[2],json.currentShade3[3]) end
				if json.currentText1 ~= nil then currentText1 = Color3.new(json.currentText1[1],json.currentText1[2],json.currentText1[3]) end
				if json.currentText2 ~= nil then currentText2 = Color3.new(json.currentText2[1],json.currentText2[2],json.currentText2[3]) end
				if json.currentScroll ~= nil then currentScroll = Color3.new(json.currentScroll[1],json.currentScroll[2],json.currentScroll[3]) end
			else
				writefileCooldown("IY_FE.iy", defaults)
				wait()
				saves()
			end
		else
			writefileCooldown("IY_FE.iy", defaults)
			wait()
			if pcall(function() readfile("IY_FE.iy") end) then
				saves()
			else
				nosaves = true
				prefix = ';'
				StayOpen = false
				logsEnabled = false
				aliases = {}
				binds = {}
				spawnCmds = {}
				WayPoints = {}
				PluginsTable = {}
				
				local FileError = Instance.new("Frame")
				local background = Instance.new("Frame")
				local Directions = Instance.new("TextLabel")
				local shadow = Instance.new("Frame")
				local PopupText = Instance.new("TextLabel")
				local Exit = Instance.new("ImageButton")
				
				FileError.Name = randomString()
				FileError.Parent = PARENT
				FileError.Active = true
				FileError.BackgroundTransparency = 1
				FileError.Position = UDim2.new(0.5, -180, 0, 290)
				FileError.Size = UDim2.new(0, 360, 0, 20)
				FileError.ZIndex = 10
				
				background.Name = "background"
				background.Parent = FileError
				background.Active = true
				background.BackgroundColor3 = Color3.fromRGB(36, 36, 37)
				background.BorderSizePixel = 0
				background.Position = UDim2.new(0, 0, 0, 20)
				background.Size = UDim2.new(0, 360, 0, 205)
				background.ZIndex = 10
				
				Directions.Name = "Directions"
				Directions.Parent = background
				Directions.BackgroundTransparency = 1
				Directions.BorderSizePixel = 0
				Directions.Position = UDim2.new(0, 10, 0, 10)
				Directions.Size = UDim2.new(0, 340, 0, 185)
				Directions.Font = Enum.Font.SourceSans
				Directions.TextSize = 14
				Directions.Text = "There was a problem writing a save file to your PC.\n\nPlease contact the developer/support team for your exploit and tell them writefile is not working.\n\nYour settings, keybinds, waypoints, and aliases will not save if you continue.\n\nThings to try:\n> Make sure a 'workspace' folder is located in the same folder as your exploit\n> If your exploit is inside of a zip/rar file, extract it.\n> Rejoin the game and try again or restart your PC and try again."
				Directions.TextColor3 = Color3.new(1, 1, 1)
				Directions.TextWrapped = true
				Directions.TextXAlignment = Enum.TextXAlignment.Left
				Directions.TextYAlignment = Enum.TextYAlignment.Top
				Directions.ZIndex = 10

				shadow.Name = "shadow"
				shadow.Parent = FileError
				shadow.BackgroundColor3 = Color3.fromRGB(46, 46, 47)
				shadow.BorderSizePixel = 0
				shadow.Size = UDim2.new(0, 360, 0, 20)
				shadow.ZIndex = 10
				
				PopupText.Name = "PopupText"
				PopupText.Parent = shadow
				PopupText.BackgroundTransparency = 1
				PopupText.Position = UDim2.new(0, 51, 0, 0)
				PopupText.Size = UDim2.new(0.760355055, -16, 0.949999988, 0)
				PopupText.ZIndex = 10
				PopupText.Font = Enum.Font.SourceSans
				PopupText.TextSize = 14
				PopupText.Text = "File Error"
				PopupText.TextColor3 = Color3.new(1, 1, 1)
				PopupText.TextWrapped = true
				
				Exit.Name = "Exit"
				Exit.Parent = shadow
				Exit.BackgroundTransparency = 1
				Exit.Size = UDim2.new(0, 20, 0, 20)
				Exit.ZIndex = 10
				Exit.Image = "rbxassetid://2132544126"
				
				Exit.MouseButton1Click:Connect(function()
					FileError:Destroy()
				end)
			end
		end
	else
		prefix = ';'
		StayOpen = false
		logsEnabled = false
		aliases = {}
		binds = {}
		spawnCmds = {}
		WayPoints = {}
		PluginsTable = {}
	end
end

saves()

function updatesaves()
	if nosaves == false and writefileExploit() then
		local update = {
		prefix = prefix;
		StayOpen = StayOpen;
		logsEnabled = logsEnabled;
		aliases = aliases;
		binds = binds;
		spawnCmds = spawnCmds;
		WayPoints = AllWaypoints;
		PluginsTable = PluginsTable;
		currentShade1 = {currentShade1.R,currentShade1.G,currentShade1.B};
		currentShade2 = {currentShade2.R,currentShade2.G,currentShade2.B};
		currentShade3 = {currentShade3.R,currentShade3.G,currentShade3.B};
		currentText1 = {currentText1.R,currentText1.G,currentText1.B};
		currentText2 = {currentText2.R,currentText2.G,currentText2.B};
		currentScroll = {currentScroll.R,currentScroll.G,currentScroll.B}
		}
		writefileCooldown("IY_FE.iy", game:GetService("HttpService"):JSONEncode(update))
	end
end

pWayPoints = {}
WayPoints = {}

if #AllWaypoints > 0 then
	for i = 1, #AllWaypoints do
		if not AllWaypoints[i].GAME or AllWaypoints[i].GAME == game.PlaceId then
			WayPoints[#WayPoints + 1] = {NAME = AllWaypoints[i].NAME, COORD = {AllWaypoints[i].COORD[1], AllWaypoints[i].COORD[2], AllWaypoints[i].COORD[3]}, GAME = AllWaypoints[i].GAME}
		end
	end
end

function Time()
	local HOUR = math.floor((tick() % 86400) / 3600)
	local MINUTE = math.floor((tick() % 3600) / 60)
	local SECOND = math.floor(tick() % 60)
	local AP = HOUR > 11 and 'PM' or 'AM'
	HOUR = (HOUR % 12 == 0 and 12 or HOUR % 12)
	HOUR = HOUR < 10 and '0' .. HOUR or HOUR
	MINUTE = MINUTE < 10 and '0' .. MINUTE or MINUTE
	SECOND = SECOND < 10 and '0' .. SECOND or SECOND
	return HOUR .. ':' .. MINUTE .. ':' .. SECOND .. ' ' .. AP
end

UserInputService = game:GetService("UserInputService")
IYMouse = Players.LocalPlayer:GetMouse()
PrefixBox.Text = prefix
SettingsOpen = false

if StayOpen == false then
	Holder.Settings.StayOpen.Button.On.BackgroundTransparency = 1
else
	Holder.Settings.StayOpen.Button.On.BackgroundTransparency = 0
end

if logsEnabled then
	Toggle.Text = 'Enabled'
else
	Toggle.Text = 'Disabled'
end

function maximizeHolder()
	if StayOpen == false then
		Holder:TweenPosition(UDim2.new(1, Holder.Position.X.Offset, 1, -220), "InOut", "Quart", 0.2, true, nil)
	end
end

function minimizeHolder()
	if StayOpen == false then
		Holder:TweenPosition(UDim2.new(1, Holder.Position.X.Offset, 1, -20), "InOut", "Quart", 0.5, true, nil)
	end
end

function cmdbarHolder()
	if StayOpen == false then
		Holder:TweenPosition(UDim2.new(1, Holder.Position.X.Offset, 1, -45), "InOut", "Quart", 0.5, true, nil)
	end
end

function enablebuttons()
	Settings.Aliases.Select.Visible = true
	Settings.SpawnC.Select.Visible = true
	Settings.Keybinds.Select.Visible = true
	Settings.StayOpen.Button.On.Visible = true
	Settings.Prefix.PrefixBox.Visible = true
	Settings.Positions.Select.Visible = true
	Settings.Plugins.Select.Visible = true
end

function disablebuttons()
	Settings.Aliases.Select.Visible = false
	Settings.SpawnC.Select.Visible = false
	Settings.Keybinds.Select.Visible = false
	Settings.StayOpen.Button.On.Visible = false
	Settings.Prefix.PrefixBox.Visible = false
	Settings.Positions.Select.Visible = false
	Settings.Plugins.Select.Visible = false
end

notifyCount = 0
pinNotification = nil
function notify(text,text2,length)
	spawn(function()
		local LnotifyCount = notifyCount+1
		local notificationPinned = false
		notifyCount = notifyCount+1
		if pinNotification then pinNotification:Disconnect() end
		pinNotification = Notification.MouseEnter:Connect(function()
			spawn(function()
				pinNotification:Disconnect()
				notificationPinned = true
				Notification.Title.BackgroundTransparency = 1
				wait(0.5)
				Notification.Title.BackgroundTransparency = 0
			end)
		end)
		Notification:TweenPosition(UDim2.new(1, Notification.Position.X.Offset, 1, 0), "InOut", "Quart", 0.5, true, nil)
		wait(0.6)
		local closepressed = false
		if text2 then
			Notification.Title.Text = text
			Notification.Text.Text = text2
		else
			Notification.Title.Text = 'Notification'
			Notification.Text.Text = text
		end
		Notification:TweenPosition(UDim2.new(1, Notification.Position.X.Offset, 1, -100), "InOut", "Quart", 0.5, true, nil)
		Notification.CloseButton.MouseButton1Click:Connect(function()
			Notification:TweenPosition(UDim2.new(1, Notification.Position.X.Offset, 1, 0), "InOut", "Quart", 0.5, true, nil)
			closepressed = true
			pinNotification:Disconnect()
		end)
		if length and isNumber(length) then
			wait(length)
		else
			wait(10)
		end
		if LnotifyCount == notifyCount then
			if closepressed == false and notificationPinned == false then
				pinNotification:Disconnect()
				Notification:TweenPosition(UDim2.new(1, Notification.Position.X.Offset, 1, 0), "InOut", "Quart", 0.5, true, nil)
			end
			notifyCount = 0
		end
	end)
end

function CreateLabel(Name, Text)
	if #scrollCL:GetChildren() >= 2546 then
		scrollCL:ClearAllChildren()
	end
	local alls = 0
	for i,v in pairs(scrollCL:GetChildren()) do
		if v then
			alls = v.Size.Y.Offset + alls
		end
		if not v then
			alls = 0
		end
	end
	local tl = Instance.new('TextLabel', scrollCL)
	local il = Instance.new('Frame', tl)
	tl.Name = Name
	tl.ZIndex = 10
	tl.Text = Time().." - ["..Name.."]: "..Text
	tl.Size = UDim2.new(0,322,0,84)
	tl.BackgroundTransparency = 1
	tl.BorderSizePixel = 0
	tl.Font = "SourceSans"
	tl.Position = UDim2.new(-1,0,0,alls)
	tl.TextTransparency = 1
	tl.TextScaled = false
	tl.TextSize = 14
	tl.TextWrapped = true
	tl.TextXAlignment = "Left"
	tl.TextYAlignment = "Top"
	il.BackgroundTransparency = 1
	il.BorderSizePixel = 0
	il.Size = UDim2.new(0,12,1,0)
	il.Position = UDim2.new(0,316,0,0)
	il.ZIndex = 10
	tl.TextColor3 = currentText1
	tl.Size = UDim2.new(0,322,0,tl.TextBounds.Y)
	table.insert(text1,tl)
	scrollCL.CanvasSize = UDim2.new(0,0,0,alls+tl.TextBounds.Y)
	scrollCL.CanvasPosition = Vector2.new(0,scrollCL.CanvasPosition.Y+tl.TextBounds.Y)
	tl:TweenPosition(UDim2.new(0,3,0,alls), 'In', 'Quint', 0.5)
	for i = 0,50 do wait(0.05)
		tl.TextTransparency = tl.TextTransparency - 0.05
	end
	tl.TextTransparency = 0
end

infJump = false
IYMouse.KeyDown:connect(function(Key)
	if (Key==prefix) then
		Holder.Cmdbar:CaptureFocus()
		spawn(function()
			repeat Holder.Cmdbar.Text = '' until Holder.Cmdbar.Text == ''
		end)
		maximizeHolder()
	elseif infJump == true and Key == " " then
		Players.LocalPlayer.Character.Humanoid:ChangeState(3)
	end
end)

Holder.MouseEnter:Connect(function()
	maximizeHolder()
end)

Holder.MouseLeave:Connect(function()
	if not Holder.Cmdbar:IsFocused() then
		minimizeHolder()
	end
end)

function updateColors(color,ctype)
	if ctype == shade1 then
		for i,v in pairs(shade1) do
			v.BackgroundColor3 = color
		end
		currentShade1 = color
	elseif ctype == shade2 then
		for i,v in pairs(shade2) do
			v.BackgroundColor3 = color
		end
		currentShade2 = color
	elseif ctype == shade3 then
		for i,v in pairs(shade3) do
			v.BackgroundColor3 = color
		end
		currentShade3 = color
	elseif ctype == text1 then
		for i,v in pairs(text1) do
			v.TextColor3 = color
		end
		currentText1 = color
	elseif ctype == text2 then
		for i,v in pairs(text2) do
			v.TextColor3 = color
		end
		currentText2 = color
	elseif ctype == scroll then
		for i,v in pairs(scroll) do
			v.ScrollBarImageColor3 = color
		end
		currentScroll = color
	end
end

colorpickerOpen = false
ColorsButton.MouseButton1Click:Connect(function()
	cache_currentShade1 = currentShade1
	cache_currentShade2 = currentShade2
	cache_currentShade3 = currentShade3
	cache_currentText1 = currentText1
	cache_currentText2 = currentText2
	cache_currentScroll = currentScroll
	if not colorpickerOpen then
		colorpickerOpen = true
		picker = game:GetObjects("rbxassetid://4908465318")[1]
		picker.Name = randomString()
		picker.Parent = PARENT
		
		local ColorPicker do
			ColorPicker = {}
			
			ColorPicker.new = function()
				local newMt = setmetatable({},{})
				
				local pickerGui = picker.ColorPicker
				local pickerTopBar = pickerGui.TopBar
				local pickerExit = pickerTopBar.Exit
				local pickerFrame = pickerGui.Content
				local colorSpace = pickerFrame.ColorSpaceFrame.ColorSpace
				local colorStrip = pickerFrame.ColorStrip
				local previewFrame = pickerFrame.Preview
				local basicColorsFrame = pickerFrame.BasicColors
				local customColorsFrame = pickerFrame.CustomColors
				local defaultButton = pickerFrame.Default
				local cancelButton = pickerFrame.Cancel
				local shade1Button = pickerFrame.Shade1
				local shade2Button = pickerFrame.Shade2
				local shade3Button = pickerFrame.Shade3
				local text1Button = pickerFrame.Text1
				local text2Button = pickerFrame.Text2
				local scrollButton = pickerFrame.Scroll
		
				local colorScope = colorSpace.Scope
				local colorArrow = pickerFrame.ArrowFrame.Arrow
		
				local hueInput = pickerFrame.Hue.Input
				local satInput = pickerFrame.Sat.Input
				local valInput = pickerFrame.Val.Input
		
				local redInput = pickerFrame.Red.Input
				local greenInput = pickerFrame.Green.Input
				local blueInput = pickerFrame.Blue.Input
		
				local mouse = game:GetService("Players").LocalPlayer:GetMouse()
		
				local hue,sat,val = 0,0,1
				local red,green,blue = 1,1,1
				local chosenColor = Color3.new(0,0,0)
		
				local basicColors = {Color3.new(0,0,0),Color3.new(0.66666668653488,0,0),Color3.new(0,0.33333334326744,0),Color3.new(0.66666668653488,0.33333334326744,0),Color3.new(0,0.66666668653488,0),Color3.new(0.66666668653488,0.66666668653488,0),Color3.new(0,1,0),Color3.new(0.66666668653488,1,0),Color3.new(0,0,0.49803924560547),Color3.new(0.66666668653488,0,0.49803924560547),Color3.new(0,0.33333334326744,0.49803924560547),Color3.new(0.66666668653488,0.33333334326744,0.49803924560547),Color3.new(0,0.66666668653488,0.49803924560547),Color3.new(0.66666668653488,0.66666668653488,0.49803924560547),Color3.new(0,1,0.49803924560547),Color3.new(0.66666668653488,1,0.49803924560547),Color3.new(0,0,1),Color3.new(0.66666668653488,0,1),Color3.new(0,0.33333334326744,1),Color3.new(0.66666668653488,0.33333334326744,1),Color3.new(0,0.66666668653488,1),Color3.new(0.66666668653488,0.66666668653488,1),Color3.new(0,1,1),Color3.new(0.66666668653488,1,1),Color3.new(0.33333334326744,0,0),Color3.new(1,0,0),Color3.new(0.33333334326744,0.33333334326744,0),Color3.new(1,0.33333334326744,0),Color3.new(0.33333334326744,0.66666668653488,0),Color3.new(1,0.66666668653488,0),Color3.new(0.33333334326744,1,0),Color3.new(1,1,0),Color3.new(0.33333334326744,0,0.49803924560547),Color3.new(1,0,0.49803924560547),Color3.new(0.33333334326744,0.33333334326744,0.49803924560547),Color3.new(1,0.33333334326744,0.49803924560547),Color3.new(0.33333334326744,0.66666668653488,0.49803924560547),Color3.new(1,0.66666668653488,0.49803924560547),Color3.new(0.33333334326744,1,0.49803924560547),Color3.new(1,1,0.49803924560547),Color3.new(0.33333334326744,0,1),Color3.new(1,0,1),Color3.new(0.33333334326744,0.33333334326744,1),Color3.new(1,0.33333334326744,1),Color3.new(0.33333334326744,0.66666668653488,1),Color3.new(1,0.66666668653488,1),Color3.new(0.33333334326744,1,1),Color3.new(1,1,1)}
				local customColors = {}
				
				dragGUI(picker)
		
				local function updateColor(noupdate)
					local relativeX,relativeY,relativeStripY = 219 - hue*219, 199 - sat*199, 199 - val*199
					local hsvColor = Color3.fromHSV(hue,sat,val)
			
					if noupdate == 2 or not noupdate then
						hueInput.Text = tostring(math.ceil(359*hue))
						satInput.Text = tostring(math.ceil(255*sat))
						valInput.Text = tostring(math.floor(255*val))
					end
					if noupdate == 1 or not noupdate then
						redInput.Text = tostring(math.floor(255*red))
						greenInput.Text = tostring(math.floor(255*green))
						blueInput.Text = tostring(math.floor(255*blue))
					end
			
					chosenColor = Color3.new(red,green,blue)
			
					colorScope.Position = UDim2.new(0,relativeX-9,0,relativeY-9)
					colorStrip.ImageColor3 = Color3.fromHSV(hue,sat,1)
					colorArrow.Position = UDim2.new(0,-2,0,relativeStripY-4)
					previewFrame.BackgroundColor3 = chosenColor
					
					newMt.Color = chosenColor
					if newMt.Changed then newMt:Changed(chosenColor) end
				end
		
				local function colorSpaceInput()
					local relativeX = mouse.X - colorSpace.AbsolutePosition.X
					local relativeY = mouse.Y - colorSpace.AbsolutePosition.Y
						
					if relativeX < 0 then relativeX = 0 elseif relativeX > 219 then relativeX = 219 end
					if relativeY < 0 then relativeY = 0 elseif relativeY > 199 then relativeY = 199 end
						
					hue = (219 - relativeX)/219
					sat = (199 - relativeY)/199
			
					local hsvColor = Color3.fromHSV(hue,sat,val)
					red,green,blue = hsvColor.r,hsvColor.g,hsvColor.b
			
					updateColor()
				end
		
				local function colorStripInput()
					local relativeY = mouse.Y - colorStrip.AbsolutePosition.Y
			
					if relativeY < 0 then relativeY = 0 elseif relativeY > 199 then relativeY = 199 end	
			
					val = (199 - relativeY)/199
			
					local hsvColor = Color3.fromHSV(hue,sat,val)
					red,green,blue = hsvColor.r,hsvColor.g,hsvColor.b
			
					updateColor()
				end
		
				local function hookButtons(frame,func)
					frame.ArrowFrame.Up.InputBegan:Connect(function(input)
						if input.UserInputType == Enum.UserInputType.MouseMovement then
							frame.ArrowFrame.Up.BackgroundTransparency = 0.5
						elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
							local releaseEvent,runEvent
					
							local startTime = tick()
							local pressing = true
							local startNum = tonumber(frame.Text)
					
							if not startNum then return end
					
							releaseEvent = UserInputService.InputEnded:Connect(function(input)
								if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
								releaseEvent:Disconnect()
								pressing = false
							end)
					
							startNum = startNum + 1
							func(startNum)
							while pressing do
								if tick()-startTime > 0.3 then
									startNum = startNum + 1
									func(startNum)
								end
								wait(0.1)
							end
						end
					end)
			
					frame.ArrowFrame.Up.InputEnded:Connect(function(input)
						if input.UserInputType == Enum.UserInputType.MouseMovement then
							frame.ArrowFrame.Up.BackgroundTransparency = 1
						end
					end)
			
					frame.ArrowFrame.Down.InputBegan:Connect(function(input)
						if input.UserInputType == Enum.UserInputType.MouseMovement then
							frame.ArrowFrame.Down.BackgroundTransparency = 0.5
						elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
							local releaseEvent,runEvent
					
							local startTime = tick()
							local pressing = true
							local startNum = tonumber(frame.Text)
					
							if not startNum then return end
					
							releaseEvent = UserInputService.InputEnded:Connect(function(input)
								if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
								releaseEvent:Disconnect()
								pressing = false
							end)
					
							startNum = startNum - 1
							func(startNum)
							while pressing do
								if tick()-startTime > 0.3 then
									startNum = startNum - 1
									func(startNum)
								end
								wait(0.1)
							end
						end
					end)
			
					frame.ArrowFrame.Down.InputEnded:Connect(function(input)
						if input.UserInputType == Enum.UserInputType.MouseMovement then
							frame.ArrowFrame.Down.BackgroundTransparency = 1
						end
					end)
				end
		
				colorSpace.InputBegan:Connect(function(input)
					if input.UserInputType == Enum.UserInputType.MouseButton1 then
						local releaseEvent,mouseEvent
				
						releaseEvent = UserInputService.InputEnded:Connect(function(input)
							if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
		            		releaseEvent:Disconnect()
							mouseEvent:Disconnect()
						end)
				
						mouseEvent = UserInputService.InputChanged:Connect(function(input)
							if input.UserInputType == Enum.UserInputType.MouseMovement then
								colorSpaceInput()
							end
						end)
				
						colorSpaceInput()
					end
				end)
		
				colorStrip.InputBegan:Connect(function(input)
					if input.UserInputType == Enum.UserInputType.MouseButton1 then
						local releaseEvent,mouseEvent
				
						releaseEvent = UserInputService.InputEnded:Connect(function(input)
							if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
		        		    releaseEvent:Disconnect()
							mouseEvent:Disconnect()
						end)
				
						mouseEvent = UserInputService.InputChanged:Connect(function(input)
							if input.UserInputType == Enum.UserInputType.MouseMovement then
								colorStripInput()
							end
						end)
				
						colorStripInput()
					end
				end)
		
				local function updateHue(str)
					local num = tonumber(str)
					if num then
						hue = math.clamp(math.floor(num),0,359)/359
						local hsvColor = Color3.fromHSV(hue,sat,val)
						red,green,blue = hsvColor.r,hsvColor.g,hsvColor.b
						hueInput.Text = tostring(hue*359)
						updateColor(1)
					end
				end
				hueInput.FocusLost:Connect(function() updateHue(hueInput.Text) end) hookButtons(hueInput,updateHue)
		
				local function updateSat(str)
					local num = tonumber(str)
					if num then
						sat = math.clamp(math.floor(num),0,255)/255
						local hsvColor = Color3.fromHSV(hue,sat,val)
						red,green,blue = hsvColor.r,hsvColor.g,hsvColor.b
						satInput.Text = tostring(sat*255)
						updateColor(1)
					end
				end
				satInput.FocusLost:Connect(function() updateSat(satInput.Text) end) hookButtons(satInput,updateSat)
		
				local function updateVal(str)
					local num = tonumber(str)
					if num then
						val = math.clamp(math.floor(num),0,255)/255
						local hsvColor = Color3.fromHSV(hue,sat,val)
						red,green,blue = hsvColor.r,hsvColor.g,hsvColor.b
						valInput.Text = tostring(val*255)
						updateColor(1)
					end
				end
				valInput.FocusLost:Connect(function() updateVal(valInput.Text) end) hookButtons(valInput,updateVal)
				
				local function updateRed(str)
					local num = tonumber(str)
					if num then
						red = math.clamp(math.floor(num),0,255)/255
						local newColor = Color3.new(red,green,blue)
						hue,sat,val = Color3.toHSV(newColor)
						redInput.Text = tostring(red*255)
						updateColor(2)
					end
				end
				redInput.FocusLost:Connect(function() updateRed(redInput.Text) end) hookButtons(redInput,updateRed)
				
				local function updateGreen(str)
					local num = tonumber(str)
					if num then
						green = math.clamp(math.floor(num),0,255)/255
						local newColor = Color3.new(red,green,blue)
						hue,sat,val = Color3.toHSV(newColor)
						greenInput.Text = tostring(green*255)
						updateColor(2)
					end
				end
				greenInput.FocusLost:Connect(function() updateGreen(greenInput.Text) end) hookButtons(greenInput,updateGreen)
				
				local function updateBlue(str)
					local num = tonumber(str)
					if num then
						blue = math.clamp(math.floor(num),0,255)/255
						local newColor = Color3.new(red,green,blue)
						hue,sat,val = Color3.toHSV(newColor)
						blueInput.Text = tostring(blue*255)
						updateColor(2)
					end
				end
				blueInput.FocusLost:Connect(function() updateBlue(blueInput.Text) end) hookButtons(blueInput,updateBlue)
				
				local colorChoice = Instance.new("TextButton")
				colorChoice.Name = "Choice"
				colorChoice.Size = UDim2.new(0,25,0,18)
				colorChoice.BorderColor3 = Color3.new(96/255,96/255,96/255)
				colorChoice.Text = ""
				colorChoice.AutoButtonColor = false
				colorChoice.ZIndex = 10
				
				local row = 0
				local column = 0
				for i,v in pairs(basicColors) do
					local newColor = colorChoice:Clone()
					newColor.BackgroundColor3 = v
					newColor.Position = UDim2.new(0,1 + 30*column,0,21 + 23*row)
					
					newColor.MouseButton1Click:Connect(function()
						red,green,blue = v.r,v.g,v.b
						local newColor = Color3.new(red,green,blue)
						hue,sat,val = Color3.toHSV(newColor)
						updateColor()
					end)	
					
					newColor.Parent = basicColorsFrame
					column = column + 1
					if column == 6 then row = row + 1 column = 0 end
				end
				
				row = 0
				column = 0
				for i = 1,12 do
					local color = customColors[i] or Color3.new(0,0,0)
					local newColor = colorChoice:Clone()
					newColor.BackgroundColor3 = color
					newColor.Position = UDim2.new(0,1 + 30*column,0,20 + 23*row)
					
					newColor.MouseButton1Click:Connect(function()
						local curColor = customColors[i] or Color3.new(0,0,0)
						red,green,blue = curColor.r,curColor.g,curColor.b
						hue,sat,val = Color3.toHSV(curColor)
						updateColor()
					end)
					
					newColor.MouseButton2Click:Connect(function()
						customColors[i] = chosenColor
						newColor.BackgroundColor3 = chosenColor
					end)
					
					newColor.Parent = customColorsFrame
					column = column + 1
					if column == 6 then row = row + 1 column = 0 end
				end
				
				shade1Button.MouseButton1Click:Connect(function() if newMt.Confirm then newMt:Confirm(chosenColor,shade1) end end)
				shade1Button.InputBegan:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseMovement then shade1Button.BackgroundTransparency = 0.4 end end)
				shade1Button.InputEnded:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseMovement then shade1Button.BackgroundTransparency = 0 end end)
		
				shade2Button.MouseButton1Click:Connect(function() if newMt.Confirm then newMt:Confirm(chosenColor,shade2) end end)
				shade2Button.InputBegan:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseMovement then shade2Button.BackgroundTransparency = 0.4 end end)
				shade2Button.InputEnded:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseMovement then shade2Button.BackgroundTransparency = 0 end end)
		
				shade3Button.MouseButton1Click:Connect(function() if newMt.Confirm then newMt:Confirm(chosenColor,shade3) end end)
				shade3Button.InputBegan:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseMovement then shade3Button.BackgroundTransparency = 0.4 end end)
				shade3Button.InputEnded:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseMovement then shade3Button.BackgroundTransparency = 0 end end)
		
				text1Button.MouseButton1Click:Connect(function() if newMt.Confirm then newMt:Confirm(chosenColor,text1) end end)
				text1Button.InputBegan:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseMovement then text1Button.BackgroundTransparency = 0.4 end end)
				text1Button.InputEnded:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseMovement then text1Button.BackgroundTransparency = 0 end end)
		
				text2Button.MouseButton1Click:Connect(function() if newMt.Confirm then newMt:Confirm(chosenColor,text2) end end)
				text2Button.InputBegan:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseMovement then text2Button.BackgroundTransparency = 0.4 end end)
				text2Button.InputEnded:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseMovement then text2Button.BackgroundTransparency = 0 end end)
		
				scrollButton.MouseButton1Click:Connect(function() if newMt.Confirm then newMt:Confirm(chosenColor,scroll) end end)
				scrollButton.InputBegan:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseMovement then scrollButton.BackgroundTransparency = 0.4 end end)
				scrollButton.InputEnded:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseMovement then scrollButton.BackgroundTransparency = 0 end end)
		
				cancelButton.MouseButton1Click:Connect(function() if newMt.Cancel then newMt:Cancel() end end)
				cancelButton.InputBegan:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseMovement then cancelButton.BackgroundTransparency = 0.4 end end)
				cancelButton.InputEnded:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseMovement then cancelButton.BackgroundTransparency = 0 end end)
		
				defaultButton.MouseButton1Click:Connect(function() if newMt.Default then newMt:Default() end end)
				defaultButton.InputBegan:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseMovement then defaultButton.BackgroundTransparency = 0.4 end end)
				defaultButton.InputEnded:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseMovement then defaultButton.BackgroundTransparency = 0 end end)
		
				pickerExit.MouseButton1Click:Connect(function()
					picker:TweenPosition(UDim2.new(0.5, -219, 0, -500), "InOut", "Quart", 0.5, true, nil)
				end)
		
				updateColor()
		
				newMt.SetColor = function(self,color)
					red,green,blue = color.r,color.g,color.b
					hue,sat,val = Color3.toHSV(color)
					updateColor()
				end
				
				return newMt
			end
		end
		
		picker:TweenPosition(UDim2.new(0.5, -219, 0, 100), "InOut", "Quart", 0.5, true, nil)
		
		local Npicker = ColorPicker.new()
		Npicker.Confirm = function(self,color,ctype) updateColors(color,ctype) wait() updatesaves() end
		Npicker.Cancel = function(self)
			updateColors(cache_currentShade1,shade1)
			updateColors(cache_currentShade2,shade2)
			updateColors(cache_currentShade3,shade3)
			updateColors(cache_currentText1,text1)
			updateColors(cache_currentText2,text2)
			updateColors(cache_currentScroll,scroll)
			wait()
			updatesaves()
		end
		Npicker.Default = function(self)
			updateColors(Color3.fromRGB(36, 36, 37),shade1)
			updateColors(Color3.fromRGB(46, 46, 47),shade2)
			updateColors(Color3.fromRGB(78, 78, 79),shade3)
			updateColors(Color3.new(1, 1, 1),text1)
			updateColors(Color3.new(0, 0, 0),text2)
			updateColors(Color3.fromRGB(78,78,79),scroll)
			wait()
			updatesaves()
		end
	else
		picker:TweenPosition(UDim2.new(0.5, -219, 0, 100), "InOut", "Quart", 0.5, true, nil)
	end
end)


Holder.SettingsButton.MouseButton1Click:Connect(function()
	if SettingsOpen == false then SettingsOpen = true
		Holder.Settings:TweenPosition(UDim2.new(0, 0, 0, 45), "InOut", "Quart", 0.5, true, nil)
		Holder.CMDs.Visible = false
	else SettingsOpen = false
		Holder.CMDs.Visible = true
		Holder.Settings:TweenPosition(UDim2.new(0, 0, 0, 220), "InOut", "Quart", 0.5, true, nil)
	end
end)

Holder.Settings.StayOpen.Button.On.MouseButton1Click:Connect(function()
	if StayOpen == false then StayOpen = true
		Holder.Settings.StayOpen.Button.On.BackgroundTransparency = 0
	else StayOpen = false
		Holder.Settings.StayOpen.Button.On.BackgroundTransparency = 1
	end
	updatesaves()
end)

Clear.MouseButton1Down:connect(function()
	for _, child in pairs(scrollCL:GetChildren()) do
		child:Destroy()
	end
	scrollCL.CanvasSize = UDim2.new(0, 0, 0, 10)
end)

Toggle.MouseButton1Down:connect(function()
	if logsEnabled then
		logsEnabled = false
		Toggle.Text = 'Disabled'
		updatesaves()
	else
		logsEnabled = true
		Toggle.Text = 'Enabled'
		updatesaves()
	end
end)

if not writefileExploit() then
	notify('Saves','Your exploit does not support read/write file. Your settings will not save.')
end

ChatLog = function(plr)
	plr.Chatted:Connect(function(Message)
		if logsEnabled == true then
			CreateLabel(plr.Name,Message)
		end
	end)
end

SaveChatlogs.MouseButton1Down:connect(function()
	if writefileExploit() then
		if #scrollCL:GetChildren() > 0 then
			notify("Loading",'Hold on a second')
			local placeName = game:GetService('MarketplaceService'):GetProductInfo(game.PlaceId).Name
			local writelogs = '-- Infinite Yield Chat logs for "'..placeName..'"\n'
			for _, child in pairs(scrollCL:GetChildren()) do
				writelogs = writelogs..'\n'..child.Text
			end
			local writelogsFile = tostring(writelogs)
			local fileext = 0
			local function nameFile()
				local file
				pcall(function() file = readfile(placeName..' Chat Logs ('..fileext..').txt') end)
				if file then
					fileext = fileext+1
					nameFile()
				else
					writefileCooldown(placeName..' Chat Logs ('..fileext..').txt', writelogsFile)
				end
			end
			nameFile()
			notify('Chat Logs','Saved chat logs to the workspace folder within your exploit folder.')
		end
	else
		notify('Chat Logs','Your exploit does not support write file. You cannot save chat logs.')
	end
end)

for _, plr in pairs(Players:GetChildren()) do
	if plr.ClassName == "Player" then
		ChatLog(plr)
	end
end

Players.PlayerAdded:connect(function(player)
	ChatLog(player)
	if ESPenabled then
		repeat wait(1) until player.Character and player.Character:FindFirstChild('HumanoidRootPart')
		ESP(player)
	end
	if CHMSenabled then
		repeat wait(1) until player.Character and player.Character:FindFirstChild('HumanoidRootPart')
		CHMS(player)
	end
end)

Players.PlayerRemoving:connect(function(player)
	for i,v in pairs(PARENT:GetChildren()) do
		if v.Name == player.Name..'_ESP' or v.Name == player.Name..'_LC' then
			v:Destroy()
		end
	end
	if viewing ~= nil and player == viewing then
		workspace.CurrentCamera.CameraSubject = Players.LocalPlayer.Character
		viewing = nil
		if viewDied then
			viewDied:Disconnect()
		end
		notify('Spectate','View turned off (player left)')
	end
end)

shadow.Exit.MouseButton1Down:connect(function()
	logsDrag:TweenPosition(UDim2.new(0, 0, 1, 10), "InOut", "Quart", 0.3, true, nil)
end)

shadow.Hide.MouseButton1Down:connect(function()
	if logsDrag.Position ~= UDim2.new(0, 0, 1, -20) then
		logsDrag:TweenPosition(UDim2.new(0, 0, 1, -20), "InOut", "Quart", 0.3, true, nil)
	else
		logsDrag:TweenPosition(UDim2.new(0, 0, 1, -245), "InOut", "Quart", 0.3, true, nil)
	end
end)

SpawnC.Select.MouseButton1Click:Connect(function()
	SpawnCFrame:TweenPosition(UDim2.new(0, 0, 0, 0), "InOut", "Quart", 0.5, true, nil)
	wait(0.5)
	disablebuttons()
end)

SpawnCFrame.Close.MouseButton1Click:Connect(function()
	enablebuttons()
	SpawnCFrame:TweenPosition(UDim2.new(0, 0, 0, 175), "InOut", "Quart", 0.5, true, nil)
end)

SpawnCFrame.Delete.MouseButton1Click:Connect(function()
	spawnCmds = {}
	updatesaves()
	refreshSpawnC()
	notify('Spawn Commands Updated','Cleared all spawn commands')
end)

Add_5.MouseButton1Click:Connect(function()
	if Cmdbar_3.Text ~= '' and Cmdbar_3.Text ~= 'Command' then
		if isNumber(DelayNum.Text) then
		addspawn(Cmdbar_3.Text,tonumber(DelayNum.Text))
		refreshSpawnC()
		updatesaves()
		notify('Spawn Commands Updated','"'..Cmdbar_3.Text..'" will run when your player spawns')
		else
			notify('Spawn Command Error','Command delay must be a number')
		end
	end
end)

Keybinds.Select.MouseButton1Click:Connect(function()
	KeybindsFrame:TweenPosition(UDim2.new(0, 0, 0, 0), "InOut", "Quart", 0.5, true, nil)
	wait(0.5)
	disablebuttons()
end)

KeybindsFrame.Close.MouseButton1Click:Connect(function()
	enablebuttons()
	KeybindsFrame:TweenPosition(UDim2.new(0, 0, 0, 175), "InOut", "Quart", 0.5, true, nil)
end)

Holder.Settings.Keybinds.Select.MouseButton1Click:Connect(function()
	KeybindsFrame:TweenPosition(UDim2.new(0, 0, 0, 0), "InOut", "Quart", 0.5, true, nil)
	wait(0.5)
	disablebuttons()
end)

KeybindsFrame.Add.MouseButton1Click:Connect(function()
	KeybindEditor:TweenPosition(UDim2.new(0.5, -180, 0, 260), "InOut", "Quart", 0.5, true, nil)
end)

KeybindsFrame.Delete.MouseButton1Click:Connect(function()
	binds = {}
	refreshbinds()
	updatesaves()
	notify('Keybinds Updated','Removed all keybinds')
end)

AliasesFrame.Close.MouseButton1Click:Connect(function()
	enablebuttons()
	AliasesFrame:TweenPosition(UDim2.new(0, 0, 0, 175), "InOut", "Quart", 0.5, true, nil)
end)

Settings.Aliases.Select.MouseButton1Click:Connect(function()
	AliasesFrame:TweenPosition(UDim2.new(0, 0, 0, 0), "InOut", "Quart", 0.5, true, nil)
	wait(0.5)
	disablebuttons()
end)

PositionsFrame.Close.MouseButton1Click:Connect(function()
	enablebuttons()
	PositionsFrame:TweenPosition(UDim2.new(0, 0, 0, 175), "InOut", "Quart", 0.5, true, nil)
end)

Settings.Positions.Select.MouseButton1Click:Connect(function()
	PositionsFrame:TweenPosition(UDim2.new(0, 0, 0, 0), "InOut", "Quart", 0.5, true, nil)
	wait(0.5)
	disablebuttons()
end)

SpawnCFrame.Add.MouseButton1Click:Connect(function()
	SpawnCEditor:TweenPosition(UDim2.new(0.5, -180, 0, 285), "InOut", "Quart", 0.5, true, nil)
end)

Exit_4.MouseButton1Click:Connect(function()
	SpawnCEditor:TweenPosition(UDim2.new(0.5, -180, 0, -400), "InOut", "Quart", 0.5, true, nil)
	Cmdbar_3.Text = 'Command'
	DelayNum.Text = '0'
end)

selectionBox = Instance.new("SelectionBox")
selectionBox.Name = randomString()
selectionBox.Color3 = Color3.new(255,255,255)
selectionBox.Adornee = nil
selectionBox.Parent = PARENT

selected = Instance.new("SelectionBox")
selected.Name = randomString()
selected.Color3 = Color3.new(0,166,0)
selected.Adornee = nil
selected.Parent = PARENT

ActivateHighlight = nil
ClickSelect = nil
Part.MouseButton1Click:Connect(function()
	ToPartFrame:TweenPosition(UDim2.new(0.5, -180, 0, 335), "InOut", "Quart", 0.5, true, nil)
	local function HighlightPart()
		if selected.Adornee ~= Players.LocalPlayer:GetMouse().Target then
			selectionBox.Adornee = Players.LocalPlayer:GetMouse().Target
		else
			selectionBox.Adornee = nil
		end
	end
	ActivateHighlight = Players.LocalPlayer:GetMouse().Move:connect(HighlightPart)
	local function SelectPart()
		if Players.LocalPlayer:GetMouse().Target ~= nil then
			selected.Adornee = Players.LocalPlayer:GetMouse().Target
			Path.Text = getHierarchy(Players.LocalPlayer:GetMouse().Target)
		end
	end
	ClickSelect = IYMouse.Button1Down:connect(SelectPart)
end)

Exit_5.MouseButton1Click:Connect(function()
	ToPartFrame:TweenPosition(UDim2.new(0.5, -180, 0, -400), "InOut", "Quart", 0.5, true, nil)
	if ActivateHighlight then
		ActivateHighlight:Disconnect()
	end
	if ClickSelect then
		ClickSelect:Disconnect()
	end
	selectionBox.Adornee = nil
	selected.Adornee = nil
	Path.Text = ""
end)

CopyPath.MouseButton1Click:Connect(function()
	if Path.Text ~= "" then
		toClipboard(Path.Text)
	else
		notify('Copy Path','Select a part to copy its path')
	end
end)

ChoosePart.MouseButton1Click:Connect(function()
	if Path.Text ~= "" then
		local tpNameExt = ''
		local function handleWpNames()
			local FoundDupe = false
			for i,v in pairs(pWayPoints) do
				if v.NAME:lower() == selected.Adornee.Name:lower()..tpNameExt then
					FoundDupe = true
				end
			end
			if not FoundDupe then
				notify('Modified Waypoints',"Created waypoint: "..selected.Adornee.Name..tpNameExt)
				pWayPoints[#pWayPoints + 1] = {NAME = selected.Adornee.Name..tpNameExt, COORD = {selected.Adornee}}
			else
				if isNumber(tpNameExt) then
					tpNameExt = tpNameExt+1
				else
					tpNameExt = 1
				end
				handleWpNames()
			end
		end
		handleWpNames()
		refreshwaypoints()
	else
		notify('Part Selection','Select a part first')
	end
end)

cmds={}
customAlias = {}
AliasesFrame.Delete.MouseButton1Click:Connect(function()
	customAlias = {}
	aliases = {}
	notify('Aliases Modified','Removed all aliases')
	updatesaves()
	refreshaliases()
end)

Holder.Settings.Prefix.PrefixBox:GetPropertyChangedSignal("Text"):connect(function()
	prefix = Holder.Settings.Prefix.PrefixBox.Text
	updatesaves()
end)

function CamViewport()
	if workspace.CurrentCamera then
		return workspace.CurrentCamera.ViewportSize.X
	end
end

function UpdateToViewport()
	if Holder.Position.X.Offset < -CamViewport() then
		Holder:TweenPosition(UDim2.new(1, -CamViewport(), Holder.Position.Y.Scale, Holder.Position.Y.Offset), "InOut", "Quart", 0.04, true, nil)
		Notification:TweenPosition(UDim2.new(1, -CamViewport() + 250, Notification.Position.Y.Scale, Notification.Position.Y.Offset), "InOut", "Quart", 0.04, true, nil)
	end
end
CameraChanged = workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):connect(UpdateToViewport)

function updateCamera(child, parent)
	if parent ~= workspace then
		CamMoved:Disconnect()
		CameraChanged:Disconnect()
		repeat wait() until workspace.CurrentCamera
		CameraChanged = workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):connect(UpdateToViewport)
		CamMoved = workspace.CurrentCamera.AncestryChanged:Connect(updateCamera)
	end
end
CamMoved = workspace.CurrentCamera.AncestryChanged:Connect(updateCamera)

function dragMain(dragpoint,gui)
	spawn(function()
		local dragging
		local dragInput
		local dragStart
		local startPos
		local function update(input)
			local pos = -250
		    local delta = input.Position - dragStart
			if startPos.X.Offset + delta.X <= -500 then
				local Position = UDim2.new(1, -250, Notification.Position.Y.Scale, Notification.Position.Y.Offset)
				game:GetService("TweenService"):Create(Notification, TweenInfo.new(.20), {Position = Position}):Play()
				pos = 250
			else
				local Position = UDim2.new(1, -500, Notification.Position.Y.Scale, Notification.Position.Y.Offset)
				game:GetService("TweenService"):Create(Notification, TweenInfo.new(.20), {Position = Position}):Play()
				pos = -250
			end
			if startPos.X.Offset + delta.X <= -250 and -CamViewport() <= startPos.X.Offset + delta.X then
				local Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, gui.Position.Y.Scale, gui.Position.Y.Offset)
				game:GetService("TweenService"):Create(gui, TweenInfo.new(.20), {Position = Position}):Play()
				local Position2 = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X + pos, Notification.Position.Y.Scale, Notification.Position.Y.Offset)
				game:GetService("TweenService"):Create(Notification, TweenInfo.new(.20), {Position = Position2}):Play()
			elseif startPos.X.Offset + delta.X > -500 then
				local Position = UDim2.new(1, -250, gui.Position.Y.Scale, gui.Position.Y.Offset)
				game:GetService("TweenService"):Create(gui, TweenInfo.new(.20), {Position = Position}):Play()
			elseif -CamViewport() > startPos.X.Offset + delta.X then
				gui:TweenPosition(UDim2.new(1, -CamViewport(), gui.Position.Y.Scale, gui.Position.Y.Offset), "InOut", "Quart", 0.04, true, nil)
				local Position = UDim2.new(1, -CamViewport(), gui.Position.Y.Scale, gui.Position.Y.Offset)
				game:GetService("TweenService"):Create(gui, TweenInfo.new(.20), {Position = Position}):Play()
				local Position2 = UDim2.new(1, -CamViewport() + 250, Notification.Position.Y.Scale, Notification.Position.Y.Offset)
				game:GetService("TweenService"):Create(Notification, TweenInfo.new(.20), {Position = Position2}):Play()
			end
		end
		dragpoint.InputBegan:Connect(function(input)
		    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		        dragging = true
		        dragStart = input.Position
		        startPos = gui.Position
		        
		        input.Changed:Connect(function()
		            if input.UserInputState == Enum.UserInputState.End then
		                dragging = false
		            end
		        end)
		    end
		end)
		dragpoint.InputChanged:Connect(function(input)
		    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
		        dragInput = input
		    end
		end)
		UserInputService.InputChanged:Connect(function(input)
		    if input == dragInput and dragging then
		        update(input)
		    end
		end)
	end)
end

dragMain(Title,Holder)

function dragGUI(gui)
	spawn(function()
		local dragging
		local dragInput
		local dragStart
		local startPos
		local function update(input)
		    local delta = input.Position - dragStart
			local Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
			game:GetService("TweenService"):Create(gui, TweenInfo.new(.20), {Position = Position}):Play()
		end
		gui.InputBegan:Connect(function(input)
		    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		        dragging = true
		        dragStart = input.Position
		        startPos = gui.Position
		        
		        input.Changed:Connect(function()
		            if input.UserInputState == Enum.UserInputState.End then
		                dragging = false
		            end
		        end)
		    end
		end)
		gui.InputChanged:Connect(function(input)
		    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
		        dragInput = input
		    end
		end)
		UserInputService.InputChanged:Connect(function(input)
		    if input == dragInput and dragging then
		        update(input)
		    end
		end)
	end)
end

dragGUI(logsDrag)
dragGUI(KeybindEditor)
dragGUI(PluginEditor)
dragGUI(SpawnCEditor)
dragGUI(ToPartFrame)

CSP = Holder
frame = CSP:WaitForChild('CMDs')

Match = function(name,str)
	return name:lower():find(str:lower()) and true
end

canvasPos = nil
canvasTop = false
topCommand = nil
IndexContents = function(str,bool,cmdbar,Ianim)
	if str == '' or str == ' ' or str == prefix then
		if canvasTop == false then
			canvasPos = CMDsF.CanvasPosition.Y
		end
	else
		CMDsF.CanvasPosition = Vector2.new(0,0)
		canvasTop = true
	end
	local Index,SizeY = 0,0
	local indexnum = 0
	topCommand = nil
	for i,v in next, frame:GetChildren() do
		if bool then
			if Match(v.Text,str) then
				indexnum = indexnum + 1
				Index = Index + 1
				v.Visible = true
				v:TweenPosition(UDim2.new(0,10,0,Index*v.AbsoluteSize.Y-v.AbsoluteSize.Y), "InOut", "Quart", 0.2, true, nil)
				SizeY = SizeY + v.AbsoluteSize.Y
				frame.CanvasSize = UDim2.new(0,0,0,SizeY)
				if topCommand == nil then
					topCommand = v.Text
				end
			else
				v.Visible = false
			end
		else
			v.Visible = true
			SizeY = SizeY + v.AbsoluteSize.Y
			frame.CanvasSize = UDim2.new(0,0,0,SizeY)
			if topCommand == nil then
				topCommand = v.Text
			end
		end
	end
	if not Ianim then
		if indexnum == 0 or string.find(str, " ") then
			if not cmdbar then
				minimizeHolder()
			elseif cmdbar then
				cmdbarHolder()
			end
		else
			maximizeHolder()
		end
	else
		minimizeHolder()
	end
end

PlayerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
local chatbox
if pcall(function() chatbox = Players.LocalPlayer:FindFirstChildWhichIsA("PlayerGui").Chat.Frame.ChatBarParentFrame.Frame.BoxFrame.Frame.ChatBar end) then	
	local function Index()
		if chatbox.Text:lower():sub(1,1) == prefix then
			if SettingsOpen == true then
				wait(0.2)
				Holder.CMDs.Visible = true
				Holder.Settings:TweenPosition(UDim2.new(0, 0, 0, 220), "InOut", "Quart", 0.2, true, nil)
			end
			IndexContents(PlayerGui.Chat.Frame.ChatBarParentFrame.Frame.BoxFrame.Frame.ChatBar.Text:lower():sub(2),true)
		else
			minimizeHolder()
			if SettingsOpen == true then
				wait(0.2)
				Settings:TweenPosition(UDim2.new(0, 0, 0, 45), "InOut", "Quart", 0.2, true, nil)
				Holder.CMDs.Visible = false
			end
		end
	end
	chatbox:GetPropertyChangedSignal("Text"):Connect(Index)
			
	chatbox.FocusLost:connect(function(enterpressed)
		if not enterpressed or chatbox.Text:lower():sub(1,1) ~= prefix then
			IndexContents('',true)
			if canvasPos ~= nil then
				CMDsF.CanvasPosition = Vector2.new(0, canvasPos)
				canvasTop = false
			end
		end
		minimizeHolder()
	end)
	
	Players.LocalPlayer:FindFirstChildWhichIsA("PlayerGui").Chat.Frame.ChatBarParentFrame.ChildAdded:Connect(function(newbar)
		wait()
		if newbar:FindFirstChild('BoxFrame') then
			chatbox = Players.LocalPlayer:FindFirstChildWhichIsA("PlayerGui").Chat.Frame.ChatBarParentFrame.Frame.BoxFrame.Frame.ChatBar
			chatbox:GetPropertyChangedSignal("Text"):Connect(Index)
		end
	end)
else
	print('Custom chat detected. Will not provide suggestions for commands typed in the chat.')
end

CMDs = {}
CMDs[#CMDs + 1] = {NAME = 'console', DESC = 'Loads old Roblox console'}
CMDs[#CMDs + 1] = {NAME = 'explorer / dex', DESC = 'Opens DEX explorer'}
CMDs[#CMDs + 1] = {NAME = 'serverinfo / info', DESC = 'Gives you info about the server'}
CMDs[#CMDs + 1] = {NAME = 'rejoin / rj', DESC = 'Makes you rejoin the game'}
CMDs[#CMDs + 1] = {NAME = 'serverhop / shop', DESC = 'Teleports you to a different server'}
CMDs[#CMDs + 1] = {NAME = 'joinplayer [username / ID] [place ID]', DESC = 'Joins a specific players server'}
CMDs[#CMDs + 1] = {NAME = 'gameteleport / gametp [place ID]', DESC = 'Joins a game by ID'}
CMDs[#CMDs + 1] = {NAME = 'antiidle / antiafk', DESC = 'Prevents the game from kicking you for being idle/afk'}
CMDs[#CMDs + 1] = {NAME = 'nopurchaseprompts / noprompts', DESC = 'Prevents the game from showing you purchase prompts'}
CMDs[#CMDs + 1] = {NAME = 'showpurchaseprompts / showprompts', DESC = 'Allows the game to show purchase prompts again'}
CMDs[#CMDs + 1] = {NAME = 'enable [inventory/playerlist/chat/all]', DESC = 'Toggles visibility of coregui items'}
CMDs[#CMDs + 1] = {NAME = 'disable [inventory/playerlist/chat/all]', DESC = 'Toggles visibility of coregui items'}
CMDs[#CMDs + 1] = {NAME = 'showguis', DESC = 'Shows any invisible GUIs'}
CMDs[#CMDs + 1] = {NAME = 'unshowguis', DESC = 'Undoes showguis'}
CMDs[#CMDs + 1] = {NAME = 'hideguis', DESC = 'Hides any GUIs in PlayerGui'}
CMDs[#CMDs + 1] = {NAME = 'unhideguis', DESC = 'Undoes hideguis'}
CMDs[#CMDs + 1] = {NAME = 'savegame / saveplace', DESC = 'Uses saveinstance to save the game'}
CMDs[#CMDs + 1] = {NAME = 'clearerror', DESC = 'Clears the annoying box and blur when a game kicks you'}
CMDs[#CMDs + 1] = {NAME = 'exit', DESC = 'Kills roblox process'}
CMDs[#CMDs + 1] = {NAME = '', DESC = ''}
CMDs[#CMDs + 1] = {NAME = 'noclip', DESC = 'Go through objects'}
CMDs[#CMDs + 1] = {NAME = 'unnoclip / clip', DESC = 'Disables noclip'}
CMDs[#CMDs + 1] = {NAME = 'fly', DESC = 'Makes you fly'}
CMDs[#CMDs + 1] = {NAME = 'unfly', DESC = 'Disables fly'}
CMDs[#CMDs + 1] = {NAME = 'flyspeed [num]', DESC = 'Set fly speed (default is 20)'}
CMDs[#CMDs + 1] = {NAME = 'vehiclefly / vfly', DESC = 'Makes you fly in a vehicle'}
CMDs[#CMDs + 1] = {NAME = 'unvehiclefly / unvfly', DESC = 'Disables vehicle fly'}
CMDs[#CMDs + 1] = {NAME = 'vehicleflyspeed  / vflyspeed [num]', DESC = 'Set vehicle fly speed'}
CMDs[#CMDs + 1] = {NAME = 'float /  platform', DESC = 'Spawns a platform beneath you causing you to float'}
CMDs[#CMDs + 1] = {NAME = 'unfloat / noplatform', DESC = 'Removes the platform'}
CMDs[#CMDs + 1] = {NAME = 'swim', DESC = 'Allows you to swim in the air'}
CMDs[#CMDs + 1] = {NAME = 'unswim / noswim', DESC = 'Stops you from swimming everywhere'}
CMDs[#CMDs + 1] = {NAME = '', DESC = ''}
CMDs[#CMDs + 1] = {NAME = 'setwaypoint / swp [name]', DESC = 'Sets a waypoint at your position'}
CMDs[#CMDs + 1] = {NAME = 'waypointpos / wpp [name] [X Y Z]', DESC = 'Sets a waypoint with specified coordinates'}
CMDs[#CMDs + 1] = {NAME = 'waypoint / wp [name]', DESC = 'Teleports player to a waypoint'}
CMDs[#CMDs + 1] = {NAME = 'deletewaypoint / dwp [name]', DESC = 'Deletes a waypoint'}
CMDs[#CMDs + 1] = {NAME = 'clearwaypoints / cwp', DESC = 'Clears all waypoints'}
CMDs[#CMDs + 1] = {NAME = '', DESC = ''}
CMDs[#CMDs + 1] = {NAME = 'goto [plr]', DESC = 'Go to a player'}
CMDs[#CMDs + 1] = {NAME = 'vehiclegoto / vgoto [plr]', DESC = 'Go to a player while in a vehicle'}
CMDs[#CMDs + 1] = {NAME = 'loopgoto [plr] [distance] [delay]', DESC = 'Loop teleport to a player'}
CMDs[#CMDs + 1] = {NAME = 'unloopgoto [plr]', DESC = 'Stops teleporting you to a player'}
CMDs[#CMDs + 1] = {NAME = 'clientbring / cbring [plr] (CLIENT)', DESC = 'Bring a player'}
CMDs[#CMDs + 1] = {NAME = 'loopbring [plr] [distance] [delay] (CLIENT)', DESC = 'Loop brings a player to you (useful for killing)'}
CMDs[#CMDs + 1] = {NAME = 'unloopbring [plr]', DESC = 'Undoes loopbring'}
CMDs[#CMDs + 1] = {NAME = 'freeze / fr [plr] (CLIENT)', DESC = 'Freezes a player'}
CMDs[#CMDs + 1] = {NAME = 'thaw / unfr [plr] (CLIENT)', DESC = 'Unfreezes a player'}
CMDs[#CMDs + 1] = {NAME = 'tpposition / tppos [X Y Z]', DESC = 'Teleports you to certain coordinates'}
CMDs[#CMDs + 1] = {NAME = 'offset [X Y Z]', DESC = 'Offsets you by certain coordinates'}
CMDs[#CMDs + 1] = {NAME = 'notifyposition / notifypos', DESC = 'Notifies you the coordinates of your character'}
CMDs[#CMDs + 1] = {NAME = 'copyposition / copypos', DESC = 'Copies the coordinates of your character to your clipboard'}
CMDs[#CMDs + 1] = {NAME = 'spawnpoint / spawn', DESC = 'Sets a position where you will spawn'}
CMDs[#CMDs + 1] = {NAME = 'nospawnpoint / nospawn', DESC = 'Removes your custom spawn point'}
CMDs[#CMDs + 1] = {NAME = 'flashback / diedtp', DESC = 'Teleports you to where you last died'}
CMDs[#CMDs + 1] = {NAME = 'walltp', DESC = 'Teleports you above/over any wall you run into'}
CMDs[#CMDs + 1] = {NAME = 'nowalltp / unwalltp', DESC = 'Disables walltp'}
CMDs[#CMDs + 1] = {NAME = '', DESC = ''}
CMDs[#CMDs + 1] = {NAME = 'chatlogs / logs', DESC = 'Log what people say or whisper'}
CMDs[#CMDs + 1] = {NAME = 'chat [text]', DESC = 'Makes you chat a string (possible mute bypass)'}
CMDs[#CMDs + 1] = {NAME = 'spam [text]', DESC = 'Makes you spam the chat'}
CMDs[#CMDs + 1] = {NAME = 'unspam', DESC = 'Turns off spam'}
CMDs[#CMDs + 1] = {NAME = 'pmspam [plr] [text]', DESC = 'Makes you spam a players whispers'}
CMDs[#CMDs + 1] = {NAME = 'unpmspam [plr]', DESC = 'Turns off pm spam'}
CMDs[#CMDs + 1] = {NAME = 'spamspeed [num]', DESC = 'How quickly you spam (default is 1)'}
CMDs[#CMDs + 1] = {NAME = '', DESC = ''}
CMDs[#CMDs + 1] = {NAME = 'esp', DESC = 'View all players and their status'}
CMDs[#CMDs + 1] = {NAME = 'noesp / unesp', DESC = 'Removes esp'}
CMDs[#CMDs + 1] = {NAME = 'partesp [part name]', DESC = 'Highlights a part'}
CMDs[#CMDs + 1] = {NAME = 'unpartesp / nopartesp [part name]', DESC = 'removes partesp'}
CMDs[#CMDs + 1] = {NAME = 'chams', DESC = 'ESP but without text in the way'}
CMDs[#CMDs + 1] = {NAME = 'nochams / unchams', DESC = 'Removes chams'}
CMDs[#CMDs + 1] = {NAME = 'locate [plr]', DESC = 'View a single player and their status'}
CMDs[#CMDs + 1] = {NAME = 'unlocate / nolocate [plr]', DESC = 'Removes locate'}
CMDs[#CMDs + 1] = {NAME = 'xray', DESC = 'Makes all parts in workspace transparent'}
CMDs[#CMDs + 1] = {NAME = 'unxray / noxray', DESC = 'Restores transparency'}
CMDs[#CMDs + 1] = {NAME = '', DESC = ''}
CMDs[#CMDs + 1] = {NAME = 'spectate / view [plr]', DESC = 'View a player'}
CMDs[#CMDs + 1] = {NAME = 'unspectate / unview', DESC = 'Stops viewing player'}
CMDs[#CMDs + 1] = {NAME = 'freecam / fc', DESC = 'Allows you to freely move camera around the game'}
CMDs[#CMDs + 1] = {NAME = 'unfreecam / unfc', DESC = 'Disables freecam'}
CMDs[#CMDs + 1] = {NAME = 'freecamspeed / fcspeed [num]', DESC = 'Adjusts freecam speed'}
CMDs[#CMDs + 1] = {NAME = 'freecamtp / fctp', DESC = 'Teleports you to the location of freecam'}
CMDs[#CMDs + 1] = {NAME = 'firstp', DESC = 'Forces camera to go into first person'}
CMDs[#CMDs + 1] = {NAME = 'thirdp', DESC = 'Allows camera to go into third person'}
CMDs[#CMDs + 1] = {NAME = 'noclipcam / nccam', DESC = 'Allows camera to go through objects like walls'}
CMDs[#CMDs + 1] = {NAME = 'maxzoom [num]', DESC = 'Maximum camera zoom'}
CMDs[#CMDs + 1] = {NAME = 'fov [num]', DESC = 'Adjusts field of view (default is 70)'}
CMDs[#CMDs + 1] = {NAME = 'fixcam / restorecam', DESC = 'Fixes camera'}
CMDs[#CMDs + 1] = {NAME = 'enableshiftlock / enablesl', DESC = 'Enables the shift lock option'}
CMDs[#CMDs + 1] = {NAME = '', DESC = ''}
CMDs[#CMDs + 1] = {NAME = 'btools (CLIENT)', DESC = 'Gives you building tools (DOES NOT REPLICATE)'}
CMDs[#CMDs + 1] = {NAME = 'f3x (CLIENT)', DESC = 'Gives you F3X building tools (DOES NOT REPLICATE)'}
CMDs[#CMDs + 1] = {NAME = 'delete [instance name] (CLIENT)', DESC = 'Removes any part with a certain name from the workspace (DOES NOT REPLICATE)'}
CMDs[#CMDs + 1] = {NAME = 'deleteclass / dc [class name] (CLIENT)', DESC = 'Removes any part with a certain classname from the workspace (DOES NOT REPLICATE)'}
CMDs[#CMDs + 1] = {NAME = 'chardelete / cd [instance name]', DESC = 'Removes any part with a certain name from your character'}
CMDs[#CMDs + 1] = {NAME = 'chardeleteclass / cdc [class name]', DESC = 'Removes any part with a certain classname from your character'}
CMDs[#CMDs + 1] = {NAME = 'deletevelocity / dv / removeforces', DESC = 'Removes any velocity / force instances in your character'}
CMDs[#CMDs + 1] = {NAME = 'lockworkspace / lockws', DESC = 'Locks the whole workspace'}
CMDs[#CMDs + 1] = {NAME = 'unlockworkspace / unlockws', DESC = 'Unlocks the whole workspace'}
CMDs[#CMDs + 1] = {NAME = 'gotopart [part name]', DESC = 'Moves your character to a part or multiple parts'}
CMDs[#CMDs + 1] = {NAME = 'bringpart [part name] (CLIENT)', DESC = 'Moves a part or multiple parts to your character'}
CMDs[#CMDs + 1] = {NAME = 'gotopartclass / gpc [class name]', DESC = 'Moves your character to a part or multiple parts based on classname'}
CMDs[#CMDs + 1] = {NAME = 'bringpartclass / bpc [class name] (CLIENT)', DESC = 'Moves a part or multiple parts to your character based on classname'}
CMDs[#CMDs + 1] = {NAME = 'noclickdetectorlimits / nocdlimits', DESC = 'Sets all click detectors MaxActivationDistance to math.huge'}
CMDs[#CMDs + 1] = {NAME = 'simulationradius / simradius', DESC = 'Sets your SimulationRadius to math.huge'}
CMDs[#CMDs + 1] = {NAME = 'tpunanchored / tpua [plr]', DESC = 'Teleports unanchored parts to a player'}
CMDs[#CMDs + 1] = {NAME = 'freezeunanchored / freezeua', DESC = 'Freezes unanchored parts'}
CMDs[#CMDs + 1] = {NAME = 'thawunanchored / thawua / unfreezeua', DESC = 'Thaws unanchored parts'}
CMDs[#CMDs + 1] = {NAME = '', DESC = ''}
CMDs[#CMDs + 1] = {NAME = 'fullbright / fb (CLIENT)', DESC = 'Makes the map brighter / more visible'}
CMDs[#CMDs + 1] = {NAME = 'ambient [num] [num] [num] (CLIENT)', DESC = 'Changes ambient'}
CMDs[#CMDs + 1] = {NAME = 'day (CLIENT)', DESC = 'Changes the time to day for the client'}
CMDs[#CMDs + 1] = {NAME = 'night (CLIENT)', DESC = 'Changes the time to night for the client'}
CMDs[#CMDs + 1] = {NAME = 'nofog (CLIENT)', DESC = 'Removes fog'}
CMDs[#CMDs + 1] = {NAME = 'brightness [num] (CLIENT)', DESC = 'Changes the brightness lighting property'}
CMDs[#CMDs + 1] = {NAME = 'globalshadows / gshadows (CLIENT)', DESC = 'Enables global shadows'}
CMDs[#CMDs + 1] = {NAME = 'noglobalshadows / nogshadows (CLIENT)', DESC = 'Disables global shadows'}
CMDs[#CMDs + 1] = {NAME = 'restorelighting / rlighting', DESC = 'Restores Lighting properties'}
CMDs[#CMDs + 1] = {NAME = 'light [radius] (CLIENT)', DESC = 'Gives your player dynamic light'}
CMDs[#CMDs + 1] = {NAME = 'nolight / unlight', DESC = 'Removes dynamic light from your player'}
CMDs[#CMDs + 1] = {NAME = '', DESC = ''}
CMDs[#CMDs + 1] = {NAME = 'age [plr]', DESC = 'Tells you the age of a player'}
CMDs[#CMDs + 1] = {NAME = 'chatage [plr]', DESC = 'Chats the age of a player'}
CMDs[#CMDs + 1] = {NAME = 'joindate / jd [plr]', DESC = 'Tells you the date the player joined Roblox'}
CMDs[#CMDs + 1] = {NAME = 'chatjoindate / cjd [plr]', DESC = 'Chats the date the player joined Roblox'}
CMDs[#CMDs + 1] = {NAME = 'os [plr]', DESC = 'Shows a players platform'}
CMDs[#CMDs + 1] = {NAME = 'chatos [plr]', DESC = 'Chats a players platform'}
CMDs[#CMDs + 1] = {NAME = 'setos [text]', DESC = 'Sets your os to whatever you input'}
CMDs[#CMDs + 1] = {NAME = 'copyname / copyuser [plr]', DESC = 'Copies a players full username to your clipboard'}
CMDs[#CMDs + 1] = {NAME = 'copyid [plr]', DESC = 'Copies a players user ID to your clipboard'}
CMDs[#CMDs + 1] = {NAME = 'copyappearanceid [plr]', DESC = 'Copies a players appearance ID to your clipboard'}
CMDs[#CMDs + 1] = {NAME = 'bang [plr]', DESC = 'owo'}
CMDs[#CMDs + 1] = {NAME = 'unbang [plr]', DESC = 'uwu'}
CMDs[#CMDs + 1] = {NAME = 'headsit [plr]', DESC = 'Sit on a players head'}
CMDs[#CMDs + 1] = {NAME = 'walkto / follow [plr]', DESC = 'Follow a player'}
CMDs[#CMDs + 1] = {NAME = 'unwalkto / unfollow', DESC = 'Stops following a player'}
CMDs[#CMDs + 1] = {NAME = 'kill [plr] (TOOL)', DESC = 'Kills a player (YOU NEED A TOOL)'}
CMDs[#CMDs + 1] = {NAME = 'bring [plr] (TOOL)', DESC = 'Brings a player (YOU NEED A TOOL)'}
CMDs[#CMDs + 1] = {NAME = 'fastkill [plr] (TOOL)', DESC = 'Kills a player (less reliable) (YOU NEED A TOOL)'}
CMDs[#CMDs + 1] = {NAME = 'fastbring [plr] (TOOL)', DESC = 'Brings a player (less reliable) (YOU NEED A TOOL)'}
CMDs[#CMDs + 1] = {NAME = 'fling', DESC = 'Flings anyone you touch'}
CMDs[#CMDs + 1] = {NAME = 'unfling', DESC = 'Disables the fling command'}
CMDs[#CMDs + 1] = {NAME = 'loopoof', DESC = 'Loops everyones character sounds (everyone can hear)'}
CMDs[#CMDs + 1] = {NAME = 'unloopoof', DESC = 'Stops the oof chaos'}
CMDs[#CMDs + 1] = {NAME = 'hitbox [plr] [size]', DESC = 'Expands the hitbox for players heads (default is 1)'}
CMDs[#CMDs + 1] = {NAME = '', DESC = ''}
CMDs[#CMDs + 1] = {NAME = 'reset', DESC = 'Resets your character normally'}
CMDs[#CMDs + 1] = {NAME = 'respawn', DESC = 'Respawns you'}
CMDs[#CMDs + 1] = {NAME = 'refresh / re', DESC = 'Respawns and brings you back to the same position'}
CMDs[#CMDs + 1] = {NAME = 'invisible / invis', DESC = 'Makes you invisible to other players'}
CMDs[#CMDs + 1] = {NAME = 'visible / vis', DESC = 'Makes you visible to other players'}
CMDs[#CMDs + 1] = {NAME = 'weaken [num]', DESC = 'Makes your character less dense'}
CMDs[#CMDs + 1] = {NAME = 'unweaken', DESC = 'Sets your characters CustomPhysicalProperties to default'}
CMDs[#CMDs + 1] = {NAME = 'strengthen [num]', DESC = 'Makes your character more dense (CustomPhysicalProperties)'}
CMDs[#CMDs + 1] = {NAME = 'unstrengthen', DESC = 'Sets your characters CustomPhysicalProperties to default'}
CMDs[#CMDs + 1] = {NAME = 'speed / ws [num]', DESC = 'Change your walkspeed'}
CMDs[#CMDs + 1] = {NAME = 'hipheight / hheight [num]', DESC = 'Adjusts hip height'}
CMDs[#CMDs + 1] = {NAME = 'jumppower / jpower [num]', DESC = 'Change a players jump height'}
CMDs[#CMDs + 1] = {NAME = 'gravity / grav [num]', DESC = 'Change your gravity'}
CMDs[#CMDs + 1] = {NAME = 'sit', DESC = 'Makes your character sit'}
CMDs[#CMDs + 1] = {NAME = 'jump', DESC = 'Makes your character jump'}
CMDs[#CMDs + 1] = {NAME = 'infinitejump / infjump', DESC = 'Allows you to jump before hitting the ground'}
CMDs[#CMDs + 1] = {NAME = 'uninfinitejump / uninfjump', DESC = 'Disables infjump'}
CMDs[#CMDs + 1] = {NAME = 'platformstand / stun', DESC = 'Enables PlatformStand'}
CMDs[#CMDs + 1] = {NAME = 'unplatformstand / unstun', DESC = 'Disables PlatformStand'}
CMDs[#CMDs + 1] = {NAME = 'team [team name] (CLIENT)', DESC = 'Changes your team. Sometimes fools localscripts.'}
CMDs[#CMDs + 1] = {NAME = 'nobillboardgui / nobgui / noname', DESC = 'Removes billboard and surface guis from your players (i.e. name guis at cafes)'}
CMDs[#CMDs + 1] = {NAME = 'animation / anim [ID] [speed]', DESC = 'Makes your character perform an animation (must be by roblox to replicate)'}
CMDs[#CMDs + 1] = {NAME = 'dance', DESC = 'Makes you  d a n c e'}
CMDs[#CMDs + 1] = {NAME = 'undance', DESC = 'Stops dance animations'}
CMDs[#CMDs + 1] = {NAME = 'spasm', DESC = 'Makes you  c r a z y'}
CMDs[#CMDs + 1] = {NAME = 'unspasm', DESC = 'Stops spasm'}
CMDs[#CMDs + 1] = {NAME = 'headthrow', DESC = 'Simply makes you throw your head'}
CMDs[#CMDs + 1] = {NAME = 'noarms', DESC = 'Removes your arms'}
CMDs[#CMDs + 1] = {NAME = 'nolegs', DESC = 'Removes your arms'}
CMDs[#CMDs + 1] = {NAME = 'nolimbs', DESC = 'Removes your limbs'}
CMDs[#CMDs + 1] = {NAME = 'naked', DESC = 'Removes your clothing'}
CMDs[#CMDs + 1] = {NAME = 'noface / removeface', DESC = 'Removes your face'}
CMDs[#CMDs + 1] = {NAME = 'blockhead', DESC = 'Turns your head into a block'}
CMDs[#CMDs + 1] = {NAME = 'blockhats', DESC = 'Turns your hats into blocks'}
CMDs[#CMDs + 1] = {NAME = 'blocktool', DESC = 'Turns the currently selected tool into a block'}
CMDs[#CMDs + 1] = {NAME = 'creeper', DESC = 'Makes you look like a creeper'}
CMDs[#CMDs + 1] = {NAME = 'drophats', DESC = 'Drops your hats'}
CMDs[#CMDs + 1] = {NAME = 'nohats / deletehats / rhats', DESC = 'Deletes your hats'}
CMDs[#CMDs + 1] = {NAME = 'spin [speed]', DESC = 'Spins your character'}
CMDs[#CMDs + 1] = {NAME = 'unspin', DESC = 'Disables spin'}
CMDs[#CMDs + 1] = {NAME = 'hatspin / spinhats', DESC = 'Spins your characters accessories'}
CMDs[#CMDs + 1] = {NAME = 'unhatspin / unspinhats', DESC = 'Undoes spinhats'}
CMDs[#CMDs + 1] = {NAME = 'vr', DESC = 'Loads CLOVR by Abacaxl'}
CMDs[#CMDs + 1] = {NAME = 'split', DESC = 'Splits your character in half'}
CMDs[#CMDs + 1] = {NAME = '', DESC = ''}
CMDs[#CMDs + 1] = {NAME = 'autoclick [click delay] [release delay]', DESC = 'Automatically clicks your mouse with a set delay'}
CMDs[#CMDs + 1] = {NAME = 'unautoclick / noautoclick', DESC = 'Turns off autoclick'}
CMDs[#CMDs + 1] = {NAME = 'hovername', DESC = 'Shows a players username when your mouse is hovered over them'}
CMDs[#CMDs + 1] = {NAME = 'unhovername / nohovername', DESC = 'Turns off hovername'}
CMDs[#CMDs + 1] = {NAME = 'mousesensitivity / ms [0-10]', DESC = 'Sets your mouse sensitivity (affects first person and right click drag) (default is 1)'}
CMDs[#CMDs + 1] = {NAME = 'clickdelete', DESC = 'Go to settings>Keybinds>Add for clicktp'}
CMDs[#CMDs + 1] = {NAME = 'clickteleport', DESC = 'Go to settings>Keybinds>Add for click tp'}
CMDs[#CMDs + 1] = {NAME = '', DESC = ''}
CMDs[#CMDs + 1] = {NAME = 'tools', DESC = 'Copies tools from ReplicatedStorage and Lighting'}
CMDs[#CMDs + 1] = {NAME = 'notools / removetools / deletetools', DESC = 'Removes tools from character and backpack'}
CMDs[#CMDs + 1] = {NAME = 'grabtools', DESC = 'Automatically get tools that are dropped'}
CMDs[#CMDs + 1] = {NAME = 'ungrabtools / nograbtools', DESC = 'Disables grabtools'}
CMDs[#CMDs + 1] = {NAME = 'copytools [plr]', DESC = 'Copies a players tools'}
CMDs[#CMDs + 1] = {NAME = 'dupetools / clonetools', DESC = 'Duplicates your inventory tools'}
CMDs[#CMDs + 1] = {NAME = 'droptools', DESC = 'Drops your tools'}
CMDs[#CMDs + 1] = {NAME = 'droppabletools', DESC = 'Makes your tools droppable'}
CMDs[#CMDs + 1] = {NAME = 'equiptools', DESC = 'Equips every tool in your inventory at once'}
CMDs[#CMDs + 1] = {NAME = 'reach [num]', DESC = 'Increases the hitbox of your held tool'}
CMDs[#CMDs + 1] = {NAME = 'unreach / noreach', DESC = 'Turns off reach'}
CMDs[#CMDs + 1] = {NAME = 'grippos [X Y Z]', DESC = 'Changes your current tools grip position'}
CMDs[#CMDs + 1] = {NAME = '', DESC = ''}
CMDs[#CMDs + 1] = {NAME = 'addalias [cmd] [alias]', DESC = 'Adds an alias to a command'}
CMDs[#CMDs + 1] = {NAME = 'removealias [alias]', DESC = 'Removes a custom alias'}
CMDs[#CMDs + 1] = {NAME = 'clraliases', DESC = 'Removes all custom aliases'}
CMDs[#CMDs + 1] = {NAME = '', DESC = ''}
CMDs[#CMDs + 1] = {NAME = 'addplugin / plugin [name]', DESC = 'Add a plugin via command'}
CMDs[#CMDs + 1] = {NAME = 'removeplugin / deleteplugin [name]', DESC = 'Remove a plugin via command'}
CMDs[#CMDs + 1] = {NAME = 'reloadplugin [name]', DESC = 'Reloads a plugin'}
CMDs[#CMDs + 1] = {NAME = '', DESC = ''}
CMDs[#CMDs + 1] = {NAME = 'breakloops / break (cmd loops)', DESC = 'Stops any cmd loops (;100^1^cmd)'}
CMDs[#CMDs + 1] = {NAME = 'removecmd / deletecmd', DESC = 'Removes a command until the admin is reloaded'}
wait()

for i = 1, #CMDs do
	local newcmd = Holder.Example:Clone()
	newcmd.Parent = Holder.CMDs
	newcmd.Visible = false
	newcmd.Text = CMDs[i].NAME
	newcmd.Name = 'CMD'
	table.insert(text1,newcmd)
	if CMDs[i].DESC ~= '' then
		local title = Instance.new("StringValue",newcmd)
		title.Name = "Title"
		title.Value = CMDs[i].NAME
		local desc = Instance.new("StringValue",newcmd)
		desc.Name = "Desc"
		desc.Value = CMDs[i].DESC
	end
end

IndexContents('',true)

function getText(object)
	if object ~= nil then
		if object:FindFirstChild('Desc') ~= nil then
			return {object.Desc.Value, object:FindFirstChild('Title')}
		elseif object.Parent:FindFirstChild('Desc') ~= nil then
			return {object.Parent.Desc.Value, object.Parent:FindFirstChild('Title')}
		end
	end
	return nil
end

function checkTT()
	local t
	local guisAtPosition = game:GetService("CoreGui"):GetGuiObjectsAtPosition(IYMouse.X, IYMouse.Y)
	
	for _, gui in pairs(guisAtPosition) do
		if gui.Parent == CMDsF then
			t = gui
		end
	end
	
	if t ~= nil then
		local gt = getText(t)
		if gt ~= nil then
			local x = IYMouse.X
			local y = IYMouse.Y
			local xP
			local yP
			if IYMouse.X > 200 then
				xP = x - 201
			else
				xP = x + 21
			end
			if IYMouse.Y > (IYMouse.ViewSizeY-96) then
				yP = y - 97
			else
				yP = y
			end
			Tooltip.Position = UDim2.new(0, xP, 0, yP)
			Tooltip.Description.Text = gt[1]
			if gt[2] ~= nil then
				Tooltip.Title.Text = gt[2].Value
			else
				Tooltip.Title.Text = ''
			end
			Tooltip.Visible = true
		else
			Tooltip.Visible = false
		end
	else
		Tooltip.Visible = false
	end
end

function FindInTable(Table, Name)
	for i,v in pairs(Table) do
		if v == Name then
			return true
		end
	end
	return false
end

function GetInTable(Table, Name)
	for i = 1, #Table do
		if Table[i] == Name then
			return i
		end
	end
	return false
end

function respawn(plr)
	plr.Character:FindFirstChildOfClass('Humanoid').Health = 0
	plr.Character:BreakJoints()
	for _,v in pairs(plr.Character:GetChildren()) do
		if v:IsA("BasePart") then
			v:Destroy()
		end
	end
end

refreshCmd = false

function refresh(plr)
	spawn(function()
		refreshCmd = true
		local rpos = plr.Character.HumanoidRootPart.Position
		wait()
		respawn(plr)
		wait()
		repeat wait() until plr.Character ~= nil and plr.Character:FindFirstChild('HumanoidRootPart')
		wait(.1)
		plr.Character:MoveTo(rpos)
		wait()
		refreshCmd = false
	end)
end

local lastDeath

function onDied()
	spawn(function()
		if pcall(function() Players.LocalPlayer.Character:FindFirstChildOfClass('Humanoid') end) and Players.LocalPlayer.Character:FindFirstChildOfClass('Humanoid') then
			Players.LocalPlayer.Character:FindFirstChildOfClass('Humanoid').Died:connect(function()
				if Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
					lastDeath = Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart").CFrame
				end
			end)
		else
			wait(2)
			onDied()
		end
	end)
end

Clip = true

Players.LocalPlayer.CharacterAdded:Connect(function()
	FLYING = false
	Floating = false
	bangplr = nil
	
	if not Clip then
		execCmd('clip nonotify')
	end
	
	if #spawnCmds > 0 then
		for i,v in pairs(spawnCmds)do
			spawn(function()
				wait(v.DELAY)
				execCmd(v.COMMAND,Players.LocalPlayer)
			end)
		end
	end

	repeat wait() until Players.LocalPlayer.Character:FindFirstChild('HumanoidRootPart')

	if spawnpoint and not refreshCmd and spawnpos ~= nil then
		wait(.1)
		Players.LocalPlayer.Character.HumanoidRootPart.CFrame = spawnpos
	end
	
	onDied()
end)

onDied()

std={}
std.inTable=function(tbl,val)
    if tbl==nil then return false end
    for _,v in pairs(tbl)do
        if v==val then return true end
    end 
	return false
end

function getstring(begin)
	local start = begin-1
	local AA = '' for i,v in pairs(cargs) do
		if i > start then
			if AA ~= '' then
				AA = AA .. ' ' .. v
			else
				AA = AA .. v
			end
		end
	end
	return AA
end

findCmd=function(cmd_name)
	for i,v in pairs(cmds)do
		if v.NAME:lower()==cmd_name:lower() or std.inTable(v.ALIAS,cmd_name:lower()) then
			return v
		end
	end
	return customAlias[cmd_name:lower()]
end

function splitString(str,delim)
	local broken = {}
	if delim == nil then delim = "," end
		for w in string.gmatch(str,"[^"..delim.."]+") do
			table.insert(broken,w)
		end
	return broken
end

historyCount = 0
cmdHistory = {}
split=" "
lastBreakTime = 0
function execCmd(cmdStr,speaker)
	spawn(function()
		local rawCmdStr = cmdStr
		cmdStr = string.gsub(cmdStr,"\\\\","%%BackSlash%%")
		local commandsToRun = splitString(cmdStr,"\\")
		for i,v in pairs(commandsToRun) do
			v = string.gsub(v,"%%BackSlash%%","\\")
			local x,y,num = v:find("^(%d+)%^")
			local cmdDelay = 0
			if num then
				v = v:sub(y+1)
				local x,y,del = v:find("^([%d%.]+)%^")
				if del then
					v = v:sub(y+1)
					cmdDelay = tonumber(del) or 0
				end
			end
		num = tonumber(num or 1)
		local args = splitString(v,split)
		local cmd = findCmd(args[1])
		if cmd then
			table.remove(args,1)
			cargs = args
			if not speaker then speaker = Players.LocalPlayer end
			if speaker == Players.LocalPlayer then
				if cmdHistory[1] ~= rawCmdStr then table.insert(cmdHistory,1,rawCmdStr) end
			end
			if #cmdHistory > 20 then table.remove(cmdHistory) end
			local cmdStartTime = tick()
			for rep = 1,num do
				if lastBreakTime > cmdStartTime then break end
					pcall(function()
						cmd.FUNC(args, speaker)
					end)
					if cmdDelay ~= 0 then wait(cmdDelay) end
				end
			end
		end
	end)
end	

function addcmd(name,alias,func,plgn)
	cmds[#cmds+1]=
	{
		NAME=name;
		ALIAS=alias;
		FUNC=func;
		PLUGIN=plgn;
	}
end

function removecmd(cmd)
	if cmd ~= " " then
		for i = #cmds,1,-1 do
			if cmds[i].NAME == cmd or FindInTable(cmds[i].ALIAS,cmd) then
				table.remove(cmds, i)
				for a,c in pairs(Holder.CMDs:GetChildren()) do
					if string.find(c.Text, "^"..cmd.."$") or string.find(c.Text, "^"..cmd.." ") or string.find(c.Text, " "..cmd.."$") or string.find(c.Text, " "..cmd.." ") then
						c.TextTransparency = 0.7
						c.MouseButton1Click:Connect(function()
							notify(c.Text, "Command has been disabled by you or a plugin")
						end)
					end
				end
			end
		end
	end
end

function addbind(cmd,key)
	binds[#binds+1]=
	{
		COMMAND=cmd;
		KEY=key;
	}
end

function addspawn(cmd,sDelay)
	spawnCmds[#spawnCmds+1]=
	{
		COMMAND=cmd;
		DELAY=sDelay;
	}
end

function addcmdtext(text,name,desc)
	local newcmd = Holder.Example:Clone()
	local tooltipText = tostring(text)
	local tooltipDesc = tostring(desc)
	newcmd.Parent = Holder.CMDs
	newcmd.Visible = false
	newcmd.Text = text
	newcmd.Name = 'PLUGIN_'..name
	table.insert(text1,newcmd)
	if desc and desc ~= '' then
		local title = Instance.new("StringValue",newcmd)
		title.Name = "Title"
		title.Value = tooltipText
		local desc = Instance.new("StringValue",newcmd)
		desc.Name = "Desc"
		desc.Value = tooltipDesc
	end
end

SpecialPlayerCases = {
	["all"] = function(speaker)return Players:GetPlayers() end,
	["others"] = function(speaker)
		local plrs = {}
		for i,v in pairs(Players:GetPlayers()) do
			if v ~= speaker then
				table.insert(plrs,v)
			end
		end
		return plrs
	 end,
	["me"] = function(speaker)return {speaker} end,
	["#(%d+)"] = function(speaker,args,currentList)
		local returns = {}
		local randAmount = tonumber(args[1])
		local players = {unpack(currentList)}
		for i = 1,randAmount do
			if #players == 0 then break end
			local randIndex = math.random(1,#players)
			table.insert(returns,players[randIndex])
			table.remove(players,randIndex)
		end
		return returns
	end,
	["random"] = function(speaker,args,currentList)
		local players = currentList
		return {players[math.random(1,#players)]}
	end,
	["%%(.+)"] = function(speaker,args)
		local returns = {}
		local team = args[1]
		for _,plr in pairs(Players:GetPlayers()) do
			if plr.Team and string.sub(string.lower(plr.Team.Name),1,#team) == string.lower(team) then
				table.insert(returns,plr)
			end
		end
		return returns
	end,
	["allies"] = function(speaker)
		local returns = {}
		local team = speaker.Team
		for _,plr in pairs(Players:GetPlayers()) do
			if plr.Team == team then
				table.insert(returns,plr)
			end
		end
		return returns
	end,
	["enemies"] = function(speaker)
		local returns = {}
		local team = speaker.Team
		for _,plr in pairs(Players:GetPlayers()) do
			if plr.Team ~= team then
				table.insert(returns,plr)
			end
		end
		return returns
	end,
	["team"] = function(speaker)
		local returns = {}
		local team = speaker.Team
		for _,plr in pairs(Players:GetPlayers()) do
			if plr.Team == team then
				table.insert(returns,plr)
			end
		end
		return returns
	end,
	["nonteam"] = function(speaker)
		local returns = {}
		local team = speaker.Team
		for _,plr in pairs(Players:GetPlayers()) do
			if plr.Team ~= team then
				table.insert(returns,plr)
			end
		end
		return returns
	end,
	["friends"] = function(speaker,args)
		local returns = {}
		for _,plr in pairs(Players:GetPlayers()) do
			if plr:IsFriendsWith(speaker.UserId) and plr ~= speaker then
				table.insert(returns,plr)
			end
		end
		return returns
	end,
	["nonfriends"] = function(speaker,args)
		local returns = {}
		for _,plr in pairs(Players:GetPlayers()) do
			if not plr:IsFriendsWith(speaker.UserId) and plr ~= speaker then
				table.insert(returns,plr)
			end
		end
		return returns
	end,
	["guests"] = function(speaker,args)
		local returns = {}
		for _,plr in pairs(Players:GetPlayers()) do
			if plr.Guest then
				table.insert(returns,plr)
			end
		end
		return returns
	end,
	["bacons"] = function(speaker,args)
		local returns = {}
		for _,plr in pairs(Players:GetPlayers()) do
			if plr.Character:FindFirstChild('Pal Hair') or plr.Character:FindFirstChild('Kate Hair') then
				table.insert(returns,plr)
			end
		end
		return returns
	end,
	["age(%d+)"] = function(speaker,args)
		local returns = {}
		local age = tonumber(args[1])
		if not age == nil then return end
		for _,plr in pairs(Players:GetPlayers()) do
		if plr.AccountAge <= age then
				table.insert(returns,plr)
			end
		end
		return returns
	end,
	["nearest"] = function(speaker,args)
		local speakerChar = speaker.Character
		if not speakerChar or not speakerChar:FindFirstChild("HumanoidRootPart") then return end
		local lowest = math.huge
		local NearestPlayer = nil
		for _,plr in pairs(Players:GetPlayers()) do
			if plr ~= speaker and plr.Character then
				local distance = plr:DistanceFromCharacter(speakerChar:FindFirstChild("HumanoidRootPart").Position)
				if distance < lowest then
					lowest = distance
					NearestPlayer = {plr}
				end
			end
		end
		return NearestPlayer
	end,
	["farthest"] = function(speaker,args)
		local speakerChar = speaker.Character
		if not speakerChar or not speakerChar:FindFirstChild("HumanoidRootPart") then return end
		local highest = math.huge
		local FarthestPlayer = nil
		for _,plr in pairs(Players:GetPlayers()) do
			if plr ~= speaker and plr.Character then
				local distance = plr:DistanceFromCharacter(speakerChar:FindFirstChild("HumanoidRootPart").Position)
				if distance > highest then
					highest = distance
					FarthestPlayer = {plr}
				end
			end
		end
		return FarthestPlayer
	end,
	["group(%d+)"] = function(speaker,args)
		local returns = {}
		local groupID = tonumber(args[1])
		for _,plr in pairs(Players:GetPlayers()) do
			if plr:IsInGroup(groupID) then  
				table.insert(returns,plr)
			end
		end
		return returns
	end,
	["rad(%d+)"] = function(speaker,args)
		local returns = {}
		local radius = tonumber(args[1])
		local speakerChar = speaker.Character
		if not speakerChar or not speakerChar:FindFirstChild("HumanoidRootPart") then return end
		for _,plr in pairs(Players:GetPlayers()) do
			if plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
				local magnitude = (plr.Character:FindFirstChild("HumanoidRootPart").Position-speakerChar.HumanoidRootPart.Position).magnitude
				if magnitude <= radius then table.insert(returns,plr) end
			end
		end
		return returns
	end
}

function toTokens(str)
	local tokens = {}
	for op,name in string.gmatch(str,"([+-])([^+-]+)") do
		table.insert(tokens,{Operator = op,Name = name})
	end
	return tokens
end

function onlyIncludeInTable(tab,matches)
	local matchTable = {}
	local resultTable = {}
	for i,v in pairs(matches) do matchTable[v.Name] = true end
	for i,v in pairs(tab) do if matchTable[v.Name] then table.insert(resultTable,v) end end
	return resultTable
end

function removeTableMatches(tab,matches)
	local matchTable = {}
	local resultTable = {}
	for i,v in pairs(matches) do matchTable[v.Name] = true end
	for i,v in pairs(tab) do if not matchTable[v.Name] then table.insert(resultTable,v) end end
	return resultTable
end

function getPlayersByName(name)
	local found = {}
	for i,v in pairs(Players:GetChildren()) do
		if string.sub(string.lower(v.Name),1,#name) == string.lower(name) then
			table.insert(found,v)
		end
	end
	return found
end

function getPlayer(list,speaker)
	if list == nil then return {speaker.Name} end
	local nameList = splitString(list,",")
	
	local foundList = {}
	
	for _,name in pairs(nameList) do
		if string.sub(name,1,1) ~= "+" and string.sub(name,1,1) ~= "-" then name = "+"..name end
		local tokens = toTokens(name)
		local initialPlayers = Players:GetPlayers()
		
		for i,v in pairs(tokens) do
			if v.Operator == "+" then
				local tokenContent = v.Name
				local foundCase = false
				for regex,case in pairs(SpecialPlayerCases) do
					local matches = {string.match(tokenContent,"^"..regex.."$")}
					if #matches > 0 then
						foundCase = true
						initialPlayers = onlyIncludeInTable(initialPlayers,case(speaker,matches,initialPlayers))
					end
				end
				if not foundCase then
					initialPlayers = onlyIncludeInTable(initialPlayers,getPlayersByName(tokenContent))
				end
			else
				local tokenContent = v.Name
				local foundCase = false
				for regex,case in pairs(SpecialPlayerCases) do
					local matches = {string.match(tokenContent,"^"..regex.."$")}
					if #matches > 0 then
						foundCase = true
						initialPlayers = removeTableMatches(initialPlayers,case(speaker,matches,initialPlayers))
					end
				end
				if not foundCase then
					initialPlayers = removeTableMatches(initialPlayers,getPlayersByName(tokenContent))
				end
			end
		end
		
		for i,v in pairs(initialPlayers) do table.insert(foundList,v) end
	end
	
	local foundNames = {}
	for i,v in pairs(foundList) do table.insert(foundNames,v.Name) end
	
	return foundNames
end

getprfx=function(strn)
    if strn:sub(1,string.len(prefix))==prefix then return{'cmd',string.len(prefix)+1}
    end return
end

function do_exec(str, plr)
	str = str:gsub('/e ', '')
	local t = getprfx(str)
	if not t then return end
	str = str:sub(t[2])
	if t[1]=='cmd' then
		execCmd(str, plr)
		IndexContents('',true,false,true)
		if canvasPos ~= nil then
			CMDsF.CanvasPosition = Vector2.new(0, canvasPos)
			canvasTop = false
		end
	end
end


Players.LocalPlayer.Chatted:connect(function(message)
	do_exec(message, Players.LocalPlayer)
end)

Holder.Cmdbar:GetPropertyChangedSignal("Text"):connect(function()
	if Holder.Cmdbar:IsFocused() then
		IndexContents(Holder.Cmdbar.Text,true,true)
	end
end)

tabComplete = nil
Holder.Cmdbar.FocusLost:connect(function(enterpressed)
	if enterpressed then
		execCmd(Holder.Cmdbar.Text,Players.LocalPlayer)
	end
	Holder.Cmdbar.Text = "Command Bar"
	IndexContents('',true,false,true)
	if canvasPos ~= nil then
		CMDsF.CanvasPosition = Vector2.new(0, canvasPos)
		canvasTop = false
	end
	if tabComplete then tabComplete:Disconnect() end
	if SettingsOpen == true then
		wait(0.2)
		Settings:TweenPosition(UDim2.new(0, 0, 0, 45), "InOut", "Quart", 0.2, true, nil)
		Holder.CMDs.Visible = false
	end
end)

Holder.Cmdbar.Focused:Connect(function()
	historyCount = 0 
	if SettingsOpen == true then
		wait(0.2)
		Holder.CMDs.Visible = true
		Holder.Settings:TweenPosition(UDim2.new(0, 0, 0, 220), "InOut", "Quart", 0.2, true, nil)
	end
	tabComplete = UserInputService.InputBegan:Connect(function(input,gameProcessed)
		if input.KeyCode == Enum.KeyCode.Tab and topCommand ~= nil then
			local str = topCommand
			local endingChar = {"[", "/", "(", " "}
			local stop = 0
			for i=1,#str do
				local c = str:sub(i,i)
				if table.find(endingChar, c) then
					stop = i
					break
				end
			end
			Holder.Cmdbar.Text = str:sub(1, stop - 1)..' '
			wait()
			Holder.Cmdbar.Text = Holder.Cmdbar.Text:gsub( '\t', '' )
			Holder.Cmdbar.CursorPosition = 1020
		end
	end)
end)

UserInputService.InputBegan:Connect(function(input)
    if not Holder.Cmdbar:IsFocused() then return end
    if input.KeyCode == Enum.KeyCode.Up then
        historyCount = historyCount + 1
        if historyCount > #cmdHistory then historyCount = #cmdHistory end
        Holder.Cmdbar.Text = cmdHistory[historyCount] or ""
    elseif input.KeyCode == Enum.KeyCode.Down then
        historyCount = historyCount - 1
        if historyCount < 1 then historyCount = 1 end
        Holder.Cmdbar.Text = cmdHistory[historyCount] or ""
    end
end)

ESPenabled = false
CHMSenabled = false

function round(num, numDecimalPlaces)
	local mult = 10^(numDecimalPlaces or 0)
	return math.floor(num * mult + 0.5) / mult
end

function ESP(plr)
	spawn(function()
		for i,v in pairs(PARENT:GetChildren()) do
			if v.Name == plr.Name..'_ESP' then
				v:Destroy()
			end
		end
		wait()
		if plr.Character and plr.Name ~= Players.LocalPlayer.Name and not PARENT:FindFirstChild(plr.Name..'_ESP') then
			local ESPholder = Instance.new("Folder", PARENT)
			ESPholder.Name = plr.Name..'_ESP'
			repeat wait(1) until plr.Character and plr.Character:FindFirstChild('HumanoidRootPart') and plr.Character:FindFirstChild('Humanoid')
			for b,n in pairs (plr.Character:GetChildren()) do
				if (n:IsA("BasePart")) then
					local a = Instance.new("BoxHandleAdornment", ESPholder)
					a.Name = plr.Name
					a.Adornee = n
					a.AlwaysOnTop = true
					a.ZIndex = 0
					a.Size = n.Size
					a.Transparency = 0.3
					a.Color = plr.TeamColor
				end
			end
            if plr.Character and plr.Character:FindFirstChild('Head') then
				local BillboardGui = Instance.new("BillboardGui", ESPholder)
				local TextLabel = Instance.new("TextLabel")
				BillboardGui.Adornee = plr.Character.Head
				BillboardGui.Name = plr.Name
				BillboardGui.Size = UDim2.new(0, 100, 0, 150)
				BillboardGui.StudsOffset = Vector3.new(0, 1, 0)
				BillboardGui.AlwaysOnTop = true
				TextLabel.Parent = BillboardGui
				TextLabel.BackgroundTransparency = 1
				TextLabel.Position = UDim2.new(0, 0, 0, -50)
				TextLabel.Size = UDim2.new(0, 100, 0, 100)
				TextLabel.Font = Enum.Font.SourceSansSemibold
				TextLabel.TextSize = 20
				TextLabel.TextColor3 = Color3.new(1, 1, 1)
				TextLabel.TextStrokeTransparency = 0
				TextLabel.TextYAlignment = Enum.TextYAlignment.Bottom
				local espLoopFunc
				plr.CharacterAdded:Connect(function()
					if ESPenabled then
						espLoopFunc:Disconnect()
						ESPholder:Destroy()
						repeat wait(1) until plr.Character:FindFirstChild('HumanoidRootPart') and plr.Character:FindFirstChild('Humanoid')
						ESP(plr)
					end
				end)
				local function espLoop()
					if PARENT:FindFirstChild(plr.Name..'_ESP') then
						if plr.Character and plr.Character:FindFirstChild('HumanoidRootPart') and plr.Character:FindFirstChild('Humanoid') then
							local pos = math.floor((Players.LocalPlayer.Character.HumanoidRootPart.Position - plr.Character.HumanoidRootPart.Position).magnitude)
							TextLabel.Text = 'Name: '..plr.Name..' | Health: '..round(plr.Character:FindFirstChildOfClass('Humanoid').Health, 1)..' | Studs: '..pos
						end
					else
						espLoopFunc:Disconnect()
					end
				end
				espLoopFunc = game:GetService("RunService").RenderStepped:Connect(espLoop)
			end
		end
	end)
end

function CHMS(plr)
	spawn(function()
		for i,v in pairs(PARENT:GetChildren()) do
			if v.Name == plr.Name..'_CHMS' then
				v:Destroy()
			end
		end
		wait()
		if plr.Character and plr.Name ~= Players.LocalPlayer.Name and not PARENT:FindFirstChild(plr.Name..'_CHMS') then
			local ESPholder = Instance.new("Folder", PARENT)
			ESPholder.Name = plr.Name..'_CHMS'
			repeat wait(1) until plr.Character and plr.Character:FindFirstChild('HumanoidRootPart') and plr.Character:FindFirstChild('Humanoid')
			for b,n in pairs (plr.Character:GetChildren()) do
				if (n:IsA("BasePart")) then
					local a = Instance.new("BoxHandleAdornment", ESPholder)
					a.Name = plr.Name
					a.Adornee = n
					a.AlwaysOnTop = true
					a.ZIndex = 0
					a.Size = n.Size
					a.Transparency = 0.3
					a.Color = plr.TeamColor
				end
			end
			plr.CharacterAdded:Connect(function()
				if CHMSenabled then
					ESPholder:Destroy()
					repeat wait(1) until plr.Character:FindFirstChild('HumanoidRootPart') and plr.Character:FindFirstChild('Humanoid')
					CHMS(plr)
				end
			end)
		end
	end)
end

function Locate(plr)
	spawn(function()
		for i,v in pairs(PARENT:GetChildren()) do
			if v.Name == plr.Name..'_LC' then
				v:Destroy()
			end
		end
		wait()
		if plr.Character and plr.Name ~= Players.LocalPlayer.Name and not PARENT:FindFirstChild(plr.Name..'_LC') then
			local ESPholder = Instance.new("Folder", PARENT)
			ESPholder.Name = plr.Name..'_LC'
			repeat wait(1) until plr.Character and plr.Character:FindFirstChild('HumanoidRootPart') and plr.Character:FindFirstChild('Humanoid')
			for b,n in pairs (plr.Character:GetChildren()) do
				if (n:IsA("BasePart")) then
					local a = Instance.new("BoxHandleAdornment", ESPholder)
					a.Name = plr.Name
					a.Adornee = n
					a.AlwaysOnTop = true
					a.ZIndex = 0
					a.Size = n.Size
					a.Transparency = 0.3
					a.Color = plr.TeamColor
				end
			end
			if plr.Character and plr.Character:FindFirstChild('Head') then
				local BillboardGui = Instance.new("BillboardGui", ESPholder)
				local TextLabel = Instance.new("TextLabel")
				BillboardGui.Adornee = plr.Character.Head
				BillboardGui.Name = plr.Name
				BillboardGui.Size = UDim2.new(0, 100, 0, 150)
				BillboardGui.StudsOffset = Vector3.new(0, 1, 0)
				BillboardGui.AlwaysOnTop = true
				TextLabel.Parent = BillboardGui
				TextLabel.BackgroundTransparency = 1
				TextLabel.Position = UDim2.new(0, 0, 0, -50)
				TextLabel.Size = UDim2.new(0, 100, 0, 100)
				TextLabel.Font = Enum.Font.SourceSansSemibold
				TextLabel.TextSize = 20
				TextLabel.TextColor3 = Color3.new(1, 1, 1)
				TextLabel.TextStrokeTransparency = 0
				TextLabel.TextYAlignment = Enum.TextYAlignment.Bottom
				local lcLoopFunc
				plr.CharacterAdded:Connect(function()
					if ESPholder ~= nil and ESPholder.Parent ~= nil then
						lcLoopFunc:Disconnect()
						ESPholder:Destroy()
						repeat wait(1) until plr.Character:FindFirstChild('HumanoidRootPart') and plr.Character:FindFirstChild('Humanoid')
						Locate(plr)
					end
				end)
				local function lcLoop()
					if PARENT:FindFirstChild(plr.Name..'_LC') then
						if plr.Character and plr.Character:FindFirstChild('HumanoidRootPart') and plr.Character:FindFirstChild('Humanoid') then
							local pos = math.floor((Players.LocalPlayer.Character.HumanoidRootPart.Position - plr.Character.HumanoidRootPart.Position).magnitude)
							TextLabel.Text = 'Name: '..plr.Name..' | Health: '..round(plr.Character:FindFirstChildOfClass('Humanoid').Health, 1)..' | Studs: '..pos
						end
					else
						lcLoopFunc:Disconnect()
					end
				end
				lcLoopFunc = game:GetService("RunService").RenderStepped:Connect(lcLoop)
			end
		end
	end)
end

bindsGUI = KeybindEditor
awaitingInput = false
keySelected = false

function unkeybind(cmd,key)
	for i = #binds,1,-1 do
		if binds[i].COMMAND == cmd and binds[i].KEY == key then
			table.remove(binds, i)
		end
	end
	refreshbinds()
	updatesaves()
	if key == 'RightClick' or key == 'LeftClick' then
		notify('Keybinds Updated','Unbinded '..key..' from '..cmd)
	else
		notify('Keybinds Updated','Unbinded '..key:sub(14)..' from '..cmd)
	end
end

function refreshbinds()
	if Holder_2 then
		Holder_2:ClearAllChildren()
		Holder_2.CanvasSize = UDim2.new(0, 0, 0, 10)
		for i = 1, #binds do
			local YSize = 25
			local Position = ((i * YSize) - YSize)
			local newbind = Example_2:Clone()
			newbind.Parent = Holder_2
			newbind.Visible = true
			newbind.Position = UDim2.new(0,0,0, Position + 5)
			table.insert(shade2,newbind)
			table.insert(shade2,newbind.Text)
			table.insert(text1,newbind.Text)
			table.insert(shade3,newbind.Text.Delete)
			table.insert(text2,newbind.Text.Delete)
			local input = tostring(binds[i].KEY)
			local key
			if input == 'RightClick' or input == 'LeftClick' then
				key = input
			else
				key = input:sub(14)
			end
			newbind.Text.Text = key.." > "..binds[i].COMMAND
			Holder_2.CanvasSize = UDim2.new(0,0,0, Position + 30)
			newbind.Text.Delete.MouseButton1Click:Connect(function()
				unkeybind(binds[i].COMMAND,binds[i].KEY)
			end)
		end
	end
end

refreshbinds()

PositionsFrame.Delete.MouseButton1Click:Connect(function()
	execCmd('cpos')
end)

function refreshwaypoints()
	if #WayPoints > 0 or #pWayPoints > 0 then
		PositionsHint:Destroy()
	end
	if Holder_4 then
		Holder_4:ClearAllChildren()
		Holder_4.CanvasSize = UDim2.new(0, 0, 0, 10)
		local YSize = 25
		local num = 1
		for i = 1, #WayPoints do
			local Position = ((num * YSize) - YSize)
			local newpoint = Example_4:Clone()
			newpoint.Parent = Holder_4
			newpoint.Visible = true
			newpoint.Position = UDim2.new(0,0,0, Position + 5)
			newpoint.Text.Text = WayPoints[i].NAME
			table.insert(shade2,newpoint)
			table.insert(shade2,newpoint.Text)
			table.insert(text1,newpoint.Text)
			table.insert(shade3,newpoint.Text.Delete)
			table.insert(text2,newpoint.Text.Delete)
			table.insert(shade3,newpoint.Text.TP)
			table.insert(text2,newpoint.Text.TP)
			Holder_4.CanvasSize = UDim2.new(0,0,0, Position + 30)
			newpoint.Text.Delete.MouseButton1Click:Connect(function()
				execCmd('dpos '..WayPoints[i].NAME)
			end)
			newpoint.Text.TP.MouseButton1Click:Connect(function()
				execCmd("loadpos "..WayPoints[i].NAME)
			end)
			num = num+1
		end
		for i = 1, #pWayPoints do
			local Position = ((num * YSize) - YSize)
			local newpoint = Example_4:Clone()
			newpoint.Parent = Holder_4
			newpoint.Visible = true
			newpoint.Position = UDim2.new(0,0,0, Position + 5)
			newpoint.Text.Text = pWayPoints[i].NAME
			table.insert(shade2,newpoint)
			table.insert(shade2,newpoint.Text)
			table.insert(text1,newpoint.Text)
			table.insert(shade3,newpoint.Text.Delete)
			table.insert(text2,newpoint.Text.Delete)
			table.insert(shade3,newpoint.Text.TP)
			table.insert(text2,newpoint.Text.TP)
			Holder_4.CanvasSize = UDim2.new(0,0,0, Position + 30)
			newpoint.Text.Delete.MouseButton1Click:Connect(function()
				execCmd('dpos '..pWayPoints[i].NAME)
			end)
			newpoint.Text.TP.MouseButton1Click:Connect(function()
				execCmd("loadpos "..pWayPoints[i].NAME)
			end)
			num = num+1
		end
	end
end

refreshwaypoints()

function removeSpawnC(cmd,Delay)
	for i = #spawnCmds,1,-1 do
		if spawnCmds[i].COMMAND == cmd and spawnCmds[i].DELAY == Delay then
			table.remove(spawnCmds, i)
		end
	end
	refreshSpawnC()
	updatesaves()
	notify('Spawn Commands Updated','Removed "'..cmd..'" from spawn commands')
end

function refreshSpawnC()
	if Holder_6 then
		Holder_6:ClearAllChildren()
		Holder_6.CanvasSize = UDim2.new(0, 0, 0, 10)
		for i = 1, #spawnCmds do
			local YSize = 25
			local Position = ((i * YSize) - YSize)
			local newspawn = Example_2:Clone()
			newspawn.Parent = Holder_6
			newspawn.Visible = true
			newspawn.Position = UDim2.new(0,0,0, Position + 5)
			table.insert(shade2,newspawn)
			table.insert(shade2,newspawn.Text)
			table.insert(text1,newspawn.Text)
			table.insert(shade3,newspawn.Text.Delete)
			table.insert(text2,newspawn.Text.Delete)
			if spawnCmds[i].DELAY == 0 or spawnCmds[i].DELAY == '0' then
				newspawn.Text.Text = spawnCmds[i].COMMAND
			else
				newspawn.Text.Text = spawnCmds[i].COMMAND..' (Delay '..spawnCmds[i].DELAY..')'
			end
			Holder_6.CanvasSize = UDim2.new(0,0,0, Position + 30)
			newspawn.Text.Delete.MouseButton1Click:Connect(function()
				removeSpawnC(spawnCmds[i].COMMAND,spawnCmds[i].DELAY)
				refreshSpawnC()
			end)
		end
	end
end

refreshSpawnC()

function refreshaliases()
	if #aliases > 0 then
		AliasHint:Destroy()
	end
	if Holder_3 then
		Holder_3:ClearAllChildren()
		Holder_3.CanvasSize = UDim2.new(0, 0, 0, 10)
		for i = 1, #aliases do
			local YSize = 25
			local Position = ((i * YSize) - YSize)
			local newalias = Example_3:Clone()
			newalias.Parent = Holder_3
			newalias.Visible = true
			newalias.Position = UDim2.new(0,0,0, Position + 5)
			newalias.Text.Text = aliases[i].CMD.." > "..aliases[i].ALIAS
			table.insert(shade2,newalias)
			table.insert(shade2,newalias.Text)
			table.insert(text1,newalias.Text)
			table.insert(shade3,newalias.Text.Delete)
			table.insert(text2,newalias.Text.Delete)
			Holder_3.CanvasSize = UDim2.new(0,0,0, Position + 30)
			newalias.Text.Delete.MouseButton1Click:Connect(function()
				execCmd('removealias '..aliases[i].ALIAS)
			end)
		end
	end
end

BindTo.MouseButton1Click:Connect(function()
	awaitingInput = true
	BindTo.Text = 'Press something'
end)

Add_2.MouseButton1Click:Connect(function()
	if keySelected then
		if string.find(Cmdbar_2.Text, "\\\\") then
			notify('Keybind Error','Only use one backslash to keybind multiple commands into one keybind or command')
		else
			addbind(Cmdbar_2.Text,keyPressed)
			refreshbinds()
			updatesaves()
			if keyPressed == 'RightClick' or keyPressed == 'LeftClick' then
				notify('Keybinds Updated','Binded '..keyPressed..' to '..Cmdbar_2.Text)
			else
				notify('Keybinds Updated','Binded '..keyPressed:sub(14)..' to '..Cmdbar_2.Text)
			end
		end
	end
end)

Exit_2.MouseButton1Click:Connect(function()
	Cmdbar_2.Text = 'Command'
	BindTo.Text = 'Click to bind'
	keySelected = false
	KeybindEditor:TweenPosition(UDim2.new(0.5, -180, 0, -400), "InOut", "Quart", 0.5, true, nil)
end)

function onInputBegan(input,gameProcessed)
	if awaitingInput then
		if input.UserInputType == Enum.UserInputType.Keyboard then
			keyPressed = tostring(input.KeyCode)
			BindTo.Text = keyPressed:sub(14)
		elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
			keyPressed = 'LeftClick'
			BindTo.Text = 'LeftClick'
		elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
			keyPressed = 'RightClick'
			BindTo.Text = 'RightClick'
		end
		awaitingInput = false
		keySelected = true
	end
	if not gameProcessed and #binds > 0 then
		for i,v in pairs(binds)do
			if input.UserInputType == Enum.UserInputType.Keyboard and v.KEY:lower()==tostring(input.KeyCode):lower() then
				execCmd(v.COMMAND,Players.LocalPlayer)
			elseif input.UserInputType == Enum.UserInputType.MouseButton1 and v.KEY:lower()=='leftclick' then
				execCmd(v.COMMAND,Players.LocalPlayer)
			elseif input.UserInputType == Enum.UserInputType.MouseButton2 and v.KEY:lower()=='rightclick' then
				execCmd(v.COMMAND,Players.LocalPlayer)
			end
		end
	end
end
 
UserInputService.InputBegan:connect(onInputBegan)

game:GetService('RunService').Stepped:connect(function()
	if bangplr then
		Players.LocalPlayer.Character.HumanoidRootPart.CFrame = Players[bangplr].Character.HumanoidRootPart.CFrame
	end
	if spinenabled then
		pcall(function()
			spinning.Position = Players.LocalPlayer.Character.Head.Position
		end)
	end
end)

Fly.Select.MouseButton1Click:Connect(function()
	if keySelected then
		addbind('togglefly',keyPressed)
		refreshbinds()
		updatesaves()
		if keyPressed == 'RightClick' or keyPressed == 'LeftClick' then
			notify('Keybinds Updated','Binded '..keyPressed..' to toggle fly')
		else
			notify('Keybinds Updated','Binded '..keyPressed:sub(14)..' to toggle fly')
		end
	end
end)

Noclip.Select.MouseButton1Click:Connect(function()
	if keySelected then
		addbind('togglenoclip',keyPressed)
		refreshbinds()
		updatesaves()
		if keyPressed == 'RightClick' or keyPressed == 'LeftClick' then
			notify('Keybinds Updated','Binded '..keyPressed..' to toggle noclip')
		else
			notify('Keybinds Updated','Binded '..keyPressed:sub(14)..' to toggle noclip')
		end
	end
end)

Float.Select.MouseButton1Click:Connect(function()
	if keySelected then
		addbind('togglefloat',keyPressed)
		refreshbinds()
		updatesaves()
		if keyPressed == 'RightClick' or keyPressed == 'LeftClick' then
			notify('Keybinds Updated','Binded '..keyPressed..' to toggle float')
		else
			notify('Keybinds Updated','Binded '..keyPressed:sub(14)..' to toggle float')
		end
	end
end)

ClickTP.Select.MouseButton1Click:Connect(function()
	if keySelected then
		addbind('clicktp',keyPressed)
		refreshbinds()
		updatesaves()
		if keyPressed == 'RightClick' or keyPressed == 'LeftClick' then
			notify('Keybinds Updated','Binded '..keyPressed..' to click tp')
		else
			notify('Keybinds Updated','Binded '..keyPressed:sub(14)..' to click tp')
		end
	end
end)

ClickDelete.Select.MouseButton1Click:Connect(function()
	if keySelected then
		addbind('clickdel',keyPressed)
		refreshbinds()
		updatesaves()
		if keyPressed == 'RightClick' or keyPressed == 'LeftClick' then
			notify('Keybinds Updated','Binded '..keyPressed..' to click delete')
		else
			notify('Keybinds Updated','Binded '..keyPressed:sub(14)..' to click delete')
		end
	end
end)

Xray.Select.MouseButton1Click:Connect(function()
	if keySelected then
		addbind('togglexray',keyPressed)
		refreshbinds()
		updatesaves()
		if keyPressed == 'RightClick' or keyPressed == 'LeftClick' then
			notify('Keybinds Updated','Binded '..keyPressed..' to toggle xray')
		else
			notify('Keybinds Updated','Binded '..keyPressed:sub(14)..' to toggle xray')
		end
	end
end)

Swim.Select.MouseButton1Click:Connect(function()
	if keySelected then
		addbind('toggleswim',keyPressed)
		refreshbinds()
		updatesaves()
		if keyPressed == 'RightClick' or keyPressed == 'LeftClick' then
			notify('Keybinds Updated','Binded '..keyPressed..' to toggle swim')
		else
			notify('Keybinds Updated','Binded '..keyPressed:sub(14)..' to toggle swim')
		end
	end
end)

Fling.Select.MouseButton1Click:Connect(function()
	if keySelected then
		addbind('togglefling',keyPressed)
		refreshbinds()
		updatesaves()
		if keyPressed == 'RightClick' or keyPressed == 'LeftClick' then
			notify('Keybinds Updated','Binded '..keyPressed..' to toggle fling')
		else
			notify('Keybinds Updated','Binded '..keyPressed:sub(14)..' to toggle fling')
		end
	end
end)

IYMouse.Button1Down:connect(function()
	for i,v in pairs(binds) do
		if v.COMMAND == 'clicktp' then
			local input = v.KEY
			if input == 'RightClick' and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) and Players.LocalPlayer.Character then
				pcall(function() Players.LocalPlayer.Character.HumanoidRootPart.CFrame = IYMouse.Hit + Vector3.new(0,7,0) end)
			elseif input == 'LeftClick' and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) and Players.LocalPlayer.Character then
				pcall(function() Players.LocalPlayer.Character.HumanoidRootPart.CFrame = IYMouse.Hit + Vector3.new(0,7,0) end)
			elseif UserInputService:IsKeyDown(Enum.KeyCode[input:sub(14)]) and Players.LocalPlayer.Character then
				pcall(function() Players.LocalPlayer.Character.HumanoidRootPart.CFrame = IYMouse.Hit + Vector3.new(0,7,0) end)
			end
		elseif v.COMMAND == 'clickdel' then
			local input = v.KEY
			if input == 'RightClick' and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
				pcall(function() IYMouse.Target:Destroy() end)
			elseif input == 'LeftClick' and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
				pcall(function() IYMouse.Target:Destroy() end)
			elseif UserInputService:IsKeyDown(Enum.KeyCode[input:sub(14)]) then
				pcall(function() IYMouse.Target:Destroy() end)
			end
		end
	end
end)

PluginsGUI = PluginEditor.background

function addPlugin(name)
	if name:lower() == 'plugin file name' or name:lower() == 'iy_fe.iy' or name == 'iy_fe' then
		notify('Plugin Error','Please enter a valid plugin')
	else
		local file
		local fileName
		if name:sub(-3) == '.iy' then
			pcall(function() file = readfile(name) end)
			fileName = name
		else
			pcall(function() file = readfile(name..'.iy') end)
			fileName = name..'.iy'
		end
		if file then
			if not FindInTable(PluginsTable, fileName) then
				table.insert(PluginsTable, fileName)
				LoadPlugin(fileName)
				refreshplugins()
			else
				notify('Plugin Error','This plugin is already added')
			end
		else
			notify('Plugin Error','Cannot locate file "'..fileName..'". Is the file in the correct folder?')
		end
	end
end

function deletePlugin(name)
	local pName = name..'.iy'
	if name:sub(-3) == '.iy' then
		pName = name
	end
	for i = #cmds,1,-1 do
		if cmds[i].PLUGIN == pName then
			table.remove(cmds, i)
		end
	end
	for i,v in pairs(Holder.CMDs:GetChildren()) do
		if v.Name == 'PLUGIN_'..pName then
			v:Destroy()
		end
	end
	for i,v in pairs(PluginsTable) do
		if v == pName then
			table.remove(PluginsTable, i)
			notify('Removed Plugin',pName..' was removed')
		end
	end
	IndexContents('',true)
	refreshplugins()
end

function refreshplugins(dontSave)
	if #PluginsTable > 0 then
		PluginsHint:Destroy()
	end
	if Holder_5 then
		Holder_5:ClearAllChildren()
		Holder_5.CanvasSize = UDim2.new(0, 0, 0, 10)
		for i,v in pairs(PluginsTable) do
			local pName = v
			local YSize = 25
			local Position = ((i * YSize) - YSize)
			local newplugin = Example_5:Clone()
			newplugin.Parent = Holder_5
			newplugin.Visible = true
			newplugin.Position = UDim2.new(0,0,0, Position + 5)
			newplugin.Text.Text = pName
			table.insert(shade2,newplugin)
			table.insert(shade2,newplugin.Text)
			table.insert(text1,newplugin.Text)
			table.insert(shade3,newplugin.Text.Delete)
			table.insert(text2,newplugin.Text.Delete)
			Holder_5.CanvasSize = UDim2.new(0,0,0, Position + 30)
			newplugin.Text.Delete.MouseButton1Click:Connect(function()
				deletePlugin(pName)
			end)
		end
		if not dontSave then
			updatesaves()
		end
	end
end

local PluginCache
function LoadPlugin(val,startup)
	local plugin

	function CatchedPluginLoad()
		plugin = loadfile(val)()
	end

	function handlePluginError(plerror)
		notify('Plugin Error','An error occurred with the plugin, "'..val..'" and it could not be loaded')
		if FindInTable(PluginsTable,val) then
			for i,v in pairs(PluginsTable) do
				if v == val then
					table.remove(PluginsTable,i)
				end
			end
		end

		print("Original Error: "..tostring(plerror))
		print("Plugin Error, stack traceback: "..tostring(debug.traceback()))

		plugin = nil

		return false
	end

	xpcall(CatchedPluginLoad, handlePluginError)

	if plugin ~= nil then
		if not startup then
			notify('Loaded Plugin',"Name: "..plugin["PluginName"].."\n".."Description: "..plugin["PluginDescription"])
		end
		addcmdtext('',val)
		addcmdtext(string.upper('--'..plugin["PluginName"]),val,plugin["PluginDescription"])
		for i,v in pairs(plugin["Commands"]) do 
			local cmdExt = ''
			local cmdName = i
			local function handleNames()
				cmdName = i
				if findCmd(cmdName..cmdExt) then
					if isNumber(cmdExt) then
						cmdExt = cmdExt+1
					else
						cmdExt = 1
					end
					handleNames()
				else
					cmdName = cmdName..cmdExt
				end
			end
			handleNames()
			addcmd(cmdName, v["Aliases"], v["Function"], val)
			if v["ListName"] then
				local newName = v.ListName
				local cmdNames = {i,unpack(v.Aliases)}
				for i,v in pairs(cmdNames) do
				    newName = newName:gsub(v,v..cmdExt)
				end
				addcmdtext(newName,val,v["Description"])
			else
				addcmdtext(cmdName,val,v["Description"])
			end
		end
		IndexContents('',true)
	elseif plugin == nil then
		plugin = nil
	end
end

function FindPlugins()
	if PluginsTable ~= nil and type(PluginsTable) == "table" then
		for i,v in pairs(PluginsTable) do
			LoadPlugin(v,true)
		end
		refreshplugins(true)
	end
end

PluginsGUI.AddPlugin.MouseButton1Click:connect(function()
	addPlugin(PluginsGUI.FileName.Text)
end)

Exit_3.MouseButton1Click:connect(function()
	PluginEditor:TweenPosition(UDim2.new(0.5, -180, 0, -400), "InOut", "Quart", 0.5, true, nil)
	PluginsGUI.FileName.Text = 'Plugin File Name'
end)

PluginsFrame.Add.MouseButton1Click:Connect(function()
	PluginEditor:TweenPosition(UDim2.new(0.5, -180, 0, 310), "InOut", "Quart", 0.5, true, nil)
end)

Settings.Plugins.Select.MouseButton1Click:Connect(function()
	if writefileExploit() then
		PluginsFrame:TweenPosition(UDim2.new(0, 0, 0, 0), "InOut", "Quart", 0.5, true, nil)
		wait(0.5)
		disablebuttons()
	else
		notify('Incompatible Exploit','Your exploit is unable to use plugins')
	end
end)

PluginsFrame.Close.MouseButton1Click:Connect(function()
	enablebuttons()
	PluginsFrame:TweenPosition(UDim2.new(0, 0, 0, 175), "InOut", "Quart", 0.5, true, nil)
end)

addcmd('addalias',{},
	function(args, speaker)
	if #args < 2 then return end
	local cmd = string.lower(args[1])
	local alias = string.lower(args[2])
	for i,v in pairs(cmds) do
		if v.NAME:lower()==cmd or std.inTable(v.ALIAS,cmd) then
			customAlias[alias] = v
			aliases[#aliases + 1] = {CMD = cmd, ALIAS = alias}
			notify('Aliases Modified',"Added "..alias.." as an alias to "..cmd)
			updatesaves()
			refreshaliases()
			break
		end
	end
end)

addcmd('loadsavedaliases',{},
	function(args, speaker)
    if #args < 2 then return end
    local cmd = string.lower(args[1])
    local alias = string.lower(args[2])
    for i,v in pairs(cmds) do
        if v.NAME:lower()==cmd or std.inTable(v.ALIAS,cmd) then
            customAlias[alias] = v
			refreshaliases()
            break
        end
    end
end)

if aliases then
	for i = 1, #aliases do
		execCmd('loadsavedaliases '..aliases[i].CMD..' '..aliases[i].ALIAS)
	end
end

addcmd('removealias',{},
	function(args, speaker)
	if #args < 1 then return end
	local alias = string.lower(args[1])
	if customAlias[alias] then
		local cmd = customAlias[alias].NAME
		customAlias[alias] = nil
		for i,v in pairs(aliases) do
			if v.ALIAS == tostring(alias) then
				table.remove(aliases, i)
			end
		end
		notify('Aliases Modified',"Removed the alias "..alias.." from "..cmd)
		updatesaves()
		refreshaliases()
	end
end)

addcmd('clraliases',{},
	function(args, speaker)
	customAlias = {}
	aliases = {}
	notify('Aliases Modified','Removed all aliases')
	updatesaves()
	refreshaliases()
end)

addcmd('serverinfo',{'info','sinfo'},
	function(args, speaker)
	local FRAME = Instance.new("Frame")
	local shadow = Instance.new("Frame")
	local PopupText = Instance.new("TextLabel")
	local Exit = Instance.new("ImageButton")
	local background = Instance.new("Frame")
	local TextLabel = Instance.new("TextLabel")
	local TextLabel2 = Instance.new("TextLabel")
	local TextLabel3 = Instance.new("TextLabel")
	local Time = Instance.new("TextLabel")
	local appearance = Instance.new("TextLabel")
	local maxplayers = Instance.new("TextLabel")
	local name = Instance.new("TextLabel")
	local placeid = Instance.new("TextLabel")
	local playerid = Instance.new("TextLabel")
	local players = Instance.new("TextLabel")
	local CopyApp = Instance.new("TextButton")
	local CopyPlrID = Instance.new("TextButton")
	local CopyPlcID = Instance.new("TextButton")
	
	FRAME.Name = randomString()
	FRAME.Parent = PARENT
	FRAME.Active = true
	FRAME.BackgroundTransparency = 1
	FRAME.Position = UDim2.new(0.5, -130, 0, -400)
	FRAME.Size = UDim2.new(0, 250, 0, 20)
	FRAME.ZIndex = 10
	dragGUI(FRAME)
	
	shadow.Name = "shadow"
	shadow.Parent = FRAME
	shadow.BackgroundColor3 = currentShade2
	shadow.BorderSizePixel = 0
	shadow.Size = UDim2.new(0, 250, 0, 20)
	shadow.ZIndex = 10
	table.insert(shade2,shadow)
	
	PopupText.Name = "PopupText"
	PopupText.Parent = shadow
	PopupText.BackgroundTransparency = 1
	PopupText.Position = UDim2.new(0, 38, 0, 0)
	PopupText.Size = UDim2.new(0.760355055, -16, 0.949999988, 0)
	PopupText.ZIndex = 10
	PopupText.Font = Enum.Font.SourceSans
	PopupText.TextSize = 14
	PopupText.Text = "Server"
	PopupText.TextColor3 = currentText1
	PopupText.TextWrapped = true
	table.insert(text1,PopupText)
	
	Exit.Name = "Exit"
	Exit.Parent = shadow
	Exit.BackgroundTransparency = 1
	Exit.Size = UDim2.new(0, 20, 0, 20)
	Exit.ZIndex = 10
	Exit.Image = "rbxassetid://2132544126"
	
	background.Name = "background"
	background.Parent = FRAME
	background.Active = true
	background.BackgroundColor3 = currentShade1
	background.BorderSizePixel = 0
	background.Position = UDim2.new(0, 0, 1, 0)
	background.Size = UDim2.new(0, 250, 0, 250)
	background.ZIndex = 10
	table.insert(shade1,background)
	
	TextLabel.Name = "Text Label"
	TextLabel.Parent = background
	TextLabel.BackgroundTransparency = 1
	TextLabel.BorderSizePixel = 0
	TextLabel.Position = UDim2.new(0, 5, 0, 80)
	TextLabel.Size = UDim2.new(0, 100, 0, 20)
	TextLabel.ZIndex = 10
	TextLabel.Font = Enum.Font.SourceSansLight
	TextLabel.TextSize = 20
	TextLabel.Text = "Run Time:"
	TextLabel.TextColor3 = currentText1
	TextLabel.TextXAlignment = Enum.TextXAlignment.Left
	table.insert(text1,TextLabel)
	
	TextLabel2.Name = "Text Label2"
	TextLabel2.Parent = background
	TextLabel2.BackgroundTransparency = 1
	TextLabel2.BorderSizePixel = 0
	TextLabel2.Position = UDim2.new(0, 5, 0, 130)
	TextLabel2.Size = UDim2.new(0, 100, 0, 20)
	TextLabel2.ZIndex = 10
	TextLabel2.Font = Enum.Font.SourceSansLight
	TextLabel2.TextSize = 20
	TextLabel2.Text = "Statistics:"
	TextLabel2.TextColor3 = currentText1
	TextLabel2.TextXAlignment = Enum.TextXAlignment.Left
	table.insert(text1,TextLabel2)
	
	TextLabel3.Name = "Text Label3"
	TextLabel3.Parent = background
	TextLabel3.BackgroundTransparency = 1
	TextLabel3.BorderSizePixel = 0
	TextLabel3.Position = UDim2.new(0, 5, 0, 10)
	TextLabel3.Size = UDim2.new(0, 100, 0, 20)
	TextLabel3.ZIndex = 10
	TextLabel3.Font = Enum.Font.SourceSansLight
	TextLabel3.TextSize = 20
	TextLabel3.Text = "Local Player:"
	TextLabel3.TextColor3 = currentText1
	TextLabel3.TextXAlignment = Enum.TextXAlignment.Left
	table.insert(text1,TextLabel3)
	
	Time.Name = "Time"
	Time.Parent = background
	Time.BackgroundTransparency = 1
	Time.BorderSizePixel = 0
	Time.Position = UDim2.new(0, 5, 0, 105)
	Time.Size = UDim2.new(0, 100, 0, 20)
	Time.ZIndex = 10
	Time.Font = Enum.Font.SourceSans
	Time.FontSize = Enum.FontSize.Size14
	Time.Text = "LOADING"
	Time.TextColor3 = currentText1
	Time.TextXAlignment = Enum.TextXAlignment.Left
	table.insert(text1,Time)
	
	appearance.Name = "appearance"
	appearance.Parent = background
	appearance.BackgroundTransparency = 1
	appearance.BorderSizePixel = 0
	appearance.Position = UDim2.new(0, 5, 0, 55)
	appearance.Size = UDim2.new(0, 100, 0, 20)
	appearance.ZIndex = 10
	appearance.Font = Enum.Font.SourceSans
	appearance.FontSize = Enum.FontSize.Size14
	appearance.Text = "Appearance: LOADING"
	appearance.TextColor3 = currentText1
	appearance.TextXAlignment = Enum.TextXAlignment.Left
	table.insert(text1,appearance)
	
	maxplayers.Name = "maxplayers"
	maxplayers.Parent = background
	maxplayers.BackgroundTransparency = 1
	maxplayers.BorderSizePixel = 0
	maxplayers.Position = UDim2.new(0, 5, 0, 175)
	maxplayers.Size = UDim2.new(0, 100, 0, 20)
	maxplayers.ZIndex = 10
	maxplayers.Font = Enum.Font.SourceSans
	maxplayers.FontSize = Enum.FontSize.Size14
	maxplayers.Text = "LOADING"
	maxplayers.TextColor3 = currentText1
	maxplayers.TextXAlignment = Enum.TextXAlignment.Left
	table.insert(text1,maxplayers)
	
	name.Name = "name"
	name.Parent = background
	name.BackgroundTransparency = 1
	name.BorderSizePixel = 0
	name.Position = UDim2.new(0, 5, 0, 215)
	name.Size = UDim2.new(0, 240, 0, 30)
	name.ZIndex = 10
	name.Font = Enum.Font.SourceSans
	name.FontSize = Enum.FontSize.Size14
	name.Text = "Place Name: LOADING"
	name.TextColor3 = currentText1
	name.TextWrapped = true
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.TextYAlignment = Enum.TextYAlignment.Top
	table.insert(text1,name)
	
	placeid.Name = "placeid"
	placeid.Parent = background
	placeid.BackgroundTransparency = 1
	placeid.BorderSizePixel = 0
	placeid.Position = UDim2.new(0, 5, 0, 195)
	placeid.Size = UDim2.new(0, 100, 0, 20)
	placeid.ZIndex = 10
	placeid.Font = Enum.Font.SourceSans
	placeid.FontSize = Enum.FontSize.Size14
	placeid.Text = "Place ID: LOADING"
	placeid.TextColor3 = currentText1
	placeid.TextXAlignment = Enum.TextXAlignment.Left
	table.insert(text1,placeid)
	
	playerid.Name = "playerid"
	playerid.Parent = background
	playerid.BackgroundTransparency = 1
	playerid.BorderSizePixel = 0
	playerid.Position = UDim2.new(0, 5, 0, 35)
	playerid.Size = UDim2.new(0, 100, 0, 20)
	playerid.ZIndex = 10
	playerid.Font = Enum.Font.SourceSans
	playerid.FontSize = Enum.FontSize.Size14
	playerid.Text = "Player ID: LOADING"
	playerid.TextColor3 = currentText1
	playerid.TextXAlignment = Enum.TextXAlignment.Left
	table.insert(text1,playerid)
	
	players.Name = "players"
	players.Parent = background
	players.BackgroundTransparency = 1
	players.BorderSizePixel = 0
	players.Position = UDim2.new(0, 5, 0, 155)
	players.Size = UDim2.new(0, 100, 0, 20)
	players.ZIndex = 10
	players.Font = Enum.Font.SourceSans
	players.FontSize = Enum.FontSize.Size14
	players.Text = "LOADING"
	players.TextColor3 = currentText1
	players.TextXAlignment = Enum.TextXAlignment.Left
	table.insert(text1,players)
	
	CopyApp.Name = "CopyApp"
	CopyApp.Parent = background
	CopyApp.BackgroundColor3 = currentShade2
	CopyApp.BorderSizePixel = 0
	CopyApp.Position = UDim2.new(0, 210, 0, 55)
	CopyApp.Size = UDim2.new(0, 35, 0, 20)
	CopyApp.Font = Enum.Font.SourceSans
	CopyApp.TextSize = 14
	CopyApp.Text = "Copy"
	CopyApp.TextColor3 = currentText1
	CopyApp.ZIndex = 10
	table.insert(shade2,CopyApp)
	table.insert(text1,CopyApp)
	
	CopyPlrID.Name = "CopyPlrID"
	CopyPlrID.Parent = background
	CopyPlrID.BackgroundColor3 = currentShade2
	CopyPlrID.BorderSizePixel = 0
	CopyPlrID.Position = UDim2.new(0, 210, 0, 35)
	CopyPlrID.Size = UDim2.new(0, 35, 0, 20)
	CopyPlrID.Font = Enum.Font.SourceSans
	CopyPlrID.TextSize = 14
	CopyPlrID.Text = "Copy"
	CopyPlrID.TextColor3 = currentText1
	CopyPlrID.ZIndex = 10
	table.insert(shade2,CopyPlrID)
	table.insert(text1,CopyPlrID)
	
	CopyPlcID.Name = "CopyPlcID"
	CopyPlcID.Parent = background
	CopyPlcID.BackgroundColor3 = currentShade2
	CopyPlcID.BorderSizePixel = 0
	CopyPlcID.Position = UDim2.new(0, 210, 0, 195)
	CopyPlcID.Size = UDim2.new(0, 35, 0, 20)
	CopyPlcID.Font = Enum.Font.SourceSans
	CopyPlcID.TextSize = 14
	CopyPlcID.Text = "Copy"
	CopyPlcID.TextColor3 = currentText1
	CopyPlcID.ZIndex = 10
	table.insert(shade2,CopyPlcID)
	table.insert(text1,CopyPlcID)
	
	local SINFOGUI = background
	FRAME:TweenPosition(UDim2.new(0.5, -130, 0, 100), "InOut", "Quart", 0.5, true, nil) 
	wait(0.5)
	Exit.MouseButton1Click:Connect(function()
		FRAME:TweenPosition(UDim2.new(0.5, -130, 0, -400), "InOut", "Quart", 0.5, true, nil) 
		wait(0.6)
		FRAME:Destroy()
	end)
	local Asset = game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId)
	SINFOGUI.name.Text = "Place Name: " .. Asset.Name
	SINFOGUI.playerid.Text = "Player ID: " ..speaker.UserId
	SINFOGUI.maxplayers.Text = Players.MaxPlayers.. " Players Max"
	SINFOGUI.placeid.Text = "Place ID: " ..game.PlaceId
	
	CopyApp.MouseButton1Click:Connect(function()
		toClipboard(speaker.CharacterAppearanceId)
	end)
	CopyPlrID.MouseButton1Click:Connect(function()
		toClipboard(speaker.UserId)
	end)
	CopyPlcID.MouseButton1Click:Connect(function()
		toClipboard(game.PlaceId)
	end)
	
	repeat
		players = Players:getPlayers()
		SINFOGUI.players.Text = #players.. " Player(s)"
		SINFOGUI.appearance.Text = "Appearance: " ..speaker.CharacterAppearanceId
		local seconds = math.floor(workspace.DistributedGameTime)
		local minutes = math.floor(workspace.DistributedGameTime / 60)
		local hours = math.floor(workspace.DistributedGameTime / 60 / 60)
		local seconds = seconds - (minutes * 60)
	local minutes = minutes - (hours * 60)
		if hours < 1 then if minutes < 1 then
			SINFOGUI.Time.Text = seconds .. " Second(s)" else
			SINFOGUI.Time.Text = minutes .. " Minute(s), " .. seconds .. " Second(s)"
		end
		else
			SINFOGUI.Time.Text = hours .. " Hour(s), " .. minutes .. " Minute(s), " .. seconds .. " Second(s)"
		end
		wait(1)
	until SINFOGUI.Parent == nil
end)

addcmd('breakloops',{'break'},
	function(args, speaker)
	lastBreakTime = tick()
end)

addcmd('gametp',{'gameteleport'},
	function(args, speaker)
	game:GetService('TeleportService'):Teleport(args[1])
end)

addcmd('rejoin',{'rj'},
	function(args, speaker)
	game:GetService('TeleportService'):Teleport(game.PlaceId)
end)

addcmd('serverhop',{'shop'},
	function(args, speaker)
	local PlaceId = game.PlaceId
	local URL = ("https://www.roblox.com/games/getgameinstancesjson?placeId=%s&startindex="):format(PlaceId)
	
	local List = {}
	
	for page = 0, 30 do
		local Query = game:GetService("HttpService"):JSONDecode(game:HttpGet(URL..page))
	
		for i,v in next, Query.Collection do 
			List[v.Guid] = v.Ping
		end
	end
	
	local ChosenServer = game.JobId
	
	for i,v in pairs(List) do
		if i ~= game.JobId then
			ChosenServer = i
			break
		end
	end
	
	game:GetService("TeleportService"):TeleportToPlaceInstance(PlaceId,ChosenServer,speaker)
end)

addcmd('joinplayer',{'joinp'},
	function(args, speaker)
	local retries = 0
	local gameID = game.PlaceId
	if args[2] then
		gameID = args[2]
	end
	function ToServer(User,PlaceId)	
		if not pcall(function()
			local FoundUser, UserId = pcall(function()
				if tonumber(User) then
					return tonumber(User)
				end
				
				return game:GetService("Players"):GetUserIdFromNameAsync(User)
			end)
			if not FoundUser then
				notify('Join Error','Username/UserID does not exist')
			else
				notify('Join Player','Loading servers. Hold on a second.')
				local res = game:HttpGet("https://www.roblox.com/headshot-thumbnail/json?userId="..UserId.."&width=48&height=48")
				local HttpURL = game:GetService("HttpService"):JSONDecode(res)
				local ThumbGrab = HttpURL["Url"]
				local Thumb = ThumbGrab
				local URL2 = ("https://www.roblox.com/games/getgameinstancesjson?placeId="..PlaceId.."&startindex=")
				local Http = game:GetService("HttpService"):JSONDecode(game:HttpGet(URL2.."0"))
				local GUID
				for i = 0,Http.TotalCollectionSize do
					local Http = game:GetService("HttpService"):JSONDecode(game:HttpGet(URL2..i))
					for x,n in pairs(Http.Collection) do
						for _,v in pairs(n.CurrentPlayers) do
							if v.Thumbnail.Url == Thumb then
								GUID = n.Guid
							end
						end
					end
				end
				if GUID ~= nil then
					notify('Join Player','Joining '..User)
					game:GetService("TeleportService"):TeleportToPlaceInstance(PlaceId,GUID,speaker)
				else
					notify('Join Error','Unable to join user.')
				end
			end
		end)
		then
			if retries < 3 then
				retries = retries + 1
				print('ERROR retrying '..retries..'/3')
				notify('Join Error','Error while trying to join. Retrying '..retries..'/3.')
				ToServer(User,PlaceId)
			else
				notify('Join Error','Error while trying to join.')
			end
		end
	end
	ToServer(args[1],gameID)
end)

addcmd('exit',{},
	function(args, speaker)
	game:shutdown() 
end)

local Noclipping = nil
addcmd('noclip',{},
	function(args, speaker)
	Clip = false
	wait(0.1)
	local function NoclipLoop()
		if Clip == false and speaker.Character ~= nil then
	   		for _, child in pairs(speaker.Character:GetDescendants()) do
				if child:IsA("BasePart") and child.CanCollide == true then
	   				child.CanCollide = false
				end
			end
		end
	end
	Noclipping = game:GetService('RunService').Stepped:connect(NoclipLoop)
	if args[1] and args[1] == 'nonotify' then return end
	notify('Noclip','Noclip Enabled')
end)

addcmd('clip',{'unnoclip'},
	function(args, speaker)
	if Noclipping then
		Noclipping:Disconnect()
	end
	Clip = true
	if args[1] and args[1] == 'nonotify' then return end
	notify('Noclip','Noclip Disabled')
end)

addcmd('togglenoclip',{},
	function(args, speaker)
	if Clip then
		execCmd('noclip')
	else
		execCmd('clip')
	end
end)

FLYING = false
iyflyspeed = 1
vehicleflyspeed = 1
function sFLY(vfly)
	repeat wait() until Players.LocalPlayer and Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChild('HumanoidRootPart') and Players.LocalPlayer.Character:FindFirstChild('Humanoid')
	repeat wait() until IYMouse
	
	local T = Players.LocalPlayer.Character.HumanoidRootPart
	local CONTROL = {F = 0, B = 0, L = 0, R = 0, Q = 0, E = 0}
	local lCONTROL = {F = 0, B = 0, L = 0, R = 0, Q = 0, E = 0}
	local SPEED = 0
	
	local function FLY()
		FLYING = true
		local BG = Instance.new('BodyGyro', T)
		local BV = Instance.new('BodyVelocity', T)
		BG.P = 9e4
		BG.maxTorque = Vector3.new(9e9, 9e9, 9e9)
		BG.cframe = T.CFrame
		BV.velocity = Vector3.new(0, 0, 0)
		BV.maxForce = Vector3.new(9e9, 9e9, 9e9)
		spawn(function()
			repeat wait()
			if not vfly then
				Players.LocalPlayer.Character:FindFirstChildOfClass('Humanoid').PlatformStand = true
			end
			if CONTROL.L + CONTROL.R ~= 0 or CONTROL.F + CONTROL.B ~= 0 or CONTROL.Q + CONTROL.E ~= 0 then
				SPEED = 50
			elseif not (CONTROL.L + CONTROL.R ~= 0 or CONTROL.F + CONTROL.B ~= 0 or CONTROL.Q + CONTROL.E ~= 0) and SPEED ~= 0 then
				SPEED = 0
			end
			if (CONTROL.L + CONTROL.R) ~= 0 or (CONTROL.F + CONTROL.B) ~= 0 or (CONTROL.Q + CONTROL.E) ~= 0 then
				BV.velocity = ((workspace.CurrentCamera.CoordinateFrame.lookVector * (CONTROL.F + CONTROL.B)) + ((workspace.CurrentCamera.CoordinateFrame * CFrame.new(CONTROL.L + CONTROL.R, (CONTROL.F + CONTROL.B + CONTROL.Q + CONTROL.E) * 0.2, 0).p) - workspace.CurrentCamera.CoordinateFrame.p)) * SPEED
				lCONTROL = {F = CONTROL.F, B = CONTROL.B, L = CONTROL.L, R = CONTROL.R}
			elseif (CONTROL.L + CONTROL.R) == 0 and (CONTROL.F + CONTROL.B) == 0 and (CONTROL.Q + CONTROL.E) == 0 and SPEED ~= 0 then
				BV.velocity = ((workspace.CurrentCamera.CoordinateFrame.lookVector * (lCONTROL.F + lCONTROL.B)) + ((workspace.CurrentCamera.CoordinateFrame * CFrame.new(lCONTROL.L + lCONTROL.R, (lCONTROL.F + lCONTROL.B + CONTROL.Q + CONTROL.E) * 0.2, 0).p) - workspace.CurrentCamera.CoordinateFrame.p)) * SPEED
			else
				BV.velocity = Vector3.new(0, 0, 0)
			end
			BG.cframe = workspace.CurrentCamera.CoordinateFrame
			until not FLYING
			CONTROL = {F = 0, B = 0, L = 0, R = 0, Q = 0, E = 0}
			lCONTROL = {F = 0, B = 0, L = 0, R = 0, Q = 0, E = 0}
			SPEED = 0
			BG:destroy()
			BV:destroy()
			Players.LocalPlayer.Character:FindFirstChildOfClass('Humanoid').PlatformStand = false
		end)
	end
	IYMouse.KeyDown:connect(function(KEY)
		if KEY:lower() == 'w' then
			if vfly then
				CONTROL.F = vehicleflyspeed
			else
				CONTROL.F = iyflyspeed
			end
		elseif KEY:lower() == 's' then
			if vfly then
				CONTROL.B = - vehicleflyspeed
			else
				CONTROL.B = - iyflyspeed
			end
		elseif KEY:lower() == 'a' then
			if vfly then
				CONTROL.L = - vehicleflyspeed
			else
				CONTROL.L = - iyflyspeed
			end
		elseif KEY:lower() == 'd' then 
			if vfly then
				CONTROL.R = vehicleflyspeed
			else
				CONTROL.R = iyflyspeed
            end
        elseif KEY:lower() == 'e' then
            if vfly then
                CONTROL.Q = vehicleflyspeed*2
            else
                CONTROL.Q = iyflyspeed*2
            end
        elseif KEY:lower() == 'q' then
            if vfly then
                CONTROL.E = -vehicleflyspeed*2
            else
                CONTROL.E = -iyflyspeed*2
            end
		end
	end)
	IYMouse.KeyUp:connect(function(KEY)
		if KEY:lower() == 'w' then
			CONTROL.F = 0
		elseif KEY:lower() == 's' then
			CONTROL.B = 0
		elseif KEY:lower() == 'a' then
			CONTROL.L = 0
		elseif KEY:lower() == 'd' then
            CONTROL.R = 0
        elseif KEY:lower() == 'e' then
            CONTROL.Q = 0
        elseif KEY:lower() == 'q' then
            CONTROL.E = 0
		end
	end)
	FLY()
end

function NOFLY()
	FLYING = false
	Players.LocalPlayer.Character:FindFirstChildOfClass('Humanoid').PlatformStand = false
end

addcmd('fly',{},
	function(args, speaker)
	NOFLY()
	wait()
	sFLY()
end)

addcmd('flyspeed',{'flysp'},
	function(args, speaker)
	if isNumber(args[1]) then
		iyflyspeed = args[1]
	end
end)

addcmd('unfly',{'nofly','novfly','unvehiclefly','novehiclefly','unvfly'},
	function(args, speaker)
	NOFLY()
end)

addcmd('vfly',{'vehiclefly'},
	function(args, speaker)
	NOFLY()
	wait()
	sFLY(true)
end)

addcmd('vflyspeed',{'vflysp','vehicleflyspeed','vehicleflysp'},
	function(args, speaker)
	if isNumber(args[1]) then
		vehicleflyspeed = args[1]
	end
end)

addcmd('togglefly',{},
	function(args, speaker)
	if FLYING then
		NOFLY()
	else
		sFLY()
	end
end)

Floating = false
addcmd('float', {'platform'},
	function(args, speaker)
	Floating = true
	local pchar = speaker.Character
	if pchar and not pchar:FindFirstChild("Float") then
		spawn(function()
			local Float = Instance.new('Part', pchar)
			Float.Name = 'Float'
			Float.Transparency = 1
			Float.Size = Vector3.new(6,1,6)
			Float.Anchored = true
			local FloatValue = -3.5
			if r15(speaker) then FloatValue = -3.65 end
			Float.CFrame = pchar.HumanoidRootPart.CFrame * CFrame.new(0,FloatValue,0)
			notify('Float','Float Enabled (Q = down & E = up)')
			qUp = IYMouse.KeyUp:connect(function(KEY)
				if KEY == 'q' then
					FloatValue = FloatValue + 0.5
				end
			end)
			eUp = IYMouse.KeyUp:connect(function(KEY)
				if KEY == 'e' then
					FloatValue = FloatValue - 0.5
				end
			end)
			qDown = IYMouse.KeyDown:connect(function(KEY)
				if KEY == 'q' then
					FloatValue = FloatValue - 0.5
				end
			end)
			eDown = IYMouse.KeyDown:connect(function(KEY)
				if KEY == 'e' then
					FloatValue = FloatValue + 0.5
				end
			end)
			floatDied = speaker.Character:FindFirstChildOfClass'Humanoid'.Died:Connect(function()
				FloatingFunc:Disconnect()
				Float:Destroy()
				qUp:Disconnect()
				eUp:Disconnect()
				qDown:Disconnect()
				eDown:Disconnect()
				floatDied:Disconnect()
			end)
			local function FloatPadLoop()
				if pchar:FindFirstChild("Float") and pchar:FindFirstChild("HumanoidRootPart") then
					Float.CFrame = pchar.HumanoidRootPart.CFrame * CFrame.new(0,FloatValue,0)
				else
					FloatingFunc:Disconnect()
					Float:Destroy()
					qUp:Disconnect()
					eUp:Disconnect()
					qDown:Disconnect()
					eDown:Disconnect()
					floatDied:Disconnect()
				end
			end			
			FloatingFunc = game:GetService('RunService').RenderStepped:connect(FloatPadLoop)
		end)
	end
end)

addcmd('unfloat',{'nofloat','unplatform','noplatform'},
	function(args, speaker)
	Floating = false
	local pchar = speaker.Character
	notify('Float','Float Disabled')
	if pchar:FindFirstChild("Float") then
		pchar.Float:Destroy()
	end
	if floatDied then
		FloatingFunc:Disconnect()
		qUp:Disconnect()
		eUp:Disconnect()
		qDown:Disconnect()
		eDown:Disconnect()
		floatDied:Disconnect()
	end
end)

addcmd('togglefloat',{},
	function(args, speaker)
	if Floating then
		execCmd('unfloat')
	else
		execCmd('float')
	end
end)

swimming = false
addcmd('swim',{},
	function(args, speaker)
	workspace.Gravity = 0
	local function swimDied()
		workspace.Gravity = 198.2
		swimming = false
	end
	gravReset = speaker.Character:FindFirstChildOfClass('Humanoid').Died:connect(swimDied)
	speaker.Character.Humanoid:SetStateEnabled(Enum.HumanoidStateType.Climbing,false)
	speaker.Character.Humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown,false)
	speaker.Character.Humanoid:SetStateEnabled(Enum.HumanoidStateType.Flying,false)
	speaker.Character.Humanoid:SetStateEnabled(Enum.HumanoidStateType.Freefall,false)
	speaker.Character.Humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp,false)
	speaker.Character.Humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping,false)
	speaker.Character.Humanoid:SetStateEnabled(Enum.HumanoidStateType.Landed,false)
	speaker.Character.Humanoid:SetStateEnabled(Enum.HumanoidStateType.Physics,false)
	speaker.Character.Humanoid:SetStateEnabled(Enum.HumanoidStateType.PlatformStanding,false)
	speaker.Character.Humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll,false)
	speaker.Character.Humanoid:SetStateEnabled(Enum.HumanoidStateType.Running,false)
	speaker.Character.Humanoid:SetStateEnabled(Enum.HumanoidStateType.RunningNoPhysics,false)
	speaker.Character.Humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated,false)
	speaker.Character.Humanoid:SetStateEnabled(Enum.HumanoidStateType.StrafingNoPhysics,false)
	speaker.Character.Humanoid:SetStateEnabled(Enum.HumanoidStateType.Swimming,false)
	speaker.Character.Humanoid:ChangeState(Enum.HumanoidStateType.Swimming)
	swimming = true
end)

addcmd('unswim',{'noswim'},
	function(args, speaker)
	workspace.Gravity = 198.2
	swimming = false
	if gravReset then
		gravReset:Disconnect()
	end
	speaker.Character.Humanoid:SetStateEnabled(Enum.HumanoidStateType.Climbing,true)
	speaker.Character.Humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown,true)
	speaker.Character.Humanoid:SetStateEnabled(Enum.HumanoidStateType.Flying,true)
	speaker.Character.Humanoid:SetStateEnabled(Enum.HumanoidStateType.Freefall,true)
	speaker.Character.Humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp,true)
	speaker.Character.Humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping,true)
	speaker.Character.Humanoid:SetStateEnabled(Enum.HumanoidStateType.Landed,true)
	speaker.Character.Humanoid:SetStateEnabled(Enum.HumanoidStateType.Physics,true)
	speaker.Character.Humanoid:SetStateEnabled(Enum.HumanoidStateType.PlatformStanding,true)
	speaker.Character.Humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll,true)
	speaker.Character.Humanoid:SetStateEnabled(Enum.HumanoidStateType.Running,true)
	speaker.Character.Humanoid:SetStateEnabled(Enum.HumanoidStateType.RunningNoPhysics,true)
	speaker.Character.Humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated,true)
	speaker.Character.Humanoid:SetStateEnabled(Enum.HumanoidStateType.StrafingNoPhysics,true)
	speaker.Character.Humanoid:SetStateEnabled(Enum.HumanoidStateType.Swimming,true)
	speaker.Character.Humanoid:ChangeState(Enum.HumanoidStateType.RunningNoPhysics)
end)

addcmd('toggleswim',{},
	function(args, speaker)
	if swimming then
		execCmd('unswim')
	else
		execCmd('swim')
	end
end)

addcmd('setwaypoint',{'swp','spos','saveposition','savepos'},
	function(args, speaker)
	local WPName = tostring(getstring(1))
	if speaker.Character:findFirstChild("HumanoidRootPart") then
		notify('Modified Waypoints',"Created waypoint: "..getstring(1))
		local torso = speaker.Character:findFirstChild("HumanoidRootPart")
		WayPoints[#WayPoints + 1] = {NAME = WPName, COORD = {math.floor(torso.Position.X), math.floor(torso.Position.Y), math.floor(torso.Position.Z)}, GAME = game.PlaceId}
		if AllWaypoints ~= nil then
			AllWaypoints[#AllWaypoints + 1] = {NAME = WPName, COORD = {math.floor(torso.Position.X), math.floor(torso.Position.Y), math.floor(torso.Position.Z)}, GAME = game.PlaceId}
		end
	end	
	refreshwaypoints()
	updatesaves()
end)

addcmd('waypointpos',{'wpp','setwaypointposition','setpos','setwaypoint','setwaypointpos'},
	function(args, speaker)
	local WPName = tostring(getstring(1))
	if speaker.Character:findFirstChild("HumanoidRootPart") then
		notify('Modified Waypoints',"Created waypoint: "..getstring(1))
		WayPoints[#WayPoints + 1] = {NAME = WPName, COORD = {args[2], args[3], args[4]}, GAME = game.PlaceId}
		if AllWaypoints ~= nil then
			AllWaypoints[#AllWaypoints + 1] = {NAME = WPName, COORD = {args[2], args[3], args[4]}, GAME = game.PlaceId}
		end
	end	
	refreshwaypoints()
	updatesaves()
end)

addcmd('waypoint',{'wp','lpos','loadposition','loadpos'},
	function(args, speaker)
	local WPName = tostring(getstring(1))
	if speaker.Character then
		for i,_ in pairs(WayPoints) do
			local x = WayPoints[i].COORD[1]
			local y = WayPoints[i].COORD[2]
			local z = WayPoints[i].COORD[3]
			if tostring(WayPoints[i].NAME):lower() == tostring(WPName):lower() then
				speaker.Character.HumanoidRootPart.CFrame = CFrame.new(x,y,z)
			end
		end
		for i,_ in pairs(pWayPoints) do
			if tostring(pWayPoints[i].NAME):lower() == tostring(WPName):lower() then
				speaker.Character.HumanoidRootPart.CFrame = CFrame.new(pWayPoints[i].COORD[1].Position)
			end
		end
	end
end)

addcmd('deletewaypoint',{'dwp','dpos','deleteposition','deletepos'},
	function(args, speaker)
	for i,v in pairs(WayPoints) do
		if v.NAME:lower() == tostring(getstring(1)):lower() then
			notify('Modified Waypoints',"Deleted waypoint: " .. v.NAME)
			table.remove(WayPoints, i)
		end
	end
	if AllWaypoints ~= nil and #AllWaypoints > 0 then
		for i,v in pairs(AllWaypoints) do
			if v.NAME:lower() == tostring(getstring(1)):lower() then
				if not v.GAME or v.GAME == game.PlaceId then
					table.remove(AllWaypoints, i)
				end
			end
		end
	end
	for i,v in pairs(pWayPoints) do
		if v.NAME:lower() == tostring(getstring(1)):lower() then
			notify('Modified Waypoints',"Deleted waypoint: " .. v.NAME)
			table.remove(pWayPoints, i)
		end
	end
	refreshwaypoints()
	updatesaves()
end)

addcmd('clearwaypoints',{'cwp','clearpositions','cpos','clearpos'},
	function(args, speaker)
	WayPoints = {}
	pWayPoints = {}
	refreshwaypoints()
	updatesaves()
	AllWaypoints = {}
	notify('Modified Waypoints','Removed all waypoints')
end)

addcmd('enable',{},
	function(args, speaker)
	if args[1]:lower() == 'inventory' or args[1]:lower() == 'backpack' then
		game:GetService("StarterGui"):SetCoreGuiEnabled('Backpack', true)
	elseif args[1]:lower() == 'playerlist' then
		game:GetService("StarterGui"):SetCoreGuiEnabled('PlayerList', true)
	elseif args[1]:lower() == 'chat' then
		game:GetService("StarterGui"):SetCoreGuiEnabled('Chat', true)
	elseif args[1]:lower() == 'all' then
		game:GetService("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.All, true)
	end
end)

addcmd('disable',{},
	function(args, speaker)
	if args[1]:lower() == 'inventory' or args[1]:lower() == 'backpack' then
		game:GetService("StarterGui"):SetCoreGuiEnabled('Backpack', false)
	elseif args[1]:lower() == 'playerlist' then
		game:GetService("StarterGui"):SetCoreGuiEnabled('PlayerList', false)
	elseif args[1]:lower() == 'chat' then
		game:GetService("StarterGui"):SetCoreGuiEnabled('Chat', false)
	elseif args[1]:lower() == 'all' then
		game:GetService("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.All, false)
	end
end)

invisGUIS = {}
addcmd('showguis',{},
	function(args, speaker)
	for i,v in pairs(speaker:FindFirstChildWhichIsA("PlayerGui"):GetDescendants()) do
		if v:IsA("Frame") or v:IsA("ImageLabel") or v:IsA("ScrollingFrame") and not v.Visible then
			v.Visible = true
			if not FindInTable(invisGUIS,v) then
				table.insert(invisGUIS,v)
			end
		end
	end
end)

addcmd('unshowguis',{},
	function(args, speaker)
	for i,v in pairs(invisGUIS) do
		v.Visible = false
	end
	invisGUIS = {}
end)

hiddenGUIS = {}
addcmd('hideguis',{},
	function(args, speaker)
	for i,v in pairs(speaker:FindFirstChildWhichIsA("PlayerGui"):GetDescendants()) do
		if v:IsA("Frame") or v:IsA("ImageLabel") or v:IsA("ScrollingFrame") and not v.Visible then
			v.Visible = false
			if not FindInTable(hiddenGUIS,v) then
				table.insert(hiddenGUIS,v)
				print('a')
			end
		end
	end
end)

addcmd('unhideguis',{},
	function(args, speaker)
	for i,v in pairs(hiddenGUIS) do
		v.Visible = true
	end
	hiddenGUIS = {}
end)

addcmd('savegame',{'saveplace'},
	function(args, speaker)
	if syn_checkcaller then
		notify("Loading","Fetching Moon's SaveInstance")
		loadstring(game:HttpGet('https://raw.githubusercontent.com/EdgeIY/saveinstance/master/source'))()
		repeat wait() until saveplace
		notify("Loading","Downloading game. This will take a while")
		local placeName = tostring(game.PlaceId).." Map"
		saveplace(tostring(game.PlaceId).." Map")
		wait(1)
		notify('Game Saved','Saved place to the workspace folder within your exploit folder.')
	elseif saveinstance then
		notify("Loading","Downloading game. This will take a while")
		saveinstance()
		notify('Game Saved','Saved place to the workspace folder within your exploit folder.')
	else
		notify('Incompatible Exploit','Your exploit does not support this command')
	end
end)


addcmd('clearerror',{'clearerrors'},
	function(args, speaker)
	game:GetService("GuiService"):ClearError()
end)

addcmd('esp',{},
	function(args, speaker)
	if not CHMSenabled then
		ESPenabled = true
		for i,v in pairs(Players:GetChildren()) do
			if v.ClassName == "Player" and v.Name ~= speaker.Name then
				ESP(v)
			end
		end
	else
		notify('ESP','Disable chams (nochams) before using esp')
	end
end)

addcmd('noesp',{'unesp'},
	function(args, speaker)
	ESPenabled = false
	for i,v in pairs(Players:GetChildren()) do
		local espplr = v
		for i,c in pairs(PARENT:GetChildren()) do
			if c.Name == espplr.Name..'_ESP' then
				c:Destroy()
			end
		end
	end
end)

partEspTrigger = nil
function partAdded(part)
	if #espParts > 0 then
		if FindInTable(espParts,part.Name:lower()) then
			local a = Instance.new("BoxHandleAdornment", part)
			a.Name = part.Name:lower().."_PESP"
			a.Adornee = part
			a.AlwaysOnTop = true
			a.ZIndex = 0
			a.Size = part.Size
			a.Transparency = 0.3
			a.Color = BrickColor.new("Lime green")
		end
	else
		partEspTrigger:Disconnect()
		partEspTrigger = nil
	end
end

espParts = {}
addcmd('partesp',{},
	function(args, speaker)
	local partEspName = getstring(1):lower()
	if not FindInTable(espParts,partEspName) then print('Added to table!!')
		table.insert(espParts,partEspName)
		for i,v in pairs(workspace:GetDescendants()) do
			if v:IsA("BasePart") and v.Name:lower() == partEspName then
				local a = Instance.new("BoxHandleAdornment", v)
				a.Name = partEspName.."_PESP"
				a.Adornee = v
				a.AlwaysOnTop = true
				a.ZIndex = 0
				a.Size = v.Size
				a.Transparency = 0.3
				a.Color = BrickColor.new("Lime green")
			end
		end
	end
	if partEspTrigger == nil then
		partEspTrigger = workspace.DescendantAdded:Connect(partAdded)
	end
end)

addcmd('unpartesp',{'nopartesp'},
	function(args, speaker)
	if args[1] then
		local partEspName = getstring(1):lower()
		if FindInTable(espParts,partEspName) then
			table.remove(espParts, GetInTable(espParts, partEspName))
		end
		for i,v in pairs(workspace:GetDescendants()) do
			if v:IsA("BoxHandleAdornment") and v.Name == partEspName..'_PESP' then
				v:Destroy()
			end
		end
	else
		partEspTrigger:Disconnect()
		partEspTrigger = nil
		espParts = {}
		for i,v in pairs(workspace:GetDescendants()) do
			if v:IsA("BoxHandleAdornment") and v.Name:sub(-5) == '_PESP' then
				v:Destroy()
			end
		end
	end
end)

addcmd('chams',{},
	function(args, speaker)
	if not ESPenabled then
		CHMSenabled = true
		for i,v in pairs(Players:GetChildren()) do
			if v.ClassName == "Player" and v.Name ~= speaker.Name then
				CHMS(v)
			end
		end
		else
		notify('Chams','Disable ESP (noesp) before using chams')
	end
end)

addcmd('nochams',{'unchams'},
	function(args, speaker)
	CHMSenabled = false
	for i,v in pairs(Players:GetChildren()) do
		local chmsplr = v
		for i,c in pairs(PARENT:GetChildren()) do
			if c.Name == chmsplr.Name..'_CHMS' then
				c:Destroy()
			end
		end
	end
end)

addcmd('locate',{},
	function(args, speaker)
	local players = getPlayer(args[1], speaker)
	for i,v in pairs(players) do
		Locate(Players[v])
	end
end)

addcmd('nolocate',{'unlocate'},
	function(args, speaker)
	local players = getPlayer(args[1], speaker)
	for i,v in pairs(players) do
		for i,c in pairs(PARENT:GetChildren()) do
			if c.Name == Players[v].Name..'_LC' then
				c:Destroy()
			end
		end
	end
end)

viewing = nil
addcmd('view',{'spectate'},
	function(args, speaker)
	local players = getPlayer(args[1], speaker)
	for i,v in pairs(players) do
		if viewDied then
			viewDied:Disconnect()
		end
		workspace.CurrentCamera.CameraSubject = Players[v].Character
		viewing = Players[v]
		notify('Spectate','Viewing ' .. Players[v].Name)
		local function viewDiedFunc()
			viewDied = Players[v].CharacterAdded:Connect(function()
				repeat wait() until Players[v].Character ~= nil and Players[v].Character:FindFirstChild('HumanoidRootPart')
				workspace.CurrentCamera.CameraSubject = Players[v].Character
				viewDied:Disconnect()
				viewDiedFunc()
			end)
		end
		viewDiedFunc()
	end
end)

addcmd('unview',{'unspectate'},
	function(args, speaker)
	workspace.CurrentCamera.CameraSubject = speaker.Character
	viewing = nil
	if viewDied then
		viewDied:Disconnect()
	end
	notify('Spectate','View turned off')
end)

fa = false
cam = workspace.CurrentCamera
cam1 = 0
cam2 = 0
cam3 = 0
k1 = false
k2 = false
k3 = false
k4 = false
k5 = false
k6 = false
cs = 0.5
function movecam()
	local fc = Players.LocalPlayer.Character:FindFirstChild('xFC')
	if fa == false then
		repeat
			if Players.LocalPlayer.Character:FindFirstChild('xFC') then
				local fp = fc.Position
				fc.CFrame = CFrame.new(Vector3.new(fp.X,fp.Y+cam3,fp.Z),cam.CFrame.p)*CFrame.new(cam2,0,cam1)
				fa = true
				Players.LocalPlayer.Character.Head.Anchored = true
			end
			game:GetService('RunService').RenderStepped:Wait()
		until not Players.LocalPlayer.Character:FindFirstChild('xFC')
		fa = false
	end
end
function kp1(inputObject, gameProcessedEvent)
	if not gameProcessedEvent and Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChild('xFC') then
		if inputObject.KeyCode == Enum.KeyCode.W or inputObject.KeyCode == Enum.KeyCode.Up then
			k1 = true
			cam1 = cs end
		if inputObject.KeyCode == Enum.KeyCode.S or inputObject.KeyCode == Enum.KeyCode.Down then
			k2 = true
			cam1 = (cs*-1) end
		if inputObject.KeyCode == Enum.KeyCode.A or inputObject.KeyCode == Enum.KeyCode.Left then
			k3 = true
			cam2 = cs end
		if inputObject.KeyCode == Enum.KeyCode.D or inputObject.KeyCode == Enum.KeyCode.Right then
			k4 = true
			cam2 = (cs*-1) end
		if inputObject.KeyCode == Enum.KeyCode.E or inputObject.KeyCode == Enum.KeyCode.Space then
			k5 = true
			cam3 = cs end
		if inputObject.KeyCode == Enum.KeyCode.Q or inputObject.KeyCode == Enum.KeyCode.LeftControl then
			k6 = true
			cam3 = (cs*-1) end
	end
end
UserInputService.InputBegan:connect(kp1)
function kp2(inputObject, gameProcessedEvent)
	if not gameProcessedEvent and Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChild('xFC') then
		if inputObject.KeyCode == Enum.KeyCode.W or inputObject.KeyCode == Enum.KeyCode.Up then
			k1 = false
			if k2 == false then
				cam1 = 0
			end
		end
		if inputObject.KeyCode == Enum.KeyCode.S or inputObject.KeyCode == Enum.KeyCode.Down then
			k2 = false
			if k1 == false then
				cam1 = 0
			end
		end
		if inputObject.KeyCode == Enum.KeyCode.A or inputObject.KeyCode == Enum.KeyCode.Left then
			k3= false
			if k4== false then
				cam2 = 0
			end
		end
		if inputObject.KeyCode == Enum.KeyCode.D or inputObject.KeyCode == Enum.KeyCode.Right then
			k4 = false
			if k3 == false then
				cam2 = 0
			end
		end
		if inputObject.KeyCode == Enum.KeyCode.E or inputObject.KeyCode == Enum.KeyCode.Space then
			k5 = false
			if k6 == false then
				cam3 = 0
			end
		end
		if inputObject.KeyCode == Enum.KeyCode.Q or inputObject.KeyCode == Enum.KeyCode.LeftControl then
			k6 = false
			if k5 == false then
				cam3 = 0
			end
		end
	end
end
UserInputService.InputEnded:connect(kp2)
fcEnabled = false
function FC()
	if not Players.LocalPlayer.Character:FindFirstChild('xFC') then
		local fc = Instance.new('Part',Players.LocalPlayer.Character)
		fc.CanCollide = false
		fc.Anchored = true
		fc.Transparency = 1
		fc.Size = Vector3.new(1,1,1)
		fc.Name = 'xFC'
		fc.CFrame = Players.LocalPlayer.Character.Head.CFrame
		local cam = workspace.CurrentCamera
		cam.CameraSubject = fc
		cam.CameraType = 'Custom'
		movecam()
	end
end
function UFC()
	if Players.LocalPlayer.Character:FindFirstChild('xFC') then
		Players.LocalPlayer.Character:FindFirstChild('xFC'):Destroy()
		local cam = workspace.CurrentCamera
		cam.CameraSubject = Players.LocalPlayer.Character.Humanoid
		cam.CameraType = 'Custom'
		Players.LocalPlayer.Character.Head.Anchored = false
	end
end

addcmd('freecam',{'fc'},
	function(args, speaker)
	FC()
end)

addcmd('unfreecam',{'nofreecam','unfc','nofc'},
	function(args, speaker)
	UFC()
end)

addcmd('freecamspeed',{'fcspeed'},
	function(args, speaker)
	if isNumber(args[1]) then
		cs = args[1]
	end
end)

addcmd('fctp',{'freecamtp','freecamteleport'},
	function(args, speaker)
	if not speaker.Character:FindFirstChild('xFC') then
		notify('Freecam TP','Freecam must be enabled to teleport to it')
	else
		speaker.Character.Head.Anchored = false
		speaker.Character.HumanoidRootPart.CFrame = speaker.Character:FindFirstChild('xFC').CFrame
		speaker.Character.Head.Anchored = true
	end
end)

addcmd('fov',{},
	function(args, speaker)
	if isNumber(args[1]) then
		workspace.CurrentCamera.FieldOfView = args[1]
	elseif not args[1] then
		workspace.CurrentCamera.FieldOfView = 70
	end
end)

addcmd('fixcam',{'restorecam'},
	function(args, speaker)
	UFC()
	workspace.CurrentCamera:remove()
	wait(.1)
	repeat wait() until speaker.Character ~= nil
	workspace.CurrentCamera.CameraSubject = speaker.Character:FindFirstChildWhichIsA('Humanoid')
	workspace.CurrentCamera.CameraType = "Custom"
	speaker.CameraMinZoomDistance = 0.5
	speaker.CameraMaxZoomDistance = 400
	speaker.CameraMode = "Classic"
	speaker.Character.Head.Anchored = false
end)

addcmd('enableshiftlock',{'enablesl','shiftlock'},
	function(args, speaker)
	speaker.DevEnableMouseLock = true
	notify('Shiftlock','Shift lock is now available')
end)

addcmd('firstp',{},
	function(args, speaker)
	speaker.CameraMode = "LockFirstPerson"
end)

addcmd('thirdp',{},
	function(args, speaker)
	speaker.CameraMode = "Classic"
end)

addcmd('noclipcam',{'nccam'},
	function(args, speaker)
	speaker.CameraMinZoomDistance = math.huge - math.huge
	speaker.CameraMaxZoomDistance = math.huge - math.huge
end)


addcmd('maxzoom',{},
	function(args, speaker)
	speaker.CameraMaxZoomDistance = args[1]
end)

addcmd('unlockws',{'unlockworkspace'},
	function(args, speaker)
    local function unlock(instance) 
        for i,v in pairs(instance:GetChildren()) do
            if v:IsA("BasePart") then
                v.Locked = false
            end
            unlock(v)
        end
    end
    unlock(workspace)
end)

addcmd('lockws',{'lockworkspace'},
	function(args, speaker)
    local function lock(instance) 
        for i,v in pairs(instance:GetChildren()) do
            if v:IsA("BasePart") then
                v.Locked = true
            end
            lock(v)
        end
    end
    lock(workspace)
end)

addcmd('delete',{'remove'},
	function(args, speaker)
	part = getstring(1)
    local function dels(instance)
        for i,v in pairs(instance:GetDescendants())do
            if v.Name:lower() == part:lower() then v:Destroy() end
            dels(v)
        end
    end
    dels(workspace)
notify('Item(s) Deleted','Deleted ' ..getstring(1))
end)

addcmd('deleteclass',{'removeclass','deleteclassname','removeclassname','dc'},
	function(args, speaker)
	part = getstring(1)
    local function dels(instance)
        for i,v in pairs(instance:GetDescendants())do
            if v.ClassName:lower() == part:lower() then v:Destroy() end
            dels(v)
        end
    end
    dels(workspace)
notify('Item(s) Deleted','Deleted items with ClassName ' ..getstring(1))
end)

addcmd('chardelete',{'charremove','cd'},
	function(args, speaker)
	part = getstring(1)
    local function dels(instance)
        for i,v in pairs(instance:GetDescendants())do
            if v.Name:lower() == part:lower() then v:Destroy() end
            dels(v)
        end
    end
    dels(speaker.Character)
	notify('Item(s) Deleted','Deleted ' ..getstring(1))
end)

addcmd('chardeleteclass',{'charremoveclass','chardeleteclassname','charremoveclassname','cdc'},
	function(args, speaker)
	part = getstring(1)
    local function dels(instance)
        for i,v in pairs(instance:GetDescendants())do
            if v.ClassName:lower() == part:lower() then v:Destroy() end
            dels(v)
        end
    end
    dels(speaker.Character)
	notify('Item(s) Deleted','Deleted items with ClassName ' ..getstring(1))
end)

addcmd('deletevelocity',{'dv','removevelocity','removeforces'},
	function(args, speaker)
	for i,v in pairs(speaker.Character:GetDescendants())do
		if v:IsA("BodyVelocity") or v:IsA("BodyGyro") or v:IsA("RocketPropulsion") or v:IsA("BodyThrust") or v:IsA("BodyAngularVelocity") or v:IsA("AngularVelocity") or v:IsA("BodyForce") or v:IsA("VectorForce") or v:IsA("LineForce") then
			v:Destroy()
		end
	end
end)

addcmd('btools',{},
	function(args, speaker)
	Instance.new("HopperBin", speaker.Backpack).BinType = 1
	Instance.new("HopperBin", speaker.Backpack).BinType = 2
	Instance.new("HopperBin", speaker.Backpack).BinType = 3
	Instance.new("HopperBin", speaker.Backpack).BinType = 4
end)

addcmd('f3x',{'fex'},
	function(args, speaker)
	loadstring(game:GetObjects("rbxassetid://4698064966")[1].Source)()
end)

addcmd('antiafk',{'antiidle'},
	function(args, speaker)
	if getconnections then
		for i,v in pairs(getconnections(Players.LocalPlayer.Idled)) do 
  		  v:Disable()
		end
		notify('Anti Idle','Anti idle is enabled')
	else
		notify('Incompatible Exploit','Your exploit does not support this command')
	end
end)

addcmd('nopurchaseprompts',{'noprompts'},
	function(args, speaker)
	game:GetService("CoreGui").PurchasePromptApp.PurchasePromptUI.Visible = false
end)

addcmd('showpurchaseprompts',{'showprompts'},
	function(args, speaker)
	game:GetService("CoreGui").PurchasePromptApp.PurchasePromptUI.Visible = true
end)

addcmd('age',{},
	function(args, speaker)
	local players = getPlayer(args[1], speaker)
	local ages = {}
	for i,v in pairs(players) do
		local p = Players[v]
		table.insert(ages, p.Name.."'s age is: "..p.AccountAge)
	end
	notify('Account Age',table.concat(ages, ',\n'))
end)

addcmd('chatage',{},
	function(args, speaker)
	local players = getPlayer(args[1], speaker)
	local ages = {}
	for i,v in pairs(players) do
		local p = Players[v]
		table.insert(ages, p.Name.."'s age is: "..p.AccountAge)
	end
	local chatString = table.concat(ages, ', ')
	game:GetService("ReplicatedStorage").DefaultChatSystemChatEvents.SayMessageRequest:FireServer(chatString, "All")
end)

addcmd('joindate',{'jd'},
	function(args, speaker)
	local players = getPlayer(args[1], speaker)
	local dates = {}
	notify("Loading",'Hold on a second')
	for i,v in pairs(players) do
		local user = game:HttpGet("https://users.roblox.com/v1/users/"..Players[v].UserId)
		local json = game:GetService("HttpService"):JSONDecode(user)
		table.insert(dates,Players[v].Name.." joined: "..json["created"]:sub(1,10))
	end
	notify('Join Date (Year/Month/Day)',table.concat(dates, ',\n'))
end)

addcmd('chatjoindate',{'cjd'},
	function(args, speaker)
	local players = getPlayer(args[1], speaker)
	local dates = {}
	notify("Loading",'Hold on a second')
	for i,v in pairs(players) do
		local user = game:HttpGet("https://users.roblox.com/v1/users/"..Players[v].UserId)
		local json = game:GetService("HttpService"):JSONDecode(user)
		table.insert(dates,Players[v].Name.." joined: "..json["created"]:sub(1,10))
	end
	local chatString = table.concat(dates, ', ')
	game:GetService("ReplicatedStorage").DefaultChatSystemChatEvents.SayMessageRequest:FireServer(chatString, "All")
end)

addcmd('os',{'platform', 'device'},
	function(args, speaker)
	local players = getPlayer(args[1], speaker)
	local platforms = {}
	for i,v in pairs(players) do
		local p = Players[v]
		table.insert(platforms,p.Name.."'s platform is: "..p.OsPlatform)
	end
	notify('OS',table.concat(platforms, ',\n'))
end)

addcmd('chatos',{'chatplatform', 'chatdevice'},
	function(args, speaker)
	local players = getPlayer(args[1], speaker)
	local platforms = {}
	for i,v in pairs(players) do
		local p = Players[v]
		table.insert(platforms,p.Name.."'s platform is: "..p.OsPlatform)
	end
	local chatString = table.concat(platforms, ', ')
	game:GetService("ReplicatedStorage").DefaultChatSystemChatEvents.SayMessageRequest:FireServer(chatString, "All")
end)

addcmd('setos',{'spoofos', 'osspoof'},
	function(args, speaker)
	speaker.OsPlatform = getstring(1)
	notify('OS','Your os is now set to '..getstring(1))
end)

addcmd('copyname',{'copyuser'},
	function(args, speaker)
	local players = getPlayer(args[1], speaker)
	for i,v in pairs(players) do
		local name = tostring(Players[v].Name)
		toClipboard(name)
	end
end)

addcmd('copyid',{},
	function(args, speaker)
	local players = getPlayer(args[1], speaker)
	for i,v in pairs(players) do
		local id = tostring(Players[v].UserId)
		toClipboard(id)
	end
end)

addcmd('copyappearanceid',{},
	function(args, speaker)
	local players = getPlayer(args[1], speaker)
	for i,v in pairs(players) do
		local aid = tostring(Players[v].CharacterAppearanceId)
		toClipboard(aid)
	end
end)

addcmd('goto',{'to'},
	function(args, speaker)
	local players = getPlayer(args[1], speaker)
	for i,v in pairs(players)do
		if Players[v].Character ~= nil then
			if speaker.Character:FindFirstChild("Humanoid") then
				speaker.Character:FindFirstChildOfClass('Humanoid').Jump = true
			end
			speaker.Character.HumanoidRootPart.CFrame = Players[v].Character.HumanoidRootPart.CFrame + Vector3.new(3,1,0)
		end
		wait(0.1)
	end
end)

addcmd('vehiclegoto',{'vgoto'},
	function(args, speaker)
	local players = getPlayer(args[1], speaker)
	for i,v in pairs(players)do
		if Players[v].Character ~= nil then
			local seat = speaker.Character.Humanoid.SeatPart
			seat.Parent.Parent:MoveTo(Players[v].Character.HumanoidRootPart.Position)
		end
		wait(0.1)
	end
end)

addcmd('clientbring',{'cbring'},
	function(args, speaker)
	local players = getPlayer(args[1], speaker)
	for i,v in pairs(players)do
		if Players[v].Character ~= nil then
			if Players[v].Character:FindFirstChild("Humanoid") then
				Players[v].Character:FindFirstChildOfClass('Humanoid').Jump = true
			end
			Players[v].Character.HumanoidRootPart.CFrame = speaker.Character.HumanoidRootPart.CFrame + Vector3.new(3,1,0)
		end
	end
end)

bringT = {}
addcmd('loopbring',{},
	function(args, speaker)
	local players = getPlayer(args[1], speaker)
	for i,v in pairs(players)do
		spawn(function()
			if Players[v].Name ~= speaker.Name and not FindInTable(bringT, Players[v].Name) then
				table.insert(bringT, Players[v].Name)
				local pchar=Players[v].Character
				pchar:FindFirstChildOfClass('Humanoid').Jump = true
				local distance = 3
				if args[2] and isNumber(args[2]) then
					distance = args[2]
				end
				local lDelay = 0
				if args[3] and isNumber(args[3]) then
					lDelay = args[3]
				end
				repeat
				pchar = Players[v].Character
				for i,c in pairs(players) do
					if pchar~= nil and pchar:FindFirstChild("HumanoidRootPart") and speaker.Character ~= nil and speaker.Character:FindFirstChild("HumanoidRootPart") then
						pchar.HumanoidRootPart.CFrame = speaker.Character.HumanoidRootPart.CFrame + Vector3.new(distance,1,0)
					end
				end
				wait(lDelay)
				until not FindInTable(bringT, Players[v].Name)
			end
		end)
	end
end)

addcmd('unloopbring',{'noloopbring'},
	function(args, speaker)
	local players = getPlayer(args[1], speaker)
	for i,v in pairs(players)do
		spawn(function()
			for a,b in pairs(bringT) do if b == Players[v].Name then table.remove(bringT, a) end end
		end)
	end
end)

local walkto
addcmd('walkto',{'follow'},
	function(args, speaker)
	local players = getPlayer(args[1], speaker)
	for i,v in pairs(players)do
		if Players[v].Character ~= nil then
			if speaker.Character:FindFirstChild("Humanoid") then
				speaker.Character:FindFirstChildOfClass('Humanoid').Jump = true
			end
			walkto = true
			repeat wait()
				speaker.Character.Humanoid:MoveTo(Players[v].Character.HumanoidRootPart.Position)
			until Players[v].Character == nil or not Players[v].Character:FindFirstChild('HumanoidRootPart') or walkto == false
		end
	end
end)

addcmd('unwalkto',{'nowalkto','unfollow','nofollow'},
	function(args, speaker)
	walkto = false
end)

addcmd('freeze',{'fr'},
	function(args, speaker)
	local players = getPlayer(args[1], speaker)
	if players ~= nil then
		for i, v in pairs(players) do
			spawn(function()
				for i, x in next, Players[v].Character:GetDescendants() do
					if x:IsA("BasePart") and not x.Anchored then
						x.Anchored = true
					end
				end
			end)
		end
	end
end)

addcmd('thaw',{'unfreeze','unfr'},
	function(args, speaker)
	local players = getPlayer(args[1], speaker)
	if players ~= nil then
		for i, v in pairs(players) do
			spawn(function()
				for i, x in next, Players[v].Character:GetDescendants() do
					if x:IsA("BasePart") and x.Anchored then
						x.Anchored = false
					end
				end
			end)
		end
	end
end)

oofing = false
addcmd('loopoof',{},
	function(args, speaker)
	oofing = true
	repeat wait(0.1)
		for i,v in pairs(Players:GetPlayers()) do
			if v.Character ~= nil and v.Character:FindFirstChild'Head' then
				for _,x in pairs(v.Character.Head:GetChildren()) do
					if x:IsA'Sound' then x.Playing = true end
				end
			end
		end
	until oofing == false
end)

addcmd('unloopoof',{},
	function(args, speaker)
	oofing = false
end)

addcmd('reset',{},
	function(args, speaker)
	speaker.Character:BreakJoints()
end)

addcmd('respawn',{},
	function(args, speaker)
	respawn(speaker)
end)

addcmd('refresh',{'re'},
	function(args, speaker)
	refresh(speaker)
end)

addcmd('invisible',{'invis'},
	function(args, speaker)
	-- Full credit to AmokahFox @V3rmillion
	local Player = speaker
	repeat wait(.1) until Player.Character
	local Character = Player.Character
	Character.Archivable = true
	local IsInvis = false
	local IsRunning = true
	local InvisibleCharacter = Character:Clone()
	InvisibleCharacter.Parent = game:GetService'Lighting'
	local Void = workspace.FallenPartsDestroyHeight
	InvisibleCharacter.Name = ""
	local CF
	
	local invisFix = game:GetService("RunService").Stepped:Connect(function()
	    pcall(function()
	        local IsInteger
	        if tostring(Void):find'-' then
	            IsInteger = true
	        else
	            IsInteger = false
	        end
	        local Pos = Player.Character.HumanoidRootPart.Position
	        local Pos_String = tostring(Pos)
	        local Pos_Seperate = Pos_String:split(', ')
	        local X = tonumber(Pos_Seperate[1])
	        local Y = tonumber(Pos_Seperate[2])
	        local Z = tonumber(Pos_Seperate[3])
	        if IsInteger == true then
	            if Y <= Void then
	                Respawn()
	            end
	        elseif IsInteger == false then
	            if Y >= Void then
	                Respawn()
	            end
	        end
	    end)
	end)
	
	for i,v in pairs(InvisibleCharacter:GetDescendants())do
	    if v:IsA("BasePart") then
	        if v.Name == "HumanoidRootPart" then
	            v.Transparency = 1
	        else
	            v.Transparency = .5
	        end
	    end
	end
	
	function Respawn()
	    IsRunning = false
	    if IsInvis == true then
	        pcall(function()
	            Player.Character = Character
	            wait()
	            Character.Parent = workspace
	            Character:FindFirstChildWhichIsA'Humanoid':Destroy()
	            IsInvis = false
	            InvisibleCharacter.Parent = nil
	        end)
	    elseif IsInvis == false then
	        pcall(function()
	            Player.Character = Character
	            wait()
	            Character.Parent = workspace
	            Character:FindFirstChildWhichIsA'Humanoid':Destroy()
	            TurnVisible()
	        end)
	    end
	end
	
	local invisDied = InvisibleCharacter:FindFirstChildOfClass'Humanoid'.Died:Connect(function()
	    Respawn()
	end)
	
	
	if IsInvis == true then return end
	IsInvis = true
	CF = workspace.CurrentCamera.CFrame
	local CF_1 = Player.Character.HumanoidRootPart.CFrame
	Character:MoveTo(Vector3.new(0,math.pi*1000000,0))
	workspace.CurrentCamera.CameraType = Enum.CameraType.Scriptable
	wait(.2)
	workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
	InvisibleCharacter = InvisibleCharacter
	Character.Parent = game:GetService'Lighting'
	InvisibleCharacter.Parent = workspace
	InvisibleCharacter.HumanoidRootPart.CFrame = CF_1
	Player.Character = InvisibleCharacter
	execCmd('fixcam')
	Player.Character.Animate.Disabled = true
	Player.Character.Animate.Disabled = false
	
	function TurnVisible()
	    if IsInvis == false then return end
		invisFix:Disconnect()
	    CF = workspace.CurrentCamera.CFrame
	    Character = Character
	    local CF_1 = Player.Character.HumanoidRootPart.CFrame
	    Character.HumanoidRootPart.CFrame = CF_1
	    InvisibleCharacter:Destroy()
	    Player.Character = Character
	    Character.Parent = workspace
	    IsInvis = false
	    execCmd('fixcam')
	    Player.Character.Animate.Disabled = true
	    Player.Character.Animate.Disabled = false
	end
	notify('Invisible','You now appear invisible to other players')
end)

addcmd('visible',{'vis'},
	function(args, speaker)
	TurnVisible()
end)

addcmd('strengthen',{},
	function(args, speaker)
	for _, child in pairs(speaker.Character:GetDescendants()) do
		if child.ClassName == "Part" then
			if args[1] then
				child.CustomPhysicalProperties = PhysicalProperties.new(args[1], 0.3, 0.5)
			else
				child.CustomPhysicalProperties = PhysicalProperties.new(100, 0.3, 0.5)
			end
		end
	end
end)

addcmd('weaken',{},
	function(args, speaker)
	for _, child in pairs(speaker.Character:GetDescendants()) do
		if child.ClassName == "Part" then
			if args[1] then
				child.CustomPhysicalProperties = PhysicalProperties.new(args[1], 0.3, 0.5)
			else
				child.CustomPhysicalProperties = PhysicalProperties.new(0, 0.3, 0.5)
			end
		end
	end
end)

addcmd('unweaken',{'unstrengthen'},
	function(args, speaker)
	for _, child in pairs(speaker.Character:GetDescendants()) do
		if child.ClassName == "Part" then
			child.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0.3, 0.5)
		end
	end
end)

addcmd('jpower',{'jumppower','jp'},
	function(args, speaker)
	speaker.Character:FindFirstChildOfClass('Humanoid').JumpPower=tonumber(args[1])
end)

addcmd('gravity',{'grav'},
	function(args, speaker)
	workspace.Gravity = (args[1])
end)

addcmd('hipheight',{'hheight'},
	function(args, speaker)
	speaker.Character:FindFirstChildOfClass('Humanoid').HipHeight = args[1]
end)

addcmd('dance',{},
	function(args, speaker)
	if not r15(speaker) then
		local pchar=speaker.Character
			local anim = nil		
			local dance1 = math.random(1,7)
			if dance1 == 1 then
			anim = '27789359'
			end
			if dance1 == 2 then
			anim = '30196114'
			end
			if dance1 == 3 then
			anim = '248263260'
			end
			if dance1 == 4 then
			anim = '45834924'
			end
			if dance1 == 5 then
			anim = '33796059'
			end
			if dance1 == 6 then
			anim = '28488254'
			end
			if dance1 == 7 then
			anim = '52155728'
			end
		local animation = Instance.new("Animation")
		animation.AnimationId = "rbxassetid://"..anim
		animTrack = pchar.Humanoid:LoadAnimation(animation)
		animTrack:Play()
	else
		notify('R6 Required','This command requires the r6 rig type')
	end
end)

addcmd('undance',{'nodance'},
	function(args, speaker)
	animTrack:Stop()
	animTrack:Destroy()
end)

addcmd('nolimbs',{'rlimbs'},
	function(args, speaker)
	if r15(speaker) then
		for i,v in pairs(speaker.Character:GetChildren()) do
			if v:IsA("BasePart") and
				v.Name == "RightUpperLeg" or
				v.Name == "LeftUpperLeg" or
				v.Name == "RightUpperArm" or
				v.Name == "LeftUpperArm" then
				v:Destroy()
			end
		end
	else
		for i,v in pairs(speaker.Character:GetChildren()) do
			if v:IsA("BasePart") and
				v.Name == "Right Leg" or
				v.Name == "Left Leg" or
				v.Name == "Right Arm" or
				v.Name == "Left Arm" then
				v:Destroy()
			end
		end
	end
end)

addcmd('noarms',{'rarms'},
	function(args, speaker)
	if r15(speaker) then
		for i,v in pairs(speaker.Character:GetChildren()) do
			if v:IsA("BasePart") and
				v.Name == "RightUpperArm" or
				v.Name == "LeftUpperArm" then
				v:Destroy()
			end
		end
	else
		for i,v in pairs(speaker.Character:GetChildren()) do
			if v:IsA("BasePart") and
				v.Name == "Right Arm" or
				v.Name == "Left Arm" then
				v:Destroy()
			end
		end
	end
end)

addcmd('nolegs',{'rlegs'},
	function(args, speaker)
	if r15(speaker) then
		for i,v in pairs(speaker.Character:GetChildren()) do
			if v:IsA("BasePart") and
				v.Name == "RightUpperLeg" or
				v.Name == "LeftUpperLeg" then
				v:Destroy()
			end
		end
	else
		for i,v in pairs(speaker.Character:GetChildren()) do
			if v:IsA("BasePart") and
				v.Name == "Right Leg" or
				v.Name == "Left Leg" then
				v:Destroy()
			end
		end
	end
end)

addcmd('sit',{},
	function(args, speaker)
	speaker.Character:FindFirstChildOfClass("Humanoid").Sit = true
end)

addcmd('jump',{},
	function(args, speaker)
	speaker.Character:FindFirstChildOfClass("Humanoid").Jump = true
end)

addcmd('infjump',{'infinitejump'},
	function(args, speaker)
	infJump = true
end)

addcmd('uninfjump',{'uninfinitejump','noinfjump','noinfinitejump'},
	function(args, speaker)
	infJump = false
end)

addcmd('team',{},
	function(args, speaker)
	local teamname = nil
	for a,b in pairs(game:GetService("Teams"):GetChildren()) do
		local L_name = b.Name:lower()
		local F = L_name:find(getstring(1))
		if F == 1 then
			teamname = b 
		end
	end
	speaker.Team = teamname
end)

addcmd('nobgui',{'unbgui','nobillboardgui','unbillboardgui','noname'},
	function(args, speaker)
	for i,v in pairs(speaker.Character:GetDescendants())do
		if v:IsA("BillboardGui") or v:IsA("SurfaceGui") then
			v:Destroy()
		end
	end
end)

addcmd('spasm',{},
	function(args, speaker)
	if not r15(speaker) then
		local pchar=speaker.Character
		local AnimationId = "33796059"
		SpasmAnim = Instance.new("Animation")
		SpasmAnim.AnimationId = "rbxassetid://"..AnimationId
		Spasm = pchar.Humanoid:LoadAnimation(SpasmAnim)
		Spasm:Play()
		Spasm:AdjustSpeed(99)
	else
		notify('R6 Required','This command requires the r6 rig type')
	end
end)

addcmd('unspasm',{'nospasm'},
	function(args, speaker)
	Spasm:Stop()
	SpasmAnim:Destroy()
end)

addcmd('headthrow',{},
	function(args, speaker)
	if not r15(speaker) then
		local AnimationId = "35154961"
		local Anim = Instance.new("Animation")
		Anim.AnimationId = "rbxassetid://"..AnimationId
		local k = speaker.Character.Humanoid:LoadAnimation(Anim)
		k:Play(0)
		k:AdjustSpeed(1)
	else
		notify('R6 Required','This command requires the r6 rig type')
	end
end)

addcmd('animation',{'anim'},
	function(args, speaker)
	if not r15(speaker) then
		local pchar=speaker.Character
		local AnimationId = tostring(args[1])
		local Anim = Instance.new("Animation")
		Anim.AnimationId = "rbxassetid://"..AnimationId
		local k = pchar.Humanoid:LoadAnimation(Anim)
		k:Play()
		if args[2] then
			k:AdjustSpeed(tostring(args[2]))
		end
	else
		notify('R6 Required','This command requires the r6 rig type')
	end
end)

addcmd('tpposition',{'tppos'},
	function(args, speaker)
	if #args < 3 then return end
	local tpX,tpY,tpZ = tonumber(args[1]),tonumber(args[2]),tonumber(args[3])
	local char = speaker.Character
	if char and char:FindFirstChild("HumanoidRootPart") then
		char.HumanoidRootPart.CFrame = CFrame.new(tpX,tpY,tpZ)
	end
end)

addcmd('offset',{},
	function(args, speaker)
	if #args < 3 then return end
	local tpX,tpY,tpZ = tonumber(args[1]),tonumber(args[2]),tonumber(args[3])
	local char = speaker.Character
	if char and char:FindFirstChild("HumanoidRootPart") then
		char.HumanoidRootPart.CFrame = char.HumanoidRootPart.CFrame + Vector3.new(tpX,tpY,tpZ)
	end
end)

addcmd('clickteleport',{},
	function(args, speaker)
	if speaker == Players.LocalPlayer then
		notify('Click TP','Go to Settings>Keybinds>Add to set up click tp')
	end
end)

addcmd('clickdelete',{},
	function(args, speaker)
	if speaker == Players.LocalPlayer then
		notify('Click Delete','Go to Settings>Keybinds>Add to set up click delete')
	end
end)

addcmd('getposition',{'getpos','notifypos','notifyposition'},
	function(args, speaker)
	local char = speaker.Character
	if char and char:FindFirstChild("HumanoidRootPart") then
		local pos = tostring(char.HumanoidRootPart.Position)
		notify('Current Position',pos)
	end
end)

addcmd('copyposition',{'copypos'},
	function(args, speaker)
	local char = speaker.Character
	if char and char:FindFirstChild("HumanoidRootPart") then
		local pos = tostring(char.HumanoidRootPart.Position)
		toClipboard(pos)
	end
end)

addcmd('speed',{'ws'},
	function(args, speaker)
	if args[2] then
		speaker.Character:FindFirstChildOfClass('Humanoid').WalkSpeed=tonumber(args[2])
	else
		speaker.Character:FindFirstChildOfClass('Humanoid').WalkSpeed=tonumber(args[1])
	end
end)

addcmd('tools',{'gears'},
	function(args, speaker)
	local function copy(instance)
		for i,c in pairs(instance:GetChildren())do
			if c:IsA('Tool') or c:IsA('HopperBin') then
				c:Clone().Parent = speaker.Backpack
			end
			copy(c)
		end
	end
	copy(game:GetService("Lighting"))
	local function copy(instance)
		for i,c in pairs(instance:GetChildren())do
			if c:IsA('Tool') or c:IsA('HopperBin') then
			c:Clone().Parent = speaker.Backpack
			end
			copy(c)
		end
	end
	copy(game:GetService("ReplicatedStorage"))
	notify('Tools','Copied tools from ReplicatedStorage and Lighting')
end)

addcmd('notools',{'rtools','clrtools','removetools','deletetools','dtools'},
	function(args, speaker)
	for i,v in pairs(speaker.Backpack:GetDescendants()) do
		if v:IsA('Tool') or v:IsA('HopperBin') then
			v:destroy()
		end
	end
	for i,v in pairs(speaker.Character:GetDescendants()) do
		if v:IsA('Tool') or v:IsA('HopperBin') then
			v:destroy()
		end
	end
end)

addcmd('console',{},
	function(args, speaker)
	-- Thanks wally!!
	notify("Loading",'Hold on a second')
	local _, str = pcall(function()
	   return game:HttpGet("https://pastebin.com/raw/i35eCznS", true)
	end)

	local s, e = loadstring(str)
	if typeof(s) ~= "function" then
	   return
	end

	local success, message = pcall(s)
	if (not success) then
	   if printconsole then
		   printconsole(message)
	   elseif printoutput then
		   printoutput(message)
	   end
	end
	wait(1)
	notify('Console','Press F9 to open the console')
end)

addcmd('explorer',{'dex'},
	function(args, speaker)
	if PARENT:FindFirstChild'Dex' then
		PARENT.Dex:Destroy();
	end
	
	local Dex = game:GetObjects("rbxassetid://3567096419")[1]
	Dex.Name = 'Dex'
	Dex.Parent = PARENT
	
	local function Load(Obj, Url)
		local function GiveOwnGlobals(Func, Script)
			local Fenv = {}
			local RealFenv = {script = Script}
			local FenvMt = {}
			FenvMt.__index = function(a,b)
				if RealFenv[b] == nil then
					return getfenv()[b]
				else
					return RealFenv[b]
				end
			end
			FenvMt.__newindex = function(a, b, c)
				if RealFenv[b] == nil then
					getfenv()[b] = c
				else
					RealFenv[b] = c
				end
			end
			setmetatable(Fenv, FenvMt)
			setfenv(Func, Fenv)
		return Func
	end
	
	local function LoadScripts(Script)
		if Script.ClassName == "Script" or Script.ClassName == "LocalScript" then
			spawn(function()
				GiveOwnGlobals(loadstring(Script.Source, "=" .. Script:GetFullName()), Script)()
			end)
		end
	    for i,v in pairs(Script:GetChildren()) do
			LoadScripts(v)
		end
	end
	
	LoadScripts(Obj)
	end
	
	Load(Dex)
end)

loopgoto = nil
addcmd('loopgoto',{},
	function(args, speaker)
	local players = getPlayer(args[1], speaker)
	for i,v in pairs(players)do
		loopgoto = nil
		wait()
		loopgoto = Players[v]
		local distance = 3
		if args[2] and isNumber(args[2]) then
			distance = args[2]
		end
		local lDelay = 0
		if args[3] and isNumber(args[3]) then
			lDelay = args[3]
		end
		speaker.Character:FindFirstChildOfClass('Humanoid').Jump = true
		repeat
			if Players[v].Character ~= nil then
				speaker.Character.HumanoidRootPart.CFrame = Players[v].Character.HumanoidRootPart.CFrame + Vector3.new(distance,1,0)
			end
			wait(lDelay)
		until loopgoto ~= Players[v]
	end
end)

addcmd('unloopgoto',{'noloopgoto'},
	function(args, speaker)
	loopgoto = nil
end)

addcmd('headsit',{},
	function(args, speaker)
	local players = getPlayer(args[1], speaker)
	for i,v in pairs(players)do
		speaker.Character:FindFirstChildOfClass('Humanoid').Sit = true
		headSit = game:GetService("RunService").RenderStepped:Connect(function()
			if Players[v].Character ~= nil and Players[v].Character:FindFirstChild('HumanoidRootPart') and speaker.Character:FindFirstChild('HumanoidRootPart') then
				if Players:FindFirstChild(Players[v].Name) and speaker.Character:FindFirstChildOfClass('Humanoid').Sit == true then
					speaker.Character.HumanoidRootPart.CFrame = Players[v].Character.HumanoidRootPart.CFrame * CFrame.Angles(0,math.rad(0),0)* CFrame.new(0,1.6,0.4)
				else
					headSit:Disconnect()
				end
			end
		end)
	end
end)

addcmd('chat',{},
	function(args, speaker)
	local cString = getstring(1)
	game:GetService("ReplicatedStorage").DefaultChatSystemChatEvents.SayMessageRequest:FireServer(cString, "All")
end)

spamming = false
spamspeed = 1
addcmd('spam',{},
	function(args, speaker)
	spamming = true
	local spamstring = getstring(1)
	repeat wait(spamspeed)
		game:GetService("ReplicatedStorage").DefaultChatSystemChatEvents.SayMessageRequest:FireServer(spamstring, "All")
	until spamming == false
end)

addcmd('nospam',{'unspam'},
	function(args, speaker)
	spamming = false
end)

pmspamming = {}
addcmd('pmspam',{},
	function(args, speaker)
	local players = getPlayer(args[1], speaker)
	for i,v in pairs(players)do
		spawn(function()
			if FindInTable(pmspamming, Players[v].Name) then return end
			table.insert(pmspamming, Players[v].Name)
			local pmspamstring = getstring(2)
			repeat wait(spamspeed)
				game:GetService("ReplicatedStorage").DefaultChatSystemChatEvents.SayMessageRequest:FireServer("/w "..Players[v].Name.." "..pmspamstring, "All")
			until not FindInTable(pmspamming, Players[v].Name)
		end)
	end
end)

addcmd('nopmspam',{'unpmspam'},
	function(args, speaker)
	local players = getPlayer(args[1], speaker)
	for i,v in pairs(players)do
		spawn(function()
			for a,b in pairs(pmspamming) do
				if b == Players[v].Name then
					table.remove(pmspamming, a)
				end
			end
		end)
	end
end)

addcmd('spamspeed',{},
	function(args, speaker)
	spamspeed = args[1]
end)

addcmd('blockhead',{},
	function(args, speaker)
	speaker.Character.Head:FindFirstChildOfClass("SpecialMesh"):Destroy()
end)

addcmd('blockhats',{},
	function(args, speaker)
	for _,v in pairs(speaker.Character.Humanoid:GetAccessories()) do
		if v:FindFirstChild('Handle') and v.Handle:FindFirstChildOfClass('SpecialMesh') then
			v.Handle:FindFirstChildOfClass("SpecialMesh"):Destroy()
		end
	end
end)

addcmd('blocktool',{},
	function(args, speaker)
	for i,v in pairs(speaker.Character:GetChildren()) do
		if v:IsA("Tool") or v:IsA("HopperBin") and v:FindFirstChild("Handle") then
			if v.Handle:FindFirstChildOfClass('SpecialMesh') then
				v.Handle:FindFirstChildOfClass('SpecialMesh'):Destroy()
			end
		end
	end
end)

addcmd('creeper',{},
	function(args, speaker)
	if r15(speaker) then
		speaker.Character.Head:FindFirstChildOfClass("SpecialMesh"):Destroy()
		speaker.Character.LeftUpperArm:Destroy()
		speaker.Character.RightUpperArm:Destroy()
		for _,v in pairs(speaker.Character.Humanoid:GetAccessories()) do
			v:Destroy()
		end
	else
		speaker.Character.Head:FindFirstChildOfClass("SpecialMesh"):Destroy()
		speaker.Character["Left Arm"]:Destroy()
		speaker.Character["Right Arm"]:Destroy()
		for _,v in pairs(speaker.Character.Humanoid:GetAccessories()) do
			v:Destroy()
		end
	end
end)

bangplr = nil

addcmd('bang',{'rape'},
	function(args, speaker)
	if not r15(speaker) then
		local players = getPlayer(args[1], speaker)
		for i,v in pairs(players)do
			bangAnim = Instance.new("Animation")
			bangAnim.AnimationId = "rbxassetid://148840371"
			bang = speaker.Character.Humanoid:LoadAnimation(bangAnim)
			bang:Play(.1, 1, 1)
			bang:AdjustSpeed(3)
			bangplr = Players[v].Name
		end
	else
		notify('R6 Required','This command requires the r6 rig type')
	end
end)

addcmd('unbang',{'unrape'},
	function(args, speaker)
	bangplr = nil
	bang:Stop()
	bangAnim:Destroy()
end)

addcmd('bringpart',{},
	function(args, speaker)
	for i,v in pairs(workspace:GetDescendants()) do
		if v.Name:lower() == getstring(1):lower() and v:IsA("BasePart") then
			v.CFrame = speaker.Character.HumanoidRootPart.CFrame
		end
	end
end)

addcmd('gotopart',{},
	function(args, speaker)
	for i,v in pairs(workspace:GetDescendants()) do
		if v.Name:lower() == getstring(1):lower() and v:IsA("BasePart") then
			speaker.Character.HumanoidRootPart.CFrame = v.CFrame
			wait(0.1)
		end
	end
end)

addcmd('bringpartclass',{'bpc'},
	function(args, speaker)
	for i,v in pairs(workspace:GetDescendants()) do
		if v.ClassName:lower() == getstring(1):lower() and v:IsA("BasePart") then
			v.CFrame = speaker.Character.HumanoidRootPart.CFrame
		end
	end
end)

addcmd('gotopartclass',{'gpc'},
	function(args, speaker)
	for i,v in pairs(workspace:GetDescendants()) do
		if v.ClassName:lower() == getstring(1):lower() and v:IsA("BasePart") then
			speaker.Character.HumanoidRootPart.CFrame = v.CFrame
			wait(0.1)
		end
	end
end)

addcmd('noclickdetectorlimits',{'nocdlimits','removecdlimits'},
	function(args, speaker)
	for i,v in pairs(workspace:GetDescendants()) do
		if v:IsA("ClickDetector") then
			v.MaxActivationDistance = math.huge
		end
	end
end)

addcmd('simulationradius',{'simradius'},
	function(args, speaker)
	speaker.MaximumSimulationRadius = math.pow(math.huge,math.huge)*math.huge
	speaker.SimulationRadius = math.pow(math.huge,math.huge)*math.huge
end)

addcmd('grabtools',{},
	function(args, speaker)
	for i,v in pairs(workspace:GetChildren()) do
		spawn(function()
			if v:IsA("Tool") or v:IsA("HopperBin") then
				if v:FindFirstChild("Handle") then
					repeat
						wait()
						if speaker.Character:FindFirstChild('HumanoidRootPart') then
							v.Handle.CFrame = speaker.Character.HumanoidRootPart.CFrame
						end
					until v.Parent == speaker.Character
				end
			end
		end)
	end
	grabtoolsFunc = workspace.ChildAdded:connect(function(part)
		if part:IsA("Tool") or part:IsA("HopperBin") then
			if part:FindFirstChild("Handle") then
				repeat
					wait()
					if speaker.Character:FindFirstChild('HumanoidRootPart') then
						part.Handle.CFrame = speaker.Character.HumanoidRootPart.CFrame
					end
				until part.Parent == speaker.Character
			end
		end
	end)
		notify('Grabtools','Picking up any dropped tools')
end)

addcmd('nograbtools',{'ungrabtools'},
	function(args, speaker)
	grabtoolsFunc:Disconnect()
	notify('Grabtools','Grabtools has been disabled')
end)

addcmd('light',{},
	function(args, speaker)
	local light = Instance.new("PointLight", speaker.Character.HumanoidRootPart)
	light.Range = 30
	if args[1] then
		light.Brightness = args[1]
	else
		light.Brightness = 5
	end
end)

addcmd('unlight',{'nolight'},
	function(args, speaker)
	for i,v in pairs(speaker.Character:GetDescendants()) do
		if v.ClassName == "PointLight" then
			v:Destroy()
		end
	end
end)

addcmd('copytools',{},
	function(args, speaker)
    local players = getPlayer(args[1], speaker)
	for i,v in pairs(players)do
		spawn(function()
			for i,v in pairs(Players[v].Backpack:GetChildren()) do
				if v:IsA('Tool') or v:IsA('HopperBin') then
					v:Clone().Parent = speaker.Backpack
				end
			end
		end)
	end
end)

addcmd('naked',{},
	function(args, speaker)
	for i,v in pairs(speaker.Character:GetDescendants()) do
		if v:IsA("Clothing") or v:IsA("ShirtGraphic") then
			v:Destroy()
		end
	end
end)

addcmd('noface',{'removeface'},
	function(args, speaker)
	for i,v in pairs(speaker.Character:GetDescendants()) do
		if v:IsA("Decal") and v.Name == 'face' then
			v:Destroy()
		end
	end
end)

addcmd('spawnpoint',{'spawn'},
	function(args, speaker)
	spawnpos = speaker.Character.HumanoidRootPart.CFrame
	spawnpoint = true
	notify('Spawn Point','Spawn point created at '..tostring(spawnpos))
end)

addcmd('nospawnpoint',{'nospawn','removespawnpoint'},
	function(args, speaker)
	spawnpoint = false
	notify('Spawn Point','Removed spawn point')
end)

addcmd('flashback',{'diedtp'},
	function(args, speaker)
	if lastDeath ~= nil then
		if speaker.Character:FindFirstChild("Humanoid") then
			speaker.Character:FindFirstChildOfClass('Humanoid').Jump = true
		end
		speaker.Character.HumanoidRootPart.CFrame = lastDeath
	end
end)

addcmd('hatspin',{'spinhats'},
	function(args, speaker)
	for _,v in pairs(speaker.Character.Humanoid:GetAccessories()) do
		local keep = Instance.new("BodyPosition") keep.Parent = v.Handle keep.Name = "no"
		local spin = Instance.new("BodyAngularVelocity") spin.Parent = v.Handle spin.Name = "ha"
		v.Handle:FindFirstChildOfClass("Weld"):Destroy()
		if args[1] then
			spin.AngularVelocity = Vector3.new(0, args[1], 0)
			spin.MaxTorque = Vector3.new(0, args[1] * 2, 0)
		else
			spin.AngularVelocity = Vector3.new(0, 100, 0)
			spin.MaxTorque = Vector3.new(0, 200, 0)
		end
		keep.P = 30000
		keep.D = 50
		spinning = keep
		spinenabled = true
	end
end)

addcmd('unhatspin',{'unspinhats'},
	function(args, speaker)
	for _,v in pairs(speaker.Character.Humanoid:GetAccessories()) do
		v.Parent = workspace
		wait(0.5)
		v.Handle.no:Destroy()
		v.Handle.ha:Destroy()
		v.Parent = speaker.Character
	end
end)

addcmd('vr',{},
	function(args, speaker)
	-- Full credit to Abacaxl @V3rmillion
	loadstring(game:HttpGet('https://ghostbin.co/paste/yb288/raw'))()
end)

addcmd('split',{},
	function(args, speaker)
	if r15(speaker) then
		speaker.Character.UpperTorso.Waist:Destroy()
	else
		notify('R15 Required','This command requires the r15 rig type')
	end
end)

addcmd('equiptools',{},
	function(args, speaker)
	for i,v in pairs(speaker.Backpack:GetChildren()) do
		if v:IsA("Tool") or v:IsA("HopperBin") then
			v.Parent = speaker.Character
		end
	end
end)

addcmd('dupetools',{'clonetools'},
	function(args, speaker)
	speaker.Character:MoveTo(Vector3.new(999999,999999,999999))
	wait()
	local tools = {}
	for i,v in pairs(speaker.Backpack:GetChildren()) do
		if v:IsA("Tool") or v:IsA("HopperBin") then
			v.Parent = speaker.Character
		end
	end
	for i,v in pairs(speaker.Character:GetChildren()) do
		if v:IsA("Tool") or v:IsA("HopperBin") and v:FindFirstChild("Handle") then
			table.insert(tools,v)
			v.Handle.Anchored = true
			v.Parent = workspace
		end
	end
	respawn(speaker)
	wait(1)
	repeat wait() until speaker.Character ~= nil and speaker.Character:FindFirstChild('HumanoidRootPart')
	wait(0.5)
	for i,v in pairs(tools) do
		spawn(function()
			v.Handle.Anchored = false
			repeat
				wait()
				if speaker.Character:FindFirstChild('HumanoidRootPart') then
					v.Handle.CFrame = speaker.Character.HumanoidRootPart.CFrame
				end
			until v.Parent == speaker.Character
		end)
	end    
end)

addcmd('fullbright',{'fb','fullbrightness'},
	function(args, speaker)
	game:GetService("Lighting").Brightness = 2
	game:GetService("Lighting").ClockTime = 14
	game:GetService("Lighting").FogEnd = 100000
	game:GetService("Lighting").GlobalShadows = false
	game:GetService("Lighting").OutdoorAmbient = Color3.fromRGB(128, 128, 128)
end)

addcmd('ambient',{},
	function(args, speaker)
	game:GetService("Lighting").Ambient = Color3.new(args[1],args[2],args[3])
	game:GetService("Lighting").OutdoorAmbient = Color3.new(args[1],args[2],args[3])
end)

addcmd('day',{},
	function(args, speaker)
	game:GetService("Lighting").ClockTime = 14
end)

addcmd('night',{},
	function(args, speaker)
	game:GetService("Lighting").ClockTime = 0
end)

addcmd('nofog',{},
	function(args, speaker)
	game:GetService("Lighting").FogEnd = 100000
end)

addcmd('brightness',{},
	function(args, speaker)
	game:GetService("Lighting").Brightness = args[1]
end)

addcmd('globalshadows',{'gshadows'},
	function(args, speaker)
    game:GetService("Lighting").GlobalShadows = true
end)

addcmd('unglobalshadows',{'nogshadows','ungshadows','noglobalshadows'},
	function(args, speaker)
    game:GetService("Lighting").GlobalShadows = false
end)

origsettings = {abt = game:GetService("Lighting").Ambient, oabt = game:GetService("Lighting").OutdoorAmbient, brt = game:GetService("Lighting").Brightness, time = game:GetService("Lighting").ClockTime, fe = game:GetService("Lighting").FogEnd, fs = game:GetService("Lighting").FogStart, gs = game:GetService("Lighting").GlobalShadows}

addcmd('restorelighting',{'rlighting'},
	function(args, speaker)
	game:GetService("Lighting").Ambient = origsettings.abt
	game:GetService("Lighting").OutdoorAmbient = origsettings.oabt
	game:GetService("Lighting").Brightness = origsettings.brt
	game:GetService("Lighting").ClockTime = origsettings.time
	game:GetService("Lighting").FogEnd = origsettings.fe
	game:GetService("Lighting").FogStart = origsettings.fs
	game:GetService("Lighting").GlobalShadows = origsettings.gs
end)

addcmd('stun',{'platformstand'},
	function(args, speaker)
	speaker.Character:FindFirstChildOfClass('Humanoid').PlatformStand = true
end)

addcmd('unstun',{'nostun','unplatformstand','noplatformstand'},
	function(args, speaker)
	speaker.Character:FindFirstChildOfClass('Humanoid').PlatformStand = false
end)

addcmd('drophats',{'drophat'},
	function(args, speaker)
	if speaker.Character then
		for _,v in pairs(speaker.Character.Humanoid:GetAccessories()) do
			v.Parent = workspace
		end
	end
end)

addcmd('deletehats',{'nohats','rhats'},
	function(args, speaker)
	if speaker.Character then
		for _,v in pairs(speaker.Character.Humanoid:GetAccessories()) do
			v:Destroy()
		end
	end
end)

addcmd('droptools',{'droptool'},
	function(args, speaker)
	if speaker.Character then
		for _,obj in pairs(speaker.Character:GetChildren()) do
			if obj:IsA("Tool") then
				obj.Parent = workspace
			end
		end
	end
	if speaker:FindFirstChild("Backpack") then
		for _,obj in pairs(speaker.Backpack:GetChildren()) do
			if obj:IsA("Tool") then
				obj.Parent = workspace
			end
		end
	end
end)

addcmd('droppabletools',{},
	function(args, speaker)
	if speaker.Character then
		for _,obj in pairs(speaker.Character:GetChildren()) do
			if obj:IsA("Tool") then
				obj.CanBeDropped = true
			end
		end
	end
	if speaker:FindFirstChild("Backpack") then
		for _,obj in pairs(speaker.Backpack:GetChildren()) do
			if obj:IsA("Tool") then
				obj.CanBeDropped = true
			end
		end
	end
end)

currentToolSize = ""
currentGripPos = ""
addcmd('reach',{},
	function(args, speaker)
	if args[1] then
		for i,v in pairs(speaker.Character:GetDescendants()) do
			if v:IsA("Tool") then
				if args[1] then
					currentToolSize = v.Handle.Size
					currentGripPos = v.GripPos
					local a = Instance.new("SelectionBox",v.Handle)
					a.Name = "SelectionBoxCreated"
					a.Adornee = v.Handle
					v.Handle.Size = Vector3.new(0.5,0.5,args[1])
					v.GripPos = Vector3.new(0,0,0)
					speaker.Character.Humanoid:UnequipTools()
				else
					currentToolSize = v.Handle.Size
					currentGripPos = v.GripPos
					local a = Instance.new("SelectionBox",v.Handle)
					a.Name = "SelectionBoxCreated"
					a.Adornee = v.Handle
					v.Handle.Size = Vector3.new(0.5,0.5,60)
					v.GripPos = Vector3.new(0,0,0)
					speaker.Character.Humanoid:UnequipTools()
				end
			end
		end
	end
end)

addcmd('unreach',{'noreach'},
	function(args, speaker)
	for i,v in pairs(speaker.Character:GetDescendants()) do
		if v:IsA("Tool") then
			v.Handle.Size = currentToolSize
			v.GripPos = currentGripPos
			v.Handle.SelectionBoxCreated:Destroy()
		end
	end
end)

addcmd('grippos',{},
	function(args, speaker)
	for i,v in pairs(speaker.Character:GetDescendants()) do
		if v:IsA("Tool") then
			v.Parent = speaker.Backpack
			v.GripPos = Vector3.new(args[1],args[2],args[3])
			wait()
			v.Parent = speaker.Character
		end
	end
end)

addcmd('logs',{'chatlogs'},
	function(args, speaker)
	logsDrag:TweenPosition(UDim2.new(0, 0, 1, -245), "InOut", "Quart", 0.3, true, nil)
end)

flinging = false
addcmd('fling',{},
	function(args, speaker)
	for _, child in pairs(speaker.Character:GetDescendants()) do
		if child:IsA("BasePart") then
			child.CustomPhysicalProperties = PhysicalProperties.new(2, 0.3, 0.5)
		end
	end
	for _,v in pairs(speaker.Character.Humanoid:GetAccessories()) do
		for e,c in pairs(v:GetDescendants()) do
			if c:IsA('BasePart') then
				c.CustomPhysicalProperties = PhysicalProperties.new(0, 0.3, 0.5)
			end
		end
	end
	execCmd('noclip nonotify')
	wait(.1)
	local bambam = Instance.new("BodyAngularVelocity", speaker.Character.HumanoidRootPart)
	bambam.Name = randomString()
	bambam.AngularVelocity = Vector3.new(0,311111,0)
	bambam.MaxTorque = Vector3.new(0,311111,0)
	bambam.P = math.huge
	local function PauseFling()
		if speaker.Character:FindFirstChildOfClass("Humanoid") then
			if speaker.Character:FindFirstChildOfClass("Humanoid").FloorMaterial == Enum.Material.Air then
				bambam.AngularVelocity = Vector3.new(0,0,0)
			else
				bambam.AngularVelocity = Vector3.new(0,311111,0)
			end
		end
	end
	if TouchingFloor then
		TouchingFloor:Disconnect()
	end
	if TouchingFloorReset then
		TouchingFloorReset:Disconnect()
	end
	TouchingFloor = speaker.Character:FindFirstChildOfClass("Humanoid"):GetPropertyChangedSignal("FloorMaterial"):connect(PauseFling)
	flinging = true
	local function flingDied()
		execCmd('unfling')
	end
	TouchingFloorReset = speaker.Character:FindFirstChildOfClass('Humanoid').Died:connect(flingDied)
end)

addcmd('unfling',{'nofling'},
	function(args, speaker)
	execCmd('clip nonotify')
	if TouchingFloor then
		TouchingFloor:Disconnect()
	end
	if TouchingFloorReset then
		TouchingFloorReset:Disconnect()
	end
	flinging = false
	wait(.1)
	local speakerChar = speaker.Character
	if not speakerChar or not speakerChar:FindFirstChild("HumanoidRootPart") then return end
	for i,v in pairs(speakerChar.HumanoidRootPart:GetChildren()) do
		if v.ClassName == 'BodyAngularVelocity' then
			v:Destroy()
		end
	end
	for _, child in pairs(speakerChar:GetDescendants()) do
		if child.ClassName == "Part" or child.ClassName == "MeshPart" then
			child.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0.3, 0.5)
		end
	end
end)

addcmd('togglefling',{},
	function(args, speaker)
	if flinging then
		execCmd('unfling')
	else
		execCmd('fling')
	end
end)

function kill(speaker,target,fast)
	if tools(speaker) then
		if target ~= nil then
			local NormPos = speaker.Character.HumanoidRootPart.CFrame
			if not fast then
				refresh(speaker)
				wait()
				repeat wait() until speaker.Character ~= nil and speaker.Character:FindFirstChild('HumanoidRootPart')
				wait(0.3)
			end
			local char = speaker.Character
			local tchar = target.Character
			local hum = speaker.Character.Humanoid
			local hrp = speaker.Character.HumanoidRootPart
			local hrp2 = target.Character.HumanoidRootPart
			hum.Name = "1"
			local newHum = hum:Clone()
			newHum.Parent = char
			newHum.Name = "Humanoid"
			wait(0.1)
			hum:Destroy()
			workspace.CurrentCamera.CameraSubject = char
			newHum.DisplayDistanceType = "None"
			wait(0.1)
			local tool = speaker.Backpack:FindFirstChildOfClass("Tool")
			tool.Parent = char
			hrp.CFrame = hrp2.CFrame * CFrame.new(0, 0, 0) * CFrame.new(math.random(-50, 50)/200,math.random(-50, 50)/200,math.random(-50, 50)/200)
			local n = 0
			repeat
				wait(.2)
				n = n + 1
				hrp.CFrame = hrp2.CFrame
			until n == 4
			repeat wait(0.1)
				hrp.CFrame = CFrame.new(999999, workspace.FallenPartsDestroyHeight + 5,999999)
			until not target.Character:FindFirstChild("HumanoidRootPart") or speaker.Character:FindFirstChild("HumanoidRootPart")
			local goBack
			goBack = speaker.CharacterAdded:Connect(function()
				repeat wait() until speaker.Character ~= nil and speaker.Character:FindFirstChild('HumanoidRootPart')
				wait(0.3)
				speaker.Character.HumanoidRootPart.CFrame = NormPos
				goBack:Disconnect()
			end)
		end
	else
		notify('Tool Required','You need to have a tool to use this command')
	end
end

addcmd('kill',{'fekill'},
	function(args, speaker)
	local players = getPlayer(args[1], speaker)
	for i,v in pairs(players) do
		kill(speaker,Players[v])
	end
end)

addcmd('fastkill',{'fastfekill'},
	function(args, speaker)
	local players = getPlayer(args[1], speaker)
	for i,v in pairs(players) do
		kill(speaker,Players[v],true)
	end
end)

function bring(speaker,target,fast)
	if tools(speaker) then
		if target ~= nil then
			local NormPos = speaker.Character.HumanoidRootPart.CFrame
			if not fast then
				refresh(speaker)
				wait()
				repeat wait() until speaker.Character ~= nil and speaker.Character:FindFirstChild('HumanoidRootPart')
				wait(0.3)
			end
			local char = speaker.Character
			local tchar = target.Character
			local hum = speaker.Character.Humanoid
			local hrp = speaker.Character.HumanoidRootPart
			local hrp2 = target.Character.HumanoidRootPart
			hum.Name = "1"
			local newHum = hum:Clone()
			newHum.Parent = char
			newHum.Name = "Humanoid"
			wait(0.1)
			hum:Destroy()
			workspace.CurrentCamera.CameraSubject = char
			newHum.DisplayDistanceType = "None"
			wait(0.1)
			local tool = speaker.Backpack:FindFirstChildOfClass("Tool")
			tool.Parent = char
			hrp.CFrame = hrp2.CFrame * CFrame.new(0, 0, 0) * CFrame.new(math.random(-50, 50)/200,math.random(-50, 50)/200,math.random(-50, 50)/200)
			local n = 0
			repeat
				wait(.2)
				n = n + 1
				hrp.CFrame = hrp2.CFrame
			until n == 4
			workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
			repeat wait(0.1)
				hrp.CFrame = NormPos
			until not target.Character:FindFirstChild("HumanoidRootPart") or speaker.Character:FindFirstChild("HumanoidRootPart")
			local goBack
			goBack = speaker.CharacterAdded:Connect(function()
				repeat wait() until speaker.Character ~= nil and speaker.Character:FindFirstChild('HumanoidRootPart')
				wait(0.3)
				speaker.Character.HumanoidRootPart.CFrame = NormPos
				goBack:Disconnect()
			end)
		end
	else
		notify('Tool Required','You need to have a tool to use this command')
	end
end

addcmd('bring',{'febring'},
	function(args, speaker)
	local players = getPlayer(args[1], speaker)
	for i,v in pairs(players) do
		bring(speaker,Players[v])
	end
end)

addcmd('fastbring',{'fastfebring'},
	function(args, speaker)
	local players = getPlayer(args[1], speaker)
	for i,v in pairs(players) do
		bring(speaker,Players[v],true)
	end
end)

addcmd('spin',{},
	function(args, speaker)
	local spinSpeed = 20
	if args[1] and isNumber(args[1]) then
		spinSpeed = args[1]
	end
	for i,v in pairs(speaker.Character.HumanoidRootPart:GetChildren()) do
		if v.Name == "Spinning" then
			v:Destroy()
		end
	end
	local Spin = Instance.new("BodyAngularVelocity", speaker.Character.HumanoidRootPart)
	Spin.Name = "Spinning"
	Spin.MaxTorque = Vector3.new(0, math.huge, 0)
	Spin.AngularVelocity = Vector3.new(0,spinSpeed,0)
end)

addcmd('unspin',{},
	function(args, speaker)
	for i,v in pairs(speaker.Character.HumanoidRootPart:GetChildren()) do
		if v.Name == "Spinning" then
			v:Destroy()
		end
	end
end)

transparent = false
function x(v)
	if v then
		for _,i in pairs(workspace:GetDescendants()) do
			if i:IsA("BasePart") and not i.Parent:FindFirstChild("Humanoid") and not i.Parent.Parent:FindFirstChild("Humanoid") then
				i.LocalTransparencyModifier = 0.5
			end
		end
	else
		for _,i in pairs(workspace:GetDescendants()) do
			if i:IsA("BasePart") and not i.Parent:FindFirstChild("Humanoid") and not i.Parent.Parent:FindFirstChild("Humanoid") then
				i.LocalTransparencyModifier = 0
			end
		end
	end
end

addcmd('xray',{},
	function(args, speaker)
	transparent = true
	x(transparent)
end)

addcmd('unxray',{'noxray'},
	function(args, speaker)
	transparent = false
	x(transparent)
end)

addcmd('togglexray',{},
	function(args, speaker)
	transparent=not transparent
	x(transparent)
end)

walltpTouch = nil
addcmd('walltp',{},
	function(args, speaker)
	local torso
	if r15(speaker) then
		torso = speaker.Character.UpperTorso
	else
		torso = speaker.Character.Torso
	end
	local function touchedFunc(hit)
		local Root = speaker.Character.HumanoidRootPart
		if hit:IsA("BasePart") and hit.Position.Y > Root.Position.Y - speaker.Character.Humanoid.HipHeight then
			local hitP = hit.Parent:FindFirstChild("HumanoidRootPart")
			if hitP ~= nil then
				Root.CFrame = hit.CFrame * CFrame.new(Root.CFrame.lookVector.X,hitP.Size.Z/2 + speaker.Character.Humanoid.HipHeight,Root.CFrame.lookVector.Z)
			elseif hitP == nil then
				Root.CFrame = hit.CFrame * CFrame.new(Root.CFrame.lookVector.X,hit.Size.Y/2 + speaker.Character.Humanoid.HipHeight,Root.CFrame.lookVector.Z)
			end
		end
	end
	walltpTouch = torso.Touched:Connect(touchedFunc)
end)

addcmd('unwalltp',{'nowalltp'},
	function(args, speaker)
	if walltpTouch then
		walltpTouch:Disconnect()
	end
end)

autoclicking = false
addcmd('autoclick',{},
	function(args, speaker)
	if mouse1press and mouse1release then
		execCmd('unautoclick')
		wait()
		local clickDelay = 0.1
		local releaseDelay = 0.1
		if args[1] and isNumber(args[1]) then clickDelay = tonumber(args[1]) end
		if args[2] and isNumber(args[2]) then releaseDelay = tonumber(args[2]) end
		autoclicking = true
		cancelAutoClick = UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
			if not gameProcessedEvent then
				if (input.KeyCode == Enum.KeyCode.Backspace and UserInputService:IsKeyDown(Enum.KeyCode.Equals)) or (input.KeyCode == Enum.KeyCode.Equals and UserInputService:IsKeyDown(Enum.KeyCode.Backspace)) then
					autoclicking = false
					cancelAutoClick:Disconnect()
				end
			end
		end)
		notify('Auto Clicker',"Press [backspace] and [=] at the same time to stop")
		repeat wait(clickDelay)
			mouse1press()
			wait(releaseDelay)
			mouse1release()
		until autoclicking == false
	else
		notify('Auto Clicker',"Your exploit doesn't have the ability to use the autoclick")
	end
end)

addcmd('unautoclick',{'noautoclick'},
	function(args, speaker)
	autoclicking = false
	if cancelAutoClick then cancelAutoClick:Disconnect() end
end)

addcmd('mousesensitivity',{'ms'},
	function(args, speaker)
	UserInputService.MouseDeltaSensitivity = args[1]
end)

nameBox = nil
nbSelection = nil
addcmd('hovername',{},
	function(args, speaker)
	execCmd('unhovername')
	wait()
	nameBox = Instance.new("TextLabel")
	nameBox.Name = randomString()
	nameBox.Parent = PARENT
	nameBox.BackgroundTransparency = 1
	nameBox.Size = UDim2.new(0,200,0,30)
	nameBox.Font = Enum.Font.Code
	nameBox.TextSize = 16
	nameBox.Text = ""
	nameBox.TextColor3 = Color3.new(1, 1, 1)
	nameBox.TextStrokeTransparency = 0
	nameBox.TextXAlignment = Enum.TextXAlignment.Left
	nameBox.ZIndex = 10
	nbSelection = Instance.new('SelectionBox')
	nbSelection.Name = randomString()
	nbSelection.LineThickness = 0.03
	nbSelection.Color3 = Color3.new(1, 1, 1)
	local function updateNameBox()
		local t
		local target = IYMouse.Target
		
		if target then
			local humanoid = target.Parent:FindFirstChild('Humanoid') or target.Parent.Parent:FindFirstChild('Humanoid')
			if humanoid then
				t = humanoid.Parent
			end
		end
		
		if t ~= nil then
			local x = IYMouse.X
			local y = IYMouse.Y
			local xP
			local yP
			if IYMouse.X > 200 then
				xP = x - 205
				nameBox.TextXAlignment = Enum.TextXAlignment.Right
			else
				xP = x + 25
				nameBox.TextXAlignment = Enum.TextXAlignment.Left
			end
			nameBox.Position = UDim2.new(0, xP, 0, y)
			nameBox.Text = t.Name
			nameBox.Visible = true
			nbSelection.Parent = t
			nbSelection.Adornee = t
		else
			nameBox.Visible = false
			nbSelection.Parent = nil
			nbSelection.Adornee = nil
		end
	end
	nbUpdateFunc = IYMouse.Move:connect(updateNameBox)
end)

addcmd('unhovername',{'nohovername'},
	function(args, speaker)
	if nbUpdateFunc then
		nbUpdateFunc:Disconnect()
		nameBox:Destroy()
		nbSelection:Destroy()
	end
end)

addcmd('hitbox',{},
	function(args, speaker)
	local players = getPlayer(args[1], speaker)
	for i,v in pairs(players) do
		if Players[v]~= speaker and Players[v].Character:FindFirstChild('Head') then
			local sizeArg = tonumber(args[2])
			local Size = Vector3.new(sizeArg,sizeArg,sizeArg)
			local Head = Players[v].Character:FindFirstChild('Head')
			if Head:IsA("BasePart") then
				if not args[2] or sizeArg == 1 then
					Head.Size = Vector3.new(2,1,1)
				else
					Head.Size = Size
				end
			end
		end
	end
end)

freezingua = nil
frozenParts = {}
addcmd('freezeunanchored',{'freezeua'},
	function(args, speaker)
	local badnames = {
		"Head",
		"UpperTorso",
		"LowerTorso",
		"RightUpperArm",
		"LeftUpperArm",
		"RightLowerArm",
		"LeftLowerArm",
		"RightHand",
		"LeftHand",
		"RightUpperLeg",
		"LeftUpperLeg",
		"RightLowerLeg",
		"LeftLowerLeg",
		"RightFoot",
		"LeftFoot",
		"Torso",
		"Right Arm",
		"Left Arm",
		"Right Leg",
		"Left Leg",
		"HumanoidRootPart"
	}
	local function FREEZENOOB(v)
		if v:IsA("BasePart" or "UnionOperation") and v.Anchored == false then
			local BADD = false
			for i = 1,#badnames do
				if v.Name == badnames[i] then
					BADD = true
				end
			end
			if speaker.Character and v:IsDescendantOf(speaker.Character) then
				BADD = true
			end
			if BADD == false then
				for i,c in pairs(v:GetChildren()) do
					if c:IsA("BodyPosition") or c:IsA("BodyGyro") then
						c:Destroy()
					end
				end
				local hUge = math.huge
				speaker.MaximumSimulationRadius = math.pow(hUge,hUge)*hUge
				speaker.SimulationRadius = math.pow(hUge,hUge)*hUge
				local bodypos = Instance.new("BodyPosition",v)
				bodypos.Position = v.Position
				bodypos.MaxForce = Vector3.new(hUge,hUge,hUge)
				local bodygyro = Instance.new("BodyGyro",v)
				bodygyro.CFrame = v.CFrame
				bodygyro.MaxTorque = Vector3.new(hUge,hUge,hUge)
				if not table.find(frozenParts,v) then print('added')
					table.insert(frozenParts,v)
				end
			end
		end
	end
	for i,v in pairs(workspace:GetDescendants()) do
		FREEZENOOB(v)
	end
	freezingua = workspace.DescendantAdded:Connect(FREEZENOOB)
end)

addcmd('thawunanchored',{'thawua','unfreezeunanchored','unfreezeua'},
	function(args, speaker)
	if freezingua then
		freezingua:Disconnect()
	end
	speaker.MaximumSimulationRadius = math.pow(math.huge,math.huge)*math.huge
	speaker.SimulationRadius = math.pow(math.huge,math.huge)*math.huge
	for i,v in pairs(frozenParts) do
		for i,c in pairs(v:GetChildren()) do
			if c:IsA("BodyPosition") or c:IsA("BodyGyro") then
				c:Destroy()
			end
		end
	end
	frozenParts = {}
end)

addcmd('tpunanchored',{'tpua'},
	function(args, speaker)
	local players = getPlayer(args[1], speaker)
	for i,v in pairs(players) do
		local Forces = {}
		for _,part in pairs(workspace:GetDescendants()) do
			if Players[v].Character:FindFirstChild('Head') and part:IsA("BasePart" or "UnionOperation" or "Model") and part.Anchored == false and not part:IsDescendantOf(speaker.Character) and part.Name == "Torso" == false and part.Name == "Head" == false and part.Name == "Right Arm" == false and part.Name == "Left Arm" == false and part.Name == "Right Leg" == false and part.Name == "Left Leg" == false and part.Name == "HumanoidRootPart" == false then
				for i,c in pairs(part:GetChildren()) do
					if c:IsA("BodyPosition") or c:IsA("BodyGyro") then
						c:Destroy()
					end
				end
				local ForceInstance = Instance.new("BodyPosition", part)
				ForceInstance.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
				table.insert(Forces, ForceInstance)
				if not table.find(frozenParts,part) then
					table.insert(frozenParts,part)
				end
			end
		end
		speaker.MaximumSimulationRadius = math.pow(math.huge,math.huge)*math.huge
		speaker.SimulationRadius = math.pow(math.huge,math.huge)*math.huge
		for i,c in pairs(Forces) do
			c.Position = Players[v].Character.Head.Position
		end
	end
end)

addcmd('addplugin',{'plugin'},
	function(args, speaker)
	addPlugin(getstring(1))
end)

addcmd('removeplugin',{'deleteplugin'},
	function(args, speaker)
	deletePlugin(getstring(1))
end)

addcmd('reloadplugin',{},
	function(args, speaker)
	local pluginName = getstring(1)
	deletePlugin(pluginName)
	wait(1)
	addPlugin(pluginName)
end)

addcmd('removecmd',{'deletecmd'},
	function(args, speaker)
	removecmd(args[1])
end)

updateColors(currentShade1,shade1)
updateColors(currentShade2,shade2)
updateColors(currentShade3,shade3)
updateColors(currentText1,text1)
updateColors(currentText2,text2)
updateColors(currentScroll,scroll)

if PluginsTable ~= nil or PluginsTable ~= {} then
	FindPlugins(PluginsTable)
end

IYMouse.Move:connect(checkTT)

if pcall(function() loadstring(game:HttpGet('https://raw.githubusercontent.com/EdgeIY/infiniteyield/master/version'))() end) then
	if ver ~= Version then
		notify('Outdated','Get the new version at infyield.yolasite.com')
	end
	if Announcement and Announcement ~= '' then
		local AnnGUI = Instance.new("Frame")
		local background = Instance.new("Frame")
		local TextBox = Instance.new("TextLabel")
		local shadow = Instance.new("Frame")
		local PopupText = Instance.new("TextLabel")
		local Exit = Instance.new("ImageButton")
		
		AnnGUI.Name = randomString()
		AnnGUI.Parent = PARENT
		AnnGUI.Active = true
		AnnGUI.BackgroundTransparency = 1
		AnnGUI.Position = UDim2.new(0.5, -180, 0, -400)
		AnnGUI.Size = UDim2.new(0, 360, 0, 20)
		AnnGUI.ZIndex = 10
		
		background.Name = "background"
		background.Parent = AnnGUI
		background.Active = true
		background.BackgroundColor3 = currentShade1
		background.BorderSizePixel = 0
		background.Position = UDim2.new(0, 0, 0, 20)
		background.Size = UDim2.new(0, 360, 0, 116)
		background.ZIndex = 10
		
		TextBox.Parent = background
		TextBox.BackgroundTransparency = 1
		TextBox.Position = UDim2.new(0.017, 0, 0.06, 0)
		TextBox.Size = UDim2.new(0, 348, 0, 104)
		TextBox.Font = Enum.Font.SourceSans
		TextBox.TextSize = 18
		TextBox.TextWrapped = true
		TextBox.Text = Announcement
		TextBox.TextColor3 = currentText1
		TextBox.TextXAlignment = Enum.TextXAlignment.Left
		TextBox.TextYAlignment = Enum.TextYAlignment.Top
		TextBox.ZIndex = 10
		
		shadow.Name = "shadow"
		shadow.Parent = AnnGUI
		shadow.BackgroundColor3 = currentShade2
		shadow.BorderSizePixel = 0
		shadow.Size = UDim2.new(0, 360, 0, 20)
		shadow.ZIndex = 10
		
		PopupText.Name = "PopupText"
		PopupText.Parent = shadow
		PopupText.BackgroundTransparency = 1
		PopupText.Position = UDim2.new(0, 51, 0, 0)
		PopupText.Size = UDim2.new(0.76, -16, 0.95, 0)
		PopupText.ZIndex = 10
		PopupText.Font = Enum.Font.SourceSans
		PopupText.TextSize = 14
		PopupText.Text = "Server Announcement"
		PopupText.TextColor3 = currentText1
		PopupText.TextWrapped = true
		
		Exit.Name = "Exit"
		Exit.Parent = shadow
		Exit.BackgroundTransparency = 1
		Exit.Size = UDim2.new(0, 20, 0, 20)
		Exit.ZIndex = 10
		Exit.Image = "rbxassetid://2132544126"
		
		wait(1)
		AnnGUI:TweenPosition(UDim2.new(0.5, -180, 0, 150), "InOut", "Quart", 0.5, true, nil)
		
		Exit.MouseButton1Click:Connect(function()
			AnnGUI:TweenPosition(UDim2.new(0.5, -180, 0, -400), "InOut", "Quart", 0.5, true, nil)
			wait(0.6)
			AnnGUI:Destroy()
		end)
	end
end

wait()
Credits:TweenPosition(UDim2.new(0,0,0.9,0), "Out", "Quart", 0.2)
Logo:TweenSizeAndPosition(UDim2.new(0,175,0,175),UDim2.new(0,37,0,45), "Out", "Quart", 0.3)
wait(1)
for i=0,1,0.1 do
    Logo.ImageTransparency = i
    IntroBackground.BackgroundTransparency = i
    wait()
end
Credits:TweenPosition(UDim2.new(0,0,0.9,30), "Out", "Quart", 0.2)
wait(0.2)
Logo:Destroy()
Credits:Destroy()
IntroBackground:Destroy()
minimizeHolder()
