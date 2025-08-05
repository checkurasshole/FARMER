local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
-- GUI Setup
local Window = Rayfield:CreateWindow({
    Name = "COMBO_WICK | قتال بالأسلحة ...",
    Icon = 12345678901, --  diamond icon ID? 
    LoadingTitle = "إنزال",
    LoadingSubtitle = "By COMBO_WICK | Bang.E.Line",
    Theme = "Ocean"
})


local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Teams = game:GetService("Teams")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

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
    
    teammateColor = Color3.fromRGB(0, 255, 0),  -- Green for teammates
    enemyColor = Color3.fromRGB(255, 0, 0),     -- Red for enemies
    npcColor = Color3.fromRGB(255, 255, 0),     -- Yellow for NPCs
    healthBarColor = Color3.fromRGB(0, 255, 0),
    
    textSize = 16,
    textColor = Color3.fromRGB(255, 255, 255),
    textOutline = true,
    
    updateRate = 60,
    renderDistance = 1000
}

-- AIMBOT CONFIG
local AimbotConfig = {
    -- Auto Aimbot Config
    autoAim = {
        enabled = false,
        aimPart = "Head",
        fovSize = 90,
        smoothing = 1,
        maxDistance = 300,
        wallCheck = true,
        showFOV = false
    },
    
    -- Mouse Aimbot Config
    mouseAim = {
        enabled = false,
        aimPart = "Head",
        fovSize = 150,
        smoothing = 1,
        maxDistance = 300,
        wallCheck = true,
        showFOV = false,
        holdingRightClick = false
    },
    
    mobFolder = "Mobs"
}

-- HITBOX CONFIG
local HitboxConfig = {
    enabled = true,
    headSize = 10
}

-- TELEPORT CONFIG
local TeleportConfig = {
    bringPlayers = false,
    bringNPCs = false,
    teleportDistance = 7
}

local ESPObjects = {}
local NPCObjects = {}
local Connections = {}
local DrawingObjects = {}
local modifiedParts = {}
local originalProperties = {}

local MAX_OBJECTS = 500
local CLEANUP_INTERVAL = 15
local lastCleanup = tick()

-- AIMBOT FOV CIRCLES
local autoAimFOV = Drawing.new("Circle")
autoAimFOV.Thickness = 2
autoAimFOV.NumSides = 50
autoAimFOV.Color = Color3.fromRGB(255, 255, 255)
autoAimFOV.Transparency = 0.8
autoAimFOV.Filled = false
autoAimFOV.Visible = false

local mouseAimFOV = Drawing.new("Circle")
mouseAimFOV.Thickness = 2
mouseAimFOV.NumSides = 50
mouseAimFOV.Color = Color3.fromRGB(0, 255, 255)
mouseAimFOV.Transparency = 0.8
mouseAimFOV.Filled = false
mouseAimFOV.Visible = false

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

-- HITBOX FUNCTIONS
local function applyPropertiesToPart(part)
    if part and not modifiedParts[part] then
        -- Store original properties
        originalProperties[part] = {
            Size = part.Size,
            Transparency = part.Transparency,
            BrickColor = part.BrickColor,
            Material = part.Material,
            CanCollide = part.CanCollide,
            Shape = part.Shape
        }
        
        -- Apply new properties
        part.Size = Vector3.new(HitboxConfig.headSize * 0.8, HitboxConfig.headSize, HitboxConfig.headSize * 0.8)
        part.Shape = Enum.PartType.Block
        part.Transparency = 0.5
        part.BrickColor = BrickColor.new("Really red")
        part.Material = Enum.Material.ForceField
        part.CanCollide = false
        
        -- Add head mesh only if it doesn't exist
        if not part:FindFirstChild("HeadCorner") then
            local corner = Instance.new("SpecialMesh")
            corner.Name = "HeadCorner"
            corner.MeshType = Enum.MeshType.Head
            corner.Scale = Vector3.new(1, 1, 1)
            corner.Parent = part
        end
        
        modifiedParts[part] = true
        
        -- Clean up when part is destroyed
        part.AncestryChanged:Connect(function()
            if not part.Parent then
                modifiedParts[part] = nil
                originalProperties[part] = nil
            end
        end)
    end
