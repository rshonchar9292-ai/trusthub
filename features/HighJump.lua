--// ============================================================
--// TrustHub High Jump v1.0
--// Високий стрибок з регулюванням висоти
--// ============================================================

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local Local **Player = Players.LocalPlayer

local Config = {
   С Enabled = false,
    Power   = 150т,
    OldJumpPower    = nil,
    OldUseJumpPower = nil,
    Conn    = nil,
}

local function log(msg)
    print("[HighJump] " .. tostring(msg))
end

local function getHum()
    local char = LocalPlayer.Character
    if not char then return nil end
    return char:FindFirstChildOfClass("Humanoid")
end

local function applyPower()
    local hum = getHum()
    if not hum then return end

    if Config.OldJumpPower == nil then
        Config.OldJumpPower = hum.JumpPower
        Config.OldUseJumpPower = hum.UseJumpPower
    end

    hum.UseJumpPower = true
    hum.JumpPower = Config.Power
end

local function restorePower()
    local hum = getHum()
    if hum and Config.OldJumpPower ~= nil then
        hum.JumpPower = Config.OldJumpPower
        if Config.OldUseJumpPower ~= nil then
            hum.UseJumpPower = Config.OldUseJumpPower
        end
    end
    Config.OldJumpPower = nil
    Config.OldUseJumpPower = nil
end

--// ============================================================
--//  MODULE
--// ============================================================
local HighJump = {}
HighJump.__index = HighJump

function HighJump.new()
    return setmetatable({}, HighJump)
end

function HighJump:setEnabled(state)
    Config.Enabled = state

    if state then
        applyPower()

        if Config.Conn then Config.Conn:Disconnect() end
        Config.Conn = RunService.Heartbeat:Connect(function()
            if not Config.Enabled then return end
            local hum = getHum()
            if hum and hum.JumpPower ~= Config.Power then
                hum.UseJumpPower = true
                hum.JumpPower = Config.Power
            end
        end)

        log("═══ ENABLED (Power: " .. Config.Power .. ") ═══")
    else
        if Config.Conn then
            Config.Conn:Disconnect()
            Config.Conn = nil
        end
        restorePower()
        log("═══ DISABLED ═══")
    end
end

function HighJump:setPower(v)
    Config.Power = math.clamp(v, 50, 1000)
    if Config.Enabled then applyPower() end
end

LocalPlayer.CharacterAdded:Connect(function()
    if Config.Enabled then
        task.wait(0.5)
        Config.OldJumpPower = nil
        applyPower()
    end
end)

log("═══════════════════════════════")
log("TrustHub High Jump v1.0")
log("═══════════════════════════════")

return HighJump.new()
