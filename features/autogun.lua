--// ╔══════════════════════════════════════════════════════════════╗
--// ║  TrustHub Auto Gun v6.0                                      ║
--// ║  Fast TP • Instant Pickup • Instant Return                   ║
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
    MaxDistance   = 3000,
    PickupWait    = 0.05,       -- затримка на 1 кадр (швидко)
    Cooldown      = 0.5,        -- перезарядка між спробами
    LogEnabled    = true,
    NotifyEnabled = true,
}

--// ============================================================
--//  STATE
--// ============================================================
local enabled = false
local busy = false
local lastAttempt = 0
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
local GUN_KEYWORDS = {
    "gun", "pistol", "sheriff", "revolver", "magnum",
    "weapon", "shoot", "handgun"
}

local function isGunName(name)
    local n = name:lower()
    for _, kw in ipairs(GUN_KEYWORDS) do
        if n:find(kw) then return true end
    end
    return false
end

local function isGunTool(obj)
    if not obj or not obj.Parent then return false end
    if not obj:IsA("Tool") then return false end
    return isGunName(obj.Name)
end

local function isGunDrop(obj)
    if not obj or not obj.Parent then return false end
    if not obj:IsA("BasePart") then return false end
    return obj.Name:lower():find("gundrop")
end

--// ============================================================
--//  FIND GUN
--// ============================================================
local function findBestGun()
    local char, hum, hrp = getChar()
    if not hrp then return nil, nil end

    -- Вже тримаємо пістолет?
    local current = char:FindFirstChildWhichIsA("Tool")
    if current and isGunTool(current) then
        return nil, nil
    end

    local bestTool, bestDrop = nil, nil
    local bestDist = math.huge

    -- 1. Шукаємо GunDrop (найчастіше в MM2)
    for _, obj in ipairs(workspace:GetDescendants()) do
        if isGunDrop(obj) then
            local dist = (hrp.Position - obj.Position).Magnitude
            if dist < bestDist and dist <= Config.MaxDistance then
                bestDist = dist
                bestDrop = obj
            end
        end
    end

    -- 2. Шукаємо Tool на землі (якщо гра так дропає)
    if not bestTool and not bestDrop then
        for _, obj in ipairs(workspace:GetDescendants()) do
            if isGunTool(obj) then
                local holder = Players:GetPlayerFromCharacter(obj.Parent)
                if not holder then
                    local handle = obj:FindFirstChild("Handle")
                    if handle then
                        local dist = (hrp.Position - handle.Position).Magnitude
                        if dist < bestDist and dist <= Config.MaxDistance then
                            bestDist = dist
                            bestTool = obj
                        end
                    end
                end
            end
        end
    end

    return bestTool, bestDrop
end

--// ============================================================
--//  PICKUP TOOL (fallback)
--// ============================================================
local function tryPickupTool(tool)
    local char, hum = getChar()
    if not char or not hum then return false end

    local ok = pcall(function()
        hum:EquipTool(tool)
    end)
    if ok then return true end

    pcall(function()
        tool.Parent = char
    end)
    return true
end

--// ============================================================
--//  FAST GRAB — TP → Pickup → Return (миттєво)
--// ============================================================
local function fastGrab()
    if busy then return end
    local now = tick()
    if now - lastAttempt < Config.Cooldown then return end
    lastAttempt = now
    busy = true

    local char, hum, hrp = getChar()
    if not char or not hrp then
        busy = false
        return
    end

    local tool, drop = findBestGun()
    if not tool and not drop then
        busy = false
        return
    end

    -- ⚡ ЗБЕРІГАЄМО ОРИГІНАЛЬНУ ПОЗИЦІЮ (включно з обертанням)
    local originalCFrame = hrp.CFrame
    local originalVelocity = hrp.AssemblyLinearVelocity

    -- Знаходимо позицію цілі
    local targetPos
    if drop then
        targetPos = drop.Position
    elseif tool then
        local handle = tool:FindFirstChild("Handle")
        if handle then
            targetPos = handle.Position
        else
            busy = false
            return
        end
    end

    if not targetPos then
        busy = false
        return
    end

    -- ⚡ ТЕЛЕПОРТ ДО ПІСТОЛЕТА (миттєво)
    hrp.CFrame = CFrame.new(targetPos + Vector3.new(0, 1, 0))
    hrp.AssemblyLinearVelocity = Vector3.zero

    -- ⚡ ЧЕКАЄМО 1 КАДР
    task.wait(Config.PickupWait)

    -- ⚡ ПІДБИРАЄМО
    if tool then
        tryPickupTool(tool)
    end
    -- Якщо drop — гра сама підбирає через дотик

    -- ⚡ ПОВЕРТАЄМОСЬ НАЗАД (миттєво)
    local newChar, newHum, newHrp = getChar()
    if newHrp then
        newHrp.CFrame = originalCFrame
        newHrp.AssemblyLinearVelocity = originalVelocity
    end

    if tool then
        log("Picked: " .. tool.Name)
        notify("🔫 Auto Gun", "Picked: " .. tool.Name, 2)
    elseif drop then
        log("Grabbed GunDrop")
        notify("🔫 Auto Gun", "Grabbed GunDrop", 2)
    end

    busy = false
end

--// ============================================================
--//  MAIN LOOP
--// ============================================================
local function startLoop()
    if loopConn then loopConn:Disconnect() end

    loopConn = RunService.Heartbeat:Connect(function()
        if not enabled then return end
        if busy then return end

        local char, hum, hrp = getChar()
        if not hrp then return end

        local tool, drop = findBestGun()
        if tool or drop then
            task.spawn(fastGrab)
        end
    end)
end

local function stopLoop()
    if loopConn then loopConn:Disconnect(); loopConn = nil end
end

--// ============================================================
--//  CHARACTER RESPAWN
--// ============================================================
LocalPlayer.CharacterAdded:Connect(function()
    if enabled then
        task.wait(1)
        busy = false
    end
end)

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

    if state then
        startLoop()
        log("═══ Auto Gun ENABLED ═══")
        notify("🔫 Auto Gun", "Enabled (Fast TP)", 2)
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

log("═══════════════════════════════════")
log("TrustHub Auto Gun v6.0 (Fast TP)")
log("═══════════════════════════════════")

return AutoGun.new()
