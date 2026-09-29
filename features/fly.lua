--// ╔══════════════════════════════════════════════════════════════╗
--// ║  TrustHub Fly — 7 Methods Edition                            ║
--// ║  Based on Fleece's Utility Panel                             ║
--// ╚══════════════════════════════════════════════════════════════╝

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local StarterGui       = game:GetService("StarterGui")

local LocalPlayer = Players.LocalPlayer
local Camera      = workspace.CurrentCamera

--// ============================================================
--//  CONFIG
--// ============================================================
local Config = {
    Enabled  = false,
    Method   = "bodyvelocity",  -- bodyvelocity | constraints | velocity | cframe | lerp | swim | platform
    Speed    = 60,
    LogEnabled = true,
}

--// ============================================================
--//  STATE
--// ============================================================
local connections = {}
local objects = {}
local enabled = false

local function log(msg)
    if Config.LogEnabled then print("[Fly] " .. msg) end
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

local function cleanup()
    for _, conn in ipairs(connections) do
        pcall(function() conn:Disconnect() end)
    end
    connections = {}
    for _, obj in ipairs(objects) do
        pcall(function() obj:Destroy() end)
    end
    objects = {}

    -- Відновлюємо PlatformStand
    local char, hum = getChar()
    if hum then
        pcall(function()
            hum.PlatformStand = false
            hum:ChangeState(Enum.HumanoidStateType.GettingUp)
        end)
    end
end

--// ============================================================
--//  MOVE DIRECTION (WASD + Space/Ctrl)
--// ============================================================
local function isTyping()
    return UserInputService:GetFocusedTextBox() ~= nil
end

local function getMoveDirection(includeVertical)
    local cam = Camera
    if not cam then return Vector3.zero end
    local cf = cam.CFrame
    local dir = Vector3.zero

    if not isTyping() then
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir += cf.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir -= cf.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir -= cf.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir += cf.RightVector end

        if includeVertical then
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir += Vector3.yAxis end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then dir -= Vector3.yAxis end
        end
    end

    if dir.Magnitude < 1e-4 then return Vector3.zero end
    return dir.Unit
end

--// ============================================================
--//  METHOD 1: BodyVelocity (Floating Hover)
--// ============================================================
local function methodBodyVelocity()
    local char, hum, hrp = getChar()
    if not hrp then return false end

    local bv = Instance.new("BodyVelocity")
    bv.MaxForce = Vector3.one * 1e6
    bv.Velocity = Vector3.zero
    bv.P = 1250
    bv.Parent = hrp
    table.insert(objects, bv)

    local bg = Instance.new("BodyGyro")
    bg.MaxTorque = Vector3.one * 4e5
    bg.P = 1e4
    bg.D = 500
    bg.CFrame = Camera.CFrame
    bg.Parent = hrp
    table.insert(objects, bg)

    local conn = RunService.Heartbeat:Connect(function()
        if not enabled then return end
        local _, _, root = getChar()
        if not root or not bv.Parent then return end
        bv.Velocity = getMoveDirection(true) * Config.Speed
        bg.CFrame = Camera.CFrame
    end)
    table.insert(connections, conn)

    log("BodyVelocity method started")
    return true
end

--// ============================================================
--//  METHOD 2: Constraints (Smooth Glide)
--// ============================================================
local function methodConstraints()
    local char, hum, hrp = getChar()
    if not hrp then return false end

    local att = Instance.new("Attachment")
    att.Parent = hrp
    table.insert(objects, att)

    local lv = Instance.new("LinearVelocity")
    lv.Attachment0 = att
    lv.MaxForce = 1e6
    lv.RelativeTo = Enum.ActuatorRelativeTo.World
    lv.VectorVelocity = Vector3.zero
    lv.Parent = hrp
    table.insert(objects, lv)

    local ao = Instance.new("AlignOrientation")
    ao.Attachment0 = att
    ao.Mode = Enum.OrientationAlignmentMode.OneAttachment
    ao.RigidityEnabled = true
    ao.Parent = hrp
    table.insert(objects, ao)

    local conn = RunService.Heartbeat:Connect(function()
        if not enabled then return end
        local _, _, root = getChar()
        if not root or not lv.Parent then return end
        lv.VectorVelocity = getMoveDirection(true) * Config.Speed
        local flat = Vector3.new(Camera.CFrame.LookVector.X, 0, Camera.CFrame.LookVector.Z)
        if flat.Magnitude > 1e-4 then
            ao.CFrame = CFrame.lookAt(Vector3.zero, flat.Unit)
        end
    end)
    table.insert(connections, conn)

    log("Constraints method started")
    return true
end

--// ============================================================
--//  METHOD 3: Velocity (Push Speed)
--// ============================================================
local function methodVelocity()
    local conn = RunService.Heartbeat:Connect(function()
        if not enabled then return end
        local _, _, hrp = getChar()
        if not hrp then return end
        hrp.AssemblyLinearVelocity = getMoveDirection(true) * Config.Speed
    end)
    table.insert(connections, conn)

    log("Velocity method started")
    return true
end

