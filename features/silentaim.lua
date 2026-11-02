--// features/silentaim.lua
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

local SilentAim = {}

--// Налаштування (відповідають твоєму UI)
local settings = {
    Enabled = false,
    FOV = 200,
    HitChance = 100,
    Prediction = 0.135,
    TeamCheck = true,
    WallCheck = false,
    ShowFOV = true
}

local targetPart = nil
local oldIndex = nil
local fovCircle = nil

--// Створення кола FOV (через Drawing API, якщо є)
local function createFOVCircle()
    if fovCircle then fovCircle:Remove() end
    if Drawing then
        fovCircle = Drawing.new("Circle")
        fovCircle.Thickness = 1
        fovCircle.Color = Color3.fromRGB(120, 140, 255)
        fovCircle.Filled = false
        fovCircle.Radius = settings.FOV
        fovCircle.Visible = false
    end
end

--// Пошук цілі (найближчий гравець до центру екрану/миші в радіусі FOV)
local function getTarget()
    local closest = nil
    local shortestDist = settings.FOV
    
    -- Використовуємо позицію миші для перевірки відстані
    local mousePos = Vector2.new(Mouse.X, Mouse.Y + 36) -- 36 - це врахування GuiInset (верхня панель Roblox)

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local char = player.Character
            local hum = char:FindFirstChildOfClass("Humanoid")
            
            if hum and hum.Health > 0 then
                -- Перевірка команди
                if settings.TeamCheck and player.Team == LocalPlayer.Team then
                    continue
                end
                
                -- Шукаємо голову або HRP
                local part = char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
                
                if part then
                    -- Перевірка стін
                    if settings.WallCheck then
                        local rayParams = RaycastParams.new()
                        rayParams.FilterDescendantsInstances = {LocalPlayer.Character, char}
                        rayParams.FilterType = Enum.RaycastFilterType.Exclude
                        local result = Workspace:Raycast(workspace.CurrentCamera.CFrame.Position, part.Position - workspace.CurrentCamera.CFrame.Position, rayParams)
                        if result then continue end
                    end

                    -- Перевірка відстані до миші (FOV)
                    local screenPos, onScreen = workspace.CurrentCamera:WorldToViewportPoint(part.Position)
                    if onScreen then
                        local dist = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
                        if dist < shortestDist then
                            shortestDist = dist
                            closest = part
                        end
                    end
                end
            end
        end
    end
    
    return closest
end

--// Оновлення цілі кожен кадр
RunService.RenderStepped:Connect(function()
    if not settings.Enabled then
        targetPart = nil
        if fovCircle then fovCircle.Visible = false end
        return
    end

    -- Оновлення кола FOV
    if fovCircle then
        fovCircle.Position = Vector2.new(Mouse.X, Mouse.Y + 36)
        fovCircle.Radius = settings.FOV
        fovCircle.Visible = settings.ShowFOV
    end

    -- Оновлення цілі
    if math.random(1, 100) <= settings.HitChance then
        targetPart = getTarget()
    else
        targetPart = nil
    end
end)

--// Основна функція вмикання (Хук)
function SilentAim:setEnabled(state)
    settings.Enabled = state
    if state then
        if not oldIndex and hookmetamethod then
            oldIndex = hookmetamethod(game, "__index", function(self, key)
                -- Перехоплюємо тільки звернення гри (не нашого скрипта) до Mouse.Hit
                if not checkcaller() and self == Mouse and targetPart then
                    if key == "Hit" then
                        -- Додаємо Prediction (компенсація пінгу)
                        local predictedPos = targetPart.Position + (targetPart.Velocity * settings.Prediction)
                        return CFrame.new(predictedPos)
                    elseif key == "Target" then
                        return targetPart
                    end
                end
                return oldIndex(self, key)
            end)
        end
        createFOVCircle()
    else
        if oldIndex then
            hookmetamethod(game, "__index", oldIndex)
            oldIndex = nil
        end
        if fovCircle then
            fovCircle:Remove()
            fovCircle = nil
        end
    end
end

--// Експорт налаштувань для UI
function SilentAim:setFOV(val) settings.FOV = val end
function SilentAim:setHitChance(val) settings.HitChance = val end
function SilentAim:setPrediction(val) settings.Prediction = val end
function SilentAim:setTeamCheck(state) settings.TeamCheck = state end
function SilentAim:setWallCheck(state) settings.WallCheck = state end
function SilentAim:setShowFOV(state) settings.ShowFOV = state end

print("[TrustHub] Silent Aim (Pulse-style) loaded.")
return SilentAim
