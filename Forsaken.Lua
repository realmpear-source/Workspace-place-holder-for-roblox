-- ========== SERVICES ==========
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local localPlayer = Players.LocalPlayer
local PlayerGui = localPlayer:WaitForChild("PlayerGui")

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
local ErrorHandler = {
    errors = {},
    maxErrors = 50,
    enabled = true,
    logToConsole = true
}

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
    local errorEntry = string.format("[%s][%s] %s: %s", timestamp, level, context, errorMsg)
    
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
    AUTO_BLOCK_ON = true,
    AUTO_BLOCK_AUDIO_ON = true,
    
    -- Block Detection
    DETECTION_RANGE = 18,
    FACING_CHECK_ENABLED = true,
    LOOSE_FACING = true,
    CUSTOM_FACING_DOT = -0.3,
    BLOCK_DELAY = 0,
    DOUBLE_BLOCK_TECH = false,
    
    -- Better Detection
    BETTER_DETECTION = false,
    ANTI_FLICK_PARTS = 4,
    ANTI_FLICK_DELAY = 0,
    ANTI_FLICK_BASE_OFFSET = 2.7,
    ANTI_FLICK_OFFSET_STEP = 0,
    STAGGER_DELAY = 0.02,
    
    -- Prediction
    PREDICTION_STRENGTH = 1,
    PREDICTION_TURN_STRENGTH = 1,
    BLOCK_PARTS_SIZE_MULTIPLIER = 1,
    PRED_SECONDS_FORWARD = 0.25,
    PRED_SECONDS_LATERAL = 0.18,
    PRED_MAX_FORWARD = 6,
    PRED_MAX_LATERAL = 4,
    ANG_TURN_MULTIPLIER = 0.6,
    SMOOTHING_LERP = 0.22,
    
    -- Sound Throttle
    AUDIO_LOCAL_COOLDOWN = 0.35,
    AUDIO_SOUND_THROTTLE = 1.0,
    AUDIO_PREDICT_DT = 0.08
}

-- ========== AUTO BLOCK DATA ==========
local AUTO_BLOCK_TRIGGER_ANIMS = {
    "126830014841198", "126355327951215", "121086746534252", "18885909645",
    "98456918873918", "105458270463374", "83829782357897", "125403313786645",
    "118298475669935", "82113744478546", "70371667919898", "99135633258223",
    "97167027849946", "109230267448394", "139835501033932", "126896426760253",
    "109667959938617", "126681776859538", "129976080405072", "121293883585738",
    "81639435858902", "137314737492715", "92173139187970", "122709416391", "879895330952"
}

local AUTO_BLOCK_TRIGGER_SOUNDS = {
    ["102228729296384"] = true,
    ["140242176732868"] = true,
    ["112809109188560"] = true,
    ["136323728355613"] = true,
    ["115026634746636"] = true,
    ["84116622032112"] = true,
    ["108907358619313"] = true,
    ["127793641088496"] = true,
    ["86174610237192"] = true,
    ["95079963655241"] = true,
    ["101199185291628"] = true,
    ["119942598489800"] = true,
    ["84307400688050"] = true,
    ["113037804008732"] = true,
    ["105200830849301"] = true,
    ["75330693422988"] = true,
    ["82221759983649"] = true,
    ["81702359653578"] = true,
    ["108610718831698"] = true,
    ["112395455254818"] = true,
    ["109431876587852"] = true,
    ["109348678063422"] = true,
    ["85853080745515"] = true,
    ["12222216"] = true,
    ["105840448036441"] = true,
    ["114742322778642"] = true,
    ["119583605486352"] = true,
    ["79980897195554"] = true,
    ["71805956520207"] = true,
    ["79391273191671"] = true,
    ["89004992452376"] = true,
    ["101553872555606"] = true,
    ["101698569375359"] = true,
    ["106300477136129"] = true,
    ["116581754553533"] = true,
    ["117231507259853"] = true,
    ["119089145505438"] = true,
    ["121954639447247"] = true,
    ["125213046326879"] = true,
    ["131406927389838"] = true,
    ["71834552297085"] = true,
    ["805165833096"] = true
}

local BLOCK_ANIM_IDS = {
    "72722244508749",
    "96959123077498",
    "95802026624883"
}

-- ========== UNIFIED STATE MANAGEMENT ==========
local State = {
    -- ESP System State
    activeHighlights = setmetatable({}, {__mode = "v"}),
    connections = ConnectionManager.new(),
    highlightConnections = ConnectionManager.new(),
    characterDied = false,
    espActive = false,
    currentGenerator = nil,
    highlightEnabled = true,
    lastHighlightUpdate = 0,
    autoFixRunning = false,
    
    -- Auto Block System State
    killerState = {},
    soundHooks = {},
    soundBlockedUntil = {},
    lastLocalBlockTime = 0,
    cachedBlockBtn = nil,
    cachedCooldown = nil,
    
    -- Error Handler
    errorHandler = ErrorHandler.new()
}

