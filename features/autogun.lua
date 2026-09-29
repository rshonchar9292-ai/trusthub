--// ╔══════════════════════════════════════════════════════════════╗
--// ║  TrustHub Auto Gun v7.0 — Optimized Edition                  ║
--// ║  Throttled scan • Fast TP • No lag                           ║
--// ╚══════════════════════════════════════════════════════════════╝

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")

local LocalPlayer = Players.LocalPlayer

--// ============================================================
--//  CONFIG
--// ============================================================
local Config = {
    Enabled       = false,
    ScanRate      = 0.5,       -- ⚡ скануємо раз на 0.5с (не кожен кадр!)
    MaxDistance   = 5000,
    Cooldown      = 1.0,
    LogEnabled    = true,
    NotifyEnabled = true,
}

--// ============================================================
--//  STATE
--// ============================================================
local enabled = false
local busy = false
local lastAttempt = 0
local lastScan = 0
local cachedGun = nil   -- кеш цілі
local loopConn = nil

--// ============================================================
--//  LOG / NOTIFY
--// ============================================================
local function log(msg)
    if Config.LogEnabled then print("[AutoGun] " .. msg) end
end

local function notify(title, text, duration)
    if not Config.NotifyEnabled then return end
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
--//  GUN DETECTION
--// ============================================================
local function isGunDrop(obj)
    if not obj or not obj.Parent then return false end
    if not obj:IsA("BasePart") then return false end
    local n = obj.Name:lower()
    return n == "gundrop" or n:find("gundrop")
end

--// ============================================================
--//  SCAN FOR GUNDROP (throttled)
--// ============================================================
local function scanForGun()
    local char, hum, hrp = getChar()
    if not hrp then return nil end

    -- Вже тримаємо пістолет — не шукаємо
    local current = char:FindFirstChildWhichIsA("Tool")
    if current then
        local n = current.Name:lower()
        if n:find("gun") or n:find("pistol") or n:find("sheriff") then
            return nil
        end
    end

    -- Шукаємо тільки в Workspace (не в GetDescendants — швидше)
    local best, bestDist = nil, math.huge

    for _, obj in ipairs(workspace:GetChildren()) do
        if isGunDrop(obj) then
            local dist = (hrp.Position - obj.Position).Magnitude
            if dist < bestDist then
                bestDist = dist
                best = obj
            end
        end
    end

    -- Також шукаємо в моделях
    for _, obj in ipairs(workspace:GetChildren()) do
        if obj:IsA("Model") then
            for _, child in ipairs(obj:GetChildren()) do
                if isGunDrop(child) then
                    local dist = (hrp.Position - child.Position).Magnitude
                    if dist < bestDist then
                        bestDist = dist
                        best = child
                    end
                end
            end
        end
    end

    if best and bestDist <= Config.MaxDistance then
        return best
    end
    return nil
end

--// ============================================================
--//  FAST GRAB
--// ============================================================
local function fastGrab(gun)
    if busy or not gun or not gun.Parent then return end
    local now = tick()
    if now - lastAttempt < Config.Cooldown then return end
    lastAttempt = now
    busy = true

    local char, hum, hrp = getChar()
    if not char or not hrp then
        busy = false
        return
    end

    -- Зберігаємо оригінальну позицію
    local originalCFrame = hrp.CFrame
    local originalVelocity = hrp.AssemblyLinearVelocity

    -- Телепорт до GunDrop
    hrp.CFrame = CFrame.new(gun.Position + Vector3.new(0, 2, 0))
    hrp.AssemblyLinearVelocity = Vector3.zero

    -- Чекаємо 1-2 кадри
    task.wait(0.05)

    -- Гра сама підбирає GunDrop через дотик

    -- Повертаємось назад
    local newChar, newHum, newHrp = getChar()
    if newHrp then
        newHrp.CFrame = originalCFrame
        newHrp.AssemblyLinearVelocity = originalVelocity
    end

    log("Grabbed GunDrop")
    notify("🔫 Auto Gun", "Grabbed gun", 2)

    busy = false
end

--// ============================================================
--//  MAIN LOOP (throttled — не кожен кадр!)
--// ============================================================
local function startLoop()
    if loopConn then loopConn:Disconnect() end

    loopConn = RunService.Heartbeat:Connect(function()
        if not enabled or busy then return end

        local now = tick()
        if now - lastScan < Config.ScanRate then return end
        lastScan = now

        -- Скануємо тільки раз на ScanRate
        local gun = scanForGun()
        if gun then
            task.spawn(fastGrab, gun)
        end
    end)
end

local function stopLoop()
    if loopConn then loopConn:Disconnect(); loopConn = nil end
end

--// ============================================================
--//  MODULE
--// ============================================================
local AutoGun = {}
AutoGun.__index = AutoGun

function AutoGun.new()
    return setmetatable({}, AutoGun)
end

function AutoGun:setEnabled(state)
    enabled = state
    Config.Enabled = state
    busy = false
    cachedGun = nil

    if state then
        startLoop()
        log("═══ Auto Gun ENABLED (scan: " .. Config.ScanRate .. "s) ═══")
        notify("🔫 Auto Gun", "Enabled", 2)
    else
        stopLoop()
        log("Auto Gun DISABLED")
        notify("🔫 Auto Gun", "Disabled", 2)
    end
end

function AutoGun:setMaxDistance(v) Config.MaxDistance = v end
function AutoGun:setRange(v) Config.MaxDistance = v end
function AutoGun:setNotify(v) Config.NotifyEnabled = v end
function AutoGun:setInstantPickup(v) end
function AutoGun:setAutoEquip(v) end

LocalPlayer.CharacterAdded:Connect(function()
    if enabled then
        task.wait(1)
        busy = false
        cachedGun = nil
    end
end)

log("═══════════════════════════════════")
log("TrustHub Auto Gun v7.0 (Optimized)")
log("Scan rate: " .. Config.ScanRate .. "s")
log("═══════════════════════════════════")

return AutoGun.new()
