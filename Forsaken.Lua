-- ========== SERVICES ==========
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local localPlayer = Players.LocalPlayer

-- ========== CONNECTION MANAGER ==========
local ConnectionManager = {}
ConnectionManager.__index = ConnectionManager

function ConnectionManager.new()
    return setmetatable({
        _connections = {}
    }, ConnectionManager)
end

function ConnectionManager:Add(connection)
    if connection then
        table.insert(self._connections, connection)
    end
    return connection
end

function ConnectionManager:DisconnectAll()
    for _, connection in ipairs(self._connections) do
        if typeof(connection) == "RBXScriptConnection" then
            connection:Disconnect()
        end
    end
    self._connections = {}
end

function ConnectionManager:Destroy()
    self:DisconnectAll()
end

-- ========== ERROR HANDLER ==========
local ErrorHandler = {}
ErrorHandler.__index = ErrorHandler

function ErrorHandler.new()
    return setmetatable({
        errors = {},
        maxErrors = 50,
        enabled = true,
        logToConsole = true
    }, ErrorHandler)
end

function ErrorHandler:Log(context, errorMsg, level, suppressOutput)
    if not self.enabled then return end
    
    level = level or "Warning"
    local timestamp = os.date("%H:%M:%S")
    local errorEntry = string.format("[%s][%s] %s: %s", timestamp, level, context, tostring(errorMsg))
    
    table.insert(self.errors, errorEntry)
    
    if #self.errors > self.maxErrors then
        table.remove(self.errors, 1)
    end
    
    if self.logToConsole and not suppressOutput then
        print(errorEntry)
    end
    
    return errorEntry
end

function ErrorHandler:Clear()
    self.errors = {}
end

