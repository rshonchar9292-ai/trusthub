--// ==================================================
--// TrustHub - ESP Module (MM2 Roles via Highlight)
--// ==================================================

local Players       = game:GetService("Players")
local RunService    = game:GetService("RunService")
local LocalPlayer   = Players.LocalPlayer

local ESP = {}
ESP.__index = ESP

--// ==================================================
--// ВИЗНАЧЕННЯ РОЛІ (з твого скрипта)
--// ==================================================
local function getPlayerRole(player)
    local char = player.Character
    if not char then return "Dead" end
    
    -- Шукаємо ніж (Murderer) в руках
    for _, tool in pairs(char:GetChildren()) do
        if tool:IsA("Tool") then
            local toolName = tool.Name:lower()
            if toolName:find("knife") or toolName:find("blade") or toolName:find("murder") then
                return "Murderer"
            end
        end
    end
    
    -- Шукаємо пістолет (Sheriff) в руках
    for _, tool in pairs(char:GetChildren()) do
        if tool:IsA("Tool") then
            local toolName = tool.Name:lower()
            if toolName:find("gun") or toolName:find("pistol") 
               or toolName:find("sheriff") or toolName:find("revolver") then
                return "Sheriff"
            end
        end
    end
    
    -- Перевіряємо Backpack
    local backpack = player:FindFirstChild("Backpack")
    if backpack then
        for _, tool in pairs(backpack:GetChildren()) do
            if tool:IsA("Tool") then
                local toolName = tool.Name:lower()
                if toolName:find("gun") or toolName:find("pistol") 
                   or toolName:find("sheriff") or toolName:find("revolver") then
                    return "Sheriff"
                end
                if toolName:find("knife") or toolName:find("blade") 
                   or toolName:find("murder") then
                    return "Murderer"
                end
            end
        end
    end
    
    return "Innocent"
end

--// ==================================================
--// КОЛІР РОЛІ
--// ==================================================
local function getRoleColor(role)
    if role == "Murderer" then return Color3.fromRGB(255, 50, 50)     -- червоний
    elseif role == "Sheriff" then return Color3.fromRGB(50, 150, 255) -- синій
    elseif role == "Innocent" then return Color3.fromRGB(50, 255, 100)-- зелений
    else return Color3.fromRGB(150, 150, 150)                          -- сірий (мертвий)
    end
end

--// ==================================================
--// СТВОРЕННЯ ESP
--// ==================================================
function ESP.new()
    local self = setmetatable({}, ESP)
    self.enabled = false
    self.objects = {}   -- [player] = Highlight
    self.conns = {}     -- всі підключення
    self:startLoop()
    return self
end

function ESP:createESP(player)
    if self.objects[player] then return end
    
    local highlight = Instance.new("Highlight")
    highlight.Name = "TrustHubESP"
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.FillTransparency = 0.5
    highlight.OutlineTransparency = 0.2
    highlight.OutlineColor = Color3.new(1, 1, 1)
    highlight.Enabled = true
    
    -- Початковий колір
    local role = getPlayerRole(player)
    highlight.FillColor = getRoleColor(role)
    
    if player.Character then
        highlight.Parent = player.Character
    end
    
    self.objects[player] = highlight
    
    -- Оновлюємо колір щокадру (бо роль може змінитись)
    local conn = RunService.Heartbeat:Connect(function()
        if not player.Parent or not highlight.Parent then return end
        local newRole = getPlayerRole(player)
        highlight.FillColor = getRoleColor(newRole)
    end)
    table.insert(self.conns, conn)
end

function ESP:removeESP(player)
    local h = self.objects[player]
    if h then h:Destroy() end
    self.objects[player] = nil
end

function ESP:startLoop()
    local self_ref = self
    
    -- При респавні гравця — переприкріплюємо Highlight
    Players.PlayerAdded:Connect(function(plr)
        plr.CharacterAdded:Connect(function(char)
            if not self_ref.enabled then return end
            task.wait(0.5)
            local h = self_ref.objects[plr]
            if h then
                h.Parent = char
            else
                self_ref:createESP(plr)
            end
        end)
    end)
    
    -- Те саме для тих, хто вже на сервері
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            plr.CharacterAdded:Connect(function(char)
                if not self_ref.enabled then return end
                task.wait(0.5)
                local h = self_ref.objects[plr]
                if h then
                    h.Parent = char
                else
                    self_ref:createESP(plr)
                end
            end)
        end
    end
    
    Players.PlayerRemoving:Connect(function(plr)
        self_ref:removeESP(plr)
    end)
end

--// ==================================================
--// API для UI
--// ==================================================
function ESP:setEnabled(state)
    self.enabled = state
    
    if state then
        -- Створюємо ESP для всіх гравців
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer then
                self:createESP(plr)
            end
        end
        print("[TrustHub] ESP: ON")
    else
        -- Видаляємо всі ESP
        for plr, _ in pairs(self.objects) do
            self:removeESP(plr)
        end
        print("[TrustHub] ESP: OFF")
    end
end

--// Заглушки для сумісності з UI (можна вмикати потім)
function ESP:setBox(state) end
function ESP:setName(state) end
function ESP:setHealth(state) end
function ESP:setDistance(state) end
function ESP:setTracer(state) end
function ESP:setTeamCheck(state) end
function ESP:setColor(color) end

return ESP.new()
