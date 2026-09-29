--// ╔══════════════════════════════════════════════════════════════╗
--// ║  TrustHub Silent Aim v3.1 — Fixed                             ║
--// ║  Не блокує постріл • Тільки підмінює координати              ║
--// ╚══════════════════════════════════════════════════════════════╝

local Players          = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local StarterGui       = game:GetService("StarterGui")
local Workspace        = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local Camera      = Workspace.CurrentCamera

--// ============================================================
--//  CONFIG
--// ============================================================
local Config = {
    Enabled     = false,
    FOV         = 200,
    HitChance   = 100,
    Prediction  = 0.135,
    TeamCheck   = true,
    WallCheck   = false,
    ShowFOV     = true,
    FOVColor    = Color3.fromRGB(255, 60, 60),
    TargetPart  = "Head",
    LogEnabled  = true,
}

--// ============================================================
--//  STATE
--// ============================================================
local enabled = false
local hookedNamecall = false
local oldNamecall = nil
local fovCircle = nil
local currentTarget = nil
local shots = 0

--// ============================================================
--//  LOG
--// ============================================================
local function log(msg)
    if Config.LogEnabled then print("[SilentAim] " .. msg) end
end

local function notify(title, text, duration)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = title, Text = text, Duration = duration or 2,
        })
    end)
end

--// ============================================================
--//  ROLE DETECTION
--// ============================================================
local function getRole(plr)
    if not plr or not plr.Character then return "Dead" end
    for _, tool in ipairs(plr.Character:GetChildren()) do
        if tool:IsA("Tool") then
            local n = tool.Name:lower()
            if n:find("knife") or n:find("blade") or n:find("murder") then
                return "Murderer"
            end
        end
    end
    for _, tool in ipairs(plr.Character:GetChildren()) do
        if tool:IsA("Tool") then
            local n = tool.Name:lower()
            if n:find("gun") or n:find("pistol") or n:find("sheriff") then
                return "Sheriff"
            end
        end
    end
    return "Innocent"
end

local function isEnemy(plr)
    if plr == LocalPlayer then return false end
    if not Config.TeamCheck then return true end
    local myRole = getRole(LocalPlayer)
    local theirRole = getRole(plr)
    if myRole == "Murderer" then
        return theirRole ~= "Murderer"
    end
    return theirRole == "Murderer"
end

local function isAlive(plr)
    if not plr or not plr.Character then return false end
    local hum = plr.Character:FindFirstChildOfClass("Humanoid")
    return hum and hum.Health > 0
end

--// ============================================================
--//  WALL CHECK
--// ============================================================
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

--// ============================================================
--//  PREDICTION
--// ============================================================
local function predictPosition(part)
    if Config.Prediction <= 0 then return part.Position end
    local vel = part.AssemblyLinearVelocity
    if vel.Magnitude > 100 then
        vel = vel.Unit * 100
    end
    return part.Position + (vel * Config.Prediction)
end

--// ============================================================
--//  FIND TARGET
--// ============================================================
local function findBestTarget()
    local mousePos = UserInputService:GetMouseLocation()
    local best, bestPart, bestScore = nil, nil, math.huge

    for _, plr in ipairs(Players:GetPlayers()) do
        if not isAlive(plr) then continue end
        if not isEnemy(plr) then continue end

        local char = plr.Character
        local part = char:FindFirstChild(Config.TargetPart)
                  or char:FindFirstChild("Head")
                  or char:FindFirstChild("HumanoidRootPart")
        if not part then continue end

        local sp, onScreen = Camera:WorldToViewportPoint(part.Position)
        if not onScreen then continue end

        local dist = (Vector2.new(sp.X, sp.Y) - mousePos).Magnitude
        if dist > Config.FOV then continue end

        if Config.WallCheck and not hasLineOfSight(part) then continue end

        if dist < bestScore then
            bestScore = dist
            best = plr
            bestPart = part
        end
    end

    return best, bestPart
end

--// ============================================================
--//  FOV CIRCLE
--// ============================================================
local function setupFOV()
    if fovCircle then
        pcall(function() fovCircle:Remove() end)
    end
    if not Drawing then return end

    fovCircle = Drawing.new("Circle")
    fovCircle.NumSides = 64
    fovCircle.Thickness = 1.5
    fovCircle.Color = Config.FOVColor
    fovCircle.Filled = false
    fovCircle.Transparency = 0.85
    fovCircle.Visible = false
end

