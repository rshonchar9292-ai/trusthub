--// ============================================================
--// TrustHub Silent Aim — MANUAL Mode
--// Ти стріляєш ЛКМ → хук підмінює позицію
--// ============================================================

local Players    = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")

local LocalPlayer = Players.LocalPlayer

--// ============================================================
--//  CONFIG
--// ============================================================
local Config = {
    Enabled      = false,
    ShootOffset  = 3.5,
    LogEnabled   = true,
}

--// ============================================================
--//  STATE
--// ============================================================
local hooked = false
local oldNamecall = nil
local shots = 0

--// ============================================================
--//  LOG
--// ============================================================
local function log(msg)
    if Config.LogEnabled then print("[SilentAim] " .. tostring(msg)) end
end

local function notify(title, text, duration)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = title, Text = text, Duration = duration or 2,
        })
    end)
end

--// ============================================================
--//  FIND MURDERER
--// ============================================================
local function findMurderer()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == LocalPlayer then continue end
        local bp = plr:FindFirstChild("Backpack")
        if bp and bp:FindFirstChild("Knife") then
            return plr
        end
    end

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == LocalPlayer then continue end
        if plr.Character and plr.Character:FindFirstChild("Knife") then
            return plr
        end
    end

    return nil
end

--// ============================================================
--//  CHECK IF LOCAL PLAYER'S GUN REMOTE
--// ============================================================
local function isOurGunRemote(Object)
    if not Object or not Object.Parent then return false end
    if Object.Name ~= "ShootGun" then return false end
    if not Object:IsA("RemoteFunction") then return false end

    local char = LocalPlayer.Character
    if not char then return false end

    local parent = Object.Parent
    if parent and parent.Name == "KnifeServer" then
        local gun = parent.Parent
        if gun and gun.Name == "Gun" and gun.Parent == char then
            return true
        end
    end

    return false
end

--// ============================================================
--//  HOOK
--// ============================================================
local function hook()
    if hooked then return true end

    local ok, err = pcall(function()
        local mt = getrawmetatable(game)
        if not mt then error("no metatable") end

        oldNamecall = mt.__namecall
        setreadonly(mt, false)

        mt.__namecall = newcclosure(function(Object, ...)
            local NamecallMethod = getnamecallmethod()
            local Arguments = {...}

            if not Config.Enabled or checkcaller() then
                return oldNamecall(Object, unpack(Arguments))
            end

            if NamecallMethod == "InvokeServer" and isOurGunRemote(Object) then
                local success, err2 = pcall(function()
                    local murderer = findMurderer()
                    if not murderer or not murderer.Character then return end

                    local hrp = murderer.Character:FindFirstChild("HumanoidRootPart")
                    local hum = murderer.Character:FindFirstChildOfClass("Humanoid")
                    if not hrp or not hum then return end

                    local predicted = hrp.Position + hum.MoveDirection * Config.ShootOffset

                    Arguments[2] = predicted
                    shots = shots + 1

                    log("🎯 Shot #" .. shots .. " → " .. murderer.Name)
                end)

                if not success then
                    log("Помилка у хуку: " .. tostring(err2))
                end
            end

            return oldNamecall(Object, unpack(Arguments))
        end)

        setreadonly(mt, true)
        hooked = true
        log("✓ Hook активовано (ShootGun manual)")
    end)

    if not ok then
        log("❌ Помилка: " .. tostring(err))
    end
    return hooked
end

local function unhook()
    if not hooked then return end
    pcall(function()
        local mt = getrawmetatable(game)
        setreadonly(mt, false)
        mt.__namecall = oldNamecall
        setreadonly(mt, true)
    end)
    hooked = false
    log("Hook знято")
end

--// ============================================================
--//  MODULE
--// ============================================================
local SilentAim = {}
SilentAim.__index = SilentAim

function SilentAim.new()
    return setmetatable({}, SilentAim)
end

function SilentAim:setEnabled(state)
    Config.Enabled = state
    if state then
        hook()
        log("═══ ENABLED (Manual Mode) ═══")
        log("Стріляй ЛКМ — куля полетить у Murderer-а")
        notify("💀 Silent Aim", "Enabled — shoot manually!", 3)
    else
        unhook()
        log("═══ DISABLED ═══")
        notify("💀 Silent Aim", "Disabled", 2)
    end
end

function SilentAim:setShootOffset(v) Config.ShootOffset = v end
function SilentAim:setPrediction(v) Config.ShootOffset = v end

-- Stubs
function SilentAim:setFOV() end
function SilentAim:setHitChance() end
function SilentAim:setTeamCheck() end
function SilentAim:setWallCheck() end
function SilentAim:setShowFOV() end
function SilentAim:setFOVColor() end
function SilentAim:setTargetPart() end
function SilentAim:setFOVThickness() end
function SilentAim:setFOVFilled() end
function SilentAim:setMethod() end

function SilentAim:getStats()
    return {
        Enabled  = Config.Enabled,
        Shots    = shots,
        Hooked   = hooked,
        Murderer = findMurderer() and findMurderer().Name or "None",
    }
end

log("═══════════════════════════════")
log("Silent Aim MM2 — MANUAL Mode")
log("Hook: ShootGun:InvokeServer")
log("Ти стріляєш → хук підмінює")
log("═══════════════════════════════")

return SilentAim.new()
