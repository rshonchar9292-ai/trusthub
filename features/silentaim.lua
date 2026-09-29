--// ╔══════════════════════════════════════════════════════════════════════════╗
--// ║  TrustHub Silent Aim — ULTRA PRO EDITION                                 ║
--// ║  Dual Hook • Prediction • FOV • Role-Aware • Wall Check • Stats          ║
--// ║  Author: rshonchar9292-ai                                                ║
--// ╚══════════════════════════════════════════════════════════════════════════╝

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local StarterGui        = game:GetService("StarterGui")
local Workspace         = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local Camera      = Workspace.CurrentCamera
local Mouse       = LocalPlayer:GetMouse()

--// ============================================================
--//  CONFIG (всі налаштування тут)
--// ============================================================
local Config = {
    Enabled         = true,         -- Silent Aim активний одразу
    Method          = "both",       -- "namecall" | "index" | "both"
    
    -- Ціль
    TargetPart      = "Head",       -- "Head" | "HumanoidRootPart" | "UpperTorso" | "Closest"
    FOV             = 200,          -- радіус FOV (пікселі)
    ShowFOV         = true,         -- показувати коло FOV
    FOVColor        = Color3.fromRGB(255, 60, 60),
    FOVThickness    = 1.5,
    FOVFilled       = false,
    FOVTransparency = 0.85,
    
    -- Prediction
    Prediction      = true,         -- компенсація руху цілі
    PredictionAmount = 0.135,       -- стандартне значення (можна 0.1 - 0.2)
    
    -- Фільтри
    TeamCheck       = true,         -- ігнорувати союзників (role-aware для MM2)
    WallCheck       = false,        -- стріляти тільки якщо ціль видима
    HitChance       = 100,          -- % влучання
    MaxDistance     = 5000,         -- максимальна дистанція
    
    -- Debug
    LogEnabled      = true,
    NotifyEnabled   = true,
}

--// ============================================================
--//  STATE
--// ============================================================
local currentTarget = nil
local currentTargetPart = nil
local shots = 0
local hookedNamecall = false
local hookedIndex = false
local oldNamecall = nil
local oldIndex = nil
local connections = {}
local fovCircle = nil
local enabled = Config.Enabled

--// ============================================================
--//  LOG / NOTIFY
--// ============================================================
local function log(msg)
    if Config.LogEnabled then print("[SilentAim] " .. msg) end
end

local function notify(title, text, duration)
    if not Config.NotifyEnabled then return end
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = title, Text = text, Duration = duration or 2,
        })
    end)
end

--// ============================================================
--//  HELPERS
--// ============================================================
local function isAlive(plr)
    if not plr or not plr.Character then return false end
    local hum = plr.Character:FindFirstChildOfClass("Humanoid")
    return hum and hum.Health > 0
end

--// Role detection для MM2
local function getRole(plr)
    if not plr or not plr.Character then return "Dead" end
    local char = plr.Character
    for _, tool in ipairs(char:GetChildren()) do
        if tool:IsA("Tool") then
            local n = tool.Name:lower()
            if n:find("knife") or n:find("blade") or n:find("murder") then
                return "Murderer"
            end
        end
    end
    for _, tool in ipairs(char:GetChildren()) do
        if tool:IsA("Tool") then
            local n = tool.Name:lower()
            if n:find("gun") or n:find("pistol") or n:find("sheriff") then
                return "Sheriff"
            end
        end
    end
    return "Innocent"
end

local function getMyRole() return getRole(LocalPlayer) end

--// Team check (role-aware)
local function isEnemy(plr)
    if plr == LocalPlayer then return false end
    if not Config.TeamCheck then return true end
    
    local myRole = getMyRole()
    local theirRole = getRole(plr)
    
    -- Якщо я Murderer — вороги всі, крім Murderer
    if myRole == "Murderer" then
        return theirRole ~= "Murderer"
    end
    -- Інакше — ворог тільки Murderer
    return theirRole == "Murderer"
end

--// Wall check
local function hasLineOfSight(part)
    local origin = Camera.CFrame.Position
    local dir = part.Position - origin
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { LocalPlayer.Character }
    params.IgnoreWater = true
    local result = Workspace:Raycast(origin, dir, params)
    return result == nil
end

--// Prediction
local function predictPosition(part)
    if not Config.Prediction then return part.Position end
    local vel = part.AssemblyLinearVelocity
    -- Обмежуємо prediction, щоб не стріляти в стіну
    if vel.Magnitude > 100 then
        vel = vel.Unit * 100
    end
    return part.Position + (vel * Config.PredictionAmount)
end

