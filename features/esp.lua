--// ==================================================
--// TrustHub - ESP Module (MM2 Roles)
--// ==================================================

local Players       = game:GetService("Players")
local RunService    = game:GetService("RunService")
local LocalPlayer   = Players.LocalPlayer
local Camera        = workspace.CurrentCamera

--// Кольори ролей MM2
local RoleColors = {
    Murderer = Color3.fromRGB(255, 50, 50),    -- Червоний
    Sheriff  = Color3.fromRGB(50, 150, 255),   -- Синій
    Innocent = Color3.fromRGB(50, 220, 100),   -- Зелений
    Hero     = Color3.fromRGB(255, 215, 0),    -- Золотий
    Unknown  = Color3.fromRGB(200, 200, 200),  -- Сірий
}

--// Іконки ролей (букви, бо емодзі не рендеряться)
local RoleIcons = {
    Murderer = "🔪",
    Sheriff  = "🔫",
    Innocent = "👤",
    Hero     = "⭐",
    Unknown  = "?",
}

local ESP = {}
ESP.__index = ESP

function ESP.new()
    local self = setmetatable({}, ESP)
    self.enabled        = false
    self.showBox        = true
    self.showName       = true
    self.showRole       = true
    self.showHealth     = true
    self.showDistance   = true
    self.showTracer     = false
    self.onlyEnemies    = false  -- показувати тільки ворогів (за твоєю роллю)
    self.objects        = {}
    self:startLoop()
    return self
end

--// Отримати роль гравця
local function getRole(plr)
    local role = plr:GetAttribute("Role")
    if role and RoleColors[role] then
        return role, RoleColors[role]
    end
    return "Unknown", RoleColors.Unknown
end

--// Хто мій ворог (за роллю)
local function isEnemy(plr)
    if plr == LocalPlayer then return false end
    local myRole = LocalPlayer:GetAttribute("Role") or "Innocent"
    local theirRole = plr:GetAttribute("Role") or "Innocent"
    
    if myRole == "Murderer" then
        return theirRole ~= "Murderer"
    end
    -- Sheriff / Innocent / Hero
    return theirRole == "Murderer"
end

--// Створити ESP-об'єкти для гравця
function ESP:create(plr)
    if self.objects[plr] then return self.objects[plr] end
    
    -- BillboardGui для тексту
    local bb = Instance.new("BillboardGui")
    bb.Name = "TrustHubESP"
    bb.Size = UDim2.new(0, 140, 0, 58)
    bb.StudsOffsetWorldSpace = Vector3.new(0, 3.5, 0)
    bb.AlwaysOnTop = true
    bb.ResetOnSpawn = false
    
    local container = Instance.new("Frame")
    container.Size = UDim2.new(1, 0, 1, 0)
    container.BackgroundTransparency = 1
    container.Parent = bb
    
    -- Роль + Ім'я
    local nameLbl = Instance.new("TextLabel")
    nameLbl.Name = "Name"
    nameLbl.Size = UDim2.new(1, 0, 0, 16)
    nameLbl.BackgroundTransparency = 1
    nameLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
    nameLbl.TextStrokeTransparency = 0.3
    nameLbl.Font = Enum.Font.GothamBold
    nameLbl.TextSize = 12
    nameLbl.Text = ""
    nameLbl.Parent = container
    
    -- Відстань
    local distLbl = Instance.new("TextLabel")
    distLbl.Name = "Distance"
    distLbl.Size = UDim2.new(1, 0, 0, 14)
    distLbl.Position = UDim2.new(0, 0, 0, 16)
    distLbl.BackgroundTransparency = 1
    distLbl.TextColor3 = Color3.fromRGB(230, 230, 240)
    distLbl.TextStrokeTransparency = 0.3
    distLbl.Font = Enum.Font.Gotham
    distLbl.TextSize = 11
    distLbl.Parent = container
    
    -- Health bar (фон)
    local hBg = Instance.new("Frame")
    hBg.Name = "HealthBg"
    hBg.Size = UDim2.new(1, 0, 0, 5)
    hBg.Position = UDim2.new(0, 0, 0, 34)
    hBg.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
    hBg.BorderSizePixel = 0
    hBg.Parent = container
    local hCorner = Instance.new("UICorner")
    hCorner.CornerRadius = UDim.new(1, 0)
    hCorner.Parent = hBg
    
    -- Health fill
    local hFill = Instance.new("Frame")
    hFill.Name = "HealthFill"
    hFill.Size = UDim2.new(1, 0, 1, 0)
    hFill.BackgroundColor3 = Color3.fromRGB(90, 220, 130)
    hFill.BorderSizePixel = 0
    hFill.Parent = hBg
    local hfCorner = Instance.new("UICorner")
    hfCorner.CornerRadius = UDim.new(1, 0)
    hfCorner.Parent = hFill
    
    -- Drawing: Box
    local box = Drawing.new("Square")
    box.Thickness = 1.5
    box.Filled = false
    box.Transparency = 0.9
    box.Color = Color3.fromRGB(255, 255, 255)
    box.Visible = false
    
    -- Drawing: Tracer
    local tracer = Drawing.new("Line")
    tracer.Thickness = 1.5
    tracer.Transparency = 0.8
    tracer.Color = Color3.fromRGB(255, 255, 255)
    tracer.Visible = false
    
    self.objects[plr] = {
        Billboard = bb,
        Name = nameLbl,
        Distance = distLbl,
        HealthBg = hBg,
        HealthFill = hFill,
        Box = box,
        Tracer = tracer,
    }
    
    return self.objects[plr]
