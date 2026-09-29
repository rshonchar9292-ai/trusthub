--// ╔══════════════════════════════════════════════════════════════╗
--// ║  TrustHub Silent Aim — ShootGun Edition                      ║
--// ║  Pistol only • Always ON • Prediction • No binds             ║
--// ╚══════════════════════════════════════════════════════════════╝

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local StarterGui       = game:GetService("StarterGui")

local LocalPlayer = Players.LocalPlayer

--// ============================================================
--//  STATE
--// ============================================================
local ACTIVE = true
local hooked = false
local oldNamecall = nil

--// ============================================================
--//  LOG / NOTIFY
--// ============================================================
local function log(msg) print("[SilentAim] " .. msg) end

local function notify(title, text, duration)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = title, Text = text, Duration = duration or 3,
        })
    end)
end

--// ============================================================
--//  ROLE DETECTION
--// ============================================================
local function getRole(player)
    if not player or not player.Character then return "Dead" end
    local char = player.Character

    for _, tool in ipairs(char:GetChildren()) do
        if tool:IsA("Tool") then
            local n = tool.Name:lower()
            if n:find("knife") or n:find("blade") or n:find("murder") then
                return "Murderer"
            end
        end
    end

    for _, tool in ipairs(char:GetChildren()) do
        if tool:IsA("Tool") then
            local n = tool.Name:lower()
            if n:find("gun") or n:find("pistol") or n:find("sheriff") then
                return "Sheriff"
            end
        end
    end

    local bp = player:FindFirstChild("Backpack")
    if bp then
        for _, tool in ipairs(bp:GetChildren()) do
            if tool:IsA("Tool") then
                local n = tool.Name:lower()
                if n:find("gun") or n:find("pistol") or n:find("sheriff") then
                    return "Sheriff"
                end
                if n:find("knife") or n:find("blade") or n:find("murder") then
                    return "Murderer"
                end
            end
        end
    end

    return "Innocent"
end

local function findMurderer()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == LocalPlayer then continue end
        if not plr.Character then continue end
        local hum = plr.Character:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 then continue end
        if getRole(plr) == "Murderer" then
            return plr
        end
    end
    return nil
end

--// ============================================================
--//  PREDICTION (з оригіналу)
--// ============================================================
local function getPredictedPosition(primaryPart)
    -- Prediction = Velocity / 40
    local velocity = primaryPart.AssemblyLinearVelocity
    local prediction = velocity / 40

    -- Якщо ціль стрибає (Y velocity > 10) — не стріляти
    if math.abs(velocity.Y) >= 10 then
        return nil
    end

    return primaryPart.Position + prediction
end

--// ============================================================
--//  HOOK
--// ============================================================
local function hook()
    if hooked then return true end
    if not hookmetamethod or not getnamecallmethod then
        log("❌ hookmetamethod недоступний")
        return false
    end

    local success = pcall(function()
        oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(Object, ...)
            local NamecallMethod = getnamecallmethod()
            local Arguments = {...}

            if ACTIVE and not checkcaller() then
                -- Silent Aim для пістолета
                if NamecallMethod == "InvokeServer" and tostring(Object) == "ShootGun" then
                    local murderer = findMurderer()
                    if murderer and murderer.Character then
                        local primaryPart = murderer.Character.PrimaryPart
                        if primaryPart then
                            local predictedPos = getPredictedPosition(primaryPart)
                            if predictedPos then
                                Arguments[2] = predictedPos
                            else
                                -- Ціль стрибає — не стріляти
                                return nil
                            end
                        end
                    end
                end
            end

            return oldNamecall(Object, unpack(Arguments))
        end))

        hooked = true
        log("✓ hookmetamethod активовано (ShootGun)")
    end)

    return success
end

--// ============================================================
--//  AUTO RE-HOOK
--// ============================================================
task.wait(0.5)
hook()

LocalPlayer.CharacterAdded:Connect(function()
    task.wait(1.5)
    if ACTIVE and not hooked then hook() end
end)

task.spawn(function()
    while task.wait(3) do
        if ACTIVE and not hooked then
            pcall(hook)
        end
    end
end)

--// ============================================================
--//  MODULE (stubs для UI)
--// ============================================================
local SilentAim = {}
SilentAim.__index = SilentAim

function SilentAim.new()
    return setmetatable({}, SilentAim)
end

function SilentAim:setEnabled() end
function SilentAim:setHitChance() end
function SilentAim:setFOV() end
function SilentAim:setAimPart() end
function SilentAim:setWallBang() end
function SilentAim:setTargetMode() end

function SilentAim:getStats()
    return { Active = ACTIVE }
end

log("═══════════════════════════════")
log("Silent Aim ShootGun loaded")
log("Pistol only • Always ON")
log("═══════════════════════════════")

return SilentAim.new()
