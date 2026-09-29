--// ╔══════════════════════════════════════════════════════════════════════════╗
--// ║  TrustHub Silent Aim — WORKING EDITION                                   ║
--// ║  Based on real Fling Gui V35.0 method                                    ║
--// ║  Pistol: ShootGun (InvokeServer) + Prediction /40                        ║
--// ║  Knife:  Throw (FireServer) + Raycast prediction                         ║
--// ║  Always On • No Settings • Auto Re-hook                                  ║
--// ╚══════════════════════════════════════════════════════════════════════════╝

--// ============================================================
--//  SERVICES
--// ============================================================
local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local StarterGui        = game:GetService("StarterGui")
local Workspace         = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local Camera      = Workspace.CurrentCamera

--// ============================================================
--//  CONFIG (тільки внутрішнє)
--// ============================================================
local Config = {
    Enabled        = true,       -- УВІМКНЕНО ЗА ЗАМОВЧУВАННЯМ
    ShowFOV        = false,      -- показувати коло FOV
    FOV            = 200,        -- радіус FOV
    FOVColor       = Color3.fromRGB(255, 60, 60),
    LogEnabled     = true,
    NotifyEnabled  = true,
    PredictionOn   = true,
    NullifyIfJump  = true,
    TeamCheck      = true,
}

--// ============================================================
--//  STATE
--// ============================================================
local enabled          = Config.Enabled
local hookedNamecall   = false
local oldNamecall      = nil
local fovCircle        = nil
local shots            = 0
local hits             = 0
local currentTarget    = nil
local currentTargetPart = nil
local lastLogTime      = 0

--// Ролі гравців MM2
local Roles = {
    Murderer = nil,   -- Player
    Sheriff  = nil,   -- Player
    Innocent = nil,   -- не використовується
    Closest  = nil,   -- найближчий
}

--// Анімації атаки (для детекту замаху)
local AttackAnimations = {
    "rbxassetid://2467567750",
    "rbxassetid://1957618848",
    "rbxassetid://2470501967",
    "rbxassetid://2467577524",
}

--// Назви зброї
local WeaponNames = {
    Knife = "Murderer",
    Gun   = "Sheriff",
}

--// ============================================================
--//  LOG / NOTIFY
--// ============================================================
local function log(msg)
    if Config.LogEnabled then
        print("[SilentAim] " .. tostring(msg))
    end
end

local function notify(title, text, duration)
    if not Config.NotifyEnabled then return end
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = title,
            Text = text,
            Duration = duration or 2,
        })
    end)
end

--// ============================================================
--//  HELPERS
--// ============================================================
local function getChar()
    local char = LocalPlayer.Character
    if not char then return nil end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hum or not hrp then return nil end
    if hum.Health <= 0 then return nil end
    return char, hum, hrp
end

local function isAlive(plr)
    if not plr or not plr.Character then return false end
    local hum = plr.Character:FindFirstChildOfClass("Humanoid")
    return hum and hum.Health > 0
end

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

--// ============================================================
--//  GET CLOSEST PLAYER (з Fling Gui V35.0)
--// ============================================================
local function GetClosestPlayer(maxDist)
    local closest = nil
    local farthest = maxDist or math.huge
    local char, hum, hrp = getChar()
    if not hrp then return nil end

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            local success = pcall(function()
                if plr.Character and plr.Character.PrimaryPart then
                    local dist = (hrp.Position - plr.Character.PrimaryPart.Position).Magnitude
                    if dist < farthest then
                        farthest = dist
                        closest = plr
                    end
                end
            end)
            if not success then
                -- пропускаємо невдалих
            end
        end
    end
    return closest
end

--// ============================================================
--//  GET TARGET FOR PISTOL (тільки Murderer)
--// ============================================================
local function getPistolTarget()
    -- Priority 1: Roles.Murderer (якщо знайдено через Backpack)
    if Roles.Murderer and isAlive(Roles.Murderer) then
        return Roles.Murderer
    end

    -- Priority 2: шукаємо Murderer-а самостійно
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and isAlive(plr) then
            if getRole(plr) == "Murderer" then
                return plr
            end
        end
    end

    return nil
end

--// ============================================================
--//  GET TARGET FOR KNIFE (будь-хто, крім себе)
--// ============================================================
local function getKnifeTarget()
    local myRole = getRole(LocalPlayer)
    local char, hum, hrp = getChar()
    if not hrp then return nil end

    local closest = nil
    local farthest = math.huge

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == LocalPlayer then continue end
        if not isAlive(plr) then continue end
        if not plr.Character or not plr.Character.PrimaryPart then continue end

        -- Team check для ножа
        if Config.TeamCheck then
            local theirRole = getRole(plr)
            if myRole == "Murderer" and theirRole == "Murderer" then continue end
            if myRole ~= "Murderer" and theirRole ~= "Murderer" then continue end
        end

        local dist = (hrp.Position - plr.Character.PrimaryPart.Position).Magnitude
        if dist < farthest then
            farthest = dist
            closest = plr
        end
    end

    return closest