--// Get target part
local function getTargetPart(char)
    if Config.TargetPart == "Closest" then
        local cursor = UserInputService:GetMouseLocation()
        local best, bestD = nil, math.huge
        for _, name in ipairs({ "Head", "UpperTorso", "HumanoidRootPart" }) do
            local p = char:FindFirstChild(name)
            if p and p:IsA("BasePart") then
                local sp = Camera:WorldToViewportPoint(p.Position)
                if sp.Z > 0 then
                    local d = (Vector2.new(sp.X, sp.Y) - cursor).Magnitude
                    if d < bestD then best, bestD = p, d end
                end
            end
        end
        return best or char:FindFirstChild("HumanoidRootPart")
    end
    return char:FindFirstChild(Config.TargetPart) or char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
end

--// ============================================================
--//  FIND BEST TARGET
--// ============================================================
local function findBestTarget()
    local cursor = UserInputService:GetMouseLocation()
    local viewport = Camera.ViewportSize
    local center = Vector2.new(viewport.X / 2, viewport.Y / 2)
    local origin = cursor -- або center, залежно від типу FOV
    
    local best, bestPart, bestD = nil, nil, math.huge
    
    for _, plr in ipairs(Players:GetPlayers()) do
        if not isAlive(plr) then continue end
        if not isEnemy(plr) then continue end
        
        local char = plr.Character
        local part = getTargetPart(char)
        if not part then continue end
        
        -- FOV check
        local sp = Camera:WorldToViewportPoint(part.Position)
        if sp.Z <= 0 then continue end
        local d = (Vector2.new(sp.X, sp.Y) - origin).Magnitude
        if d > Config.FOV then continue end
        
        -- Distance check
        local dist = (LocalPlayer.Character.HumanoidRootPart.Position - part.Position).Magnitude
        if dist > Config.MaxDistance then continue end
        
        -- Wall check
        if Config.WallCheck and not hasLineOfSight(part) then continue end
        
        if d < bestD then
            best, bestPart, bestD = plr, part, d
        end
    end
    
    return best, bestPart
end

--// ============================================================
--//  FOV CIRCLE
--// ============================================================
local function setupFOV()
    if fovCircle then fovCircle:Remove() end
    if not Drawing then return end
    
    fovCircle = Drawing.new("Circle")
    fovCircle.NumSides = 64
    fovCircle.Thickness = Config.FOVThickness
    fovCircle.Color = Config.FOVColor
    fovCircle.Filled = Config.FOVFilled
    fovCircle.Transparency = Config.FOVTransparency
    fovCircle.Visible = false
end

local function updateFOV()
    if not fovCircle then return end
    if not Config.ShowFOV or not enabled then
        fovCircle.Visible = false
        return
    end
    
    local pos
    if UserInputService.MouseEnabled then
        pos = UserInputService:GetMouseLocation()
    else
        pos = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    end
    
    fovCircle.Position = pos
    fovCircle.Radius = Config.FOV
    fovCircle.Color = Config.FOVColor
    fovCircle.Thickness = Config.FOVThickness
    fovCircle.Filled = Config.FOVFilled
    fovCircle.Transparency = Config.FOVTransparency
    fovCircle.Visible = true
end

--// ============================================================
--//  HOOK NAME CALL
--// ============================================================
local function hookNamecall()
    if hookedNamecall then return true end
    
    local mt = getrawmetatable(game)
    if not mt then return false end
    
    local old
    local ok = pcall(function()
        old = mt.__namecall
        setreadonly(mt, false)
        mt.__namecall = newcclosure(function(self, ...)
            local method = getnamecallmethod()
            local args = {...}
            
            if enabled and (method == "FireServer" or method == "InvokeServer") then
                -- Знаходимо ціль
                local target, targetPart = findBestTarget()
                if target and targetPart then
                    -- Перевірка шансу
                    if math.random(1, 100) <= Config.HitChance then
                        local aimPos = predictPosition(targetPart)
                        -- Підмінюємо всі Vector3 в аргументах
                        for i, arg in ipairs(args) do
                            if typeof(arg) == "Vector3" then
                                args[i] = aimPos
                            elseif typeof(arg) == "CFrame" then
                                local rot = arg - arg.Position
                                args[i] = CFrame.new(aimPos) * rot
                            elseif typeof(arg) == "table" then
                                for k, v in pairs(arg) do
                                    if typeof(v) == "Vector3" then
                                        arg[k] = aimPos
                                    end
                                end
                            end
                        end
                        shots = shots + 1
                        currentTarget = target
                        currentTargetPart = targetPart
                    end
                end
            end
            
            return old(self, unpack(args))
        end)
        setreadonly(mt, true)
    end)
    
    if ok then
        hookedNamecall = true
        oldNamecall = old
        log("✓ Hooked __namecall")
        return true
    end
    return false
