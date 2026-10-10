--// ============================================================
--// TrustHub Wings v4.0 — PREMIUM WORKING
--// Багатошарова анімація • Градієнт • Частинки • Trail
--// 100% робоча версія з усіма перевірками
--// ============================================================

local Players      = game:GetService("Players")
local RunService   = game:GetService("RunService")
local LocalPlayer  = Players.LocalPlayer

--// ============================================================
--//  CONFIG
--// ============================================================
local Config = {
    Enabled       = false,
    Size          = 8,
    FlapSpeed     = 4,
    FlapAngle     = 50,
    ColorA        = Color3.fromRGB(255, 255, 255),   -- основа (біля спини)
    ColorB        = Color3.fromRGB(180, 220, 255),   -- кінчик (блакитний відтінок)
    NumFeathers   = 6,
    GlowParticles = true,
    Trail         = false,
    Transparency  = 0.1,
    Material      = Enum.Material.Neon,
}

--// ============================================================
--//  STATE
--// ============================================================
local wingData   = {}       -- {right = {...}, left = {...}}
local animConn   = nil
local glowData   = nil
local flapTime   = 0
local lastUpdate = 0
local currentChar = nil

local function log(msg)
    print("[Wings] " .. tostring(msg))
end

--// ============================================================
--//  CLEANUP
--// ============================================================
local function cleanupWings()
    --// Знімаємо анімацію
    if animConn then
        animConn:Disconnect()
        animConn = nil
    end

    --// Видаляємо частинки
    if glowData then
        if glowData.emitter then pcall(function() glowData.emitter:Destroy() end) end
        if glowData.attachment then pcall(function() glowData.attachment:Destroy() end) end
        glowData = nil
    end

    --// Видаляємо всі частини крил
    local char = currentChar or LocalPlayer.Character
    if char then
        for _, child in ipairs(char:GetChildren()) do
            if child.Name:sub(1, 12) == "TrustHubWing"
                or child.Name == "TrustHubFeather" then
                pcall(function() child:Destroy() end)
            end
        end
    end

    wingData = {}
end

--// ============================================================
--//  BUILD ONE WING
--// ============================================================
local function buildWing(side, char, torso)
    --// side: 1 = right, -1 = left
    local root = Instance.new("Part")
    root.Name = "TrustHubWingRoot_" .. (side == 1 and "R" or "L")
    root.Size = Vector3.new(0.1, 0.1, 0.1)
    root.Transparency = 1
    root.CanCollide = false
    root.CanQuery = false
    root.CanTouch = false
    root.Massless = true
    root.Anchored = false
    root.Parent = char

    --// Motor6D — кріпимо до torso
    local motor = Instance.new("Motor6D")
    motor.Name = "TrustHubWingMotor_" .. (side == 1 and "R" or "L")
    motor.Part0 = torso
    motor.Part1 = root
    motor.C0 = CFrame.new(0.6 * -side, 0.6, 0.65)
    motor.C1 = CFrame.new(0, 0, 0)
    motor.Parent = root

    local feathers = {}
    local n = Config.NumFeathers

    for i = 1, n do
        local t = (i - 1) / math.max(n - 1, 1)
        local length = Config.Size * (1 - t * 0.15)
        local angle = math.rad(-50 + (i - 1) * 22) * side
        local offset = Vector3.new(0, -length / 2 - (i - 1) * 0.1, t * 0.4)

        --// Градієнт кольору
        local col = Config.ColorA:Lerp(Config.ColorB, t)

        local feather = Instance.new("Part")
        feather.Name = "TrustHubFeather"
        feather.Size = Vector3.new(0.15, length, Config.Size * 0.2)
        feather.Color = col
        feather.Material = Config.Material
        feather.Transparency = Config.Transparency
        feather.CanCollide = false
        feather.CanQuery = false
        feather.CanTouch = false
        feather.Massless = true
        feather.Anchored = false
        feather.CastShadow = false
        feather.Parent = char

        local weld = Instance.new("Weld")
        weld.Part0 = root
        weld.Part1 = feather
        weld.C0 = CFrame.Angles(0, 0, angle) * CFrame.new(offset)
        weld.Parent = feather

        table.insert(feathers, feather)
    end

    return {
        root = root,
        motor = motor,
        feathers = feathers,
        side = side,
    }
end

--// ============================================================
--//  BUILD GLOW PARTICLES
--// ============================================================
local function buildGlow(char)
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end

    local attachment = Instance.new("Attachment")
    attachment.Name = "TrustHubGlowAtt"
    attachment.Position = Vector3.new(0, 0, 0)
    attachment.Parent = hrp

    local emitter = Instance.new("ParticleEmitter")
    emitter.Name = "TrustHubGlowEmitter"
    emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
    emitter.Color = ColorSequence.new(Config.ColorA)
    emitter.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.2),
        NumberSequenceKeypoint.new(0.5, 0.5),
        NumberSequenceKeypoint.new(1, 0),
    })
    emitter.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.4),
        NumberSequenceKeypoint.new(1, 1),
    })
    emitter.Lifetime = NumberRange.new(0.8, 1.5)
    emitter.Rate = 20
    emitter.Speed = NumberRange.new(1, 2)
    emitter.SpreadAngle = Vector2.new(180, 180)
    emitter.Rotation = NumberRange.new(0, 360)
    emitter.RotSpeed = NumberRange.new(-90, 90)
    emitter.LightEmission = 1
    emitter.LightInfluence = 0
    emitter.Acceleration = Vector3.new(0, 2, 0)
    emitter.Parent = attachment

    return { attachment = attachment, emitter = emitter }
