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
    self.fov = 200
    self.aimPart = "Head"
    self.hitChance = 100
    self.wallBang = true
    self.showFov = true
    self.hookedScripts = {}
    
    -- FOV circle
    self.fovCircle = Drawing.new("Circle")
    self.fovCircle.NumSides = 64
    self.fovCircle.Thickness = 1.5
    self.fovCircle.Color = Color3.fromRGB(255, 60, 60)
    self.fovCircle.Filled = false
    self.fovCircle.Transparency = 0.85
    self.fovCircle.Visible = false
    
    self:startLoop()
    return self
end

function SilentAim:isAlive(plr)
    local char = plr.Character
    if not char then return false end
    local hum = char:FindFirstChildOfClass("Humanoid")
    return hum and hum.Health > 0
end

function SilentAim:findTarget()
    local mousePos = UserInputService:GetMouseLocation()
    local closest, closestDist = nil, math.huge

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == LocalPlayer then continue end
        if not self:isAlive(plr) then continue end

        local char = plr.Character
        local part = char:FindFirstChild(self.aimPart)
            or char:FindFirstChild("HumanoidRootPart")
        if not part then continue end

        if not self.wallBang then
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

function SilentAim:hook()
    local char = LocalPlayer.Character
    if not char then return false end

    local tool = char:FindFirstChildWhichIsA("Tool")
    if not tool then return false end

    local gunScript
    for _, child in ipairs(tool:GetDescendants()) do
        if child.Name == "GunScript_Local" and child:IsA("LocalScript") then
            gunScript = child
            break
        end
    end
    if not gunScript then return false end
    if self.hookedScripts[gunScript] then return true end

    local ok, env = pcall(getsenv, gunScript)
    if not ok or not env or not env.Fire then return false end

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
                            args[i] = target.Position + Vector3.new(0, 0.1, 0)
                        end
                    end
                end
            end
        end
        return oldFire(unpack(args))
    end

    self.hookedScripts[gunScript] = true
    print("[TrustHub] SilentAim: GunScript hooked ✓")
    return true
end

function SilentAim:startLoop()
    local self_ref = self
    
    RunService.RenderStepped:Connect(function()
        if self_ref.fovCircle then
            if self_ref.enabled and self_ref.showFov then
                self_ref.fovCircle.Visible = true
                self_ref.fovCircle.Radius = self_ref.fov
                self_ref.fovCircle.Position = UserInputService:GetMouseLocation()
            else
                self_ref.fovCircle.Visible = false
            end
        end
    end)
    
    LocalPlayer.CharacterAdded:Connect(function()
        task.wait(1.5)
        self_ref:hook()
    end)
    
    task.spawn(function()
        while task.wait(2) do
            if self_ref.enabled then
                self_ref:hook()
            end
        end
    end)
    
    task.wait(0.5)
    self:hook()
end

function SilentAim:setEnabled(state)
    self.enabled = state
    if state then self:hook() end
end

function SilentAim:setFOV(value) self.fov = value end
function SilentAim:setAimPart(part) self.aimPart = part end
function SilentAim:setHitChance(v) self.hitChance = v end
function SilentAim:setWallBang(v) self.wallBang = v end
function SilentAim:setShowFOV(v) self.showFov = v end

return SilentAim.new()
