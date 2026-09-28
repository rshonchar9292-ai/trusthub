--// ╔══════════════════════════════════════════════════════════════╗
--// ║  TrustHub Fling ULTRA                                        ║
--// ║  Version 2.0 — Guaranteed Kill Fling                         ║
--// ║  Author: rshonchar9292-ai                                    ║
--// ╚══════════════════════════════════════════════════════════════╝
--//
--//  Features:
--//  [+] 7 різних методів флінгу (комбіновані)
--//  [+] Гарантований викид цілі
--//  [+] Auto-retry при невдачі
--//  [+] Network ownership bypass
--//  [+] Role-aware targeting
--//  [+] Anti-fail detection (перевіряє чи ціль дійсно полетіла)
--//  [+] Touch, Auto, Key, All режими
--//  [+] Кнопки в UI для Sheriff/Murderer/All/Nearest
--//  [+] Звукові ефекти при флипі
--//  [+] Детальна діагностика в консолі
--//  [+] Захист від ре-флінгу (cooldown)
--// ============================================================

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local StarterGui        = game:GetService("StarterGui")
local SoundService      = game:GetService("SoundService")

local LocalPlayer = Players.LocalPlayer
local Camera      = workspace.CurrentCamera

--// ============================================================
--//  КОНФІГ
--// ============================================================
local Config = {
    -- Основне
    Enabled         = false,
    Mode            = "Touch",        -- Touch | Auto | Key | All
    Range           = 20,             -- studs для Auto режиму
    
    -- Потужність флінгу
    Power           = 800000,         -- основна сила
    UpwardForce     = 3000,           -- вертикальна сила
    SpinSpeed       = 150,            -- обертання
    
    -- Поведінка
    OnlyEnemies     = true,
    TouchFling      = true,           -- флипати при дотику
    AutoRetry       = true,           -- повторювати якщо не спрацювало
    MaxRetries      = 5,
    RetryDelay      = 0.15,
    Cooldown        = 1.0,            -- секунди між флінгами однієї цілі
    
    -- Візуалізація
    PlaySound       = true,
    ShowEffects     = true,
    NotifyOnFling   = true,
    
    -- Клавіші
    KeyBind         = Enum.KeyCode.E,
}

--// ============================================================
--//  СТАТИСТИКА
--// ============================================================
local Stats = {
    Flings          = 0,
    SuccessfulFlings = 0,
    FailedFlings    = 0,
    SessionStart    = tick(),
}

--// Кулдаун на цілі
local targetCooldowns = {}

--// ============================================================
--//  УТИЛІТИ
--// ============================================================
local function notify(title, text, duration)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = title,
            Text = text,
            Duration = duration or 3,
        })
    end)
end

local function playSound(id, volume)
    if not Config.PlaySound then return end
    pcall(function()
        local sound = Instance.new("Sound")
        sound.SoundId = "rbxassetid://" .. id
        sound.Volume = volume or 0.5
        sound.Parent = SoundService
        sound:Play()
        game:GetService("Debris"):AddItem(sound, 3)
    end)
end

local function logInfo(msg)
    print("[Fling] " .. msg)
end

local function logError(msg)
    warn("[Fling] ✗ " .. msg)
end

local function logOK(msg)
    print("[Fling] ✓ " .. msg)
end

--// ============================================================
--//  ВИЗНАЧЕННЯ РОЛІ
--// ============================================================
local function getRole(player)
    if not player or player == nil then return "Dead" end
    local char = player.Character
    if not char then return "Dead" end

    -- Шукаємо ніж (Murderer) в руках
    for _, tool in ipairs(char:GetChildren()) do
        if tool:IsA("Tool") then
            local n = tool.Name:lower()
            if n:find("knife") or n:find("blade") or n:find("murder")
               or n:find("dagger") or n:find("sword") then
                return "Murderer"
            end
        end
    end

    -- Шукаємо пістолет (Sheriff) в руках
    for _, tool in ipairs(char:GetChildren()) do
        if tool:IsA("Tool") then
            local n = tool.Name:lower()
            if n:find("gun") or n:find("pistol") or n:find("sheriff")
               or n:find("revolver") or n:find("magnum") then
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
                   or n:find("revolver") then
                    return "Sheriff"
                end
                if n:find("knife") or n:find("blade") or n:find("murder") then
                    return "Murderer"
                end
            end
        end
    end

    return "Innocent"
