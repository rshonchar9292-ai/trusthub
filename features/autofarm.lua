--// ╔══════════════════════════════════════════════════════════════╗
--// ║  TrustHub Auto Farm v11.2 — Fixed Coin Collection             ║
--// ║  Speed 22 • SkidFling • Auto-fling on death                   ║
--// ╚══════════════════════════════════════════════════════════════╝

local Players      = game:GetService("Players")
local RunService   = game:GetService("RunService")
local Workspace    = game:GetService("Workspace")
local StarterGui   = game:GetService("StarterGui")
local VirtualUser  = game:GetService("VirtualUser")

local LocalPlayer  = Players.LocalPlayer

--// ============================================================
--//  CONFIG
--// ============================================================
local CONFIG = {
    Speed           = 22,
    TargetRefresh   = 0.25,
    CacheRefresh    = 3,
    MaxTargetTime   = 4,
    AutoFling       = true,
    AutoFlingDelay  = 0.5,
    AutoKill        = false,
    KillDelay       = 3,
    AntiAFK         = true,
    Verbose         = true,
}

--// ============================================================
--//  STATE
--// ============================================================
local enabled          = false
local coinCache        = {}
local cacheDirty       = true
local lastCacheTime    = 0
local currentTarget    = nil
local currentCoinPos   = nil
local lastTargetTime   = 0
local targetAcquiredAt = 0
local flyVel           = nil
local flyAtt           = nil
local flyAlign         = nil
local noclipConn       = nil
local mainConn         = nil
local deathConn        = nil
local afkConn          = nil
local flingInProgress  = false
local hasFlinged       = false
local allCollected     = false
local collectedCount   = 0
local getgenv = getgenv or function() return _G end

--// ============================================================
--//  LOGGING
--// ============================================================
local function log(msg)
    if CONFIG.Verbose then print("[AutoFarm] " .. msg) end
end

local function notify(title, text, duration)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = title, Text = text, Duration = duration or 2,
        })
    end)
end

--// ============================================================
--//  CHARACTER
--// ============================================================
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
            if n:find("knife") or n:find("blade") then return "Murderer" end
        end
    end
    for _, tool in ipairs(char:GetChildren()) do
        if tool:IsA("Tool") then
            local n = tool.Name:lower()
            if n:find("gun") or n:find("pistol") or n:find("revolver") then
                return "Sheriff"
            end
        end
    end
    return "Innocent"
end

local function findMurderer()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character then
            local hum = plr.Character:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health > 0 and getRole(plr) == "Murderer" then
                return plr
            end
        end
    end
    return nil
end

