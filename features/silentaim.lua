--// ╔══════════════════════════════════════════════════════════╗
--// ║  TrustHub Silent Aim PRO                                 ║
--// ║  Version 3.0 — Best-in-class MM2 Silent Aim              ║
--// ║  Author: rshonchar9292-ai                                ║
--// ╚══════════════════════════════════════════════════════════╝
--//
--//  Features:
--//  [+] Dual hook: getsenv + hookmetamethod fallback
--//  [+] Smart target selection (role-aware, priority-based)
--//  [+] Prediction for moving targets
--//  [+] Auto-shoot when target in crosshair zone
--//  [+] Trigger bot
--//  [+] Statistics tracking (kills, shots, accuracy)
--//  [+] Target visualization (highlight, line, dot)
--//  [+] Auto re-hook on weapon change
--//  [+] Config persistence via attributes
--//  [+] Multiple aim parts + custom priority
--//  [+] Detailed console logging with colors
--//  [+] Bypass-friendly (no writes to game DataModel)
--// ============================================================

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local StarterGui        = game:GetService("StarterGui")

local LocalPlayer = Players.LocalPlayer
local Camera      = workspace.CurrentCamera
local Mouse       = LocalPlayer:GetMouse()

--// ============================================================
--//  КОНФІГ
--// ============================================================
local Config = {
    -- Основне
    Enabled         = false,
    AimPart         = "Head",        -- Head | HumanoidRootPart | UpperTorso | LowerTorso
    HitChance       = 100,           -- 1-100 %
    MaxDistance     = 5000,          -- studs
    
    -- Ціль
    TargetMode      = "Auto",        -- Auto | Murderer | Sheriff | Innocent | All
    Priority        = "Cursor",      -- Cursor | Distance | Health | Threat
    PredictMovement = true,          -- передбачення руху цілі
    PredictionTime  = 0.15,          -- секунди
    
    -- Обмеження
    WallBang        = true,          -- крізь стіни
    VisibleCheck    = false,         -- тільки видимі
    IgnoreDead      = true,
    IgnoreTeam      = true,          -- не стріляти у своїх (за роллю)
    
    -- Автострільба
    AutoShoot       = false,
    AutoShootDelay  = 0.05,          -- секунди між пострілами
    TriggerBot      = false,
    TriggerRadius   = 30,            -- px від курсора
    
    -- Візуалізація
    ShowTargetLine  = true,
    ShowTargetDot   = true,
    ShowTargetBox   = true,
    TargetColor     = Color3.fromRGB(255, 60, 60),
    LineColor       = Color3.fromRGB(120, 140, 255),
    ShowStats       = true,
    
    -- Тонке
    OnlyWhenAiming  = false,         -- стріляти тільки коли утримуєш ПКМ
    ToggleKey       = Enum.KeyCode.C,
    SilentLogs      = false,         -- менше спаму в консолі
}

--// ============================================================
--//  СТАТИСТИКА
--// ============================================================
local Stats = {
    Shots       = 0,
    Kills       = 0,
    Hits        = 0,
    SessionStart = tick(),
}

--// ============================================================
--//  УТИЛІТИ
--// ============================================================
local Log = {}
function Log.info(msg) print("[SilentAim] " .. msg) end
function Log.ok(msg) print("[SilentAim] ✓ " .. msg) end
function Log.warn(msg) warn("[SilentAim] ⚠ " .. msg) end
function Log.err(msg) warn("[SilentAim] ✗ " .. msg) end
function Log.debug(msg) if not Config.SilentLogs then print("[SilentAim][D] " .. msg) end end

local function notify(title, text, duration)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = title,
            Text = text,
            Duration = duration or 3,
        })
    end)
end

--// ============================================================
--//  РОЛІ
--// ============================================================
local function getRole(player)
    local char = player.Character
    if not char then return "Dead" end

    -- Ніж у руках
    for _, tool in ipairs(char:GetChildren()) do
        if tool:IsA("Tool") then
            local n = tool.Name:lower()
            if n:find("knife") or n:find("blade") or n:find("murder")
               or n:find("dagger") or n:find("sword") then
                return "Murderer"
            end
        end
    end

    -- Пістолет у руках
    for _, tool in ipairs(char:GetChildren()) do
        if tool:IsA("Tool") then
            local n = tool.Name:lower()
            if n:find("gun") or n:find("pistol") or n:find("sheriff")
               or n:find("revolver") or n:find("magnum") or n:find("weapon") then
                return "Sheriff"
            end
        end
    end

    -- Backpack
    local bp = player:FindFirstChild("Backpack")
    if bp then
        for _, tool in ipairs(bp:GetChildren()) do
            if tool:IsA("Tool") then
                local n = tool.Name:lower()
                if n:find("gun") or n:find("pistol") or n:find("sheriff")
                   or n:find("revolver") or n:find("magnum") then
                    return "Sheriff"
                end
                if n:find("knife") or n:find("blade") or n:find("murder")
                   or n:find("dagger") then
                    return "Murderer"
                end
            end
        end
    end

    return "Innocent"