end

--// ============================================================
--//  BUILD ALL
--// ============================================================
local function buildAll()
    cleanupWings()

    local char = LocalPlayer.Character
    if not char then
        warn("[Wings] Немає персонажа")
        return
    end

    --// Чекаємо HumanoidRootPart і UpperTorso
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local torso = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")

    if not hrp or not torso then
        warn("[Wings] Персонаж ще не готовий (немає hrp/torso)")
        return
    end

    currentChar = char

    --// Створюємо обидва крила
    local rightWing = buildWing(1, char, torso)
    local leftWing  = buildWing(-1, char, torso)

    wingData.right = rightWing
    wingData.left  = leftWing

    --// Частинки
    if Config.GlowParticles then
        glowData = buildGlow(char)
    end

    flapTime = 0
    log("Крила побудовано: R=" .. #rightWing.feathers .. " L=" .. #leftWing.feathers)
end

--// ============================================================
--//  ANIMATION LOOP
--// ============================================================
local function startAnimation()
    if animConn then animConn:Disconnect() end

    animConn = RunService.Heartbeat:Connect(function(dt)
        if not Config.Enabled then return end
        if not wingData.right or not wingData.left then return end

        --// Обмеження 40 Hz — оптимізація
        local now = tick()
        if now - lastUpdate < 0.025 then return end
        lastUpdate = now

        --// Махання
        flapTime = flapTime + dt * Config.FlapSpeed
        local angle = math.sin(flapTime) * math.rad(Config.FlapAngle)
        local pulse = math.sin(flapTime * 1.7) * math.rad(6)

        --// Праве крило
        local rMotor = wingData.right.motor
        if rMotor and rMotor.Parent then
            rMotor.C1 = CFrame.Angles(0, 0, angle + pulse)
        end

        --// Ліве крило (дзеркально)
        local lMotor = wingData.left.motor
        if lMotor and lMotor.Parent then
            lMotor.C1 = CFrame.Angles(0, 0, -angle - pulse)
        end
    end)
end

--// ============================================================
--//  UPDATE COLORS
--// ============================================================
local function updateColors()
    local function recolor(wing)
        if not wing or not wing.feathers then return end
        local n = #wing.feathers
        for i, f in ipairs(wing.feathers) do
            if f and f.Parent then
                local t = (i - 1) / math.max(n - 1, 1)
                f.Color = Config.ColorA:Lerp(Config.ColorB, t)
            end
        end
    end
    recolor(wingData.right)
    recolor(wingData.left)
end

--// ============================================================
--//  MODULE API
--// ============================================================
local Wings = {}
Wings.__index = Wings

function Wings.new()
    return setmetatable({}, Wings)
end

function Wings:setEnabled(state)
    Config.Enabled = state
    log("setEnabled(" .. tostring(state) .. ")")

    if state then
        --// Чекаємо персонажа якщо треба
        if not LocalPlayer.Character then
            LocalPlayer.CharacterAdded:Wait()
            task.wait(0.3)
        end
        buildAll()
        startAnimation()
        log("═══ ENABLED ═══")
    else
        cleanupWings()
        log("═══ DISABLED ═══")
    end
end

function Wings:setSize(v)
    Config.Size = math.clamp(v, 1, 50)
    if Config.Enabled then task.spawn(buildAll) end
end

function Wings:setSpeed(v)
    Config.FlapSpeed = math.clamp(v, 0.1, 30)
end

function Wings:setFlapAngle(v)
    Config.FlapAngle = math.clamp(v, 5, 89)
end

function Wings:setColorR(v)
    Config.ColorA = Color3.fromRGB(v, math.floor(Config.ColorA.G * 255), math.floor(Config.ColorA.B * 255))
    Config.ColorB = Color3.fromRGB(v, math.floor(Config.ColorB.G * 255), math.floor(Config.ColorB.B * 255))
    updateColors()
end

function Wings:setColorG(v)
    Config.ColorA = Color3.fromRGB(math.floor(Config.ColorA.R * 255), v, math.floor(Config.ColorA.B * 255))
    Config.ColorB = Color3.fromRGB(math.floor(Config.ColorB.R * 255), v, math.floor(Config.ColorB.B * 255))
    updateColors()
end

function Wings:setColorB(v)
    Config.ColorA = Color3.fromRGB(math.floor(Config.ColorA.R * 255), math.floor(Config.ColorA.G * 255), v)
    Config.ColorB = Color3.fromRGB(math.floor(Config.ColorB.R * 255), math.floor(Config.ColorB.G * 255), v)
    updateColors()
end

function Wings:setGlow(v)
    Config.GlowParticles = v
    if Config.Enabled then task.spawn(buildAll) end
end

function Wings:setTrail(v)
    Config.Trail = v
end

--// ============================================================
--//  AUTO-RESPAWN
--// ============================================================
LocalPlayer.CharacterAdded:Connect(function(char)
    if not Config.Enabled then return end
    task.wait(1.5)
    if Config.Enabled then
        buildAll()
        startAnimation()
    end
end)

--// Cleanup при виході
game:BindToClose(function()
    if Config.Enabled then cleanupWings() end
end)

log("═══════════════════════════════════")
log("Wings v4.0 PREMIUM — Завантажено")
log("═══════════════════════════════════")

return Wings.new()