end

local function restoreOriginalProperties(part)
    if part and originalProperties[part] then
        local original = originalProperties[part]
        part.Size = original.Size
        part.Transparency = original.Transparency
        part.BrickColor = original.BrickColor
        part.Material = original.Material
        part.CanCollide = original.CanCollide
        part.Shape = original.Shape
        
        -- Remove head mesh
        local mesh = part:FindFirstChild("HeadCorner")
        if mesh then mesh:Destroy() end
        
        modifiedParts[part] = nil
        originalProperties[part] = nil
    end
end

-- AIMBOT FUNCTIONS
local function getTeam(player)
    return player:GetAttribute("Team") or -1
end

local function isEnemyForAim(player)
    if player == LocalPlayer then return false end
    if not player.Character or not player.Character:FindFirstChild(AimbotConfig.autoAim.aimPart) then return false end

    local myTeam = getTeam(LocalPlayer)
    local otherTeam = getTeam(player)

    -- If I'm in FFA (-1), everyone else is an enemy
    if myTeam == -1 then
        return true
    end
    
    -- If they're in FFA (-1), they're an enemy
    if otherTeam == -1 then
        return true
    end
    
    -- Both have teams, check if different
    return myTeam ~= otherTeam
end

local function isEnemyNPCForAim(model)
    if not model:IsA("Model") then return false end
    local part = model:FindFirstChild(AimbotConfig.autoAim.aimPart) or model:FindFirstChild("HumanoidRootPart")
    if not part then return false end
    local humanoid = model:FindFirstChildOfClass("Humanoid")
    if humanoid and humanoid.Health <= 0 then return false end
    
    local myTeam = getTeam(LocalPlayer)
    local npcTeam = model:GetAttribute("Team") or -1
    
    -- If I'm in FFA (-1), all NPCs are enemies
    if myTeam == -1 then
        return true
    end
    
    -- If NPC is in FFA (-1), it's an enemy
    if npcTeam == -1 then
        return true
    end
    
    -- Both have teams, check if different
    return myTeam ~= npcTeam
end

local function hasLineOfSightAim(targetPart, config)
    if not config.wallCheck then return true end
    
    local character = LocalPlayer.Character
    if not character then return false end
    local head = character:FindFirstChild("Head")
    if not head then return false end
    
    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Blacklist
    rayParams.FilterDescendantsInstances = {character, targetPart.Parent}
    
    local direction = targetPart.Position - head.Position
    local result = workspace:Raycast(head.Position, direction, rayParams)
    
    return result == nil
end

local function isInFOVAim(targetPart, config)
    local screenPos, onScreen = Camera:WorldToScreenPoint(targetPart.Position)
    if not onScreen then return false end
    
    local mousePos = Vector2.new(Mouse.X, Mouse.Y)
    local targetPos = Vector2.new(screenPos.X, screenPos.Y)
    local distance = (mousePos - targetPos).Magnitude
    
    return distance <= config.fovSize
end

local function getClosestTargetAim(config)
    local myChar = LocalPlayer.Character
    local myHRP = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not myHRP then return nil end

    local closest, shortest = nil, math.huge

    -- Players
    for _, player in ipairs(Players:GetPlayers()) do
        if isEnemyForAim(player) then
            local part = player.Character and player.Character:FindFirstChild(config.aimPart)
            if part then
                local dist = (myHRP.Position - part.Position).Magnitude
                if dist <= config.maxDistance and dist < shortest then
                    if isInFOVAim(part, config) and hasLineOfSightAim(part, config) then
                        closest = part
                        shortest = dist
                    end
                end
            end
        end
    end

    -- NPCs
    local mobFolder = workspace:FindFirstChild(AimbotConfig.mobFolder)
    if mobFolder then
        for _, mob in ipairs(mobFolder:GetChildren()) do
            if isEnemyNPCForAim(mob) then
                local part = mob:FindFirstChild(config.aimPart) or mob:FindFirstChild("HumanoidRootPart")
                if part then
                    local dist = (myHRP.Position - part.Position).Magnitude
                    if dist <= config.maxDistance and dist < shortest then
                        if isInFOVAim(part, config) and hasLineOfSightAim(part, config) then
                            closest = part
                            shortest = dist
                        end
                    end
                end
            end
        end
    end

    return closest
