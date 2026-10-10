--// ============================================================
--// TrustHub Animated Wings v3.0 — PREMIUM
--// Градієнт • Частинки • Trail • 5 стилів • Багатошарова анімація
--// ============================================================

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local LocalPlayer = Players.LocalPlayer

--// ============================================================
--//  CONFIG
--// ============================================================
local Config = {
    Enabled     = false,
    Size        = 8,            -- довжина крила
    FlapSpeed   = 3,            -- швидкість махання
    FlapAngle   = 50,           -- максимальний кут
    Style       = "Angel",      -- Angel | Demon | Dragon | Butterfly | Energy
    ColorA      = Color3.fromRGB(255, 255, 255),  -- основний
    ColorB      = Color3.fromRGB(180, 220, 255),  -- градієнт
    Glow        = true,         -- частинки навколо
    Trail       = true,         -- trail за кінчиками
    NumFeathers = 8,            -- пір'їн на крило
    Transparency = 0.1,
}

--// ============================================================
--//  STYLES — різні форми крил
--// ============================================================
local STYLES = {
    Angel     = { spread = 22,  curve = 1.2, taper = 0.10, angleBase = -60 },
    Demon     = { spread = 25,  curve = 0.6, taper = 0.18, angleBase = -75 },
    Dragon    = { spread = 30,  curve = 0.4, taper = 0.22, angleBase = -85 },
    Butterfly = { spread = 15,  curve = 1.8, taper = 0.05, angleBase = -40 },
    Energy    = { spread = 35,  curve = 1.5, taper = 0.08, angleBase = -55 },
}

--// ============================================================
--//  STATE
--// ============================================================
local wings      = { right = nil, left = nil }
local animConn   = nil
local glowConn   = nil
local flapTime   = 0
local lastUpdate = 0

local function log(msg) print("[Wings] " .. tostring(msg)) end

--// ============================================================
--//  BUILD WING
--// ============================================================
local function buildWing(side)
    local char = LocalPlayer.Character
    if not char then return nil end
    local torso = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")
    if not torso then return nil end

    local style = STYLES[Config.Style] or STYLES.Angel

    --// Root (невидима, кріпиться до спини)
    local root = Instance.new("Part")
    root.Name = "TrustHub_WingRoot_" .. (side == 1 and "R" or "L")
    root.Size = Vector3.new(0.1, 0.1, 0.1)
    root.Transparency = 1
    root.CanCollide = false
    root.CanQuery = false
    root.CanTouch = false
    root.Massless = true
    root.Anchored = false
    root.CastShadow = false
    root.Parent = char

    local motor = Instance.new("Motor6D")
    motor.Name = "TrustHub_WingMotor_" .. (side == 1 and "R" or "L")
    motor.Part0 = torso
    motor.Part1 = root
    motor.C0 = CFrame.new(0.65 * -side, 0.6, 0.6) * CFrame.Angles(0, 0, math.rad(20 * -side))
    motor.C1 = CFrame.new(0, 0, 0)
    motor.Parent = root

    --// Пір'я з градієнтом
    local feathers = {}
    local n = Config.NumFeathers

    for i = 1, n do
        local t = (i - 1) / math.max(n - 1, 1)   -- 0 → 1

        --// Довжина: від довгого до короткого
        local length = Config.Size * (1 - t * style.taper)

        --// Кут: розкидаються віялом
        local angle = math.rad(style.angleBase + (i - 1) * style.spread) * side

        --// Позиція: зміщується від кореня
        local offset = Vector3.new(0, -length / 2 - (i - 1) * 0.15, t * 0.3 * style.curve)

        --// Колір: градієнт від ColorA (біля кореня) до ColorB (кінчик)
        local featherColor = Config.ColorA:Lerp(Config.ColorB, t)

        local feather = Instance.new("Part")
        feather.Name = "TrustHub_Feather"
        feather.Size = Vector3.new(0.12, length, Config.Size * 0.18)
        feather.Color = featherColor
        feather.Material = Enum.Material.Neon
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

        --// Decal для м'якшого вигляду
        if Config.Style == "Angel" or Config.Style == "Energy" then
            local mesh = Instance.new("SpecialMesh")
            mesh.MeshType = Enum.MeshType.FileMesh
            mesh.MeshId = "rbxassetid://1033714"  -- тонкий шпиль
            mesh.Scale = Vector3.new(0.3, length / 3, 0.3)
            mesh.Parent = feather
        end

        table.insert(feathers, feather)
    end

    --// TRAIL на кінчику (додатково)
    local trail = nil
    local trailAttach0 = nil
    local trailAttach1 = nil
    if Config.Trail and #feathers > 0 then
        trailAttach0 = Instance.new("Attachment")
        trailAttach0.Name = "TrailAttach0"
        trailAttach0.Position = Vector3.new(0, 0, 0)
        trailAttach0.Parent = feathers[1]

        trailAttach1 = Instance.new("Attachment")
        trailAttach1.Name = "TrailAttach1"
        trailAttach1.Position = Vector3.new(0, feathers[1].Size.Y * 0.4, 0)
        trailAttach1.Parent = feathers[1]

        trail = Instance.new("Trail")
        trail.Name = "TrustHub_Trail"
        trail.Attachment0 = trailAttach0
        trail.Attachment1 = trailAttach1
        trail.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Config.ColorA),
            ColorSequenceKeypoint.new(1, Config.ColorB),
        })
        trail.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.2),
            NumberSequenceKeypoint.new(1, 1),
        })
        trail.Lifetime = 0.6
        trail.LightEmission = 0.8
        trail.LightInfluence = 0
        trail.MinLength = 0.1
        trail.Enabled = true
        trail.Parent = feathers[1]
    end

    return {
        root = root,
        motor = motor,
        feathers = feathers,
        trail = trail,
    }
