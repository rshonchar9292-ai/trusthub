--// ╔══════════════════════════════════════════════════════════════════╗
--// ║  TrustHub Fling — FULL EDITION                                   ║
--// ║  All 3 methods from source: SkidFling, shhhlol, yeet             ║
--// ║  + Anti-Fling, Anti-Kill Parts, FPD Protection, Touch Fling      ║
--// ╚══════════════════════════════════════════════════════════════════╝

local Players      = game:GetService("Players")
local RunService   = game:GetService("RunService")
local StarterGui   = game:GetService("StarterGui")

local LocalPlayer = Players.LocalPlayer

--// ============================================================
--//  STATE
--// ============================================================
local flingActive = false
local flingMode = 1  -- 1 = SkidFling, 2 = shhhlol, 3 = yeet
local hiddenfling = false  -- Touch Fling
local AntiFlingEnabled = false
local AntiKillPartsEnabled = false
local FPDProtectionEnabled = false
local isNoclipEnabled = false

local SteppedConnection = nil
local antiKillPartsLoop = nil
local fpdProtectionLoop = nil
local oldNewIndex = nil
local touchFlingConn = nil

--// ============================================================
--//  UTILS
--// ============================================================
local function notify(title, text, duration)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = title,
            Text = text,
            Duration = duration or 3,
        })
    end)
end

local function log(msg) print("[Fling] " .. msg) end
local function logOK(msg) print("[Fling] ✓ " .. msg) end
local function logErr(msg) warn("[Fling] ✗ " .. msg) end

--// ============================================================
--//  ROLE DETECTION
--// ============================================================
local function getRole(player)
    if not player then return "Dead" end
    local char = player.Character
    if not char then return "Dead" end

    for _, tool in ipairs(char:GetChildren()) do
        if tool:IsA("Tool") then
            local n = tool.Name:lower()
            if n:find("knife") or n:find("blade") or n:find("murder")
               or n:find("dagger") or n:find("sword") or n:find("kukri") then
                return "Murderer"
            end
        end
    end

    for _, tool in ipairs(char:GetChildren()) do
        if tool:IsA("Tool") then
            local n = tool.Name:lower()
            if n:find("gun") or n:find("pistol") or n:find("sheriff")
               or n:find("revolver") or n:find("magnum") or n:find("shoot") then
                return "Sheriff"
            end
        end
    end

    local bp = player:FindFirstChild("Backpack")
    if bp then
        for _, tool in ipairs(bp:GetChildren()) do
            if tool:IsA("Tool") then
                local n = tool.Name:lower()
                if n:find("gun") or n:find("pistol") or n:find("sheriff")
                   or n:find("revolver") or n:find("magnum") then
                    return "Sheriff"
                end
                if n:find("knife") or n:find("blade") or n:find("murder")
                   or n:find("dagger") then
                    return "Murderer"
                end
            end
        end
    end

    return "Innocent"
end

local function getRoleColor(role)
    if role == "Murderer" then return Color3.fromRGB(255, 50, 50)
    elseif role == "Sheriff" then return Color3.fromRGB(50, 150, 255)
    elseif role == "Innocent" then return Color3.fromRGB(50, 220, 100)
    else return Color3.fromRGB(150, 150, 150)
    end
end

local function isAlive(plr)
    if not plr then return false end
    local char = plr.Character
    if not char then return false end
    local hum = char:FindFirstChildOfClass("Humanoid")
    return hum and hum.Health > 0
end