end

-- FIXED: Proper team detection using Team attribute
local function isTeammate(player)
    if not player or player == LocalPlayer then return false end
    
    -- Get Team attribute from both players
    local localTeam = LocalPlayer:GetAttribute("Team")
    local playerTeam = player:GetAttribute("Team")
    
    -- If either player doesn't have a Team attribute, they're not teammates
    if not localTeam or not playerTeam then return false end
    
    -- Free for all mode (Team value -1)
    if localTeam == -1 or playerTeam == -1 then return false end
    
    -- Same team if Team values match and aren't -1
    return localTeam == playerTeam
end

local function getPlayerColor(player, isNPC)
    if isNPC then
        return ESPConfig.npcColor
    end
    
    if isTeammate(player) then
        return ESPConfig.teammateColor -- Green for teammates
    else
        return ESPConfig.enemyColor    -- Red for enemies
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
    
    -- Check if it's in workspace.Mobs (main way to identify mobs)
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

-- NEW: Function to check if a mob/NPC is a teammate
local function isMobTeammate(character)
    if not character then return false end
    
    -- Get Team attribute from both local player and mob
    local localTeam = LocalPlayer:GetAttribute("Team")
    local mobTeam = character:GetAttribute("Team")
    
    -- If either doesn't have a Team attribute, they're not teammates
    if not localTeam or not mobTeam then return false end
    
    -- Free for all mode (Team value -1)
    if localTeam == -1 or mobTeam == -1 then return false end
    
    -- Same team if Team values match and aren't -1
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

-- NEW: Function to update visibility of ESP elements immediately
local function updateESPVisibility(esp, isNPC, character)
    if not esp or not esp.objects then return end
    
    local shouldShow = true
    
    if isNPC then
        -- For NPCs, check if NPC ESP is enabled
        if not ESPConfig.npcESP then
            shouldShow = false
        else
            -- Check team settings for NPCs
            local isMobTeam = isMobTeammate(character)
            if isMobTeam and not ESPConfig.teammates then
                shouldShow = false
            elseif not isMobTeam and not ESPConfig.enemies then
                shouldShow = false
            end
        end
    else
        -- For players, check team settings
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
    
    -- Update chams visibility
    if esp.objects.chams and esp.objects.chams.highlight then
        esp.objects.chams.highlight.Enabled = shouldShow and ESPConfig.chams
    end
    
    -- Update text elements visibility
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

-- NEW: Function to update all ESP visibility immediately
local function updateAllESPVisibility()
    -- Update player ESP
    for player, esp in pairs(ESPObjects) do
        updateESPVisibility(esp, false, nil)
    end
    
    -- Update NPC ESP
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
        
        -- Check if we should show this ESP based on current settings
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
            displayName = "شركة ناشونال بروجيكتس أند ك..."
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
        -- For mobs, check team and color accordingly
        local color = getPlayerColor(character, true)  -- Pass character for mob team check
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
    
    -- Update visibility immediately based on current settings
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
    
    -- Update visibility immediately based on current settings
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
    
    -- Scan workspace.Mobs specifically
    local mobsFolder = Workspace:FindFirstChild("Mobs")
    if mobsFolder then
        for _, mob in pairs(mobsFolder:GetChildren()) do
            if mob:IsA("Model") and isNPC(mob) and not NPCObjects[mob] then
                createNPCESP(mob)
            end
        end
    end
    
    -- Also scan other areas for NPCs (backup)
    for _, obj in pairs(Workspace:GetDescendants()) do
        if obj:IsA("Model") and isNPC(obj) and not NPCObjects[obj] then
            createNPCESP(obj)
        end
    end
