if getgenv().CL0VER then return warn("{CLØVER} already running") end
getgenv().CL0VER = true

if not game:IsLoaded() then game.Loaded:Wait() end
print("{CLØVER} connected successfully.")

-- vars with fallbacks
local HOTKEY     = getgenv().CL0VER_HOTKEY    or "R"
local SPEED      = getgenv().CL0VER_SPEED     or 0
local DELAY      = getgenv().CL0VER_DELAY     or 1.5
local OFFSET     = getgenv().CL0VER_OFFSET    or -20
local SERVER_HOP = getgenv().CL0VER_SERVERHOP or false


local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local player = game.Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoidRootPart = character.PrimaryPart or character:FindFirstChild("HumanoidRootPart") or character:FindFirstChildWhichIsA("BasePart")
local humanoid = character:WaitForChild("Humanoid")
local farmFolder = workspace.ItemSpawn:FindFirstChild("Amber")

local noclipConnection
local autoTriggerRunning = false
_G.AutoFarm = false

local function firePrompt(prompt, amount, skipCheck)
    if skipCheck or prompt.MaxActivationDistance >= (prompt.Parent.Position - humanoidRootPart.Position).Magnitude then
        for _ = 1, amount or 1 do
            pcall(function() fireproximityprompt(prompt, 1, true) end)
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
    else
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
    if not _G.AutoFarm or not part or not part:IsA("BasePart") then
        return
    end

    local pos = part.Position + Vector3.new(0, OFFSET, 0)
    humanoid:ChangeState(Enum.HumanoidStateType.Flying)
    humanoidRootPart.CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(180))
    setPromptBoost(true)
    task.wait(DELAY)
end

local function setNoclip(state)
    if state then
        if not noclipConnection then
            noclipConnection = RunService.Stepped:Connect(function()
                for _, part in pairs(player.Character:GetDescendants()) do
                    if part:IsA("BasePart") then part.CanCollide = false end
                end
                humanoid.PlatformStand = true
            end)
        end
    elseif noclipConnection then
        noclipConnection:Disconnect()
        noclipConnection = nil
        humanoid.PlatformStand = false
    end
end

local function autoFarmLoop()
    local found = false
    for _, prompt in ipairs(farmFolder:GetDescendants()) do
        if prompt:IsA("ProximityPrompt") and prompt.Enabled then
            moveTo(prompt.Parent)
            found = true
        end
    end

    if not found and SERVER_HOP then
        print("[CLØVER] No ambers found. Hopping servers...")
        task.wait(1)
        game:GetService("TeleportService"):Teleport(game.PlaceId)
    end
end

local function toggleAutoFarm(state)
    setGravity(state)
    setPromptBoost(state)
    setAutoTrigger(state)
    setNoclip(state)
    if state then
        task.spawn(function()
            while _G.AutoFarm do
                autoFarmLoop()
                task.wait(DELAY)
            end
        end)
    end
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode.Name == HOTKEY then
        _G.AutoFarm = not _G.AutoFarm
        toggleAutoFarm(_G.AutoFarm)
        print("{CLØVER} toggled", _G.AutoFarm and "ON" or "OFF")
    end
end)