--// ============================================================
--//  METHOD 1: SKIDFLING (з твого файлу, 1-в-1)
--// ============================================================
local function SkidFling(TargetPlayer, duration)
    local startTime = tick()
    local Character = LocalPlayer.Character
    local Humanoid = Character and Character:FindFirstChildOfClass("Humanoid")
    local RootPart = Humanoid and Humanoid.RootPart

    local TCharacter = TargetPlayer.Character
    local THumanoid
    local TRootPart
    local THead
    local Accessory
    local Handle

    if TCharacter:FindFirstChildOfClass("Humanoid") then
        THumanoid = TCharacter:FindFirstChildOfClass("Humanoid")
    end
    if THumanoid and THumanoid.RootPart then
        TRootPart = THumanoid.RootPart
    end
    if TCharacter:FindFirstChild("Head") then
        THead = TCharacter.Head
    end
    if TCharacter:FindFirstChildOfClass("Accessory") then
        Accessory = TCharacter:FindFirstChildOfClass("Accessory")
    end
    if Accessory and Accessory:FindFirstChild("Handle") then
        Handle = Accessory.Handle
    end

    if Character and Humanoid and RootPart then
        if RootPart.Velocity.Magnitude < 50 then
            getgenv().OldPos = RootPart.CFrame
        end
        if THead then
            workspace.CurrentCamera.CameraSubject = THead
        elseif not THead and Handle then
            workspace.CurrentCamera.CameraSubject = Handle
        elseif THumanoid and TRootPart then
            workspace.CurrentCamera.CameraSubject = THumanoid
        end
        if not TCharacter:FindFirstChildWhichIsA("BasePart") then
            return
        end

        local FPos = function(BasePart, Pos, Ang)
            RootPart.CFrame = CFrame.new(BasePart.Position) * Pos * Ang
            Character:SetPrimaryPartCFrame(CFrame.new(BasePart.Position) * Pos * Ang)
            RootPart.Velocity = Vector3.new(9e7, 9e7 * 10, 9e7)
            RootPart.RotVelocity = Vector3.new(9e8, 9e8, 9e8)
        end

        local SFBasePart = function(BasePart)
            local TimeToWait = duration or 2
            local Time = tick()
            local Angle = 0

            repeat
                if RootPart and THumanoid then
                    if BasePart.Velocity.Magnitude < 50 then
                        Angle = Angle + 100

                        FPos(BasePart, CFrame.new(0, 1.5, 0) + THumanoid.MoveDirection * BasePart.Velocity.Magnitude / 1.25, CFrame.Angles(math.rad(Angle),0 ,0))
                        task.wait()

                        FPos(BasePart, CFrame.new(0, -1.5, 0) + THumanoid.MoveDirection * BasePart.Velocity.Magnitude / 1.25, CFrame.Angles(math.rad(Angle), 0, 0))
                        task.wait()

                        FPos(BasePart, CFrame.new(2.25, 1.5, -2.25) + THumanoid.MoveDirection * BasePart.Velocity.Magnitude / 1.25, CFrame.Angles(math.rad(Angle), 0, 0))
                        task.wait()

                        FPos(BasePart, CFrame.new(-2.25, -1.5, 2.25) + THumanoid.MoveDirection * BasePart.Velocity.Magnitude / 1.25, CFrame.Angles(math.rad(Angle), 0, 0))
                        task.wait()

                        FPos(BasePart, CFrame.new(0, 1.5, 0) + THumanoid.MoveDirection,CFrame.Angles(math.rad(Angle), 0, 0))
                        task.wait()

                        FPos(BasePart, CFrame.new(0, -1.5, 0) + THumanoid.MoveDirection,CFrame.Angles(math.rad(Angle), 0, 0))
                        task.wait()
                    else
                        FPos(BasePart, CFrame.new(0, 1.5, THumanoid.WalkSpeed), CFrame.Angles(math.rad(90), 0, 0))
                        task.wait()

                        FPos(BasePart, CFrame.new(0, -1.5, -THumanoid.WalkSpeed), CFrame.Angles(0, 0, 0))
                        task.wait()

                        FPos(BasePart, CFrame.new(0, 1.5, THumanoid.WalkSpeed), CFrame.Angles(math.rad(90), 0, 0))
                        task.wait()

                        FPos(BasePart, CFrame.new(0, 1.5, TRootPart.Velocity.Magnitude / 1.25), CFrame.Angles(math.rad(90), 0, 0))
                        task.wait()

                        FPos(BasePart, CFrame.new(0, -1.5, -TRootPart.Velocity.Magnitude / 1.25), CFrame.Angles(0, 0, 0))
                        task.wait()

                        FPos(BasePart, CFrame.new(0, 1.5, TRootPart.Velocity.Magnitude / 1.25), CFrame.Angles(math.rad(90), 0, 0))
                        task.wait()

                        FPos(BasePart, CFrame.new(0, -1.5, 0), CFrame.Angles(math.rad(90), 0, 0))
                        task.wait()

                        FPos(BasePart, CFrame.new(0, -1.5, 0), CFrame.Angles(0, 0, 0))
                        task.wait()

                        FPos(BasePart, CFrame.new(0, -1.5 ,0), CFrame.Angles(math.rad(-90), 0, 0))
                        task.wait()

                        FPos(BasePart, CFrame.new(0, -1.5, 0), CFrame.Angles(0, 0, 0))
                        task.wait()
                    end
                else
                    break
                end
            until not flingActive or BasePart.Velocity.Magnitude > 500 or BasePart.Parent ~= TargetPlayer.Character or TargetPlayer.Parent ~= Players or not TargetPlayer.Character == TCharacter or THumanoid.Sit or tick() > Time + TimeToWait
        end

        local previousDestroyHeight = workspace.FallenPartsDestroyHeight
        workspace.FallenPartsDestroyHeight = 0/0

        local BV = Instance.new("BodyVelocity")
        BV.Name = "EpixVel"
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
        elseif TRootPart and not THead then
            SFBasePart(TRootPart)
        elseif not TRootPart and THead then
            SFBasePart(THead)
        elseif not TRootPart and not THead and Accessory and Handle then
            SFBasePart(Handle)
        end

        BV:Destroy()
        Humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, true)
        workspace.CurrentCamera.CameraSubject = Humanoid

        repeat
            if Character and Humanoid and RootPart and getgenv().OldPos then
                RootPart.CFrame = getgenv().OldPos * CFrame.new(0, .5, 0)
                Character:SetPrimaryPartCFrame(getgenv().OldPos * CFrame.new(0, .5, 0))
                Humanoid:ChangeState("GettingUp")
                table.foreach(Character:GetChildren(), function(_, x)
                    if x:IsA("BasePart") then
                        x.Velocity, x.RotVelocity = Vector3.new(), Vector3.new()
                    end
                end)
            end
            task.wait()
        until not flingActive or (RootPart and getgenv().OldPos and (RootPart.Position - getgenv().OldPos.p).Magnitude < 25)
        workspace.FallenPartsDestroyHeight = previousDestroyHeight
    end
