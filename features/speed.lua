--// ==================================================
--// TrustHub - Speed Module
--// ==================================================

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

local Speed = {}
Speed.__index = Speed

function Speed.new()
    local self = setmetatable({}, Speed)
    self.enabled = false
    self.value = 32
    self:startLoop()
    return self
end

function Speed:startLoop()
    local self_ref = self
    
    RunService.Heartbeat:Connect(function()
        if not self_ref.enabled then return end
        
        local char = LocalPlayer.Character
        if not char then return end
        
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            hum.WalkSpeed = self_ref.value
        end
    end)
    
    -- Автоматичне застосування при респавні
    LocalPlayer.CharacterAdded:Connect(function(char)
        task.wait(0.5)
        if self_ref.enabled then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then hum.WalkSpeed = self_ref.value end
        end
    end)
end

--// API для UI
function Speed:setEnabled(state)
    self.enabled = state
    -- Якщо вимикаємо — повертаємо стандартну швидкість
    if not state then
        local char = LocalPlayer.Character
        if char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then hum.WalkSpeed = 16 end
        end
    end
end

function Speed:setValue(value)
    self.value = value
end

return Speed.new()
