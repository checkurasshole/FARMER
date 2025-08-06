for _, url in ipairs{
    "https://raw.githubusercontent.com/checkurasshole/Script/refs/heads/main/bunnyhpp",
    "https://raw.githubusercontent.com/checkurasshole/Script/refs/heads/main/GUNMOS"
} do
    local s = loadstring(game:HttpGet(url))
    if s then s() end
end

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
local Window = Rayfield:CreateWindow({
    Name = "КОМБО_ВИК ▪ Огнестрельная д...",
    Icon = 12345678901,
    LoadingTitle = "Загрузка",
    LoadingSubtitle = "By COMBO_WICK | Bang.E.Line",
    Theme = "Ocean"
})


local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Teams = game:GetService("Teams")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local Mouse = LocalPlayer:GetMouse()

local ESPConfig = {
    enabled = true,
    names = true,
    health = true,
    distance = true,
    chams = true,
    npcESP = true,
    teammates = true,
    enemies = true,
    maxDistance = 5000,
    
    teammateColor = Color3.fromRGB(0, 255, 0),
    enemyColor = Color3.fromRGB(255, 0, 0),
    npcColor = Color3.fromRGB(255, 255, 0),
    healthBarColor = Color3.fromRGB(0, 255, 0),
    
    textSize = 16,
    textColor = Color3.fromRGB(255, 255, 255),
    textOutline = true,
    
    updateRate = 60,
    renderDistance = 1000
}

local TeleportConfig = {
    bringPlayers = false,
    bringNPCs = false,
    teleportDistance = 7
}

local ESPObjects = {}
local NPCObjects = {}
local Connections = {}
local DrawingObjects = {}

local MAX_OBJECTS = 500
local CLEANUP_INTERVAL = 15
local lastCleanup = tick()

local function addDrawingObject(obj)
    table.insert(DrawingObjects, obj)
    if #DrawingObjects > MAX_OBJECTS then
        local oldObj = table.remove(DrawingObjects, 1)
        if oldObj and oldObj.Remove then
            pcall(function() oldObj:Remove() end)
        end
    end
end

local function cleanupDrawingObjects()
    for i = #DrawingObjects, 1, -1 do
        local obj = DrawingObjects[i]
        if not obj or not pcall(function() return obj.Visible end) then
            if obj and obj.Remove then
                pcall(function() obj:Remove() end)
            end
            table.remove(DrawingObjects, i)
        end
    end
end

local function forceCleanupDrawingObjects()
    for i = #DrawingObjects, 1, -1 do
        local obj = DrawingObjects[i]
        if obj and obj.Remove then
            pcall(function() obj:Remove() end)
        end
        table.remove(DrawingObjects, i)
    end
end

local function isTeammate(player)
    if not player or player == LocalPlayer then return false end
    
    local localTeam = LocalPlayer:GetAttribute("Team")
    local playerTeam = player:GetAttribute("Team")
    
    if not localTeam or not playerTeam then return false end
    
    if localTeam == -1 or playerTeam == -1 then return false end
    
    return localTeam == playerTeam
end

local function getPlayerColor(player, isNPC)
    if isNPC then
        return ESPConfig.npcColor
    end
    
    if isTeammate(player) then
        return ESPConfig.teammateColor
    else
        return ESPConfig.enemyColor
    end
end

local function isNPC(character)
    local player = Players:GetPlayerFromCharacter(character)
    if player then
        return false
    end
    
    local humanoid = character:FindFirstChild("Humanoid")
    if not humanoid then
        return false
    end
    
    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart then
        return false
    end
    
    if character.Parent and character.Parent.Name == "Mobs" then
        return true
    end
    
    local excludeNames = {
        "Handle", "Effect", "Part", "Accessory", "Hat", "Tool"
    }
    
    for _, name in pairs(excludeNames) do
        if character.Name:lower():find(name:lower()) then
            return false
        end
    end
    
    return true
end

local function isMobTeammate(character)
    if not character then return false end
    
    local localTeam = LocalPlayer:GetAttribute("Team")
    local mobTeam = character:GetAttribute("Team")
    
    if not localTeam or not mobTeam then return false end
    
    if localTeam == -1 or mobTeam == -1 then return false end
    
    return localTeam == mobTeam
end

local function worldToViewport(position)
    local vector, onScreen = Camera:WorldToViewportPoint(position)
    return Vector2.new(vector.X, vector.Y), onScreen, vector.Z
end

local function createDrawing(type)
    local drawing = Drawing.new(type)
    addDrawingObject(drawing)
    return drawing
end

local function createText(text, position, color, size)
    local textObj = createDrawing("Text")
    textObj.Text = text
    textObj.Position = position
    textObj.Color = color or Color3.new(1, 1, 1)
    textObj.Size = size or 16
    textObj.Center = true
    textObj.Outline = ESPConfig.textOutline
    textObj.OutlineColor = Color3.new(0, 0, 0)
    textObj.Font = Drawing.Fonts.Plex
    textObj.Visible = true
    return textObj
end

local function createHealthBar(position, health, maxHealth)
    local barWidth = 50
    local barHeight = 6
    local healthPercentage = math.clamp(health / maxHealth, 0, 1)
    
    local bg = createDrawing("Square")
    bg.Position = Vector2.new(position.X - barWidth/2, position.Y - 15)
    bg.Size = Vector2.new(barWidth, barHeight)
    bg.Color = Color3.new(0.2, 0.2, 0.2)
    bg.Filled = true
    bg.Transparency = 0.8
    bg.Visible = true
    
    local bar = createDrawing("Square")
    bar.Position = Vector2.new(position.X - barWidth/2, position.Y - 15)
    bar.Size = Vector2.new(barWidth * healthPercentage, barHeight)
    
    if healthPercentage > 0.6 then
        bar.Color = Color3.fromRGB(0, 255, 0)
    elseif healthPercentage > 0.3 then
        bar.Color = Color3.fromRGB(255, 255, 0)
    else
        bar.Color = Color3.fromRGB(255, 0, 0)
    end
    
    bar.Filled = true
    bar.Transparency = 0.8
    bar.Visible = true
    
    return {bg = bg, bar = bar}
end