-- ========== NETWORK REFERENCES ==========
local testRemote = ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Network"):WaitForChild("RemoteEvent")

-- ========== UNIFIED UTILITY FUNCTIONS ==========
local function safeCall(func, context, suppressError)
    local success, result = pcall(func)
    if not success then
        State.errorHandler:Log(context or "Unknown", result, "Error", suppressError)
        return nil
    end
    return result
end

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
local function isFacing(localRoot, targetRoot)
    if not CONFIG.FACING_CHECK_ENABLED then return true end
    
    local dx = localRoot.Position.X - targetRoot.Position.X
    local dy = localRoot.Position.Y - targetRoot.Position.Y
    local dz = localRoot.Position.Z - targetRoot.Position.Z
    
    local mag = math.sqrt(dx*dx + dy*dy + dz*dz)
    if mag == 0 then return true end
    local invMag = 1 / mag
    
    local ux, uy, uz = dx * invMag, dy * invMag, dz * invMag
    local lv = targetRoot.CFrame.LookVector
    local lx, ly, lz = lv.X, lv.Y, lv.Z
    
    local dot = lx * ux + ly * uy + lz * uz
    return dot > CONFIG.CUSTOM_FACING_DOT
end

local function fireGuiBlock()
    local blockAction = "UseActorAbility"
    local blockData = "Block"  -- Fixed: Removed buffer.fromstring
    
    testRemote:FireServer(blockAction, blockData)
end

local function refreshUIRefs()
    local main = PlayerGui and PlayerGui:FindFirstChild("MainUI")
    if main then
        local ability = main:FindFirstChild("AbilityContainer")
        State.cachedBlockBtn = ability and ability:FindFirstChild("Block")
        State.cachedCooldown = State.cachedBlockBtn and State.cachedBlockBtn:FindFirstChild("CooldownTime")
    else
        State.cachedBlockBtn, State.cachedCooldown = nil, nil
    end
end

local function handleAnimationDetection()
    if not CONFIG.AUTO_BLOCK_ON then return end
    
    local myChar = localPlayer.Character
    if not myChar then return end
    
    local myRoot = myChar:FindFirstChild("HumanoidRootPart")
    if not myRoot then return end
    
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
                            local facingOk = not CONFIG.FACING_CHECK_ENABLED or isFacing(myRoot, hrp)
                            
                            if facingOk then
                                if State.cachedCooldown and State.cachedCooldown.Text == "" then
                                    State.errorHandler:Log("AutoBlock", "Animation detected: " .. animId .. " - Blocking!", "Info")
                                    fireGuiBlock()
                                    
                                    if CONFIG.DOUBLE_BLOCK_TECH then
                                        local punchAction = "UseActorAbility"
                                        local punchData = "Punch"  -- Fixed: Removed buffer.fromstring
                                        testRemote:FireServer(punchAction, punchData)
                                    end
                                    return
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end

local function extractNumericSoundId(sound)
    if not sound then return nil end
    
    local sid = sound.SoundId
    if not sid then return nil end
    sid = tostring(sid)
    
    return string.match(sid, "rbxassetid://(%d+)") or
           string.match(sid, "://(%d+)") or
           string.match(sid, "^(%d+)$")
end

local function getSoundWorldPosition(sound)
    if not sound then return nil end
    
    local parent = sound.Parent
    if parent then
        if parent:IsA("BasePart") then
            return parent.Position, parent
        end
        
        if parent:IsA("Attachment") then
            local gp = parent.Parent
            if gp and gp:IsA("BasePart") then
                return gp.Position, gp
            end
        end
    end
    return nil, nil
end

local function getCharacterFromDescendant(inst)
    if not inst then return nil end
    local model = inst:FindFirstAncestorOfClass("Model")
    if model and model:FindFirstChildOfClass("Humanoid") then
        return model
    end
    return nil
end

local function isPointInsidePart(part, point)
    if not (part and point) then return false end
    
    local rel = part.CFrame:PointToObjectSpace(point)
    local half = part.Size * 0.5
    return math.abs(rel.X) <= half.X + 0.001 and
           math.abs(rel.Y) <= half.Y + 0.001 and
           math.abs(rel.Z) <= half.Z + 0.001
end

