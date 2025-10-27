local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

local repo = 'https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/'
local Library = loadstring(game:HttpGet(repo .. 'Library.lua'))()
local ThemeManager = loadstring(game:HttpGet(repo .. 'addons/ThemeManager.lua'))()
local SaveManager = loadstring(game:HttpGet(repo .. 'addons/SaveManager.lua'))()

-- Configuration
local Config = {
    AimAssist = {
        Active = false, -- Tracks press/release state
        Key = Enum.UserInputType.MouseButton2, -- Activation key
        LockFOV = math.rad(8), -- FOV angle in radians
        Smoothness = 0.2,
        Prediction = 0.13,
        TargetPart = "Head", -- Options: Head, HumanoidRootPart
        TeamCheck = false,
        WallCheck = true,
        MaxDistance = 500,
        UseMouseMove = false
    },
    ESP = {
        Enabled = false,
        BoxColor = Color3.new(1, 0, 0),
        TracerColor = Color3.new(1, 0, 0),
        HealthColor = Color3.new(1, 1, 1),
        NameColor = Color3.new(1, 1, 1),
        ShowBoxes = true,
        ShowHealth = true,
        ShowTracers = true,
        ShowNames = true
    }
}

-- ESP Drawings
local ESPDrawings = {}

-- Function to check if target is valid
local function isValidTarget(player)
    if player == LocalPlayer or not player.Character or not player.Character:FindFirstChild("Humanoid") or player.Character.Humanoid.Health <= 0 then
        return false
    end
    if Config.AimAssist.TeamCheck then
        return player.Team ~= LocalPlayer.Team
    end
    return true
end

-- Function to perform wall check
local function canSeeTarget(targetPart)
    if not Config.AimAssist.WallCheck then return true end
    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    rayParams.FilterDescendantsInstances = {LocalPlayer.Character, Camera}
    local raycastResult = workspace:Raycast(Camera.CFrame.Position, (targetPart.Position - Camera.CFrame.Position).Unit * Config.AimAssist.MaxDistance, rayParams)
    return raycastResult == nil or raycastResult.Instance:IsDescendantOf(targetPart.Parent)
end

-- Function to get closest player based on angle to camera
local function getClosestPlayerToCamera()
    local closestPlayer = nil
    local closestAngle = Config.AimAssist.LockFOV

    for _, player in ipairs(Players:GetPlayers()) do
        if isValidTarget(player) then
            local character = player.Character
            local targetPart = character:FindFirstChild(Config.AimAssist.TargetPart) or character:FindFirstChild("HumanoidRootPart")
            if targetPart and canSeeTarget(targetPart) then
                local distance = (targetPart.Position - Camera.CFrame.Position).Magnitude
                if distance <= Config.AimAssist.MaxDistance then
                    local predictedPos = targetPart.Position + targetPart.Velocity * Config.AimAssist.Prediction
                    local direction = (predictedPos - Camera.CFrame.Position).Unit
                    local angle = math.acos(direction:Dot(Camera.CFrame.LookVector))
                    if angle < closestAngle then
                        closestAngle = angle
                        closestPlayer = {Player = player, PredictedPos = predictedPos}
                    end
                end
            end
        end
    end

    return closestPlayer
end

-- Improved Aim Assist Function with Lerp Smoothing and Prediction
local function aimAtTarget(target)
    if not target or not target.Player or not target.Player.Character then return end
    
    local targetPos = target.PredictedPos
    if Config.AimAssist.UseMouseMove then
        local screenPoint = Camera:WorldToScreenPoint(targetPos)
        local deltaX = (screenPoint.X - Mouse.X) * Config.AimAssist.Smoothness
        local deltaY = (screenPoint.Y - Mouse.Y) * Config.AimAssist.Smoothness
        mousemoverel(deltaX, deltaY)
    else
        local currentCFrame = Camera.CFrame
        local targetCFrame = CFrame.new(currentCFrame.Position, targetPos)
        Camera.CFrame = currentCFrame:Lerp(targetCFrame, Config.AimAssist.Smoothness)
    end
end

-- Aim Assist Press/Release
UserInputService.InputBegan:Connect(function(input)
    if input.UserInputType == Config.AimAssist.Key then
        Config.AimAssist.Active = true
        print('[cb] Aim Assist activated')
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Config.AimAssist.Key then
        Config.AimAssist.Active = false
        print('[cb] Aim Assist deactivated')
    end
end)

