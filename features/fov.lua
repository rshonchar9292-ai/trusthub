--// ╔══════════════════════════════════════════════════════════════╗
--// ║  TrustHub FOV — 3 Methods Edition                            ║
--// ║  Based on Fleece's Utility Panel                             ║
--// ╚══════════════════════════════════════════════════════════════╝

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")

local LocalPlayer = Players.LocalPlayer
local Camera      = workspace.CurrentCamera

--// ============================================================
--//  CONFIG
--// ============================================================
local Config = {
    Enabled   = false,
    Method    = "direct",  -- direct | lock | maxaxis
    Value     = 100,
    LogEnabled = true,
}

--// ============================================================
--//  STATE
--// ============================================================
local connections = {}
local enabled = false
local savedOriginal = nil

local function log(msg)
    if Config.LogEnabled then print("[FOV] " .. msg) end
end

local function cleanup()
    for _, conn in ipairs(connections) do
        pcall(function() conn:Disconnect() end)
    end
    connections = {}

    -- Відновлюємо оригінальний FOV
    if savedOriginal then
        pcall(function()
            Camera.FieldOfView = savedOriginal.fov
            if savedOriginal.mode then
                Camera.FieldOfViewMode = savedOriginal.mode
            end
        end)
        savedOriginal = nil
    end
end

local function saveOriginal()
    if savedOriginal then return end
    savedOriginal = {
        fov = Camera.FieldOfView,
        mode = Camera.FieldOfViewMode,
    }
end

--// ============================================================
--//  METHOD 1: Direct (Just Set It)
--// ============================================================
local function methodDirect()
    saveOriginal()

    local conn = RunService.Heartbeat:Connect(function()
        if not enabled then return end
        if Camera and Camera.FieldOfView ~= Config.Value then
            Camera.FieldOfView = Config.Value
        end
    end)
    table.insert(connections, conn)

    log("Direct method started")
    return true
end

--// ============================================================
--//  METHOD 2: Lock (Keep Re-Setting)
--// ============================================================
local function methodLock()
    saveOriginal()

    local conn = RunService.RenderStepped:Connect(function()
        if not enabled then return end
        if Camera then
            Camera.FieldOfView = Config.Value
        end
    end)
    table.insert(connections, conn)

    log("Lock method started")
    return true
end

--// ============================================================
--//  METHOD 3: MaxAxis (Widescreen)
--// ============================================================
local function methodMaxAxis()
    saveOriginal()

    pcall(function()
        Camera.FieldOfViewMode = Enum.FieldOfViewMode.MaxAxis
    end)

    local conn = RunService.RenderStepped:Connect(function()
        if not enabled then return end
        if Camera then
            Camera.FieldOfView = Config.Value
        end
    end)
    table.insert(connections, conn)

    log("MaxAxis method started")
    return true
end

--// ============================================================
--//  METHOD SELECTOR
--// ============================================================
local METHODS = {
    direct  = methodDirect,
    lock    = methodLock,
    maxaxis = methodMaxAxis,
}

local function startMethod(name)
    local fn = METHODS[name] or METHODS.direct
    local ok, err = pcall(fn)
    if not ok then
        warn("[FOV] Method " .. name .. " failed: " .. tostring(err))
        return false
    end
    return true
end

--// ============================================================
--//  MODULE
--// ============================================================
local FOV = {}
FOV.__index = FOV

function FOV.new()
    return setmetatable({}, FOV)
end

function FOV:setEnabled(state)
    enabled = state
    Config.Enabled = state

    if state then
        cleanup()
        startMethod(Config.Method)
        log("═══ FOV ENABLED (Value: " .. Config.Value .. ", Method: " .. Config.Method .. ") ═══")
    else
        cleanup()
        log("FOV DISABLED")
    end
end

function FOV:setValue(value)
    Config.Value = value
    if enabled and Camera then
        pcall(function()
            Camera.FieldOfView = value
        end)
    end
    log("Value: " .. value)
end

function FOV:setMethod(name)
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
function FOV:setSpeed() end
function FOV:getValue() return Config.Value end
function FOV:getMethod() return Config.Method end

log("═══════════════════════════════")
log("TrustHub FOV loaded (3 methods)")
log("═══════════════════════════════")

return FOV.new()
