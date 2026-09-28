--// TrustHub Noclip

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

local Noclip = {}
Noclip.__index = Noclip

local enabled = false
local conn = nil

local function setCharCollide(char, state)
    if not char then return end
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            pcall(function() part.CanCollide = state end)
        end
    end
end

local function startLoop()
    if conn then conn:Disconnect() end
    conn = RunService.Stepped:Connect(function()
        if not enabled then return end
        local char = LocalPlayer.Character
        if char then setCharCollide(char, false) end
    end)
end

function Noclip.new()
    return setmetatable({}, Noclip)
end

function Noclip:setEnabled(state)
    enabled = state
    if state then
        startLoop()
        print("[Noclip] ON")
    else
        if conn then conn:Disconnect(); conn = nil end
        local char = LocalPlayer.Character
        if char then setCharCollide(char, true) end
        print("[Noclip] OFF")
    end
end

LocalPlayer.CharacterAdded:Connect(function(char)
    if enabled then
        task.wait(0.5)
        setCharCollide(char, false)
    end
end)

return Noclip.new()
