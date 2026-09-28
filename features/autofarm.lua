--// ╔══════════════════════════════════════════════════════════════╗
--// ║  TrustHub Auto Farm v2.0                                     ║
--// ║  Auto round start + Noclip flight + Auto Fling Murderer      ║
--// ╚══════════════════════════════════════════════════════════════╝

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local StarterGui       = game:GetService("StarterGui")

local LocalPlayer = Players.LocalPlayer
local Camera      = workspace.CurrentCamera

--// ============================================================
--//  CONFIG
--// ============================================================
local Config = {
    Enabled       = false,      -- Master toggle
    AutoStart     = true,       -- Автоматично включати на початку раунду
    FlySpeed      = 22,         -- Швидкість польоту (studs/s)
    MaxDistance   = 2000,       -- Максимальна дистанція пошуку
    UpdateRate    = 0.05,       -- Як часто оновлювати ціль
    AutoFlingAfterFarm = true,  -- Флингати Murderer-а після збору
    FlingDelay    = 1.5,        -- Затримка перед флингом
    AntiMurderer  = true,       -- Тікати від Murderer-а під час фарму
    DangerRange   = 40,         -- Радіус втечі
}

--// ============================================================
--//  STATE
--// ============================================================
local enabled = false
local flying = false
local noclipEnabled = false
local currentTarget = nil
local lastUpdate = 0
local collectedCoins = {}   -- монети, які вже зібрали
local totalCoinsFound = 0
local roundStartTime = 0
local flingInProgress = false

--// Velocity-based fly
local bodyVelocity = nil
local bodyGyro = nil

--// Noclip
local noclipConn = nil

--// ============================================================
--//  LOG
--// ============================================================
local function log(msg) print("[AutoFarm] " .. msg) end

local function notify(title, text, duration)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = title, Text = text, Duration = duration or 2,
        })
    end)
end

--// ============================================================
--//  ROLE DETECTION
--// ============================================================
local function getRole(player)
    if not player or not player.Character then return "Dead" end
    local char = player.Character

    for _, tool in ipairs(char:GetChildren()) do
        if tool:IsA("Tool") then
            local n = tool.Name:lower()
            if n:find("knife") or n:find("blade") or n:find("murder") then
                return "Murderer"
            end
        end
    end

    for _, tool in ipairs(char:GetChildren()) do
        if tool:IsA("Tool") then
            local n = tool.Name:lower()
            if n:find("gun") or n:find("pistol") or n:find("sheriff") or n:find("revolver") then
                return "Sheriff"
            end
        end
    end

    local bp = player:FindFirstChild("Backpack")
    if bp then
        for _, tool in ipairs(bp:GetChildren()) do
            if tool:IsA("Tool") then
                local n = tool.Name:lower()
                if n:find("gun") or n:find("pistol") or n:find("sheriff") then
                    return "Sheriff"
                end
                if n:find("knife") or n:find("blade") or n:find("murder") then
                    return "Murderer"
                end
            end
        end
    end

    return "Innocent"
end

local function findMurderer()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == LocalPlayer then continue end
        if not plr.Character then continue end
        local hum = plr.Character:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 then continue end

        if getRole(plr) == "Murderer" then
            return plr
        end
    end
    return nil
end

--// ============================================================
--//  NOCLIP
--// ============================================================
local function enableNoclip()
    if noclipConn then return end
    noclipEnabled = true
    noclipConn = RunService.Stepped:Connect(function()
        if not noclipEnabled then return end
        local char = LocalPlayer.Character
        if not char then return end
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = false
            end
        end
    end)
end

local function disableNoclip()
    noclipEnabled = false
    if noclipConn then noclipConn:Disconnect(); noclipConn = nil end
    local char = LocalPlayer.Character
    if char then
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = true
            end
        end
    end
end

--// ============================================================
--//  FLY SETUP (velocity based)
--// ============================================================
local function setupFly()
    local char = LocalPlayer.Character
    if not char then return false end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end

    -- Cleanup old
    if bodyVelocity then bodyVelocity:Destroy(); bodyVelocity = nil end
    if bodyGyro then bodyGyro:Destroy(); bodyGyro = nil end

    bodyVelocity = Instance.new("BodyVelocity")
    bodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    bodyVelocity.Velocity = Vector3.zero
    bodyVelocity.P = 10000
    bodyVelocity.Parent = hrp

    bodyGyro = Instance.new("BodyGyro")
    bodyGyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
    bodyGyro.P = 10000
    bodyGyro.CFrame = hrp.CFrame
    bodyGyro.Parent = hrp

    flying = true
    return true