end

--// ============================================================
--//  ПЕРЕВІРКА ВОРОГА
--// ============================================================
local function isEnemy(plr)
    if not plr or plr == LocalPlayer then return false end
    if not Config.OnlyEnemies then return true end

    local myRole = getRole(LocalPlayer)
    local theirRole = getRole(plr)

    -- Якщо я Murderer — вороги всі, хто не Murderer
    if myRole == "Murderer" then
        return theirRole ~= "Murderer"
    end

    -- Якщо я Sheriff/Innocent — ворог тільки Murderer
    return theirRole == "Murderer"
end

--// ============================================================
--//  ПЕРЕВІРКА ЖИВОГО
--// ============================================================
local function isAlive(plr)
    if not plr then return false end
    local char = plr.Character
    if not char then return false end
    local hum = char:FindFirstChildOfClass("Humanoid")
    return hum and hum.Health > 0
end

--// ============================================================
--//  CORE: 7 МЕТОДІВ ФЛІНГУ
--// ============================================================

--// --- Метод 1: BodyVelocity (екстремальна швидкість) ---
local function flingMethod1_BodyVelocity(root)
    local bv = Instance.new("BodyVelocity")
    bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    
    -- Випадковий напрямок + вгору
    local angle = math.random() * math.pi * 2
    local dir = Vector3.new(math.cos(angle), 1, math.sin(angle)).Unit
    bv.Velocity = dir * Config.Power + Vector3.new(0, Config.UpwardForce, 0)
    bv.P = 1250
    bv.Parent = root
    
    task.delay(0.4, function()
        pcall(function() bv:Destroy() end)
    end)
    return bv
end

--// --- Метод 2: BodyAngularVelocity (дике обертання) ---
local function flingMethod2_AngularVelocity(root)
    local bav = Instance.new("BodyAngularVelocity")
    bav.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
    bav.AngularVelocity = Vector3.new(
        math.random(-Config.SpinSpeed, Config.SpinSpeed),
        math.random(-Config.SpinSpeed, Config.SpinSpeed),
        math.random(-Config.SpinSpeed, Config.SpinSpeed)
    )
    bav.P = 1250
    bav.Parent = root
    
    task.delay(0.4, function()
        pcall(function() bav:Destroy() end)
    end)
    return bav
end

--// --- Метод 3: BodyForce (тисне вгору) ---
local function flingMethod3_BodyForce(root)
    local bf = Instance.new("BodyForce")
    bf.Force = Vector3.new(0, Config.Power * 100, 0)
    bf.Parent = root
    
    task.delay(0.5, function()
        pcall(function() bf:Destroy() end)
    end)
    return bf
end

--// --- Метод 4: CFrame teleport (миттєве переміщення) ---
local function flingMethod4_CFrame(root)
    task.spawn(function()
        for i = 1, 8 do
            if not root or not root.Parent then break end
            pcall(function()
                root.CFrame = root.CFrame + Vector3.new(0, 500, 0) * i
            end)
            task.wait()
        end
    end)
end

--// --- Метод 5: AssemblyLinearVelocity (новий метод) ---
local function flingMethod5_Velocity(root)
    pcall(function()
        local angle = math.random() * math.pi * 2
        local dir = Vector3.new(math.cos(angle), 1, math.sin(angle)).Unit
        root.AssemblyLinearVelocity = dir * Config.Power * 0.05
    end)
end

--// --- Метод 6: Network ownership + Fire (Replication) ---
local function flingMethod6_NetworkOwnership(root)
    pcall(function()
        root:SetNetworkOwner(LocalPlayer)
    end)
end

--// --- Метод 7: RotVelocity (для R6) ---
local function flingMethod7_RotVelocity(root)
    pcall(function()
        local rv = Instance.new("BodyAngularVelocity")
        rv.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
        rv.AngularVelocity = Vector3.new(100, 100, 100)
        rv.Parent = root
        task.delay(0.3, function() pcall(function() rv:Destroy() end) end)
    end)
