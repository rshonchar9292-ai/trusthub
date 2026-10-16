--// ============================================================
--// TrustHub AutoFarm v13.0 — фікс v12.0
--// ============================================================
--// ВИПРАВЛЕНО:
--//   1. coinCache: словник -> масив. #coinCache тепер справжній.
--//      Було: #dict == 0 завжди -> "всі монети зібрані" через 2с після старту.
--//   2. Noclip запам'ятовує оригінальний CanCollide і вертає ЙОГО,
--//      а не ставить true всьому (аксесуари більше не стають твердими).
--//   3. Noclip не перебирає персонажа щокадру + не тече при респавні.
--//   4. Прибрано AlignOrientation з RigidityEnabled — він блокував поворот.
--//   5. CONFIG.Speed тепер реально пише Humanoid.WalkSpeed.
--//   6. ProximityPrompt: якщо монета збирається промптом, політ у неї
--//      не давав нічого — тепер промпт спрацьовує.
--//   7. Мертві місця прибрано: BindToClose (на клієнті не працює),
--//      StarterGui-нотифікації на кожен чіх.
--//
--// ПРИБРАНО СВІДОМО (не фіксилось):
--//   SkidFling, autoFlingMurderer, autoKillMurderer, findMurderer,
--//   findSheriff, getRole, FallenPartsDestroyHeight = NaN.
--//   Це вплив на інших гравців і на фізику сесії.
--// ============================================================
local Players     = game:GetService("Players")
local RunService  = game:GetService("RunService")
local VirtualUser = game:GetService("VirtualUser")
local LocalPlayer = Players.LocalPlayer
--// ============================================================
--//  CONFIG
--// ============================================================
local CONFIG = {
    Enabled       = false,
    WalkSpeed     = 22,      --// тепер реально Humanoid.WalkSpeed
    FlySpeed      = 22,      --// швидкість польоту
    CoinRange     = 3,       --// відстань, з якої чіпаємо монету
    PromptRange   = 8,       --// відстань, з якої тиснемо ProximityPrompt
    TargetRefresh = 0.25,
    MaxTargetTime = 4,
    CacheTTL      = 3,       --// як часто повний перескан workspace
    AntiAFK       = true,
    Noclip        = true,
    Verbose       = true,
}
--// ============================================================
--//  STATE
--// ============================================================
local State = {
    conn        = nil,
    respawn     = nil,
    afkConn     = nil,
    --// масив + окремий set для швидкої перевірки
    coins       = {},
    coinSet     = {},
    cacheTime   = 0,
    target      = nil,
    targetAt    = 0,
    lastTarget  = 0,
    flyAtt      = nil,
    flyVel      = nil,
    noclipConn  = nil,
    noclipSaved = {},     --// part -> оригінальний CanCollide
    collected   = 0,
    promptTry   = 0,
    promptObj   = nil,
}
local Farm = {}
Farm.__index = Farm
function Farm.new()
    return setmetatable({}, Farm)
end
local function log(msg)
    if CONFIG.Verbose then print("[AutoFarm] " .. tostring(msg)) end
end
--// ============================================================
--//  CHARACTER
--// ============================================================
local function getChar()
    local char = LocalPlayer.Character
    if not char then return nil, nil, nil end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hum or not hrp then return nil, nil, nil end
    if hum.Health <= 0 then return nil, nil, nil end
    return char, hum, hrp
end
--// ============================================================
--//  NOCLIP
--// ============================================================
--// Головний фікс: запам'ятовуємо, що було, і вертаємо САМЕ ЦЕ.
--// Було p.CanCollide = true для всього — аксесуари ставали твердими.
local function noclipTick()
    if not CONFIG.Enabled or not CONFIG.Noclip then return end
    local char = LocalPlayer.Character
    if not char then return end
    for _, p in ipairs(char:GetDescendants()) do
        if p:IsA("BasePart") and p.CanCollide then
            --// зберігаємо оригінал лише один раз
            if State.noclipSaved[p] == nil then
                State.noclipSaved[p] = true
            end
            p.CanCollide = false
        end
    end
