--// ============================================================
--// TrustHub Silent Aim v3.2 — MM2 (100% Working Fix)
--// Використовує __index для Mouse.Hit + GuiInset Fix
--// ============================================================

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace        = game:GetService("Workspace")
local GuiService       = game:GetService("GuiService")

local LocalPlayer = Players.LocalPlayer
local Camera      = Workspace.CurrentCamera
local Mouse       = LocalPlayer:GetMouse()

--// ============================================================
--//  CONFIG
--// ============================================================
local Config = {
    Enabled     = false,
    FOV         = 150,
    HitChance   = 100,
    WallCheck   = false,
    TargetPart  = "Head",
    ShowFOV     = true,
}

local fovCircle = nil
local oldIndex = nil
local hooked = false

local function log(msg) print("[SilentAim] " .. tostring(msg)) end

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
    fovCircle.Color = Color3.fromRGB(120, 140, 255)
    fovCircle.Transparency = 0.6
    fovCircle.Visible = false
else
    warn("[SilentAim] Drawing API недоступний, FOV не буде видно")
end

--// ============================================================
--//  TARGET LOGIC
--// ============================================================
local function getTargetPart(plr)
    local char = plr.Character
    if not char then return nil end
    return char:FindFirstChild(Config.TargetPart) or char:FindFirstChild("Head")
end

local function isVisible(part)
    if not Config.WallCheck then return true end
    local origin = Camera.CFrame.Position
    local dir = part.Position - origin
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { LocalPlayer.Character, Camera, part.Parent }
    local result = Workspace:Raycast(origin, dir, params)
    return result == nil
end

local function getClosestPlayer()
    --// ФІКС: компенсуємо верхню панель (Top Bar) Roblox
    local inset = GuiService:GetGuiInset()
    local mouseLoc = UserInputService:GetMouseLocation() - Vector2.new(inset.X, inset.Y)
    
    local closest, closestDist = nil, Config.FOV

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character then
            local hum = plr.Character:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health > 0 then
                local part = getTargetPart(plr)
                if part then
                    local sp, onScreen = Camera:WorldToViewportPoint(part.Position)
                    if onScreen then
                        local dist = (Vector2.new(sp.X, sp.Y) - mouseLoc).Magnitude
                        if dist <= closestDist and isVisible(part) then
                            closest = plr
                            closestDist = dist
                        end
                    end
                end
            end
        end
    end
    return closest
end

--// ============================================================
--//  HOOK (__index для Mouse.Hit)
--// ============================================================
local function installHook()
    if hooked then return end
    local ok, err = pcall(function()
        local mt = getrawmetatable(game)
        oldIndex = mt.__index
        setreadonly(mt, false)

        mt.__index = newcclosure(function(self, key)
            if Config.Enabled and not checkcaller() then
                --// Перехоплюємо саме Mouse.Hit
                if self == Mouse and key == "Hit" then
                    local target = getClosestPlayer()
                    if target then
                        local part = getTargetPart(target)
                        if part and math.random(1, 100) <= Config.HitChance then
                            return CFrame.new(part.Position)
                        end
                    end
                end
            end
            return oldIndex(self, key)
        end)
        setreadonly(mt, true)
        hooked = true
        log("Hook встановлено (Mouse.Hit)")
    end)
    if not ok then warn("[SilentAim] Hook error: " .. tostring(err)) end
end

local function removeHook()
    if not hooked or not oldIndex then return end
    pcall(function()
        local mt = getrawmetatable(game)
        setreadonly(mt, false)
        mt.__index = oldIndex
        setreadonly(mt, true)
    end)
    hooked = false
    log("Hook знято")
end

--// ============================================================
--//  RENDER LOOP
--// ============================================================
RunService.RenderStepped:Connect(function()
    if fovCircle then
        local inset = GuiService:GetGuiInset()
        local mouseLoc = UserInputService:GetMouseLocation() - Vector2.new(inset.X, inset.Y)
        
        fovCircle.Position = mouseLoc
        fovCircle.Radius = Config.FOV
        fovCircle.Visible = Config.Enabled and Config.ShowFOV
        
        -- Коло стає червоним, якщо є ціль
        if getClosestPlayer() then
            fovCircle.Color = Color3.fromRGB(255, 60, 60)
        else
            fovCircle.Color = Color3.fromRGB(120, 140, 255)
        end
    end
end)

--// ============================================================
--//  MODULE API (Підключення до ui.lua)
--// ============================================================
local Module = {}
Module.__index = Module

function Module.new()
    return setmetatable({}, Module)
end

function Module:setEnabled(v)
    Config.Enabled = v
    if v then installHook() else removeHook() end
    log("Enabled: " .. tostring(v))
end

function Module:setFOV(v) Config.FOV = math.clamp(v, 10, 800) end
function Module:setHitChance(v) Config.HitChance = math.clamp(v, 1, 100) end
function Module:setWallCheck(v) Config.WallCheck = v end
function Module:setTargetPart(v) Config.TargetPart = v end
function Module:setShowFOV(v) Config.ShowFOV = v end

--// Очищення при виході з гри
game:BindToClose(function()
    removeHook()
    if fovCircle then pcall(function() fovCircle:Remove() end) end
end)

return Module.new()