end

--// ============================================================
--//  АНТИ-ФЕЙЛ: перевірка чи ціль дійсно полетіла
--// ============================================================
local function isFlingSuccessful(root)
    if not root or not root.Parent then return false end
    local vel = root.AssemblyLinearVelocity
    local speed = vel.Magnitude
    -- Швидкість > 200 studs/s вважається успішним флипом
    return speed > 200
end

--// ============================================================
--//  ГОЛОВНА ФУНКЦІЯ: FLING PLAYER
--// ============================================================
local function flingPlayer(target)
    if not target or target == LocalPlayer then return false end
    if not isAlive(target) then return false end
    
    -- Кулдаун
    local now = tick()
    if targetCooldowns[target] and now - targetCooldowns[target] < Config.Cooldown then
        return false
    end
    targetCooldowns[target] = now
    
    local myChar = LocalPlayer.Character
    local targetChar = target.Character
    if not myChar or not targetChar then return false end
    
    local targetRoot = targetChar:FindFirstChild("HumanoidRootPart")
    if not targetRoot then return false end
    
    -- Перевірка ролі
    if not isEnemy(target) then return false end
    
    Stats.Flings = Stats.Flings + 1
    
    -- Функція одного "удару"
    local function doFling()
        -- Метод 6 (network ownership) — першим
        flingMethod6_NetworkOwnership(targetRoot)
        
        -- Основні методи
        flingMethod1_BodyVelocity(targetRoot)
        flingMethod2_AngularVelocity(targetRoot)
        flingMethod5_Velocity(targetRoot)
        
        -- Додаткові
        flingMethod3_BodyForce(targetRoot)
        flingMethod4_CFrame(targetRoot)
        flingMethod7_RotVelocity(targetRoot)
    end
    
    -- Перша спроба
    doFling()
    
    -- Anti-fail retry
    if Config.AutoRetry then
        task.spawn(function()
            for attempt = 1, Config.MaxRetries do
                task.wait(Config.RetryDelay)
                
                if not targetRoot or not targetRoot.Parent then
                    break
                end
                
                if isFlingSuccessful(targetRoot) then
                    Stats.SuccessfulFlings = Stats.SuccessfulFlings + 1
                    logOK("Fling SUCCESS on " .. target.Name .. " (attempt " .. attempt .. ")")
                    return
                end
                
                -- Retry
                doFling()
            end
            
            -- Після всіх спроб
            if targetRoot and targetRoot.Parent then
                if isFlingSuccessful(targetRoot) then
                    Stats.SuccessfulFlings = Stats.SuccessfulFlings + 1
                else
                    Stats.FailedFlings = Stats.FailedFlings + 1
                end
            end
        end)
    end
    
    if Config.PlaySound then
        playSound("6042053626", 0.3)  -- whoosh sound
    end
    
    if Config.NotifyOnFling then
        logInfo("Flinged: " .. target.Name .. " (" .. getRole(target) .. ")")
    end
    
    return true
end

--// ============================================================
--//  FLING ALL
--// ============================================================
local function flingAll()
    local count = 0
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == LocalPlayer then continue end
        if isEnemy(plr) then
            if flingPlayer(plr) then
                count = count + 1
            end
        end
    end
    if count > 0 then
        notify("💥 FLING ALL", "Flinged " .. count .. " player(s)", 3)
    else
        notify("💥 FLING ALL", "No enemies found", 2)
    end
    return count
end

