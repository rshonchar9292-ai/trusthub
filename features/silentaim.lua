--// ╔══════════════════════════════════════════════════════════════╗
--// ║  TrustHub Silent Aim — Auto Active                           ║
--// ║  Always ON. No toggles. Dual hook.                           ║
--// ╚══════════════════════════════════════════════════════════════╝

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local StarterGui       = game:GetService("StarterGui")

local LocalPlayer = Players.LocalPlayer
local Camera      = workspace.CurrentCamera

--// ============================================================
--//  STATE
--// ============================================================
local ACTIVE = true        -- завжди активний
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
            if n:find("knife") or n:find("blade") or n:find("murder") 
               or n:find("dagger") or n:find("sword") then
                return "Murderer"
            end
        end
    end

    for _, tool in ipairs(char:GetChildren()) do
        if tool:IsA("Tool") then
            local n = tool.Name:lower()
            if n:find("gun") or n:find("pistol") or n:find("sheriff") 
               or n:find("revolver") or n:find("magnum") then
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

--// ============================================================
--//  TARGET VALIDATION
--// ============================================================
local function isValidTarget(plr)
    if plr == LocalPlayer then return false end
    if not isAlive(plr) then return false end

    local myRole = getMyRole()
    local theirRole = getRole(plr)

    -- Як Murderer — стріляю в усіх, хто не Murderer
    if myRole == "Murderer" then
        return theirRole ~= "Murderer"
    end

    -- Інакше — тільки в Murderer-а
    return theirRole == "Murderer"
end

--// ============================================================
--//  FIND BEST TARGET
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
        local part = char:FindFirstChild("Head")
                  or char:FindFirstChild("HumanoidRootPart")
        if not part then continue end

        local sp, onScreen = Camera:WorldToViewportPoint(part.Position)
        local score
        if onScreen then
            score = (Vector2.new(sp.X, sp.Y) - mousePos).Magnitude
        else
            -- За екраном — wallbang (низький приоритет)
            local dist = (myRoot.Position - part.Position).Magnitude
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
--//  HOOK __namecall (головний метод)
--// ============================================================
local function hookNamecall()
    if hooked then return true end
    if not hookmetamethod or not getnamecallmethod then
        log("❌ hookmetamethod недоступний")
        return false
    end

    local success = pcall(function()
        oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
            local method = getnamecallmethod()
            local args = {...}

            if method == "FireServer" and ACTIVE then
                local char = LocalPlayer.Character
                local tool = char and char:FindFirstChildWhichIsA("Tool")

                if tool then
                    -- Чи це remote зброї?
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

                    if isWeaponRemote then
                        -- Знаходимо ціль
                        local target = findBestTarget()
                        if target then
                            local targetPos = target.Position + Vector3.new(0, 0.1, 0)
                            
                            -- Замінюємо Vector3 / CFrame
                            for i, arg in ipairs(args) do
                                if typeof(arg) == "Vector3" then
                                    args[i] = targetPos
                                elseif typeof(arg) == "CFrame" then
                                    local rot = arg - arg.Position
                                    args[i] = CFrame.new(targetPos) * rot
                                end
                            end
                        end
                    end
                end
            end

            -- ⚠ ГОЛОВНЕ: повертаємо результат oldNamecall
            return oldNamecall(self, unpack(args))
        end))

        hooked = true
        log("✓ hookmetamethod активовано")
    end)

    return success
end

--// ============================================================
--//  HOOK getsenv (додатковий метод)
--// ============================================================
local hookedScripts = {}

local function hookGetsenv()
    if not getsenv then return false end
    local char = LocalPlayer.Character
    if not char then return false end
    local tool = char:FindFirstChildWhichIsA("Tool")
    if not tool then return false end

    local anyHooked = false

    for _, gunScript in ipairs(tool:GetDescendants()) do
        if not gunScript:IsA("LocalScript") then continue end
        if hookedScripts[gunScript] then continue end

        local ok, env = pcall(getsenv, gunScript)
        if not ok or not env then continue end

        for funcName, funcValue in pairs(env) do
            if type(funcValue) == "function" then
                local lower = tostring(funcName):lower()
                if lower == "fire" or lower == "shoot" or lower == "hit" then
                    local oldFunc = env[funcName]
                    env[funcName] = function(...)
                        local args = {...}
                        if ACTIVE then
                            local target = findBestTarget()
                            if target then
                                local targetPos = target.Position + Vector3.new(0, 0.1, 0)
                                for i, arg in ipairs(args) do
                                    if typeof(arg) == "Vector3" then
                                        args[i] = targetPos
                                    end
                                end
                            end
                        end
                        return oldFunc(unpack(args))
                    end
                    hookedScripts[gunScript] = true
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
--//  AUTO RE-HOOK
--// ============================================================
local function tryAllHooks()
    hookNamecall()
    hookGetsenv()
end

-- Перший хук
task.wait(0.5)
tryAllHooks()

-- При зміні персонажа
LocalPlayer.CharacterAdded:Connect(function()
    task.wait(1.5)
    tryAllHooks()
end)

-- Кожні 2 секунди (якщо зброя змінилась)
task.spawn(function()
    while task.wait(2) do
        tryAllHooks()
    end
end)

--// ============================================================
--//  MODULE (API stubs для UI сумісності)
--// ============================================================
local SilentAim = {}
SilentAim.__index = SilentAim

function SilentAim.new()
    return setmetatable({}, SilentAim)
end

-- Нічого не роблять — просто stubs
function SilentAim:setEnabled() end
function SilentAim:setHitChance() end
function SilentAim:setFOV() end
function SilentAim:setAimPart() end
function SilentAim:setWallBang() end
function SilentAim:setTargetMode() end
function SilentAim:getStats() return { Active = true } end

log("═══════════════════════════════")
log("Silent Aim loaded — ALWAYS ON")
log("No toggles needed")
log("═══════════════════════════════")

notify("💀 Silent Aim", "Active (no toggle needed)", 4)

return SilentAim.new()