end

--// ============================================================
--//  GLOW PARTICLES (навколо персонажа)
--// ============================================================
local function createGlowParticles()
    local char = LocalPlayer.Character
    if not char then return nil end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end

    local attachment = Instance.new("Attachment")
    attachment.Name = "TrustHub_GlowAttachment"
    attachment.Position = Vector3.new(0, 0.5, 0)
    attachment.Parent = hrp

    local emitter = Instance.new("ParticleEmitter")
    emitter.Name = "TrustHub_GlowEmitter"
    emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
    emitter.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Config.ColorA),
        ColorSequenceKeypoint.new(1, Config.ColorB),
    })
    emitter.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.3),
        NumberSequenceKeypoint.new(0.5, 0.6),
        NumberSequenceKeypoint.new(1, 0),
    })
    emitter.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.3),
        NumberSequenceKeypoint.new(1, 1),
    })
    emitter.Lifetime = NumberRange.new(0.8, 1.5)
    emitter.Rate = 25
    emitter.Speed = NumberRange.new(1, 3)
    emitter.SpreadAngle = Vector2.new(180, 180)
    emitter.Rotation = NumberRange.new(0, 360)
    emitter.RotSpeed = NumberRange.new(-90, 90)
    emitter.LightEmission = 1
    emitter.LightInfluence = 0
    emitter.Acceleration = Vector3.new(0, 3, 0)
    emitter.Parent = attachment

    return { attachment = attachment, emitter = emitter }
end

--// ============================================================
--//  DESTROY
--// ============================================================
local function destroyWings()
    local char = LocalPlayer.Character
    if not char then return end

    for _, child in ipairs(char:GetChildren()) do
        local n = child.Name
        if n == "TrustHub_WingRoot_R"
            or n == "TrustHub_WingRoot_L"
            or n == "TrustHub_Feather"
            or n == "TrustHub_GlowAttachment" then
            pcall(function() child:Destroy() end)
        end
    end

    wings.right = nil
    wings.left  = nil
end