end

local function stopFly()
    flying = false
    if bodyVelocity then bodyVelocity:Destroy(); bodyVelocity = nil end
    if bodyGyro then bodyGyro:Destroy(); bodyGyro = nil end
end

--// ============================================================
--//  COIN DETECTION
--// ============================================================
local COIN_KEYWORDS = { "coin", "money", "token", "cash" }

local function isCoin(obj)
    if not obj or not obj.Parent then return false end
    if not (obj:IsA("BasePart") or obj:IsA("Model")) then return false end
    local n = obj.Name:lower()
    for _, kw in ipairs(COIN_KEYWORDS) do
        if n:find(kw) then return true end
    end
    return false
end

local function getCoinPosition(coin)
    if coin:IsA("BasePart") then return coin.Position end
    if coin:IsA("Model") then
        local primary = coin.PrimaryPart or coin:FindFirstChildWhichIsA("BasePart")
        if primary then return primary.Position end
    end
    return nil
end

--// ============================================================
--//  FIND NEAREST COIN
--// ============================================================
local function findNearestCoin()
    local char = LocalPlayer.Character
    if not char then return nil end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end

    local best, bestDist = nil, math.huge

    for _, obj in ipairs(workspace:GetDescendants()) do
        if isCoin(obj) and not collectedCoins[obj] then
            local pos = getCoinPosition(obj)
            if pos then
                local dist = (hrp.Position - pos).Magnitude
                if dist < bestDist and dist <= Config.MaxDistance then
                    bestDist = dist
                    best = obj
                end
            end
        end
    end

    return best
end

--// ============================================================
--//  COUNT ALL COINS
--// ============================================================
local function countAllCoins()
    local count = 0
    for _, obj in ipairs(workspace:GetDescendants()) do
        if isCoin(obj) then
            count = count + 1
        end
    end
    return count
end

--// ============================================================
--//  ANTI-MURDERER ESCAPE
--// ============================================================
local function escapeFromMurderer()
    if not Config.AntiMurderer then return false end

    local myChar = LocalPlayer.Character
    if not myChar then return false end
    local myHrp = myChar:FindFirstChild("HumanoidRootPart")
    if not myHrp then return false end

    local murderer = findMurderer()
    if not murderer or not murderer.Character then return false end
    local mHrp = murderer.Character:FindFirstChild("HumanoidRootPart")
    if not mHrp then return false end

    local dist = (myHrp.Position - mHrp.Position).Magnitude
    if dist > Config.DangerRange then return false end

    -- Тікаємо в протилежний бік
    local escapeDir = (myHrp.Position - mHrp.Position).Unit
    if bodyVelocity then
        bodyVelocity.Velocity = escapeDir * Config.FlySpeed * 3
    end
    return true
end

