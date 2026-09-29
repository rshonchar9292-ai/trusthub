--// ╔══════════════════════════════════════════════════════════════╗
--// ║  TrustHub Anti-Fling — 3 Methods Edition                     ║
--// ║  Based on Fleece's Utility Panel                             ║
--// ╚══════════════════════════════════════════════════════════════╝

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")

local LocalPlayer = Players.LocalPlayer

--// ============================================================
--//  CONFIG
--// ============================================================
local Config = {
    Enabled   = false,
    Method    = "clamp",  -- clamp | spinlock | massive
    Limit     = 220,
    LogEnabled = true,
}

--// ============================================================
--//  STATE
--// ============================================================
local connections = {}
local enabled = false
local savedPhysical = nil

local function log(msg)
    if Config.LogEnabled then print("[AntiFling] " .. msg) end
end

local function getChar()
    local char = LocalPlayer.Character
    if not char then return nil end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hum or not hrp then return nil end
    if hum.Health <= 0 then return nil end
    return char, hum, hrp
end

local function isFinite(v)
    return v == v and v ~= math.huge and v ~= -math.huge
end

local function cleanup()
    for _, conn in ipairs(connections) do
        pcall(function() conn:Disconnect() end)
    end
    connections = {}

    -- Відновлюємо CustomPhysicalProperties
    if savedPhysical then
        local char = LocalPlayer.Character
        if char then
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if hrp then
                pcall(function()
                    hrp.CustomPhysicalProperties = savedPhysical
                end)
            end
        end
        savedPhysical = nil
    end
end

--// ============================================================
--//  METHOD 1: Clamp (Limit Your Speed)
--// ============================================================
local function methodClamp()
    local conn = RunService.Heartbeat:Connect(function()
        if not enabled then return end
        local char, hum, hrp = getChar()
        if not hrp then return end

        local v = hrp.AssemblyLinearVelocity
        if v.Magnitude > Config.Limit and isFinite(v.Magnitude) then
            hrp.AssemblyLinearVelocity = v.Unit * Config.Limit
        end

        if hrp.AssemblyAngularVelocity.Magnitude > 30 then
            hrp.AssemblyAngularVelocity = Vector3.zero
        end
    end)
    table.insert(connections, conn)

    log("Clamp method started (limit: " .. Config.Limit .. ")")
    return true
end

--// ============================================================
--//  METHOD 2: Spinlock (Stop Spinning Only)
--// ============================================================
local function methodSpinlock()
    local conn = RunService.Stepped:Connect(function()
        if not enabled then return end
        local char, hum, hrp = getChar()
        if not hrp then return end

        hrp.AssemblyAngularVelocity = Vector3.zero
    end)
    table.insert(connections, conn)

    log("Spinlock method started")
    return true
end

--// ============================================================
--//  METHOD 3: Massive (Make Yourself Heavy)
--// ============================================================
local function methodMassive()
    local char, hum, hrp = getChar()
    if not hrp then return false end

    -- Зберігаємо оригінальні властивості
    savedPhysical = hrp.CustomPhysicalProperties

    pcall(function()
        hrp.CustomPhysicalProperties = PhysicalProperties.new(100, 0.3, 0.5, 1, 1)
    end)

    local conn = RunService.Heartbeat:Connect(function()
        if not enabled then return end
        local c, h, root = getChar()
        if not root then return end

        if root.AssemblyAngularVelocity.Magnitude > 25 then
            root.AssemblyAngularVelocity = Vector3.zero
        end
    end)
    table.insert(connections, conn)

    log("Massive method started")
    return true
end

--// ============================================================
--//  METHOD SELECTOR
--// ============================================================
local METHODS = {
    clamp     = methodClamp,
    spinlock  = methodSpinlock,
    massive   = methodMassive,
}

local function startMethod(name)
    local fn = METHODS[name] or METHODS.clamp
    local ok, err = pcall(fn)
    if not ok then
        warn("[AntiFling] Method " .. name .. " failed: " .. tostring(err))
        return false
    end
    return true
end

--// ============================================================
--//  MODULE
--// ============================================================
local AntiFling = {}
AntiFling.__index = AntiFling

function AntiFling.new()
    return setmetatable({}, AntiFling)
end

function AntiFling:setEnabled(state)
    enabled = state
    Config.Enabled = state

    if state then
        cleanup()
        startMethod(Config.Method)
        log("═══ Anti-Fling ENABLED (Method: " .. Config.Method .. ") ═══")
    else
        cleanup()
        log("Anti-Fling DISABLED")
    end
end

function AntiFling:setLimit(v)
    Config.Limit = v
    log("Limit: " .. v)
end

function AntiFling:setMethod(name)
    local wasEnabled = enabled
    if wasEnabled then
        self:setEnabled(false)
        task.wait(0.05)
    end
    Config.Method = name
    if wasEnabled then
        self:setEnabled(true)
    end
    log("Method: " .. name)
end

-- Stubs
function AntiFling:setSpeed() end
function AntiFling:setValue(v) Config.Limit = v end
function AntiFling:getMethod() return Config.Method end

-- Автоматичне перепідключення при респавні
LocalPlayer.CharacterAdded:Connect(function()
    if enabled then
        cleanup()
        task.wait(0.5)
        startMethod(Config.Method)
    end
end)

log("═══════════════════════════════")
log("TrustHub Anti-Fling loaded (3 methods)")
log("═══════════════════════════════")

return AntiFling.new()