end

--// ============================================================
--//  METHOD 2: SHHHLOL (з твого файлу, 1-в-1)
--// ============================================================
local function shhhlol(TargetPlayer)
    local Character = LocalPlayer.Character
    local Humanoid = Character and Character:FindFirstChildOfClass("Humanoid")
    local RootPart = Humanoid and Humanoid.RootPart

    local TCharacter = TargetPlayer.Character
    local THumanoid = TCharacter and TCharacter:FindFirstChildOfClass("Humanoid")
    local TRootPart = THumanoid and THumanoid.RootPart
    local THead = TCharacter and TCharacter:FindFirstChild("Head")

    if Character and Humanoid and RootPart then
        if RootPart.Velocity.Magnitude < 50 then
            getgenv().OldPos = RootPart.CFrame
        end

        if not TCharacter:FindFirstChildWhichIsA("BasePart") then return end

        local function mmmm(comkid, Pos, Ang)
            RootPart.CFrame = CFrame.new(comkid.Position) * Pos * Ang
            RootPart.RotVelocity = Vector3.new(9e8, 9e8, 9e8)
        end

        local function wtf(comkid)
            local TimeToWait = 0.134
            local Time = tick()

            local Att1 = Instance.new("Attachment", RootPart)
            local Att2 = Instance.new("Attachment", comkid)

            repeat
                if RootPart and THumanoid then
                    if comkid.Velocity.Magnitude < 30 then
                        mmmm(
                            comkid,
                            CFrame.new(0, 1.5, 0) + THumanoid.MoveDirection * comkid.Velocity.Magnitude / 5,
                            CFrame.Angles(
                                math.random(1, 2) == 1 and math.rad(0) or math.rad(180),
                                math.random(1, 2) == 1 and math.rad(0) or math.rad(180),
                                math.random(1, 2) == 1 and math.rad(0) or math.rad(180)
                            )
                        )
                        task.wait()

                        mmmm(
                            comkid,
                            CFrame.new(0, 1.5, 0) + THumanoid.MoveDirection * comkid.Velocity.Magnitude / 1.25,
                            CFrame.Angles(
                                math.random(1, 2) == 1 and math.rad(0) or math.rad(180),
                                math.random(1, 2) == 1 and math.rad(0) or math.rad(180),
                                math.random(1, 2) == 1 and math.rad(0) or math.rad(180)
                            )
                        )
                        task.wait()

                        mmmm(
                            comkid,
                            CFrame.new(0, -1.5, 0) + THumanoid.MoveDirection * comkid.Velocity.Magnitude / 1.25,
                            CFrame.Angles(
                                math.random(1, 2) == 1 and math.rad(0) or math.rad(180),
                                math.random(1, 2) == 1 and math.rad(0) or math.rad(180),
                                math.random(1, 2) == 1 and math.rad(0) or math.rad(180)
                            )
                        )
                        task.wait()
                    else
                        mmmm(comkid, CFrame.new(0, -1.5, 0), CFrame.Angles(math.rad(0), 0, 0))
                        task.wait()
                    end
                else
                    break
                end
            until comkid.Velocity.Magnitude > 1000 or 
                  comkid.Parent ~= TargetPlayer.Character or
                  TargetPlayer.Parent ~= Players or
                  not TargetPlayer.Character == TCharacter or
                  Humanoid.Health <= 0 or
                  tick() > Time + TimeToWait or
                  not flingActive

            Att1:Destroy()
            Att2:Destroy()
        end

        local previousDestroyHeight = workspace.FallenPartsDestroyHeight
        workspace.FallenPartsDestroyHeight = 0/0

        local BV = Instance.new("BodyVelocity")
        BV.Parent = RootPart
        BV.Velocity = Vector3.new(-9e99, 9e99, -9e99)
        BV.MaxForce = Vector3.new(-9e9, 9e9, -9e9)

        local BodyGyro = Instance.new("BodyGyro")
        BodyGyro.CFrame = CFrame.new(RootPart.Position)
        BodyGyro.D = 9e8
        BodyGyro.MaxTorque = Vector3.new(-9e9, 9e9, -9e9)
        BodyGyro.P = -9e9

        local BodyPosition = Instance.new("BodyPosition")
        BodyPosition.Position = RootPart.Position
        BodyPosition.D = 9e8
        BodyPosition.MaxForce = Vector3.new(-9e9, 9e9, -9e9)
        BodyPosition.P = -9e9

        if TRootPart and THead then
            if (TRootPart.CFrame.p - THead.CFrame.p).Magnitude > 5 then
                wtf(THead)
            else
                wtf(TRootPart)
            end
        elseif TRootPart and not THead then
            wtf(TRootPart)
        elseif not TRootPart and THead then
            wtf(THead)
        end

        BV:Destroy()
        BodyGyro:Destroy()
        BodyPosition:Destroy()

        repeat
            if Character and Humanoid and RootPart and getgenv().OldPos then
                RootPart.CFrame = getgenv().OldPos * CFrame.new(0, .5, 0)
                Character:SetPrimaryPartCFrame(getgenv().OldPos * CFrame.new(0, .5, 0))
                Humanoid:ChangeState("GettingUp")
                for _, x in pairs(Character:GetDescendants()) do
                    if x:IsA("BasePart") then
                        x.Velocity, x.RotVelocity = Vector3.new(), Vector3.new()
                    end
                end
            end
            task.wait()
        until not flingActive or (RootPart and getgenv().OldPos and (RootPart.Position - getgenv().OldPos.p).Magnitude < 25)

        workspace.FallenPartsDestroyHeight = previousDestroyHeight
    end