--// ============================================================
--//  SKIDFLING (Murderer)
--// ============================================================
local function SkidFling(TargetPlayer, duration)
    if not TargetPlayer or TargetPlayer == LocalPlayer then return false end
    if not TargetPlayer.Character then return false end

    local Character = LocalPlayer.Character
    local Humanoid = Character and Character:FindFirstChildOfClass("Humanoid")
    local RootPart = Humanoid and Humanoid.RootPart

    local TCharacter = TargetPlayer.Character
    local THumanoid = TCharacter:FindFirstChildOfClass("Humanoid")
    local TRootPart = THumanoid and THumanoid.RootPart
    local THead = TCharacter:FindFirstChild("Head")

    if not (Character and Humanoid and RootPart and THumanoid and TRootPart) then return false end

    if RootPart.Velocity.Magnitude < 50 then
        getgenv().AutoFarmOldPos = RootPart.CFrame
    end

    local FPos = function(BasePart, Pos, Ang)
        RootPart.CFrame = CFrame.new(BasePart.Position) * Pos * Ang
        pcall(function()
            Character:SetPrimaryPartCFrame(CFrame.new(BasePart.Position) * Pos * Ang)
        end)
        RootPart.Velocity = Vector3.new(9e7, 9e7 * 10, 9e7)
        RootPart.RotVelocity = Vector3.new(9e8, 9e8, 9e8)
    end

    local function SFBasePart(BasePart)
        local TimeToWait = duration or 2
        local Time = tick()
        local Angle = 0

        repeat
            if not RootPart or not THumanoid then break end
            if BasePart.Velocity.Magnitude < 50 then
                Angle = Angle + 100
                FPos(BasePart, CFrame.new(0, 1.5, 0) + THumanoid.MoveDirection * BasePart.Velocity.Magnitude / 1.25, CFrame.Angles(math.rad(Angle), 0, 0))
                task.wait()
                FPos(BasePart, CFrame.new(0, -1.5, 0) + THumanoid.MoveDirection * BasePart.Velocity.Magnitude / 1.25, CFrame.Angles(math.rad(Angle), 0, 0))
                task.wait()
                FPos(BasePart, CFrame.new(2.25, 1.5, -2.25) + THumanoid.MoveDirection * BasePart.Velocity.Magnitude / 1.25, CFrame.Angles(math.rad(Angle), 0, 0))
                task.wait()
                FPos(BasePart, CFrame.new(-2.25, -1.5, 2.25) + THumanoid.MoveDirection * BasePart.Velocity.Magnitude / 1.25, CFrame.Angles(math.rad(Angle), 0, 0))
                task.wait()
            else
                FPos(BasePart, CFrame.new(0, 1.5, THumanoid.WalkSpeed), CFrame.Angles(math.rad(90), 0, 0))
                task.wait()
                FPos(BasePart, CFrame.new(0, -1.5, -THumanoid.WalkSpeed), CFrame.Angles(0, 0, 0))
                task.wait()
                FPos(BasePart, CFrame.new(0, 1.5, TRootPart.Velocity.Magnitude / 1.25), CFrame.Angles(math.rad(90), 0, 0))
                task.wait()
                FPos(BasePart, CFrame.new(0, -1.5, -TRootPart.Velocity.Magnitude / 1.25), CFrame.Angles(0, 0, 0))
                task.wait()
            end
        until BasePart.Velocity.Magnitude > 500 
           or BasePart.Parent ~= TargetPlayer.Character 
           or tick() > Time + TimeToWait
    end

    local prevDestroy = workspace.FallenPartsDestroyHeight
    workspace.FallenPartsDestroyHeight = 0/0

    local BV = Instance.new("BodyVelocity")
    BV.Name = "AutoFarmFling"
    BV.Parent = RootPart
    BV.Velocity = Vector3.new(9e8, 9e8, 9e8)
    BV.MaxForce = Vector3.new(1/0, 1/0, 1/0)

    Humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, false)

    if TRootPart and THead then
        if (TRootPart.CFrame.p - THead.CFrame.p).Magnitude > 5 then
            SFBasePart(THead)
        else
            SFBasePart(TRootPart)
        end
    elseif TRootPart then
        SFBasePart(TRootPart)
    elseif THead then
        SFBasePart(THead)
    end

    BV:Destroy()
    Humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, true)

    -- Return to start
    task.wait(0.5)
    if getgenv().AutoFarmOldPos and RootPart then
        pcall(function()
            RootPart.CFrame = getgenv().AutoFarmOldPos
        end)
    end

    workspace.FallenPartsDestroyHeight = prevDestroy
    return true
end

--// ============================================================
--//  AUTO FLING MURDERER
--// ============================================================
local function autoFlingMurderer()
    if flingInProgress then return end
    flingInProgress = true

    local murderer = findMurderer()
    if not murderer then
        log("No Murderer found to fling")
        flingInProgress = false
        return
    end

    log("Auto-flinging Murderer: " .. murderer.Name)
    notify("💥 Auto Fling", "Flinging " .. murderer.Name, 3)

    -- Підлітаємо до Murderer-а
    local myChar = LocalPlayer.Character
    local murdererChar = murderer.Character
    if myChar and murdererChar then
        local myHrp = myChar:FindFirstChild("HumanoidRootPart")
        local mHrp = murdererChar:FindFirstChild("HumanoidRootPart")
        if myHrp and mHrp then
            task.wait(Config.FlingDelay)
            pcall(function()
                myHrp.CFrame = mHrp.CFrame * CFrame.new(2, 0, 2)
            end)
            task.wait(0.1)
        end
    end

    -- Флингаємо
    local ok = pcall(SkidFling, murderer, 2)
    if ok then
        log("Fling success: " .. murderer.Name)
        notify("✅ Fling", "Flinged " .. murderer.Name, 3)
    else
        log("Fling failed")
    end

    flingInProgress = false
end

--// ============================================================
--//  RESET ON ROUND
--// ============================================================
local function resetForNewRound()
    collectedCoins = {}
    currentTarget = nil
    totalCoinsFound = countAllCoins()
    roundStartTime = tick()
    flingInProgress = false
    log("New round — coins found: " .. totalCoinsFound)
end

--// ============================================================
--//  MAIN LOOP
--// ============================================================
local mainConn = nil
local lastCoinCount = 0
local coinCountTimer = 0