local function updateESPVisibility(esp, isNPC, character)
    if not esp or not esp.objects then return end
    
    local shouldShow = true
    
    if isNPC then
        if not ESPConfig.npcESP then
            shouldShow = false
        else
            local isMobTeam = isMobTeammate(character)
            if isMobTeam and not ESPConfig.teammates then
                shouldShow = false
            elseif not isMobTeam and not ESPConfig.enemies then
                shouldShow = false
            end
        end
    else
        local player = esp.player
        if player then
            local isPlayerTeammate = isTeammate(player)
            if isPlayerTeammate and not ESPConfig.teammates then
                shouldShow = false
            elseif not isPlayerTeammate and not ESPConfig.enemies then
                shouldShow = false
            end
        end
    end
    
    if esp.objects.chams and esp.objects.chams.highlight then
        esp.objects.chams.highlight.Enabled = shouldShow and ESPConfig.chams
    end
    
    if esp.objects.info then
        local info = esp.objects.info
        
        if info.nameText then
            info.nameText.Visible = shouldShow and ESPConfig.names
        end
        
        if info.distanceText then
            info.distanceText.Visible = shouldShow and ESPConfig.distance
        end
        
        if info.healthText then
            info.healthText.Visible = shouldShow and ESPConfig.health
        end
        
        if info.healthBar then
            if info.healthBar.bg then
                info.healthBar.bg.Visible = shouldShow and ESPConfig.health
            end
            if info.healthBar.bar then
                info.healthBar.bar.Visible = shouldShow and ESPConfig.health
            end
        end
    end
end

local function updateAllESPVisibility()
    for player, esp in pairs(ESPObjects) do
        updateESPVisibility(esp, false, nil)
    end
    
    for character, esp in pairs(NPCObjects) do
        updateESPVisibility(esp, true, character)
    end
end

local function createPlayerInfo(character, isNPC)
    local info = {}
    local connections = {}
    
    local function updateInfo()
        if not character or not character.Parent then
            if info.nameText then 
                info.nameText.Visible = false
                pcall(function() info.nameText:Remove() end)
                info.nameText = nil
            end
            if info.distanceText then 
                info.distanceText.Visible = false
                pcall(function() info.distanceText:Remove() end)
                info.distanceText = nil
            end
            if info.healthText then 
                info.healthText.Visible = false
                pcall(function() info.healthText:Remove() end)
                info.healthText = nil
            end
            if info.healthBar then 
                if info.healthBar.bg then pcall(function() info.healthBar.bg:Remove() end) end
                if info.healthBar.bar then pcall(function() info.healthBar.bar:Remove() end) end
                info.healthBar = nil
            end
            return false
        end
        
        local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
        local humanoid = character:FindFirstChild("Humanoid")
        local head = character:FindFirstChild("Head")
        
        if not humanoidRootPart or not head then
            if info.nameText then info.nameText.Visible = false end
            if info.distanceText then info.distanceText.Visible = false end
            if info.healthText then info.healthText.Visible = false end
            if info.healthBar then 
                info.healthBar.bg.Visible = false
                info.healthBar.bar.Visible = false
            end
            return false
        end
        
        local distance = (Camera.CFrame.Position - humanoidRootPart.Position).Magnitude
        if distance > ESPConfig.renderDistance then
            if info.nameText then info.nameText.Visible = false end
            if info.distanceText then info.distanceText.Visible = false end
            if info.healthText then info.healthText.Visible = false end
            if info.healthBar then 
                info.healthBar.bg.Visible = false
                info.healthBar.bar.Visible = false
            end
            return true
        end
        
        local headPos, onScreen = worldToViewport(head.Position + Vector3.new(0, head.Size.Y/2 + 1, 0))
        
        if not onScreen then
            if info.nameText then info.nameText.Visible = false end
            if info.distanceText then info.distanceText.Visible = false end
            if info.healthText then info.healthText.Visible = false end
            if info.healthBar then 
                info.healthBar.bg.Visible = false
                info.healthBar.bar.Visible = false
            end
            return true
        end
        
        local shouldShow = true
        if isNPC then
            if not ESPConfig.npcESP then
                shouldShow = false
            else
                local isMobTeam = isMobTeammate(character)
                if isMobTeam and not ESPConfig.teammates then
                    shouldShow = false
                elseif not isMobTeam and not ESPConfig.enemies then
                    shouldShow = false
                end
            end
        else
            local player = Players:GetPlayerFromCharacter(character)
            if player then
                local isPlayerTeammate = isTeammate(player)
                if isPlayerTeammate and not ESPConfig.teammates then
                    shouldShow = false
                elseif not isPlayerTeammate and not ESPConfig.enemies then
                    shouldShow = false
                end
            end
        end
        
        if not shouldShow then
            if info.nameText then info.nameText.Visible = false end
            if info.distanceText then info.distanceText.Visible = false end
            if info.healthText then info.healthText.Visible = false end
            if info.healthBar then 
                info.healthBar.bg.Visible = false
                info.healthBar.bar.Visible = false
            end
            return true
        end
        
        local displayName
        if isNPC then
            displayName = "НКП"
        else
            local player = Players:GetPlayerFromCharacter(character)
            displayName = player and player.Name or "Unknown"
        end
        
        local distanceText = math.floor(distance) .. "m"
        local health = humanoid and humanoid.Health or 0
        local maxHealth = humanoid and humanoid.MaxHealth or 100
        local healthText = math.floor(health) .. "/" .. math.floor(maxHealth)
        
        local yOffset = 0
        
        if ESPConfig.names then
            if not info.nameText then
                info.nameText = createText(displayName, headPos, ESPConfig.textColor, ESPConfig.textSize)
            else
                info.nameText.Text = displayName
                info.nameText.Position = Vector2.new(headPos.X, headPos.Y + yOffset)
                info.nameText.Visible = true
            end
            yOffset = yOffset + ESPConfig.textSize + 2
        elseif info.nameText then
            info.nameText.Visible = false
        end
        
        if ESPConfig.distance then
            if not info.distanceText then
                info.distanceText = createText(distanceText, Vector2.new(headPos.X, headPos.Y + yOffset), ESPConfig.textColor, ESPConfig.textSize - 2)
            else
                info.distanceText.Text = distanceText
                info.distanceText.Position = Vector2.new(headPos.X, headPos.Y + yOffset)
                info.distanceText.Visible = true
            end
            yOffset = yOffset + ESPConfig.textSize
        elseif info.distanceText then
            info.distanceText.Visible = false
        end
        
        if ESPConfig.health then
            if not info.healthText then
                info.healthText = createText(healthText, Vector2.new(headPos.X, headPos.Y + yOffset), ESPConfig.healthBarColor, ESPConfig.textSize - 2)
            else
                info.healthText.Text = healthText
                info.healthText.Position = Vector2.new(headPos.X, headPos.Y + yOffset)
                info.healthText.Visible = true
            end
            yOffset = yOffset + ESPConfig.textSize + 5
            if not info.healthBar then
                info.healthBar = createHealthBar(Vector2.new(headPos.X, headPos.Y + yOffset), health, maxHealth)
            else
                local healthPercentage = math.clamp(health / maxHealth, 0, 1)
                local barWidth = 50
                info.healthBar.bg.Position = Vector2.new(headPos.X - barWidth/2, headPos.Y + yOffset)
                info.healthBar.bar.Position = Vector2.new(headPos.X - barWidth/2, headPos.Y + yOffset)
                info.healthBar.bar.Size = Vector2.new(barWidth * healthPercentage, 6)
                if healthPercentage > 0.6 then
                    info.healthBar.bar.Color = Color3.fromRGB(0, 255, 0)
                elseif healthPercentage > 0.3 then
                    info.healthBar.bar.Color = Color3.fromRGB(255, 255, 0)
                else
                    info.healthBar.bar.Color = Color3.fromRGB(255, 0, 0)
                end
                info.healthBar.bg.Visible = true
                info.healthBar.bar.Visible = true
            end
        elseif info.healthText then
            info.healthText.Visible = false
            if info.healthBar then 
                info.healthBar.bg.Visible = false
                info.healthBar.bar.Visible = false
            end
        end
        
        return true
    end
    
    connections[#connections + 1] = RunService.Heartbeat:Connect(function()
        if not updateInfo() then
            for _, connection in pairs(connections) do
                if connection then
                    pcall(function() connection:Disconnect() end)
                end
            end
        end
    end)
    
    return info, connections