end

--// ============================================================
--//  METHOD 3: YEET (з твого файлу, 1-в-1)
--// ============================================================
local function yeet(targetPlayer, duration)
    local lp = LocalPlayer
    local character = lp.Character
    local targetCharacter = targetPlayer.Character

    if not character or not targetCharacter or not targetCharacter:FindFirstChild("HumanoidRootPart") then
        return false
    end

    if character.HumanoidRootPart.Velocity.Magnitude < 50 then
        getgenv().OldPos = character.HumanoidRootPart.CFrame
    end

    local existingForce = character.HumanoidRootPart:FindFirstChild("YeetForce")
    if existingForce then
        existingForce:Destroy()
    end

    local Thrust = Instance.new('BodyThrust', character.HumanoidRootPart)
    Thrust.Force = Vector3.new(9999, 9999, 9999)
    Thrust.Name = "YeetForce"

    local previousDestroyHeight = workspace.FallenPartsDestroyHeight
    workspace.FallenPartsDestroyHeight = 0/0

    local startTime = tick()
    local dur = duration or 5

    local yeetConnection
    yeetConnection = RunService.Heartbeat:Connect(function()
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        if not targetCharacter or not targetCharacter:FindFirstChild("HumanoidRootPart") 
           or not flingActive or tick() > startTime + dur 
           or (humanoid and humanoid.Health <= 0) then
            yeetConnection:Disconnect()
            Thrust:Destroy()
            workspace.FallenPartsDestroyHeight = previousDestroyHeight

            if character and character.HumanoidRootPart and getgenv().OldPos then
                character.HumanoidRootPart.CFrame = getgenv().OldPos * CFrame.new(0, .5, 0)
                character.Humanoid:ChangeState("GettingUp")
                for _, x in pairs(character:GetDescendants()) do
                    if x:IsA("BasePart") then
                        x.Velocity, x.RotVelocity = Vector3.new(), Vector3.new()
                    end
                end
            end
            return
        end

        local targetHRP = targetCharacter.HumanoidRootPart
        local targetVelocity = targetHRP.Velocity
        local speed = targetVelocity.Magnitude
        local direction = targetVelocity.Unit
        local ping = lp:GetNetworkPing()

        local offsetPosition
        if speed > 0.1 then
            offsetPosition = targetHRP.Position + (direction * speed * ping)
        else
            offsetPosition = targetHRP.Position + Vector3.new(0, 0, 0)
        end

        character.HumanoidRootPart.CFrame = CFrame.new(offsetPosition)
        Thrust.Location = targetHRP.Position
    end)

    return true