--// ============================================================
--//  METHOD 4: CFrame (Instant Move)
--// ============================================================
local function methodCFrame()
    local conn = RunService.RenderStepped:Connect(function(dt)
        if not enabled then return end
        local _, _, hrp = getChar()
        if not hrp then return end
        hrp.AssemblyLinearVelocity = Vector3.zero
        local dir = getMoveDirection(true)
        if dir.Magnitude > 0 then
            hrp.CFrame = hrp.CFrame + dir * Config.Speed * math.min(dt, 0.1)
        end
    end)
    table.insert(connections, conn)

    log("CFrame method started")
    return true
end

--// ============================================================
--//  METHOD 5: Lerp (Gentle Drift)
--// ============================================================
local function methodLerp()
    local char, hum, hrp = getChar()
    if not hrp then return false end

    local goal = hrp.Position

    local conn = RunService.RenderStepped:Connect(function(dt)
        if not enabled then return end
        local _, _, root = getChar()
        if not root then return end

        local dir = getMoveDirection(true)
        goal += dir * Config.Speed * math.min(dt, 0.1)

        if (goal - root.Position).Magnitude > 60 then
            goal = root.Position
        end

        root.AssemblyLinearVelocity = Vector3.zero
        root.CFrame = root.CFrame:Lerp(
            CFrame.new(goal) * (root.CFrame - root.CFrame.Position),
            math.clamp(dt * 12, 0, 1)
        )
    end)
    table.insert(connections, conn)

    log("Lerp method started")
    return true
end

--// ============================================================
--//  METHOD 6: Swim (Swim Through Air)
--// ============================================================
local function methodSwim()
    local char, hum, hrp = getChar()
    if not hum then return false end

    local wasEnabled = hum:GetStateEnabled(Enum.HumanoidStateType.Swimming)
    pcall(function()
        hum:SetStateEnabled(Enum.HumanoidStateType.Swimming, true)
    end)

    table.insert(objects, {
        Destroy = function()
            local _, h = getChar()
            if h then
                pcall(function()
                    h:SetStateEnabled(Enum.HumanoidStateType.Swimming, wasEnabled)
                    h:ChangeState(Enum.HumanoidStateType.GettingUp)
                end)
            end
        end
    })

    local conn = RunService.Heartbeat:Connect(function()
        if not enabled then return end
        local _, h, root = getChar()
        if not h or not root then return end
        h:ChangeState(Enum.HumanoidStateType.Swimming)
        root.AssemblyLinearVelocity = getMoveDirection(true) * Config.Speed
    end)
    table.insert(connections, conn)

    log("Swim method started")
    return true
end

--// ============================================================
--//  METHOD 7: Platform (Ragdoll Float)
--// ============================================================
local function methodPlatform()
    local char, hum, hrp = getChar()
    if not hum or not hrp then return false end

    hum.PlatformStand = true

    local conn = RunService.Heartbeat:Connect(function()
        if not enabled then return end
        local _, h, root = getChar()
        if not h or not root then return end
        h.PlatformStand = true
        root.AssemblyLinearVelocity = getMoveDirection(true) * Config.Speed

        local flat = Vector3.new(Camera.CFrame.LookVector.X, 0, Camera.CFrame.LookVector.Z)
        if flat.Magnitude > 1e-4 then
            root.CFrame = CFrame.lookAt(root.Position, root.Position + flat.Unit)
        end
    end)
    table.insert(connections, conn)

    log("Platform method started")
    return true
end

--// ============================================================
--//  METHOD SELECTOR
--// ============================================================
local METHODS = {
    bodyvelocity = methodBodyVelocity,
    constraints  = methodConstraints,
    velocity     = methodVelocity,
    cframe       = methodCFrame,
    lerp         = methodLerp,
    swim         = methodSwim,
    platform     = methodPlatform,
}

local function startMethod(name)
    local fn = METHODS[name] or METHODS.bodyvelocity
    local ok, err = pcall(fn)
    if not ok then
        warn("[Fly] Method " .. name .. " failed: " .. tostring(err))
        return false
    end
    return true
end

--// ============================================================
--//  MODULE
--// ============================================================
local Fly = {}
Fly.__index = Fly

function Fly.new()
    return setmetatable({}, Fly)
end

function Fly:setEnabled(state)
    enabled = state
    Config.Enabled = state

    if state then
        cleanup()
        startMethod(Config.Method)
        log("═══ Fly ENABLED (Speed: " .. Config.Speed .. ", Method: " .. Config.Method .. ") ═══")
    else
        cleanup()
        log("Fly DISABLED")
    end
end

function Fly:setSpeed(value)
    Config.Speed = value
    log("Speed: " .. value)
end

function Fly:setMethod(name)
    local wasEnabled = enabled
    if wasEnabled then
        self:setEnabled(false)
        task.wait(0.1)
    end
    Config.Method = name
    if wasEnabled then
        self:setEnabled(true)
    end
    log("Method: " .. name)
end

-- Stubs для сумісності з UI
function Fly:setValue(v) Config.Speed = v end
function Fly:getSpeed() return Config.Speed end
function Fly:getMethod() return Config.Method end

-- Автоматичне відновлення при респавні
LocalPlayer.CharacterAdded:Connect(function()
    if enabled then
        cleanup()
        task.wait(0.5)
        startMethod(Config.Method)
    end
end)

log("═══════════════════════════════")
log("TrustHub Fly loaded (7 methods)")
log("═══════════════════════════════")

return Fly.new()
