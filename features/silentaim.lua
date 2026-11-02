--// features/silentaim.lua
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

local SilentAim = {}

--// Налаштування (ініціалізуються значеннями з UI)
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

--// Створення кола FOV (Drawing API)
local function updateFOVCircle()
    if not Drawing then return end
    if not fovCircle then
        fovCircle = Drawing.new("Circle")
        fovCircle.Thickness = 1
        fovCircle.Color = Color3.fromRGB(120, 140, 255) -- Колір акценту з UI
        fovCircle.Filled = false
    end
    
    if settings.Enabled and settings.ShowFOV then
        fovCircle.Visible = true
        fovCircle.Radius = settings.FOV
        -- Центруємо коло по миші (враховуємо GuiInset)
        fovCircle.Position = Vector2.new(Mouse.X, Mouse.Y + 36)
    else
        fovCircle.Visible = false
    end
end

--// Пошук найближчої цілі (Маніяк / Ворог)
local function getTarget()
    local closest = nil
    local shortestDist = settings.FOV
    local mousePos = Vector2.new(Mouse.X, Mouse.Y + 36)

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local char = player.Character
            local hum = char:FindFirstChildOfClass("Humanoid")
            
            if hum and hum.Health > 0 then
                -- Перевірка команди (Team Check)
                if settings.TeamCheck and player.Team == LocalPlayer.Team then
                    continue
                end
                
                -- Цілимось в голову
                local part = char:FindFirstChild("Head")
                
                if part then
                    -- Перевірка стін (Wall Check)
                    if settings.WallCheck then
                        local rayParams = RaycastParams.new()
                        rayParams.FilterDescendantsInstances = {LocalPlayer.Character, char}
                        rayParams.FilterType = Enum.RaycastFilterType.Exclude
                        local result = Workspace:Raycast(workspace.CurrentCamera.CFrame.Position, part.Position - workspace.CurrentCamera.CFrame.Position, rayParams)
                        if result then continue end
                    end

                    -- Перевірка FOV
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

--// Оновлення кожен кадр
RunService.RenderStepped:Connect(function()
    updateFOVCircle()
    
    if not settings.Enabled then
        targetPart = nil
        return
    end

    -- Перевірка Hit Chance (якщо випало 1 з 100, ціль скидається)
    if math.random(1, 100) <= settings.HitChance then
        targetPart = getTarget()
    else
        targetPart = nil
    end
end)

--// Увімкнення / Вимкнення (Pulse-style Hook)
function SilentAim:setEnabled(state)
    settings.Enabled = state
    
    if state then
        if not oldIndex and hookmetamethod then
            oldIndex = hookmetamethod(game, "__index", function(self, key)
                -- Перехоплюємо тільки звернення гри до Mouse.Hit / Target
                if not checkcaller() and self == Mouse and targetPart then
                    if key == "Hit" then
                        -- Prediction: передбачаємо позицію цілі з урахуванням її швидкості
                        local predictedPos = targetPart.Position + (targetPart.Velocity * settings.Prediction)
                        return CFrame.new(predictedPos)
                    elseif key == "Target" then
                        return targetPart
                    end
                end
                return oldIndex(self, key)
            end)
        end
    else
        if oldIndex then
            hookmetamethod(game, "__index", oldIndex)
            oldIndex = nil
        end
        targetPart = nil
    end
end

--// Експорт функцій для UI
function SilentAim:setFOV(val) settings.FOV = val end
function SilentAim:setHitChance(val) settings.HitChance = val end
function SilentAim:setPrediction(val) settings.Prediction = val end
function SilentAim:setTeamCheck(state) settings.TeamCheck = state end
function SilentAim:setWallCheck(state) settings.WallCheck = state end
function SilentAim:setShowFOV(state) settings.ShowFOV = state end

print("[TrustHub] Silent Aim (Pulse Hook) loaded.")
return SilentAim