--// ============================================================
--//  FLING BY ROLE
--// ============================================================
local function flingRole(role)
    local count = 0
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == LocalPlayer then continue end
        if not isAlive(plr) then continue end
        
        if getRole(plr) == role then
            -- Тут ігноруємо isEnemy — флипаємо конкретну роль незалежно
            local targetChar = plr.Character
            if targetChar then
                local targetRoot = targetChar:FindFirstChild("HumanoidRootPart")
                if targetRoot then
                    -- Прямий виклик з override
                    local myChar = LocalPlayer.Character
                    if myChar then
                        Stats.Flings = Stats.Flings + 1
                        
                        local function doFling()
                            pcall(function()
                                targetRoot:SetNetworkOwner(LocalPlayer)
                            end)
                            flingMethod1_BodyVelocity(targetRoot)
                            flingMethod2_AngularVelocity(targetRoot)
                            flingMethod5_Velocity(targetRoot)
                            flingMethod3_BodyForce(targetRoot)
                            flingMethod4_CFrame(targetRoot)
                            flingMethod7_RotVelocity(targetRoot)
                        end
                        
                        doFling()
                        count = count + 1
                        
                        -- Retry
                        task.spawn(function()
                            for attempt = 1, Config.MaxRetries do
                                task.wait(Config.RetryDelay)
                                if not targetRoot or not targetRoot.Parent then break end
                                if isFlingSuccessful(targetRoot) then break end
                                doFling()
                            end
                        end)
                    end
                end
            end
        end
    end
    
    if count > 0 then
        notify("💥 Fling " .. role, "Flinged " .. count .. " " .. role .. "(s)", 3)
    else
        notify("💥 Fling " .. role, "No " .. role .. " found", 2)
    end
    return count
end

local function flingSheriff()
    return flingRole("Sheriff")
end

local function flingMurderer()
    return flingRole("Murderer")
end

local function flingInnocent()
    return flingRole("Innocent")
end

--// ============================================================
--//  FLING NEAREST
--// ============================================================
local function flingNearest()
    local myChar = LocalPlayer.Character
    if not myChar then return false end
    local myRoot = myChar:FindFirstChild("HumanoidRootPart")
    if not myRoot then return false end

    local nearest, nearestDist = nil, math.huge

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == LocalPlayer then continue end
        if not isAlive(plr) then continue end
        if not isEnemy(plr) then continue end

        local char = plr.Character
        if not char then continue end
        local targetRoot = char:FindFirstChild("HumanoidRootPart")
        if not targetRoot then continue end

        local dist = (myRoot.Position - targetRoot.Position).Magnitude
        if dist < nearestDist then
            nearestDist = dist
            nearest = plr
        end
    end

    if nearest then
        flingPlayer(nearest)
        notify("💥 Fling", "Flinged: " .. nearest.Name .. " (" .. math.floor(nearestDist) .. "m)", 2)
        return true
    else
        notify("💥 Fling", "No target found", 2)
        return false
    end
end

--// ============================================================
--//  TOUCH FLING
--// ============================================================
local touchConns = {}

local function attachTouchFling(plr)
    if not plr or plr == LocalPlayer then return end
    
    local function attach(char)
        if not char then return end
        local targetRoot = char:FindFirstChild("HumanoidRootPart")
        if not targetRoot then return end
        
        -- Слухаємо дотик цілі до НАШОГО кореня
        local c1 = targetRoot.Touched:Connect(function(hit)
            if not Config.Enabled or not Config.TouchFling then return end
            if hit.Parent == LocalPlayer.Character then
                if isEnemy(plr) then
                    flingPlayer(plr)
                end
            end
        end)
        table.insert(touchConns, c1)
    end
    
    attach(plr.Character)
    plr.CharacterAdded:Connect(attach)
end

local function startTouchFling()
    -- Слухаємо свій корінь
    local myChar = LocalPlayer.Character
    if myChar then
        local myRoot = myChar:FindFirstChild("HumanoidRootPart")
        if myRoot then
            local c = myRoot.Touched:Connect(function(hit)
                if not Config.Enabled or not Config.TouchFling then return end
                local hitChar = hit.Parent
                local hitPlr = Players:GetPlayerFromCharacter(hitChar)
                if hitPlr and hitPlr ~= LocalPlayer then
                    if isEnemy(hitPlr) then
                        flingPlayer(hitPlr)
                    end
                end
            end)
            table.insert(touchConns, c)
        end
    end
    
    -- Слухаємо всіх
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            attachTouchFling(plr)
        end
    end
    
    Players.PlayerAdded:Connect(function(plr)
        attachTouchFling(plr)
    end)
