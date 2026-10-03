--// ╔══════════════════════════════════════════════════════════════╗
--// ║  TrustHub Silent Aim — MM2 Real Edition                      ║
--// ║  Hook: RemoteEvent "Shoot" via FireServer                    ║
--// ╚══════════════════════════════════════════════════════════════╝

local Players    = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")

local LocalPlayer = Players.LocalPlayer

--// ============================================================
--//  CONFIG
--// ============================================================
local Config = {
    Enabled    = false,
    Prediction = 40,
    LogEnabled = true,
    DebugAll   = false,   -- true = логувати ВСІ виклики
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
--//  HELPERS
--// ============================================================
local function isAlive(plr)
    if not plr or not plr.Character then return false end
    local hum = plr.Character:FindFirstChildOfClass("Humanoid")
    return hum and hum.Health > 0
end

--// ============================================================
--//  ROLE TRACKING
--// ============================================================
local function getRoleFromTool(tool)
    if not tool:IsA("Tool") then return nil end
    local n = tool.Name:lower()
    if n:find("knife") or n:find("blade") or n:find("murder") then
        return "Murderer"
    elseif n:find("gun") or n:find("pistol") or n:find("sheriff") then
        return "Sheriff"
    end
    return nil
end

local function trackPlayer(plr)
    if plr == LocalPlayer then return end

    local function scanContainer(container)
        if not container then return end
        for _, tool in ipairs(container:GetChildren()) do
            local role = getRoleFromTool(tool)
            if role == "Murderer" then
                if Roles.Murderer ~= plr then
                    Roles.Murderer = plr
                    log("🎯 Murderer: " .. plr.Name)
                end
            elseif role == "Sheriff" then
                Roles.Sheriff = plr
            end
        end
    end

    -- Backpack
    local bp = plr:FindFirstChild("Backpack")
    if bp then
        scanContainer(bp)
        bp.ChildAdded:Connect(function(child)
            local role = getRoleFromTool(child)
            if role == "Murderer" then
                Roles.Murderer = plr
                log("🎯 Murderer (backpack): " .. plr.Name)
            elseif role == "Sheriff" then
                Roles.Sheriff = plr
            end
        end)
    end

    -- Character
    if plr.Character then scanContainer(plr.Character) end
    plr.CharacterAdded:Connect(function(char)
        task.wait(1)
        scanContainer(char)
        char.ChildAdded:Connect(function(child)
            local role = getRoleFromTool(child)
            if role == "Murderer" then
                Roles.Murderer = plr
                log("🎯 Murderer (equipped): " .. plr.Name)
            elseif role == "Sheriff" then
                Roles.Sheriff = plr
            end
        end)
    end)
end

for _, plr in ipairs(Players:GetPlayers()) do trackPlayer(plr) end
Players.PlayerAdded:Connect(trackPlayer)
Players.PlayerRemoving:Connect(function(plr)
    if Roles.Murderer == plr then Roles.Murderer = nil end
    if Roles.Sheriff == plr then Roles.Sheriff = nil end
end)

--// ============================================================
--//  GET MURDERER
--// ============================================================
local function getMurderer()
    if Roles.Murderer and isAlive(Roles.Murderer) then
        return Roles.Murderer
    end

    -- Fallback пошук
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
--//  HOOK — FireServer on "Shoot" (пістолет)
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

            -- Debug — логуємо всі виклики
            if Config.DebugAll then
                if NamecallMethod == "FireServer" or NamecallMethod == "InvokeServer" then
                    print("[DEBUG] " .. NamecallMethod .. " → " .. tostring(Object))
                    for i, arg in ipairs(Arguments) do
                        print("    [" .. i .. "] " .. typeof(arg) .. " = " .. tostring(arg))
                    end
                end
            end

            -- === SILENT AIM: RemoteEvent "Shoot" ===
            -- Об'єкт має бути RemoteEvent з назвою "Shoot"
            if NamecallMethod == "FireServer" and tostring(Object) == "Shoot" then
                local success, err2 = pcall(function()
                    local target = getMurderer()
                    if not target or not target.Character then return end

                    local primaryPart = target.Character.PrimaryPart
                    if not primaryPart then return end

                    -- Перевірка чи є Vector3 в аргументах
                    local hasVector = false
                    for _, arg in ipairs(Arguments) do
                        if typeof(arg) == "Vector3" then
                            hasVector = true
                            break
                        end
                    end
                    if not hasVector then return end

                    local velocity = primaryPart.AssemblyLinearVelocity
                    local prediction = velocity / Config.Prediction

                    -- Якщо ціль стрибає — не стріляти
                    if math.abs(velocity.Y) >= 10 then
                        return "Nullify"
                    end

                    -- ⚡ ПІДМІНА ВСІХ Vector3
                    for i, arg in ipairs(Arguments) do
                        if typeof(arg) == "Vector3" then
                            Arguments[i] = primaryPart.Position + prediction
                        end
                    end

                    shots = shots + 1
                    if shots % 10 == 1 then
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
        log("✓ Hook активовано (Shoot remote)")
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

function SilentAim:setDebug(v) Config.DebugAll = v end
function SilentAim:setPrediction(v) Config.Prediction = v end
function SilentAim:setTeamCheck(v) end
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
log("Silent Aim MM2 — Real Edition")
log("Hook: FireServer → RemoteEvent 'Shoot'")
log("Prediction: velocity / " .. Config.Prediction)
log("═══════════════════════════════")

return SilentAim.new()