-- ESP Function with Boxes, Names, Health, and Tracers
local function createESP(player)
    if player == LocalPlayer then return end
    
    local box = Drawing.new("Square")
    box.Visible = false
    box.Color = Config.ESP.BoxColor
    box.Thickness = 2
    box.Transparency = 1
    box.Filled = false
    
    local name = Drawing.new("Text")
    name.Visible = false
    name.Color = Config.ESP.NameColor
    name.Size = 16
    name.Center = true
    name.Outline = true
    name.Font = 2
    
    local health = Drawing.new("Text")
    health.Visible = false
    health.Color = Config.ESP.HealthColor
    health.Size = 14
    health.Center = true
    health.Outline = true
    health.Font = 2
    
    local tracer = Drawing.new("Line")
    tracer.Visible = false
    tracer.Color = Config.ESP.TracerColor
    tracer.Thickness = 2
    tracer.Transparency = 1
    
    ESPDrawings[player] = {box = box, name = name, health = health, tracer = tracer}
end

local function updateESP()
    local screenHeight = Camera.ViewportSize.Y
    for player, drawings in pairs(ESPDrawings) do
        if player and player.Character and player.Character:FindFirstChild("HumanoidRootPart") and player.Character:FindFirstChild("Humanoid") and player.Character.Humanoid.Health > 0 then
            local humanoidRootPart = player.Character.HumanoidRootPart
            local vector, onScreen = Camera:WorldToViewportPoint(humanoidRootPart.Position)
            
            if onScreen then
                local headPos = player.Character:FindFirstChild("Head") and player.Character.Head.Position or humanoidRootPart.Position
                local headVector = Camera:WorldToViewportPoint(headPos - Vector3.new(0, 3, 0))
                local sizeY = math.abs(headVector.Y - vector.Y) * 2
                local boxSize = Vector2.new(sizeY / 2, sizeY)
                
                drawings.box.Size = boxSize
                drawings.box.Position = Vector2.new(vector.X - boxSize.X / 2, vector.Y - boxSize.Y / 2)
                drawings.box.Visible = Config.ESP.Enabled and Config.ESP.ShowBoxes
                
                if Config.ESP.ShowNames then
                    drawings.name.Position = Vector2.new(vector.X, vector.Y - boxSize.Y / 2 - 16)
                    drawings.name.Text = player.Name
                    drawings.name.Visible = Config.ESP.Enabled
                end
                
                if Config.ESP.ShowHealth then
                    local healthVal = player.Character.Humanoid.Health / player.Character.Humanoid.MaxHealth * 100
                    drawings.health.Position = Vector2.new(vector.X - boxSize.X / 2 - 30, vector.Y - boxSize.Y / 2)
                    drawings.health.Text = string.format("%.0f%%", healthVal)
                    drawings.health.Visible = Config.ESP.Enabled
                end
                
                if Config.ESP.ShowTracers then
                    local tracerStart = Vector2.new(Camera.ViewportSize.X / 2, screenHeight)
                    drawings.tracer.From = tracerStart
                    drawings.tracer.To = Vector2.new(vector.X, vector.Y + boxSize.Y / 2)
                    drawings.tracer.Visible = Config.ESP.Enabled
                end
            else
                drawings.box.Visible = false
                drawings.name.Visible = false
                drawings.health.Visible = false
                drawings.tracer.Visible = false
            end
        else
            drawings.box.Visible = false
            drawings.name.Visible = false
            drawings.health.Visible = false
            drawings.tracer.Visible = false
        end
    end
end

-- Create ESP for all players
for _, player in pairs(Players:GetPlayers()) do
    createESP(player)
end

Players.PlayerAdded:Connect(createESP)

-- Main Loops
RunService.RenderStepped:Connect(function()
    if LocalPlayer.Character and Config.AimAssist.Active then
        local target = getClosestPlayerToCamera()
        if target then
            aimAtTarget(target)
        end
    end
    
    if Config.ESP.Enabled then
        updateESP()
    end
end)

local Window = Library:CreateWindow({
    Title = 'ChatGptHaxx.lol',
    Center = true,
    AutoShow = true,
    TabPadding = 8,
    MenuFadeTime = 0.2
})

