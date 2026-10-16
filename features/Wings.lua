--// ============================================================
--// TrustHub Wings v5.1 — повна версія
--// ============================================================
--// Виправлено проти v4.0:
--//   1. Мах: Y = помах вперед-назад, Z = підйом кінчика (симетрично!)
--//      Було CFrame.Angles(0,0,angle) з протилежними знаками —
--//      одне крило вгору, друге вниз.
--//   2. Кріплення: +X — ліва рука, тому X = +0.55 * side
--//   3. Колір: 3 числа на канал, один apply. Канали більше не збиваються.
--//   4. setSize міняє розмір НА МІСЦІ (було Destroy+rebuild на кожен драг)
--//   5. Trail реалізовано
--//   6. Мах залежить від стану Humanoid (політ = розкриті, земля = підібрані)
--//   7. Прибирання одним Folder:Destroy замість скану імен
--//   8. Чекаємо персонажа циклом, а не task.wait(1.5)
--// ============================================================

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer

--// ============================================================
--//  CONFIG
--// ============================================================

local Config = {
    Enabled      = false,
    Size         = 8,
    FlapSpeed    = 4,
    FlapAngle    = 50,
    Spread       = 1,
    NumFeathers  = 6,
    Transparency = 0.1,
    Material     = Enum.Material.Neon,

    ColorA = {R = 255, G = 255, B = 255},   -- біля кореня
    ColorB = {R = 191, G = 217, B = 255},   -- кінчик
    TintB  = 0.75,

    GlowParticles = true,
    GlowRate      = 10,
    Trail         = false,
}

local FOLDER_NAME = "TrustHubWings"

--// ============================================================
--//  STATE
--// ============================================================

local State = {
    conn      = nil,
    folder    = nil,
    wings     = {},
    flapTime  = 0,
    geomSig   = "",
    respawn   = nil,
}

--// оголошуємо ДО функцій, які їх читають
local spread       = 0.6
local targetSpread = 1

local function log(msg)
    print("[Wings] " .. tostring(msg))
end

--// ============================================================
--//  COLOR
--// ============================================================

local function colorA3()
    local c = Config.ColorA
    return Color3.fromRGB(math.floor(c.R + 0.5), math.floor(c.G + 0.5), math.floor(c.B + 0.5))
end

local function colorB3()
    local c = Config.ColorB
    return Color3.fromRGB(math.floor(c.R + 0.5), math.floor(c.G + 0.5), math.floor(c.B + 0.5))
end

--// кінчик = основа * TintB, тому обидва кінці рухаються разом
local function syncTintB()
    local c = Config.ColorA
    Config.ColorB = {
        R = c.R * Config.TintB,
        G = c.G * Config.TintB,
        B = c.B * Config.TintB,
    }
end

--// ============================================================
--//  CLEANUP
--// ============================================================

local function cleanup()
    if State.conn then
        State.conn:Disconnect()
        State.conn = nil
    end

    if State.folder then
        pcall(function() State.folder:Destroy() end)
        State.folder = nil
    end

    --// сироти від попередніх запусків / респавнів
    local char = LocalPlayer.Character
    if char then
        for _, c in ipairs(char:GetChildren()) do
            if c.Name == FOLDER_NAME or c.Name == "TrustHubWingsAnchor" then
                pcall(function() c:Destroy() end)
            end
        end
    end

    State.wings    = {}
    State.flapTime = 0
    State.geomSig  = ""
end

--// ============================================================
--//  GEOMETRY
--// ============================================================

--// Чиста функція від Config: повертає розкладку пір'їв
local function layoutFeathers()
    local n    = math.max(1, math.floor(Config.NumFeathers))
    local size = Config.Size
    local out  = {}

    for i = 1, n do
        local t = (n > 1) and ((i - 1) / (n - 1)) or 0

        local len = size * (1 - t * 0.28)

        --// віяло: внутрішні майже вертикальні, зовнішні завалені
        local fan = math.rad(-58 + t * 78 * Config.Spread)

        local thick = math.max(0.06, size * 0.022)
        local width = size * (0.22 - t * 0.05)

        out[i] = {
            t     = t,
            len   = len,
            size  = Vector3.new(thick, len, width),
            hinge = CFrame.Angles(0, 0, fan),
        }
    end

    return out
end

--// Кількість пір'їв вимагає нового набору частин; решта — ні
local function geometrySignature()
    return tostring(math.floor(Config.NumFeathers))