--// ============================================================
--//  SKIDFLING
--// ============================================================
local function SkidFling(TargetPlayer)
    if not TargetPlayer or TargetPlayer == LocalPlayer then return false end
    if not TargetPlayer.Character then return false end

    local Character = LocalPlayer.Character
    if not Character then return false end

    local Humanoid = Character:FindFirstChildOfClass("Humanoid")
    local RootPart = Humanoid and Humanoid.RootPart
    if not Humanoid or not RootPart then return false end

    local TCharacter = TargetPlayer.Character
    if not TCharacter then return false end

    local THumanoid = TCharacter:FindFirstChildOfClass("Humanoid")
    local TRootPart = THumanoid and THumanoid.RootPart
    local THead = TCharacter:FindFirstChild("Head")
    local Accessory = TCharacter:FindFirstChildOfClass("Accessory")
    local Handle = Accessory and Accessory:FindFirstChild("Handle")

    if not THumanoid then return false end

    if RootPart.Velocity.Magnitude < 50 then
        getgenv().AutoFarmOldPos = RootPart.CFrame
    end

    if THumanoid.Sit then
        log(TargetPlayer.Name .. " is sitting — skip")
        return false
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
        local TimeToWait = 2
        local Time = tick()
        local Angle = 0
        repeat
            if not RootPart or not THumanoid then break end
            if not BasePart or not BasePart.Parent then break end

            if BasePart.Velocity.Magnitude < 50 then
                Angle = Angle + 100
                FPos(BasePart, CFrame.new(0, 1.5, 0) + THumanoid.MoveDirection * BasePart.Velocity.Magnitude / 1.25, CFrame.Angles(math.rad(Angle), 0, 0))
                task.wait()
                FPos(BasePart, CFrame.new(0, -1.5, 0) + THumanoid.MoveDirection * BasePart.Velocity.Magnitude / 1.25, CFrame.Angles(math.rad(Angle), 0, 0))
                task.wait()
                FPos(BasePart, CFrame.new(0, 1.5, 0) + THumanoid.MoveDirection * BasePart.Velocity.Magnitude / 1.25, CFrame.Angles(math.rad(Angle), 0, 0))
                task.wait()
                FPos(BasePart, CFrame.new(0, -1.5, 0) + THumanoid.MoveDirection * BasePart.Velocity.Magnitude / 1.25, CFrame.Angles(math.rad(Angle), 0, 0))
                task.wait()
                FPos(BasePart, CFrame.new(0, 1.5, 0) + THumanoid.MoveDirection, CFrame.Angles(math.rad(Angle), 0, 0))
                task.wait()
                FPos(BasePart, CFrame.new(0, -1.5, 0) + THumanoid.MoveDirection, CFrame.Angles(math.rad(Angle), 0, 0))
                task.wait()
            else
                FPos(BasePart, CFrame.new(0, 1.5, THumanoid.WalkSpeed), CFrame.Angles(math.rad(90), 0, 0))
                task.wait()
                FPos(BasePart, CFrame.new(0, -1.5, -THumanoid.WalkSpeed), CFrame.Angles(0, 0, 0))
                task.wait()
                FPos(BasePart, CFrame.new(0, 1.5, THumanoid.WalkSpeed), CFrame.Angles(math.rad(90), 0, 0))
                task.wait()
                FPos(BasePart, CFrame.new(0, -1.5, 0), CFrame.Angles(math.rad(90), 0, 0))
                task.wait()
                FPos(BasePart, CFrame.new(0, -1.5, 0), CFrame.Angles(0, 0, 0))
                task.wait()
                FPos(BasePart, CFrame.new(0, -1.5, 0), CFrame.Angles(math.rad(90), 0, 0))
                task.wait()
                FPos(BasePart, CFrame.new(0, -1.5, 0), CFrame.Angles(0, 0, 0))
                task.wait()
            end
        until Time + TimeToWait < tick()
    end

    local prevFPDH = Workspace.FallenPartsDestroyHeight
    Workspace.FallenPartsDestroyHeight = 0/0

    local BV = Instance.new("BodyVelocity")
    BV.Parent = RootPart
    BV.Velocity = Vector3.new(0, 0, 0)
    BV.MaxForce = Vector3.new(9e9, 9e9, 9e9)

    Humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, false)

    if TRootPart then
        SFBasePart(TRootPart)
    elseif THead then
        SFBasePart(THead)
    elseif Handle then
        SFBasePart(Handle)
    end

    BV:Destroy()
    Humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, true)

    if getgenv().AutoFarmOldPos then
        local deadline = tick() + 2
        repeat
            if RootPart and RootPart.Parent then
                RootPart.CFrame = getgenv().AutoFarmOldPos * CFrame.new(0, 0.5, 0)
                pcall(function()
                    Character:SetPrimaryPartCFrame(getgenv().AutoFarmOldPos * CFrame.new(0, 0.5, 0))
                end)
                pcall(function() Humanoid:ChangeState("GettingUp") end)
                for _, part in pairs(Character:GetChildren()) do
                    if part:IsA("BasePart") then
                        part.Velocity = Vector3.zero
                        part.RotVelocity = Vector3.zero
                    end
                end
            end
            task.wait()
        until (RootPart.Position - getgenv().AutoFarmOldPos.p).Magnitude < 25 or tick() > deadline
    end

    Workspace.FallenPartsDestroyHeight = prevFPDH
    return true
end

--// ============================================================
--//  AUTO FLING MURDERER
--// ============================================================
local function autoFlingMurderer()
    if flingInProgress then return end
    if not CONFIG.AutoFling then return end

    flingInProgress = true

    local murderer = findMurderer()
    if not murderer then
        log("Murderer не знайдено")
        flingInProgress = false
        return
    end

    log("Auto-fling: " .. murderer.Name)
    notify("💥 Auto Fling", "Flinging " .. murderer.Name, 3)

    task.wait(CONFIG.AutoFlingDelay)

    for attempt = 1, 2 do
        if not murderer or not murderer.Parent then break end
        if not murderer.Character then break end

        local ok, err = pcall(SkidFling, murderer)
        if ok then
            log("Fling OK: " .. murderer.Name .. " (attempt " .. attempt .. ")")
            break
        else
            log("Fling failed (attempt " .. attempt .. "): " .. tostring(err))
            task.wait(0.3)
        end
    end

    flingInProgress = false
end

--// ============================================================
--//  COIN CACHE
--// ============================================================
local COIN_WORDS = { "coin", "money", "token", "cash", "gem", "gold", "diamond" }

local function isCoin(obj)
    if not obj or not obj.Parent then return false end
    if not (obj:IsA("BasePart") or obj:IsA("Model")) then return false end
    local n = obj.Name:lower()
    for _, w in ipairs(COIN_WORDS) do
        if n:find(w) then return true end
    end
    return false