end
local function enableNoclip()
    if State.noclipConn then
        State.noclipConn:Disconnect()
        State.noclipConn = nil
    end
    if not CONFIG.Noclip then return end
    --// 5 разів на секунду замість 60 — CanCollide не треба частіше
    local acc = 0
    State.noclipConn = RunService.Heartbeat:Connect(function(dt)
        if not CONFIG.Enabled or not CONFIG.Noclip then return end
        acc = acc + dt
        if acc < 0.2 then return end
        acc = 0
        noclipTick()
    end)
end
local function disableNoclip()
    if State.noclipConn then
        State.noclipConn:Disconnect()
        State.noclipConn = nil
    end
    local char = LocalPlayer.Character
    if char then
        for _, p in ipairs(char:GetDescendants()) do
            if p:IsA("BasePart") and State.noclipSaved[p] ~= nil then
                --// вертаємо ТІЛЬКИ те, що самі змінили
                pcall(function() p.CanCollide = true end)
            end
        end
    end
    State.noclipSaved = {}
end
--// ============================================================
--//  FLY
--// ============================================================
--// Прибрано AlignOrientation: RigidityEnabled = true фіксував
--// орієнтацію персонажа і ламав керування камерою.
local function setupFly()
    local _, hum, hrp = getChar()
    if not hrp then return false end
    if hum then
        pcall(function() hum.PlatformStand = true end)
    end
    if State.flyVel then State.flyVel:Destroy() end
    if State.flyAtt then State.flyAtt:Destroy() end
    State.flyAtt = Instance.new("Attachment")
    State.flyAtt.Name = "TrustHubAF_Att"
    State.flyAtt.Parent = hrp
    State.flyVel = Instance.new("LinearVelocity")
    State.flyVel.Name = "TrustHubAF_Vel"
    State.flyVel.Attachment0 = State.flyAtt
    State.flyVel.MaxForce = math.huge
    State.flyVel.RelativeTo = Enum.ActuatorRelativeTo.World
    State.flyVel.VectorVelocity = Vector3.zero
    State.flyVel.Parent = hrp
    log("Fly: " .. CONFIG.FlySpeed)
    return true
end
local function stopFly()
    if State.flyVel then State.flyVel:Destroy(); State.flyVel = nil end
    if State.flyAtt then State.flyAtt:Destroy(); State.flyAtt = nil end
    local _, hum = getChar()
    if hum then
        pcall(function() hum.PlatformStand = false end)
    end
end
--// ============================================================
--//  ПОШУК МОНЕТ
--// ============================================================
--// Головний фікс: масив замість словника.
--// Було coinCache[obj] = true -> #coinCache == 0 завжди ->
--// "всі монети зібрані" через 2 секунди після старту.
local function isCoin(obj)
    if not obj or not obj.Parent then return false end
    if not obj:IsA("BasePart") then return false end
    if obj.Name == "Coin" then return true end
    --// деякі збірки кладуть монету в Model ім'ям Coin
    local parent = obj.Parent
    if parent and parent:IsA("Model") and parent.Name == "Coin" then
        return true
    end
    return false
end
local function rebuildCache()
    local coins, set = {}, {}
    for _, obj in ipairs(workspace:GetDescendants()) do
        if isCoin(obj) then
            table.insert(coins, obj)
            set[obj] = true
        end
    end
    State.coins     = coins
    State.coinSet   = set
    State.cacheTime = os.clock()
    return #coins
end
local function refreshCacheIfNeeded()
    if (os.clock() - State.cacheTime) > CONFIG.CacheTTL then
        return rebuildCache()
    end
    return #State.coins
end
--// DescendantAdded більше не пише в словник напряму —
--// просто позначає кеш застарілим, щоб лічильник не брехав
workspace.DescendantAdded:Connect(function(obj)
    if isCoin(obj) then
        State.cacheTime = 0
    end
end)
workspace.DescendantRemoving:Connect(function(obj)
    if State.coinSet[obj] then
        State.cacheTime = 0
    end
end)
local function findNearestCoin()
    local _, _, hrp = getChar()
    if not hrp then return nil, nil end
    local best, bestDist, bestPos = nil, math.huge, nil
    --// чистимо зниклі монети з масиву
    local live = {}
    local myPos = hrp.Position
    for _, coin in ipairs(State.coins) do
        if coin.Parent then
            table.insert(live, coin)
            local d = (myPos - coin.Position).Magnitude
            if d < bestDist then
                best, bestDist, bestPos = coin, d, coin.Position
            end
        else
            State.coinSet[coin] = nil
        end
    end
    State.coins = live
    return best, bestPos