end

--// ============================================================
--//  PREDICTION — PISTOL (velocity / 40)
--// ============================================================
local function predictPistol(primaryPart)
    if not Config.PredictionOn then return primaryPart.Position end

    local velocity = primaryPart.AssemblyLinearVelocity

    -- Якщо ціль стрибає — не стріляти (nullify)
    if Config.NullifyIfJump and math.abs(velocity.Y) >= 10 then
        return nil
    end

    local prediction = velocity / 40
    return primaryPart.Position + prediction
end

--// ============================================================
--//  PREDICTION — KNIFE (velocity * 0.5 * dist / 100 + raycast)
--// ============================================================
local function predictKnife(targetPrimaryPart)
    if not Config.PredictionOn then return targetPrimaryPart.Position end

    local char, hum, hrp = getChar()
    if not hrp then return targetPrimaryPart.Position end

    local velocity = targetPrimaryPart.AssemblyLinearVelocity * Vector3.new(1, 0, 1)
    local magnitude = (targetPrimaryPart.Position - hrp.Position).Magnitude
    local prediction = velocity * 0.5 * magnitude / 100

    -- Raycast для перевірки перешкод
    local raycastParams = RaycastParams.new()
    raycastParams.IgnoreWater = true
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
    raycastParams.FilterDescendantsInstances = { LocalPlayer.Character }

    local direction = (targetPrimaryPart.Position - (hrp.Position + prediction))
    if direction.Magnitude < 0.01 then
        return targetPrimaryPart.Position + prediction
    end

    local result = Workspace:Raycast(
        hrp.Position,
        direction.Unit * 200,
        raycastParams
    )

    if result then
        return result.Position
    end

    return targetPrimaryPart.Position + prediction
end

--// ============================================================
--//  FOV CIRCLE (optional visual)
--// ============================================================
local function setupFOV()
    if fovCircle then
        pcall(function() fovCircle:Remove() end)
        fovCircle = nil
    end
    if not Config.ShowFOV then return end
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
    if not enabled or not Config.ShowFOV then
        fovCircle.Visible = false
        return
    end
    local mousePos = UserInputService:GetMouseLocation()
    fovCircle.Position = mousePos
    fovCircle.Radius = Config.FOV
    fovCircle.Color = Config.FOVColor
    fovCircle.Visible = true
end

--// ============================================================
--//  HOOK __namecall (головний метод)
--// ============================================================
local function hookNamecall()
    if hookedNamecall then return true end
    if not hookmetamethod or not getnamecallmethod then
        log("❌ hookmetamethod недоступний — треба Delta/Xeno/Solara")
        return false
    end

    local success = pcall(function()
        oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(Object, ...)
            local NamecallMethod = getnamecallmethod()
            local Arguments = {...}

            if enabled and not checkcaller() then
                -- ============================================
                -- ПІСТОЛЕТ (Sheriff) — InvokeServer ShootGun
                -- ============================================
                if NamecallMethod == "InvokeServer" and tostring(Object) == "ShootGun" then
                    local success2, err2 = pcall(function()
                        local target = getPistolTarget()
                        if not target then return end

                        local targetPart = target.Character.PrimaryPart
                        if not targetPart then return end

                        local predictedPos = predictPistol(targetPart)
                        if predictedPos then
                            -- ⚡ ПІДМІНА ТОЧКИ ВЛУЧАННЯ
                            Arguments[2] = predictedPos
                            shots = shots + 1
                            currentTarget = target
                            currentTargetPart = targetPart
                        else
                            -- Ціль стрибає — скасовуємо постріл
                            return "Nullify"
                        end
                    end)
                    if not success2 then
                        -- silent fail
                    end
                    if err2 == "Nullify" then
                        return nil
                    end
                end

                -- ============================================
                -- НІЖ (Murderer) — FireServer Throw
                -- ============================================
                if NamecallMethod == "FireServer" and tostring(Object) == "Throw" then
                    local success2, err2 = pcall(function()
                        local target = getKnifeTarget()
                        if not target then return end

                        local targetPart = target.Character.PrimaryPart
                        if not targetPart then return end

                        local predictedPos = predictKnife(targetPart)
                        if predictedPos then
                            Arguments[2] = predictedPos
                            shots = shots + 1
                            currentTarget = target
                            currentTargetPart = targetPart
                        end
                    end)
                    if not success2 then
                        -- silent fail
                    end
                end
            end

            -- ⚠ ВАЖЛИВО: завжди повертаємо оригінальний результат
            return oldNamecall(Object, unpack(Arguments))
        end))

        hookedNamecall = true
        log("✓ hookmetamethod активовано")
    end)

    if not success then
        log("❌ Помилка при активації хука")
    end

    return hookedNamecall
