--// ╔══════════════════════════════════════════════════════════════╗
--// ║  TrustHub Silent Aim — REAL MM2 METHOD                       ║
--// ║  Hook: Gun.KnifeServer.ShootGun:InvokeServer                 ║
--// ║  Args: [1]=1  [2]=Vector3 position  [3]="AH"                 ║
--// ╚══════════════════════════════════════════════════════════════╝

local Players    = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")

local LocalPlayer = Players.LocalPlayer

--// ============================================================
--//  CONFIG
--// ============================================================
local Config = {
    Enabled      = false,
    ShootOffset  = 3.5,       -- offset як у референсі
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
--//  FIND MURDERER (як у референсі)
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
--//  GET LOCAL GUN REMOTE
--// ============================================================
local function getLocalGunRemote()
    local char = LocalPlayer.Character
    if not char then return nil end
    local gun = char:FindFirstChild("Gun")
    if not gun then return nil end
    local knifeServer = gun:FindFirstChild("KnifeServer")
    if not knifeServer then return nil end
    local shootGun = knifeServer:FindFirstChild("ShootGun")
    return shootGun
end

--// ============================================================
--//  HOOK __namecall
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

            -- === SILENT AIM ===
            -- Об'єкт — це RemoteFunction ShootGun
            if NamecallMethod == "InvokeServer" 
               and tostring(Object) == "ShootGun" then

                local success, err2 = pcall(function()
                    local murderer = findMurderer()
                    if not murderer or not murderer.Character then return end

                    local hrp = murderer.Character:FindFirstChild("HumanoidRootPart")
                    local hum = murderer.Character:FindFirstChildOfClass("Humanoid")
                    if not hrp or not hum then return end

                    -- Prediction: position + MoveDirection * offset
                    local predicted = hrp.Position + hum.MoveDirection * Config.ShootOffset

                    -- ⚡ ПІДМІНА Arguments[2]
                    Arguments[2] = predicted
                    shots = shots + 1

                    if shots % 5 == 1 then
                        log("🎯 Shot #" .. shots .. " → " .. murderer.Name)
                    end
                end)
            end

            return oldNamecall(Object, unpack(Arguments))
        end)

        setreadonly(mt, true)
        hooked = true
        log("✓ Hook активовано (ShootGun:InvokeServer)")
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
--//  AUTO SHOOT (як у референсі — кожні 0.1s)
--// ============================================================
local autoShootConn = nil

local function startAutoShoot()
    if autoShootConn then return end

    autoShootConn = task.spawn(function()
        while Config.Enabled do
            task.wait(0.1)

            local murderer = findMurderer()
            if not murderer or not murderer.Character then continue end

            local char = LocalPlayer.Character
            if not char then continue end

            local gun = char:FindFirstChild("Gun")
            if not gun then
                -- Екіпірувати Gun з Backpack
                local bp = LocalPlayer:FindFirstChild("Backpack")
                if bp and bp:FindFirstChild("Gun") then
                    local hum = char:FindFirstChildOfClass("Humanoid")
                    if hum then hum:EquipTool(bp.Gun) end
                end
                continue
            end

            local knifeServer = gun:FindFirstChild("KnifeServer")
            if not knifeServer then continue end
            local shootGun = knifeServer:FindFirstChild("ShootGun")
            if not shootGun then continue end

            local hrp = murderer.Character:FindFirstChild("HumanoidRootPart")
            local hum = murderer.Character:FindFirstChildOfClass("Humanoid")
            if not hrp or not hum then continue end

            -- Prediction
            local pos = hrp.Position + hum.MoveDirection * Config.ShootOffset

            -- Виклик remote напряму (без хука)
            pcall(function()
                shootGun:InvokeServer(1, pos, "AH")
                shots = shots + 1
            end)
        end
    end)
end

local function stopAutoShoot()
    autoShootConn = nil
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
        startAutoShoot()
        log("═══ ENABLED ═══")
        notify("💀 Silent Aim", "Enabled", 2)
    else
        unhook()
        stopAutoShoot()
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
        Enabled = Config.Enabled,
        Shots   = shots,
        Hooked  = hooked,
        Murderer = findMurderer() and findMurderer().Name or "None",
    }
end

log("═══════════════════════════════")
log("Silent Aim MM2 (REAL METHOD)")
log("Hook: ShootGun:InvokeServer")
log("Args: [1]=1, [2]=Vector3, [3]='AH'")
log("Offset: " .. Config.ShootOffset)
log("═══════════════════════════════")

return SilentAim.new()