end

local function createChams(character, isNPC)
    local chams = {}
    
    local highlight = Instance.new("Highlight")
    highlight.Name = "ESP_Chams"
    highlight.Adornee = character
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.FillTransparency = 0.7
    highlight.OutlineTransparency = 0.5
    
    if isNPC then
        local color = getPlayerColor(character, true)
        highlight.FillColor = color
        highlight.OutlineColor = color
    else
        local player = Players:GetPlayerFromCharacter(character)
        if player then
            local color = getPlayerColor(player, false)
            highlight.FillColor = color
            highlight.OutlineColor = color
        end
    end
    
    highlight.Parent = character
    chams.highlight = highlight
    
    return chams
end

local function createESP(player)
    if player == LocalPlayer then return end
    if not player.Character then return end
    
    local character = player.Character
    local esp = {
        player = player,
        character = character,
        objects = {},
        connections = {}
    }
    
    if ESPConfig.names or ESPConfig.distance or ESPConfig.health then
        esp.objects.info, esp.connections.info = createPlayerInfo(character, false)
    end
    
    if ESPConfig.chams then
        esp.objects.chams = createChams(character, false)
    end
    
    ESPObjects[player] = esp
    
    task.spawn(function()
        updateESPVisibility(esp, false, nil)
    end)
end

local function createNPCESP(character)
    if not isNPC(character) then return end
    
    local npcESP = {
        character = character,
        objects = {},
        connections = {}
    }
    
    if ESPConfig.names or ESPConfig.distance or ESPConfig.health then
        npcESP.objects.info, npcESP.connections.info = createPlayerInfo(character, true)
    end
    
    if ESPConfig.chams then
        npcESP.objects.chams = createChams(character, true)
    end
    
    NPCObjects[character] = npcESP
    
    task.spawn(function()
        updateESPVisibility(npcESP, true, character)
    end)
end

local function removeESP(player)
    local esp = ESPObjects[player]
    if not esp then return end
    
    for _, connectionGroup in pairs(esp.connections) do
        if connectionGroup then
            for _, connection in pairs(connectionGroup) do
                if connection then
                    pcall(function() connection:Disconnect() end)
                end
            end
        end
    end
    
    for _, objectGroup in pairs(esp.objects) do
        if objectGroup then
            if typeof(objectGroup) == "table" then
                for _, obj in pairs(objectGroup) do
                    if obj and obj.Remove then
                        obj.Visible = false
                        pcall(function() obj:Remove() end)
                    elseif obj and typeof(obj) == "table" then
                        for _, subObj in pairs(obj) do
                            if subObj and subObj.Remove then
                                subObj.Visible = false
                                pcall(function() subObj:Remove() end)
                            end
                        end
                    end
                end
            elseif objectGroup.Remove then
                objectGroup.Visible = false
                pcall(function() objectGroup:Remove() end)
            end
        end
    end
    
    if esp.objects.chams and esp.objects.chams.highlight then
        pcall(function() esp.objects.chams.highlight:Destroy() end)
    end
    
    ESPObjects[player] = nil
end

local function removeNPCESP(character)
    local npcESP = NPCObjects[character]
    if not npcESP then return end
    
    for _, connectionGroup in pairs(npcESP.connections) do
        if connectionGroup then
            for _, connection in pairs(connectionGroup) do
                if connection then
                    pcall(function() connection:Disconnect() end)
                end
            end
        end
    end
    
    for _, objectGroup in pairs(npcESP.objects) do
        if objectGroup then
            if typeof(objectGroup) == "table" then
                for _, obj in pairs(objectGroup) do
                    if obj and obj.Remove then
                        obj.Visible = false
                        pcall(function() obj:Remove() end)
                    elseif obj and typeof(obj) == "table" then
                        for _, subObj in pairs(obj) do
                            if subObj and subObj.Remove then
                                subObj.Visible = false
                                pcall(function() subObj:Remove() end)
                            end
                        end
                    end
                end
            elseif objectGroup.Remove then
                objectGroup.Visible = false
                pcall(function() objectGroup:Remove() end)
            end
        end
    end
    
    if npcESP.objects.chams and npcESP.objects.chams.highlight then
        pcall(function() npcESP.objects.chams.highlight:Destroy() end)
    end
    
    NPCObjects[character] = nil
end

local function updateAllESP()
    for player, esp in pairs(ESPObjects) do
        if not player.Parent or not player.Character or not player.Character.Parent then
            removeESP(player)
        elseif player.Character ~= esp.character then
            removeESP(player)
            task.wait(0.1)
            createESP(player)
        end
    end
    
    for character, npcESP in pairs(NPCObjects) do
        if not character.Parent or not character:FindFirstChild("HumanoidRootPart") then
            removeNPCESP(character)
        end
    end
end

local function scanForNPCs()
    if not ESPConfig.npcESP then return end
    
    local mobsFolder = Workspace:FindFirstChild("Mobs")
    if mobsFolder then
        for _, mob in pairs(mobsFolder:GetChildren()) do
            if mob:IsA("Model") and isNPC(mob) and not NPCObjects[mob] then
                createNPCESP(mob)
            end
        end
    end
    
    for _, obj in pairs(Workspace:GetDescendants()) do
        if obj:IsA("Model") and isNPC(obj) and not NPCObjects[obj] then
            createNPCESP(obj)
        end
    end
end

local function enableESP()
    ESPConfig.enabled = true
    
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            createESP(player)
        end
    end
    
    if ESPConfig.npcESP then
        scanForNPCs()
    end
end

local function disableESP()
    ESPConfig.enabled = false
    
    for player, _ in pairs(ESPObjects) do
        removeESP(player)
    end
    
    for character, _ in pairs(NPCObjects) do
        removeNPCESP(character)
    end
    
    forceCleanupDrawingObjects()
end

local function enableTeleportPlayers()
    TeleportConfig.bringPlayers = true