end

--// ============================================================
--//  UNIFIED FLING
--// ============================================================
local function flingPlayer(target, overrideMode)
    if not target or target == LocalPlayer then return false end
    if not isAlive(target) then return false end

    flingActive = true
    local mode = overrideMode or flingMode

    task.spawn(function()
        local ok, err
        if mode == 1 then
            ok, err = pcall(SkidFling, target, 2)
        elseif mode == 2 then
            ok, err = pcall(shhhlol, target)
        elseif mode == 3 then
            ok, err = pcall(yeet, target, 3)
        end
        if not ok then
            logErr("Error: " .. tostring(err))
        else
            logOK("Fling done: " .. target.Name)
        end
        flingActive = false
    end)

    log("Flinging: " .. target.Name .. " (" .. getRole(target) .. ") mode=" .. mode)
    return true
end

local function flingRole(role)
    local count = 0
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == LocalPlayer then continue end
        if not isAlive(plr) then continue end
        if getRole(plr) ~= role then continue end

        flingPlayer(plr)
        count = count + 1
        task.wait(2.5)
    end

    if count > 0 then
        notify("💥 Fling " .. role, "Flinged " .. count .. " player(s)", 3)
    else
        notify("💥 Fling " .. role, "No " .. role .. " found", 2)
    end
    return count
end

local function flingSheriff() return flingRole("Sheriff") end
local function flingMurderer() return flingRole("Murderer") end
local function flingInnocent() return flingRole("Innocent") end

