--// ============================================================
--// TrustHub Silent Aim — WALLBANG Edition
--// Стріляє крізь стіни. Замінює origin + hit position.
--// ============================================================

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local StarterGui       = game:GetService("StarterGui")

local LocalPlayer = Players.LocalPlayer
local Camera      = workspace.CurrentCamera

local Config = {
    Enabled       = false,
    AimPart       = "Head",
    HitChance     = 100,
    TargetMode    = "Auto",     -- Auto | Murderer | All
    WallBang      = true,       -- стріляти крізь стіни
    ReplaceOrigin = true,       -- підміняти точку початку пострілу
    ToggleKey     = Enum.KeyCode.C,
}

local Stats = { Shots = 0, Hooks = 0 }

local function notify(title, text, duration)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = title, Text = text, Duration = duration or 2,
        })
    end)
end

local function log(msg) print("[SilentAim] " .. msg) end

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
            if n:find("gun") or n:find("pistol") or n:find("sheriff") or n:find("revolver") then
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

local function getMyRole() return getRole(LocalPlayer) end

local function isAlive(plr)
    local char = plr.Character
    if not char then return false end
    local hum = char:FindFirstChildOfClass("Humanoid")
    return hum and hum.Health > 0
end

local function isValidTarget(plr)
    if plr == LocalPlayer then return false end
    if not isAlive(plr) then return false end

    if Config.TargetMode == "Auto" then
        local myRole = getMyRole()
        local theirRole = getRole(plr)
        if myRole == "Murderer" then
            return theirRole ~= "Murderer"
        end
        return theirRole == "Murderer"
    elseif Config.TargetMode == "Murderer" then
        return getRole(plr) == "Murderer"
    end
    return true
end

--// ============================================================
--//  FIND BEST TARGET (без wall check — wallbang!)
--// ============================================================
local function findBestTarget()
    local myChar = LocalPlayer.Character
    if not myChar then return nil end
    local myRoot = myChar:FindFirstChild("HumanoidRootPart")
    if not myRoot then return nil end

    local mousePos = UserInputService:GetMouseLocation()
    local best, bestScore = nil, math.huge

    for _, plr in ipairs(Players:GetPlayers()) do
        if not isValidTarget(plr) then continue end

        local char = plr.Character
        local part = char:FindFirstChild(Config.AimPart) 
                  or char:FindFirstChild("Head")
                  or char:FindFirstChild("HumanoidRootPart")
        if not part then continue end

        local dist = (myRoot.Position - part.Position).Magnitude
        if dist > 5000 then continue end

        -- НЕ перевіряємо стіни — wallbang!
        
        local sp, onScreen = Camera:WorldToViewportPoint(part.Position)
        local score
        if onScreen then
            score = (Vector2.new(sp.X, sp.Y) - mousePos).Magnitude
        else
            -- За екраном — але все одно можемо цілитись
            score = 100000 + dist
        end

        if score < bestScore then
            bestScore = score
            best = part
        end
    end

    return best
end

--// ============================================================
--//  WALLBANG ARGUMENT REPLACER
--// ============================================================
local function replaceAimArgs(args, target, myRoot)
    if not target then return args end

    local targetPos = target.Position + Vector3.new(0, 0.1, 0)

    for i, arg in ipairs(args) do
        if typeof(arg) == "Vector3" then
            -- Замінюємо ВСІ Vector3
            -- Якщо WallBang — підміняємо на позицію цілі
            args[i] = targetPos
            
        elseif typeof(arg) == "CFrame" then
            -- CFrame — теж підміняємо позицію, зберігаючи обертання
            local rot = arg - arg.Position
            args[i] = CFrame.new(targetPos) * rot
            
        elseif typeof(arg) == "table" then
            -- Вкладена таблиця (деякі ігри так передають)
            for k, v in pairs(arg) do
                if typeof(v) == "Vector3" then
                    arg[k] = targetPos
                end
            end
        end
    end

    return args
end

--// ============================================================
--//  HOOK — __namecall
--// ============================================================
local mtHooked = false

