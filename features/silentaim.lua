--// ============================================================
--// TrustHub Silent Aim v1.0 — MM2 Edition
--// Raycast + Mouse.Hit hooks, FOV Circle, closest target
--// ============================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer

--// ============================================================
--//  CONFIG
--// ============================================================
local Config = {
    Enabled        = false,
    FOV            = 150,           -- радіус пошуку (пікселів)
    ShowFOV        = true,
    TargetPart     = "Head",        -- "Head" або "HumanoidRootPart"
    TeamCheck      = true,          -- ігнорувати Murderer'а (щоб не вбити шерифа?)
    WallCheck      = true,          -- не стріляти крізь стіни
    HitChance      = 100,           -- % влучань
    Prediction     = 0.135,         -- компенсація руху цілі
    Method         = "Raycast",     -- "Raycast" або "Mouse"
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
local cachedChar    = nil

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
    print("[SilentAim] FOV circle created (Drawing API)")
else
    warn("[SilentAim] Drawing API unavailable")
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
    return char:FindFirstChild(Config.TargetPart) or char:FindFirstChild("HumanoidRootPart")
end

local function isVisible(part)
    if not Config.WallCheck then return true end
    local origin = Workspace.CurrentCamera.CFrame.Position
    local dir = part.Position - origin
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { LocalPlayer.Character, Workspace.CurrentCamera, part.Parent }
    local result = Workspace:Raycast(origin, dir, params)
    return result == nil
end

local function getRole(plr)
    --// Спрощена перевірка ролі в MM2 (за назвою інструментів)
    local char = plr.Character
    if not char then return "Innocent" end
    for _, tool in ipairs(char:GetChildren()) do
        if tool:IsA("Tool") then
            local n = tool.Name:lower()
            if n:find("knife") then return "Murderer" end
            if n:find("gun") or n:find("pistol") then return "Sheriff" end
        end
    end
    return "Innocent"
end

--// ============================================================
--//  FIND CLOSEST TARGET
--// ============================================================
local function findClosestPlayer()
    local mousePos = UserInputService:GetMouseLocation()
    local best, bestDist = nil, Config.FOV

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            local part = getTargetPart(plr)
            if part then
                --// Team Check (можна налаштувати під MM2: не стріляти в Murderer'а, якщо ми Sheriff)
                local skip = false
                if Config.TeamCheck then
                    local role = getRole(plr)
                    --// Приклад: якщо ми Sheriff — не стріляємо в Innocent/Sheriff
                    --// Тут можна додати логіку для MM2
                end

                if not skip then
                    local screenPos, onScreen = Workspace.CurrentCamera:WorldToViewportPoint(part.Position)
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
                    if targetPart then
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
        print("[SilentAim] __index hook installed (Mouse.Hit)")
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
                        --// Підміна напрямку на ціль
                        if method == "Raycast" then
                            --// args[1] = origin, args[2] = direction
                            if #args >= 2 then
                                args[2] = (targetPart.Position - args[1]).Unit * (args[2].Magnitude or 1000)
                            end
                        elseif method == "FindPartOnRay" then
                            --// args[1] = ray
                            if args[1] then
                                args[1] = Ray.new(args[1].Origin, (targetPart.Position - args[1].Origin))
                            end
                        end
                    end
                end
            end
            return oldNamecall(self, unpack(args))
        end)

        setreadonly(mt, true)
        hookedNamecall = true
        print("[SilentAim] __namecall hook installed (Raycast)")
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
        fovCircle.Color = currentTarget and Color3.fromRGB(255, 60, 60) or Color3.fromRGB(255, 200, 200)
    end

    if not Config.Enabled then return end

    currentTarget = findClosestPlayer()
end)

--// ============================================================
--//  MODULE API (для UI)
--// ============================================================
local SilentAim = {}
SilentAim.__index = SilentAim

function SilentAim.new()
    return setmetatable({}, SilentAim)
end

function SilentAim:setEnabled(state)
    Config.Enabled = state
    if state then
        if Config.Method == "Raycast" then hookNamecall() end
        if Config.Method == "Mouse" then hookIndex() end
        --// Встановлюємо обидва для надійності
        hookIndex()
        hookNamecall()
        print("[SilentAim] ═══ ENABLED ═══")
    else
        unhookAll()
        currentTarget = nil
        print("[SilentAim] ═══ DISABLED ═══")
    end
end

function SilentAim:setFOV(v)
    Config.FOV = math.clamp(v, 10, 800)
    print("[SilentAim] FOV set to " .. Config.FOV)
end

function SilentAim:setShowFOV(v) Config.ShowFOV = v end
function SilentAim:setTargetPart(v) Config.TargetPart = v end
function SilentAim:setTeamCheck(v) Config.TeamCheck = v end
function SilentAim:setWallCheck(v) Config.WallCheck = v end
function SilentAim:setHitChance(v) Config.HitChance = math.clamp(v, 1, 100) end
function SilentAim:setPrediction(v) Config.Prediction = v end

function SilentAim:getStats()
    return {
        Enabled = Config.Enabled,
        Target  = currentTarget and currentTarget.Name or "None",
        FOV     = Config.FOV,
    }
end

--// Cleanup при виході
game:BindToClose(function()
    if Config.Enabled then unhookAll() end
    if fovCircle then fovCircle:Remove() end
end)

print("═══════════════════════════════")
print("TrustHub Silent Aim v1.0 — Loaded")
print("═══════════════════════════════")

return SilentAim.new()