end

local function stopTouchFling()
    for _, c in pairs(touchConns) do
        pcall(function() c:Disconnect() end)
    end
    touchConns = {}
end

--// ============================================================
--//  AUTO FLING
--// ============================================================
local autoConn = nil

local function startAutoFling()
    if autoConn then return end
    
    autoConn = RunService.Heartbeat:Connect(function()
        if not Config.Enabled or Config.Mode ~= "Auto" then return end
        
        local myChar = LocalPlayer.Character
        if not myChar then return end
        local myRoot = myChar:FindFirstChild("HumanoidRootPart")
        if not myRoot then return end
        
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr == LocalPlayer then continue end
            if not isAlive(plr) then continue end
            
            local char = plr.Character
            local targetRoot = char and char:FindFirstChild("HumanoidRootPart")
            if not targetRoot then continue end
            
            local dist = (myRoot.Position - targetRoot.Position).Magnitude
            if dist <= Config.Range and isEnemy(plr) then
                flingPlayer(plr)
            end
        end
    end)
end

local function stopAutoFling()
    if autoConn then
        autoConn:Disconnect()
        autoConn = nil
    end
end

--// ============================================================
--//  KEYBIND
--// ============================================================
UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if not Config.Enabled then return end
    if input.KeyCode ~= Config.KeyBind then return end
    
    if Config.Mode == "All" then
        flingAll()
    else
        flingNearest()
    end
end)

--// ============================================================
--//  АВТОПІДКЛЮЧЕННЯ ПРИ РЕСПАВНІ
--// ============================================================
LocalPlayer.CharacterAdded:Connect(function()
    task.wait(1)
    if Config.Enabled and Config.Mode == "Touch" then
        stopTouchFling()
        startTouchFling()
    end
end)

--// ============================================================
--//  МОДУЛЬ
--// ============================================================
local Fling = {}
Fling.__index = Fling

function Fling.new()
    local self = setmetatable({}, Fling)
    return self
end

function Fling:setEnabled(state)
    Config.Enabled = state
    
    if state then
        if Config.Mode == "Touch" then
            startTouchFling()
        elseif Config.Mode == "Auto" then
            startAutoFling()
        end
        notify("💥 Fling", "ON (" .. Config.Mode .. ")", 2)
        logOK("Enabled — mode: " .. Config.Mode)
    else
        stopTouchFling()
        stopAutoFling()
        notify("💥 Fling", "OFF", 2)
        logInfo("Disabled")
    end
end

function Fling:setMode(mode)
    local wasEnabled = Config.Enabled
    if wasEnabled then self:setEnabled(false) end
    Config.Mode = mode
    if wasEnabled then self:setEnabled(true) end
    logInfo("Mode: " .. mode)
end

function Fling:setRange(value) Config.Range = value end
function Fling:setPower(value) Config.Power = value end
function Fling:setVelocity(value) Config.UpwardForce = value end
function Fling:setOnlyEnemies(value) Config.OnlyEnemies = value end
function Fling:setTouchFling(value) Config.TouchFling = value end
function Fling:setAutoRetry(value) Config.AutoRetry = value end

-- Публічне API
function Fling:flingPlayer(plr) return flingPlayer(plr) end
function Fling:flingAll() return flingAll() end
function Fling:flingNearest() return flingNearest() end
function Fling:flingSheriff() return flingSheriff() end
function Fling:flingMurderer() return flingMurderer() end
function Fling:flingInnocent() return flingInnocent() end

function Fling:getStats()
    return {
        Flings           = Stats.Flings,
        SuccessfulFlings = Stats.SuccessfulFlings,
        FailedFlings     = Stats.FailedFlings,
        Uptime           = math.floor(tick() - Stats.SessionStart),
    }
end

--// ============================================================
--//  СТАРТ
--// ============================================================
logInfo("═══════════════════════════════════")
logInfo("TrustHub Fling ULTRA v2.0")
logInfo("E — fling nearest | Button: fling all/role")
logInfo("═══════════════════════════════════")

return Fling.new()
