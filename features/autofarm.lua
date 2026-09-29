--// ╔══════════════════════════════════════════════════════════════╗
--// ║  TrustHub Auto Farm v9.0 — Smooth Edition                    ║
--// ║  Speed 22 • No jitter • Auto fling Murderer                  ║
--// ╚══════════════════════════════════════════════════════════════╝

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")

local LocalPlayer = Players.LocalPlayer

--// ============================================================
--//  FIXED CONFIG
--// ============================================================
local FLY_SPEED       = 22
local COIN_RANGE      = 3       -- studs — наскільки близько підлетіти
local UPDATE_RATE     = 0.1     -- як часто шукати нову ціль
local AUTO_FLING      = true    -- флинг Murderer-а після фарму
local FLING_DELAY     = 1.5
local LOG_ENABLED     = true
local NOTIFY_ENABLED  = true

--// ============================================================
--//  STATE
--// ============================================================
local enabled = false
local currentTarget = nil
local currentTargetPos = nil
local lastTargetUpdate = 0
local collectedCount = 0
local flingInProgress = false
local bodyVelocity = nil
local bodyGyro = nil
local noclipConn = nil
local mainConn = nil
local deathConn = nil
local allCollected = false

--// ============================================================
--//  LOG / NOTIFY
--// ============================================================
local function log(msg)
    if LOG_ENABLED then print("[AutoFarm] " .. msg) end
end

local function notify(title, text, duration)
    if not NOTIFY_ENABLED then return end
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

--// ============================================================
--//  COIN DETECTION
--// ============================================================
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
    if not hrp then return nil, nil end
    local best, bestDist = nil, math.huge
    local bestPos = nil
    for _, obj in ipairs(workspace:GetDescendants()) do
        if isCoin(obj) then
            local pos = getCoinPosition(obj)
            if pos then
                local d = (hrp.Position - pos).Magnitude
                if d < bestDist then
                    bestDist = d
                    best = obj
                    bestPos = pos
                end
            end
        end
    end
    return best, bestPos
end

--// ============================================================
--//  NOCLIP
--// ============================================================
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

--// ============================================================
--//  FLY SETUP — BodyVelocity (плавний)
--// ============================================================
local function setupFly()
    local char, hum, hrp = getChar()
    if not hrp then return false end

    -- Відключаємо контроль гравця
    if hum then
        pcall(function()
            hum.PlatformStand = true
            hum:ChangeState(Enum.HumanoidStateType.Physics)
        end)
    end

    -- Очищаємо старі
    if bodyVelocity then bodyVelocity:Destroy() end
    if bodyGyro then bodyGyro:Destroy() end

    -- BodyVelocity з м'яким P (плавність!)
    bodyVelocity = Instance.new("BodyVelocity")
    bodyVelocity.Name = "AutoFarmFly"
    bodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    bodyVelocity.Velocity = Vector3.zero
    bodyVelocity.P = 400   -- ⚠ низький P = плавний рух без ривків
    bodyVelocity.Parent = hrp

    -- BodyGyro — тримає вертикально, без обертання
    bodyGyro = Instance.new("BodyGyro")
    bodyGyro.Name = "AutoFarmGyro"
    bodyGyro.MaxTorque = Vector3.new(0, math.huge, 0)  -- тільки Y
    bodyGyro.P = 3000
    bodyGyro.D = 500
    bodyGyro.CFrame = hrp.CFrame
    bodyGyro.Parent = hrp

    log("Fly setup done (BodyVelocity, P=400)")
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

--// ============================================================
--//  SKIDFLING
--// ============================================================
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

--// ============================================================
--//  AUTO FLING MURDERER
--// ============================================================
local function autoFlingMurderer()
    if flingInProgress then return end
    flingInProgress = true

    local murderer = findMurderer()
    if not murderer then
        log("No Murderer found")
        flingInProgress = false
        return
    end

    log("Auto-flinging: " .. murderer.Name)
    notify("💥 Auto Fling", "Flinging " .. murderer.Name, 3)

    task.wait(FLING_DELAY)

    -- Підлітаємо до Murderer-а
    local char, hum, hrp = getChar()
    local mChar = murderer.Character
    if hrp and mChar then
        local mHrp = mChar:FindFirstChild("HumanoidRootPart")
        if mHrp then
            pcall(function()
                hrp.CFrame = mHrp.CFrame * CFrame.new(2, 0, 2)
            end)
            task.wait(0.1)
        end
    end

    local ok = pcall(SkidFling, murderer, 2)
    if ok then
        log("Fling OK: " .. murderer.Name)
        notify("✅ Fling", "Flinged " .. murderer.Name, 3)
    else
        log("Fling failed")
    end

    flingInProgress = false
