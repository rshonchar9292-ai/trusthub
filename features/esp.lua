--// ==================================================
--// TrustHub - ESP Module
--// ==================================================

local Players       = game:GetService("Players")
local RunService    = game:GetService("RunService")
local LocalPlayer   = Players.LocalPlayer
local Camera        = workspace.CurrentCamera

local ESP = {}
ESP.__index = ESP

function ESP.new()
    local self = setmetatable({}, ESP)
    self.enabled = false
    self.showBox = true
    self.showName = true
    self.showHealth = true
    self.showDistance = true
    self.showTracer = false
    self.teamCheck = true
    self.boxColor = Color3.fromRGB(255, 100, 100)
    self.objects = {}
    self:startLoop()
    return self
end

--// Перевірка ролі (для MM2)
local function isEnemy(plr)
    if plr == LocalPlayer then return false end
    local myRole = LocalPlayer:GetAttribute("Role") or "Innocent"
    local theirRole = plr:GetAttribute("Role") or "Innocent"
    
    if myRole == "Murderer" then
        return theirRole ~= "Murderer"
    end
    return theirRole == "Murderer"
end

--// Створити ESP для гравця
function ESP:create(plr)
    if self.objects[plr] then return self.objects[plr] end
    
    -- Billboard (Name + Distance + Health)
    local bb = Instance.new("BillboardGui")
    bb.Name = "TrustHubESP"
    bb.Size = UDim2.new(0, 120, 0, 46)
    bb.StudsOffset = Vector3.new(0, 3.2, 0)
    bb.AlwaysOnTop = true
    bb.ResetOnSpawn = false
    
    local cont = Instance.new("Frame")
    cont.Size = UDim2.new(1, 0, 1, 0)
    cont.BackgroundTransparency = 1
    cont.Parent = bb
    
    local nameLbl = Instance.new("TextLabel")
    nameLbl.Name = "Name"
    nameLbl.Size = UDim2.new(1, 0, 0, 16)
    nameLbl.BackgroundTransparency = 1
    nameLbl.TextColor3 = self.boxColor
    nameLbl.TextStrokeTransparency = 0.2
    nameLbl.Font = Enum.Font.GothamBold
    nameLbl.TextSize = 12
    nameLbl.Text = plr.Name
    nameLbl.Parent = cont
    
    local distLbl = Instance.new("TextLabel")
    distLbl.Name = "Distance"
    distLbl.Size = UDim2.new(1, 0, 0, 14)
    distLbl.Position = UDim2.new(0, 0, 0, 16)
    distLbl.BackgroundTransparency = 1
    distLbl.TextColor3 = Color3.fromRGB(235, 235, 245)
    distLbl.TextStrokeTransparency = 0.2
    distLbl.Font = Enum.Font.Gotham
    distLbl.TextSize = 11
    distLbl.Parent = cont
    
    local hBg = Instance.new("Frame")
    hBg.Name = "HealthBg"
    hBg.Size = UDim2.new(1, 0, 0, 4)
    hBg.Position = UDim2.new(0, 0, 0, 32)
    hBg.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    hBg.BorderSizePixel = 0
    hBg.Parent = cont
    local hc = Instance.new("UICorner")
    hc.CornerRadius = UDim.new(1, 0)
    hc.Parent = hBg
    
    local hFill = Instance.new("Frame")
    hFill.Name = "HealthFill"
    hFill.Size = UDim2.new(1, 0, 1, 0)
    hFill.BackgroundColor3 = Color3.fromRGB(90, 220, 130)
    hFill.BorderSizePixel = 0
    hFill.Parent = hBg
    local hfc = Instance.new("UICorner")
    hfc.CornerRadius = UDim.new(1, 0)
    hfc.Parent = hFill
    
    -- Drawing об'єкти (Box, Tracer)
    local box = Drawing.new("Square")
    box.Thickness = 1.5
    box.Filled = false
    box.Transparency = 0.9
    box.Color = self.boxColor
    box.Visible = false
    
    local tracer = Drawing.new("Line")
    tracer.Thickness = 1.5
    tracer.Color = self.boxColor
    tracer.Transparency = 0.8
    tracer.Visible = false
    
    self.objects[plr] = {
        Billboard = bb,
        Name = nameLbl,
        Distance = distLbl,
        HealthFill = hFill,
        Box = box,
        Tracer = tracer,
    }
    
    return self.objects[plr]
