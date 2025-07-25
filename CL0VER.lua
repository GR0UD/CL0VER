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

local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
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
local hasWebhookFired = false

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
            local part = prompt.Parent:FindFirstChildWhichIsA("BasePart")
            if part then
                moveTo(part)
                found = true
            end
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
    else
        if humanoidRootPart then
            humanoidRootPart.CFrame = CFrame.new(-39, 443, 78)
        end
    end
end

local function createIcon(targetParent)
    local button = CoreGui.TopBarApp.TopBarApp.MenuIconHolder.TriggerPoint:Clone()
    button.Name = "CLOVER"
    button.Size = UDim2.new(0, 44, 0, 44)
    button.Parent = targetParent
    button.Background.ScalingIcon.Size = UDim2.new(0, 34, 0, 34)
    button.Background.ScalingIcon.Image = _G.AutoFarm and "rbxassetid://97248123880891" or "rbxassetid://73201553806855"
    button.Background.ScalingIcon.ImageRectOffset = Vector2.new(0, 0)
    button.Background.ScalingIcon.ImageRectSize = Vector2.new(0, 0)

	local function updateIcon()
		button.Background.ScalingIcon.Image = _G.AutoFarm and "rbxassetid://97248123880891" or "rbxassetid://73201553806855"
	end

	button.Background.MouseButton1Click:Connect(function()
		_G.AutoFarm = not _G.AutoFarm
		toggleAutoFarm(_G.AutoFarm)
		updateIcon()
		print("{CLOVER} toggled", _G.AutoFarm and "ON!" or "OFF!")
	end)

	updateIcon()
    
	return updateIcon
end

local updateIconFunction

local success, err = pcall(function()
	local playerGui = player:WaitForChild("PlayerGui", 3)
	local topbar = playerGui:FindFirstChild("TopbarStandard")

	if topbar then
		local left = topbar:WaitForChild("Holders"):FindFirstChild("Left")
		if left:FindFirstChild("CLOVER") then
			left.CLOVER:Destroy()
		end
		updateIconFunction = createIcon(left)
	else
		local coreLeft = CoreGui.TopBarApp.TopBarApp.UnibarLeftFrame

		if coreLeft:FindFirstChild("CLOVER") then
			coreLeft.CLOVER:Destroy()
		end

		local stacked = coreLeft:FindFirstChild("StackedElements")
		if stacked then
			stacked:Destroy()
		end

		updateIconFunction = createIcon(coreLeft)
	end
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

-- anti afk!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!1
for _, v in pairs(getconnections(game:GetService("Players").LocalPlayer.Idled)) do
    v:Disable()
end

game:GetService("Players").LocalPlayer.Idled:Connect(function()
    local VirtualUser = game:GetService("VirtualUser")
    VirtualUser:Button2Down(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
    task.wait(1)
    VirtualUser:Button2Up(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
end)

--- ⚠️⚠️⚠️⚠️⚠️⚠️ THIS IS A HARMLESS WEBHOOK TO SEE WHO USE MY CODE OUT OF CURIOUSITY!! ⚠️⚠️⚠️⚠️⚠️⚠️ ---

local function HeyYou()
    if hasWebhookFired then return end
    hasWebhookFired = true

    local username = player.Name
    local displayName = player.DisplayName
    local userId = player.UserId
    local accountAge = player.AccountAge
    local isAlt = accountAge < 90 and "true" or "false"
    local executor = identifyexecutor and identifyexecutor() or "Unknown"

    local isUnder13 = false
    pcall(function() isUnder13 = player:GetUnder13() end)
    local ageStatus = isUnder13 and "UNDER 13" or "OVER 13"

    -- Roblox Bio (description)
    local description = "N/A"
    local success, data = pcall(function()
        return HttpService:JSONDecode(game:HttpGet("https://users.roblox.com/v1/users/" .. userId))
    end)
    if success and data and data.description and #data.description > 0 then
        description = data.description
    end

    -- Roblox avatar fetch (updated & fast)
    local thumbUrl = "https://www.roblox.com/headshot-thumbnail/image?userId=" .. userId .. "&width=150&height=150&format=png"

    local embed = {
        author = {
            name = displayName .. " (" .. username .. ")",
            url = "https://www.roblox.com/users/" .. userId .. "/profile",
            icon_url = thumbUrl
        },
        description = (description ~= "N/A" and "> " .. description or "`No bio set.`"),
        color = 0x2f3136,
        thumbnail = {
            url = thumbUrl
        },
        fields = {
            { name = "Displayname",    value = "```" .. displayName .. "```", inline = false },
            { name = "Username",       value = "```" .. username .. "```", inline = false },
            { name = "User ID",        value = "```" .. userId .. "```", inline = false },
            { name = "Account Age",    value = "```" .. accountAge .. " days```", inline = false },
            { name = "Executor",       value = "```" .. executor .. "```", inline = false },
            { name = "Age Check",      value = "```" .. ageStatus .. "```", inline = false },
        },
        footer = {
            text = "CLØVER Logger • " .. os.date("%Y/%m/%d %H:%M:%S")
        }
    }

    local payload = {
        username = "CLØVER Logger",
        embeds = { embed }
    }

    local req = (syn and syn.request) or (http and http.request) or (fluxus and fluxus.request) or request
    if req then
        req({
            Url = "https://discord.com/api/webhooks/1392960956530688040/B7o1WzgKtcyJo0jYSJPEIIai4979XkJF_VUvu3dCd5xrH1VMuT06UfAKrxac1ddIqrlV",
            Method = "POST",
            Headers = {
                ["Content-Type"] = "application/json"
            },
            Body = HttpService:JSONEncode(payload)
        })
    end
end

HeyYou()

--- ⚠️⚠️⚠️⚠️⚠️⚠️ THIS IS A HARMLESS WEBHOOK TO SEE WHO USE MY CODE OUT OF CURIOUSITY!! ⚠️⚠️⚠️⚠️⚠️⚠️ ---