--// ============================================================
--// TrustHub Silent Aim v3.0 — Sendox-style
--// Module for MM2, controlled from ui.lua
--// ============================================================

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace        = game:GetService("Workspace")
local StarterGui       = game:GetService("StarterGui")

local LocalPlayer = Players.LocalPlayer
local Camera      = Workspace.CurrentCamera
local Mouse       = LocalPlayer:GetMouse()

--// ============================================================
--//  OBFUSCATION STUB (Luraph-compatible)
--// ============================================================
local LPH_NO_VIRTUALIZE = LPH_NO_VIRTUALIZE or function(fn)
    return fn
end

--// ============================================================
--//  MODULE + CONFIG
--// ============================================================
local Module = {}
Module.__index = Module

Module.Config = {
    Enabled     = false,
    FOV         = 150,
    HitChance   = 100,
    TargetPart  = "Head",           -- "Head" | "HumanoidRootPart" | "UpperTorso"
    WallCheck   = true,
    TeamCheck   = false,
    ShowFOV     = true,
    CircleColor = Color3.fromRGB(255, 60, 60),
}

local Config = Module.Config

--// ============================================================
--//  STATE
--// ============================================================
local currentTarget = nil
local fovCircle     = nil
local oldIndex      = nil
local hooked        = false

--// ============================================================
--//  LOG
--// ============================================================
local function log(msg)
    print("[SilentAim] " .. tostring(msg))
end

--// ============================================================
--//  FOV CIRCLE (Drawing API)
--// ============================================================
local hasDrawing = pcall(function()
    local d = Drawing.new("Circle")
    d:Remove()
end)

if hasDrawing then
    fovCircle = Drawing.new("Circle")
    fovCircle.Thickness = 1.5
    fovCircle.NumSides = 64
    fovCircle.Filled = false
    fovCircle.Color = Config.CircleColor
    fovCircle.Transparency = 0.6
    fovCircle.Visible = false
    log("FOV circle: Drawing API")
else
    warn("[SilentAim] Drawing API unavailable")
end

--// ============================================================
--//  HELPERS
--// ============================================================
local function getAliveChar(plr)
    local char = plr.Character
    if not char then return nil end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hum or not hrp or hum.Health <= 0 then return nil end
    return char, hum, hrp
end

local function getTargetPart(plr)
    local char = getAliveChar(plr)
    if not char then return nil end
    return char:FindFirstChild(Config.TargetPart)
        or char:FindFirstChild("Head")
        or char:FindFirstChild("HumanoidRootPart")
end

local function isOnScreen(part)
    local _, onScreen = Camera:WorldToViewportPoint(part.Position)
    return onScreen
end

local function isVisible(part)
    if not Config.WallCheck then return true end
    local origin = Camera.CFrame.Position
    local dir = part.Position - origin
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {
        LocalPlayer.Character, Camera, part.Parent,
    }
    return Workspace:Raycast(origin, dir, params) == nil
end

--// ============================================================
--//  1. CLOSEST PLAYER
--// ============================================================
local function closestPlayer()
    local mousePos = UserInputService:GetMouseLocation()
    local best, bestDist = nil, Config.FOV

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            local skip = Config.TeamCheck
                and plr.Team ~= nil
                and plr.Team == LocalPlayer.Team

            if not skip then
                local part = getTargetPart(plr)
                if part and isOnScreen(part) then
                    local screenPos = Camera:WorldToViewportPoint(part.Position)
                    local dist = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude

                    if dist < bestDist and isVisible(part) then
                        bestDist = dist
                        best = part
                    end
                end
            end
        end
    end
    return best
end

--// ============================================================
--//  2. SHOULD HIT (Hit Chance)
--// ============================================================
local function shouldHit()
    return math.random(1, 100) <= Config.HitChance
end

--// ============================================================
--//  3. SAFE HOOK (__index)
--// ============================================================
local function installHook()
    if hooked then return end

    local ok, err = pcall(function()
        --// 4. LPH_NO_VIRTUALIZE wrapper (для майбутньої обфускації)
        LPH_NO_VIRTUALIZE(function()
            oldIndex = hookmetamethod(game, "__index", function(self, key)
                --// Тільки для non-caller'ів (захист від рекурсії)
                if not checkcaller() and Config.Enabled then
                    --// Перевірка: self == Mouse, key == "Hit"
                    if self == Mouse and key == "Hit" then
                        --// Перевірка цілі та шансу
                        if currentTarget
                            and currentTarget.Parent
                            and shouldHit()
                        then
                            return CFrame.new(currentTarget.Position)
                        end
                    end
                end
                --// Fallback — оригінальна логіка
                return oldIndex(self, key)
            end)
        end)()
    end)

    if ok then
        hooked = true
        log("✓ __index hook installed")
    else
        warn("[SilentAim] Hook failed: " .. tostring(err))
    end
end

local function uninstallHook()
    if not hooked or not oldIndex then return end
    pcall(function()
        LPH_NO_VIRTUALIZE(function()
            hookmetamethod(game, "__index", oldIndex)
        end)()
    end)
    hooked = false
    oldIndex = nil
    log("✗ __index hook removed")
end

--// ============================================================
--//  MAIN LOOP (RenderStepped)
--// ============================================================
RunService.RenderStepped:Connect(function()
    --// FOV circle update
    if fovCircle then
        fovCircle.Position = UserInputService:GetMouseLocation()
        fovCircle.Radius = Config.FOV
        fovCircle.Visible = Config.Enabled and Config.ShowFOV
        fovCircle.Color = currentTarget
            and Color3.fromRGB(255, 60, 60)
            or  Config.CircleColor
    end

    --// Target update
    if not Config.Enabled then
        currentTarget = nil
        return
    end
    currentTarget = closestPlayer()
end)

--// ============================================================
--//  PUBLIC API (для ui.lua)
--// ============================================================
function Module:setEnabled(state)
    Config.Enabled = state
    if state then
        installHook()
        log("═══ ENABLED (FOV: " .. Config.FOV .. ", Hit: " .. Config.HitChance .. "%) ═══")
        pcall(function()
            StarterGui:SetCore("SendNotification", {
                Title = "🎯 Silent Aim",
                Text  = "Enabled",
                Duration = 2,
            })
        end)
    else
        uninstallHook()
        currentTarget = nil
        log("═══ DISABLED ═══")
    end
end

function Module:setFOV(v)
    Config.FOV = math.clamp(v, 10, 800)
end

function Module:setHitChance(v)
    Config.HitChance = math.clamp(v, 1, 100)
end

function Module:setTargetPart(v)
    Config.TargetPart = v
end

function Module:setWallCheck(v)
    Config.WallCheck = v
end

function Module:setTeamCheck(v)
    Config.TeamCheck = v
end

function Module:setShowFOV(v)
    Config.ShowFOV = v
end

function Module:getStats()
    return {
        Enabled = Config.Enabled,
        Target  = currentTarget and currentTarget.Name or "None",
        FOV     = Config.FOV,
        Hooked  = hooked,
    }
end

--// ============================================================
--//  CLEANUP
--// ============================================================
game:BindToClose(function()
    uninstallHook()
    if fovCircle then
        pcall(function() fovCircle:Remove() end)
    end
end)

--// ============================================================
--//  INIT LOG
--// ============================================================
log("═══════════════════════════════")
log("TrustHub Silent Aim v3.0")
log("Sendox-style • __index Hook")
log("═══════════════════════════════")

return Module
