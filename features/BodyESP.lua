--// ============================================================
--// TrustHub Body ESP v2.0 — Transparent Body + Red Outline
--// Твоє тіло стає прозорим + червоний glow по контуру
--// ============================================================

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

--// ============================================================
--//  CONFIG
--// ============================================================
local Config = {
    Enabled          = false,

    --// Прозорість тіла
    BodyTransparency = 0.7,      -- 0 = видиме, 1 = невидиме (0.7 = сильно прозоре)

    --// Highlight (контур)
    UseHighlight     = true,
    OutlineColor     = Color3.fromRGB(255, 30, 30),   -- ЧЕРВОНИЙ контур
    FillColor        = Color3.fromRGB(255, 80, 80),    -- заповнення
    FillTransparency = 1,                              -- 1 = без заливки (тільки контур)
    OutlineTransparency = 0,                           -- 0 = яскравий контур

    --// Додатковий glow через PointLight
    UseGlow          = true,
    GlowColor        = Color3.fromRGB(255, 50, 50),
    GlowBrightness   = 3,
    GlowRange        = 12,

    --// Trail за тілом (опційно)
    UseTrail         = false,
    TrailColor       = Color3.fromRGB(255, 50, 50),
}

--// ============================================================
--//  STATE
--// ============================================================
local highlight   = nil
local glowLight   = nil
local trailAtt    = nil
local trailAtt2   = nil
local trail       = nil
local savedTransparency = {}     -- [part] = оригінальна прозорість
local transparencyConn = nil

local function log(msg) print("[BodyESP] " .. tostring(msg)) end

--// ============================================================
--//  APPLY TRANSPARENCY
--// ============================================================
local function applyTransparency()
    local char = LocalPlayer.Character
    if not char then return end

    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            --// Запам'ятовуємо оригінал
            if savedTransparency[part] == nil then
                savedTransparency[part] = part.Transparency
            end

            --// Пропускаємо невидимі частини (не чіпаємо)
            if savedTransparency[part] < 1 then
                part.Transparency = math.max(savedTransparency[part], Config.BodyTransparency)
                part.CastShadow = false
            end
        elseif part:IsA("Decal") or part:IsA("Texture") then
            if savedTransparency[part] == nil then
                savedTransparency[part] = part.Transparency
            end
            part.Transparency = math.max(savedTransparency[part], Config.BodyTransparency)
        end
    end
end

--// ============================================================
--//  RESTORE TRANSPARENCY
--// ============================================================
local function restoreTransparency()
    for part, orig in pairs(savedTransparency) do
        if part and part.Parent then
            pcall(function()
                part.Transparency = orig
            end)
        end
    end
    savedTransparency = {}
end

--// ============================================================
--//  CREATE HIGHLIGHT (червоний контур)
--// ============================================================
local function createHighlight()
    local char = LocalPlayer.Character
    if not char then return end

    if highlight then highlight:Destroy(); highlight = nil end

    highlight = Instance.new("Highlight")
    highlight.Name = "TrustHub_BodyESP"
    highlight.Adornee = char
    highlight.FillColor = Config.FillColor
    highlight.OutlineColor = Config.OutlineColor
    highlight.FillTransparency = Config.FillTransparency     -- 1 = тільки контур
    highlight.OutlineTransparency = Config.OutlineTransparency
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Parent = game:GetService("CoreGui")

    log("Highlight створено (червоний контур)")
end

--// ============================================================
--//  CREATE GLOW (PointLight)
--// ============================================================
local function createGlow()
    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    if glowLight then glowLight:Destroy(); glowLight = nil end

    local att = Instance.new("Attachment")
    att.Name = "TrustHub_GlowAtt"
    att.Position = Vector3.new(0, 0, 0)
    att.Parent = hrp

    glowLight = Instance.new("PointLight")
    glowLight.Name = "TrustHub_BodyGlow"
    glowLight.Color = Config.GlowColor
    glowLight.Brightness = Config.GlowBrightness
    glowLight.Range = Config.GlowRange
    glowLight.Shadows = false
    glowLight.Parent = att
end

--// ============================================================
--//  CREATE TRAIL
--// ============================================================
local function createTrail()
    if not Config.UseTrail then return end
    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    trailAtt = Instance.new("Attachment")
    trailAtt.Name = "TrustHub_TrailAtt0"
    trailAtt.Position = Vector3.new(0, 1, 0)
    trailAtt.Parent = hrp

    trailAtt2 = Instance.new("Attachment")
    trailAtt2.Name = "TrustHub_TrailAtt1"
    trailAtt2.Position = Vector3.new(0, -1, 0)
    trailAtt2.Parent = hrp

    trail = Instance.new("Trail")
    trail.Name = "TrustHub_BodyTrail"
    trail.Attachment0 = trailAtt
    trail.Attachment1 = trailAtt2
    trail.Color = ColorSequence.new(Config.TrailColor)
    trail.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.3),
        NumberSequenceKeypoint.new(1, 1),
    })
    trail.Lifetime = 0.4
    trail.LightEmission = 1
    trail.LightInfluence = 0
    trail.Parent = hrp