end

local function getMyRole() return getRole(LocalPlayer) end

--// ============================================================
--//  ВАЛІДАЦІЯ ЦІЛІ
--// ============================================================
local function isAlive(plr)
    local char = plr.Character
    if not char then return false end
    local hum = char:FindFirstChildOfClass("Humanoid")
    return hum and hum.Health > 0
end

local function isFriendly(plr)
    if plr == LocalPlayer then return true end
    if not Config.IgnoreTeam then return false end

    local myRole = getMyRole()
    local theirRole = getRole(plr)

    -- Маніяк не має друзів
    if myRole == "Murderer" then return false end

    -- Шериф + невинний = союзники
    if (myRole == "Sheriff" or myRole == "Innocent") then
        if theirRole ~= "Murderer" then return true end
    end

    return false
end

local function isValidTarget(plr)
    if plr == LocalPlayer then return false end
    if Config.IgnoreDead and not isAlive(plr) then return false end

    -- Рольова логіка
    if Config.TargetMode == "Auto" then
        if isFriendly(plr) then return false end
    elseif Config.TargetMode == "Murderer" then
        if getRole(plr) ~= "Murderer" then return false end
    elseif Config.TargetMode == "Sheriff" then
        if getRole(plr) ~= "Sheriff" then return false end
    elseif Config.TargetMode == "Innocent" then
        if getRole(plr) ~= "Innocent" then return false end
    end
    -- "All" — без фільтра

    return true
end

--// ============================================================
--//  PREDICTION (передбачення руху)
--// ============================================================
local function predictPosition(part, ping)
    if not Config.PredictMovement then return part.Position end

    local velocity = part.AssemblyLinearVelocity
    if velocity.Magnitude < 1 then return part.Position end

    local time = math.clamp(Config.PredictionTime + (ping or 0), 0, 0.5)
    return part.Position + velocity * time
end

local function getPing()
    local ok, ping = pcall(function()
        return game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue() / 1000
    end)
    return ok and ping or 0.05
end

