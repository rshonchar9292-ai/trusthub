--// ==================================================
--// TrustHub - Silent Aim Module
--// ==================================================

local Players          = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService       = game:GetService("RunService")
local LocalPlayer      = Players.LocalPlayer
local Camera           = workspace.CurrentCamera

local SilentAim = {}
SilentAim.__index = SilentAim

function SilentAim.new()
    local self = setmetatable({}, SilentAim)
    self.enabled = false
    self.fov = 150
    self.aimPart = "Head"
    self.hitChance = 100
    self.wallCheck = false
    self.hookedScripts = {}
    self.fovCircle = nil
    self:createFOVCircle()
    self:startLoop()
    return self
end

--// FOV Circle (Drawing)
function SilentAim:createFOVCircle()
    self.fovCircle = Drawing.new("Circle")
    self.fovCircle.NumSides = 64
    self.fovCircle.Thickness = 1.5
    self.fovCircle.Color = Color3.fromRGB(255, 60, 60)
    self.fovCircle.Filled = false
    self.fovCircle.Transparency = 0.85
    self.fovCircle.Visible = false
end

--// Знайти ціль
function SilentAim:findTarget()
    local mousePos = UserInputService:GetMouseLocation()
    local closest, closestDist = nil, math.huge
    
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == LocalPlayer then continue end
        local char = plr.Character
        if not char then continue end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 then continue end
        
        local part = char:FindFirstChild(self.aimPart)
            or char:FindFirstChild("HumanoidRootPart")
        if not part then continue end
        
        -- Wall check (тільки якщо wallCheck = true)
        if self.wallCheck then
            local parts = Camera:GetPartsObscuringTarget(
                {part.Position},
                {LocalPlayer.Character, char}
            )
            if #parts > 0 then continue end
        end
        
        local screenPos, onScreen = Camera:WorldToViewportPoint(part.Position)
        if not onScreen then continue end
        
        local dist = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
        if dist < closestDist and dist <= self.fov then
            closestDist = dist
            closest = part
        end
    end
    
    return closest
end

--// Хук на GunScript
function SilentAim:hook()
    local char = LocalPlayer.Character
    if not char then return end
    
    local tool = char:FindFirstChildWhichIsA("Tool")
    if not tool then return end
    
    local gunScript
    for _, child in ipairs(tool:GetDescendants()) do
        if child.Name == "GunScript_Local" and child:IsA("LocalScript") then
            gunScript = child
            break
        end
    end
    if not gunScript or self.hookedScripts[gunScript] then return end
    
    local ok, env = pcall(getsenv, gunScript)
    if not ok or not env or not env.Fire then return end
    
    local self_ref = self
    local oldFire = env.Fire
    env.Fire = function(...)
        local args = {...}
        if self_ref.enabled then
            if math.random(1, 100) <= self_ref.hitChance then
                local target = self_ref:findTarget()
                if target then
                    for i, arg in ipairs(args) do
                        if typeof(arg) == "Vector3" then
                            args[i] = target.Position
                        end
                    end
                end
            end
        end
        return oldFire(unpack(args))
    end
    
    self.hookedScripts[gunScript] = true
    print("[TrustHub] SilentAim: GunScript hooked ✓")
end

--// Loop оновлення FOV + автопідключення
function SilentAim:startLoop()
    local self_ref = self
    RunService.RenderStepped:Connect(function()
        if self_ref.fovCircle then
            if self_ref.enabled then
                self_ref.fovCircle.Visible = true
                self_ref.fovCircle.Radius = self_ref.fov
                self_ref.fovCircle.Position = UserInputService:GetMouseLocation()
            else
                self_ref.fovCircle.Visible = false
            end
        end
    end)
    
    -- Автоматичне перепідключення хука
    LocalPlayer.CharacterAdded:Connect(function()
        task.wait(1.5)
        self_ref:hook()
    end)
    
    -- Періодична спроба
    task.spawn(function()
        while task.wait(2) do
            if self_ref.enabled then
                self_ref:hook()
            end
        end
    end)
end

--// API методи (викликаються з UI)
function SilentAim:setEnabled(state)
    self.enabled = state
    if state then self:hook() end
end

function SilentAim:setFOV(value)
    self.fov = value
end

function SilentAim:setAimPart(part)
    self.aimPart = part
end

function SilentAim:setHitChance(value)
    self.hitChance = value
end

function SilentAim:setWallCheck(value)
    self.wallCheck = value
end

return SilentAim.new()
