--// ╔══════════════════════════════════════════════════════════════╗
--// ║  TrustHub Murderer Script                                    ║
--// ║  Kill All (knife remote exploit) + Auto Fling + ESP          ║
--// ╚══════════════════════════════════════════════════════════════╝

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")

local LocalPlayer = Players.LocalPlayer

--// ============================================================
--//  CONFIG
--// ============================================================
local Config = {
    LogEnabled    = true,
    NotifyEnabled = true,
    KillCooldown  = 0.5,
}

--// ============================================================
--//  STATE
--// ============================================================
local lastKill = 0
local killCount = 0

--// ============================================================
--//  HELPERS
--// ============================================================
local function log(msg)
    if Config.LogEnabled then print("[Murderer] " .. msg) end
end

local function notify(title, text, duration)
    if not Config.NotifyEnabled then return end
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = title, Text = text, Duration = duration or 2,
        })
    end)
end

local function getChar()
    local char = LocalPlayer.Character
    if not char then return nil end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hum or not hrp or hum.Health <= 0 then return nil end
    return char, hum, hrp
end

--// ============================================================
--//  FIND KNIFE
--// ============================================================
local function findKnife()
    local char = LocalPlayer.Character
    if not char then return nil end

    for _, tool in ipairs(char:GetChildren()) do
        if tool:IsA("Tool") then
            local n = tool.Name:lower()
            if n:find("knife") or n:find("blade") or n:find("murder") 
               or n:find("dagger") or n:find("sword") then
                return tool
            end
        end
    end

    -- Перевіряємо Backpack
    local bp = LocalPlayer:FindFirstChild("Backpack")
    if bp then
        for _, tool in ipairs(bp:GetChildren()) do
            if tool:IsA("Tool") then
                local n = tool.Name:lower()
                if n:find("knife") or n:find("blade") or n:find("murder") then
                    return tool
                end
            end
        end
    end

    return nil
end

local function amIMurderer()
    return findKnife() ~= nil
end

--// ============================================================
--//  FIND KNIFE REMOTES
--// ============================================================
local function findKnifeRemotes(knife)
    local remotes = {}
    if not knife then return remotes end

    for _, child in ipairs(knife:GetDescendants()) do
        if child:IsA("RemoteEvent") or child:IsA("RemoteFunction") then
            table.insert(remotes, child)
        end
        -- Також перевіряємо Tool.Handle на наявність RemoteEvent
        if child:IsA("BasePart") then
            for _, sub in ipairs(child:GetChildren()) do
                if sub:IsA("RemoteEvent") or sub:IsA("RemoteFunction") then
                    table.insert(remotes, sub)
                end
            end
        end
    end

    return remotes
end

--// ============================================================
--//  FIND ALL REMOTES (fallback — весь Character + Backpack)
--// ============================================================
local function findAllRemotes()
    local remotes = {}
    local char = LocalPlayer.Character
    if not char then return remotes end

    -- Character remotes
    for _, obj in ipairs(char:GetDescendants()) do
        if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
            table.insert(remotes, obj)
        end
    end

    -- Backpack remotes
    local bp = LocalPlayer:FindFirstChild("Backpack")
    if bp then
        for _, obj in ipairs(bp:GetDescendants()) do
            if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
                table.insert(remotes, obj)
            end
        end
    end

    return remotes
end

--// ============================================================
--//  CHECK IF PLAYER IS VALID TARGET
--// ============================================================
local function isValidTarget(plr)
    if plr == LocalPlayer then return false end
    if not plr.Character then return false end
    local hum = plr.Character:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return false end
    return true
end