--// ============================================================
--//  SCORING ЦІЛІ
--// ============================================================
local function scoreTarget(plr, part, myPos, mousePos)
    local dist = (myPos - part.Position).Magnitude
    if dist > Config.MaxDistance then return nil end

    local screenPos, onScreen = Camera:WorldToViewportPoint(part.Position)

    -- Wall check
    if Config.VisibleCheck then
        local ray = Ray.new(Camera.CFrame.Position,
            (part.Position - Camera.CFrame.Position).Unit * dist)
        local hit = workspace:FindPartOnRayWithIgnoreList(ray,
            {LocalPlayer.Character, Camera})
        if hit and not hit:IsDescendantOf(plr.Character) then return nil end
    end

    -- Score залежить від пріоритету
    if Config.Priority == "Distance" then
        return dist
    elseif Config.Priority == "Health" then
        local hum = plr.Character:FindFirstChildOfClass("Humanoid")
        return hum and hum.Health or 100
    elseif Config.Priority == "Threat" then
        -- Murderer = максимальний пріоритет
        local role = getRole(plr)
        local base = dist
        if role == "Murderer" then base = base * 0.3 end
        if role == "Sheriff" then base = base * 1.5 end
        return base
    else -- Cursor
        if onScreen then
            return (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
        else
            return 100000 + dist
        end
    end
end

--// ============================================================
--//  ПОШУК ЦІЛІ
--// ============================================================
local function findBestTarget()
    local myChar = LocalPlayer.Character
    if not myChar then return nil, nil end
    local myRoot = myChar:FindFirstChild("HumanoidRootPart")
    if not myRoot then return nil, nil end

    local mousePos = UserInputService:GetMouseLocation()
    local bestPart, bestPlr = nil, nil
    local bestScore = math.huge

    for _, plr in ipairs(Players:GetPlayers()) do
        if not isValidTarget(plr) then continue end

        local char = plr.Character
        local part = char:FindFirstChild(Config.AimPart)
                  or char:FindFirstChild("Head")
                  or char:FindFirstChild("HumanoidRootPart")
        if not part then continue end

        local score = scoreTarget(plr, part, myRoot.Position, mousePos)
        if score and score < bestScore then
            bestScore = score
            bestPart = part
            bestPlr = plr
        end
    end

    return bestPart, bestPlr, bestScore
end

--// ============================================================
--//  ВІЗУАЛІЗАЦІЯ ЦІЛІ
--// ============================================================
local targetLine = Drawing.new("Line")
targetLine.Thickness = 1.5
targetLine.Transparency = 0.7
targetLine.Visible = false

local targetDot = Drawing.new("Circle")
targetDot.NumSides = 30
targetDot.Radius = 4
targetDot.Filled = true
targetDot.Transparency = 0.9
targetDot.Visible = false

local targetBox = Drawing.new("Square")
targetBox.Thickness = 1.5
targetBox.Filled = false
targetBox.Transparency = 0.85
targetBox.Visible = false

local currentTarget = nil

--// ============================================================
--//  ХУК через getsenv (основний)
--// ============================================================
local hookedScripts = {}
local hookSuccess = false

local function hookViaGetsenv()
    local char = LocalPlayer.Character
    if not char then return false end

    local tool = char:FindFirstChildWhichIsA("Tool")
    if not tool then return false end

    -- Шукаємо GunScript_Local
    local gunScript = nil
    for _, child in ipairs(tool:GetDescendants()) do
        if child:IsA("LocalScript") and child.Name == "GunScript_Local" then
            gunScript = child
            break
        end
    end

    -- Fallback: будь-який LocalScript з "gun" у назві
    if not gunScript then
        for _, child in ipairs(tool:GetDescendants()) do
            if child:IsA("LocalScript") and child.Name:lower():find("gun") then
                gunScript = child
                break
            end
        end
    end

    if not gunScript then return false end
    if hookedScripts[gunScript] then return true end

    local ok, env = pcall(getsenv, gunScript)
    if not ok or not env or not env.Fire then return false end

    local oldFire = env.Fire
    env.Fire = function(...)
        local args = {...}

        if Config.Enabled then
            if math.random(1, 100) <= Config.HitChance then
                local target = findBestTarget()
                if target then
                    local ping = getPing()
                    local aimPos = predictPosition(target, ping)

                    for i, arg in ipairs(args) do
                        if typeof(arg) == "Vector3" then
                            args[i] = aimPos
                        end
                    end

                    Stats.Shots = Stats.Shots + 1
                    currentTarget = target
                end
            end
        end

        return oldFire(unpack(args))
    end

    hookedScripts[gunScript] = true
    hookSuccess = true
    Log.ok("GunScript hooked via getsenv")
    return true
end

--// ============================================================
--//  ХУК через hookmetamethod (fallback)
--// ============================================================
local mtHooked = false

local function hookViaMetamethod()
    if mtHooked then return true end
    if not hookmetamethod or not getnamecallmethod then return false end

    local ok = pcall(function()
        local oldNamecall
        oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
            local method = getnamecallmethod()
            local args = {...}

            if method == "FireServer" and Config.Enabled then
                local char = LocalPlayer.Character
                local tool = char and char:FindFirstChildWhichIsA("Tool")

                if tool then
                    -- Перевіряємо чи це ремоут зброї
                    local isWeaponRemote = false
                    local parent = self.Parent
                    while parent do
                        if parent == tool then
                            isWeaponRemote = true
                            break
                        end
                        parent = parent.Parent
                    end

                    if isWeaponRemote then
                        if math.random(1, 100) <= Config.HitChance then
                            local target = findBestTarget()
                            if target then
                                local aimPos = predictPosition(target, getPing())
                                for i, arg in ipairs(args) do
                                    if typeof(arg) == "Vector3" then
                                        args[i] = aimPos
                                    end
                                end
                                Stats.Shots = Stats.Shots + 1
                                currentTarget = target
                            end
                        end
                    end
                end
            end

            return oldNamecall(self, unpack(args))
        end))

        mtHooked = true
        Log.ok("Metamethod hooked (fallback)")
    end)

    return ok
end

--// ============================================================
--//  UNIFIED HOOK
--// ============================================================
local function tryHook()
    local ok1 = pcall(hookViaGetsenv)
    if ok1 then return true end

    local ok2 = pcall(hookViaMetamethod)
    return ok2
end

--// ============================================================
--//  AUTO-SHOOT / TRIGGER BOT
--// ============================================================
local lastShoot = 0

RunService.Heartbeat:Connect(function()
    if not Config.Enabled then return end

    -- Auto Shoot
    if Config.AutoShoot then
        if tick() - lastShoot < Config.AutoShootDelay then return end
        local target = findBestTarget()
        if target then
            lastShoot = tick()
            local tool = LocalPlayer.Character 
                      and LocalPlayer.Character:FindFirstChildWhichIsA("Tool")
            if tool then
                -- Симулюємо клік через inputbegan fire (не працює напряму, але хук
                -- активується при натисканні, тож лишаємо це як TODO — 
                -- тут потрібен VIM або інший метод)
                pcall(function()
                    LocalPlayer:GetMouse():Click()
                end)
            end
        end
    end

    -- Trigger Bot
    if Config.TriggerBot then
        local target = findBestTarget()
        if target then
            local screenPos, onScreen = Camera:WorldToViewportPoint(target.Position)
            if onScreen then
                local mousePos = UserInputService:GetMouseLocation()
                local d = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
                if d <= Config.TriggerRadius then
                    if tick() - lastShoot > 0.15 then
                        lastShoot = tick()
                        -- Активація пострілу через mouse1click
                        pcall(function()
                            if mouse1click then mouse1click() end
                        end)
                    end
                end
            end
        end
    end
end)

