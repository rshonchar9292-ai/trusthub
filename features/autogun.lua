--// ╔══════════════════════════════════════════════════════════════╗
--// ║  TrustHub Auto Gun v3.0 — Working Version                    ║
--// ╚══════════════════════════════════════════════════════════════╝

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")

local LocalPlayer = Players.LocalPlayer

local Config = {
    MaxDistance    = 500,
    TeleportDelay  = 0.1,
    InstantPickup  = true,
    NotifyOnPickup = true,
}

local enabled = false
local conn = nil
local lastTeleport = 0
local pickedUp = {}

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

--// Назви пістолетів
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

    local ok = pcall(function()
        hum:EquipTool(tool)
    end)
    if ok then
        log("Picked via EquipTool: " .. tool.Name)
        return true
    end

    pcall(function()
        tool.Parent = char
    end)
    log("Picked via Parent: " .. tool.Name)
    return true
end

local function scanForGuns()
    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    -- Вже тримаємо пістолет?
    local currentTool = char:FindFirstChildWhichIsA("Tool")
    if currentTool and isGunTool(currentTool) then return end

    local bestGun = nil
    local bestDist = math.huge

    -- 1. Workspace
    for _, obj in ipairs(workspace:GetDescendants()) do
        if isGunTool(obj) and not pickedUp[obj] then
            local holder = Players:GetPlayerFromCharacter(obj.Parent)
            if not holder then
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
    end

    -- 2. Backpack інших
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
                notify("🔫 Auto Gun", "Picked: " .. bestGun.Name, 2)
            end
        end
    end
end

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

local AutoGun = {}
AutoGun.__index = AutoGun

function AutoGun.new()
    local self = setmetatable({}, AutoGun)

    LocalPlayer.CharacterAdded:Connect(function()
        task.wait(0.5)
        pickedUp = {}
    end)

    return self
end

function AutoGun:setEnabled(state)
    enabled = state
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
function AutoGun:setRange(v) Config.MaxDistance = v end
function AutoGun:setInstantPickup(v) Config.InstantPickup = v end
function AutoGun:setAutoEquip(v) end
function AutoGun:setNotify(v) Config.NotifyOnPickup = v end

log("═══════════════════════════════")
log("TrustHub Auto Gun v3.0 loaded")
log("═══════════════════════════════")

return AutoGun.new()