end

local function getCoinPart(obj)
    if not obj or not obj.Parent then return nil end
    if obj:IsA("BasePart") then return obj end
    if obj:IsA("Model") then
        return obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
    end
    return nil
end

local function rebuildCache()
    coinCache = {}
    local count = 0
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if isCoin(obj) then
            local part = getCoinPart(obj)
            if part then
                coinCache[part] = true
                count = count + 1
            end
        end
    end
    cacheDirty = false
    lastCacheTime = tick()
    return count
end

local function refreshCacheIfNeeded()
    if cacheDirty or (tick() - lastCacheTime) > CONFIG.CacheRefresh then
        rebuildCache()
    end
end

Workspace.DescendantAdded:Connect(function(obj)
    if isCoin(obj) then
        local part = getCoinPart(obj)
        if part then coinCache[part] = true end
    end
end)

--// ============================================================
--//  FIND NEAREST COIN
--// ============================================================
local function findNearestCoin()
    local _, _, hrp = getChar()
    if not hrp then return nil, nil end

    local best, bestDist, bestPos = nil, math.huge, nil
    for part in pairs(coinCache) do
        if not part.Parent then
            coinCache[part] = nil
            continue
        end
        local d = (hrp.Position - part.Position).Magnitude
        if d < bestDist then
            bestDist = d
            best = part
            bestPos = part.Position
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
            if p:IsA("BasePart") and p.CanCollide then
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
--//  FLY
--// ============================================================
local function setupFly()
    local char, hum, hrp = getChar()
    if not hrp then return false end

    if hum then hum.PlatformStand = true end

    if flyVel then flyVel:Destroy() end
    if flyAlign then flyAlign:Destroy() end
    if flyAtt then flyAtt:Destroy() end

    flyAtt = Instance.new("Attachment")
    flyAtt.Name = "AutoFarmAtt"
    flyAtt.Parent = hrp

    flyVel = Instance.new("LinearVelocity")
    flyVel.Name = "AutoFarmVel"
    flyVel.Attachment0 = flyAtt
    flyVel.MaxForce = math.huge
    flyVel.RelativeTo = Enum.ActuatorRelativeTo.World
    flyVel.VectorVelocity = Vector3.zero
    flyVel.Parent = hrp

    flyAlign = Instance.new("AlignOrientation")
    flyAlign.Name = "AutoFarmAlign"
    flyAlign.Attachment0 = flyAtt
    flyAlign.Mode = Enum.OrientationAlignmentMode.OneAttachment
    flyAlign.RigidityEnabled = true
    flyAlign.Parent = hrp

    log("Fly setup (Speed: " .. CONFIG.Speed .. ")")
    return true
end

local function stopFly()
    if flyVel then flyVel:Destroy(); flyVel = nil end
    if flyAlign then flyAlign:Destroy(); flyAlign = nil end
    if flyAtt then flyAtt:Destroy(); flyAtt = nil end

    local char = LocalPlayer.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            pcall(function() hum.PlatformStand = false end)
        end
    end
end

--// ============================================================
--//  ANTI-AFK
--// ============================================================
local function startAntiAFK()
    if afkConn then afkConn:Disconnect() end
    afkConn = LocalPlayer.Idled:Connect(function()
        if not CONFIG.AntiAFK then return end
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
        end)
    end)
end

