--// ============================================================
--// TrustHub Silent Aim v7.0 — Namecall Hook (Ultimate)
--// Перехоплює FireServer від зброї та підміняє координати
--// ============================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local GuiService = game:GetService("GuiService")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

local Config = {
    Enabled = false,
    FOV = 150,
    HitChance = 100,
    Prediction = 2.8,
    Headshot = true,
}

local fovCircle = nil
local oldNamecall = nil
local hooked = false

--// ============================================================
--// FOV CIRCLE
--// ============================================================
local hasDrawing = pcall(function() local d = Drawing.new("Circle"); d:Remove() end)
if hasDrawing then
    fovCircle = Drawing.new("Circle")
    fovCircle.Thickness = 1.5
    fovCircle.NumSides = 64
    fovCircle.Filled = false
    fovCircle.Color = Color3.fromRGB(120, 140, 255)
    fovCircle.Transparency = 0.5
    fovCircle.Visible = false
end

--// ============================================================
--// ПОШУК ВБИВЦІ
--// ============================================================
local function getMurderer()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character then
            local hum = plr.Character:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health > 0 then
                local hasKnife = plr.Character:FindFirstChild("Knife") or (plr:FindFirstChild("Backpack") and plr.Backpack:FindFirstChild("Knife"))
                if hasKnife then
                    return plr
                end
            end
        end
    end
    return nil
end

--// Розрахунок передбачення позиції
local function getPredictedPosition(plr)
    local char = plr.Character
    if not char then return nil end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum then return nil end
    
    local velocity = hrp.AssemblyLinearVelocity
    local position = hrp.Position
    return position + velocity * Vector3.new(0.75, 0.5, 0.75) * (Config.Prediction / 15) + hum.MoveDirection * Config.Prediction
end

--// ============================================================
--// ХУК NAMECALL (Перехоплення FireServer)
--// ============================================================
local function installHook()
    if hooked then return end
    local ok, err = pcall(function()
        local mt = getrawmetatable(game)
        oldNamecall = mt.__namecall
        setreadonly(mt, false)

        mt.__namecall = newcclosure(function(self, ...)
            local method = getnamecallmethod()
            local args = {...}

            if Config.Enabled and not checkcaller() then
                -- Перехоплюємо виклики FireServer / InvokeServer
                if method == "FireServer" or method == "InvokeServer" then
                    local target = getMurderer()
                    if target then
                        local targetPos = getPredictedPosition(target)
                        if targetPos then
                            -- Шукаємо аргументи, які схожі на позицію або CFrame
                            for i, arg in ipairs(args) do
                                local argType = typeof(arg)
                                if argType == "CFrame" then
                                    -- Змінюємо напрямок CFrame на ціль
                                    args[i] = CFrame.new(arg.Position, targetPos)
                                elseif argType == "Vector3" then
                                    -- Змінюємо Vector3 на позицію цілі
                                    args[i] = targetPos
                                end
                            end
                            -- Виводимо в консоль для перевірки
                            print("[SilentAim] Перехоплено постріл у:", target.Name)
                        end
                    end
                end
            end
            return oldNamecall(self, table.unpack(args))
        end)

        setreadonly(mt, true)
        hooked = true
        print("[SilentAim] Namecall Hook активовано!")
    end)
    if not ok then warn("[SilentAim] Помилка хука: " .. tostring(err)) end
end

local function removeHook()
    if not hooked or not oldNamecall then return end
    pcall(function()
        local mt = getrawmetatable(game)
        setreadonly(mt, false)
        mt.__namecall = oldNamecall
        setreadonly(mt, true)
    end)
    hooked = false
    print("[SilentAim] Namecall Hook знято")
end

--// ============================================================
--// RENDER LOOP (FOV)
--// ============================================================
RunService.RenderStepped:Connect(function()
    if fovCircle then
        local inset = GuiService:GetGuiInset()
        fovCircle.Position = UserInputService:GetMouseLocation() - Vector2.new(inset.X, inset.Y)
        fovCircle.Radius = Config.FOV
        fovCircle.Visible = Config.Enabled
        
        if getMurderer() then
            fovCircle.Color = Color3.fromRGB(255, 60, 60)
        else
            fovCircle.Color = Color3.fromRGB(120, 140, 255)
        end
    end
end)

--// ============================================================
--// API ДЛЯ UI
--// ============================================================
local Module = {}
Module.__index = Module
function Module.new() return setmetatable({}, Module) end

function Module:setEnabled(v)
    Config.Enabled = v
    if v then installHook() else removeHook() end
    print("[SilentAim] Enabled:", v)
end

function Module:setFOV(v) Config.FOV = v end
function Module:setHitChance(v) end
function Module:setPrediction(v) Config.Prediction = v end
function Module:setTeamCheck(v) end
function Module:setWallCheck(v) end
function Module:setShowFOV(v) fovCircle.Visible = v end
function Module:setTargetPart(v) Config.Headshot = v end

game:BindToClose(function()
    removeHook()
    if fovCircle then pcall(function() fovCircle:Remove() end) end
end)

return Module.new()