function ErrorHandler:GetRecent(count)
    count = math.min(count or 5, #self.errors)
    local result = {}
    for i = #self.errors, #self.errors - count + 1, -1 do
        if self.errors[i] then
            table.insert(result, self.errors[i])
        end
    end
    return result
end

function ErrorHandler:Enable()
    self.enabled = true
end

function ErrorHandler:Disable()
    self.enabled = false
end

function ErrorHandler:SetConsoleLogging(enabled)
    self.logToConsole = enabled
end

-- ========== UNIFIED CONFIGURATION ==========
local CONFIG = {
    -- ESP System
    COLORS = {
        survivor = Color3.fromRGB(0, 255, 255),
        killer = Color3.fromRGB(255, 100, 100),
        item = Color3.fromRGB(255, 255, 0),
        generator = Color3.fromRGB(50, 255, 50),
        minion = Color3.fromRGB(170, 0, 255),
        survivorAbility = Color3.fromRGB(255, 165, 0),
        killerAbility = Color3.fromRGB(255, 50, 150)
    },
    
    OBJECT_NAMES = {
        items = {"Medkit", "BloxyCola"},
        minions = {"PizzaDeliveryRig", "1x1x1x1Zombie", "Mafia1", "Mafia2", "Mafia3", "Mafia4", "BlueGuy", "RedGuy", "PurpleGuy", "GreenGuy"},
        survivorAbilities = {"SubspaceTripmine", "pizza"},
        killerAbilities = {"Swords", "Shockwave", "Voidstar", "HumanoidRootProjectile"}
    },
    
    -- ESP Settings
    ESP_SETTINGS = {
        players = true,
        items = true,
        generators = true,
        survivorAbilities = true,
        killerAbilities = true,
        minions = true
    },
    
    -- Generator Repair
    GEN_REPAIR_KEY = Enum.KeyCode.X,
    GEN_TIME = 2.5,
    MAX_ATTEMPTS = 1,
    AUTO_FIX = false,
    AUTO_FIX_DELAY = 1,
    
    -- Highlight System
    HIGHLIGHT_REFRESH_RATE = 1,
    ESP_TOGGLE_KEY = Enum.KeyCode.P,
    
    -- Auto Block System
    AUTO_BLOCK_ENABLED = true,
    AUTO_BLOCK_TOGGLE_KEY = Enum.KeyCode.O,
    
    -- Block Detection
    DETECTION_RANGE = 1,
    BLOCK_DELAY = 0.65,
    HITBOX_SIZE = 1.4,
    HITBOX_TRANSPARENCY = 0.5
}

-- ========== AUTO BLOCK ANIMATION TRIGGERS ==========
local AUTO_BLOCK_TRIGGER_ANIMS = {
    "126830014841198", "126355327951215", "121086746534252", "18885909645",
    "98456918873918", "105458270463374", "83829782357897", "125403313786645",
    "118298475669935", "82113744478546", "70371667919898", "99135633258223",
    "97167027849946", "109230267448394", "139835501033932", "126896426760253",
    "109667959938617", "126681776859538", "129976080405072", "121293883585738",
    "81639435858902", "137314737492715", "92173139187970", "122709416391", "879895330952"
}

-- ========== UNIFIED STATE MANAGEMENT ==========
local State = {
    -- ESP System State
    activeHighlights = setmetatable({}, {__mode = "v"}),
    characterDied = false,
    espActive = false,
    currentGenerator = nil,
    highlightEnabled = true,
    lastHighlightUpdate = 0,
    autoFixRunning = false,
    
    -- Auto Block System State
    autoBlockEnabled = CONFIG.AUTO_BLOCK_ENABLED,
    lastBlockTime = 0,
    
    -- Managers
    connections = ConnectionManager.new(),
    highlightConnections = ConnectionManager.new(),
    errorHandler = nil  -- Will be initialized later
}

-- ========== NETWORK REFERENCES ==========
local testRemote = ReplicatedStorage:FindFirstChild("Modules") and 
                   ReplicatedStorage.Modules:FindFirstChild("Network") and
                   ReplicatedStorage.Modules.Network:FindFirstChild("RemoteEvent")

-- ========== GLOBAL ERROR HANDLER ==========
local function safeCall(func, context, suppressError)
    local success, result = pcall(func)
    if not success then
        -- Use global print if errorHandler is not available yet
        if State.errorHandler then
            State.errorHandler:Log(context or "Unknown", result, "Error", suppressError)
        else
            local errorMsg = string.format("[%s][Error] %s: %s", os.date("%H:%M:%S"), context or "Unknown", tostring(result))
            if not suppressError then
                print(errorMsg)
            end
        end
        return nil
    end
    return result
end

-- ========== UNIFIED UTILITY FUNCTIONS ==========
local function waitForLocalPlayer(timeout)
    if localPlayer then return true end
    
    local startTime = os.clock()
    timeout = timeout or 10
    
    local success = safeCall(function()
        local connection
        local playerFound = false
        
        connection = Players:GetPropertyChangedSignal("LocalPlayer"):Connect(function()
            if Players.LocalPlayer then
                playerFound = true
                localPlayer = Players.LocalPlayer
                if connection then 
                    connection:Disconnect() 
                end
            end
        end)
        
        if Players.LocalPlayer then
            playerFound = true
            localPlayer = Players.LocalPlayer
        end
        
        while os.clock() - startTime < timeout and not playerFound do
            task.wait(0.1)
        end
        
        return playerFound
    end, "waitForLocalPlayer")
    
    return success or false
end

local function isPlayerAlive()
    if State.characterDied then return false end
    
    return safeCall(function()
        local character = localPlayer.Character
        if not character then return false end
        
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        return humanoid and humanoid.Health > 0
    end, "isPlayerAlive", true) or false
end

local function getLocalPlayerRoot()
    return safeCall(function()
        local character = localPlayer.Character
        return character and character:FindFirstChild("HumanoidRootPart")
    end, "getLocalPlayerRoot", true)
end

local function isValidObject(obj)
    return safeCall(function()
        return obj and (obj:IsA("Model") or obj:IsA("Part") or obj:IsA("BasePart"))
    end, "isValidObject", true) or false
end

local function isLocalPlayerModel(model)
    if not model then return false end
    
    return safeCall(function()
        if model == localPlayer.Character then
            return true
        end
        
        local playersFolder = workspace:FindFirstChild("Players")
        if playersFolder then
            local survivors = playersFolder:FindFirstChild("Survivors")
            local killers = playersFolder:FindFirstChild("Killers")
            
            if survivors and survivors:IsAncestorOf(model) then
                return model:IsAncestorOf(localPlayer.Character) or model == localPlayer.Character
            end
            
            if killers and killers:IsAncestorOf(model) then
                return model:IsAncestorOf(localPlayer.Character) or model == localPlayer.Character
            end
        end
        
        return false
    end, "isLocalPlayerModel", true) or false
end

-- ========== ESP SYSTEM FUNCTIONS ==========
local function cleanupHighlight(parent)
    safeCall(function()
        local highlight = State.activeHighlights[parent]
        if highlight and highlight.Parent then
            highlight:Destroy()
        end
        State.activeHighlights[parent] = nil
    end, "cleanupHighlight", true)
end

local function clearAllHighlights()
    safeCall(function()
        for parent, highlight in pairs(State.activeHighlights) do
            if highlight and highlight.Parent then
                highlight:Destroy()
            end
        end
        table.clear(State.activeHighlights)
    end, "clearAllHighlights", true)
end

local function createHighlight(parent, color)
    if not parent or not parent.Parent or State.activeHighlights[parent] then 
        return nil 
    end
    
    return safeCall(function()
        local highlight = Instance.new("Highlight")
        highlight.FillTransparency = 1
        highlight.OutlineColor = color
        highlight.OutlineTransparency = 0.3
        highlight.Parent = parent
        
        State.activeHighlights[parent] = highlight
        
        parent.AncestryChanged:Connect(function(_, newParent)
            if newParent == nil then
                cleanupHighlight(parent)
            end
        end)
        
        return highlight
    end, "createHighlight") or nil
end

local function processObjectCollection(names, color, conditionCheck)
    conditionCheck = conditionCheck or function() return true end
    
    safeCall(function()
        for _, obj in ipairs(workspace:GetDescendants()) do
            if isValidObject(obj) and names[obj.Name] and conditionCheck(obj) then
                createHighlight(obj, color)
            end
        end
        
        State.highlightConnections:Add(workspace.DescendantAdded:Connect(function(descendant)
            if isValidObject(descendant) and names[descendant.Name] and conditionCheck(descendant) then
                createHighlight(descendant, color)
            end
        end))
    end, "processObjectCollection", true)
end

local function highlightObjects()
    if not State.highlightEnabled then return end
    
    safeCall(function()
        -- Clear existing highlights
        clearAllHighlights()
        State.highlightConnections:DisconnectAll()
        
        -- Highlight players if enabled
        if CONFIG.ESP_SETTINGS.players then
            local playersFolder = workspace:FindFirstChild("Players")
            if playersFolder then
                local function highlightPlayerGroup(group, color)
                    if not group then return end
                    
                    for _, playerModel in ipairs(group:GetChildren()) do
                        if playerModel:IsA("Model") and not isLocalPlayerModel(playerModel) then
                            createHighlight(playerModel, color)
                        end
                    end
                    
                    State.highlightConnections:Add(group.ChildAdded:Connect(function(child)
                        if child:IsA("Model") and not isLocalPlayerModel(child) then
                            createHighlight(child, color)
                        end
                    end))
                end
                
                highlightPlayerGroup(playersFolder:FindFirstChild("Survivors"), CONFIG.COLORS.survivor)
                highlightPlayerGroup(playersFolder:FindFirstChild("Killers"), CONFIG.COLORS.killer)
            end
        end
        
        -- Highlight items if enabled
        if CONFIG.ESP_SETTINGS.items then
            local itemMap = {}
            for _, name in ipairs(CONFIG.OBJECT_NAMES.items) do
                itemMap[name] = true
            end
            processObjectCollection(itemMap, CONFIG.COLORS.item)
        end
        
        -- Highlight minions if enabled
        if CONFIG.ESP_SETTINGS.minions then
            local minionMap = {}
            for _, name in ipairs(CONFIG.OBJECT_NAMES.minions) do
                minionMap[name] = true
            end
            processObjectCollection(minionMap, CONFIG.COLORS.minion)
        end
        
        -- Highlight survivor abilities if enabled
        if CONFIG.ESP_SETTINGS.survivorAbilities then
            local abilityMap = {}
            for _, name in ipairs(CONFIG.OBJECT_NAMES.survivorAbilities) do
                abilityMap[name] = true
            end
            processObjectCollection(abilityMap, CONFIG.COLORS.survivorAbility)
        end
        
        -- Highlight killer abilities if enabled
        if CONFIG.ESP_SETTINGS.killerAbilities then
            local abilityMap = {}
            for _, name in ipairs(CONFIG.OBJECT_NAMES.killerAbilities) do
                abilityMap[name] = true
            end
            processObjectCollection(abilityMap, CONFIG.COLORS.killerAbility)
        end
        
        -- Highlight generators if enabled
        if CONFIG.ESP_SETTINGS.generators then
            safeCall(function()
                local map = workspace:FindFirstChild("Map")
                local ingame = map and map:FindFirstChild("Ingame")
                local generators = ingame and ingame:FindFirstChild("Map")
                
                if not generators then return end
                
                local function isGeneratorValid(generator)
                    if not generator:IsA("Model") then return false end
                    local progress = generator:FindFirstChild("Progress")
                    return progress and progress.Value < 100
                end
                
                for _, gen in ipairs(generators:GetChildren()) do
                    if gen.Name == "Generator" and isGeneratorValid(gen) then
                        createHighlight(gen, CONFIG.COLORS.generator)
                        
                        local progress = gen:FindFirstChild("Progress")
                        if progress then
                            local progressConnection = progress:GetPropertyChangedSignal("Value"):Connect(function()
                                if progress.Value >= 100 then
                                    cleanupHighlight(gen)
                                end
                            end)
                            State.highlightConnections:Add(progressConnection)
                        end
                    end
                end
                
                State.highlightConnections:Add(generators.ChildAdded:Connect(function(child)
                    if child.Name == "Generator" and isGeneratorValid(child) then
                        createHighlight(child, CONFIG.COLORS.generator)
                        
                        local progress = child:FindFirstChild("Progress")
                        if progress then
                            local progressConnection = progress:GetPropertyChangedSignal("Value"):Connect(function()
                                if progress.Value >= 100 then
                                    cleanupHighlight(child)
                                end
                            end)
                            State.highlightConnections:Add(progressConnection)
                        end
                    end
                end))
            end, "highlightGenerators", true)
        end
    end, "highlightObjects", true)
end

local function toggleESP()
    State.highlightEnabled = not State.highlightEnabled
    
    safeCall(function()
        if State.highlightEnabled then
            highlightObjects()
        else
            clearAllHighlights()
            State.highlightConnections:DisconnectAll()
        end
    end, "toggleESP", true)
end

-- ========== GENERATOR REPAIR SYSTEM ==========
local function validateGenerator(generator)
    if not generator or not generator.Parent then return false end
    
    return safeCall(function()
        return generator:FindFirstChild("Progress") and
               generator:FindFirstChild("Main") and
               generator.Main:FindFirstChild("Prompt") and
               generator:FindFirstChild("Remotes") and
               generator.Remotes:FindFirstChild("RE")
    end, "validateGenerator", true) or false
end

local function getClosestGenerator()
    if not isPlayerAlive() then return nil end
    
    return safeCall(function()
        local character = localPlayer.Character
        local rootPart = character and character:FindFirstChild("HumanoidRootPart")
        if not rootPart then return nil end
        
        local closest = nil
        local minDistance = math.huge
        
        local map = workspace:FindFirstChild("Map")
        local ingame = map and map:FindFirstChild("Ingame")
        local generators = ingame and ingame:FindFirstChild("Map")
        
        if not generators then return nil end
        
        for _, generator in ipairs(generators:GetDescendants()) do
            if generator.Name == "Generator" and validateGenerator(generator) then
                local progress = generator.Progress.Value
                if progress < 100 then
                    local distance = (generator:GetPivot().Position - rootPart.Position).Magnitude
                    if distance < minDistance then
                        minDistance = distance
                        closest = generator
                    end
                end
            end
        end
        
        return closest
    end, "getClosestGenerator", true)
end

local function attemptFixGenerator()
    if State.espActive or not isPlayerAlive() then return end
    
    State.espActive = true
    
    safeCall(function()
        local generator = getClosestGenerator()
        
        if not generator then
            State.espActive = false
            return
        end
        
        State.currentGenerator = generator
        local prompt = generator.Main.Prompt
        
        for _ = 1, 3 do
            if not State.espActive or not isPlayerAlive() then break end
            if prompt and prompt.Parent then
                fireproximityprompt(prompt, 1)
            end
            task.wait(0.1)
        end
        
        for i = 1, CONFIG.MAX_ATTEMPTS do
            if not State.espActive or not isPlayerAlive() or not validateGenerator(generator) or generator.Progress.Value >= 100 then 
                break 
            end
            
            generator.Remotes.RE:FireServer()
            
            if i < CONFIG.MAX_ATTEMPTS and generator.Progress.Value < 100 then
                task.wait(CONFIG.GEN_TIME)
            end
        end
    end, "attemptFixGenerator", true)
    
    State.espActive = false
    State.currentGenerator = nil
end

local function autoFixLoop()
    if State.autoFixRunning then return end
    
    State.autoFixRunning = true
    
    safeCall(function()
        while CONFIG.AUTO_FIX and State.autoFixRunning do
            if not State.espActive and isPlayerAlive() then
                local generator = getClosestGenerator()
                if generator then
                    attemptFixGenerator()
                end
            end
            task.wait(CONFIG.AUTO_FIX_DELAY)
        end
    end, "autoFixLoop", true)
    
    State.autoFixRunning = false
end

-- ========== AUTO BLOCK SYSTEM FUNCTIONS ==========
local function fireGuiBlock()
    if not testRemote then return false end
    
    return safeCall(function()
        local blockAction = "UseActorAbility"
        local blockData = {buffer.fromstring("\"Block\"")}
        
        testRemote:FireServer(blockAction, blockData)
        return true
    end, "fireGuiBlock", true) or false
end

local function createHitbox(character, targetCharacter)
    if not character or not targetCharacter then return nil end
    
    return safeCall(function()
        local hrp = targetCharacter:FindFirstChild("HumanoidRootPart")
        local myRoot = character:FindFirstChild("HumanoidRootPart")
        
        if not hrp or not myRoot then return nil end
        
        local part = Instance.new("Part")
        part.Name = "AutoBlockHitbox"
        part.Size = Vector3.new(CONFIG.HITBOX_SIZE, CONFIG.HITBOX_SIZE, CONFIG.HITBOX_SIZE)
        part.Transparency = CONFIG.HITBOX_TRANSPARENCY
        part.Anchored = true
        part.CanCollide = false
        part.CFrame = CFrame.new(hrp.Position + hrp.CFrame.LookVector * 3)
        part.BrickColor = BrickColor.new("Bright red")
        part.Parent = workspace
        
        Debris:AddItem(part, 0.5)
        
        -- Check if player is inside hitbox
        local distance = (myRoot.Position - part.Position).Magnitude
        local hitboxRadius = CONFIG.HITBOX_SIZE / 2
        
        return distance <= hitboxRadius, part
    end, "createHitbox", true)
end

local function handleAnimationDetection()
    if not State.autoBlockEnabled or not CONFIG.AUTO_BLOCK_ENABLED then return end
    
    return safeCall(function()
        local myChar = localPlayer.Character
        if not myChar then return end
        
        local myRoot = myChar:FindFirstChild("HumanoidRootPart")
        if not myRoot then return end
        
        local now = tick()
        if now - State.lastBlockTime < CONFIG.BLOCK_DELAY then return end
        
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= localPlayer and plr.Character then
                local char = plr.Character
                local hrp = char:FindFirstChild("HumanoidRootPart")
                local hum = char:FindFirstChildOfClass("Humanoid")
                
                if hrp and hum and (hrp.Position - myRoot.Position).Magnitude <= CONFIG.DETECTION_RANGE then
                    local animator = hum:FindFirstChildOfClass("Animator")
                    if animator then
                        for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
                            local animId = tostring(track.Animation.AnimationId):match("%d+")
                            
                            if animId and table.find(AUTO_BLOCK_TRIGGER_ANIMS, animId) then
                                -- Create hitbox and check if player is inside
                                local hitResult, hitbox = createHitbox(myChar, char)
                                
                                if hitResult then
                                    if State.errorHandler then
                                        State.errorHandler:Log("AutoBlock", "Attack detected: " .. animId .. " - Blocking!", "Info")
                                    end
                                    if fireGuiBlock() then
                                        State.lastBlockTime = now
                                    end
                                    return true
                                end
                            end
                        end
                    end
                end
            end
        end
        return false
    end, "handleAnimationDetection", true) or false
end

local function toggleAutoBlock()
    State.autoBlockEnabled = not State.autoBlockEnabled
    if State.errorHandler then
        State.errorHandler:Log("AutoBlock", "Auto Block: " .. (State.autoBlockEnabled and "ENABLED" or "DISABLED"), "Info")
    end
end

-- ========== EVENT HANDLERS ==========
local function onCharacterDeath()
    State.characterDied = true
    State.espActive = false
    State.currentGenerator = nil
    clearAllHighlights()
end

local function onCharacterAdded(character)
    State.characterDied = false
    
    safeCall(function()
        local humanoid = character:WaitForChild("Humanoid", 5)
        if humanoid then
            humanoid.Died:Connect(onCharacterDeath)
        end
        
        task.wait(1)
        
        if State.highlightEnabled then
            highlightObjects()
        end
    end, "onCharacterAdded", true)
end

local function onPlayerDeathCleanup(playerModel)
    cleanupHighlight(playerModel)
end

-- ========== INPUT HANDLING ==========
local function setupInputHandlers()
    -- ESP Toggle
    State.connections:Add(UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if not gameProcessed and input.KeyCode == CONFIG.ESP_TOGGLE_KEY then
            toggleESP()
        end
    end))
    
    -- Auto Block Toggle
    State.connections:Add(UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if not gameProcessed and input.KeyCode == CONFIG.AUTO_BLOCK_TOGGLE_KEY then
            toggleAutoBlock()
        end
    end))
    
    -- Manual Generator Repair
    if not CONFIG.AUTO_FIX then
        State.connections:Add(UserInputService.InputBegan:Connect(function(input, gameProcessed)
            if gameProcessed or State.characterDied or CONFIG.AUTO_FIX then return end
            
            if input.KeyCode == CONFIG.GEN_REPAIR_KEY then
                task.spawn(attemptFixGenerator)
            end
        end))
    end