local function startLoop()
    if mainConn then mainConn:Disconnect() end

    mainConn = RunService.Heartbeat:Connect(function(dt)
        if not enabled then return end

        local char = LocalPlayer.Character
        if not char then return end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 then return end

        -- Перевірка: чи закінчився фарм (всі монети зібрані)
        coinCountTimer = coinCountTimer + dt
        if coinCountTimer > 2 then
            coinCountTimer = 0
            local remaining = countAllCoins()
            if remaining == 0 and Config.AutoFlingAfterFarm and not flingInProgress then
                log("All coins collected — auto flinging Murderer")
                task.spawn(autoFlingMurderer)
                return
            end
        end

        -- Anti-murderer escape
        if escapeFromMurderer() then
            return
        end

        -- Оновлення цілі
        local now = tick()
        if now - lastUpdate > Config.UpdateRate then
            lastUpdate = now
            currentTarget = findNearestCoin()
        end

        -- Летимо до цілі
        if currentTarget and currentTarget.Parent then
            local targetPos = getCoinPosition(currentTarget)
            if targetPos and bodyVelocity then
                local direction = (targetPos - hrp.Position)
                local dist = direction.Magnitude

                if dist < 3 then
                    -- Близько — просто продовжуємо (гра сама дасть підібрати)
                    bodyVelocity.Velocity = Vector3.zero
                else
                    -- Летимо в напрямку монети
                    bodyVelocity.Velocity = direction.Unit * Config.FlySpeed
                end
            end
        else
            -- Немає цілі — шукаємо знову
            currentTarget = findNearestCoin()
            if not currentTarget and bodyVelocity then
                bodyVelocity.Velocity = Vector3.zero
            end
        end
    end)
end

local function stopLoop()
    if mainConn then mainConn:Disconnect(); mainConn = nil end
    stopFly()
    currentTarget = nil
end

--// ============================================================
--//  CHARACTER EVENTS
--// ============================================================
LocalPlayer.CharacterAdded:Connect(function(char)
    task.wait(1.5)
    resetForNewRound()

    if enabled then
        -- Перезапуск noclip + fly
        disableNoclip()
        enableNoclip()
        task.wait(0.3)
        setupFly()
    end
end)

-- Виявлення смерті гравця
task.spawn(function()
    while task.wait(0.5) do
        if not enabled then continue end
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 then
            if not flingInProgress and Config.AutoFlingAfterFarm then
                log("Player died — auto flinging Murderer")
                task.spawn(autoFlingMurderer)
            end
        end
    end
end)

--// ============================================================
--//  AUTO-START DETECTION
--// ============================================================
task.spawn(function()
    while task.wait(2) do
        if Config.AutoStart and Config.Enabled then
            local char = LocalPlayer.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            -- Якщо раунд почався (новий персонаж) — переконатись що налаштування активні
            if hum and hum.Health > 0 then
                if not noclipEnabled then enableNoclip() end
                if not flying then setupFly() end
            end
        end
    end
end)

--// ============================================================
--//  MODULE API
--// ============================================================
local AutoFarm = {}
AutoFarm.__index = AutoFarm

function AutoFarm.new()
    return setmetatable({}, AutoFarm)
end

function AutoFarm:setEnabled(state)
    enabled = state
    Config.Enabled = state

    if state then
        resetForNewRound()
        enableNoclip()
        task.wait(0.2)
        setupFly()
        startLoop()
        log("ON — Auto Start: " .. tostring(Config.AutoStart))
        notify("💰 Auto Farm", "Enabled", 2)
    else
        stopLoop()
        disableNoclip()
        log("OFF")
        notify("💰 Auto Farm", "Disabled", 2)
    end
end

function AutoFarm:setFlySpeed(v) Config.FlySpeed = v end
function AutoFarm:setMaxDistance(v) Config.MaxDistance = v end
function AutoFarm:setAntiMurderer(v) Config.AntiMurderer = v end
function AutoFarm:setAutoFling(v) Config.AutoFlingAfterFarm = v end
function AutoFarm:setAutoStart(v) Config.AutoStart = v end

function AutoFarm:getStats()
    return {
        CollectedCoins = totalCoinsFound,
        TotalCoins = totalCoinsFound,
        RoundTime = math.floor(tick() - roundStartTime),
    }
end

log("═══════════════════════════════════")
log("TrustHub Auto Farm v2.0 loaded")
log("Auto round start | Noclip fly | Auto fling")
log("═══════════════════════════════════")

return AutoFarm.new()