end

local function getTorso(char)
    return char:FindFirstChild("UpperTorso")
        or char:FindFirstChild("Torso")
        or char:FindFirstChild("LowerTorso")
end

--// ============================================================
--//  BUILD
--// ============================================================

local function buildWing(side, parent, torso)
    --// side: 1 = права рука, -1 = ліва
    --// У Roblox +X — ЛІВА рука, +Z — НАЗАД від персонажа.
    local root = Instance.new("Part")
    root.Name = "TrustHubWingRoot_" .. (side == 1 and "R" or "L")
    root.Size = Vector3.new(0.1, 0.1, 0.1)
    root.Transparency = 1
    root.CanCollide = false
    root.CanQuery = false
    root.CanTouch = false
    root.CastShadow = false
    root.Massless = true
    root.Anchored = false
    root.Parent = parent

    local motor = Instance.new("Motor6D")
    motor.Name = "TrustHubWingMotor_" .. (side == 1 and "R" or "L")
    motor.Part0 = torso
    motor.Part1 = root
    --// +X = у бік, +Y = рівень лопаток, +Z = назад за спину
    motor.C0 = CFrame.new(0.55 * side, 0.55, 0.45)
    motor.C1 = CFrame.new(0, 0, 0)
    motor.Parent = root

    local wing = {
        side     = side,
        root     = root,
        motor    = motor,
        blades   = {},
        feathers = {},
        trailAtt = nil,
    }

    local layout = layoutFeathers()
    local a, b = colorA3(), colorB3()

    for i, item in ipairs(layout) do
        --// blade — невидимий кістяк, який рухає шарнір
        local blade = Instance.new("Part")
        blade.Name = "TrustHubWingBlade_" .. i
        blade.Size = Vector3.new(item.size.X, item.size.X, item.size.X)
        blade.Transparency = 1
        blade.CanCollide = false
        blade.CanQuery = false
        blade.CanTouch = false
        blade.CastShadow = false
        blade.Massless = true
        blade.Anchored = false
        blade.Parent = parent

        --// видиме перо
        local feather = Instance.new("Part")
        feather.Name = "TrustHubFeather"
        feather.Size = item.size
        feather.Color = a:Lerp(b, item.t)
        feather.Material = Config.Material
        feather.Transparency = Config.Transparency
        feather.CanCollide = false
        feather.CanQuery = false
        feather.CanTouch = false
        feather.CastShadow = false
        feather.Massless = true
        feather.Anchored = false
        feather.Parent = parent

        local weld = Instance.new("Weld")
        weld.Name = "TrustHubFeatherWeld"
        weld.Part0 = blade
        weld.Part1 = feather
        weld.C0 = CFrame.new(0, -item.len / 2, 0)
        weld.Parent = feather

        local hinge = Instance.new("Motor6D")
        hinge.Name = "TrustHubHinge_" .. i
        hinge.Part0 = root
        hinge.Part1 = blade
        hinge.C0 = item.hinge
        hinge.C1 = CFrame.new(0, 0, 0)
        hinge.Parent = blade

        wing.blades[i] = {
            hinge = hinge,
            part  = feather,
            base  = item.hinge,
            t     = item.t,
            len   = item.len,
        }
        wing.feathers[i] = feather
    end

    --// точки для Trail
    local attIn = Instance.new("Attachment")
    attIn.Name = "TrustHubTrailIn"
    attIn.Position = Vector3.new(0, 0, 0)
    attIn.Parent = root

    local attOut = Instance.new("Attachment")
    attOut.Name = "TrustHubTrailOut"
    attOut.Position = Vector3.new(0, -layout[1].len / 2, 0)
    attOut.Parent = wing.feathers[1]

    wing.trailAtt = {attIn, attOut}

    --// світіння на кожному крилі — частинки летять від крил, не з центру тіла
    if Config.GlowParticles then
        local glowAtt = Instance.new("Attachment")
        glowAtt.Name = "TrustHubGlowAtt"
        glowAtt.Parent = root

        local emitter = Instance.new("ParticleEmitter")
        emitter.Name = "TrustHubGlowEmitter"
        emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
        emitter.Color = ColorSequence.new(a, b)
        emitter.Size = NumberSequence.new({
            NumberSequenceKeypoint.new(0, Config.Size * 0.02),
            NumberSequenceKeypoint.new(0.5, Config.Size * 0.05),
            NumberSequenceKeypoint.new(1, 0),
        })
        emitter.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.35),
            NumberSequenceKeypoint.new(1, 1),
        })
        emitter.Lifetime = NumberRange.new(0.7, 1.4)
        emitter.Rate = Config.GlowRate
        emitter.Speed = NumberRange.new(0.5, 1.5)
        emitter.SpreadAngle = Vector2.new(180, 180)
        emitter.LightEmission = 1
        emitter.LightInfluence = 0
        emitter.Acceleration = Vector3.new(0, 1.5, 0)
        emitter.Parent = glowAtt

        wing.glow = {attachment = glowAtt, emitter = emitter}
    end

    --// Trail
    if Config.Trail then
        local trail = Instance.new("Trail")
        trail.Name = "TrustHubTrail"
        trail.Attachment0 = attIn
        trail.Attachment1 = attOut
        trail.Color = ColorSequence.new(a, b)
        trail.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.5),
            NumberSequenceKeypoint.new(1, 1),
        })
        trail.Lifetime = 0.35
        trail.MinLength = 0
        trail.FaceCamera = true
        trail.LightEmission = 1
        trail.Parent = root
        wing.trail = trail
    end

    return wing
