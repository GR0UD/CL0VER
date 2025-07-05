if getgenv().CL0VER then return warn("{CLØVER} already running") end
getgenv().CL0VER = true

if not game:IsLoaded() then game.Loaded:Wait() end
print("{CLØVER} connected successfully.")

local script_url = "https://raw.githubusercontent.com/GR0UD/CL0VER/main/CL0VER.lua"
local script_path = "CL0VER/script.lua"

writefile(script_path, game:HttpGet(script_url))

local queue_on_teleport =
    (syn and syn.queue_on_teleport) or
    (fluxus and fluxus.queue_on_teleport) or
    (KRNL_LOADED and queue_on_teleport)

if queue_on_teleport then
    queue_on_teleport([[
        if not game:IsLoaded() then game.Loaded:Wait() end
        loadstring(readfile("CL0VER/script.lua"))()
    ]])
else
    warn("{CLØVER} Teleport queue not supported on this executor.")
end

local HOTKEY     = getgenv().CL0VER_HOTKEY    or "R"
local SPEED      = getgenv().CL0VER_SPEED     or 0
local DELAY      = getgenv().CL0VER_DELAY     or 1.5
local OFFSET     = getgenv().CL0VER_OFFSET    or -20
local SERVER_HOP = getgenv().CL0VER_SERVERHOP or false

local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
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
        print("[CLØVER] No ambers found. Searching for a new server...")

        local HttpService = game:GetService("HttpService")
        local TeleportService = game:GetService("TeleportService")
        local PlaceId = game.PlaceId
        local JobId = game.JobId

        local servers = {}
        local success, result = pcall(function()
            return HttpService:JSONDecode(game:HttpGet(
                "https://games.roblox.com/v1/games/" .. PlaceId .. "/servers/Public?sortOrder=Desc&limit=100&excludeFullGames=true"
            ))
        end)

        if success and result and result.data then
            for _, v in next, result.data do
                if type(v) == "table" and tonumber(v.playing) and tonumber(v.maxPlayers)
                and v.playing < v.maxPlayers and v.id ~= JobId then
                    table.insert(servers, v.id)
                end
            end
        end

        if #servers > 0 then
            local targetServer = servers[math.random(1, #servers)]

            -- Queue script again
            local queue_on_teleport =
                (syn and syn.queue_on_teleport) or
                (fluxus and fluxus.queue_on_teleport) or
                (KRNL_LOADED and queue_on_teleport)

            if queue_on_teleport then
                queue_on_teleport([[
                    if not game:IsLoaded() then game.Loaded:Wait() end
                    loadstring(readfile("CL0VER/script.lua"))()
                ]])
            end

            TeleportService:TeleportToPlaceInstance(PlaceId, targetServer, game.Players.LocalPlayer)
        else
            warn("[CLØVER] No suitable servers found.")
        end
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

local topbar = player.PlayerGui.TopbarStandard.Holders.Left
topbar.Widget.IconButton.Menu.IconSpot.Contents.IconImage.IconImageScale.Value = 1 -- icon resize

local AutoFarmIcon = topbar.Widget:Clone()
AutoFarmIcon.Name = "AutoFarmIcon"
AutoFarmIcon.Parent = topbar

local iconImage = AutoFarmIcon.IconButton.Menu.IconSpot.Contents.IconImage
iconImage.Image = "rbxassetid://73201553806855"

local clickRegion = AutoFarmIcon.IconButton.Menu.IconSpot.ClickRegion
local iconOverlay = AutoFarmIcon.IconButton.Menu.IconSpot.IconOverlay

-- Toggle logic
local function updateIcon()
    iconImage.Image = _G.AutoFarm and "rbxassetid://97248123880891" or "rbxassetid://73201553806855"
    iconOverlay.Visible = true
end

clickRegion.MouseButton1Click:Connect(function()
    _G.AutoFarm = not _G.AutoFarm
    toggleAutoFarm(_G.AutoFarm)
    print("Auto-farming toggled", _G.AutoFarm and "ON!" or "OFF!")
    updateIcon()    
end)

clickRegion.MouseEnter:Connect(function()
    iconOverlay.Visible = true
end)

clickRegion.MouseLeave:Connect(function()
    iconOverlay.Visible = false
end)


UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode.Name == HOTKEY then
        _G.AutoFarm = not _G.AutoFarm
        toggleAutoFarm(_G.AutoFarm)
        AutoFarmIcon.IconButton.Menu.IconSpot.Contents.IconImage.Image = (_G.AutoFarm and "rbxassetid://97248123880891") or "rbxassetid://73201553806855"
        print("{CLØVER} toggled", _G.AutoFarm and "ON" or "OFF")
    end
end)
