--// ╔══════════════════════════════════════════════════════════════╗
--// ║  TrustHub Silent Aim — MM2 Edition                           ║
--// ║  Exact method from working reference (Fling Gui V35.0)       ║
--// ╚══════════════════════════════════════════════════════════════╝

local Players    = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")

local LocalPlayer = Players.LocalPlayer

--// ============================================================
--//  CONFIG
--// ============================================================
local Config = {
    Enabled    = false,
    Prediction = 40,        -- velocity / 40 (як у референсі)
    TeamCheck  = true,
    LogEnabled = true,
}

--// ============================================================
--//  STATE
--// ============================================================
local Roles = {
    Murderer = nil,
    Sheriff  = nil,
}

local hooked = false
local oldNamecall = nil
local shots = 0

--// ============================================================
--//  LOG / NOTIFY
--// ============================================================
local function log(msg)
    if Config.LogEnabled then
        print("[SilentAim] " .. tostring(msg))
    end
end

local function notify(title, text, duration)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = title, Text = text, Duration = duration or 2,
        })
    end)
end

--// ============================================================
--//  HELPERS
--// ============================================================
local function isAlive(plr)
    if not plr or not plr.Character then return false end
    local hum = plr.Character:FindFirstChildOfClass("Humanoid")
    return hum and hum.Health > 0
end

--// ============================================================
--//  ROLE TRACKING (як у референсі — через Backpack.ChildAdded)
--// ============================================================
local function checkWeapon(child)
    if not child:IsA("Tool") then return end
    local n = child.Name:lower()
    if n:find("knife") or n:find("blade") or n:find("murder") then
        return "Murderer"
    elseif n:find("gun") or n:find("pistol") or n:find("sheriff") then
        return "Sheriff"
    end
    return nil
end

local function trackPlayer(plr)
    if plr == LocalPlayer then return end

    local function attach(char)
        if not char then return end

        -- Backpack
        local bp = plr:FindFirstChild("Backpack")
        if bp then
            for _, tool in ipairs(bp:GetChildren()) do
                local role = checkWeapon(tool)
                if role == "Murderer" then
                    Roles.Murderer = plr
                    log("🎯 Murderer: " .. plr.Name)
                elseif role == "Sheriff" then
                    Roles.Sheriff = plr
                end
            end
            bp.ChildAdded:Connect(function(child)
                local role = checkWeapon(child)
                if role == "Murderer" then
                    Roles.Murderer = plr
                    log("🎯 Murderer (backpack): " .. plr.Name)
                elseif role == "Sheriff" then
                    Roles.Sheriff = plr
                end
            end)
        end

        -- Character (вже тримає в руках)
        for _, tool in ipairs(char:GetChildren()) do
            local role = checkWeapon(tool)
            if role == "Murderer" then
                Roles.Murderer = plr
                log("🎯 Murderer: " .. plr.Name)
            elseif role == "Sheriff" then
                Roles.Sheriff = plr
            end
        end
        char.ChildAdded:Connect(function(child)
            local role = checkWeapon(child)
            if role == "Murderer" then
                Roles.Murderer = plr
                log("🎯 Murderer (equipped): " .. plr.Name)
            elseif role == "Sheriff" then
                Roles.Sheriff = plr
            end
        end)
    end

    attach(plr.Character)
    plr.CharacterAdded:Connect(attach)
end

for _, plr in ipairs(Players:GetPlayers()) do
    trackPlayer(plr)
end
Players.PlayerAdded:Connect(trackPlayer)
Players.PlayerRemoving:Connect(function(plr)
    if Roles.Murderer == plr then Roles.Murderer = nil end
    if Roles.Sheriff == plr then Roles.Sheriff = nil end
end)

--// ============================================================
--//  GET MURDERER (fallback якщо кеш порожній)
--// ============================================================
local function getMurderer()
    if Roles.Murderer and isAlive(Roles.Murderer) then
        return Roles.Murderer
    end

    -- Fallback — шукаємо самі
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == LocalPlayer then continue end
        if not isAlive(plr) then continue end
        for _, tool in ipairs(plr.Character:GetChildren()) do
            if tool:IsA("Tool") then
                local n = tool.Name:lower()
                if n:find("knife") or n:find("blade") or n:find("murder") then
                    Roles.Murderer = plr
                    return plr
                end
            end
        end
    end

    return nil
end

--// ============================================================
--//  HOOK __namecall (метод з референсу — getrawmetatable)
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

            -- Пропускаємо власні виклики
            if not Config.Enabled or checkcaller() then
                return oldNamecall(Object, unpack(Arguments))
            end

            -- === SILENT AIM для ShootGun (пістолет) ===
            if NamecallMethod == "InvokeServer" and tostring(Object) == "ShootGun" then
                local success, err2 = pcall(function()
                    local target = getMurderer()
                    if not target or not target.Character then return end

                    local primaryPart = target.Character.PrimaryPart
                    if not primaryPart then return end

                    local velocity = primaryPart.AssemblyLinearVelocity
                    local prediction = velocity / Config.Prediction

                    -- Якщо ціль стрибає — скасувати постріл (як у референсі)
                    if math.abs(velocity.Y) >= 10 then
                        return "Nullify"
                    end

                    -- ⚡ ПІДМІНА ТОЧКИ ВЛУЧАННЯ (Arguments[2])
                    Arguments[2] = primaryPart.Position + prediction
                    shots = shots + 1

                    if Config.LogEnabled and shots % 10 == 1 then
                        log("🎯 Shot #" .. shots .. " → " .. target.Name)
                    end
                end)

                if err2 == "Nullify" then
                    return nil
                end
            end

            return oldNamecall(Object, unpack(Arguments))
        end)

        setreadonly(mt, true)
        hooked = true
        log("✓ Hook активовано (ShootGun)")
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
--//  AUTO RE-HOOK
--// ============================================================
LocalPlayer.CharacterAdded:Connect(function()
    task.wait(2)
    if Config.Enabled and not hooked then hook() end
end)

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
        log("═══ ENABLED ═══")
        notify("💀 Silent Aim", "Enabled", 2)
    else
        unhook()
        log("═══ DISABLED ═══")
        notify("💀 Silent Aim", "Disabled", 2)
    end
end

function SilentAim:setPrediction(v) Config.Prediction = v end
function SilentAim:setTeamCheck(v) Config.TeamCheck = v end
function SilentAim:setFOV() end
function SilentAim:setHitChance() end
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
        Murderer = Roles.Murderer and Roles.Murderer.Name or "None",
        Sheriff  = Roles.Sheriff and Roles.Sheriff.Name or "None",
    }
end

log("═══════════════════════════════")
log("Silent Aim MM2 loaded")
log("Hook: __namecall → ShootGun")
log("Prediction: velocity / " .. Config.Prediction)
log("═══════════════════════════════")

return SilentAim.new()
