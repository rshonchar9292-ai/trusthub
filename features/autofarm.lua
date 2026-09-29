--// ╔══════════════════════════════════════════════════════════════╗
--// ║  TrustHub Auto Farm v8.0 — Speed Limited                     ║
--// ║  Speed: 22 studs/s (fixed, no jitter)                        ║
--// ╚══════════════════════════════════════════════════════════════╝

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")

local LocalPlayer = Players.LocalPlayer

--// FIXED CONFIG
local FLY_SPEED     = 22
local UPDATE_RATE   = 0.15
local AUTO_FLING    = true
local FLING_DELAY   = 1.0
local ANTI_MURDERER = true
local DANGER_RANGE  = 35
local LOG_ENABLED   = true

local enabled = false
local currentTarget = nil
local lastTargetUpdate = 0
local collectedCoins = {}
local totalCoinsCollected = 0
local roundStartTime = 0
local flingInProgress = false

local bodyVelocity = nil
local bodyGyro = nil
local noclipConn = nil
local mainLoopConn = nil
local deathCheckConn = nil

local function log(msg)
    if LOG_ENABLED then print("[AutoFarm] " .. msg) end
end

local function notify(title, text, duration)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = title, Text = text, Duration = duration or 2,
        })
    end)
end

local function getChar()
    local char = LocalPlayer.Character
    if not char then return nil end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hum or not hrp then return nil end
    if hum.Health <= 0 then return nil end
    return char, hum, hrp
end

--// ROLE DETECTION
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
            if n:find("gun") or n:find("pistol") or n:find("sheriff") then
                return "Sheriff"
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
        if getRole(plr) == "Murderer" then return plr end
    end
    return nil
end

--// COINS
local COIN_WORDS = { "coin", "money", "token", "cash", "gem", "gold" }

local function isCoin(obj)
    if not obj or not obj.Parent then return false end
    if not (obj:IsA("BasePart") or obj:IsA("Model")) then return false end
    local n = obj.Name:lower()
    for _, w in ipairs(COIN_WORDS) do
        if n:find(w) then return true end
    end
    return false
end

local function getCoinPosition(coin)
    if not coin or not coin.Parent then return nil end
    if coin:IsA("BasePart") then return coin.Position end
    if coin:IsA("Model") then
        local p = coin.PrimaryPart or coin:FindFirstChildWhichIsA("BasePart")
        return p and p.Position or nil
    end
    return nil
end

local function countAllCoins()
    local count = 0
    for _, obj in ipairs(workspace:GetDescendants()) do
        if isCoin(obj) then count = count + 1 end
    end
    return count
end

local function findNearestCoin()
    local char, hum, hrp = getChar()
    if not hrp then return nil end
    local best, bestDist = nil, math.huge
    for _, obj in ipairs(workspace:GetDescendants()) do
        if isCoin(obj) and not collectedCoins[obj] then
            local pos = getCoinPosition(obj)
            if pos then
                local d = (hrp.Position - pos).Magnitude
                if d < bestDist then
                    bestDist = d
                    best = obj
                end
            end
        end
    end
    return best
end

--// NOCLIP
local function enableNoclip()
    if noclipConn then noclipConn:Disconnect() end
    noclipConn = RunService.Stepped:Connect(function()
        if not enabled then return end
        local char = LocalPlayer.Character
        if not char then return end
        for _, p in ipairs(char:GetDescendants()) do
            if p:IsA("BasePart") then
                p.CanCollide = false
            end
        end
    end)
end

local function disableNoclip()
    if noclipConn then noclipConn:Disconnect(); noclipConn = nil end
    local char = LocalPlayer.Character
    if char then
        for _, p in ipairs(char:GetDescendants()) do
            if p:IsA("BasePart") then p.CanCollide = true end
        end
    end
end