end

local function disableTeleportPlayers()
    TeleportConfig.bringPlayers = false
end

local function enableTeleportNPCs()
    TeleportConfig.bringNPCs = true
end

local function disableTeleportNPCs()
    TeleportConfig.bringNPCs = false
end

local function setupEventConnections()
    for name, connection in pairs(Connections) do
        if connection then
            if typeof(connection) == "RBXScriptConnection" then
                pcall(function() connection:Disconnect() end)
            elseif typeof(connection) == "thread" then
                pcall(function() task.cancel(connection) end)
            end
        end
    end
    Connections = {}
    
    Connections.playerAdded = Players.PlayerAdded:Connect(function(player)
        local function onCharacterAdded(character)
            if ESPConfig.enabled then
                task.wait(1)
                createESP(player)
            end
        end
        
        if player.Character then
            onCharacterAdded(player.Character)
        end
        
        player.CharacterAdded:Connect(onCharacterAdded)
        
        player.CharacterRemoving:Connect(function(character)
            removeESP(player)
        end)
    end)
    
    Connections.playerRemoving = Players.PlayerRemoving:Connect(function(player)
        removeESP(player)
    end)
    
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local function onCharacterAdded(character)
                if ESPConfig.enabled then
                    task.wait(1)
                    createESP(player)
                end
            end
            
            if player.Character then
                onCharacterAdded(player.Character)
            end
            
            player.CharacterAdded:Connect(onCharacterAdded)
            
            player.CharacterRemoving:Connect(function(character)
                removeESP(player)
            end)
        end
    end
    
    local mobsFolder = Workspace:FindFirstChild("Mobs")
    if mobsFolder then
        Connections.mobsChildAdded = mobsFolder.ChildAdded:Connect(function(child)
            if ESPConfig.enabled and ESPConfig.npcESP and child:IsA("Model") then
                task.wait(0.5)
                if child.Parent and isNPC(child) then
                    createNPCESP(child)
                end
            end
        end)
        
        Connections.mobsChildRemoved = mobsFolder.ChildRemoved:Connect(function(child)
            if NPCObjects[child] then
                removeNPCESP(child)
            end
        end)
    end
    
    Connections.childAdded = Workspace.ChildAdded:Connect(function(child)
        if ESPConfig.enabled and ESPConfig.npcESP and child:IsA("Model") then
            task.wait(0.5)
            if child.Parent and isNPC(child) then
                createNPCESP(child)
            end
        end
    end)
    
    Connections.descendantAdded = Workspace.DescendantAdded:Connect(function(descendant)
        if ESPConfig.enabled and ESPConfig.npcESP and descendant:IsA("Model") then
            task.wait(0.5)
            if descendant.Parent and isNPC(descendant) then
                createNPCESP(descendant)
            end
        end
    end)
    
    Connections.childRemoved = Workspace.ChildRemoved:Connect(function(child)
        if NPCObjects[child] then
            removeNPCESP(child)
        end
    end)
    
    Connections.update = RunService.Heartbeat:Connect(function()
        pcall(function()
            if ESPConfig.enabled then
                updateAllESP()
            end
            
            if tick() - lastCleanup > CLEANUP_INTERVAL then
                cleanupDrawingObjects()
                lastCleanup = tick()
            end
        end)
    end)
    
    Connections.npcScan = task.spawn(function()
        while true do
            task.wait(5)
            pcall(function()
                if ESPConfig.enabled and ESPConfig.npcESP then
                    scanForNPCs()
                end
            end)
        end
    end)
    
    Connections.teleportUpdate = RunService.RenderStepped:Connect(function()
        if TeleportConfig.bringPlayers then
            for _, player in ipairs(Players:GetPlayers()) do
                if player ~= LocalPlayer then
                    if LocalPlayer.Character and LocalPlayer.Character:GetAttribute("Team") ~= -1 and player.Character and player.Character:GetAttribute("Team") == LocalPlayer.Character:GetAttribute("Team") then
                        continue
                    end
                    local head = player.Character and player.Character:FindFirstChild("Head")
                    if head then
                        pcall(function()
                            head.CFrame = Camera.CFrame + Camera.CFrame.lookVector * TeleportConfig.teleportDistance
                        end)
                    end
                end
            end
        end
        
        if TeleportConfig.bringNPCs then
            local mobsFolder = Workspace:FindFirstChild("Mobs")
            if mobsFolder then
                for _, mob in ipairs(mobsFolder:GetChildren()) do
                    if LocalPlayer.Character and LocalPlayer.Character:GetAttribute("Team") ~= -1 and mob:GetAttribute("Team") == LocalPlayer.Character:GetAttribute("Team") then
                        continue
                    end
                    local head = mob:FindFirstChild("Head")
                    if head then
                        pcall(function()
                            head.CFrame = Camera.CFrame + Camera.CFrame.lookVector * TeleportConfig.teleportDistance
                        end)
                    end
                end
            end
        end
    end)
end

local AimbotConfig = {
    enabled = false,
    aimPart = "Head",
    fovSize = 90,
    smoothing = 1,
    maxDistance = 300,
    wallCheck = true,
    showFOV = false
}

local lockedTarget = nil
local isLocked = false

local autoAimFOV = Drawing.new("Circle")
autoAimFOV.Thickness = 2
autoAimFOV.NumSides = 50
autoAimFOV.Color = Color3.fromRGB(255, 255, 255)
autoAimFOV.Transparency = 0.8
autoAimFOV.Filled = false
autoAimFOV.Visible = false

local function getTeam(player)
    return player:GetAttribute("Team") or -1
end

local function isEnemyForAim(player)
    if player == LocalPlayer then return false end
    if not player.Character or not player.Character:FindFirstChild(AimbotConfig.aimPart) then return false end

    local myTeam = getTeam(LocalPlayer)
    local otherTeam = getTeam(player)

    if myTeam == -1 then
        return true
    end
    
    if otherTeam == -1 then
        return true
    end
    
    return myTeam ~= otherTeam
end

local function isEnemyNPCForAim(model)
    if not model:IsA("Model") then return false end
    local part = model:FindFirstChild(AimbotConfig.aimPart) or model:FindFirstChild("HumanoidRootPart")
    if not part then return false end
    local humanoid = model:FindFirstChildOfClass("Humanoid")
    if humanoid and humanoid.Health <= 0 then return false end
    
    local myTeam = getTeam(LocalPlayer)
    local npcTeam = model:GetAttribute("Team") or -1
    
    if myTeam == -1 then
        return true
    end
    
    if npcTeam == -1 then
        return true
    end
    
    return myTeam ~= npcTeam
end