--// ============================================================
--//  TOUCH FLING (з твого файлу)
--// ============================================================
local function fling()
    local lp = Players.LocalPlayer
    local c, hrp, vel, movel = nil, nil, nil, 0.1

    while hiddenfling do
        RunService.Heartbeat:Wait()
        c = lp.Character
        hrp = c and c:FindFirstChild("HumanoidRootPart")

        if hrp then
            vel = hrp.Velocity
            hrp.Velocity = vel * 1e35 + Vector3.new(0, 1e35, 0)
            RunService.RenderStepped:Wait()
            hrp.Velocity = vel
            RunService.Stepped:Wait()
            hrp.Velocity = vel + Vector3.new(0, movel, 0)
            movel = -movel
        end
    end
end

local function setTouchFling(state)
    hiddenfling = state
    if state then
        coroutine.wrap(fling)()
        notify("💥 Touch Fling", "ON", 2)
    else
        notify("💥 Touch Fling", "OFF", 2)
    end
end

LocalPlayer.CharacterAdded:Connect(function()
    if hiddenfling then
        coroutine.wrap(fling)()
    end
end)

--// ============================================================
--//  ANTI-FLING (з твого файлу)
--// ============================================================
local function setCanCollideOfModelDescendants(model, bval)
    if not model then return end
    for _, v in pairs(model:GetDescendants()) do
        if v:IsA("BasePart") then
            v.CanCollide = bval
        end
    end
end

local function setAntiFling(state)
    AntiFlingEnabled = state
    if state then
        for _, v in pairs(Players:GetPlayers()) do
            if v ~= LocalPlayer and v.Character then
                setCanCollideOfModelDescendants(v.Character, false)
            end
        end
        notify("🛡 Anti-Fling", "ON", 2)
    else
        for _, v in pairs(Players:GetPlayers()) do
            if v ~= LocalPlayer and v.Character then
                setCanCollideOfModelDescendants(v.Character, true)
            end
        end
        notify("🛡 Anti-Fling", "OFF", 2)
    end
end

RunService.Stepped:Connect(function()
    if not AntiFlingEnabled then return end
    for _, v in pairs(Players:GetPlayers()) do
        if v ~= LocalPlayer and v.Character then
            setCanCollideOfModelDescendants(v.Character, false)
        end
    end
end)

--// ============================================================
--//  ANTI-KILL PARTS (з твого файлу)
--// ============================================================
local function setAntiKillParts(state)
    AntiKillPartsEnabled = state
    if state then
        if antiKillPartsLoop then antiKillPartsLoop:Disconnect() end
        antiKillPartsLoop = RunService.Heartbeat:Connect(function()
            if not AntiKillPartsEnabled then return end
            local character = LocalPlayer.Character
            if not character then return end
            local hrp = character:FindFirstChild("HumanoidRootPart")
            if not hrp then return end
            local parts = workspace:GetPartBoundsInRadius(hrp.Position, 10)
            for _, part in ipairs(parts) do
                part.CanTouch = false
            end
        end)
        notify("🛡 Anti-Kill Parts", "ON", 2)
    else
        if antiKillPartsLoop then
            antiKillPartsLoop:Disconnect()
            antiKillPartsLoop = nil
        end
        notify("🛡 Anti-Kill Parts", "OFF", 2)
    end
end