local function hookMetamethod()
    if mtHooked then return true end
    if not hookmetamethod or not getnamecallmethod then
        log("hookmetamethod недоступний")
        return false
    end

    local ok = pcall(function()
        local oldNamecall
        oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
            local method = getnamecallmethod()
            local args = {...}

            if method == "FireServer" and Config.Enabled then
                local char = LocalPlayer.Character
                local tool = char and char:FindFirstChildWhichIsA("Tool")

                if tool then
                    local isWeaponRemote = false
                    local parent = self.Parent
                    local depth = 0
                    while parent and depth < 5 do
                        if parent == tool or parent == char then
                            isWeaponRemote = true
                            break
                        end
                        parent = parent.Parent
                        depth = depth + 1
                    end

                    -- Fallback: будь-який RemoteEvent з Vector3 в аргументах
                    if not isWeaponRemote and self:IsA("RemoteEvent") then
                        for _, arg in ipairs(args) do
                            if typeof(arg) == "Vector3" then
                                isWeaponRemote = true
                                break
                            end
                        end
                    end

                    if isWeaponRemote then
                        if math.random(1, 100) <= Config.HitChance then
                            local target = findBestTarget()
                            if target then
                                args = replaceAimArgs(args, target)
                                Stats.Shots = Stats.Shots + 1
                            end
                        end
                    end
                end
            end

            return oldNamecall(self, unpack(args))
        end))

        mtHooked = true
        log("✓ hookmetamethod активовано")
    end)

    return ok
end

--// ============================================================
--//  HOOK — getsenv
--// ============================================================
local hookedTools = {}

local function hookGetsenv()
    local char = LocalPlayer.Character
    if not char then return false end
    local tool = char:FindFirstChildWhichIsA("Tool")
    if not tool then return false end

    local scripts = {}
    for _, child in ipairs(tool:GetDescendants()) do
        if child:IsA("LocalScript") then
            table.insert(scripts, child)
        end
    end

    if #scripts == 0 then return false end

    local anyHooked = false

    for _, gunScript in ipairs(scripts) do
        if hookedTools[gunScript] then continue end

        local ok, env = pcall(getsenv, gunScript)
        if not ok or not env then continue end

        for funcName, funcValue in pairs(env) do
            if type(funcValue) == "function" then
                local lower = tostring(funcName):lower()
                if lower == "fire" or lower == "shoot" or lower == "hit" 
                   or lower:find("fire") or lower:find("shoot") then
                    
                    local oldFunc = env[funcName]
                    env[funcName] = function(...)
                        local args = {...}
                        if Config.Enabled then
                            if math.random(1, 100) <= Config.HitChance then
                                local target = findBestTarget()
                                if target then
                                    args = replaceAimArgs(args, target)
                                end
                            end
                        end
                        return oldFunc(unpack(args))
                    end
                    
                    hookedTools[gunScript] = true
                    anyHooked = true
                    log("✓ getsenv хук: " .. gunScript.Name .. "." .. funcName)
                    break
                end
            end
        end
    end

    return anyHooked
end

--// ============================================================
--//  UNIFIED
--// ============================================================
local function tryAllHooks()
    hookMetamethod()
    hookGetsenv()
end

task.spawn(function()
    while task.wait(2) do
        if Config.Enabled then
            pcall(tryAllHooks)
        end
    end
end)

LocalPlayer.CharacterAdded:Connect(function()
    task.wait(1.5)
    if Config.Enabled then tryAllHooks() end
end)

--// ============================================================
--//  KEYBIND
--// ============================================================
UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Config.ToggleKey then
        Config.Enabled = not Config.Enabled
        if Config.Enabled then
            tryAllHooks()
            notify("💀 Silent Aim (WallBang)", "ON", 2)
            log("ON")
        else
            notify("💀 Silent Aim", "OFF", 2)
            log("OFF")
        end
    end
end)

--// ============================================================
--//  MODULE
--// ============================================================
local SilentAim = {}
SilentAim.__index = SilentAim

function SilentAim.new()
    local self = setmetatable({}, SilentAim)
    task.wait(0.5)
    tryAllHooks()
    return self
end

function SilentAim:setEnabled(state)
    Config.Enabled = state
    if state then tryAllHooks() end
    log("setEnabled: " .. tostring(state))
end

function SilentAim:setHitChance(v) Config.HitChance = v end
function SilentAim:setFOV(v) end
function SilentAim:setAimPart(v) Config.AimPart = v end
function SilentAim:setWallBang(v) Config.WallBang = v end
function SilentAim:setTargetMode(v) Config.TargetMode = v end
function SilentAim:getStats() return Stats end

log("═══════════════════════════════")
log("Silent Aim WALLBANG loaded")
log("Toggle: C key")
log("═══════════════════════════════")

return SilentAim.new()
