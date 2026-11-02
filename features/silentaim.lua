--// features/silentaim.lua
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

local SilentAim = {}

--// ФІКСОВАНІ НАЛАШТУВАННЯ (найкращі для MM2)
local settings = {
    Enabled = false,
    FOV = 300,           -- Радіус дії (досить великий, щоб не водити мишкою)
    HitChance = 100,     -- Завжди влучає
    Prediction = 0.135,  -- Компенсація пінгу (ідеально для більшості серверів)
    TeamCheck = true,    -- Ігнорує союзників
    WallCheck = false,   -- Стріляє крізь стіни (якщо ворог за стіною)
    ShowFOV = true       -- Показує коло на екрані
}

local targetPart = nil
local oldIndex = nil
local fovCircle = nil

--// Створення кола FOV
local function updateFOVCircle()
    if not Drawing then return end
    if not fovCircle then
        fovCircle = Drawing.new("Circle")
        fovCircle.Thickness = 1
        fovCircle.Color = Color3.fromRGB(120, 140, 255)
        fovCircle.Filled = false
    end
    
    if settings.Enabled and settings.ShowFOV then
        fovCircle.Visible = true
        fovCircle.Radius = settings.FOV
        fovCircle.Position = Vector2.new(Mouse.X, Mouse.Y + 36)
    else
        fovCircle.Visible = false
    end
end

--// Пошук цілі
local function getTarget()
    local closest = nil
    local shortestDist = settings.FOV
    local mousePos = Vector2.new(Mouse.X, Mouse.Y + 36)

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local char = player.Character
            local hum = char:FindFirstChildOfClass("Humanoid")
            
            if hum and hum.Health > 0 then
                if settings.TeamCheck and player.Team == LocalPlayer.Team then
                    continue
                end
                
                local part = char:FindFirstChild("Head")
                
                if part then
                    if settings.WallCheck then
                        local rayParams = RaycastParams.new()
                        rayParams.FilterDescendantsInstances = {LocalPlayer.Character, char}
                        rayParams.FilterType = Enum.RaycastFilterType.Exclude
                        local result = Workspace:Raycast(workspace.CurrentCamera.CFrame.Position, part.Position - workspace.CurrentCamera.CFrame.Position, rayParams)
                        if result then continue end
                    end

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

--// Оновлення
RunService.RenderStepped:Connect(function()
    updateFOVCircle()
    
    if not settings.Enabled then
        targetPart = nil
        return
    end

    if math.random(1, 100) <= settings.HitChance then
        targetPart = getTarget()
    else
        targetPart = nil
    end
end)

--// Увімкнення / Вимкнення
function SilentAim:setEnabled(state)
    settings.Enabled = state
    
    if state then
        if not oldIndex and hookmetamethod then
            oldIndex = hookmetamethod(game, "__index", function(self, key)
                if not checkcaller() and self == Mouse and targetPart then
                    if key == "Hit" then
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

print("[TrustHub] Silent Aim (Auto-Config) loaded.")
return SilentAim