--// ============================================================
--//  KILL PLAYER (спроба різними способами)
--// ============================================================
local function tryKillPlayer(target, remotes)
    if not isValidTarget(target) then return false end

    local myChar, myHum, myHrp = getChar()
    if not myHrp then return false end

    local targetChar = target.Character
    local targetHrp = targetChar:FindFirstChild("HumanoidRootPart")
    local targetHum = targetChar:FindFirstChildOfClass("Humanoid")
    local targetHead = targetChar:FindFirstChild("Head")

    if not targetHrp or not targetHum then return false end

    -- Телепортуємось поруч з ціллю (щоб пройти distance check)
    pcall(function()
        myHrp.CFrame = targetHrp.CFrame * CFrame.new(2, 0, 2)
    end)
    task.wait(0.03)

    local killed = false

    -- Метод 1: Fire всіма remotes з різними аргументами
    for _, remote in ipairs(remotes) do
        if remote:IsA("RemoteEvent") then
            -- Варіант A: просто виклик без аргументів
            pcall(function() remote:FireServer() end)
            -- Варіант B: Humanoid
            pcall(function() remote:FireServer(targetHum) end)
            -- Варіант C: Character
            pcall(function() remote:FireServer(targetChar) end)
            -- Варіант D: Player
            pcall(function() remote:FireServer(target) end)
            -- Варіант E: HRP
            pcall(function() remote:FireServer(targetHrp) end)
            -- Варіант F: Head
            if targetHead then
                pcall(function() remote:FireServer(targetHead) end)
            end
            -- Варіант G: комбінація
            pcall(function() remote:FireServer(targetChar, targetHrp) end)
            pcall(function() remote:FireServer(target, targetHrp) end)
            -- Варіант H: Vector3 позиція
            pcall(function() remote:FireServer(targetHrp.Position) end)
            -- Варіант I: Attack (слова)
            pcall(function() remote:FireServer("attack", target) end)
            pcall(function() remote:FireServer("hit", targetChar) end)
            pcall(function() remote:FireServer("kill", target) end)

            killed = true
        elseif remote:IsA("RemoteFunction") then
            pcall(function() remote:InvokeServer() end)
            pcall(function() remote:InvokeServer(target) end)
            pcall(function() remote:InvokeServer(targetChar) end)
            pcall(function() remote:InvokeServer(targetHrp) end)
        end
    end

    -- Метод 2: Просто доторкнутись до цілі (Knife Touched event)
    pcall(function()
        myHrp.CFrame = targetHrp.CFrame
    end)

    return killed
end

