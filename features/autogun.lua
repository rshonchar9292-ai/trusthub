--// ╔══════════════════════════════════════════════════════════════╗
--// ║  TrustHub Auto Gun v4.0 — MM2 GunDrop Edition                ║
--// ╚══════════════════════════════════════════════════════════════╝

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")

local LocalPlayer = Players.LocalPlayer

local Config = {
    MaxDistance    = 1000,
    TeleportDelay  = 0.3,
    NotifyOnPickup = true,
}

local enabled = false
local conn = nil
local lastTeleport = 0

local function notify(title, text, duration)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = title, Text = text, Duration = duration or 2,
        })
    end)
end

local function log(msg) print("[AutoGun] " .. msg) end

--// Перевірка чи це GunDrop (Part, а не Tool)
local function isGunDrop(obj)
    if not obj or not obj.Parent then return false end
    if not obj:IsA("BasePart") then return false end
    local n = obj.Name
    return n == "GunDrop" or n:lower():find("gundrop")
end

local function teleportTo(position)
    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    pcall(function()
        hrp.CFrame = CFrame.new(position + Vector3.new(0, 2, 0))
    end)
end

local function scanForGunDrop()
    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    -- Вже тримаємо пістолет?
    local currentTool = char:FindFirstChildWhichIsA("Tool")
    if currentTool and currentTool.Name:lower():find("gun") then return end

    local best, bestDist = nil, math.huge

    for _, obj in ipairs(workspace:GetDescendants()) do
        if isGunDrop(obj) then
            local dist = (hrp.Position - obj.Position).Magnitude
            if dist < bestDist and dist <= Config.MaxDistance then
                bestDist = dist
                best = obj
            end
        end
    end

    if best then
        local now = tick()
        if now - lastTeleport < Config.TeleportDelay then return end
        lastTeleport = now

        teleportTo(best.Position)
        log("Teleported to GunDrop (" .. math.floor(bestDist) .. " studs)")

        if Config.NotifyOnPickup then
            notify("🔫 Auto Gun", "Moving to gun (" .. math.floor(bestDist) .. "m)", 2)
        end
    end
end

local function startLoop()
    if conn then conn:Disconnect() end
    conn = RunService.Heartbeat:Connect(function()
        if not enabled then return end
        pcall(scanForGunDrop)
    end)
end

local function stopLoop()
    if conn then conn:Disconnect(); conn = nil end
end

local AutoGun = {}
AutoGun.__index = AutoGun

function AutoGun.new()
    return setmetatable({}, AutoGun)
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
function AutoGun:setInstantPickup(v) end
function AutoGun:setAutoEquip(v) end
function AutoGun:setNotify(v) Config.NotifyOnPickup = v end

log("═══════════════════════════════")
log("TrustHub Auto Gun v4.0 (GunDrop)")
log("═══════════════════════════════")

return AutoGun.new()