--// ============================================================
--//  ANIMATION LOOP
--// ============================================================
local function startAnimation()
    if animConn then animConn:Disconnect() end

    animConn = RunService.Heartbeat:Connect(function(dt)
        if not Config.Enabled then return end
        if not wings.right or not wings.left then return end

        --// Обмеження 40 FPS для анімації (достатньо і не лагає)
        local now = tick()
        if now - lastUpdate < 0.025 then return end
        lastUpdate = now

        flapTime = flapTime + dt * Config.FlapSpeed

        --// Основне махання
        local angle = math.sin(flapTime) * math.rad(Config.FlapAngle)

        --// Додаткова "пульсація" (друга хвиля з різницею фаз)
        local pulse = math.sin(flapTime * 1.7) * math.rad(8)

        --// Застосовуємо до моторів (тільки C1 — легше)
        if wings.right.motor and wings.right.motor.Parent then
            wings.right.motor.C1 = CFrame.Angles(0, 0, angle + pulse)
        end
        if wings.left.motor and wings.left.motor.Parent then
            wings.left.motor.C1 = CFrame.Angles(0, 0, -angle - pulse)
        end

        --// Додаткова анімація для Energy стилю — "мерехтіння"
        if Config.Style == "Energy" then
            local glow = 0.5 + math.sin(flapTime * 2) * 0.3
            for _, side in ipairs({"right", "left"}) do
                local w = wings[side]
                if w and w.feathers then
                    for _, f in ipairs(w.feathers) do
                        if f and f.Parent then
                            f.Transparency = Config.Transparency + (1 - glow) * 0.3
                        end
                    end
                end
            end
        end
    end)
end

--// ============================================================
--//  ATTACH
--// ============================================================
local function attach()
    destroyWings()
    task.wait(0.2)

    local char = LocalPlayer.Character
    if not char then return end

    wings.right = buildWing(1)
    wings.left  = buildWing(-1)

    --// Glow частинки
    if Config.Glow then
        createGlowParticles()
    end

    flapTime = 0
    startAnimation()
    log("Крила прикріплено (стиль: " .. Config.Style .. ", розмір: " .. Config.Size .. ")")
end

--// ============================================================
--//  UPDATE COLORS
--// ============================================================
local function updateColors()
    for _, side in ipairs({"right", "left"}) do
        local w = wings[side]
        if w and w.feathers then
            local n = #w.feathers
            for i, f in ipairs(w.feathers) do
                if f and f.Parent then
                    local t = (i - 1) / math.max(n - 1, 1)
                    f.Color = Config.ColorA:Lerp(Config.ColorB, t)
                end
            end
            if w.trail then
                w.trail.Color = ColorSequence.new({
                    ColorSequenceKeypoint.new(0, Config.ColorA),
                    ColorSequenceKeypoint.new(1, Config.ColorB),
                })
            end
        end
    end
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
    if state then
        attach()
        log("═══ ENABLED ═══")
    else
        if animConn then animConn:Disconnect(); animConn = nil end
        destroyWings()
        log("═══ DISABLED ═══")
    end
end

function Wings:setSize(v) Config.Size = v; if Config.Enabled then attach() end end
function Wings:setSpeed(v) Config.FlapSpeed = v end
function Wings:setFlapAngle(v) Config.FlapAngle = v end
function Wings:setStyle(name) Config.Style = name; if Config.Enabled then attach() end end
function Wings:setNumFeathers(v) Config.NumFeathers = v; if Config.Enabled then attach() end end

function Wings:setColorR(v)
    Config.ColorA = Color3.fromRGB(v, Config.ColorA.G * 255, Config.ColorA.B * 255)
    updateColors()
end
function Wings:setColorG(v)
    Config.ColorA = Color3.fromRGB(Config.ColorA.R * 255, v, Config.ColorA.B * 255)
    updateColors()
end
function Wings:setColorB(v)
    Config.ColorA = Color3.fromRGB(Config.ColorA.R * 255, Config.ColorA.G * 255, v)
    updateColors()
end

--// Сумісність із UI
function Wings:setGlow(v) Config.Glow = v; if Config.Enabled then attach() end end
function Wings:setTrail(v) Config.Trail = v; if Config.Enabled then attach() end end

--// ============================================================
--//  AUTO-RESPAWN
--// ============================================================
LocalPlayer.CharacterAdded:Connect(function()
    if Config.Enabled then
        task.wait(1.2)
        attach()
    end
end)

game:BindToClose(function()
    if Config.Enabled then destroyWings() end
end)

log("═══════════════════════════════════")
log("TrustHub Wings v3.0 PREMIUM")
log("Angel • Demon • Dragon • Butterfly • Energy")
log("═══════════════════════════════════")

return Wings.new()