--// ============================================================
--//  KILL ALL
--// ============================================================
local function killAll()
    local now = tick()
    if now - lastKill < Config.KillCooldown then
        notify("⏳ Murderer", "Wait a moment...", 1)
        return
    end
    lastKill = now

    local knife = findKnife()
    if not knife then
        notify("❌ Murderer", "Ти не Murderer (немає ножа)", 3)
        log("Kill All failed — not Murderer")
        return
    end

    log("💀 Kill All started with knife: " .. knife.Name)

    -- Знаходимо remotes
    local remotes = findKnifeRemotes(knife)
    log("Found " .. #remotes .. " remotes in knife")

    -- Якщо в ножі немає remotes — шукаємо у всьому Character
    if #remotes == 0 then
        log("No remotes in knife, checking Character...")
        remotes = findAllRemotes()
        log("Found " .. #remotes .. " remotes in Character")
    end

    if #remotes == 0 then
        notify("❌ Murderer", "Не знайдено remote в ножі", 3)
        return
    end

    -- Вбиваємо всіх гравців
    local killed = 0
    for _, plr in ipairs(Players:GetPlayers()) do
        if isValidTarget(plr) then
            log("Killing: " .. plr.Name)
            local ok = tryKillPlayer(plr, remotes)
            if ok then
                killed = killed + 1
                killCount = killCount + 1
            end
            task.wait(0.05)
        end
    end

    log("💀 Kill All done — attacked " .. killed .. " players")
    notify("💀 Murderer", "Attacked " .. killed .. " players", 3)
end

--// ============================================================
--//  AUTO KILL (постійно вбивати всіх)
--// ============================================================
local autoKillEnabled = false
local autoKillConn = nil
local lastAutoKill = 0

local function startAutoKill()
    if autoKillConn then autoKillConn:Disconnect() end

    autoKillConn = RunService.Heartbeat:Connect(function()
        if not autoKillEnabled then return end
        if not amIMurderer() then return end

        local now = tick()
        if now - lastAutoKill < 2 then return end  -- кожні 2 секунди

        local knife = findKnife()
        if not knife then return end

        local remotes = findKnifeRemotes(knife)
        if #remotes == 0 then
            remotes = findAllRemotes()
        end
        if #remotes == 0 then return end

        lastAutoKill = now

        for _, plr in ipairs(Players:GetPlayers()) do
            if isValidTarget(plr) then
                task.spawn(function()
                    tryKillPlayer(plr, remotes)
                end)
                task.wait(0.1)
            end
        end
    end)
end

local function stopAutoKill()
    if autoKillConn then autoKillConn:Disconnect(); autoKillConn = nil end
end

--// ============================================================
--//  SKIDFLING (викинути за карту)
--// ============================================================
local function SkidFling(TargetPlayer, duration)
    if not TargetPlayer or TargetPlayer == LocalPlayer then return false end
    if not TargetPlayer.Character then return false end

    local Character = LocalPlayer.Character
    if not Character then return false end
    local Humanoid = Character:FindFirstChildOfClass("Humanoid")
    local RootPart = Humanoid and Humanoid.RootPart
    if not Humanoid or not RootPart then return false end

    local TCharacter = TargetPlayer.Character
    local THumanoid = TCharacter:FindFirstChildOfClass("Humanoid")
    local TRootPart = THumanoid and THumanoid.RootPart
    local THead = TCharacter:FindFirstChild("Head")
    if not (THumanoid and TRootPart) then return false end

    if RootPart.Velocity.Magnitude < 50 then
        getgenv().MurdererOldPos = RootPart.CFrame
    end

    local FPos = function(BasePart, Pos, Ang)
        RootPart.CFrame = CFrame.new(BasePart.Position) * Pos * Ang
        pcall(function()
            Character:SetPrimaryPartCFrame(CFrame.new(BasePart.Position) * Pos * Ang)
        end)
        RootPart.Velocity = Vector3.new(9e7, 9e7 * 10, 9e7)
        RootPart.RotVelocity = Vector3.new(9e8, 9e8, 9e8)
    end

    local function SFBasePart(BasePart)
        local TimeToWait = duration or 2
        local Time = tick()
        local Angle = 0
        repeat
            if not RootPart or not THumanoid then break end
            if BasePart.Velocity.Magnitude < 50 then
                Angle = Angle + 100
                FPos(BasePart, CFrame.new(0, 1.5, 0) + THumanoid.MoveDirection * BasePart.Velocity.Magnitude / 1.25, CFrame.Angles(math.rad(Angle), 0, 0))
                task.wait()
                FPos(BasePart, CFrame.new(0, -1.5, 0) + THumanoid.MoveDirection * BasePart.Velocity.Magnitude / 1.25, CFrame.Angles(math.rad(Angle), 0, 0))
                task.wait()
                FPos(BasePart, CFrame.new(2.25, 1.5, -2.25) + THumanoid.MoveDirection * BasePart.Velocity.Magnitude / 1.25, CFrame.Angles(math.rad(Angle), 0, 0))
                task.wait()
                FPos(BasePart, CFrame.new(-2.25, -1.5, 2.25) + THumanoid.MoveDirection * BasePart.Velocity.Magnitude / 1.25, CFrame.Angles(math.rad(Angle), 0, 0))
                task.wait()
            else
                FPos(BasePart, CFrame.new(0, 1.5, THumanoid.WalkSpeed), CFrame.Angles(math.rad(90), 0, 0))
                task.wait()
                FPos(BasePart, CFrame.new(0, -1.5, -THumanoid.WalkSpeed), CFrame.Angles(0, 0, 0))
                task.wait()
            end
        until BasePart.Velocity.Magnitude > 500 
           or BasePart.Parent ~= TargetPlayer.Character 
           or tick() > Time + TimeToWait
    end

    local prevDestroy = workspace.FallenPartsDestroyHeight
    workspace.FallenPartsDestroyHeight = 0/0

    local BV = Instance.new("BodyVelocity")
    BV.Name = "MurdererFling"
    BV.Parent = RootPart
    BV.Velocity = Vector3.new(9e8, 9e8, 9e8)
    BV.MaxForce = Vector3.new(1/0, 1/0, 1/0)

    Humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, false)

    if TRootPart and THead then
        if (TRootPart.CFrame.p - THead.CFrame.p).Magnitude > 5 then
            SFBasePart(THead)
        else
            SFBasePart(TRootPart)
        end
    elseif TRootPart then
        SFBasePart(TRootPart)
    end

    BV:Destroy()
    Humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, true)

    task.wait(0.3)
    if getgenv().MurdererOldPos and RootPart then
        pcall(function()
            RootPart.CFrame = getgenv().MurdererOldPos
        end)
    end

    workspace.FallenPartsDestroyHeight = prevDestroy
    return true