end

--// ============================================================
--//  RESET FOR NEW ROUND
--// ============================================================
local function resetForNewRound()
    currentTarget = nil
    currentTargetPos = nil
    collectedCount = 0
    allCollected = false
    flingInProgress = false
    log("New round — coins: " .. countAllCoins())
end

--// ============================================================
--//  DEATH DETECTION
--// ============================================================
local function startDeathCheck()
    if deathConn then deathConn:Disconnect() end
    deathConn = RunService.Heartbeat:Connect(function()
        if not enabled then return end
        local char = LocalPlayer.Character
        if not char then return end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum and hum.Health <= 0 and AUTO_FLING and not flingInProgress then
            log("Player died → auto-flinging Murderer")
            task.spawn(autoFlingMurderer)
        end
    end)
end

--// ============================================================
--//  MAIN LOOP — Smooth BodyVelocity flight
--// ============================================================
local coinCheckTimer = 0

local function startMainLoop()
    if mainConn then mainConn:Disconnect() end

    mainConn = RunService.Heartbeat:Connect(function(dt)
        if not enabled then return end

        local char, hum, hrp = getChar()
        if not hrp or not bodyVelocity then return end

        -- Перевірка чи всі монети зібрані
        coinCheckTimer = coinCheckTimer + dt
        if coinCheckTimer > 2 then
            coinCheckTimer = 0
            local remaining = countAllCoins()
            if remaining == 0 and not allCollected then
                allCollected = true
                log("All coins collected")
                if AUTO_FLING and not flingInProgress then
                    task.spawn(autoFlingMurderer)
                end
                return
            end
        end

        -- Оновлення цілі
        local now = tick()
        if now - lastTargetUpdate > UPDATE_RATE or not currentTarget or not currentTarget.Parent then
            lastTargetUpdate = now
            currentTarget, currentTargetPos = findNearestCoin()
        end

        -- Рух до цілі (плавний, з фіксованою швидкістю)
        if currentTarget and currentTargetPos then
            local direction = currentTargetPos - hrp.Position
            local dist = direction.Magnitude

            if dist > COIN_RANGE then
                -- Плавний політ до цілі
                bodyVelocity.Velocity = direction.Unit * FLY_SPEED
            else
                -- Близько — зупиняємось, чекаємо підбору
                bodyVelocity.Velocity = Vector3.zero
                collectedCount = collectedCount + 1
                currentTarget = nil
                currentTargetPos = nil
            end
        else
            -- Немає цілі — стоїмо
            bodyVelocity.Velocity = Vector3.zero
        end
    end)
end

local function stopMainLoop()
    if mainConn then mainConn:Disconnect(); mainConn = nil end
    if deathConn then deathConn:Disconnect(); deathConn = nil end
end

--// ============================================================
--//  CHARACTER RESPAWN
--// ============================================================
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

--// ============================================================
--//  MODULE
--// ============================================================
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

-- Stubs для сумісності
function AutoFarm:setSpeed() end
function AutoFarm:setFlySpeed() end
function AutoFarm:setAntiMurderer() end
function AutoFarm:setAutoStart() end

function AutoFarm:setAutoFling(v)
    AUTO_FLING = v
    log("Auto Fling: " .. tostring(v))
end

function AutoFarm:setAutoKill() end
function AutoFarm:setKillDelay() end
function AutoFarm:killAll() end

function AutoFarm:getStats()
    return {
        CoinsCollected = collectedCount,
        Speed = FLY_SPEED,
    }
end

log("═══════════════════════════════════")
log("TrustHub Auto Farm v9.0 (Smooth)")
log("Speed: " .. FLY_SPEED .. " • No jitter")
log("═══════════════════════════════════")

return AutoFarm.new()