end

local function setupRespawnHandling()
    local playersFolder = workspace:FindFirstChild("Players")
    if playersFolder then
        local function setupDeathTrackingForGroup(group)
            if not group then return end
            
            for _, playerModel in ipairs(group:GetChildren()) do
                if playerModel:IsA("Model") and not isLocalPlayerModel(playerModel) then
                    local humanoid = playerModel:FindFirstChildOfClass("Humanoid")
                    if humanoid then
                        humanoid.Died:Connect(function()
                            onPlayerDeathCleanup(playerModel)
                        end)
                    end
                end
            end
            
            group.ChildAdded:Connect(function(child)
                if child:IsA("Model") and not isLocalPlayerModel(child) then
                    local humanoid = child:WaitForChild("Humanoid", 2)
                    if humanoid then
                        humanoid.Died:Connect(function()
                            onPlayerDeathCleanup(child)
                        end)
                    end
                end
            end)
        end
        
        setupDeathTrackingForGroup(playersFolder:FindFirstChild("Survivors"))
        setupDeathTrackingForGroup(playersFolder:FindFirstChild("Killers"))
    end
end

-- ========== INITIALIZATION ==========
local function initialize()
    -- Initialize ErrorHandler FIRST before any safeCall uses it
    State.errorHandler = ErrorHandler.new()
    
    if not waitForLocalPlayer() then
        State.errorHandler:Log("Initialization", "Failed to get local player", "Error")
        return false
    end
    
    safeCall(function()
        -- Setup input handlers
        setupInputHandlers()
        
        -- Setup character tracking
        if localPlayer.Character then
            local humanoid = localPlayer.Character:FindFirstChildOfClass("Humanoid")
            if humanoid then
                humanoid.Died:Connect(onCharacterDeath)
            end
        end
        
        State.connections:Add(localPlayer.CharacterAdded:Connect(onCharacterAdded))
        
        -- Setup respawn handling
        setupRespawnHandling()
        
        -- Setup highlight updates
        State.connections:Add(RunService.Heartbeat:Connect(function()
            if State.highlightEnabled and os.clock() - State.lastHighlightUpdate > CONFIG.HIGHLIGHT_REFRESH_RATE then
                safeCall(function()
                    for parent, highlight in pairs(State.activeHighlights) do
                        if parent and parent.Parent and parent.Name == "Generator" then
                            local progress = parent:FindFirstChild("Progress")
                            if progress and progress.Value >= 100 then
                                cleanupHighlight(parent)
                            end
                        end
                    end
                end, "updateGeneratorHighlights", true)
                State.lastHighlightUpdate = os.clock()
            end
        end))
        
        -- Start auto systems
        if CONFIG.AUTO_FIX then
            task.spawn(autoFixLoop)
        end
        
        -- Initialize ESP
        if State.highlightEnabled then
            highlightObjects()
        end
        
        -- Animation detection loop (with error protection)
        State.connections:Add(RunService.RenderStepped:Connect(function()
            local success = pcall(handleAnimationDetection)
            if not success then
                -- If auto block fails, ESP continues working
                State.errorHandler:Log("AutoBlock", "Error in animation detection, continuing with ESP only", "Warning", true)
            end
        end))
        
        State.errorHandler:Log("Initialization", "Script initialized successfully", "Info")
        State.errorHandler:Log("AutoBlock", "Auto Block: " .. (State.autoBlockEnabled and "ENABLED" or "DISABLED"), "Info")
        State.errorHandler:Log("ESP", "ESP: " .. (State.highlightEnabled and "ENABLED" or "DISABLED"), "Info")
    end, "initialize")
    
    return true
end

local function cleanup()
    safeCall(function()
        -- Stop all active systems
        State.espActive = false
        State.currentGenerator = nil
        State.autoFixRunning = false
        
        -- Clean up connections
        State.connections:Destroy()
        State.highlightConnections:DisconnectAll()
        
        -- Clear highlights
        clearAllHighlights()
        
        -- Clean up auto block hitboxes
        for _, obj in ipairs(workspace:GetChildren()) do
            if obj.Name == "AutoBlockHitbox" then
                obj:Destroy()
            end
        end
        
        if State.errorHandler then
            State.errorHandler:Log("Cleanup", "Script cleaned up", "Info")
        end
    end, "cleanup", true)
end

-- ========== MAIN EXECUTION ==========
local success = safeCall(initialize, "Main")

if not success then
    cleanup()
end

return cleanup, State.errorHandler
