--// ╔══════════════════════════════════════════════════════════════════╗
--// ║  TrustHub Fling v5.0 — Production Grade                         ║
--// ║  Combined Weld + Velocity + CFrame Rotation Method               ║
--// ║  Author: rshonchar9292-ai                                        ║
--// ╚══════════════════════════════════════════════════════════════════╝
--//
--//  МЕТОДИ (всі застосовуються одночасно):
--//  1. Network Ownership Hijack (всі BaseParts)
--//  2. Velocity Spam (BodyVelocity на кожну частину)
--//  3. CFrame Rotation Exploit (дике обертання через CFrame)
--//  4. Weld Exploit (приварка до обертаючої частини)
--//  5. PlatformStand (вимкнення контролю гравця)
--//  6. AssemblyLinearVelocity (пряма установка)
--//  7. Torque Exploit (фізичне обертання)
--//
--//  РЕЖИМИ:
--//  Touch  — флінгує при дотику (100% надійно)
--//  Direct — телепорт + флінг
--//  Role   — флінг за роллю (Sheriff/Murderer)
-- ================================================================

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local StarterGui       = game:GetService("StarterGui")
local Debris           = game:GetService("Debris")

local LocalPlayer = Players.LocalPlayer
local Camera      = workspace.CurrentCamera

--// ================================================================
--//  CONFIG
--// ================================================================
local Config = {
    -- Потужність
    VelocityPower  = 500000,     -- швидкість для флінгу
    SpinSpeed      = 500,        -- швидкість обертання
    UpwardPower    = 100000,     -- вертикальна сила
    WeldRotSpeed   = 999999,     -- обертання weld-частини
    Torque         = 1000000,    -- фізична сила обертання
    
    -- Режими
    TeleportFirst  = true,       -- телепорт до цілі перед флінгом
    TouchFling     = true,       -- флінг при дотику
    AutoRetry      = true,       -- повторювати якщо не спрацювало
    MaxRetries     = 3,
    RetryDelay     = 0.1,
    
    -- Фільтри
    OnlyEnemies    = true,
    Cooldown       = 1.0,
    
    -- Тонке
    MinVelocity    = 300,        -- мінімальна швидкість для "успішного" флінгу
    PlatformStand  = true,       -- вимикати контроль жертви
    CleanupTime    = 1.5,        -- через скільки секунд видаляти споруди
}

--// ================================================================
--//  СТАТИСТИКА
--// ================================================================
local Stats = {
    Flings           = 0,
    SuccessfulFlings = 0,
    FailedFlings     = 0,
    SessionStart     = tick(),
}

local cooldowns = {}
local activeBuilds = {}  -- [targetRoot] = {objects...}

--// ================================================================
--//  UTILITIES
--// ================================================================
local function notify(title, text, duration)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = title,
            Text = text,
            Duration = duration or 3,
        })
    end)
end

local function log(msg) print("[Fling] " .. msg) end
local function logOK(msg) print("[Fling] ✓ " .. msg) end
local function logErr(msg) warn("[Fling] ✗ " .. msg) end

--// ================================================================
--//  ROLE DETECTION
--// ================================================================
local function getRole(player)
    if not player then return "Dead" end
    local char = player.Character
    if not char then return "Dead" end

    -- Шукаємо ніж (Murderer) в руках
    for _, tool in ipairs(char:GetChildren()) do
        if tool:IsA("Tool") then
            local n = tool.Name:lower()
            if n:find("knife") or n:find("blade") or n:find("murder")
               or n:find("dagger") or n:find("sword") or n:find("kukri") then
                return "Murderer"
            end
        end
    end

    -- Шукаємо пістолет (Sheriff) в руках
    for _, tool in ipairs(char:GetChildren()) do
        if tool:IsA("Tool") then
            local n = tool.Name:lower()
            if n:find("gun") or n:find("pistol") or n:find("sheriff")
               or n:find("revolver") or n:find("magnum") or n:find("shoot") then
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

local function isAlive(plr)
    if not plr then return false end
    local char = plr.Character
    if not char then return false end
    local hum = char:FindFirstChildOfClass("Humanoid")
    return hum and hum.Health > 0
end

