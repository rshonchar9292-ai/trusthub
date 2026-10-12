--// ============================================================
--// TrustHub Silent Aim v2.0 — MM2 Edition
--// Детальна перевірка ролей (Knife / Revolver / Gun)
--// Raycast + Mouse.Hit hooks, FOV Circle
--// ============================================================

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace        = game:GetService("Workspace")
local StarterGui       = game:GetService("StarterGui")

local LocalPlayer = Players.LocalPlayer
local Camera      = Workspace.CurrentCamera

--// ============================================================
--//  CONFIG
--// ============================================================
local Config = {
    Enabled      = false,
    FOV          = 150,
    ShowFOV      = true,
    TargetPart   = "Head",
    TeamCheck    = false,       -- для MM2: не стріляти в Sheriff
    WallCheck    = true,
    HitChance    = 100,
    Prediction   = 0.135,
    AimAtRole    = "Any",       -- "Any" | "Murderer" | "Sheriff"
    Verbose      = true,
}

--// ============================================================
--//  STATE
--// ============================================================
local enabled       = false
local currentTarget = nil
local fovCircle     = nil
local oldIndex      = nil
local oldNamecall   = nil
local hookedIndex   = false
local hookedNamecall= false

local function log(msg)
    if Config.Verbose then print("[SilentAim] " .. tostring(msg)) end
end

--// ============================================================
--//  FOV CIRCLE (Drawing API)
--// ============================================================
local hasDrawing = pcall(function()
    local d = Drawing.new("Circle")
    d:Remove()
end)

if hasDrawing then
    fovCircle = Drawing.new("Circle")
    fovCircle.Thickness = 1.5
    fovCircle.NumSides = 64
    fovCircle.Filled = false
    fovCircle.Color = Color3.fromRGB(255, 60, 60)
    fovCircle.Transparency = 0.6
    fovCircle.Visible = false
    log("FOV circle created (Drawing API)")
else
    warn("[SilentAim] Drawing API unavailable")
end

--// ============================================================
--//  ROLE DETECTION (з сурсу)
--// ============================================================
local function getRole(plr)
    if not plr or not plr.Character then return "Innocent" end

    --// Перевірка Backpack
    local backpack = plr:FindFirstChild("Backpack")
    if backpack then
        for _, tool in ipairs(backpack:GetChildren()) do
            if tool.Name == "Knife" then return "Murderer" end
            if tool.Name == "Revolver" or tool.Name == "Gun" then return "Sheriff" end
        end
    end

    --// Перевірка Character (тримає в руках)
    for _, tool in ipairs(plr.Character:GetChildren()) do
        if tool:IsA("Tool") then
            if tool.Name == "Knife" then return "Murderer" end
            if tool.Name == "Revolver" or tool.Name == "Gun" then return "Sheriff" end
        end
    end

    return "Innocent"
end

--// ============================================================
--//  HELPERS
--// ============================================================
local function getChar(plr)
    local char = plr.Character
    if not char then return nil end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hum or not hrp or hum.Health <= 0 then return nil end
    return char, hum, hrp
end

local function getTargetPart(plr)
    local char = getChar(plr)
    if not char then return nil end
    if Config.TargetPart == "Head" then
        return char:FindFirstChild("Head")
    elseif Config.TargetPart == "Torso" then
        return char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")
    else
        return char:FindFirstChild("HumanoidRootPart")
    end
end

local function isVisible(part)
    if not Config.WallCheck then return true end
    local origin = Camera.CFrame.Position
    local dir = part.Position - origin
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {
        LocalPlayer.Character, Camera, part.Parent,
    }
    return Workspace:Raycast(origin, dir, params) == nil
end

--// ============================================================
--//  FIND CLOSEST PLAYER (з урахуванням ролі)
--// ============================================================
local function findClosestPlayer()
    local mousePos = UserInputService:GetMouseLocation()
    local best, bestDist = nil, Config.FOV

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            local part = getTargetPart(plr)
            if part then
                --// Перевірка ролі
                local role = getRole(plr)
                local skip = false

                if Config.AimAtRole == "Murderer" and role ~= "Murderer" then
                    skip = true
                elseif Config.AimAtRole == "Sheriff" and role ~= "Sheriff" then
                    skip = true
                end

                --// Team Check (не стріляти в Sheriff'а, якщо він наш союзник)
                if Config.TeamCheck and role == "Sheriff" then
                    skip = true
                end

                if not skip then
                    local screenPos, onScreen = Camera:WorldToViewportPoint(part.Position)
                    if onScreen then
                        local dist = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
                        if dist < bestDist and isVisible(part) then
                            bestDist = dist
                            best = plr
                        end
                    end
                end
            end
        end
    end
    return best
end

