--// ============================================================
--// TrustHub Silent Aim v3.0 — MM2 Edition
--// Auto-Target • FOV Circle • Prediction • Wall Check
--// ============================================================

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace        = game:GetService("Workspace")
local StarterGui       = game:GetService("StarterGui")
local GuiService       = game:GetService("GuiService")

local LocalPlayer = Players.LocalPlayer
local Camera      = Workspace.CurrentCamera

--// ============================================================
--//  CONFIG
--// ============================================================
local Config = {
    Enabled       = false,
    FOV           = 150,
    ShowFOV       = true,
    FOVColor      = Color3.fromRGB(255, 60, 60),
    FOVThickness  = 1.5,
    FOVTransparency = 0.5,
    TargetPart    = "Head",       -- "Head" | "HumanoidRootPart" | "UpperTorso"
    Prediction    = 0.135,        -- компенсація руху цілі
    HitChance     = 100,          -- % влучань
    TeamCheck     = false,
    WallCheck     = true,
    MaxDistance   = 5000,
    LogEnabled    = true,
}

--// ============================================================
--//  STATE
--// ============================================================
local enabled     = false
local hooked      = false
local oldNamecall = nil
local currentTarget = nil
local fovCircle   = nil
local shots       = 0

--// ============================================================
--//  LOG
--// ============================================================
local function log(msg)
    if Config.LogEnabled then print("[SilentAim] " .. tostring(msg)) end
end

local function notify(title, text, duration)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = title, Text = text, Duration = duration or 2,
        })
    end)
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
    fovCircle.Thickness = Config.FOVThickness
    fovCircle.NumSides = 64
    fovCircle.Filled = false
    fovCircle.Color = Config.FOVColor
    fovCircle.Transparency = Config.FOVTransparency
    fovCircle.Visible = false
    log("FOV Circle: Drawing API")
else
    log("FOV Circle: Drawing недоступний")
end

--// ============================================================
--//  UTILS
--// ============================================================
local function getChar()
    local char = LocalPlayer.Character
    if not char then return nil end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hum or not hrp then return nil end
    return char, hum, hrp
end

local function getTargetPart(char)
    if not char then return nil end
    if Config.TargetPart == "Head" then
        return char:FindFirstChild("Head")
    elseif Config.TargetPart == "UpperTorso" then
        return char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")
    else
        return char:FindFirstChild("HumanoidRootPart")
    end
end

--// ============================================================
--//  WALL CHECK
--// ============================================================
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = true

local function isVisible(part)
    if not Config.WallCheck then return true end
    local char = LocalPlayer.Character
    rayParams.FilterDescendantsInstances = { char, part.Parent }
    local origin = Camera.CFrame.Position
    local dir = part.Position - origin
    local result = Workspace:Raycast(origin, dir, rayParams)
    return result == nil
end

--// ============================================================
--//  FIND CLOSEST TARGET (до центру екрана)
--// ============================================================
local function findTarget()
    local char, hum, hrp = getChar()
    if not hrp then return nil end

    local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    local best, bestDist = nil, Config.FOV

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character then
            local tHum = plr.Character:FindFirstChildOfClass("Humanoid")
            if tHum and tHum.Health > 0 then
                --// Team Check
                if not Config.TeamCheck or plr.Team ~= LocalPlayer.Team then
                    local part = getTargetPart(plr.Character)
                    if part then
                        local dist = (hrp.Position - part.Position).Magnitude
                        if dist <= Config.MaxDistance then
                            local sp, onScreen = Camera:WorldToViewportPoint(part.Position)
                            if onScreen then
                                local screenPos = Vector2.new(sp.X, sp.Y)
                                local screenDist = (screenPos - center).Magnitude
                                if screenDist < bestDist then
                                    if isVisible(part) then
                                        bestDist = screenDist
                                        best = plr
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    return best
end

--// ============================================================
--//  CHECK IF OUR GUN REMOTE
--// ============================================================
local function isOurGunRemote(obj)
    if not obj or not obj.Parent then return false end
    if obj.Name ~= "ShootGun" then return false end
    if not obj:IsA("RemoteFunction") then return false end
    local parent = obj.Parent
    if parent and parent.Name == "KnifeServer" then
        local gun = parent.Parent
        if gun and gun.Name == "Gun" and gun.Parent == LocalPlayer.Character then
            return true
        end
    end
    return false