--// FLY SETUP — BodyVelocity (плавно і з обмеженням швидкості)
local function setupFly()
    local char, hum, hrp = getChar()
    if not hrp then return false end

    if hum then
        pcall(function()
            hum.PlatformStand = true
            hum:ChangeState(Enum.HumanoidStateType.Physics)
        end)
    end

    if bodyVelocity then bodyVelocity:Destroy() end
    if bodyGyro then bodyGyro:Destroy() end

    -- BodyVelocity з м'яким P — плавно, без ривків
    bodyVelocity = Instance.new("BodyVelocity")
    bodyVelocity.Name = "AutoFarmFly"
    bodyVelocity.MaxForce = Vector3.new(50000, 0, 50000)  -- ⚠ ТІЛЬКИ X/Z, без Y
    bodyVelocity.Velocity = Vector3.zero
    bodyVelocity.P = 500          -- низький P = плавно
    bodyVelocity.Parent = hrp

    -- BodyGyro тримає вертикально
    bodyGyro = Instance.new("BodyGyro")
    bodyGyro.MaxTorque = Vector3.new(0, math.huge, 0)
    bodyGyro.P = 3000
    bodyGyro.D = 500
    bodyGyro.CFrame = hrp.CFrame
    bodyGyro.Parent = hrp

    log("Fly setup done (BodyVelocity, P=500, Y locked)")
    return true
end

local function stopFly()
    if bodyVelocity then bodyVelocity:Destroy(); bodyVelocity = nil end
    if bodyGyro then bodyGyro:Destroy(); bodyGyro = nil end
    local char = LocalPlayer.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            pcall(function()
                hum.PlatformStand = false
                hum:ChangeState(Enum.HumanoidStateType.GettingUp)
            end)
        end
    end
end

--// ANTI-MURDERER
local function shouldEscapeFromMurderer()
    if not ANTI_MURDERER then return false end
    local char, hum, hrp = getChar()
    if not hrp then return false end
    local murderer = findMurderer()
    if not murderer or not murderer.Character then return false end
    local mHrp = murderer.Character:FindFirstChild("HumanoidRootPart")
    if not mHrp then return false end
    return (hrp.Position - mHrp.Position).Magnitude <= DANGER_RANGE
end

--// SKIDFLING
local function SkidFling(TargetPlayer, duration)
    if not TargetPlayer or TargetPlayer == LocalPlayer then return false end
    if not TargetPlayer.Character then return false end

    local Character = LocalPlayer.Character
    if not Character then return false end
    local Humanoid = Character:FindFirstChildOfClass("Humanoid")
    local RootPart = Humanoid and Humanoid.RootPart
    if not Humanoid or not RootPart then return false end

    local TCharacter = TargetPlayer.Character
    local THumanoid = TCharacter:FindFirstChildOfClass("Humanoid")
    local TRootPart = THumanoid and THumanoid.RootPart
    local THead = TCharacter:FindFirstChild("Head")
    if not (THumanoid and TRootPart) then return false end

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
    end

    BV:Destroy()
    Humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, true)

    task.wait(0.3)
    if getgenv().AutoFarmOldPos and RootPart then
        pcall(function() RootPart.CFrame = getgenv().AutoFarmOldPos end)
    end

    workspace.FallenPartsDestroyHeight = prevDestroy
    return true
end

local function autoFlingMurderer()
    if flingInProgress then return end
    flingInProgress = true

    local murderer = findMurderer()
    if not murderer then
        log("No Murderer")
        flingInProgress = false
        return
    end

    log("Auto-flinging: " .. murderer.Name)
    task.wait(FLING_DELAY)

    local char, hum, hrp = getChar()
    local mChar = murderer.Character
    if hrp and mChar then
        local mHrp = mChar:FindFirstChild("HumanoidRootPart")
        if mHrp then
            pcall(function() hrp.CFrame = mHrp.CFrame * CFrame.new(2, 0, 2) end)
            task.wait(0.1)
        end
    end

    local ok = pcall(SkidFling, murderer, 2)
    if ok then
        log("Fling OK: " .. murderer.Name)
        notify("✅ Fling", "Flinged " .. murderer.Name, 3)
    end
    flingInProgress = false
end

local function resetForNewRound()
    collectedCoins = {}
    currentTarget = nil
    totalCoinsCollected = 0
    roundStartTime = tick()
    flingInProgress = false
    log("New round — coins: " .. countAllCoins())
end

local function startDeathCheck()
    if deathCheckConn then deathCheckConn:Disconnect() end
    deathCheckConn = RunService.Heartbeat:Connect(function()
        if not enabled then return end
        local char = LocalPlayer.Character
        if not char then return end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum and hum.Health <= 0 and AUTO_FLING and not flingInProgress then
            task.spawn(autoFlingMurderer)
        end
    end)
end