end

local function buildAll()
    cleanup()

    local char = LocalPlayer.Character
    if not char then return false end

    local hrp   = char:FindFirstChild("HumanoidRootPart")
    local torso = getTorso(char)
    if not hrp or not torso then return false end

    --// Folder: прибирання стає одним Destroy
    local folder = Instance.new("Folder")
    folder.Name = FOLDER_NAME
    folder.Parent = char
    State.folder = folder

    --// якір: тримає крила в одній збірці з персонажем
    local anchor = Instance.new("Part")
    anchor.Name = "TrustHubWingsAnchor"
    anchor.Size = Vector3.new(0.1, 0.1, 0.1)
    anchor.Transparency = 1
    anchor.CanCollide = false
    anchor.CanQuery = false
    anchor.CanTouch = false
    anchor.CastShadow = false
    anchor.Massless = true
    anchor.Anchored = false
    anchor.Parent = char

    local anchorMotor = Instance.new("Motor6D")
    anchorMotor.Name = "TrustHubAnchorMotor"
    anchorMotor.Part0 = hrp
    anchorMotor.Part1 = anchor
    anchorMotor.Parent = anchor

    State.wings.right = buildWing(1, anchor, torso)
    State.wings.left  = buildWing(-1, anchor, torso)

    State.geomSig  = geometrySignature()
    State.flapTime = 0
    spread         = 0.6

    log(("Побудовано: %d пір'їв/крило, size=%.1f"):format(Config.NumFeathers, Config.Size))
    return true
end

--// ============================================================
--//  IN-PLACE UPDATES
--// ============================================================

local function applyGeometry()
    local layout = layoutFeathers()

    for _, wing in pairs(State.wings) do
        if wing and wing.blades then
            for i, blade in ipairs(wing.blades) do
                local item = layout[i]
                if item then
                    blade.base = item.hinge
                    blade.t    = item.t
                    blade.len  = item.len

                    if blade.part and blade.part.Parent then
                        blade.part.Size = item.size
                    end
                    if blade.hinge and blade.hinge.Parent then
                        blade.hinge.C0 = item.hinge
                    end
                end
            end
        end
    end

    State.geomSig = geometrySignature()
end

local function applyColors()
    local a, b = colorA3(), colorB3()

    for _, wing in pairs(State.wings) do
        if wing then
            for _, blade in ipairs(wing.blades or {}) do
                if blade.part and blade.part.Parent then
                    blade.part.Color = a:Lerp(b, blade.t or 0)
                end
            end
            if wing.glow and wing.glow.emitter then
                wing.glow.emitter.Color = ColorSequence.new(a, b)
            end
            if wing.trail then
                wing.trail.Color = ColorSequence.new(a, b)
            end
        end
    end
end

--// ============================================================
--//  ANIMATION
--// ============================================================

local function humanoidState(char)
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hum then return nil end
    return hum:GetState()
end