local function hasLineOfSightAim(targetPart)
    if not AimbotConfig.wallCheck then return true end
    
    local character = LocalPlayer.Character
    if not character then return false end
    local head = character:FindFirstChild("Head")
    if not head then return false end
    
    local startPosition = head.Position
    local targetPosition = targetPart.Position
    local direction = (targetPosition - startPosition).Unit
    local distance = (targetPosition - startPosition).Magnitude
    
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
    raycastParams.IgnoreWater = true
    
    local filterList = {}
    
    for _, player in pairs(Players:GetPlayers()) do
        if player.Character then
            table.insert(filterList, player.Character)
        end
    end
    
    local mobFolder = workspace:FindFirstChild("Mobs")
    if mobFolder then
        for _, mob in pairs(mobFolder:GetChildren()) do
            if mob:IsA("Model") and mob:FindFirstChildOfClass("Humanoid") then
                table.insert(filterList, mob)
            end
        end
    end
    
    raycastParams.FilterDescendantsInstances = filterList
    
    local rayDirection = direction * (distance - 2)
    local raycastResult = workspace:Raycast(startPosition, rayDirection, raycastParams)
    
    return raycastResult == nil
end

local function isInFOVAim(targetPart)
    local screenPos, onScreen = Camera:WorldToScreenPoint(targetPart.Position)
    if not onScreen then return false end
    
    local mousePos = Vector2.new(Mouse.X, Mouse.Y)
    local targetPos = Vector2.new(screenPos.X, screenPos.Y)
    local distance = (mousePos - targetPos).Magnitude
    
    return distance <= AimbotConfig.fovSize
end

local function isLockedTargetValid()
    if not lockedTarget or not lockedTarget.Parent then 
        return false 
    end
    
    if not lockedTarget.Parent.Parent then
        return false
    end
    
    local player = Players:GetPlayerFromCharacter(lockedTarget.Parent)
    if player then
        if not player.Character then return false end
        if not player.Character:FindFirstChild(AimbotConfig.aimPart) then return false end
        if not isEnemyForAim(player) then return false end
        
        local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
        if not humanoid or humanoid.Health <= 0 then return false end
    else
        if not isEnemyNPCForAim(lockedTarget.Parent) then return false end
        
        local humanoid = lockedTarget.Parent:FindFirstChildOfClass("Humanoid")
        if not humanoid or humanoid.Health <= 0 then return false end
    end
    
    local myChar = LocalPlayer.Character
    local myHRP = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not myHRP then return false end
    
    local dist = (myHRP.Position - lockedTarget.Position).Magnitude
    if dist > (AimbotConfig.maxDistance + 100) then return false end
    
    if tick() % 0.2 < 0.033 then
        if not hasLineOfSightAim(lockedTarget) then 
            return false 
        end
    end
    
    return true
end

local function findNewTarget()
    if isLocked then return nil end
    
    local myChar = LocalPlayer.Character
    local myHRP = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not myHRP then return nil end

    for _, player in pairs(Players:GetPlayers()) do
        if isEnemyForAim(player) then
            local part = player.Character and player.Character:FindFirstChild(AimbotConfig.aimPart)
            if part then
                local dist = (myHRP.Position - part.Position).Magnitude
                if dist <= AimbotConfig.maxDistance then
                    if isInFOVAim(part) and hasLineOfSightAim(part) then
                        return part
                    end
                end
            end
        end
    end

    local mobFolder = workspace:FindFirstChild("Mobs")
    if mobFolder then
        for _, mob in pairs(mobFolder:GetChildren()) do
            if isEnemyNPCForAim(mob) then
                local part = mob:FindFirstChild(AimbotConfig.aimPart) or mob:FindFirstChild("HumanoidRootPart")
                if part then
                    local dist = (myHRP.Position - part.Position).Magnitude
                    if dist <= AimbotConfig.maxDistance then
                        if isInFOVAim(part) and hasLineOfSightAim(part) then
                            return part
                        end
                    end
                end
            end
        end
    end

    return nil
end

local function unlockTarget()
    lockedTarget = nil
    isLocked = false
end

local aimbotConnection
local function enableAimbot()
    if aimbotConnection then
        aimbotConnection:Disconnect()
    end
    
    aimbotConnection = RunService.RenderStepped:Connect(function()
        autoAimFOV.Position = Vector2.new(Mouse.X, Mouse.Y)
        autoAimFOV.Radius = AimbotConfig.fovSize
        autoAimFOV.Visible = AimbotConfig.showFOV and AimbotConfig.enabled
        
        if not AimbotConfig.enabled then
            return
        end
        
        if isLocked and lockedTarget then
            if not isLockedTargetValid() then
                unlockTarget()
            end
        end
        
        if not isLocked then
            local newTarget = findNewTarget()
            if newTarget then
                lockedTarget = newTarget
                isLocked = true
            end
        end
        
        if isLocked and lockedTarget then
            local camPos = Camera.CFrame.Position
            local direction = (lockedTarget.Position - camPos).Unit
            local goalCFrame = CFrame.new(camPos, camPos + direction)

            local smoothFactor = math.clamp(1 / AimbotConfig.smoothing, 0, 1)
            Camera.CFrame = Camera.CFrame:Lerp(goalCFrame, smoothFactor)
        end
    end)
end

local function disableAimbot()
    if aimbotConnection then
        aimbotConnection:Disconnect()
        aimbotConnection = nil
    end
    autoAimFOV.Visible = false
    unlockTarget()
end

local HitboxConfig = {
    enabled = false,
    headSize = 10,
    applyToPlayers = true,
    applyToNPCs = true,
    onlyEnemies = true
}

local modifiedParts = {}
local originalProperties = {}
local connections = {}
local monitoredNPCs = {}

local function getNPCLocations()
    local locations = {}
    
    local mobsInWorkspace = Workspace:FindFirstChild("Mobs")
    if mobsInWorkspace then table.insert(locations, mobsInWorkspace) end
    
    local botsInReplicatedStorage = ReplicatedStorage:FindFirstChild("Bots")
    if botsInReplicatedStorage then table.insert(locations, botsInReplicatedStorage) end
    
    local mobsInReplicatedStorage = ReplicatedStorage:FindFirstChild("Mobs")
    if mobsInReplicatedStorage then table.insert(locations, mobsInReplicatedStorage) end
    
    return locations
end

local function isEnemy(entity)
    if not entity then return false end
    
    local localTeam = getTeam(LocalPlayer)
    local entityTeam = getTeam(entity)
    
    if localTeam == -1 then return true end
    if entityTeam == -1 then return true end
    
    return localTeam ~= entityTeam
end