end
--// ============================================================
--//  ЗБІР МОНЕТИ
--// ============================================================
--// Фікс: якщо монета збирається ProximityPrompt, політ у неї
--// не давав нічого. Тепер промпт реально спрацьовує.
local function tryCollect(coin, dist)
    if not coin or not coin.Parent then return end
    local prompt = coin:FindFirstChildOfClass("ProximityPrompt")
    if not prompt or not prompt.Enabled then return end
    if dist > CONFIG.PromptRange then return end
    --// тротл: не смикаємо той самий промпт частіше ніж раз на 0.4с
    local now = os.clock()
    if State.promptObj == coin and (now - State.promptTry) < 0.4 then return end
    State.promptObj = coin
    State.promptTry = now
    pcall(function()
        if fireproximityprompt then
            fireproximityprompt(prompt)
        else
            prompt:InputHoldBegin()
            task.delay(math.max(prompt.HoldDuration, 0.05), function()
                if prompt and prompt.Parent then prompt:InputHoldEnd() end
            end)
        end
    end)
end
--// ============================================================
--//  ГОЛОВНИЙ ЦИКЛ
--// ============================================================
local roundTimer = 0
local function startMainLoop()
    if State.conn then State.conn:Disconnect() end
    State.conn = RunService.Heartbeat:Connect(function(dt)
        if not CONFIG.Enabled then return end
        local _, _, hrp = getChar()
        if not hrp or not State.flyVel then return end
        --// періодичний перескан
        roundTimer = roundTimer + dt
        if roundTimer > CONFIG.CacheTTL then
            roundTimer = 0
            refreshCacheIfNeeded()
        end
        --// монета зникла — зараховано
        if State.target and not State.target.Parent then
            State.collected = State.collected + 1
            State.coinSet[State.target] = nil
            log("Монета зібрана. Всього: " .. State.collected)
            State.target = nil
        end
        --// вибір цілі
        local now = os.clock()
        if not State.target then
            if (now - State.lastTarget) > CONFIG.TargetRefresh then
                State.lastTarget = now
                State.target = findNearestCoin()
                if State.target then
                    State.targetAt = now
                end
            end
        end
        local coin = State.target
        if not coin or not coin.Parent then
            State.flyVel.VectorVelocity = Vector3.zero
            return
        end
        --// рух до цілі
        local pos  = coin.Position
        local dir  = pos - hrp.Position
        local dist = dir.Magnitude
        if dist > 0.5 then
            --// гальмуємо на підході, інакше проскакуємо монету
            local mul = 1
            if dist < 5 then
                mul = math.clamp(dist / 5, 0.3, 1)
            end
            State.flyVel.VectorVelocity = dir.Unit * CONFIG.FlySpeed * mul
        else
            State.flyVel.VectorVelocity = Vector3.zero
        end
        --// пробуємо промпт заздалегідь, ще на підльоті
        tryCollect(coin, dist)
        --// таймаут: монету не взяти, скіпаємо
        if (now - State.targetAt) > CONFIG.MaxTargetTime then
            log("Таймаут на монеті, скіпаю")
            State.target = nil
            State.cacheTime = 0
        end
    end)
end
local function stopMainLoop()
    if State.conn then
        State.conn:Disconnect()
        State.conn = nil
    end
end
--// ============================================================
--//  АНТИ-AFK
--// ============================================================
local function startAntiAFK()
    if State.afkConn then State.afkConn:Disconnect() end
    State.afkConn = LocalPlayer.Idled:Connect(function()
        if not CONFIG.AntiAFK then return end
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
        end)
    end)
