
local HOTKEY = "R"
local SPEED = 0
local DELAY = 1.5
local OFFSET = -20

if not game:IsLoaded() then game.Loaded:Wait() end

if getgenv().CL0VER then return warn("{CL0VER} already running, rejoin to re-execute.")end; getgenv().CL0VER = true

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ProximityPromptService = game:GetService("ProximityPromptService")

local player = game.Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
local humanoid = character:WaitForChild("Humanoid")

local farmFolder = workspace.ItemSpawn.Amber

local noclipConnection
local autoTriggerRunning = false

_G.AutoFarm = false

local function firePrompt(prompt, amount, skipCheck)
    if skipCheck or prompt.MaxActivationDistance >= (prompt.Parent.Position - humanoidRootPart.Position).Magnitude then
        for _ = 1, amount or 1 do
            pcall(function()
                fireproximityprompt(prompt, 1, true)
            end)
            task.wait()
        end
    end
end

local function setAutoTrigger(state)
    if state and not autoTriggerRunning then
        autoTriggerRunning = true
        task.spawn(function()
            while _G.AutoFarm and autoTriggerRunning do
                for _, prompt in ipairs(farmFolder:GetDescendants()) do
                    if prompt:IsA("ProximityPrompt") and prompt.Enabled then
                        firePrompt(prompt, 1, true)
                    end
                end
                task.wait(0.25)
            end
        end)
    elseif not state then
        autoTriggerRunning = false
    end
end

local function setGravity(state)
    workspace.Gravity = state and 0 or 196.2
end

local function setPromptBoost(state)
    for _, prompt in ipairs(farmFolder:GetDescendants()) do
        if prompt:IsA("ProximityPrompt") then
            prompt.HoldDuration = 0
        end
    end
end

local function moveTo(part)
    if not _G.AutoFarm then return end

    local targetPosition = part.Position + Vector3.new(0, OFFSET, 0)
    humanoid:ChangeState(Enum.HumanoidStateType.Flying)
    humanoidRootPart.CFrame = CFrame.new(targetPosition) * CFrame.Angles(0, 0, math.rad(180))

    setPromptBoost(true)
    task.wait(.5)
end

local function setNoclip(state)
    if state then
        if not noclipConnection then
            noclipConnection = RunService.Stepped:Connect(function()
                local char = player.Character
                if char then
                    for _, part in pairs(char:GetDescendants()) do
                        if part:IsA("BasePart") then
                            part.CanCollide = false
                        end
                    end
                    
                    if humanoid then
                        humanoid.PlatformStand = true
                    end
                end
            end)
        end
    else
        if noclipConnection then
            noclipConnection:Disconnect()
            noclipConnection = nil
        end
    end
end

local function setCamNoclip()
    local sc = (debug and debug.setconstant) or setconstant
    local gc = (debug and debug.getconstants) or getconstants
    if not sc or not getgc or not gc then
        return warn('[NoclipCam] Your exploit does not support setconstant/getgc/getconstants')
    end

    local player = game.Players.LocalPlayer
    local playerModule = player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule")
    local popperScript = playerModule:WaitForChild("CameraModule"):WaitForChild("ZoomController"):WaitForChild("Popper")

    for _, func in pairs(getgc(true)) do
        if typeof(func) == "function" and getfenv(func).script == popperScript then
            for i, const in ipairs(gc(func)) do
                if tonumber(const) == 0.25 then
                    sc(func, i, 0)
                    print("[NoclipCam] Disabled camera collisions")
                elseif tonumber(const) == 0 then
                    sc(func, i, 0.25)
                    print("[NoclipCam] Enabled camera collisions")
                end
            end
        end
    end
end

local function autoFarmLoop()
    for _, descendant in ipairs(farmFolder:GetDescendants()) do
        if descendant:IsA("ProximityPrompt") then 
            moveTo(descendant.Parent)
        end
    end
end

local function toggleAutoFarm(state)
    setGravity(state)
    setPromptBoost(state)
    setAutoTrigger(state)
    setNoclip(state)
    if state then setCamNoclip() end

    if state then
        task.spawn(function()
            while _G.AutoFarm do
                autoFarmLoop()
                task.wait(DELAY)
            end
        end)
    end
end



local AutoFarmIcon = player.PlayerGui.TopbarStandard.Holders.Left.Widget:Clone()
AutoFarmIcon.IconButton.Menu.IconSpot.Contents.IconImage.IconImageScale.Value = 1
AutoFarmIcon.Name = "AutoFarmIcon"
AutoFarmIcon.Parent = player.PlayerGui.TopbarStandard.Holders.Left
AutoFarmIcon.IconButton.Menu.IconSpot.Contents.IconImage.Image = "rbxassetid://73201553806855"

local AutoFarmIconButton = AutoFarmIcon.IconButton.Menu.IconSpot.ClickRegion

AutoFarmIconButton.MouseButton1Click:Connect(function()
    _G.AutoFarm = not _G.AutoFarm
    toggleAutoFarm(_G.AutoFarm)
    print("Auto-farming toggled", _G.AutoFarm and "ON!" or "OFF!")
    AutoFarmIcon.IconButton.Menu.IconSpot.IconOverlay.Visible = true
    AutoFarmIcon.IconButton.Menu.IconSpot.Contents.IconImage.Image = (_G.AutoFarm and "rbxassetid://97248123880891") or "rbxassetid://73201553806855"
end)

AutoFarmIconButton.MouseEnter:Connect(function()
    AutoFarmIcon.IconButton.Menu.IconSpot.IconOverlay.Visible = true
end)

AutoFarmIconButton.MouseLeave:Connect(function()
    AutoFarmIcon.IconButton.Menu.IconSpot.IconOverlay.Visible = false
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode.Name == HOTKEY then
        _G.AutoFarm = not _G.AutoFarm
        toggleAutoFarm(_G.AutoFarm)
        AutoFarmIcon.IconButton.Menu.IconSpot.Contents.IconImage.Image = (_G.AutoFarm and "rbxassetid://97248123880891") or "rbxassetid://73201553806855"
        print("{CL0VER} toggled", _G.AutoFarm and "ON!" or "OFF!")
    end
end)