end

--// Видалити ESP
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
        -- Якщо вимкнено — чистимо все
        if not self_ref.enabled then
            for plr, _ in pairs(self_ref.objects) do
                self_ref:remove(plr)
            end
            return
        end
        
        local vp = Camera.ViewportSize
        
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr == LocalPlayer then continue end
            
            local char = plr.Character
            if not char then
                self_ref:remove(plr)
                continue
            end
            
            local hum = char:FindFirstChildOfClass("Humanoid")
            local hrp = char:FindFirstChild("HumanoidRootPart")
            local head = char:FindFirstChild("Head")
            
            if not hum or hum.Health <= 0 or not hrp or not head then
                self_ref:remove(plr)
                continue
            end
            
            -- Team/Role check
            if self_ref.teamCheck and not isEnemy(plr) then
                self_ref:remove(plr)
                continue
            end
            
            local data = self_ref:create(plr)
            data.Billboard.Adornee = head
            
            -- Name
            data.Name.Visible = self_ref.showName
            data.Name.Text = plr.Name
            data.Name.TextColor3 = self_ref.boxColor
            
            -- Distance
            data.Distance.Visible = self_ref.showDistance
            local dist = math.floor((Camera.CFrame.Position - hrp.Position).Magnitude)
            data.Distance.Text = dist .. " studs"
            
            -- Health
            data.HealthFill.Parent.Visible = self_ref.showHealth
            local hp = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
            data.HealthFill.Size = UDim2.new(hp, 0, 1, 0)
            data.HealthFill.BackgroundColor3 = Color3.fromRGB(
                math.floor(255 * (1 - hp)),
                math.floor(255 * hp),
                80
            )
            
            -- Box (Drawing)
            local screenPos, onScreen = Camera:WorldToViewportPoint(hrp.Position)
            local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
            local anyVisible = false
            
            if self_ref.showBox and onScreen then
                local cf = hrp.CFrame
                local offsets = {
                    Vector3.new(-2, -3, -1), Vector3.new(2, -3, -1),
                    Vector3.new(-2, 3, -1),  Vector3.new(2, 3, -1),
                    Vector3.new(-2, -3, 1),  Vector3.new(2, -3, 1),
                    Vector3.new(-2, 3, 1),   Vector3.new(2, 3, 1),
                }
                for _, off in ipairs(offsets) do
                    local sp, vis = Camera:WorldToViewportPoint((cf * off).Position)
                    if vis then
                        anyVisible = true
                        minX = math.min(minX, sp.X); maxX = math.max(maxX, sp.X)
                        minY = math.min(minY, sp.Y); maxY = math.max(maxY, sp.Y)
                    end
                end
                
                if anyVisible then
                    data.Box.Size = Vector2.new(maxX - minX, maxY - minY)
                    data.Box.Position = Vector2.new(minX, minY)
                    data.Box.Color = self_ref.boxColor
                    data.Box.Visible = true
                else
                    data.Box.Visible = false
                end
            else
                data.Box.Visible = false
            end
            
            -- Tracer
            if self_ref.showTracer and anyVisible then
                data.Tracer.From = Vector2.new(vp.X / 2, vp.Y)
                data.Tracer.To = Vector2.new((minX + maxX) / 2, maxY)
                data.Tracer.Color = self_ref.boxColor
                data.Tracer.Visible = true
            else
                data.Tracer.Visible = false
            end
        end
    end)
end

--// API для UI
function ESP:setEnabled(state)
    self.enabled = state
end

function ESP:setBox(state) self.showBox = state end
function ESP:setName(state) self.showName = state end
function ESP:setHealth(state) self.showHealth = state end
function ESP:setDistance(state) self.showDistance = state end
function ESP:setTracer(state) self.showTracer = state end
function ESP:setTeamCheck(state) self.teamCheck = state end
function ESP:setColor(color)
    self.boxColor = color
    for _, data in pairs(self.objects) do
        data.Name.TextColor3 = color
        data.Box.Color = color
        data.Tracer.Color = color
    end
end

return ESP.new()