local Tabs = {
    Combat = Window:AddTab('Combat'),
    Visuals = Window:AddTab('Visuals'),
    ['UI Settings'] = Window:AddTab('UI Settings'),
}

-- Combat Tab
local CombatGroup = Tabs.Combat:AddLeftGroupbox('Aim Settings')

CombatGroup:AddToggle('AimAssist', {
    Text = 'Aim Assist',
    Default = false,
    Tooltip = 'Enable Aim Assist',
    Callback = function(Value)
        Config.AimAssist.Active = Value
    end
})

CombatGroup:AddLabel('Aim Assist Key'):AddKeyPicker('AimAssistKey', {
    Default = 'F',
    Mode = 'Toggle',
    Text = 'Aim Assist Key',
    NoUI = false,
    Callback = function(Value)
        Config.AimAssist.Active = Value
        print('[cb] Aim Assist:', Value and 'activated' or 'deactivated')
    end,
    ChangedCallback = function(New)
        Config.AimAssist.Key = New
        print('[cb] Aim Assist key changed:', New)
    end
})

CombatGroup:AddSlider('AimAssistLockFOV', {
    Text = 'Lock FOV (degrees)',
    Default = 8,
    Min = 1,
    Max = 30,
    Rounding = 1,
    Callback = function(Value)
        Config.AimAssist.LockFOV = math.rad(Value)
    end
})

CombatGroup:AddSlider('AimAssistSmoothness', {
    Text = 'Aim Smoothness',
    Default = 0.2,
    Min = 0.01,
    Max = 1,
    Rounding = 2,
    Callback = function(Value)
        Config.AimAssist.Smoothness = Value
    end
})

CombatGroup:AddSlider('AimAssistPrediction', {
    Text = 'Prediction Factor',
    Default = 0.13,
    Min = 0,
    Max = 0.5,
    Rounding = 2,
    Callback = function(Value)
        Config.AimAssist.Prediction = Value
    end
})

CombatGroup:AddDropdown('AimAssistTargetPart', {
    Text = 'Aim Part',
    Values = {'Head', 'HumanoidRootPart'},
    Default = 1,
    Tooltip = 'Select which part to aim at',
    Callback = function(Value)
        Config.AimAssist.TargetPart = Value
    end
})

CombatGroup:AddToggle('AimAssistTeamCheck', {
    Text = 'Team Check',
    Default = false,
    Tooltip = 'Ignore teammates for aim assist',
    Callback = function(Value)
        Config.AimAssist.TeamCheck = Value
    end
})

CombatGroup:AddToggle('AimAssistWallCheck', {
    Text = 'Wall Check',
    Default = true,
    Tooltip = 'Check if target is behind a wall',
    Callback = function(Value)
        Config.AimAssist.WallCheck = Value
    end
})

CombatGroup:AddSlider('AimAssistMaxDistance', {
    Text = 'Max Distance',
    Default = 500,
    Min = 100,
    Max = 1000,
    Rounding = 0,
    Callback = function(Value)
        Config.AimAssist.MaxDistance = Value
    end
})

CombatGroup:AddToggle('AimAssistUseMouseMove', {
    Text = 'Use Mouse Move',
    Default = false,
    Tooltip = 'Use mouse movement instead of camera lerp',
    Callback = function(Value)
        Config.AimAssist.UseMouseMove = Value
    end
})

-- Visuals Tab
local VisualsGroup = Tabs.Visuals:AddLeftGroupbox('ESP Settings')

VisualsGroup:AddToggle('ESPToggle', {
    Text = 'ESP',
    Default = false,
    Tooltip = 'Enable ESP (boxes, names, health, tracers)',
    Callback = function(Value)
        Config.ESP.Enabled = Value
    end
})

VisualsGroup:AddLabel('Box Color'):AddColorPicker('ESPBoxColor', {
    Default = Color3.new(1, 0, 0),
    Title = 'ESP Box Color',
    Callback = function(Value)
        Config.ESP.BoxColor = Value
        for _, drawings in pairs(ESPDrawings) do
            drawings.box.Color = Value
        end
    end
})