end

--// ============================================================
--//  DESTROY ALL
--// ============================================================
local function destroyAll()
    if highlight then highlight:Destroy(); highlight = nil end
    if glowLight then glowLight:Destroy(); glowLight = nil end
    if trail then trail:Destroy(); trail = nil end
    if trailAtt then trailAtt:Destroy(); trailAtt = nil end
    if trailAtt2 then trailAtt2:Destroy(); trailAtt2 = nil end
    restoreTransparency()
end

--// ============================================================
--//  START CONTINUOUS LOOP (перепризначає прозорість)
--// ============================================================
local function startLoop()
    if transparencyConn then transparencyConn:Disconnect() end
    transparencyConn = RunService.Heartbeat:Connect(function()
        if not Config.Enabled then return end
        applyTransparency()
    end)
end

local function stopLoop()
    if transparencyConn then transparencyConn:Disconnect(); transparencyConn = nil end
end

--// ============================================================
--//  APPLY (після зміни налаштувань)
--// ============================================================
local function applyAll()
    if not Config.Enabled then return end

    applyTransparency()

    if Config.UseHighlight then
        createHighlight()
    elseif highlight then
        highlight:Destroy(); highlight = nil
    end

    if Config.UseGlow then
        createGlow()
    elseif glowLight then
        glowLight:Destroy(); glowLight = nil
    end

    createTrail()
end

--// ============================================================
--//  MODULE API
--// ============================================================
local BodyESP = {}
BodyESP.__index = BodyESP

function BodyESP.new()
    return setmetatable({}, BodyESP)
end

function BodyESP:setEnabled(state)
    Config.Enabled = state

    if state then
        --// Чекаємо персонажа
        local char = LocalPlayer.Character
        if not char then
            LocalPlayer.CharacterAdded:Wait()
            task.wait(0.5)
        end

        applyTransparency()
        if Config.UseHighlight then createHighlight() end
        if Config.UseGlow then createGlow() end
        if Config.UseTrail then createTrail() end
        startLoop()
        log("═══ ENABLED (Transparency: " .. Config.BodyTransparency .. ") ═══")
    else
        stopLoop()
        destroyAll()
        log("═══ DISABLED ═══")
    end
end

--// ============================================================
--//  SETTERS
--// ============================================================
function BodyESP:setBodyTransparency(v)
    Config.BodyTransparency = math.clamp(v, 0, 1)
    if Config.Enabled then applyTransparency() end
end

function BodyESP:setOutlineColor(r, g, b)
    Config.OutlineColor = Color3.fromRGB(r, g, b)
    if highlight then highlight.OutlineColor = Config.OutlineColor end
end

function BodyESP:setFillColor(r, g, b)
    Config.FillColor = Color3.fromRGB(r, g, b)
    if highlight then highlight.FillColor = Config.FillColor end
end

function BodyESP:setFillTransparency(v)
    Config.FillTransparency = math.clamp(v, 0, 1)
    if highlight then highlight.FillTransparency = Config.FillTransparency end
end

--// Сумісність з існуючим UI (R/G/B + Fill)
function BodyESP:setColorR(v)
    Config.OutlineColor = Color3.fromRGB(v, Config.OutlineColor.G * 255, Config.OutlineColor.B * 255)
    Config.FillColor = Config.OutlineColor
    if highlight then
        highlight.OutlineColor = Config.OutlineColor
        highlight.FillColor = Config.FillColor
    end
end

function BodyESP:setColorG(v)
    Config.OutlineColor = Color3.fromRGB(Config.OutlineColor.R * 255, v, Config.OutlineColor.B * 255)
    Config.FillColor = Config.OutlineColor
    if highlight then
        highlight.OutlineColor = Config.OutlineColor
        highlight.FillColor = Config.FillColor
    end
end

function BodyESP:setColorB(v)
    Config.OutlineColor = Color3.fromRGB(Config.OutlineColor.R * 255, Config.OutlineColor.G * 255, v)
    Config.FillColor = Config.OutlineColor
    if highlight then
        highlight.OutlineColor = Config.OutlineColor
        highlight.FillColor = Config.FillColor
    end
end

function BodyESP:setFill(v)
    self:setFillTransparency(1 - v)
end

function BodyESP:setGlow(v) Config.UseGlow = v; if Config.Enabled then applyAll() end end
function BodyESP:setHighlight(v) Config.UseHighlight = v; if Config.Enabled then applyAll() end end
function BodyESP:setTrail(v) Config.UseTrail = v; if Config.Enabled then applyAll() end end

--// ============================================================
--//  АВТО-ВІДНОВЛЕННЯ ПРИ РЕСПАВНІ
--// ============================================================
LocalPlayer.CharacterAdded:Connect(function()
    if Config.Enabled then
        task.wait(0.8)
        applyAll()
        startLoop()
    end
end)

game:BindToClose(function()
    if Config.Enabled then
        stopLoop()
        destroyAll()
    end
end)

log("═══════════════════════════════════")
log("TrustHub Body ESP v2.0")
log("Transparent body + Red outline")
log("═══════════════════════════════════")

return BodyESP.new()