end

--// ============================================================
--//  HOOK INDEX (Mouse.Hit / Target)
--// ============================================================
local function hookIndex()
    if hookedIndex then return true end
    
    local mt = getrawmetatable(game)
    if not mt then return false end
    
    local old
    local ok = pcall(function()
        old = mt.__index
        setreadonly(mt, false)
        mt.__index = newcclosure(function(self, key)
            if enabled and self == Mouse and (key == "Hit" or key == "Target") then
                local target, targetPart = findBestTarget()
                if target and targetPart then
                    local aimPos = predictPosition(targetPart)
                    if key == "Hit" then
                        return CFrame.new(aimPos)
                    else
                        return targetPart
                    end
                end
            end
            return old(self, key)
        end)
        setreadonly(mt, true)
    end)
    
    if ok then
        hookedIndex = true
        oldIndex = old
        log("✓ Hooked __index")
        return true
    end
    return false
end

--// ============================================================
--//  START / STOP
--// ============================================================
local function start()
    if enabled then return end
    enabled = true
    Config.Enabled = true
    
    if Config.Method == "namecall" or Config.Method == "both" then
        hookNamecall()
    end
    if Config.Method == "index" or Config.Method == "both" then
        hookIndex()
    end
    
    setupFOV()
    log("═══ Silent Aim ENABLED ═══")
    notify("💀 Silent Aim", "Enabled", 2)
end

local function stop()
    if not enabled then return end
    enabled = false
    Config.Enabled = false
    
    if hookedNamecall and oldNamecall then
        pcall(function()
            local mt = getrawmetatable(game)
            setreadonly(mt, false)
            mt.__namecall = oldNamecall
            setreadonly(mt, true)
        end)
        hookedNamecall = false
    end
    
    if hookedIndex and oldIndex then
        pcall(function()
            local mt = getrawmetatable(game)
            setreadonly(mt, false)
            mt.__index = oldIndex
            setreadonly(mt, true)
        end)
        hookedIndex = false
    end
    
    if fovCircle then
        fovCircle.Visible = false
    end
    
    log("Silent Aim DISABLED")
    notify("💀 Silent Aim", "Disabled", 2)
end

--// ============================================================
--//  RENDER LOOP (FOV update + auto target)
--// ============================================================
RunService.RenderStepped:Connect(function()
    if enabled then
        updateFOV()
        -- Оновлюємо ціль кожен кадр (для FOV підсвітки)
        local target, targetPart = findBestTarget()
        currentTarget = target
        currentTargetPart = targetPart
    end
end)

--// ============================================================
--//  CHARACTER RESPAWN (перепідключення)
--// ============================================================
LocalPlayer.CharacterAdded:Connect(function()
    if enabled then
        task.wait(1)
        if Config.Method == "namecall" or Config.Method == "both" then
            hookNamecall()
        end
        if Config.Method == "index" or Config.Method == "both" then
            hookIndex()
        end
        setupFOV()
    end
end)

--// ============================================================
--//  MODULE API
--// ============================================================
local SilentAim = {}
SilentAim.__index = SilentAim

function SilentAim.new()
    return setmetatable({}, SilentAim)
end

function SilentAim:setEnabled(state)
    if state then start() else stop() end
end

function SilentAim:setHitChance(v) Config.HitChance = v end
function SilentAim:setFOV(v) Config.FOV = v end
function SilentAim:setPrediction(v) Config.PredictionAmount = v end
function SilentAim:setTargetPart(v) Config.TargetPart = v end
function SilentAim:setTeamCheck(v) Config.TeamCheck = v end
function SilentAim:setWallCheck(v) Config.WallCheck = v end
function SilentAim:setShowFOV(v) Config.ShowFOV = v end
function SilentAim:setFOVColor(c) Config.FOVColor = c end
function SilentAim:setFOVThickness(v) Config.FOVThickness = v end
function SilentAim:setFOVFilled(v) Config.FOVFilled = v end
function SilentAim:setMethod(m)
    Config.Method = m
    stop()
    task.wait(0.1)
    start()
end

function SilentAim:getStats()
    return {
        Shots = shots,
        Enabled = enabled,
        Target = currentTarget and currentTarget.Name or "None",
    }
end

--// ============================================================
--//  INIT
--// ============================================================
task.wait(0.5)
start()

log("═══════════════════════════════")
log("TrustHub Silent Aim ULTRA loaded")
log("Dual Hook • Prediction • FOV")
log("═══════════════════════════════")

return SilentAim.new()
