--// ╔══════════════════════════════════════════════════════════════╗
--// ║  TrustHub Auto Farm v5.0 — Fixed Speed Edition                ║
--// ║  Speed: 22 (safe, no kick)                                    ║
--// ╚══════════════════════════════════════════════════════════════╝

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")

local LocalPlayer = Players.LocalPlayer

--// ============================================================
--//  FIXED CONFIG (без слайдерів)
--// ============================================================
local FLY_SPEED      = 22       -- Фіксована швидкість (безпечна)
local UPDATE_RATE    = 0.05
local AUTO_FLING     = true     -- Флинг Murderer-а після фарму
local FLING_DELAY    = 1.0
local ANTI_MURDERER  = true
local DANGER_RANGE   = 35
local LOG_ENABLED    = true
local NOTIFY_ENABLED = true

--// ============================================================
--//  STATE
--// ============================================================
local enabled = false
local currentTarget = nil
local lastTargetUpdate = 0
local collectedCoins = {}
local totalCoinsCollected = 0
local roundStartTime = 0
local flingInProgress = false

local noclipConn = nil
local mainLoopConn = nil
local deathCheckConn = nil

--// ============================================================
--//  LOG / NOTIFY
--// ============================================================
local function log(msg)
    if LOG_ENABLED then
        print("[AutoFarm] " .. msg)
    end
end

local function notify(title, text, duration)
    if not NOTIFY_ENABLED then return end
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = title,
            Text = text,
            Duration = duration or 2,
        })
    end)
end

--// ============================================================
--//  HELPERS
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
            if n:find("knife") or n:find("blade") or n:find("murder") 
               or n:find("dagger") or n:find("sword") then
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
--//  COIN DETECTION
--// ============================================================
local COIN_WORDS = { 
    "coin", "money", "token", "cash", 
    "gem", "gold", "collect", "pickup", "reward" 
}

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
            if p:IsA("BasePart") then
                p.CanCollide = true
            end
        end
    end
end

--// ============================================================
--//  ANTI-MURDERER ESCAPE
--// ============================================================
local function shouldEscapeFromMurderer()
    if not ANTI_MURDERER then return false end
    local char, hum, hrp = getChar()
    if not hrp then return false end
    local murderer = findMurderer()
    if not murderer or not murderer.Character then return false end
    local mHrp = murderer.Character:FindFirstChild("HumanoidRootPart")
    if not mHrp then return false end
    local dist = (hrp.Position - mHrp.Position).Magnitude
    return dist <= DANGER_RANGE
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
        log("No Murderer to fling")
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
    end

    flingInProgress = false
end

--// ============================================================
--//  ROUND RESET
--// ============================================================
local function resetForNewRound()
    collectedCoins = {}
    currentTarget = nil
    totalCoinsCollected = 0
    roundStartTime = tick()
    flingInProgress = false
    log("New round — coins: " .. countAllCoins())
end

--// ============================================================
--//  DEATH DETECTION
--// ============================================================
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

--// ============================================================
--//  MAIN LOOP — CFrame FLY (Speed = 22)
--// ============================================================
local coinCheckTimer = 0

local function startMainLoop()
    if mainLoopConn then mainLoopConn:Disconnect() end
    mainLoopConn = RunService.RenderStepped:Connect(function(dt)
        if not enabled then return end

        local char, hum, hrp = getChar()
        if not hrp then return end

        -- Anti-Murderer escape
        if shouldEscapeFromMurderer() then
            local murderer = findMurderer()
            if murderer and murderer.Character then
                local mHrp = murderer.Character:FindFirstChild("HumanoidRootPart")
                if mHrp then
                    local escapeDir = (hrp.Position - mHrp.Position).Unit
                    local newPos = hrp.Position + escapeDir * FLY_SPEED * 3 * dt
                    hrp.CFrame = CFrame.new(newPos)
                    hrp.AssemblyLinearVelocity = Vector3.zero
                end
            end
            return
        end

        -- Перевірка чи всі монети зібрані
        coinCheckTimer = coinCheckTimer + dt
        if coinCheckTimer > 3 then
            coinCheckTimer = 0
            if countAllCoins() == 0 and AUTO_FLING and not flingInProgress then
                log("All coins collected — auto-flinging")
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

        -- Політ до монети (швидкість 22)
        if currentTarget then
            local pos = getCoinPosition(currentTarget)
            if pos then
                local currentPos = hrp.Position
                local direction = pos - currentPos
                local dist = direction.Magnitude
                if dist > 2.5 then
                    local step = direction.Unit * FLY_SPEED * dt
                    if step.Magnitude > dist then step = direction.Unit * dist end
                    hrp.CFrame = CFrame.new(currentPos + step)
                    hrp.AssemblyLinearVelocity = Vector3.zero
                    hrp.AssemblyAngularVelocity = Vector3.zero
                else
                    if not collectedCoins[currentTarget] then
                        collectedCoins[currentTarget] = true
                        totalCoinsCollected = totalCoinsCollected + 1
                    end
                    currentTarget = nil
                end
            else
                currentTarget = nil
            end
        end
    end)
end

local function stopMainLoop()
    if mainLoopConn then mainLoopConn:Disconnect(); mainLoopConn = nil end
    if deathCheckConn then deathCheckConn:Disconnect(); deathCheckConn = nil end
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
    end
end)

--// ============================================================
--//  PUBLIC API (без слайдерів швидкості)
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
        task.wait(0.1)
        startMainLoop()
        startDeathCheck()
        log("═══ Auto Farm ENABLED (Speed: " .. FLY_SPEED .. ") ═══")
        notify("💰 Auto Farm", "Enabled (Speed: " .. FLY_SPEED .. ")", 3)
    else
        stopMainLoop()
        disableNoclip()
        log("Auto Farm DISABLED")
        notify("💰 Auto Farm", "Disabled", 2)
    end
end

-- Stub функції для сумісності з UI (нічого не роблять)
function AutoFarm:setSpeed() end
function AutoFarm:setFlySpeed() end
function AutoFarm:setAutoFling() end
function AutoFarm:setAntiMurderer() end
function AutoFarm:setAutoStart() end
function AutoFarm:setAutoKill() end
function AutoFarm:setKillDelay() end

function AutoFarm:getStats()
    return {
        CoinsCollected = totalCoinsCollected,
        RoundTime = math.floor(tick() - roundStartTime),
        Speed = FLY_SPEED,
    }
end

log("═══════════════════════════════════")
log("TrustHub Auto Farm v5.0")
log("Speed: " .. FLY_SPEED .. " (fixed, safe)")
log("═══════════════════════════════════")

return AutoFarm.new()