end

--// Видалити ESP гравця
function ESP:remove(plr)
    local data = self.objects[plr]
    if not data then return end
    if data.Billboard then data.Billboard:Destroy() end
    if data.Box then data.Box:Remove() end
    if data.Tracer then data.Tracer:Remove() end
    self.objects[plr] = nil
end

--// Головний цикл
function ESP:startLoop()
    local self_ref = self
    
    Players.PlayerRemoving:Connect(function(plr)
        self_ref:remove(plr)
    end)
    
    RunService.RenderStepped:Connect(function()
        -- Якщо вимкнено — чистимо
        if not self_ref.enabled then
            for plr, _ in pairs(self_ref.objects) do
                self_ref:remove(plr)
            end
            return
        end
        
        local vp = Camera.ViewportSize
        local centerX = vp.X / 2
        local centerY = vp.Y
        
        for _, plr in ipairs(Players:GetPlayers()) do
            -- Пропускаємо себе
            if plr == LocalPlayer then
                self_ref:remove(plr)
                continue
            end
            
            -- Перевірка на живого
            local char = plr.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            local head = char and char:FindFirstChild("Head")
            
            if not char or not hum or hum.Health <= 0 or not hrp or not head then
                self_ref:remove(plr)
                continue
            end
            
            -- Фільтр ворогів
            if self_ref.onlyEnemies and not isEnemy(plr) then
                self_ref:remove(plr)
                continue
            end
            
            -- Отримуємо роль і колір
            local role, color = getRole(plr)
            
            -- Створюємо ESP
            local data = self_ref:create(plr)
            data.Billboard.Adornee = head
            
            -- Name + Role icon
            data.Name.Visible = self_ref.showName
            if self_ref.showRole then
                data.Name.Text = role .. " | " .. plr.Name
            else
                data.Name.Text = plr.Name
            end
            data.Name.TextColor3 = color
            
            -- Distance
            data.Distance.Visible = self_ref.showDistance
            local dist = math.floor((Camera.CFrame.Position - hrp.Position).Magnitude)
            data.Distance.Text = dist .. " studs"
            
            -- Health
            data.HealthBg.Visible = self_ref.showHealth
            local hp = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
            data.HealthFill.Size = UDim2.new(hp, 0, 1, 0)
            data.HealthFill.BackgroundColor3 = Color3.fromRGB(
                math.floor(255 * (1 - hp)),
                math.floor(255 * hp),
                80
            )
            
            -- BOX (Drawing) — малюємо рамку навколо персонажа
            local screenPos, onScreen = Camera:WorldToViewportPoint(hrp.Position)
            local anyVisible = false
            local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
            
            if self_ref.showBox and onScreen then
                -- Використовуємо 8 кутів персонажа (розмір ~4x5x2)
                local cf = hrp.CFrame
                local charSize = Vector3.new(4, 5, 2)  -- приблизний розмір персонажа MM2
                local corners = {
                    Vector3.new(-1, -1, -1), Vector3.new(1, -1, -1),
                    Vector3.new(-1,  1, -1), Vector3.new(1,  1, -1),
                    Vector3.new(-1, -1,  1), Vector3.new(1, -1,  1),
                    Vector3.new(-1,  1,  1), Vector3.new(1,  1,  1),
                }
                
                for _, corner in ipairs(corners) do
                    local worldPos = (cf * CFrame.new(
                        corner.X * charSize.X / 2,
                        corner.Y * charSize.Y / 2,
                        corner.Z * charSize.Z / 2
                    )).Position
                    
                    local sp, vis = Camera:WorldToViewportPoint(worldPos)
                    if vis then
                        anyVisible = true
                        minX = math.min(minX, sp.X)
                        minY = math.min(minY, sp.Y)
                        maxX = math.max(maxX, sp.X)
                        maxY = math.max(maxY, sp.Y)
                    end
                end
                
                if anyVisible and maxX > minX and maxY > minY then
                    local w = maxX - minX
                    local h = maxY - minY
                    
                    data.Box.Size = Vector2.new(w, h)
                    data.Box.Position = Vector2.new(minX, minY)
                    data.Box.Color = color
                    data.Box.Visible = true
                else
                    data.Box.Visible = false
                end
            else
                data.Box.Visible = false
            end
            
            -- Tracer
            if self_ref.showTracer and anyVisible then
                data.Tracer.From = Vector2.new(centerX, centerY)
                data.Tracer.To = Vector2.new((minX + maxX) / 2, maxY)
                data.Tracer.Color = color
                data.Tracer.Visible = true
            else
                data.Tracer.Visible = false
            end
        end
    end)
end

--// API для UI
function ESP:setEnabled(state) self.enabled = state end
function ESP:setBox(state) self.showBox = state end
function ESP:setName(state) self.showName = state end
function ESP:setRole(state) self.showRole = state end
function ESP:setHealth(state) self.showHealth = state end
function ESP:setDistance(state) self.showDistance = state end
function ESP:setTracer(state) self.showTracer = state end
function ESP:setOnlyEnemies(state) self.onlyEnemies = state end

return ESP.new()