end

--// ============================================================
--//  HOOK
--// ============================================================
local function hook()
    if hooked then return true end

    local ok, err = pcall(function()
        local mt = getrawmetatable(game)
        if not mt then error("no metatable") end

        oldNamecall = mt.__namecall
        setreadonly(mt, false)

        mt.__namecall = newcclosure(function(self, ...)
            local method = getnamecallmethod()
            local args = {...}

            if not Config.Enabled or checkcaller() then
                return oldNamecall(self, unpack(args))
            end

            if method == "InvokeServer" and isOurGunRemote(self) then
                pcall(function()
                    local target = currentTarget or findTarget()
                    if not target or not target.Character then return end

                    local part = getTargetPart(target.Character)
                    if not part then return end

                    --// Prediction: позиція + швидкість * час
                    local predicted = part.Position + (part.Velocity * Config.Prediction)

                    --// Hit Chance
                    if math.random(1, 100) <= Config.HitChance then
                        args[2] = predicted
                        shots = shots + 1
                        log("🎯 Shot #" .. shots .. " → " .. target.Name)
                    end
                end)
            end

            return oldNamecall(self, unpack(args))
        end)

        setreadonly(mt, true)
        hooked = true
        log("✓ Hook активовано (ShootGun)")
    end)

    if not ok then
        log("❌ Помилка хука: " .. tostring(err))
    end
    return hooked
end

local function unhook()
    if not hooked then return end
    pcall(function()
        local mt = getrawmetatable(game)
        setreadonly(mt, false)
        mt.__namecall = oldNamecall
        setreadonly(mt, true)
    end)
    hooked = false
    log("Hook знято")
end

--// ============================================================
--//  MAIN LOOP — оновлення цілі + FOV
--// ============================================================
RunService.RenderStepped:Connect(function()
    --// FOV Circle
    if fovCircle then
        local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
        fovCircle.Position = center
        fovCircle.Radius = Config.FOV
        fovCircle.Visible = Config.Enabled and Config.ShowFOV
        fovCircle.Color = currentTarget and Color3.fromRGB(255, 60, 60) or Config.FOVColor
    end

    if not Config.Enabled then return end

    --// Оновлюємо ціль
    currentTarget = findTarget()
end)

--// ============================================================
--//  MODULE
--// ============================================================
local SilentAim = {}
SilentAim.__index = SilentAim

function SilentAim.new()
    return setmetatable({}, SilentAim)
end

function SilentAim:setEnabled(state)
    Config.Enabled = state
    enabled = state

    if state then
        hook()
        log("═══ ENABLED ═══")
        notify("🎯 Silent Aim", "Enabled", 2)
    else
        unhook()
        currentTarget = nil
        log("═══ DISABLED ═══")
        notify("🎯 Silent Aim", "Disabled", 2)
    end
end

function SilentAim:setFOV(v) Config.FOV = v end
function SilentAim:setShowFOV(v) Config.ShowFOV = v end
function SilentAim:setTargetPart(v) Config.TargetPart = v end
function SilentAim:setPrediction(v) Config.Prediction = v end
function SilentAim:setHitChance(v) Config.HitChance = v end
function SilentAim:setTeamCheck(v) Config.TeamCheck = v end
function SilentAim:setWallCheck(v) Config.WallCheck = v end
function SilentAim:setMaxDistance(v) Config.MaxDistance = v end
function SilentAim:setFOVColor(c) Config.FOVColor = c end
function SilentAim:setFOVThickness(v) Config.FOVThickness = v; if fovCircle then fovCircle.Thickness = v end end
function SilentAim:setFOVFilled(v) if fovCircle then fovCircle.Filled = v end end

function SilentAim:getStats()
    return {
        Enabled  = Config.Enabled,
        Shots    = shots,
        Hooked   = hooked,
        Target   = currentTarget and currentTarget.Name or "None",
        FOV      = Config.FOV,
    }
end

--// Stubs
function SilentAim:setMethod() end
function SilentAim:setFOVTransparency(v) Config.FOVTransparency = v end

log("═══════════════════════════════")
log("Silent Aim MM2 v3.0")
log("Auto-Target • FOV • Prediction")
log("═══════════════════════════════")

return SilentAim.new()