--// ============================================================
--//  ROUND RESET
--// ============================================================
local function resetRound()
    currentTarget    = nil
    currentCoinPos   = nil
    allCollected     = false
    flingInProgress  = false
    hasFlinged       = false
    collectedCount   = 0
    targetAcquiredAt = 0
    cacheDirty       = true
    rebuildCache()
    log("Round reset — coins: " .. tostring(#coinCache))
end

--// ============================================================
--//  DEATH CHECK
--// ============================================================
local function startDeathCheck()
    if deathConn then deathConn:Disconnect() end
    deathConn = RunService.Heartbeat:Connect(function()
        if not enabled then return end
        if hasFlinged then return end
        if flingInProgress then return end

        local char = LocalPlayer.Character
        if not char then return end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum and hum.Health <= 0 then
            if CONFIG.AutoFling then
                hasFlinged = true
                log("Ти помер → авто-флинг Murderer-а")
                task.spawn(autoFlingMurderer)
            end
        end
    end)
end

--// ============================================================
--//  MAIN LOOP — Fixed (летимо прямо в монету)
--// ============================================================
local roundCheckTimer = 0

local function startMainLoop()
    if mainConn then mainConn:Disconnect() end

    mainConn = RunService.Heartbeat:Connect(function(dt)
        if not enabled then return end

        local char, hum, hrp = getChar()
        if not hrp or not flyVel then return end

        --// Перевірка нового раунду / всі монети зібрані
        roundCheckTimer = roundCheckTimer + dt
        if roundCheckTimer > 2 then
            roundCheckTimer = 0
            refreshCacheIfNeeded()

            if #coinCache == 0 and not allCollected and not hasFlinged then
                allCollected = true
                log("Всі монети зібрані")
                if CONFIG.AutoFling then
                    hasFlinged = true
                    task.spawn(autoFlingMurderer)
                end
            end
        end

        --// Якщо монета зникла (гра підібрала) — скидаємо ціль
        if currentTarget and not currentTarget.Parent then
            collectedCount = collectedCount + 1
            coinCache[currentTarget] = nil
            log("Монета зібрана! Всього: " .. collectedCount)
            currentTarget = nil
            currentCoinPos = nil
        end

        --// Оновлення цілі
        local now = tick()
        if not currentTarget or not currentCoinPos then
            if (now - lastTargetTime) > CONFIG.TargetRefresh then
                lastTargetTime = now
                currentTarget, currentCoinPos = findNearestCoin()
                if currentTarget then
                    targetAcquiredAt = now
                    log("Нова ціль: " .. currentTarget.Name)
                end
            end
        end

        --// Рух до цілі — летимо ПРЯМО в монету
        if currentTarget and currentTarget.Parent and currentCoinPos then
            --// Оновлюємо позицію монети (вона може рухатись)
            currentCoinPos = currentTarget.Position

            local direction = currentCoinPos - hrp.Position
            local dist = direction.Magnitude

            if dist > 0.5 then
                --// Плавний підхід
                local speedMul = 1
                if dist < 5 then
                    speedMul = math.clamp(dist / 5, 0.3, 1)
                end
                flyVel.VectorVelocity = direction.Unit * CONFIG.Speed * speedMul
            else
                --// На місці — тримаємо, чекаємо підбору
                flyVel.VectorVelocity = Vector3.zero
            end

            --// Таймаут: якщо летимо > MaxTargetTime і монета не зникла — скіпаємо
            local targetTime = now - targetAcquiredAt
            if targetTime > CONFIG.MaxTargetTime then
                log("⚠ Таймаут на " .. currentTarget.Name .. " — скіпаємо")
                coinCache[currentTarget] = nil
                currentTarget = nil
                currentCoinPos = nil
            end
        else
            flyVel.VectorVelocity = Vector3.zero
        end
    end)
end

local function stopMainLoop()
    if mainConn then mainConn:Disconnect(); mainConn = nil end
    if deathConn then deathConn:Disconnect(); deathConn = nil end
end

--// ============================================================
--//  RESPAWN
--// ============================================================
LocalPlayer.CharacterAdded:Connect(function()
    task.wait(1.5)
    resetRound()
    if enabled then
        disableNoclip()
        task.wait(0.1)
        enableNoclip()
        task.wait(0.2)
        setupFly()
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

    if state then
        resetRound()
        startAntiAFK()
        enableNoclip()
        task.wait(0.2)
        setupFly()
        startMainLoop()
        startDeathCheck()
        log("═══ Auto Farm ENABLED (Speed: " .. CONFIG.Speed .. ") ═══")
        notify("💰 Auto Farm", "Enabled (Speed: " .. CONFIG.Speed .. ")", 3)
    else
        stopMainLoop()
        stopFly()
        disableNoclip()
        if afkConn then afkConn:Disconnect(); afkConn = nil end
        log("Auto Farm DISABLED")
        notify("💰 Auto Farm", "Disabled", 2)
    end
end

function AutoFarm:setAutoFling(v)
    CONFIG.AutoFling = v
    log("Auto Fling: " .. tostring(v))
end

function AutoFarm:setAutoKill(v) CONFIG.AutoKill = v end
function AutoFarm:setKillDelay(v) CONFIG.KillDelay = v end
function AutoFarm:setSpeed(v) CONFIG.Speed = v end
function AutoFarm:setFlySpeed(v) CONFIG.Speed = v end

function AutoFarm:flingMurderer()
    task.spawn(autoFlingMurderer)
end

function AutoFarm:getStats()
    return {
        CoinsCollected = collectedCount,
        CoinsRemaining = #coinCache,
        Speed = CONFIG.Speed,
        HasFlinged = hasFlinged,
    }
end

function AutoFarm:setAntiMurderer() end
function AutoFarm:setAutoStart() end
function AutoFarm:killAll() end

log("═══════════════════════════════════")
log("TrustHub Auto Farm v11.2 (Speed 22)")
log("Fixed: летить прямо в монету")
log("═══════════════════════════════════")

return AutoFarm.new()