local function startAnimation()
    if State.conn then State.conn:Disconnect() end

    State.conn = RunService.RenderStepped:Connect(function(dt)
        if not Config.Enabled then return end
        if not State.wings.right or not State.wings.left then return end

        --// після лага один кадр не має стрибати на пів секунди
        dt = math.min(dt, 0.1)

        --// цільова розкритість за станом персонажа
        local st = humanoidState(LocalPlayer.Character)
        if st == Enum.HumanoidStateType.Freefall
            or st == Enum.HumanoidStateType.Flying
            or st == Enum.HumanoidStateType.Swimming
            or st == Enum.HumanoidStateType.Jumping then
            targetSpread = 1
        elseif st == Enum.HumanoidStateType.Landed
            or st == Enum.HumanoidStateType.Running
            or st == Enum.HumanoidStateType.RunningNoPhysics then
            targetSpread = 0.82
        else
            targetSpread = 0.9
        end

        spread = spread + (targetSpread - spread) * math.min(dt * 5, 1)

        --// ГОЛОВНЕ: мах
        State.flapTime = State.flapTime + dt * Config.FlapSpeed
        local flap = math.sin(State.flapTime) * math.rad(Config.FlapAngle)

        --// хвиля із запізненням — проходить по крилу
        local wave = math.sin(State.flapTime - 0.4) * math.rad(Config.FlapAngle) * 0.25

        for _, wing in pairs(State.wings) do
            local side = wing.side

            if wing.motor and wing.motor.Parent then
                --// Y: кінчик іде вперед-назад (дзеркально)
                --// Z: кінчик піднімається-опускається
                --//    БЕЗ * side — інакше одне крило вгору, друге вниз
                wing.motor.C1 = CFrame.Angles(
                    math.rad(-3) * spread,
                    flap * side * spread,
                    flap * 0.6 * spread
                )
            end

            for i, blade in ipairs(wing.blades or {}) do
                local hinge = blade.hinge
                if hinge and hinge.Parent then
                    --// пера розкриваються/складаються + другорядний мах
                    local openT  = math.rad(18) * (1 - spread) * (blade.t or 0)
                    local fanOff = side * (flap * 0.35 * spread + wave * (blade.t or 0))
                    hinge.C0 = blade.base * CFrame.Angles(0, 0, fanOff + openT)
                end
            end
        end
    end)
end

--// ============================================================
--//  MODULE
--// ============================================================

local Wings = {}
Wings.__index = Wings

local function isReady()
    local char = LocalPlayer.Character
    if not char then return false end
    return char:FindFirstChild("HumanoidRootPart") ~= nil and getTorso(char) ~= nil
end

local function waitForCharacter(timeout)
    timeout = timeout or 8
    local t = 0
    while t < timeout do
        if not Config.Enabled then return false end
        if isReady() then return true end
        task.wait(0.1)
        t = t + 0.1
    end
    return false
end

function Wings:setEnabled(state)
    state = not not state
    Config.Enabled = state
    log("setEnabled(" .. tostring(state) .. ")")

    if state then
        if not waitForCharacter() then
            warn("[Wings] персонаж не з'явився за 8с")
            return
        end
        if not buildAll() then
            warn("[Wings] не вдалось побудувати крила")
            return
        end
        startAnimation()
    else
        cleanup()
    end
end

--// setSize тепер НЕ перебудовує частини
function Wings:setSize(v)
    Config.Size = math.clamp(tonumber(v) or Config.Size, 1, 50)
    if not Config.Enabled then return end

    if geometrySignature() == State.geomSig then
        applyGeometry()
    else
        task.spawn(function()
            if not Config.Enabled then return end
            if buildAll() then startAnimation() end
        end)
    end
end

function Wings:setSpeed(v)
    Config.FlapSpeed = math.clamp(tonumber(v) or Config.FlapSpeed, 0, 30)
end

function Wings:setFlapAngle(v)
    Config.FlapAngle = math.clamp(tonumber(v) or Config.FlapAngle, 5, 89)
end

function Wings:setSpread(v)
    Config.Spread = math.clamp(tonumber(v) or Config.Spread, 0.3, 2)
    if Config.Enabled then applyGeometry() end
end

function Wings:setFeathers(v)
    Config.NumFeathers = math.clamp(math.floor(tonumber(v) or Config.NumFeathers), 2, 16)
    if Config.Enabled then
        task.spawn(function()
            if not Config.Enabled then return end
            if buildAll() then startAnimation() end
        end)
    end
end