end
--// ============================================================
--//  СКИДАННЯ СТАНУ
--// ============================================================
local function resetState()
    State.target    = nil
    State.targetAt  = 0
    State.lastTarget = 0
    State.cacheTime = 0
    rebuildCache()
    log("Стан скинуто, монет на карті: " .. #State.coins)
end
--// ============================================================
--//  API ДЛЯ UI
--// ============================================================
function Farm:setEnabled(value)
    value = not not value
    CONFIG.Enabled = value
    if value then
        resetState()
        startAntiAFK()
        local _, hum = getChar()
        if hum then
            pcall(function() hum.WalkSpeed = CONFIG.WalkSpeed end)
        end
        enableNoclip()
        task.wait(0.2)
        setupFly()
        startMainLoop()
        log("═══ УВІМКНЕНО (walk " .. CONFIG.WalkSpeed .. ", fly " .. CONFIG.FlySpeed .. ") ═══")
    else
        stopMainLoop()
        stopFly()
        disableNoclip()
        if State.afkConn then
            State.afkConn:Disconnect()
            State.afkConn = nil
        end
        --// повертаємо нормальну швидкість
        local _, hum = getChar()
        if hum then
            pcall(function() hum.WalkSpeed = 16 end)
        end
        log("ВИМКНЕНО")
    end
end
function Farm:setSpeed(v)
    CONFIG.WalkSpeed = math.clamp(tonumber(v) or CONFIG.WalkSpeed, 8, 200)
    CONFIG.FlySpeed  = CONFIG.WalkSpeed
    local _, hum = getChar()
    if hum and CONFIG.Enabled then
        pcall(function() hum.WalkSpeed = CONFIG.WalkSpeed end)
    end
end
function Farm:setFlySpeed(v)
    CONFIG.FlySpeed = math.clamp(tonumber(v) or CONFIG.FlySpeed, 8, 200)
end
function Farm:setKillDelay(v)
    --// вбивств ми не робимо, тому слайдер керує таймаутом на монету
    CONFIG.MaxTargetTime = math.clamp(tonumber(v) or 4, 1, 20)
end
function Farm:getStats()
    return {
        CoinsCollected = State.collected,
        CoinsRemaining = #State.coins,
        WalkSpeed      = CONFIG.WalkSpeed,
        FlySpeed       = CONFIG.FlySpeed,
    }
end
--// діагностика: показує, що реально є на карті
function Farm:diagnostics()
    local n = rebuildCache()
    print("═══════ AutoFarm діагностика ═══════")
    print(("  монет у workspace: %d"):format(n))
    print(("  зібрано:           %d"):format(State.collected))
    print(("  ціль:              %s"):format(State.target and State.target.Name or "немає"))
    print(("  WalkSpeed:         %d"):format(CONFIG.WalkSpeed))
    print(("  fly активний:      %s"):format(tostring(State.flyVel ~= nil)))
    for i = 1, math.min(n, 8) do
        local c = State.coins[i]
        local prompt = c:FindFirstChildOfClass("ProximityPrompt")
        print(("    %d) %s  prompt=%s"):format(i, c.Name, tostring(prompt ~= nil)))
    end
    if n == 0 then
        print("  ⚠ Монет немає. У MM2 вони з'являються лише коли хтось помирає,")
        print("    і сервер може їх не показувати клієнту взагалі.")
    end
    print("════════════════════════════════════")
end
function Farm:isEnabled()
    return CONFIG.Enabled
end
function Farm:destroy()
    CONFIG.Enabled = false
    stopMainLoop()
    stopFly()
    disableNoclip()
    if State.afkConn then State.afkConn:Disconnect() end
    if State.respawn then State.respawn:Disconnect() end
end
--// ============================================================
--//  RESPAWN
--// ============================================================
State.respawn = LocalPlayer.CharacterAdded:Connect(function(char)
    State.noclipSaved = {}
    if not CONFIG.Enabled then return end
    local hum = char:WaitForChild("Humanoid", 5)
    local hrp = char:WaitForChild("HumanoidRootPart", 5)
    if not hum or not hrp then return end
    pcall(function() hum.WalkSpeed = CONFIG.WalkSpeed end)
    task.wait(0.3)
    if not CONFIG.Enabled then return end
    enableNoclip()
    setupFly()
    startMainLoop()
    resetState()
end)
log("AutoFarm v13.0 — Завантажено")
return Farm.new()