local function applyHitboxProperties(part, entity)
    if not part or modifiedParts[part] or not HitboxConfig.enabled then return end
    if HitboxConfig.onlyEnemies and not isEnemy(entity) then return end
    
    originalProperties[part] = {
        Size = part.Size,
        Transparency = part.Transparency,
        BrickColor = part.BrickColor,
        Material = part.Material,
        CanCollide = part.CanCollide,
        Shape = part.Shape
    }
    
    pcall(function()
        part.Size = Vector3.new(HitboxConfig.headSize, HitboxConfig.headSize, HitboxConfig.headSize)
        part.Shape = Enum.PartType.Block
        part.Transparency = 0.5
        part.BrickColor = BrickColor.new("Really red")
        part.Material = Enum.Material.ForceField
        part.CanCollide = false
        
        local mesh = part:FindFirstChild("HitboxMesh")
        if not mesh then
            mesh = Instance.new("SpecialMesh")
            mesh.Name = "HitboxMesh"
            mesh.Parent = part
        end
        mesh.MeshType = Enum.MeshType.Head
        mesh.Scale = Vector3.new(1, 1, 1)
        
        modifiedParts[part] = true
    end)
end

local function restoreOriginalProperties(part)
    if not part or not originalProperties[part] then return end
    
    local original = originalProperties[part]
    pcall(function()
        part.Size = original.Size
        part.Transparency = original.Transparency
        part.BrickColor = original.BrickColor
        part.Material = original.Material
        part.CanCollide = original.CanCollide
        part.Shape = original.Shape
        
        local mesh = part:FindFirstChild("HitboxMesh")
        if mesh then mesh:Destroy() end
    end)
    
    modifiedParts[part] = nil
    originalProperties[part] = nil
end

local function cleanupPart(part)
    if connections[part] then
        pcall(function()
            connections[part]:Disconnect()
        end)
        connections[part] = nil
    end
    restoreOriginalProperties(part)
end

local function processCharacter(character, entity)
    if not character or not character:IsA("Model") then return end
    
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    
    if HitboxConfig.enabled then
        if entity:IsA("Player") and HitboxConfig.applyToPlayers then
            applyHitboxProperties(hrp, entity)
        elseif isNPC(character) and HitboxConfig.applyToNPCs then
            applyHitboxProperties(hrp, character)
        end
    end
    
    if not connections[hrp] then
        connections[hrp] = hrp.AncestryChanged:Connect(function()
            if not hrp.Parent then
                cleanupPart(hrp)
            end
        end)
    end
end

local function monitorPlayer(player)
    if player == LocalPlayer then return end
    
    local function onCharacterAdded(character)
        task.wait(0.5)
        processCharacter(character, player)
    end
    
    if player.Character then
        onCharacterAdded(player.Character)
    end
    
    player.CharacterAdded:Connect(onCharacterAdded)
    player.CharacterRemoving:Connect(function(character)
        local hrp = character:FindFirstChild("HumanoidRootPart")
        if hrp then cleanupPart(hrp) end
    end)
end

local function monitorNPC(npc)
    if not isNPC(npc) or monitoredNPCs[npc] then return end
    
    monitoredNPCs[npc] = true
    
    local function checkAndApply()
        if HitboxConfig.enabled and HitboxConfig.applyToNPCs then
            processCharacter(npc, npc)
        end
    end
    
    checkAndApply()
    
    local connection = npc.AncestryChanged:Connect(function()
        if not npc.Parent then
            monitoredNPCs[npc] = nil
            local hrp = npc:FindFirstChild("HumanoidRootPart")
            if hrp then cleanupPart(hrp) end
            pcall(function()
                connection:Disconnect()
            end)
        end
    end)
end

local function scanForNPCs()
    if not ESPConfig.npcESP then return end
    
    local mobsFolder = Workspace:FindFirstChild("Mobs")
    if mobsFolder then
        for _, mob in pairs(mobsFolder:GetChildren()) do
            if mob:IsA("Model") and isNPC(mob) and not NPCObjects[mob] then
                createNPCESP(mob)
            end
        end
    end
    
    for _, obj in pairs(Workspace:GetDescendants()) do
        if obj:IsA("Model") and isNPC(obj) and not NPCObjects[obj] then
            createNPCESP(obj)
        end
    end
end

local function enableHitbox()
    HitboxConfig.enabled = true
    
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            processCharacter(player.Character, player)
        end
    end
    
    scanForNPCs()
end

local function disableHitbox()
    HitboxConfig.enabled = false
    
    for part, _ in pairs(modifiedParts) do
        cleanupPart(part)
    end
end

local function refreshHitbox()
    if not HitboxConfig.enabled then return end
    
    disableHitbox()
    task.wait(0.1)
    enableHitbox()
end

local function setupHitboxConnections()
    for _, player in pairs(Players:GetPlayers()) do
        monitorPlayer(player)
    end
    
    Players.PlayerAdded:Connect(monitorPlayer)
    Players.PlayerRemoving:Connect(function(player)
        if player.Character then
            local hrp = player.Character:FindFirstChild("HumanoidRootPart")
            if hrp then cleanupPart(hrp) end
        end
    end)
    
    local locations = getNPCLocations()
    for _, location in pairs(locations) do
        if location then
            location.ChildAdded:Connect(function(child)
                if child:IsA("Model") then
                    task.wait(0.5)
                    if isNPC(child) then
                        monitorNPC(child)
                    end
                end
            end)
        end
    end
    
    task.spawn(function()
        while true do
            task.wait(3)
            if HitboxConfig.enabled then
                pcall(scanForNPCs)
            end
        end
    end)
    
    task.spawn(function()
        while true do
            task.wait(10)
            
            for part, _ in pairs(modifiedParts) do
                if not part.Parent then
                    cleanupPart(part)
                end
            end
            
            for npc, _ in pairs(monitoredNPCs) do
                if not npc.Parent then
                    monitoredNPCs[npc] = nil
                end
            end
        end
    end)
end

local MainTab = Window:CreateTab("Главное", 4483362458)
local VisualsTab = Window:CreateTab("Визуальная техника", 4483362458)
local TeleportTab = Window:CreateTab("Телепорт", 4483362458)
local AimbotTab = Window:CreateTab("Автоаимбот", 4483362458)

local MainSection = MainTab:CreateSection("Контроль за ЭСО")

local ESPToggle = MainTab:CreateToggle({
   Name = "Включить ЭСО",
   CurrentValue = true,
   Flag = "ESPToggle",
   Callback = function(Value)
       ESPConfig.enabled = Value
       if Value then
           enableESP()
       else
           disableESP()
       end
   end,
})

local ChamsToggle = MainTab:CreateToggle({
   Name = "Чамы",
   CurrentValue = true,
   Flag = "ChamsToggle",
   Callback = function(Value)
       ESPConfig.chams = Value
       for player, esp in pairs(ESPObjects) do
           if esp.objects.chams and esp.objects.chams.highlight then
               esp.objects.chams.highlight.Enabled = Value
           end
       end
       for character, esp in pairs(NPCObjects) do
           if esp.objects.chams and esp.objects.chams.highlight then
               esp.objects.chams.highlight.Enabled = Value
           end
       end
   end,
})