local function updateKillerState(dt)
    local killersFolder = workspace:FindFirstChild("Players") and workspace.Players:FindFirstChild("Killers")
    if not killersFolder then return end
    
    for _, killer in ipairs(killersFolder:GetChildren()) do
        if killer and killer.Parent then
            local hrp = killer:FindFirstChild("HumanoidRootPart")
            if hrp then
                local st = State.killerState[killer] or { 
                    prevPos = hrp.Position, 
                    prevLook = hrp.CFrame.LookVector, 
                    vel = Vector3.new(), 
                    angVel = 0 
                }
                
                local newVel = (hrp.Position - st.prevPos) / math.max(dt, 1e-6)
                st.vel = st.vel:Lerp(newVel, CONFIG.SMOOTHING_LERP)
                
                local prevLook = st.prevLook or hrp.CFrame.LookVector
                local look = hrp.CFrame.LookVector
                local dot = math.clamp(prevLook:Dot(look), -1, 1)
                local angle = math.acos(dot)
                local crossY = prevLook:Cross(look).Y
                local angSign = (crossY >= 0) and 1 or -1
                local newAngVel = (angle / math.max(dt, 1e-6)) * angSign
                st.angVel = (st.angVel * (1 - CONFIG.SMOOTHING_LERP)) + (newAngVel * CONFIG.SMOOTHING_LERP)
                
                st.prevPos = hrp.Position
                st.prevLook = look
                State.killerState[killer] = st
            end
        end
    end
end

local function attemptAntiFlickBlock(sound, char)
    if not CONFIG.AUTO_BLOCK_AUDIO_ON then return end
    if not sound or not sound:IsA("Sound") then return end
    
    local now = tick()
    if State.soundBlockedUntil[sound] and now < State.soundBlockedUntil[sound] then return end
    if now - State.lastLocalBlockTime < CONFIG.AUDIO_LOCAL_COOLDOWN then return end
    
    local myChar = localPlayer.Character
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not myRoot then return end
    
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    
    local distSq = (hrp.Position - myRoot.Position).MagnitudeSquared
    if distSq > (CONFIG.DETECTION_RANGE + 3) ^ 2 then return end
    
    if CONFIG.FACING_CHECK_ENABLED and not isFacing(myRoot, hrp) then
        return
    end
    
    local basePartSize = Vector3.new(5.5, 7.5, 8.5) * CONFIG.BLOCK_PARTS_SIZE_MULTIPLIER
    local count = math.max(1, CONFIG.ANTI_FLICK_PARTS)
    local base = CONFIG.ANTI_FLICK_BASE_OFFSET
    local step = CONFIG.ANTI_FLICK_OFFSET_STEP
    
    task.spawn(function()
        local blocked = false
        task.wait(CONFIG.ANTI_FLICK_DELAY)
        
        for i = 1, count do
            if not hrp or not myRoot then break end
            
            local dist = base + (i - 1) * step
            local st = State.killerState[char] or { vel = hrp.Velocity or Vector3.new(), angVel = 0 }
            local vel = st.vel or hrp.Velocity or Vector3.new()
            
            local forwardSpeed = vel:Dot(hrp.CFrame.LookVector)
            local lateralSpeed = vel:Dot(hrp.CFrame.RightVector)
            
            local forwardPredictRaw = forwardSpeed * CONFIG.PRED_SECONDS_FORWARD * CONFIG.PREDICTION_STRENGTH
            local lateralPredictRaw = lateralSpeed * CONFIG.PRED_SECONDS_LATERAL * CONFIG.PREDICTION_STRENGTH
            local turnLateralRaw = st.angVel * CONFIG.ANG_TURN_MULTIPLIER * CONFIG.PREDICTION_TURN_STRENGTH
            
            local forwardPredict = math.clamp(forwardPredictRaw, -CONFIG.PRED_MAX_FORWARD, CONFIG.PRED_MAX_FORWARD)
            local lateralPredict = math.clamp(lateralPredictRaw, -CONFIG.PRED_MAX_LATERAL, CONFIG.PRED_MAX_LATERAL)
            local turnLateral = math.clamp(turnLateralRaw, -CONFIG.PRED_MAX_LATERAL, CONFIG.PRED_MAX_LATERAL)
            
            local forwardDist = dist + forwardPredict
            local spawnPos = hrp.Position +
                            hrp.CFrame.LookVector * forwardDist +
                            hrp.CFrame.RightVector * (lateralPredict + turnLateral)
            
            local part = Instance.new("Part")
            part.Name = "AntiFlickZone"
            part.Size = basePartSize
            part.Transparency = 0.45
            part.Anchored = true
            part.CanCollide = false
            part.CFrame = CFrame.new(spawnPos, hrp.Position)
            part.BrickColor = BrickColor.new("Bright blue")
            part.Parent = workspace
            
            Debris:AddItem(part, 0.2)
            
            if isPointInsidePart(part, myRoot.Position) then
                blocked = true
            else
                local touching = {}
                pcall(function() touching = myRoot:GetTouchingParts() end)
                for _, p in ipairs(touching) do
                    if p == part then
                        blocked = true
                        break
                    end
                end
            end
            
            if blocked then
                State.errorHandler:Log("AutoBlock", "Anti-flick block triggered!", "Info")
                fireGuiBlock()
                State.soundBlockedUntil[sound] = now + CONFIG.AUDIO_SOUND_THROTTLE
                State.lastLocalBlockTime = now
                break
            end
            
            if CONFIG.STAGGER_DELAY > 0 then
                task.wait(CONFIG.STAGGER_DELAY)
            end
        end
    end)