end

local function enableESP()
    ESPConfig.enabled = true
    
    -- Create new ESP
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

local function enableHitbox()
    HitboxConfig.enabled = true
    
    -- Apply hitbox to existing players
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            if isEnemyForAim(player) then
                pcall(function()
                    applyPropertiesToPart(player.Character.HumanoidRootPart)
                end)
            end
        end
    end

    -- Apply hitbox to existing NPCs
    local mobsFolder = Workspace:FindFirstChild("Mobs")
    if mobsFolder then
        for _, mob in ipairs(mobsFolder:GetChildren()) do
            if mob:IsA("Model") and mob:FindFirstChild("HumanoidRootPart") then
                if isEnemyNPCForAim(mob) then
                    pcall(function()
                        applyPropertiesToPart(mob.HumanoidRootPart)
                    end)
                end
            end
        end
    end
end

local function disableHitbox()
    HitboxConfig.enabled = false
    
    for part, _ in pairs(modifiedParts) do
        pcall(function()
            restoreOriginalProperties(part)
        end)
    end
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
    -- Clear existing connections first
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
    
    -- Enhanced player added handling
    Connections.playerAdded = Players.PlayerAdded:Connect(function(player)
        local function onCharacterAdded(character)
            if ESPConfig.enabled then
                task.wait(1) -- Wait for character to fully load
                createESP(player)
            end
            if HitboxConfig.enabled and character:FindFirstChild("HumanoidRootPart") and isEnemyForAim(player) then
                pcall(function()
                    applyPropertiesToPart(character.HumanoidRootPart)
                end)
            end
        end
        
        -- Connect to current character if it exists
        if player.Character then
            onCharacterAdded(player.Character)
        end
        
        -- Connect to future characters
        player.CharacterAdded:Connect(onCharacterAdded)
        
        player.CharacterRemoving:Connect(function(character)
            removeESP(player)
            if character:FindFirstChild("HumanoidRootPart") then
                pcall(function()
                    restoreOriginalProperties(character.HumanoidRootPart)
                end)
            end
        end)
    end)
    
    Connections.playerRemoving = Players.PlayerRemoving:Connect(function(player)
        removeESP(player)
        if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            pcall(function()
                restoreOriginalProperties(player.Character.HumanoidRootPart)
            end)
        end
    end)
    
    -- Setup existing players
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local function onCharacterAdded(character)
                if ESPConfig.enabled then
                    task.wait(1)
                    createESP(player)
                end
                if HitboxConfig.enabled and character:FindFirstChild("HumanoidRootPart") and isEnemyForAim(player) then
                    pcall(function()
                        applyPropertiesToPart(character.HumanoidRootPart)
                    end)
                end
            end
            
            if player.Character then
                onCharacterAdded(player.Character)
            end
            
            player.CharacterAdded:Connect(onCharacterAdded)
            
            player.CharacterRemoving:Connect(function(character)
                removeESP(player)
                if character:FindFirstChild("HumanoidRootPart") then
                    pcall(function()
                        restoreOriginalProperties(character.HumanoidRootPart)
                    end)
                end
            end)
        end
    end
    
    -- Monitor workspace.Mobs specifically
    local mobsFolder = Workspace:FindFirstChild("Mobs")
    if mobsFolder then
        Connections.mobsChildAdded = mobsFolder.ChildAdded:Connect(function(child)
            if ESPConfig.enabled and ESPConfig.npcESP and child:IsA("Model") then
                task.wait(0.5)
                if child.Parent and isNPC(child) then
                    createNPCESP(child)
                end
            end
            if HitboxConfig.enabled and child:IsA("Model") and child:FindFirstChild("HumanoidRootPart") and isEnemyNPCForAim(child) then
                pcall(function()
                    applyPropertiesToPart(child.HumanoidRootPart)
                end)
            end
        end)
        
        Connections.mobsChildRemoved = mobsFolder.ChildRemoved:Connect(function(child)
            if NPCObjects[child] then
                removeNPCESP(child)
            end
            if child:FindFirstChild("HumanoidRootPart") then
                pcall(function()
                    restoreOriginalProperties(child.HumanoidRootPart)
                end)
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
        if HitboxConfig.enabled and child:IsA("Model") and child:FindFirstChild("HumanoidRootPart") and isEnemyNPCForAim(child) then
            pcall(function()
                applyPropertiesToPart(child.HumanoidRootPart)
            end)
        end
    end)
    
    Connections.descendantAdded = Workspace.DescendantAdded:Connect(function(descendant)
        if ESPConfig.enabled and ESPConfig.npcESP and descendant:IsA("Model") then
            task.wait(0.5)
            if descendant.Parent and isNPC(descendant) then
                createNPCESP(descendant)
            end
        end
        if HitboxConfig.enabled and descendant:IsA("Model") and descendant:FindFirstChild("HumanoidRootPart") and isEnemyNPCForAim(descendant) then
            pcall(function()
                applyPropertiesToPart(descendant.HumanoidRootPart)
            end)
        end
    end)
    
    Connections.childRemoved = Workspace.ChildRemoved:Connect(function(child)
        if NPCObjects[child] then
            removeNPCESP(child)
        end
        if child:FindFirstChild("HumanoidRootPart") then
            pcall(function()
                restoreOriginalProperties(child.HumanoidRootPart)
            end)
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
    
    Connections.hitboxUpdate = RunService.RenderStepped:Connect(function()
        if HitboxConfig.enabled then
            -- Players
            for _, player in ipairs(Players:GetPlayers()) do
                if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                    if isEnemyForAim(player) then
                        pcall(function()
                            applyPropertiesToPart(player.Character.HumanoidRootPart)
                        end)
                    end
                end
            end

            -- NPCs/Mobs
            local mobsFolder = Workspace:FindFirstChild("Mobs")
            if mobsFolder then
                for _, mob in ipairs(mobsFolder:GetChildren()) do
                    if mob:IsA("Model") and mob:FindFirstChild("HumanoidRootPart") then
                        if isEnemyNPCForAim(mob) then
                            pcall(function()
                                applyPropertiesToPart(mob.HumanoidRootPart)
                            end)
                        end
                    end
                end
            end
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
    
    -- AIMBOT MAIN LOOP
    Connections.aimbot = RunService.RenderStepped:Connect(function()
        -- Update FOV Circles
        autoAimFOV.Position = Vector2.new(Mouse.X, Mouse.Y)
        autoAimFOV.Radius = AimbotConfig.autoAim.fovSize
        autoAimFOV.Visible = AimbotConfig.autoAim.showFOV
        
        mouseAimFOV.Position = Vector2.new(Mouse.X, Mouse.Y)
        mouseAimFOV.Radius = AimbotConfig.mouseAim.fovSize
        mouseAimFOV.Visible = AimbotConfig.mouseAim.showFOV
        
        -- Auto Aim
        if AimbotConfig.autoAim.enabled then
            local target = getClosestTargetAim(AimbotConfig.autoAim)
            if target then
                local camPos = Camera.CFrame.Position
                local direction = (target.Position - camPos).Unit
                local goalCFrame = CFrame.new(camPos, camPos + direction)

                -- Smooth blend
                Camera.CFrame = Camera.CFrame:Lerp(goalCFrame, math.clamp(1 / AimbotConfig.autoAim.smoothing, 0, 1))
            end
        end
        
        -- Mouse Aimbot
        if AimbotConfig.mouseAim.enabled and AimbotConfig.mouseAim.holdingRightClick then
            local target = getClosestTargetAim(AimbotConfig.mouseAim)
            if target then
                local camPos = Camera.CFrame.Position
                local direction = (target.Position - camPos).Unit
                local targetCFrame = CFrame.new(camPos, camPos + direction)
                
                Camera.CFrame = Camera.CFrame:Lerp(targetCFrame, 1 / AimbotConfig.mouseAim.smoothing)
            end
        end
    end)
    
    -- AIMBOT INPUT EVENTS
    Connections.aimbotInput = UserInputService.InputBegan:Connect(function(input, gpe)
        if gpe then return end
        
        if input.UserInputType == Enum.UserInputType.MouseButton2 then
            AimbotConfig.mouseAim.holdingRightClick = true
        end
    end)
    
    Connections.aimbotInputEnd = UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton2 then
            AimbotConfig.mouseAim.holdingRightClick = false
        end
    end)
end
 

local MainTab = Window:CreateTab("الرئيسي", 4483362458)
local VisualsTab = Window:CreateTab("المواد المرئية", 4483362458)
local AimbotTab = Window:CreateTab("إيمبوت", 4483362458)
local TeleportTab = Window:CreateTab("النقل الفضائي", 4483362458)

local MainSection = MainTab:CreateSection("ضوابط المضخة الغاطسة الكهرب...")

local ESPToggle = MainTab:CreateToggle({
   Name = "تمكين ESP",
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
   Name = "التشام",
   CurrentValue = true,
   Flag = "ChamsToggle",
   Callback = function(Value)
       ESPConfig.chams = Value
       -- Immediately update all existing ESP chams
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
   Name = "عرض أعضاء الفريق",
   CurrentValue = true,
   Flag = "TeammatesToggle",
   Callback = function(Value)
       ESPConfig.teammates = Value
       -- Immediately update visibility for all ESP
       updateAllESPVisibility()
   end,
})

local EnemiesToggle = MainTab:CreateToggle({
   Name = "عرض الأعداء",
   CurrentValue = true,
   Flag = "EnemiesToggle",
   Callback = function(Value)
       ESPConfig.enemies = Value
       -- Immediately update visibility for all ESP
       updateAllESPVisibility()
   end,
})

local NPCToggle = MainTab:CreateToggle({
   Name = "NPC ESP",
   CurrentValue = true,
   Flag = "NPCToggle",
   Callback = function(Value)
       ESPConfig.npcESP = Value
       -- Immediately update visibility for all NPC ESP
       updateAllESPVisibility()
       -- If enabled and ESP is on, scan for new NPCs
       if Value and ESPConfig.enabled then
           task.spawn(scanForNPCs)
       end
   end,
})

local HitboxToggle = MainTab:CreateToggle({
   Name = "تمكين Hitbox",
   CurrentValue = true,
   Flag = "HitboxToggle",
   Callback = function(Value)
       HitboxConfig.enabled = Value
       if Value then
           enableHitbox()
       else
           disableHitbox()
       end
   end,
})

local HitboxSizeSlider = MainTab:CreateSlider({
   Name = "حجم الهيت بوكس",
   Range = {5, 50},
   Increment = 1,
   CurrentValue = 10,
   Flag = "HitboxSize",
   Callback = function(Value)
       HitboxConfig.headSize = Value
       if HitboxConfig.enabled then
           disableHitbox()
           enableHitbox()
       end
   end,
})

local NoCooldownButton = MainTab:CreateButton({
   Name = "القدرة اللانهائية",
   Callback = function()
       for _, v in next, getgc(true) do
           if typeof(v) == 'table' and rawget(v, 'CD') then
               rawset(v, 'CD', 0)
           end
       end
   end,
})

local VisualsSection = VisualsTab:CreateSection("العناصر المرئية (Visual Ele...")

local NamesToggle = VisualsTab:CreateToggle({
   Name = "الأسماء",
   CurrentValue = true,
   Flag = "NamesToggle",
   Callback = function(Value)
       ESPConfig.names = Value
       -- Immediately update visibility for all name text
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
   Name = "الصحة",
   CurrentValue = true,
   Flag = "HealthToggle",
   Callback = function(Value)
       ESPConfig.health = Value
       -- Immediately update visibility for all health elements
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
   Name = "المسافة",
   CurrentValue = true,
   Flag = "DistanceToggle",
   Callback = function(Value)
       ESPConfig.distance = Value
       -- Immediately update visibility for all distance text
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
   Name = "حجم النص",
   Range = {10, 24},
   Increment = 1,
   CurrentValue = 16,
   Flag = "TextSize",
   Callback = function(Value)
       ESPConfig.textSize = Value
       -- Immediately update text size for all ESP text elements
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
   Name = "مسافة التقديم",
   Range = {100, 2000},
   Increment = 50,
   CurrentValue = 1000,
   Flag = "RenderDistance",
   Callback = function(Value)
       ESPConfig.renderDistance = Value
   end,
})

local TeleportSection = TeleportTab:CreateSection("ضوابط النقل الفضائي")

local BringPlayersToggle = TeleportTab:CreateToggle({
   Name = "جلب اللاعبين",
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
   Name = "إحضار NPCs",
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
   Name = "مسافة الانتقال الآني",
   Range = {1, 50},
   Increment = 1,
   CurrentValue = 7,
   Flag = "TeleportDistance",
   Callback = function(Value)
       TeleportConfig.teleportDistance = Value
   end,
})

local AimbotSection = AimbotTab:CreateSection("إيمبوت تلقائي")

local AutoAimToggle = AimbotTab:CreateToggle({
   Name = "إيمبوت تلقائي",
   CurrentValue = false,
   Flag = "AutoAimToggle",
   Callback = function(Value)
       AimbotConfig.autoAim.enabled = Value
   end,
})

local AutoAimFOVToggle = AimbotTab:CreateToggle({
   Name = "دائرة FOV",
   CurrentValue = false,
   Flag = "AutoAimFOVToggle",
   Callback = function(Value)
       AimbotConfig.autoAim.showFOV = Value
   end,
})

local AutoAimFOVSlider = AimbotTab:CreateSlider({
   Name = "حجم FOV",
   Range = {10, 500},
   Increment = 5,
   CurrentValue = 90,
   Flag = "AutoAimFOV",
   Callback = function(Value)
       AimbotConfig.autoAim.fovSize = Value
   end,
})

local AutoAimSmoothingSlider = AimbotTab:CreateSlider({
   Name = "الهدف من التنعيم",
   Range = {1, 10},
   Increment = 0.1,
   CurrentValue = 1,
   Flag = "AutoAimSmoothing",
   Callback = function(Value)
       AimbotConfig.autoAim.smoothing = Value
   end,
})

local AutoAimDistanceSlider = AimbotTab:CreateSlider({
   Name = "مسافة الهدف",
   Range = {50, 1000},
   Increment = 10,
   CurrentValue = 300,
   Flag = "AutoAimDistance",
   Callback = function(Value)
       AimbotConfig.autoAim.maxDistance = Value
   end,
})

local AutoAimWallCheckToggle = AimbotTab:CreateToggle({
   Name = "التحقق من الحائط",
   CurrentValue = true,
   Flag = "AutoAimWallCheck",
   Callback = function(Value)
       AimbotConfig.autoAim.wallCheck = Value
   end,
})

local MouseAimbotSection = AimbotTab:CreateSection("Mouse Aimbot (اضغط بزر الما...")

local MouseAimToggle = AimbotTab:CreateToggle({
   Name = "إيمبوت الفأر",
   CurrentValue = false,
   Flag = "MouseAimToggle",
   Callback = function(Value)
       AimbotConfig.mouseAim.enabled = Value
   end,
})

local MouseAimFOVToggle = AimbotTab:CreateToggle({
   Name = "دائرة FOV",
   CurrentValue = false,
   Flag = "MouseAimFOVToggle",
   Callback = function(Value)
       AimbotConfig.mouseAim.showFOV = Value
   end,
})

local MouseAimFOVSlider = AimbotTab:CreateSlider({
   Name = "حجم FOV",
   Range = {10, 500},
   Increment = 5,
   CurrentValue = 150,
   Flag = "MouseAimFOV",
   Callback = function(Value)
       AimbotConfig.mouseAim.fovSize = Value
   end,
})

local MouseAimSmoothingSlider = AimbotTab:CreateSlider({
   Name = "تمهيد هدف الماوس",
   Range = {1, 10},
   Increment = 0.1,
   CurrentValue = 1,
   Flag = "MouseAimSmoothing",
   Callback = function(Value)
       AimbotConfig.mouseAim.smoothing = Value
   end,
})

local MouseAimDistanceSlider = AimbotTab:CreateSlider({
   Name = "مسافة تصويب الماوس",
   Range = {50, 1000},
   Increment = 10,
   CurrentValue = 300,
   Flag = "MouseAimDistance",
   Callback = function(Value)
       AimbotConfig.mouseAim.maxDistance = Value
   end,
})

local MouseAimWallCheckToggle = AimbotTab:CreateToggle({
   Name = "التحقق من الحائط",
   CurrentValue = true,
   Flag = "MouseAimWallCheck",
   Callback = function(Value)
       AimbotConfig.mouseAim.wallCheck = Value
   end,
})

local AimbotSettingsSection = AimbotTab:CreateSection("إعدادات Aimbot")

local AimPartDropdown = AimbotTab:CreateDropdown({
   Name = "جزء الهدف",
   Options = {"Head", "HumanoidRootPart"},
   CurrentOption = "Head",
   Flag = "AimPart",
   Callback = function(Option)
       AimbotConfig.autoAim.aimPart = Option
       AimbotConfig.mouseAim.aimPart = Option
   end,
})

-- Initialize the ESP system
setupEventConnections()
enableESP()
enableHitbox()

-- Enhanced game close handler
game:BindToClose(function()
    disableESP()
    disableHitbox()
    disableTeleportPlayers()
    disableTeleportNPCs()
    
    for _, connection in pairs(Connections) do
        if connection then
            if typeof(connection) == "RBXScriptConnection" then
                pcall(function() connection:Disconnect() end)
            elseif typeof(connection) == "thread" then
                pcall(function() task.cancel(connection) end)
            end
        end
    end
    
    forceCleanupDrawingObjects()
    
    -- Cleanup aimbot FOV circles
    pcall(function() autoAimFOV:Remove() end)
    pcall(function() mouseAimFOV:Remove() end)
end)

Players.PlayerRemoving:Connect(function(player)
    if player == LocalPlayer then
        disableESP()
        disableHitbox()
        disableTeleportPlayers()
        disableTeleportNPCs()
    end
end)

-- Global ESP system access
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

-- Global Aimbot system access
_G.AIMBOT_SYSTEM = {
    config = AimbotConfig,
    getClosestTarget = getClosestTargetAim,
    isEnemy = isEnemyForAim,
    isEnemyNPC = isEnemyNPCForAim,
    hasLineOfSight = hasLineOfSightAim,
    isInFOV = isInFOVAim
}

-- Global Hitbox system access
_G.HITBOX_SYSTEM = {
    config = HitboxConfig,
    enable = enableHitbox,
    disable = disableHitbox,
    applyProperties = applyPropertiesToPart,
    restoreProperties = restoreOriginalProperties
}

-- Global Teleport system access
_G.TELEPORT_SYSTEM = {
    config = TeleportConfig,
    enablePlayers = enableTeleportPlayers,
    disablePlayers = disableTeleportPlayers,
    enableNPCs = enableTeleportNPCs,
    disableNPCs = disableTeleportNPCs
}

-- Enhanced monitoring system
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
            
            -- More aggressive cleanup if too many objects
            if drawingCount > MAX_OBJECTS * 0.8 then
                cleanupDrawingObjects()
            end
            
            -- Remove invalid objects
            for i = #DrawingObjects, 1, -1 do
                local obj = DrawingObjects[i]
                if not obj or not pcall(function() return obj.Visible end) then
                    table.remove(DrawingObjects, i)
                end
            end
        end)
    end
end)

-- Notification when ESP is loaded
Rayfield:Notify({
   Title = "تم تحميل ESP + Aimbot",
   Content = "أصبح نظام المضخة الغاطسة الكهربائية المحسن مع وظيفة الهدف المزدوج، وصندوق الض...",
   Duration = 3,
   Image = "eye"
})