local TeammatesToggle = MainTab:CreateToggle({
   Name = "Показать товарищей по команде",
   CurrentValue = true,
   Flag = "TeammatesToggle",
   Callback = function(Value)
       ESPConfig.teammates = Value
       updateAllESPVisibility()
   end,
})

local EnemiesToggle = MainTab:CreateToggle({
   Name = "Показать враги",
   CurrentValue = true,
   Flag = "EnemiesToggle",
   Callback = function(Value)
       ESPConfig.enemies = Value
       updateAllESPVisibility()
   end,
})

local NPCToggle = MainTab:CreateToggle({
   Name = "ЭСП ВСНП",
   CurrentValue = true,
   Flag = "NPCToggle",
   Callback = function(Value)
       ESPConfig.npcESP = Value
       updateAllESPVisibility()
       if Value and ESPConfig.enabled then
           task.spawn(scanForNPCs)
       end
   end,
})

local NoCooldownButton = MainTab:CreateButton({
   Name = "Бесконечность",
   Callback = function()
       for _, v in next, getgc(true) do
           if typeof(v) == 'table' and rawget(v, 'CD') then
               rawset(v, 'CD', 0)
           end
       end
   end,
})

local EnableHitboxToggle = MainTab:CreateToggle({
    Name = "Включить Hitbox",
    CurrentValue = false,
    Flag = "EnableHitbox",
    Callback = function(Value)
        if Value then
            enableHitbox()
        else
            disableHitbox()
        end
    end,
})

local RefreshHitboxButton = MainTab:CreateButton({
    Name = "Обновить Hitbox",
    Callback = function()
        refreshHitbox()
        Rayfield:Notify({
            Title = "Модернизация Xitbox",
            Content = "Все хитбоксы были перезаряжены!",
            Duration = 2,
        })
    end,
})

local VisualsSection = VisualsTab:CreateSection("Визуальные элементы")

local NamesToggle = VisualsTab:CreateToggle({
   Name = "Имена",
   CurrentValue = true,
   Flag = "NamesToggle",
   Callback = function(Value)
       ESPConfig.names = Value
       for player, esp in pairs(ESPObjects) do
           if esp.objects.info and esp.objects.info.nameText then
               esp.objects.info.nameText.Visible = Value and ESPConfig.enabled
           end
       end
       for character, esp in pairs(NPCObjects) do
           if esp.objects.info and esp.objects.info.nameText then
               esp.objects.info.nameText.Visible = Value and ESPConfig.enabled and ESPConfig.npcESP
           end
       end
   end,
})

local HealthToggle = VisualsTab:CreateToggle({
   Name = "Здравоохранение",
   CurrentValue = true,
   Flag = "HealthToggle",
   Callback = function(Value)
       ESPConfig.health = Value
       for player, esp in pairs(ESPObjects) do
           if esp.objects.info then
               if esp.objects.info.healthText then
                   esp.objects.info.healthText.Visible = Value and ESPConfig.enabled
               end
               if esp.objects.info.healthBar then
                   if esp.objects.info.healthBar.bg then
                       esp.objects.info.healthBar.bg.Visible = Value and ESPConfig.enabled
                   end
                   if esp.objects.info.healthBar.bar then
                       esp.objects.info.healthBar.bar.Visible = Value and ESPConfig.enabled
                   end
               end
           end
       end
       for character, esp in pairs(NPCObjects) do
           if esp.objects.info then
               if esp.objects.info.healthText then
                   esp.objects.info.healthText.Visible = Value and ESPConfig.enabled and ESPConfig.npcESP
               end
               if esp.objects.info.healthBar then
                   if esp.objects.info.healthBar.bg then
                       esp.objects.info.healthBar.bg.Visible = Value and ESPConfig.enabled and ESPConfig.npcESP
                   end
                   if esp.objects.info.healthBar.bar then
                       esp.objects.info.healthBar.bar.Visible = Value and ESPConfig.enabled and ESPConfig.npcESP
                   end
               end
           end
       end
   end,
})

local DistanceToggle = VisualsTab:CreateToggle({
   Name = "Расстояние",
   CurrentValue = true,
   Flag = "DistanceToggle",
   Callback = function(Value)
       ESPConfig.distance = Value
       for player, esp in pairs(ESPObjects) do
           if esp.objects.info and esp.objects.info.distanceText then
               esp.objects.info.distanceText.Visible = Value and ESPConfig.enabled
           end
       end
       for character, esp in pairs(NPCObjects) do
           if esp.objects.info and esp.objects.info.distanceText then
               esp.objects.info.distanceText.Visible = Value and ESPConfig.enabled and ESPConfig.npcESP
           end
       end
   end,
})

local TextSizeSlider = VisualsTab:CreateSlider({
   Name = "Размер текста",
   Range = {10, 24},
   Increment = 1,
   CurrentValue = 16,
   Flag = "TextSize",
   Callback = function(Value)
       ESPConfig.textSize = Value
       for player, esp in pairs(ESPObjects) do
           if esp.objects.info then
               if esp.objects.info.nameText then
                   esp.objects.info.nameText.Size = Value
               end
               if esp.objects.info.distanceText then
                   esp.objects.info.distanceText.Size = Value - 2
               end
               if esp.objects.info.healthText then
                   esp.objects.info.healthText.Size = Value - 2
               end
           end
       end
       for character, esp in pairs(NPCObjects) do
           if esp.objects.info then
               if esp.objects.info.nameText then
                   esp.objects.info.nameText.Size = Value
               end
               if esp.objects.info.distanceText then
                   esp.objects.info.distanceText.Size = Value - 2
               end
               if esp.objects.info.healthText then
                   esp.objects.info.healthText.Size = Value - 2
               end
           end
       end
   end,
})

local RenderDistanceSlider = VisualsTab:CreateSlider({
   Name = "Расстояние",
   Range = {100, 2000},
   Increment = 50,
   CurrentValue = 1000,
   Flag = "RenderDistance",
   Callback = function(Value)
       ESPConfig.renderDistance = Value
   end,
})

local TeleportSection = TeleportTab:CreateSection("Контроль за телепортацией")

local BringPlayersToggle = TeleportTab:CreateToggle({
   Name = "Приведите игроков",
   CurrentValue = false,
   Flag = "BringPlayersToggle",
   Callback = function(Value)
       TeleportConfig.bringPlayers = Value
       if Value then
           enableTeleportPlayers()
       else
           disableTeleportPlayers()
       end
   end,
})

local BringNPCsToggle = TeleportTab:CreateToggle({
   Name = "Приводим НПК",
   CurrentValue = false,
   Flag = "BringNPCsToggle",
   Callback = function(Value)
       TeleportConfig.bringNPCs = Value
       if Value then
           enableTeleportNPCs()
       else
           disableTeleportNPCs()
       end
   end,
})