--// MAIN LOOP (BodyVelocity — обмежена швидкість)
local coinCheckTimer = 0

local function startMainLoop()
    if mainLoopConn then mainLoopConn:Disconnect() end

    mainLoopConn = RunService.Heartbeat:Connect(function(dt)
        if not enabled then return end

        local char, hum, hrp = getChar()
        if not hrp then return end

        -- Anti-Murderer
        if shouldEscapeFromMurderer() then
            local murderer = findMurderer()
            if murderer and murderer.Character and bodyVelocity then
                local mHrp = murderer.Character:FindFirstChild("HumanoidRootPart")
                if mHrp then
                    local escapeDir = (hrp.Position - mHrp.Position).Unit
                    bodyVelocity.Velocity = Vector3.new(escapeDir.X, 0, escapeDir.Z).Unit * FLY_SPEED * 2
                end
            end
            return
        end

        -- Перевірка монет
        coinCheckTimer = coinCheckTimer + dt
        if coinCheckTimer > 3 then
            coinCheckTimer = 0
            if countAllCoins() == 0 and AUTO_FLING and not flingInProgress then
                task.spawn(autoFlingMurderer)
                return
            end
        end

        -- Оновлення цілі
        local now = tick()
        if now - lastTargetUpdate > UPDATE_RATE or not currentTarget or not currentTarget.Parent then
            lastTargetUpdate = now
            currentTarget = findNearestCoin()
        end

        -- Рух (швидкість 22, тільки X/Z)
        if currentTarget and bodyVelocity then
            local pos = getCoinPosition(currentTarget)
            if pos then
                local direction = pos - hrp.Position
                local dist = direction.Magnitude

                if dist > 2 then
                    -- ОБМЕЖЕННЯ: тільки горизонтальний рух
                    local horizontalDir = Vector3.new(direction.X, 0, direction.Z)
                    if horizontalDir.Magnitude > 0 then
                        bodyVelocity.Velocity = horizontalDir.Unit * FLY_SPEED
                    end
                else
                    bodyVelocity.Velocity = Vector3.zero
                    if not collectedCoins[currentTarget] then
                        collectedCoins[currentTarget] = true
                        totalCoinsCollected = totalCoinsCollected + 1
                    end
                    currentTarget = nil
                end
            else
                currentTarget = nil
            end
        elseif bodyVelocity then
            bodyVelocity.Velocity = Vector3.zero
        end
    end)
end

local function stopMainLoop()
    if mainLoopConn then mainLoopConn:Disconnect(); mainLoopConn = nil end
    if deathCheckConn then deathCheckConn:Disconnect(); deathCheckConn = nil end
end

LocalPlayer.CharacterAdded:Connect(function(char)
    task.wait(1.5)
    resetForNewRound()
    if enabled then
        disableNoclip()
        task.wait(0.1)
        enableNoclip()
        task.wait(0.2)
        setupFly()
    end
end)

--// MODULE
local AutoFarm = {}
AutoFarm.__index = AutoFarm

function AutoFarm.new()
    return setmetatable({}, AutoFarm)
end

function AutoFarm:setEnabled(state)
    enabled = state
    if state then
        resetForNewRound()
        enableNoclip()
        task.wait(0.2)
        setupFly()
        startMainLoop()
        startDeathCheck()
        log("═══ Auto Farm ENABLED (Speed: " .. FLY_SPEED .. ") ═══")
        notify("💰 Auto Farm", "Enabled (Speed: " .. FLY_SPEED .. ")", 3)
    else
        stopMainLoop()
        stopFly()
        disableNoclip()
        log("Auto Farm DISABLED")
        notify("💰 Auto Farm", "Disabled", 2)
    end
end

-- Stubs
function AutoFarm:setSpeed() end
function AutoFarm:setFlySpeed() end
function AutoFarm:setAutoFling() end
function AutoFarm:setAntiMurderer() end
function AutoFarm:setAutoStart() end
function AutoFarm:setAutoKill() end
function AutoFarm:setKillDelay() end

function AutoFarm:getStats()
    return { CoinsCollected = totalCoinsCollected, Speed = FLY_SPEED }
end

log("═══════════════════════════════════")
log("TrustHub Auto Farm v8.0")
log("Speed: " .. FLY_SPEED .. " studs/s")
log("═══════════════════════════════════")

return AutoFarm.new()
