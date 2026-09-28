--// ==================================================
--// TrustHub - Silent Aim (BEST VERSION)
--// Без FOV. Завжди цілиться в правильну ціль.
--// ==================================================

local Players          = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService       = game:GetService("RunService")
local LocalPlayer      = Players.LocalPlayer
local Camera           = workspace.CurrentCamera

local SilentAim = {}
SilentAim.__index = SilentAim

--// ==================================================
--// КОНФІГ
--// ==================================================
local CONFIG = {
    Enabled      = false,
    AimPart      = "Head",      -- Head / HumanoidRootPart / UpperTorso
    HitChance    = 100,         -- % влучання
    WallBang     = true,        -- стріляти крізь стіни
    TargetMode   = "Auto",      -- Auto | Murderer | All
    MaxDistance  = 5000,        -- максимальна відстань (studs)
    VisibleCheck = false,       -- перевіряти чи видно ціль (не для самого пострілу)
}

--// ==================================================
--// ВИЗНАЧЕННЯ РОЛІ (з ESP)
--// ==================================================
local function getRole(player)
    local char = player.Character
    if not char then return "Dead" end
    
    for _, tool in pairs(char:GetChildren()) do
        if tool:IsA("Tool") then
            local n = tool.Name:lower()
            if n:find("knife") or n:find("blade") or n:find("murder") then
                return "Murderer"
            end
        end
    end
    
    for _, tool in pairs(char:GetChildren()) do
        if tool:IsA("Tool") then
            local n = tool.Name:lower()
            if n:find("gun") or n:find("pistol") 
               or n:find("sheriff") or n:find("revolver") then
                return "Sheriff"
            end
        end
    end
    
    local backpack = player:FindFirstChild("Backpack")
    if backpack then
        for _, tool in pairs(backpack:GetChildren()) do
            if tool:IsA("Tool") then
                local n = tool.Name:lower()
                if n:find("gun") or n:find("pistol") 
                   or n:find("sheriff") or n:find("revolver") then
                    return "Sheriff"
                end
                if n:find("knife") or n:find("blade") 
                   or n:find("murder") then
                    return "Murderer"
                end
            end
        end
    end
    
    return "Innocent"
end

--// Моя роль
local function getMyRole()
    return getRole(LocalPlayer)
end

--// ==================================================
--// ЛОГІКА ЦІЛІ
--// ==================================================
-- Чи можна стріляти в цього гравця
local function isValidTarget(player)
    if player == LocalPlayer then return false end
    if not player.Character then return false end
    
    local hum = player.Character:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return false end
    
    local myRole = getMyRole()
    local theirRole = getRole(player)
    
    -- Режим Auto: розумний вибір
    if CONFIG.TargetMode == "Auto" then
        if myRole == "Murderer" then
            -- Я Murderer → стріляю в усіх, хто не Murderer
            return theirRole ~= "Murderer"
        else
            -- Я Innocent/Sheriff → стріляю тільки в Murderer
            return theirRole == "Murderer"
        end
    end
    
    -- Режим Murderer: тільки Murderer
    if CONFIG.TargetMode == "Murderer" then
        return theirRole == "Murderer"
    end
    
    -- Режим All: всі, крім себе
    if CONFIG.TargetMode == "All" then
        return true
    end
    
    return false
end

--// ==================================================
--// ПОШУК ЦІЛІ
--// ==================================================
local function isAlive(plr)
    local char = plr.Character
    if not char then return false end
    local hum = char:FindFirstChildOfClass("Humanoid")
    return hum and hum.Health > 0
end