VisualsGroup:AddLabel('Name Color'):AddColorPicker('ESPNameColor', {
    Default = Color3.new(1, 1, 1),
    Title = 'ESP Name Color',
    Callback = function(Value)
        Config.ESP.NameColor = Value
        for _, drawings in pairs(ESPDrawings) do
            drawings.name.Color = Value
        end
    end
})

VisualsGroup:AddLabel('Health Color'):AddColorPicker('ESPHealthColor', {
    Default = Color3.new(1, 1, 1),
    Title = 'ESP Health Color',
    Callback = function(Value)
        Config.ESP.HealthColor = Value
        for _, drawings in pairs(ESPDrawings) do
            drawings.health.Color = Value
        end
    end
})

VisualsGroup:AddLabel('Tracer Color'):AddColorPicker('ESPTracerColor', {
    Default = Color3.new(1, 0, 0),
    Title = 'ESP Tracer Color',
    Callback = function(Value)
        Config.ESP.TracerColor = Value
        for _, drawings in pairs(ESPDrawings) do
            drawings.tracer.Color = Value
        end
    end
})

VisualsGroup:AddToggle('ESPShowBoxes', {
    Text = 'Show Boxes',
    Default = true,
    Tooltip = 'Display boxes around players in ESP',
    Callback = function(Value)
        Config.ESP.ShowBoxes = Value
    end
})

VisualsGroup:AddToggle('ESPShowNames', {
    Text = 'Show Names',
    Default = true,
    Tooltip = 'Display player names in ESP',
    Callback = function(Value)
        Config.ESP.ShowNames = Value
    end
})

VisualsGroup:AddToggle('ESPShowHealth', {
    Text = 'Show Health',
    Default = true,
    Tooltip = 'Display player health in ESP',
    Callback = function(Value)
        Config.ESP.ShowHealth = Value
    end
})

VisualsGroup:AddToggle('ESPShowTracers', {
    Text = 'Show Tracers',
    Default = true,
    Tooltip = 'Display tracers to players in ESP',
    Callback = function(Value)
        Config.ESP.ShowTracers = Value
    end
})

-- UI Settings Tab
local MenuGroup = Tabs['UI Settings']:AddLeftGroupbox('Menu')

MenuGroup:AddButton({
    Text = 'Unload',
    Func = function() Library:Unload() end,
    Tooltip = 'Unload the script'
})

MenuGroup:AddLabel('Menu bind'):AddKeyPicker('MenuKeybind', {
    Default = 'End',
    NoUI = true,
    Text = 'Menu keybind',
    Callback = function(Value)
        print('[cb] Menu keybind changed:', Value)
    end
})

Library.ToggleKeybind = Options.MenuKeybind

-- Cleanup on player removing
Players.PlayerRemoving:Connect(function(player)
    if ESPDrawings[player] then
        ESPDrawings[player].box:Remove()
        ESPDrawings[player].name:Remove()
        ESPDrawings[player].health:Remove()
        ESPDrawings[player].tracer:Remove()
        ESPDrawings[player] = nil
    end
end)

-- Watermark with FPS and Ping
Library:SetWatermarkVisibility(true)
local FrameTimer = tick()
local FrameCounter = 0
local FPS = 60

local WatermarkConnection = RunService.RenderStepped:Connect(function()
    FrameCounter += 1
    if (tick() - FrameTimer) >= 1 then
        FPS = FrameCounter
        FrameTimer = tick()
        FrameCounter = 0
    end
    Library:SetWatermark(('Roblox Cheat | %s fps | %s ms'):format(
        math.floor(FPS),
        math.floor(game:GetService('Stats').Network.ServerStatsItem['Data Ping']:GetValue())
    ))
end)

Library:OnUnload(function()
    WatermarkConnection:Disconnect()
    print('Unloaded!')
    Library.Unloaded = true
end)

ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({'MenuKeybind'})
ThemeManager:SetFolder('RobloxCheat')
SaveManager:SetFolder('RobloxCheat/configs')
SaveManager:BuildConfigSection(Tabs['UI Settings'])
ThemeManager:ApplyToTab(Tabs['UI Settings'])
SaveManager:LoadAutoloadConfig()
ThemeManager:ApplyTheme('Ubuntu')

print("Cheat Script Loaded with Linoria (Aim Assist Press/Release + ESP with Boxes, Names, Health, Tracers)!")