local TeleportDistanceSlider = TeleportTab:CreateSlider({
   Name = "Расстояние между телепортами",
   Range = {1, 50},
   Increment = 1,
   CurrentValue = 7,
   Flag = "TeleportDistance",
   Callback = function(Value)
       TeleportConfig.teleportDistance = Value
   end,
})

local AimbotSection = AimbotTab:CreateSection("Параметры Auto Aimbot")

local AutoAimToggle = AimbotTab:CreateToggle({
   Name = "Автоаимбот",
   CurrentValue = false,
   Flag = "AutoAimToggle",
   Callback = function(Value)
       AimbotConfig.enabled = Value
       if Value then
           enableAimbot()
       else
           disableAimbot()
       end
   end,
})

local AutoAimFOVToggle = AimbotTab:CreateToggle({
   Name = "Показать круг FOV",
   CurrentValue = false,
   Flag = "AutoAimFOVToggle",
   Callback = function(Value)
       AimbotConfig.showFOV = Value
   end,
})

local AutoAimFOVSlider = AimbotTab:CreateSlider({
   Name = "Размер FOV",
   Range = {10, 500},
   Increment = 5,
   CurrentValue = 90,
   Flag = "AutoAimFOV",
   Callback = function(Value)
       AimbotConfig.fovSize = Value
   end,
})

local AutoAimSmoothingSlider = AimbotTab:CreateSlider({
   Name = "Цель",
   Range = {0.1, 10},
   Increment = 0.1,
   CurrentValue = 1,
   Flag = "AutoAimSmoothing",
   Callback = function(Value)
       AimbotConfig.smoothing = Value
   end,
})

local AutoAimDistanceSlider = AimbotTab:CreateSlider({
   Name = "Максимальная дистанция",
   Range = {50, 1000},
   Increment = 10,
   CurrentValue = 300,
   Flag = "AutoAimDistance",
   Callback = function(Value)
       AimbotConfig.maxDistance = Value
   end,
})

local AutoAimWallCheckToggle = AimbotTab:CreateToggle({
   Name = "Проверка на стене",
   CurrentValue = true,
   Flag = "AutoAimWallCheck",
   Callback = function(Value)
       AimbotConfig.wallCheck = Value
   end,
})

local AimPartDropdown = AimbotTab:CreateDropdown({
   Name = "Цель",
   Options = {"Head", "HumanoidRootPart"},
   CurrentOption = "Head",
   Flag = "AimPart",
   Callback = function(Option)
       AimbotConfig.aimPart = Option
       unlockTarget()
   end,
})

local UnlockTargetButton = AimbotTab:CreateButton({
   Name = "Разблокировать цель",
   Callback = function()
       unlockTarget()
   end,
})

local TargetStatusSection = AimbotTab:CreateSection("Целевое состояние")
local targetStatusLabel = AimbotTab:CreateLabel("Target: None")

local statusUpdateConnection
statusUpdateConnection = RunService.Heartbeat:Connect(function()
    if isLocked and lockedTarget then
        local targetName = "Неизвестно"
        local player = Players:GetPlayerFromCharacter(lockedTarget.Parent)
        if player then
            targetName = player.Name
        else
            targetName = lockedTarget.Parent.Name or "NPC"
        end
        targetStatusLabel:Set("Target: " .. targetName .. " (LOCKED)")
    else
        targetStatusLabel:Set("Target: None")
    end
end)

enableAimbot()
setupEventConnections()
setupHitboxConnections()
enableESP()

game:BindToClose(function()
    disableESP()
    disableTeleportPlayers()
    disableTeleportNPCs()
    disableAimbot()
    disableHitbox()
    if statusUpdateConnection then
        statusUpdateConnection:Disconnect()
    end
    pcall(function() autoAimFOV:Remove() end)
    for _, connection in pairs(Connections) do
        if connection then
            if typeof(connection) == "RBXScriptConnection" then
                pcall(function() connection:Disconnect() end)
            elseif typeof(connection) == "thread" then
                pcall(function() task.cancel(connection) end)
            end
        end
    end
    for _, connection in pairs(connections) do
        if connection then
            pcall(function()
                connection:Disconnect()
            end)
        end
    end
    modifiedParts = {}
    originalProperties = {}
    connections = {}
    monitoredNPCs = {}
    forceCleanupDrawingObjects()
end)

Players.PlayerRemoving:Connect(function(player)
    if player == LocalPlayer then
        disableESP()
        disableTeleportPlayers()
        disableTeleportNPCs()
        disableAimbot()
        disableHitbox()
    end
end)

_G.ESP_SYSTEM = {
    enable = enableESP,
    disable = disableESP,
    config = ESPConfig,
    removePlayer = removeESP,
    addPlayer = createESP,
    removeNPC = removeNPCESP,
    addNPC = createNPCESP,
    scanNPCs = scanForNPCs,
    updateVisibility = updateAllESPVisibility,
    forceCleanup = forceCleanupDrawingObjects,
    isTeammate = isTeammate,
    isMobTeammate = isMobTeammate,
    isNPC = isNPC,
    cleanup = cleanupDrawingObjects,
    objects = {
        players = ESPObjects,
        npcs = NPCObjects,
        drawings = DrawingObjects
    }
}

_G.TELEPORT_SYSTEM = {
    config = TeleportConfig,
    enablePlayers = enableTeleportPlayers,
    disablePlayers = disableTeleportPlayers,
    enableNPCs = enableTeleportNPCs,
    disableNPCs = disableTeleportNPCs
}

_G.AIMBOT_SYSTEM = {
    enable = enableAimbot,
    disable = disableAimbot,
    config = AimbotConfig,
    unlockTarget = unlockTarget
}

_G.HITBOX_SYSTEM = {
    enable = enableHitbox,
    disable = disableHitbox,
    refresh = refreshHitbox,
    config = HitboxConfig
}

task.spawn(function()
    while true do
        task.wait(10)
        
        pcall(function()
            local playerCount = 0
            for _ in pairs(ESPObjects) do
                playerCount = playerCount + 1
            end
            
            local npcCount = 0
            for _ in pairs(NPCObjects) do
                npcCount = npcCount + 1
            end
            
            local drawingCount = #DrawingObjects
            
            if drawingCount > MAX_OBJECTS * 0.8 then
                cleanupDrawingObjects()
            end
            
            for i = #DrawingObjects, 1, -1 do
                local obj = DrawingObjects[i]
                if not obj or not pcall(function() return obj.Visible end) then
                    table.remove(DrawingObjects, i)
                end
            end
        end)
    end
end)

Rayfield:Notify({
   Title = "ESP, Aimbot и Hitbox Загружены",
   Content = "В настоящее время активированы усовершенствованные ЭСО, мишени и хитбокс-сист...",
   Duration = 3,
   Image = "eye"
})
