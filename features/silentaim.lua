--// ============================================================
--// TrustHub Silent Aim v6.0 — Murderer Target (Mouse.Hit)
--// Автоматично наводиться ТІЛЬКИ на Вбивцю (з ножем)
--// ============================================================

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local GuiService = game:GetService("GuiService")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local Mouse = LocalPlayer:GetMouse()

local Config = {
    Enabled = false,
    FOV = 360, -- Ставимо великий FOV, щоб точно влучати
    ShowFOV = true,
    Headshot = true, -- Стріляти в голову
}

local fovCircle = nil
local oldIndex = nil
local hooked = false

--// ============================================================
--// FOV CIRCLE
--// ============================================================
local hasDrawing = pcall(function() local d = Drawing.new("Circle"); d:Remove() end)
if hasDrawing then
    fovCircle = Drawing.new("Circle")
    fovCircle.Thickness = 1.5
    fovCircle.NumSides = 64
    fovCircle.Filled = false
    fovCircle.Color = Color3.fromRGB(255, 60, 60) -- Червоне коло
    fovCircle.Transparency = 0.5
    fovCircle.Visible = false
end

--// ============================================================
--// ФУНКЦІЯ ПОШУКУ ВБИВЦІ
--// ============================================================
local function getMurderer()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character then
            local hum = plr.Character:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health > 0 then
                -- Перевіряємо, чи є ніж у руках або в рюкзаку
                local hasKnife = plr.Character:FindFirstChild("Knife") or (plr:FindFirstChild("Backpack") and plr.Backpack:FindFirstChild("Knife"))
                if hasKnife then
                    return plr
                end
            end
        end
    end
    return nil
end

--// ============================================================
--// ХУК МИШІ (Підміна Mouse.Hit)
--// ============================================================
local function installHook()
    if hooked then return end
    local ok, err = pcall(function()
        local mt = getrawmetatable(game)
        oldIndex = mt.__index
        setreadonly(mt, false)

        mt.__index = newcclosure(function(self, key)
            -- Якщо функція увімкнена і це не наш власний виклик
            if Config.Enabled and not checkcaller() then
                if self == Mouse and key == "Hit" then
                    local murderer = getMurderer()
                    if murderer and murderer.Character then
                        local targetPart = Config.Headshot and murderer.Character:FindFirstChild("Head") or murderer.Character:FindFirstChild("HumanoidRootPart")
                        if targetPart then
                            -- Повертаємо CFrame голови вбивці замість позиції миші
                            return CFrame.new(targetPart.Position)
                        end
                    end
                end
            end
            return oldIndex(self, key)
        end)

        setreadonly(mt, true)
        hooked = true
        print("[SilentAim] Хук встановлено (Mouse.Hit -> Murderer)")
    end)
    if not ok then warn("[SilentAim] Помилка хука: " .. tostring(err)) end
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
    print("[SilentAim] Хук знято")
end

--// ============================================================
--// RENDER LOOP (Візуалізація)
--// ============================================================
game:GetService("RunService").RenderStepped:Connect(function()
    if fovCircle then
        local inset = GuiService:GetGuiInset()
        fovCircle.Position = UserInputService:GetMouseLocation() - Vector2.new(inset.X, inset.Y)
        fovCircle.Radius = Config.FOV
        fovCircle.Visible = Config.Enabled and Config.ShowFOV
        
        -- Коло стає яскраво-червоним, якщо вбивця знайдений
        if getMurderer() then
            fovCircle.Color = Color3.fromRGB(255, 0, 0)
        else
            fovCircle.Color = Color3.fromRGB(150, 150, 150)
        end
    end
end)

--// ============================================================
--// API ДЛЯ UI
--// ============================================================
local Module = {}
Module.__index = Module
function Module.new() return setmetatable({}, Module) end

function Module:setEnabled(v)
    Config.Enabled = v
    if v then installHook() else removeHook() end
    print("[SilentAim] Enabled:", v)
end

function Module:setFOV(v) Config.FOV = v end
function Module:setHitChance(v) end -- Ігноруємо, тут завжди 100%
function Module:setPrediction(v) end -- Ігноруємо, гра сама рахує
function Module:setTeamCheck(v) end -- Ігноруємо
function Module:setWallCheck(v) end -- Ігноруємо
function Module:setShowFOV(v) Config.ShowFOV = v end
function Module:setTargetPart(v) Config.Headshot = v end

-- Видаляємо хук при виході
game:BindToClose(function()
    removeHook()
    if fovCircle then pcall(function() fovCircle:Remove() end) end
end)

return Module.new()