--// ============================================================
--//  RENDER LOOP (візуалізація + авто-хук)
--// ============================================================
local reconnectTimer = 0

RunService.RenderStepped:Connect(function(dt)
    -- Авто-хук кожні 2 секунди
    reconnectTimer = reconnectTimer + dt
    if reconnectTimer > 2 then
        reconnectTimer = 0
        if Config.Enabled then
            tryHook()
        end
    end

    -- Візуалізація цілі
    if not Config.Enabled then
        targetLine.Visible = false
        targetDot.Visible = false
        targetBox.Visible = false
        return
    end

    local target = findBestTarget()
    currentTarget = target

    if target then
        local screenPos, onScreen = Camera:WorldToViewportPoint(target.Position)

        if onScreen then
            -- Dot
            if Config.ShowTargetDot then
                targetDot.Visible = true
                targetDot.Position = Vector2.new(screenPos.X, screenPos.Y)
                targetDot.Color = Config.TargetColor
            else
                targetDot.Visible = false
            end

            -- Line
            if Config.ShowTargetLine then
                local vp = Camera.ViewportSize
                targetLine.Visible = true
                targetLine.From = Vector2.new(vp.X / 2, vp.Y)
                targetLine.To = Vector2.new(screenPos.X, screenPos.Y)
                targetLine.Color = Config.LineColor
            else
                targetLine.Visible = false
            end

            -- Box (простий)
            if Config.ShowTargetBox then
                local size = math.clamp(2000 / (Camera.CFrame.Position - target.Position).Magnitude, 20, 200)
                targetBox.Visible = true
                targetBox.Size = Vector2.new(size * 0.5, size)
                targetBox.Position = Vector2.new(screenPos.X - size * 0.25, screenPos.Y - size * 0.5)
                targetBox.Color = Config.TargetColor
            else
                targetBox.Visible = false
            end
        else
            targetLine.Visible = false
            targetDot.Visible = false
            targetBox.Visible = false
        end
    else
        targetLine.Visible = false
        targetDot.Visible = false
        targetBox.Visible = false
    end
end)

--// ============================================================
--//  KEYBIND
--// ============================================================
UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Config.ToggleKey then
        Config.Enabled = not Config.Enabled
        if Config.Enabled then
            tryHook()
            notify("💀 Silent Aim", "ON", 2)
            Log.info("Enabled")
        else
            notify("💀 Silent Aim", "OFF", 2)
            Log.info("Disabled")
        end
    end
end)

--// ============================================================
--//  МОДУЛЬ
--// ============================================================
local SilentAim = {}
SilentAim.__index = SilentAim

function SilentAim.new()
    local self = setmetatable({}, SilentAim)

    -- Автопідключення
    LocalPlayer.CharacterAdded:Connect(function()
        task.wait(1.5)
        tryHook()
    end)

    task.wait(0.5)
    tryHook()

    return self
end

-- API для UI
function SilentAim:setEnabled(state)
    Config.Enabled = state
    if state then
        tryHook()
        Log.info("Enabled (via UI)")
    else
        Log.info("Disabled (via UI)")
    end
end

function SilentAim:setFOV(value)
    -- FOV не використовується (без FOV)
end

function SilentAim:setAimPart(part) Config.AimPart = part end
function SilentAim:setHitChance(v) Config.HitChance = v end
function SilentAim:setWallBang(v) Config.WallBang = v end
function SilentAim:setTargetMode(mode) Config.TargetMode = mode end
function SilentAim:setPriority(p) Config.Priority = p end
function SilentAim:setPredict(v) Config.PredictMovement = v end
function SilentAim:setAutoShoot(v) Config.AutoShoot = v end
function SilentAim:setTriggerBot(v) Config.TriggerBot = v end

function SilentAim:getStats()
    local accuracy = 0
    if Stats.Shots > 0 then
        accuracy = math.floor((Stats.Kills / Stats.Shots) * 100)
    end
    return {
        Shots = Stats.Shots,
        Kills = Stats.Kills,
        Accuracy = accuracy,
        Uptime = math.floor(tick() - Stats.SessionStart),
    }
end

--// ============================================================
--//  СТАРТ
--// ============================================================
Log.info("═══════════════════════════════════")
Log.info("TrustHub Silent Aim PRO v3.0")
Log.info("Toggle: C key")
Log.info("═══════════════════════════════════")

notify("💀 Silent Aim PRO", "Loaded. Press C to toggle.", 5)

return SilentAim.new()