-- Знаходить найкращу ціль (без FOV — по 3D відстані)
local function findBestTarget()
    local myChar = LocalPlayer.Character
    if not myChar then return nil end
    local myRoot = myChar:FindFirstChild("HumanoidRootPart")
    if not myRoot then return nil end
    
    local bestTarget = nil
    local bestScore = math.huge
    local mousePos = UserInputService:GetMouseLocation()
    
    for _, plr in ipairs(Players:GetPlayers()) do
        if not isValidTarget(plr) then continue end
        
        local char = plr.Character
        local part = char:FindFirstChild(CONFIG.AimPart) 
                  or char:FindFirstChild("HumanoidRootPart")
        if not part then continue end
        
        -- Перевірка дистанції
        local dist = (myRoot.Position - part.Position).Magnitude
        if dist > CONFIG.MaxDistance then continue end
        
        -- Перевірка видимості (якщо увімкнено)
        if CONFIG.VisibleCheck then
            local ray = Ray.new(Camera.CFrame.Position, 
                (part.Position - Camera.CFrame.Position).Unit * dist)
            local hit = workspace:FindPartOnRayWithIgnoreList(ray, 
                {LocalPlayer.Character, Camera})
            if hit and not hit:IsDescendantOf(char) then continue end
        end
        
        -- Пріоритет: найближчий на екрані до курсора, якщо видно
        -- інакше — просто найближчий 3D
        local screenPos, onScreen = Camera:WorldToViewportPoint(part.Position)
        local score
        
        if onScreen then
            -- Пріоритет: близько до курсора
            local screenDist = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
            score = screenDist
        else
            -- За екраном — далекий пріоритет
            score = 10000 + dist
        end
        
        if score < bestScore then
            bestScore = score
            bestTarget = part
        end
    end
    
    return bestTarget
end

--// ==================================================
--// ХУК через getsenv (основний метод)
--// ==================================================
local hookedScripts = {}

local function hookViaGetsenv()
    local char = LocalPlayer.Character
    if not char then return false end
    
    local tool = char:FindFirstChildWhichIsA("Tool")
    if not tool then return false end
    
    -- Шукаємо GunScript_Local в будь-якому вигляді
    local gunScript
    for _, child in ipairs(tool:GetDescendants()) do
        if child.Name == "GunScript_Local" and child:IsA("LocalScript") then
            gunScript = child
            break
        end
    end
    -- Fallback: будь-який LocalScript в зброї
    if not gunScript then
        for _, child in ipairs(tool:GetDescendants()) do
            if child:IsA("LocalScript") and child.Name:lower():find("gun") then
                gunScript = child
                break
            end
        end
    end
    
    if not gunScript then return false end
    if hookedScripts[gunScript] then return true end
    
    local ok, env = pcall(getsenv, gunScript)
    if not ok or not env then return false end
    if not env.Fire then return false end
    
    local oldFire = env.Fire
    env.Fire = function(...)
        local args = {...}
        
        if CONFIG.Enabled then
            if math.random(1, 100) <= CONFIG.HitChance then
                local target = findBestTarget()
                if target then
                    -- Замінюємо всі Vector3-аргументи на позицію цілі
                    for i, arg in ipairs(args) do
                        if typeof(arg) == "Vector3" then
                            args[i] = target.Position + Vector3.new(0, 0.05, 0)
                        end
                    end
                end
            end
        end
        
        return oldFire(unpack(args))
    end
    
    hookedScripts[gunScript] = true
    print("[TrustHub] SilentAim ✓ GunScript hooked (getsenv)")
    return true
end

--// ==================================================
--// АВТО-ПІДКЛЮЧЕННЯ
--// ==================================================
function SilentAim.new()
    local self = setmetatable({}, SilentAim)
    self.enabled = false
    self:startLoop()
    return self
end

function SilentAim:startLoop()
    -- Перша спроба
    task.wait(0.5)
    hookViaGetsenv()
    
    -- При зміні персонажа
    LocalPlayer.CharacterAdded:Connect(function()
        task.wait(1.5)
        hookViaGetsenv()
    end)
    
    -- Постійна перевірка (для випадку, коли з'явилась нова зброя)
    task.spawn(function()
        while task.wait(2) do
            if CONFIG.Enabled then
                hookViaGetsenv()
            end
        end
    end)
end

--// ==================================================
--// API для UI
--// ==================================================
function SilentAim:setEnabled(state)
    self.enabled = state
    CONFIG.Enabled = state
    
    if state then
        hookViaGetsenv()
        print("[TrustHub] SilentAim: ON")
    else
        print("[TrustHub] SilentAim: OFF")
    end
end

function SilentAim:setFOV(value)
    -- FOV більше не використовується (без FOV)
    -- Але залишаємо для сумісності з UI
end

function SilentAim:setAimPart(part)
    CONFIG.AimPart = part
end

function SilentAim:setHitChance(value)
    CONFIG.HitChance = value
end

function SilentAim:setWallBang(value)
    CONFIG.WallBang = value
end

function SilentAim:setTargetMode(mode)
    CONFIG.TargetMode = mode
end

function SilentAim:setMaxDistance(value)
    CONFIG.MaxDistance = value
end

return SilentAim.new()
