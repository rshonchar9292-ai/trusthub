--// ╔══════════════════════════════════════════════════════════════╗
--// ║  TrustHub Auto Gun v7.1 — Murderer Skip                      ║
--// ║  Не бере пістолет, якщо ти Murderer                           ║
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
    ScanRate      = 0.5,
    MaxDistance   = 5000,
    Cooldown      = 1.0,
    SkipIfMurderer = true,   -- ← НЕ брати пістолет, якщо я Murderer
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
local cachedGun = nil
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
--//  ROLE DETECTION — чи я Murderer?
--// ============================================================
local function isLocalMurderer()
    local char = LocalPlayer.Character
    if not char then return false end

    --// Шукаємо ніж у себе
    for _, tool in ipairs(char:GetChildren()) do
        if tool:IsA("Tool") then
            local n = tool.Name:lower()
            if n:find("knife") or n:find("blade") then
                return true
            end
        end
    end
    return false
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
--//  SCAN FOR GUNDROP
--// ============================================================
local function scanForGun()
    --// ЯКЩО Я MURDERER — НЕ ШУКАЄМО ПІСТОЛЕТ
    if Config.SkipIfMurderer and isLocalMurderer() then
        return nil
    end

    local char, hum, hrp = getChar()
    if not hrp then return nil end

    --// Вже тримаємо пістолет — не шукаємо
    local current = char:FindFirstChildWhichIsA("Tool")
    if current then
        local n = current.Name:lower()
        if n:find("gun") or n:find("pistol") or n:find("sheriff") then
            return nil
        end
    end

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

    --// ЩЕ РАЗ ПЕРЕВІРКА (раптом роль змінилась)
    if Config.SkipIfMurderer and isLocalMurderer() then
        return
    end

    local now = tick()
    if now - lastAttempt < Config.Cooldown then return end
    lastAttempt = now
    busy = true

    local char, hum, hrp = getChar()
    if not char or not hrp then
        busy = false
        return
    end

    local originalCFrame = hrp.CFrame
    local originalVelocity = hrp.AssemblyLinearVelocity

    hrp.CFrame = CFrame.new(gun.Position + Vector3.new(0, 2, 0))
    hrp.AssemblyLinearVelocity = Vector3.zero

    task.wait(0.05)

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
--//  MAIN LOOP
--// ============================================================
local function startLoop()
    if loopConn then loopConn:Disconnect() end

    loopConn = RunService.Heartbeat:Connect(function()
        if not enabled or busy then return end

        local now = tick()
        if now - lastScan < Config.ScanRate then return end
        lastScan = now

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
function AutoGun:setSkipIfMurderer(v) Config.SkipIfMurderer = v end
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
log("TrustHub Auto Gun v7.1")
log("Skip if Murderer: " .. tostring(Config.SkipIfMurderer))
log("═══════════════════════════════════")

return AutoGun.new()