--// ============================================================
--//  FPD PROTECTION (з твого файлу)
--// ============================================================
local function setFPDProtection(state)
    FPDProtectionEnabled = state

    if state then
        workspace.FallenPartsDestroyHeight = 0/0

        -- Спроба захукати __newindex
        pcall(function()
            local mt = getrawmetatable(workspace)
            oldNewIndex = mt.__newindex
            setreadonly(mt, false)
            mt.__newindex = function(t, k, v)
                if k == "FallenPartsDestroyHeight" then
                    rawset(t, k, 0/0)
                    return
                end
                if oldNewIndex then oldNewIndex(t, k, v) end
            end
            setreadonly(mt, true)
        end)

        if fpdProtectionLoop then fpdProtectionLoop:Disconnect() end
        fpdProtectionLoop = RunService.Heartbeat:Connect(function()
            pcall(function()
                if workspace.FallenPartsDestroyHeight ~= workspace.FallenPartsDestroyHeight then return end
                workspace.FallenPartsDestroyHeight = 0/0
            end)
        end)

        notify("🛡 FPD Protection", "ON", 2)
    else
        if fpdProtectionLoop then
            fpdProtectionLoop:Disconnect()
            fpdProtectionLoop = nil
        end
        pcall(function()
            if oldNewIndex then
                local mt = getrawmetatable(workspace)
                setreadonly(mt, false)
                mt.__newindex = oldNewIndex
                setreadonly(mt, true)
            end
        end)
        notify("🛡 FPD Protection", "OFF", 2)
    end
end

--// ============================================================
--//  NOCLIP (з твого файлу)
--// ============================================================
local function enableNoclip()
    if SteppedConnection then return end
    SteppedConnection = RunService.Stepped:Connect(function()
        local character = LocalPlayer.Character
        if character then
            for _, v in pairs(character:GetChildren()) do
                if v:IsA("BasePart") then
                    v.CanCollide = false
                end
            end
        end
    end)
end

local function disableNoclip()
    if SteppedConnection then
        SteppedConnection:Disconnect()
        SteppedConnection = nil
        local character = LocalPlayer.Character
        if character then
            for _, v in pairs(character:GetChildren()) do
                if v:IsA("BasePart") then
                    v.CanCollide = true
                end
            end
        end
    end
end

local function setNoclip(state)
    isNoclipEnabled = state
    if state then enableNoclip() else disableNoclip() end
    notify("Noclip", state and "ON" or "OFF", 2)
end

LocalPlayer.CharacterAdded:Connect(function()
    if isNoclipEnabled then enableNoclip() end
end)

--// ============================================================
--//  PLAYER LIST
--// ============================================================
local function getPlayersWithRoles()
    local list = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == LocalPlayer then continue end
        if not plr.Character then continue end
        local role = getRole(plr)
        table.insert(list, {
            player = plr,
            role = role,
            color = getRoleColor(role),
        })
    end
    table.sort(list, function(a, b)
        local order = { Murderer = 1, Sheriff = 2, Innocent = 3, Dead = 4 }
        return (order[a.role] or 99) < (order[b.role] or 99)
    end)
    return list
end

--// ============================================================
--//  MODULE
--// ============================================================
local Fling = {}
Fling.__index = Fling

function Fling.new()
    return setmetatable({}, Fling)
end

-- Заглушки
function Fling:setEnabled(state) setTouchFling(state) end
function Fling:setRange() end
function Fling:setPower() end
function Fling:setVelocity() end
function Fling:setOnlyEnemies() end
function Fling:setAutoRetry() end

-- Головне API
function Fling:flingPlayer(plr, mode) return flingPlayer(plr, mode) end
function Fling:flingSheriff() return flingSheriff() end
function Fling:flingMurderer() return flingMurderer() end
function Fling:flingInnocent() return flingInnocent() end
function Fling:getPlayersWithRoles() return getPlayersWithRoles() end
function Fling:getRole(plr) return getRole(plr) end
function Fling:getRoleColor(role) return getRoleColor(role) end

-- Method switching
function Fling:setMethod(mode) flingMode = mode end
function Fling:getMethod() return flingMode end

-- Utilities
function Fling:setTouchFling(state) setTouchFling(state) end
function Fling:setAntiFling(state) setAntiFling(state) end
function Fling:setAntiKillParts(state) setAntiKillParts(state) end
function Fling:setFPDProtection(state) setFPDProtection(state) end
function Fling:setNoclip(state) setNoclip(state) end

log("═══════════════════════════════════")
log("TrustHub Fling FULL EDITION loaded")
log("Methods: 1=SkidFling  2=shhhlol  3=yeet")
log("═══════════════════════════════════")

return Fling.new()