end

local function flingAll()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and isValidTarget(plr) then
            task.spawn(function()
                pcall(SkidFling, plr, 1.5)
            end)
            task.wait(0.3)
        end
    end
    notify("💥 Murderer", "Flinged all players", 3)
end

--// ============================================================
--//  DIAGNOSTICS
--// ============================================================
local function runDiagnostics()
    log("═══════════════════════════════")
    log("MURDERER DIAGNOSTICS")
    log("═══════════════════════════════")

    local knife = findKnife()
    if not knife then
        log("❌ No knife found — ти не Murderer")
        return
    end

    log("✅ Knife found: " .. knife.Name)
    log("Knife ClassName: " .. knife.ClassName)

    log("\n-- Knife descendants --")
    for _, obj in ipairs(knife:GetDescendants()) do
        log("  " .. obj.ClassName .. ": " .. obj.Name)
    end

    local remotes = findKnifeRemotes(knife)
    log("\n-- Found " .. #remotes .. " remotes --")
    for _, r in ipairs(remotes) do
        log("  " .. r.ClassName .. ": " .. r.Name)
    end

    if #remotes == 0 then
        log("\n-- Fallback: Character remotes --")
        local charRemotes = findAllRemotes()
        log("Found " .. #charRemotes .. " remotes in Character")
        for _, r in ipairs(charRemotes) do
            log("  " .. r.ClassName .. ": " .. r.Name .. " | Parent: " .. r.Parent.Name)
        end
    end

    log("═══════════════════════════════")
end

--// ============================================================
--//  MODULE
--// ============================================================
local Murderer = {}
Murderer.__index = Murderer

function Murderer.new()
    return setmetatable({}, Murderer)
end

function Murderer:killAll()
    task.spawn(killAll)
end

function Murderer:flingAll()
    task.spawn(flingAll)
end

function Murderer:setAutoKill(state)
    autoKillEnabled = state
    if state then
        startAutoKill()
        log("Auto Kill ENABLED")
        notify("🔪 Murderer", "Auto Kill ON", 3)
    else
        stopAutoKill()
        log("Auto Kill DISABLED")
        notify("🔪 Murderer", "Auto Kill OFF", 2)
    end
end

function Murderer:isMurderer()
    return amIMurderer()
end

function Murderer:diagnostics()
    runDiagnostics()
end

function Murderer:getStats()
    return { KillCount = killCount }
end

log("═══════════════════════════════")
log("TrustHub Murderer Script loaded")
log("═══════════════════════════════")

return Murderer.new()