end

local function attemptBasicSoundBlock(sound, char)
    if not CONFIG.AUTO_BLOCK_AUDIO_ON then return end
    if not sound or not sound:IsA("Sound") then return end
    
    local now = tick()
    if State.soundBlockedUntil[sound] and now < State.soundBlockedUntil[sound] then return end
    if now - State.lastLocalBlockTime < CONFIG.AUDIO_LOCAL_COOLDOWN then return end
    
    local myChar = localPlayer.Character
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not myRoot then return end
    
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    
    local distSq = (hrp.Position - myRoot.Position).MagnitudeSquared
    if distSq > (CONFIG.DETECTION_RANGE + 3) ^ 2 then return end
    
    if CONFIG.FACING_CHECK_ENABLED and not isFacing(myRoot, hrp) then
        return
    end
    
    if State.cachedCooldown and State.cachedCooldown.Text == "" then
        State.errorHandler:Log("AutoBlock", "Sound detected - Blocking!", "Info")
        task.wait(CONFIG.BLOCK_DELAY)
        fireGuiBlock()
        
        if CONFIG.DOUBLE_BLOCK_TECH then
            local punchAction = "UseActorAbility"
            local punchData = "Punch"  -- Fixed: Removed buffer.fromstring
            testRemote:FireServer(punchAction, punchData)
        end
        
        State.soundBlockedUntil[sound] = now + CONFIG.AUDIO_SOUND_THROTTLE
        State.lastLocalBlockTime = now
    end
end

local function hookSound(sound)
    if not sound or not sound:IsA("Sound") then return end
    if State.soundHooks[sound] then return end
    
    local soundId = extractNumericSoundId(sound)
    if not soundId or not AUTO_BLOCK_TRIGGER_SOUNDS[soundId] then return end
    
    State.soundHooks[sound] = true
    
    local function handleSound()
        if not sound.IsPlaying then return end
        
        local soundPos, soundPart = getSoundWorldPosition(sound)
        if not soundPart then return end
        
        local char = getCharacterFromDescendant(soundPart)
        if not char then return end
        
        if CONFIG.BETTER_DETECTION then
            attemptAntiFlickBlock(sound, char)
        else
            attemptBasicSoundBlock(sound, char)
        end
    end
    
    local playedConn = sound.Played:Connect(handleSound)
    local propConn = sound:GetPropertyChangedSignal("IsPlaying"):Connect(function()
        if sound.IsPlaying then
            handleSound()
        end
    end)
    
    local destroyConn = sound.Destroying:Connect(function()
        playedConn:Disconnect()
        propConn:Disconnect()
        destroyConn:Disconnect()
        State.soundHooks[sound] = nil
        State.soundBlockedUntil[sound] = nil
    end)
    
    if sound.IsPlaying then
        handleSound()
    end
end

local function hookExistingSounds()
    local killersFolder = workspace:FindFirstChild("Players") and workspace.Players:FindFirstChild("Killers")
    if killersFolder then
        for _, sound in ipairs(killersFolder:GetDescendants()) do
            if sound:IsA("Sound") then
                hookSound(sound)
            end
        end
        
        killersFolder.DescendantAdded:Connect(function(desc)
            if desc:IsA("Sound") then
                hookSound(desc)
            end
        end)
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
                        end
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
        
        -- Initialize Auto Block
        refreshUIRefs()
        localPlayer.CharacterAdded:Connect(function()
            task.delay(0.5, refreshUIRefs)
        end)
        
        hookExistingSounds()
        
        -- Animation detection loop
        State.connections:Add(RunService.RenderStepped:Connect(function()
            handleAnimationDetection()
        end))
        
        -- Prediction update loop
        State.connections:Add(RunService.RenderStepped:Connect(function(dt)
            updateKillerState(dt)
        end))
        
        State.errorHandler:Log("Initialization", "Script initialized successfully", "Info")
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
        
        -- Clean up auto block hooks
        for sound, _ in pairs(State.soundHooks) do
            State.soundHooks[sound] = nil
        end
        table.clear(State.soundBlockedUntil)
        table.clear(State.killerState)
        
        State.errorHandler:Log("Cleanup", "Script cleaned up", "Info")
    end, "cleanup", true)
end

-- ========== MAIN EXECUTION ==========
local success = safeCall(initialize, "Main")

if not success then
    cleanup()
end

-- ========== EXPORTS ==========
return cleanup, State.errorHandler