local function updateFOV()
    if not fovCircle then return end
    if not Config.ShowFOV or not enabled then
        fovCircle.Visible = false
        return
    end
    fovCircle.Position = UserInputService:GetMouseLocation()
    fovCircle.Radius = Config.FOV
    fovCircle.Color = Config.FOVColor
    fovCircle.Visible = true
end

--// ============================================================
--//  HOOK (тільки підмінює Vector3, не блокує)
--// ============================================================
local function hook()
    if hookedNamecall then return true end
    if not hookmetamethod or not getnamecallmethod then
        log("❌ hookmetamethod недоступний")
        return false
    end

    local success = pcall(function()
        oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
            local method = getnamecallmethod()
            local args = {...}

            if method == "FireServer" and enabled then
                local char = LocalPlayer.Character
                local tool = char and char:FindFirstChildWhichIsA("Tool")

                if tool then
                    -- Чи це remote зброї?
                    local isWeaponRemote = false
                    local parent = self.Parent
                    local depth = 0
                    while parent and depth < 5 do
                        if parent == tool or parent == char then
                            isWeaponRemote = true
                            break
                        end
                        parent = parent.Parent
                        depth = depth + 1
                    end

                    if isWeaponRemote then
                        -- Чи є Vector3 в аргументах?
                        local hasVector = false
                        for _, arg in ipairs(args) do
                            if typeof(arg) == "Vector3" then
                                hasVector = true
                                break
                            end
                        end

                        if hasVector then
                            local target, targetPart = findBestTarget()
                            if target and targetPart then
                                currentTarget = target
                                if math.random(1, 100) <= Config.HitChance then
                                    local aimPos = predictPosition(targetPart)
                                    for i, arg in ipairs(args) do
                                        if typeof(arg) == "Vector3" then
                                            args[i] = aimPos
                                        end
                                    end
                                    shots = shots + 1
                                end
                            end
                        end
                    end
                end
            end

            -- ⚠ ГОЛОВНЕ: завжди повертаємо результат
            return oldNamecall(self, unpack(args))
        end))

        hookedNamecall = true
        log("✓ hookmetamethod активовано")
    end)

    return success
end

local function unhook()
    if not hookedNamecall or not oldNamecall then return end
    pcall(function()
        hookmetamethod(game, "__namecall", oldNamecall)
    end)
    hookedNamecall = false
    log("Hook removed")
end

--// ============================================================
--//  START / STOP
--// ============================================================
local function start()
    if enabled then return end
    enabled = true
    Config.Enabled = true
    hook()
    setupFOV()
    log("═══ Silent Aim ENABLED ═══")
    notify("💀 Silent Aim", "Enabled", 2)
end

local function stop()
    if not enabled then return end
    enabled = false
    Config.Enabled = false
    unhook()
    if fovCircle then fovCircle.Visible = false end
    log("Silent Aim DISABLED")
    notify("💀 Silent Aim", "Disabled", 2)
end

--// ============================================================
--//  RENDER LOOP (тільки FOV)
--// ============================================================
RunService.RenderStepped:Connect(function()
    if enabled then
        updateFOV()
    end
end)

--// ============================================================
--//  AUTO RE-HOOK
--// ============================================================
LocalPlayer.CharacterAdded:Connect(function()
    if enabled then
        task.wait(1.5)
        if not hookedNamecall then hook() end
    end
end)

--// ============================================================
--//  MODULE
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
function SilentAim:setFOV(v) 
    Config.FOV = v 
    if fovCircle then fovCircle.Radius = v end
end
function SilentAim:setPrediction(v) Config.Prediction = v end
function SilentAim:setTargetPart(v) Config.TargetPart = v end
function SilentAim:setTeamCheck(v) Config.TeamCheck = v end
function SilentAim:setWallCheck(v) Config.WallCheck = v end
function SilentAim:setShowFOV(v) 
    Config.ShowFOV = v 
    if fovCircle then fovCircle.Visible = v and enabled end
end
function SilentAim:setFOVColor(c) 
    Config.FOVColor = c 
    if fovCircle then fovCircle.Color = c end
end
function SilentAim:setFOVThickness(v) end
function SilentAim:setFOVFilled(v) end
function SilentAim:setMethod(v) end

function SilentAim:getStats()
    return { Shots = shots, Enabled = enabled }
end

log("═══════════════════════════════")
log("TrustHub Silent Aim v3.1")
log("Ready — enable via UI toggle")
log("═══════════════════════════════")

return SilentAim.new()