local function isEnemy(plr)
    if not plr or plr == LocalPlayer then return false end
    if not Config.OnlyEnemies then return true end

    local myRole = getRole(LocalPlayer)
    local theirRole = getRole(plr)

    -- Якщо я Murderer — вороги всі
    if myRole == "Murderer" then
        return theirRole ~= "Murderer"
    end
    -- Інакше ворог тільки Murderer
    return theirRole == "Murderer"
end

--// ================================================================
--//  NETWORK OWNERSHIP HIJACK
--// ================================================================
local function takeOwnership(character)
    if not character then return end

    -- Забираємо ownership на ВСЕ тіло
    for _, part in ipairs(character:GetDescendants()) do
        if part:IsA("BasePart") then
            pcall(function()
                part:SetNetworkOwner(LocalPlayer)
            end)
        end
    end

    -- Забираємо ownership і на аксесуари
    for _, child in ipairs(character:GetChildren()) do
        if child:IsA("Accessory") then
            local handle = child:FindFirstChild("Handle")
            if handle and handle:IsA("BasePart") then
                pcall(function()
                    handle:SetNetworkOwner(LocalPlayer)
                end)
            end
        end
    end
end

--// ================================================================
--//  METHOD 1: VELOCITY SPAM (BodyVelocity на все)
--// ================================================================
local function flingVelocity(character)
    local objects = {}
    local directions = {
        Vector3.new(1, 1, 0),
        Vector3.new(-1, 1, 0),
        Vector3.new(0, 1, 1),
        Vector3.new(0, 1, -1),
        Vector3.new(1, 1, 1),
        Vector3.new(-1, 1, -1),
    }

    for _, part in ipairs(character:GetDescendants()) do
        if part:IsA("BasePart") then
            -- BodyVelocity на кожну частину
            local bv = Instance.new("BodyVelocity")
            bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
            bv.P = 1250
            bv.Velocity = directions[math.random(#directions)] * Config.VelocityPower
            bv.Parent = part
            table.insert(objects, bv)

            -- BodyAngularVelocity — обертання
            local bav = Instance.new("BodyAngularVelocity")
            bav.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
            bav.P = 1250
            bav.AngularVelocity = Vector3.new(
                math.random(-Config.SpinSpeed, Config.SpinSpeed),
                math.random(-Config.SpinSpeed, Config.SpinSpeed),
                math.random(-Config.SpinSpeed, Config.SpinSpeed)
            )
            bav.Parent = part
            table.insert(objects, bav)
        end
    end

    return objects
end

--// ================================================================
--//  METHOD 2: CFRAME ROTATION EXPLOIT
--// ================================================================
local function flingCFrameRotation(character)
    local objects = {}
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return objects end

    -- Створюємо runner, який буде швидко крутити CFrame
    task.spawn(function()
        for i = 1, 20 do
            if not hrp or not hrp.Parent then break end
            pcall(function()
                hrp.CFrame = hrp.CFrame * CFrame.Angles(
                    math.rad(math.random(-180, 180)),
                    math.rad(math.random(-180, 180)),
                    math.rad(math.random(-180, 180))
                )
                hrp.CFrame = hrp.CFrame + Vector3.new(
                    math.random(-50, 50),
                    math.random(50, 200),
                    math.random(-50, 50)
                )
            end)
            task.wait(0.01)
        end
    end)

    return objects
end

--// ================================================================
--//  METHOD 3: WELD EXPLOIT (найнадійніший)
--// ================================================================
-- Створюємо невидиму частину в позиції цілі, приварюємо її HRP
-- і крутимо частину на 999999 градусів — фізика вибухає
local function flingWeldExploit(character)
    local objects = {}
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return objects end

    -- Створюємо частину
    local weldPart = Instance.new("Part")
    weldPart.Name = "FlingWeld"
    weldPart.Size = Vector3.new(1, 1, 1)
    weldPart.CFrame = hrp.CFrame * CFrame.new(0, 0, 3)
    weldPart.Anchored = true
    weldPart.CanCollide = false
    weldPart.Transparency = 1
    weldPart.Massless = true
    weldPart.Parent = workspace
    table.insert(objects, weldPart)

    -- Weld HRP до цієї частини
    local weld = Instance.new("WeldConstraint")
    weld.Part0 = hrp
    weld.Part1 = weldPart
    weld.Parent = weldPart
    table.insert(objects, weld)

    -- Швидко обертаємо частину (999999 градусів)
    task.spawn(function()
        for i = 1, 30 do
            if not weldPart or not weldPart.Parent then break end
            if not hrp or not hrp.Parent then break end
            pcall(function()
                weldPart.CFrame = weldPart.CFrame * CFrame.Angles(
                    math.rad(Config.WeldRotSpeed),
                    math.rad(Config.WeldRotSpeed),
                    math.rad(Config.WeldRotSpeed)
                )
            end)
            task.wait(0.005)
        end
    end)

    return objects
end

--// ================================================================
--//  METHOD 4: TORQUE EXPLOIT
--// ================================================================
local function flingTorque(character)
    local objects = {}
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return objects end

    -- BodyThrust — фізична сила в різні боки
    for i = 1, 6 do
        local bt = Instance.new("BodyThrust")
        bt.Force = Vector3.new(
            math.random(-Config.Torque, Config.Torque),
            Config.Torque,
            math.random(-Config.Torque, Config.Torque)
        )
        bt.Location = Vector3.new(
            math.random(-2, 2),
            math.random(-2, 2),
            math.random(-2, 2)
        )
        bt.Parent = hrp
        table.insert(objects, bt)
    end

    return objects
end

--// ================================================================
--//  METHOD 5: PLATFORMSTAND (вимкнути контроль)
--// ================================================================
local function disableControl(character)
    local hum = character:FindFirstChildOfClass("Humanoid")
    if hum then
        pcall(function()
            hum.PlatformStand = true
        end)
    end
end

--// ================================================================
--//  COMBINED FLING — ЗАПУСК ВСІХ МЕТОДІВ
--// ================================================================
local function doFling(character)
    if not character then return end

    -- 1. Забираємо ownership
    takeOwnership(character)

    -- 2. Відключаємо контроль
    if Config.PlatformStand then
        disableControl(character)
    end

    -- 3. Запускаємо ВСІ методи одночасно
    local allObjects = {}

    local v1 = flingVelocity(character)
    for _, o in ipairs(v1) do table.insert(allObjects, o) end

    local v2 = flingCFrameRotation(character)
    for _, o in ipairs(v2) do table.insert(allObjects, o) end

    local v3 = flingWeldExploit(character)
    for _, o in ipairs(v3) do table.insert(allObjects, o) end

    local v4 = flingTorque(character)
    for _, o in ipairs(v4) do table.insert(allObjects, o) end

    -- 4. Пряма установка швидкості на всі частини
    for _, part in ipairs(character:GetDescendants()) do
        if part:IsA("BasePart") then
            pcall(function()
                part.AssemblyLinearVelocity = Vector3.new(
                    math.random(-Config.VelocityPower, Config.VelocityPower),
                    Config.VelocityPower,
                    math.random(-Config.VelocityPower, Config.VelocityPower)
                )
            end)
        end
    end

    -- 5. Cleanup через CleanupTime секунд
    task.delay(Config.CleanupTime, function()
        for _, obj in ipairs(allObjects) do
            pcall(function()
                if obj and obj.Parent then obj:Destroy() end
            end)
        end
    end)

    return allObjects
end

--// ================================================================
--//  CHECK SUCCESS
--// ================================================================
local function isFlingSuccessful(character)
    if not character or not character.Parent then return false end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end

    local vel = hrp.AssemblyLinearVelocity
    return vel.Magnitude >= Config.MinVelocity
end

--// ================================================================
--//  TELEPORT TO TARGET
--// ================================================================
local function teleportTo(targetChar)
    local myChar = LocalPlayer.Character
    if not myChar or not targetChar then return end
    local myRoot = myChar:FindFirstChild("HumanoidRootPart")
    local tRoot = targetChar:FindFirstChild("HumanoidRootPart")
    if not myRoot or not tRoot then return end

    pcall(function()
        myRoot.CFrame = tRoot.CFrame * CFrame.new(2, 0, 2)
    end)
end

--// ================================================================
--//  FLING PLAYER
--// ================================================================
local function flingPlayer(target)
    if not target or target == LocalPlayer then return false end
    if not isAlive(target) then return false end

    local now = tick()
    if cooldowns[target] and now - cooldowns[target] < Config.Cooldown then
        return false
    end
    cooldowns[target] = now

    local targetChar = target.Character
    if not targetChar then return false end

    Stats.Flings = Stats.Flings + 1

    -- Телепорт до цілі (якщо увімкнено)
    if Config.TeleportFirst then
        teleportTo(targetChar)
        task.wait(0.05)
    end

    -- Основний флінг
    doFling(targetChar)

    -- Retry якщо не спрацювало
    if Config.AutoRetry then
        task.spawn(function()
            for attempt = 1, Config.MaxRetries do
                task.wait(Config.RetryDelay)

                if not targetChar or not targetChar.Parent then return end

                if isFlingSuccessful(targetChar) then
                    Stats.SuccessfulFlings = Stats.SuccessfulFlings + 1
                    logOK("Fling SUCCESS on " .. target.Name .. " (attempt " .. attempt .. ")")
                    return
                end

                doFling(targetChar)
            end

            if isFlingSuccessful(targetChar) then
                Stats.SuccessfulFlings = Stats.SuccessfulFlings + 1
            else
                Stats.FailedFlings = Stats.FailedFlings + 1
            end
        end)
    end

    log("Flinged: " .. target.Name .. " (" .. getRole(target) .. ")")
    return true
end

--// ================================================================
--//  FLING BY ROLE
--// ================================================================
local function flingRole(role)
    local count = 0
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == LocalPlayer then continue end
        if not isAlive(plr) then continue end
        if getRole(plr) ~= role then continue end

        if flingPlayer(plr) then
            count = count + 1
        end
    end

    if count > 0 then
        notify("💥 Fling " .. role, "Flinged " .. count .. " player(s)", 3)
    else
        notify("💥 Fling " .. role, "No " .. role .. " found", 2)
    end
    return count
end

local function flingSheriff() return flingRole("Sheriff") end
local function flingMurderer() return flingRole("Murderer") end

--// ================================================================
--//  TOUCH FLING (автоматично)
--// ================================================================
local touchConns = {}

local function attachTouchFling(plr)
    if not plr or plr == LocalPlayer then return end

    local function attach(char)
        if not char then return end
        local targetRoot = char:FindFirstChild("HumanoidRootPart")
        if not targetRoot then return end

        local c = targetRoot.Touched:Connect(function(hit)
            if not Config.TouchFling then return end
            if hit.Parent == LocalPlayer.Character then
                if isEnemy(plr) then
                    flingPlayer(plr)
                end
            end
        end)
        table.insert(touchConns, c)
    end

    attach(plr.Character)
    plr.CharacterAdded:Connect(attach)
end

local function startTouchFling()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            attachTouchFling(plr)
        end
    end
    Players.PlayerAdded:Connect(attachTouchFling)
end

local function stopTouchFling()
    for _, c in pairs(touchConns) do
        pcall(function() c:Disconnect() end)
    end
    touchConns = {}
end

--// ================================================================
--//  MODULE
--// ================================================================
local Fling = {}
Fling.__index = Fling

function Fling.new()
    local self = setmetatable({}, Fling)
    return self
end

-- Заглушки для сумісності з UI
function Fling:setEnabled(state)
    if state then
        startTouchFling()
    else
        stopTouchFling()
    end
end

function Fling:setRange() end
function Fling:setPower(v) Config.VelocityPower = v end
function Fling:setVelocity(v) Config.UpwardPower = v end
function Fling:setOnlyEnemies(v) Config.OnlyEnemies = v end
function Fling:setTouchFling(v) Config.TouchFling = v end
function Fling:setAutoRetry(v) Config.AutoRetry = v end

-- Публічне API
function Fling:flingPlayer(plr) return flingPlayer(plr) end
function Fling:flingSheriff() return flingSheriff() end
function Fling:flingMurderer() return flingMurderer() end

function Fling:getStats()
    return {
        Flings           = Stats.Flings,
        SuccessfulFlings = Stats.SuccessfulFlings,
        FailedFlings     = Stats.FailedFlings,
        Uptime           = math.floor(tick() - Stats.SessionStart),
    }
end

--// ================================================================
--//  STARTUP
--// ================================================================
log("════════════════════════════════════════")
log("TrustHub Fling v5.0 — Production Grade")
log("Methods: Velocity + CFrame + Weld + Torque + PlatformStand")
log("════════════════════════════════════════")

return Fling.new()