end

--// ============================================================
--//  UNHOOK
--// ============================================================
local function unhook()
    if not hookedNamecall or not oldNamecall then return end
    pcall(function()
        hookmetamethod(game, "__namecall", oldNamecall)
    end)
    hookedNamecall = false
    log("Hook removed")
end

--// ============================================================
--//  ROLE TRACKING (з Backpack.ChildAdded)
--// ============================================================
local function trackPlayerRole(plr)
    if plr == LocalPlayer then return end

    local function attach(char)
        if not char then return end
        local backpack = plr:FindFirstChild("Backpack")
        if not backpack then return end

        local function checkWeapon(child)
            local role = WeaponNames[child.Name]
            if role == "Murderer" then
                Roles.Murderer = plr
                log("🎯 Знайдено Murderer: " .. plr.Name)
                notify("🔪 Murderer", plr.Name, 3)
            elseif role == "Sheriff" then
                Roles.Sheriff = plr
                log("🔫 Знайдено Sheriff: " .. plr.Name)
            end
        end

        for _, tool in ipairs(backpack:GetChildren()) do
            if tool:IsA("Tool") then
                checkWeapon(tool)
            end
        end

        backpack.ChildAdded:Connect(function(child)
            if child:IsA("Tool") then
                checkWeapon(child)
            end
        end)
    end

    plr.CharacterAdded:Connect(attach)
    if plr.Character then attach(plr.Character) end
end

--// Ініціалізація для всіх гравців
for _, plr in ipairs(Players:GetPlayers()) do
    if plr ~= LocalPlayer then
        trackPlayerRole(plr)
    end
end

Players.PlayerAdded:Connect(function(plr)
    trackPlayerRole(plr)
end)

Players.PlayerRemoving:Connect(function(plr)
    if Roles.Murderer == plr then Roles.Murderer = nil end
    if Roles.Sheriff == plr then Roles.Sheriff = nil end
end)

--// ============================================================
--//  AUTO RE-HOOK
--// ============================================================
LocalPlayer.CharacterAdded:Connect(function()
    task.wait(1.5)
    if enabled and not hookedNamecall then
        hookNamecall()
    end
end)

--// ============================================================
--//  RENDER LOOP (FOV circle)
--// ============================================================
RunService.RenderStepped:Connect(function()
    if enabled then
        updateFOV()
    end
end)

--// ============================================================
--//  START / STOP
--// ============================================================
local function start()
    if enabled then return end
    enabled = true
    Config.Enabled = true
    hookNamecall()
    setupFOV()
    log("═══ Silent Aim ENABLED ═══")
    log("Method: ShootGun + Throw")
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

function SilentAim:isEnabled()
    return enabled
end

function SilentAim:getStats()
    return {
        Enabled = enabled,
        Shots   = shots,
        Hits    = hits,
        Target  = currentTarget and currentTarget.Name or "None",
        Murderer = Roles.Murderer and Roles.Murderer.Name or "None",
        Sheriff  = Roles.Sheriff and Roles.Sheriff.Name or "None",
    }
end

function SilentAim:getRoles()
    return Roles
end

-- Stubs для сумісності з UI (не використовуються)
function SilentAim:setHitChance() end
function SilentAim:setFOV() end
function SilentAim:setPrediction() end
function SilentAim:setTargetPart() end
function SilentAim:setTeamCheck() end
function SilentAim:setWallCheck() end
function SilentAim:setShowFOV() end
function SilentAim:setFOVColor() end
function SilentAim:setFOVThickness() end
function SilentAim:setFOVFilled() end
function SilentAim:setMethod() end

--// ============================================================
--//  AUTO START
--// ============================================================
task.wait(0.5)
start()

--// ============================================================
--//  CONSOLE BANNER
--// ============================================================
log("═══════════════════════════════════════")
log("TrustHub Silent Aim WORKING EDITION")
log("Method: ShootGun (pistol) + Throw (knife)")
log("Prediction: ON")
log("Team Check: ON")
log("═══════════════════════════════════════")
log("Toggle: через UI (Features.SilentAim:setEnabled)")
log("Status: УВІМКНЕНО")

return SilentAim.new()