--// ============================================================
--//  HOOK: __index (Mouse.Hit / Mouse.Target)
--// ============================================================
local function hookIndex()
    if hookedIndex then return end
    local ok, err = pcall(function()
        local mt = getrawmetatable(game)
        if not mt then error("No metatable") end
        oldIndex = mt.__index
        setreadonly(mt, false)

        mt.__index = newcclosure(function(self, key)
            if not checkcaller() and Config.Enabled and currentTarget then
                local mouse = LocalPlayer:GetMouse()
                if self == mouse and (key == "Hit" or key == "Target") then
                    local targetPart = getTargetPart(currentTarget)
                    if targetPart and math.random(1, 100) <= Config.HitChance then
                        if key == "Hit" then
                            return CFrame.new(targetPart.Position)
                        elseif key == "Target" then
                            return targetPart
                        end
                    end
                end
            end
            return oldIndex(self, key)
        end)

        setreadonly(mt, true)
        hookedIndex = true
        log("__index hook installed (Mouse.Hit)")
    end)
    if not ok then warn("[SilentAim] __index hook failed: " .. tostring(err)) end
end

--// ============================================================
--//  HOOK: __namecall (workspace:Raycast)
--// ============================================================
local function hookNamecall()
    if hookedNamecall then return end
    local ok, err = pcall(function()
        local mt = getrawmetatable(game)
        if not mt then error("No metatable") end
        oldNamecall = mt.__namecall
        setreadonly(mt, false)

        mt.__namecall = newcclosure(function(self, ...)
            local method = getnamecallmethod()
            local args = {...}

            if not checkcaller() and Config.Enabled and currentTarget then
                if self == Workspace and (method == "Raycast" or method == "FindPartOnRay") then
                    local targetPart = getTargetPart(currentTarget)
                    if targetPart and math.random(1, 100) <= Config.HitChance then
                        if method == "Raycast" and #args >= 2 then
                            local origin = args[1]
                            local dir = targetPart.Position - origin
                            args[2] = dir.Unit * (args[2].Magnitude or 1000)
                        elseif method == "FindPartOnRay" and args[1] then
                            args[1] = Ray.new(args[1].Origin, targetPart.Position - args[1].Origin)
                        end
                    end
                end
            end
            return oldNamecall(self, unpack(args))
        end)

        setreadonly(mt, true)
        hookedNamecall = true
        log("__namecall hook installed (Raycast)")
    end)
    if not ok then warn("[SilentAim] __namecall hook failed: " .. tostring(err)) end
end

local function unhookAll()
    if hookedIndex and oldIndex then
        pcall(function()
            local mt = getrawmetatable(game)
            setreadonly(mt, false)
            mt.__index = oldIndex
            setreadonly(mt, true)
        end)
        hookedIndex = false
    end
    if hookedNamecall and oldNamecall then
        pcall(function()
            local mt = getrawmetatable(game)
            setreadonly(mt, false)
            mt.__namecall = oldNamecall
            setreadonly(mt, true)
        end)
        hookedNamecall = false
    end
end

--// ============================================================
--//  MAIN LOOP
--// ============================================================
RunService.RenderStepped:Connect(function()
    if fovCircle then
        local mousePos = UserInputService:GetMouseLocation()
        fovCircle.Position = mousePos
        fovCircle.Radius = Config.FOV
        fovCircle.Visible = Config.Enabled and Config.ShowFOV
        fovCircle.Color = currentTarget
            and Color3.fromRGB(255, 60, 60)
            or  Color3.fromRGB(255, 200, 200)
    end

    if not Config.Enabled then return end
    currentTarget = findClosestPlayer()
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
    Config.Enabled = state
    if state then
        hookIndex()
        hookNamecall()
        log("═══ ENABLED ═══")
        pcall(function()
            StarterGui:SetCore("SendNotification", {
                Title = "🎯 Silent Aim", Text = "Enabled", Duration = 2,
            })
        end)
    else
        unhookAll()
        currentTarget = nil
        log("═══ DISABLED ═══")
    end
end

function SilentAim:setFOV(v) Config.FOV = math.clamp(v, 10, 800) end
function SilentAim:setShowFOV(v) Config.ShowFOV = v end
function SilentAim:setTargetPart(v) Config.TargetPart = v end
function SilentAim:setTeamCheck(v) Config.TeamCheck = v end
function SilentAim:setWallCheck(v) Config.WallCheck = v end
function SilentAim:setHitChance(v) Config.HitChance = math.clamp(v, 1, 100) end
function SilentAim:setPrediction(v) Config.Prediction = v end
function SilentAim:setAimAtRole(v) Config.AimAtRole = v end
function SilentAim:setMethod() end

function SilentAim:getRole(plr) return getRole(plr) end

function SilentAim:getStats()
    return {
        Enabled = Config.Enabled,
        Target  = currentTarget and currentTarget.Name or "None",
        Role    = currentTarget and getRole(currentTarget) or "None",
        FOV     = Config.FOV,
    }
end

game:BindToClose(function()
    if Config.Enabled then unhookAll() end
    if fovCircle then pcall(function() fovCircle:Remove() end) end
end)

log("═══════════════════════════════")
log("TrustHub Silent Aim v2.0 — MM2")
log("Knife/Revolver/Gun detection")
log("═══════════════════════════════")

return SilentAim.new()