--// Колір: міняємо ОДИН канал, решту беремо з Config.ColorA.
--// У v4.0 R/G/B читались із двох різних Color3 — канали збивались.
local function setChannel(channel, v)
    v = math.clamp(tonumber(v) or 0, 0, 255)
    Config.ColorA[channel] = v
    syncTintB()
    applyColors()
end

function Wings:setColorR(v) setChannel("R", v) end
function Wings:setColorG(v) setChannel("G", v) end
function Wings:setColorB(v) setChannel("B", v) end

function Wings:setColor(color)
    if typeof(color) ~= "Color3" then return end
    Config.ColorA = {R = color.R * 255, G = color.G * 255, B = color.B * 255}
    syncTintB()
    applyColors()
end

function Wings:setTransparency(v)
    Config.Transparency = math.clamp(tonumber(v) or 0, 0, 1)
    for _, wing in pairs(State.wings) do
        for _, blade in ipairs((wing and wing.blades) or {}) do
            if blade.part and blade.part.Parent then
                blade.part.Transparency = Config.Transparency
            end
        end
    end
end

function Wings:setGlow(v)
    Config.GlowParticles = not not v
    if not Config.Enabled then return end

    for _, wing in pairs(State.wings) do
        if wing then
            if Config.GlowParticles and not wing.glow then
                local att = Instance.new("Attachment")
                att.Name = "TrustHubGlowAtt"
                att.Parent = wing.root

                local emitter = Instance.new("ParticleEmitter")
                emitter.Name = "TrustHubGlowEmitter"
                emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
                emitter.Color = ColorSequence.new(colorA3(), colorB3())
                emitter.Size = NumberSequence.new({
                    NumberSequenceKeypoint.new(0, Config.Size * 0.02),
                    NumberSequenceKeypoint.new(0.5, Config.Size * 0.05),
                    NumberSequenceKeypoint.new(1, 0),
                })
                emitter.Transparency = NumberSequence.new({
                    NumberSequenceKeypoint.new(0, 0.35),
                    NumberSequenceKeypoint.new(1, 1),
                })
                emitter.Lifetime = NumberRange.new(0.7, 1.4)
                emitter.Rate = Config.GlowRate
                emitter.Speed = NumberRange.new(0.5, 1.5)
                emitter.SpreadAngle = Vector2.new(180, 180)
                emitter.LightEmission = 1
                emitter.LightInfluence = 0
                emitter.Parent = att
                wing.glow = {attachment = att, emitter = emitter}
            elseif not Config.GlowParticles and wing.glow then
                if wing.glow.emitter then wing.glow.emitter.Enabled = false end
                wing.glow = nil
            end
        end
    end
end

function Wings:setTrail(v)
    Config.Trail = not not v
    if not Config.Enabled then return end

    for _, wing in pairs(State.wings) do
        if wing and wing.trailAtt then
            if Config.Trail and not wing.trail then
                local attIn, attOut = wing.trailAtt[1], wing.trailAtt[2]
                if attIn and attOut and attIn.Parent and attOut.Parent then
                    local trail = Instance.new("Trail")
                    trail.Name = "TrustHubTrail"
                    trail.Attachment0 = attIn
                    trail.Attachment1 = attOut
                    trail.Color = ColorSequence.new(colorA3(), colorB3())
                    trail.Transparency = NumberSequence.new({
                        NumberSequenceKeypoint.new(0, 0.5),
                        NumberSequenceKeypoint.new(1, 1),
                    })
                    trail.Lifetime = 0.35
                    trail.MinLength = 0
                    trail.FaceCamera = true
                    trail.LightEmission = 1
                    trail.Parent = wing.root
                    wing.trail = trail
                end
            elseif not Config.Trail and wing.trail then
                wing.trail:Destroy()
                wing.trail = nil
            end
        end
    end
end

function Wings:isEnabled()
    return Config.Enabled
end

function Wings:destroy()
    Config.Enabled = false
    cleanup()
    if State.respawn then
        State.respawn:Disconnect()
        State.respawn = nil
    end
end

--// ============================================================
--//  AUTO-RESPAWN
--// ============================================================

if State.respawn then State.respawn:Disconnect() end
State.respawn = LocalPlayer.CharacterAdded:Connect(function()
    if not Config.Enabled then return end
    if not waitForCharacter(10) then return end
    if not Config.Enabled then return end
    if not buildAll() then return end
    startAnimation()
end)

log("Wings v5.1 — Завантажено")

return Wings.new()
