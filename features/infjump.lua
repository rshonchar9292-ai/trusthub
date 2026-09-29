--// ╔══════════════════════════════════════════════════════════════╗
--// ║  TrustHub Infinite Jump — 2 Methods Edition                  ║
--// ║  Based on Fleece's Utility Panel                             ║
--// ╚══════════════════════════════════════════════════════════════╝

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local StarterGui       = game:GetService("StarterGui")

local LocalPlayer = Players.LocalPlayer

--// ============================================================
--//  CONFIG
--// ============================================================
local Config = {
    Enabled   = false,
    Method    = "jumprequest",  -- jumprequest | hold
    LogEnabled = true,
}

--// ============================================================
--//  STATE
--// ============================================================
local connections = {}
local enabled = false
local jumpCount = 0

local function log(msg)
    if Config.LogEnabled then print("[InfJump] " .. msg) end
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

local function isTyping()
    return UserInputService:GetFocusedTextBox() ~= nil
end

local function cleanup()
    for _, conn in ipairs(connections) do
        pcall(function() conn:Disconnect() end)
    end
    connections = {}
end

--// ============================================================
--//  METHOD 1: Jump On Press (JumpRequest event)
--// ============================================================
local function methodJumpRequest()
    local conn = UserInputService.JumpRequest:Connect(function()
        if not enabled then return end
        if isTyping() then return end

        local char, hum = getChar()
        if not hum then return end

        pcall(function()
            hum:ChangeState(Enum.HumanoidStateType.Jumping)
        end)
        jumpCount = jumpCount + 1
    end)
    table.insert(connections, conn)

    log("JumpRequest method started")
    return true
end

--// ============================================================
--//  METHOD 2: Hold To Bunny Hop (Space held)
--// ============================================================
local function methodHold()
    local conn = RunService.RenderStepped:Connect(function()
        if not enabled then return end
        if isTyping() then return end
        if not UserInputService:IsKeyDown(Enum.KeyCode.Space) then return end

        local char, hum = getChar()
        if not hum then return end

        pcall(function()
            hum:ChangeState(Enum.HumanoidStateType.Jumping)
        end)
    end)
    table.insert(connections, conn)

    log("Hold method started")
    return true
end

--// ============================================================
--//  METHOD SELECTOR
--// ============================================================
local METHODS = {
    jumprequest = methodJumpRequest,
    hold        = methodHold,
}

local function startMethod(name)
    local fn = METHODS[name] or METHODS.jumprequest
    local ok, err = pcall(fn)
    if not ok then
        warn("[InfJump] Method " .. name .. " failed: " .. tostring(err))
        return false
    end
    return true
end

--// ============================================================
--//  MODULE
--// ============================================================
local InfJump = {}
InfJump.__index = InfJump

function InfJump.new()
    return setmetatable({}, InfJump)
end

function InfJump:setEnabled(state)
    enabled = state
    Config.Enabled = state

    if state then
        cleanup()
        startMethod(Config.Method)
        log("═══ Infinite Jump ENABLED (Method: " .. Config.Method .. ") ═══")
    else
        cleanup()
        log("Infinite Jump DISABLED")
    end
end

function InfJump:setMethod(name)
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
function InfJump:setSpeed() end
function InfJump:setValue() end
function InfJump:getMethod() return Config.Method end
function InfJump:getJumpCount() return jumpCount end

-- Автоматичне перепідключення при респавні
LocalPlayer.CharacterAdded:Connect(function()
    if enabled then
        cleanup()
        task.wait(0.5)
        startMethod(Config.Method)
    end
end)

log("═══════════════════════════════")
log("TrustHub InfJump loaded (2 methods)")
log("═══════════════════════════════")

return InfJump.new()
