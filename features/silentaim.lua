--// ============================================================
--// TrustHub Silent Aim v4.0 — MM2 (Remote FireServer)
--// Логіка взята з сурсу KITI (fn73, fn75)
--// ============================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local GuiService = game:GetService("GuiService")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

--// ============================================================
--// CONFIG (налаштування з нашого UI)
--// ============================================================
local Config = {
    Enabled = false,
    FOV = 150,
    HitChance = 100,
    Prediction = 2.8, -- В оригіналі це offset (за замовчуванням 2.8)
    TeamCheck = false,
    WallCheck = false,
    ShowFOV = true,
}

local fovCircle = nil

--// ============================================================
--// FOV CIRCLE (Drawing API)
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
end

--// ============================================================
--// ДОПОМІЖНІ ФУНКЦІЇ (з сурсу)
--// ============================================================
local function getMurderer()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            local bp = plr:FindFirstChild("Backpack")
            if bp and bp:FindFirstChild("Knife") then return plr end
            if plr.Character and plr.Character:FindFirstChild("Knife") then return plr end
        end
    end
    return nil
end

--// Розрахунок передбачення позиції (fn73 з сурсу)
local function getPredictedPosition(plr)
    local char = plr.Character
    if not char then return nil end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum then return nil end
    
    local velocity = hrp.AssemblyLinearVelocity
    local position = hrp.Position
    -- Формула з оригінального скрипта
    return position + velocity * Vector3.new(0.75, 0.5, 0.75) * (Config.Prediction / 15) + hum.MoveDirection * Config.Prediction
end

--// Пошук цілі
local function findTarget()
    local mousePos = UserInputService:GetMouseLocation()
    local inset = GuiService:GetGuiInset()
    local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2) - Vector2.new(inset.X, inset.Y)
    
    -- Пріоритет: Шукаємо Вбивцю
    local murderer = getMurderer()
    if murderer and murderer.Character then
        local hum = murderer.Character:FindFirstChildOfClass("Humanoid")
        if hum and hum.Health > 0 then
            local hrp = murderer.Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                local sp, onScreen = Camera:WorldToViewportPoint(hrp.Position)
                if onScreen then
                    local dist = (Vector2.new(sp.X, sp.Y) - center).Magnitude
                    if dist <= Config.FOV then
                        return murderer
                    end
                end
            end
        end
    end
    
    -- Якщо Вбивці немає, шукаємо найближчого
    local closest, closestDist = nil, Config.FOV
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character then
            local hum = plr.Character:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health > 0 then
                local hrp = plr.Character:FindFirstChild("HumanoidRootPart")
                if hrp then
                    local sp, onScreen = Camera:WorldToViewportPoint(hrp.Position)
                    if onScreen then
                        local dist = (Vector2.new(sp.X, sp.Y) - center).Magnitude
                        if dist <= closestDist then
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
--// ГОЛОВНА ФУНКЦІЯ СТРІЛЬБИ (fn31 та fn75 з сурсу)
--// ============================================================
local function doShoot()
    if not Config.Enabled then return end
    if math.random(1, 100) > Config.HitChance then return end
    
    local target = findTarget()
    if not target then return end
    
    local char = LocalPlayer.Character
    if not char then return end
    
    -- Шукаємо зброю
    local gun = char:FindFirstChild("Gun") or LocalPlayer.Backpack:FindFirstChild("Gun")
    if not gun then return end
    
    -- Екіпіруємо, якщо в рюкзаку
    if gun.Parent == LocalPlayer.Backpack then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then hum:EquipTool(gun) end
    end
    
    local rightHand = char:FindFirstChild("RightHand") or char:FindFirstChild("Right Arm")
    if not rightHand then return end
    
    local targetPos = getPredictedPosition(target)
    if not targetPos then return end
    
    -- Викликаємо RemoteEvent (як у fn75)
    local shootRemote = gun:FindFirstChild("Shoot") or (gun:FindFirstChild("Events") and gun.Events:FindFirstChild("Shoot"))
    
    if shootRemote then
        shootRemote:FireServer(CFrame.new(rightHand.Position), CFrame.new(targetPos))
        print("[SilentAim] Shot fired at:", target.Name)
    end
end

--// ============================================================
--// ОБРОБКА ВВОДУ (стрільба на ЛКМ)
--// ============================================================
UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        doShoot()
    end
end)

--// ============================================================
--// RENDER LOOP (FOV)
--// ============================================================
RunService.RenderStepped:Connect(function()
    if fovCircle then
        local inset = GuiService:GetGuiInset()
        fovCircle.Position = UserInputService:GetMouseLocation() - Vector2.new(inset.X, inset.Y)
        fovCircle.Radius = Config.FOV
        fovCircle.Visible = Config.Enabled and Config.ShowFOV
        
        if findTarget() then
            fovCircle.Color = Color3.fromRGB(255, 60, 60)
        else
            fovCircle.Color = Color3.fromRGB(120, 140, 255)
        end
    end
end)

--// ============================================================
--// MODULE API (Підключення до ui.lua)
--// ============================================================
local Module = {}
Module.__index = Module

function Module.new()
    return setmetatable({}, Module)
end

function Module:setEnabled(v) 
    Config.Enabled = v 
    print("[SilentAim] Enabled:", v) 
end

function Module:setFOV(v) Config.FOV = v end
function Module:setHitChance(v) Config.HitChance = v end
function Module:setPrediction(v) Config.Prediction = v end
function Module:setTeamCheck(v) Config.TeamCheck = v end
function Module:setWallCheck(v) Config.WallCheck = v end
function Module:setShowFOV(v) Config.ShowFOV = v end
function Module:setTargetPart(v) end -- Ігноруємо, стріляємо завжди в HRP

return Module.new()
