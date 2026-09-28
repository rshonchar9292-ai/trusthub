--// ╔══════════════════════════════════════════════════════════════╗
--// ║  TrustHub Auto Gun v2.0                                      ║
--// ║  Auto-teleports to any gun on the map and picks it up         ║
--// ╚══════════════════════════════════════════════════════════════╝

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local StarterGui       = game:GetService("StarterGui")

local LocalPlayer = Players.LocalPlayer

--// ============================================================
--//  CONFIG
--// ============================================================
local Config = {
    Enabled       = false,
    MaxDistance   = 500,       -- максимальна дистанція пошуку (studs)
    TeleportDelay = 0.1,       -- затримка між телепортами
    InstantPickup = true,      -- підбирати одразу після телепорту
    NotifyOnPickup = true,     -- показувати повідомлення
    OnlySheriffGun = false,    -- тільки пістолет Sheriff-а
}

--// ============================================================
--//  STATE
--// ============================================================
local enabled = false
local conn = nil
local lastTeleport = 0
local pickedUp = {}  -- щоб не підбирати одне й те саме

--// ============================================================
--//  NOTIFY
--// ============================================================
local function notify(title, text, duration)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = title,
            Text = text,
            Duration = duration or 2,
        })
    end)
end

local function log(msg) print("[AutoGun] " .. msg) end

--// ============================================================
--//  GUN DETECTION
--// ============================================================
-- Назви, які вважаються пістолетом
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

--// ============================================================
--//  PICKUP LOGIC
--// ============================================================
local function teleportTo(position)
    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    pcall(function()
        hrp.CFrame = CFrame.new(position + Vector3.new(0, 3, 0))
    end)
end

local function tryPickup(tool)
    local char = LocalPlayer.Character
    if not char then return false end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return false end

    -- Метод 1: через Humanoid:EquipTool()
    local ok = pcall(function()
        hum:EquipTool(tool)
    end)
    if ok then
        log("Picked up via EquipTool: " .. tool.Name)
        return true
    end

    -- Метод 2: зміна Parent
    pcall(function()
        tool.Parent = char
    end)

    log("Picked up via Parent: " .. tool.Name)
    return true
end

--// ============================================================
--//  SCAN FOR GUNS
--// ============================================================
local function scanForGuns()
    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    -- Перевіряємо чи вже тримаємо пістолет
    local currentTool = char:FindFirstChildWhichIsA("Tool")
    if currentTool and isGunTool(currentTool) then
        return  -- вже тримаємо
    end

    local bestGun = nil
    local bestDist = math.huge

    -- 1. Шукаємо пістолети в Workspace (лежать на землі)
    for _, obj in ipairs(workspace:GetDescendants()) do
        if isGunTool(obj) then
            -- Пропускаємо, якщо вже підбирали
            if pickedUp[obj] then continue end

            -- Пропускаємо, якщо гравець вже тримає цей Tool
            local holder = Players:GetPlayerFromCharacter(obj.Parent)
            if holder then continue end

            local handle = obj:FindFirstChild("Handle")
            if handle then
                local dist = (hrp.Position - handle.Position).Magnitude
                if dist < bestDist and dist <= Config.MaxDistance then
                    bestDist = dist
                    bestGun = obj
                end
            end
        end
    end

    -- 2. Шукаємо пістолети в Backpack інших гравців (якщо Sheriff помер)
    if not bestGun then
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr == LocalPlayer then continue end
            local bp = plr:FindFirstChild("Backpack")
            if bp then
                for _, tool in ipairs(bp:GetChildren()) do
                    if isGunTool(tool) and not pickedUp[tool] then
                        local handle = tool:FindFirstChild("Handle")
                        if handle then
                            local dist = (hrp.Position - handle.Position).Magnitude
                            if dist < bestDist and dist <= Config.MaxDistance then
                                bestDist = dist
                                bestGun = tool
                            end
                        end
                    end
                end
            end
        end
    end

    -- 3. Знайшли — телепортуємось і підбираємо
    if bestGun then
        local handle = bestGun:FindFirstChild("Handle")
        if not handle then return end

        local now = tick()
        if now - lastTeleport < Config.TeleportDelay then return end
        lastTeleport = now

        teleportTo(handle.Position)

        if Config.InstantPickup then
            task.wait(0.05)
            tryPickup(bestGun)
            pickedUp[bestGun] = true

            if Config.NotifyOnPickup then
                notify("🔫 Auto Gun", "Picked up: " .. bestGun.Name, 2)
            end
        end
    end
end

--// ============================================================
--//  MAIN LOOP
--// ============================================================
local function startLoop()
    if conn then conn:Disconnect() end

    conn = RunService.Heartbeat:Connect(function()
        if not enabled then return end
        pcall(scanForGuns)
    end)
end

local function stopLoop()
    if conn then
        conn:Disconnect()
        conn = nil
    end
end

--// ============================================================
--//  MODULE
--// ============================================================
local AutoGun = {}
AutoGun.__index = AutoGun

function AutoGun.new()
    local self = setmetatable({}, AutoGun)

    -- Автоматичне перепідключення при респавні
    LocalPlayer.CharacterAdded:Connect(function()
        task.wait(0.5)
        pickedUp = {}
    end)

    return self
end

function AutoGun:setEnabled(state)
    enabled = state
    Config.Enabled = state

    if state then
        startLoop()
        log("ON")
        notify("🔫 Auto Gun", "Enabled", 2)
    else
        stopLoop()
        log("OFF")
        notify("🔫 Auto Gun", "Disabled", 2)
    end
end

function AutoGun:setMaxDistance(v) Config.MaxDistance = v end
function AutoGun:setInstantPickup(v) Config.InstantPickup = v end
function AutoGun:setNotify(v) Config.NotifyOnPickup = v end

-- Заглушки для сумісності з UI
function AutoGun:setRange(v) Config.MaxDistance = v end
function AutoGun:setAutoEquip(v) end

log("═══════════════════════════════")
log("TrustHub Auto Gun v2.0 loaded")
log("═══════════════════════════════")

return AutoGun.new()
