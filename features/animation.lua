--// ╔══════════════════════════════════════════════════════════╗
--// ║  TrustHub Animation Module                               ║
--// ║  Based on Eazvy Hub (extracted anims + emotes)           ║
--// ╚══════════════════════════════════════════════════════════╝

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

local Animation = {}
Animation.__index = Animation

--// ============================================================
--//  URL PREFIX
--// ============================================================
local URL = "http://www.roblox.com/asset/?id="

--// ============================================================
--//  STATE
--// ============================================================
local enabled = false
local currentAnim = nil
local animationSpeed = 1
local loadedAnim = nil
local originalAnimations = {}

--// ============================================================
--//  ANIMATION SETS (R15) — з Eazvy Hub
--// ============================================================
local Animations = {
    Stylish       = {Idle=616136790, Idle2=616138447, Idle3=886888594, Walk=616146177, Run=616140816, Jump=616139451, Climb=616133594, Fall=616134815, Swim=616143378, SwimIdle=616144772},
    Zombie        = {Idle=616158929, Idle2=616160636, Idle3=885545458, Walk=616168032, Run=616163682, Jump=616161997, Climb=616156119, Fall=616157476, Swim=616165109, SwimIdle=616166655},
    Robot         = {Idle=616088211, Idle2=616089559, Idle3=885531463, Walk=616095330, Run=616091570, Jump=616090535, Climb=616086039, Fall=616087089, Swim=616092998, SwimIdle=616094091},
    Toy           = {Idle=782841498, Idle2=782845736, Idle3=980952228, Walk=782843345, Run=782842708, Jump=782847020, Climb=782843869, Fall=782846423, Swim=782844582, SwimIdle=782845186},
    Cartoony      = {Idle=742637544, Idle2=742638445, Idle3=885477856, Walk=742640026, Run=742638842, Jump=742637942, Climb=742636889, Fall=742637151, Swim=742639220, SwimIdle=742639812},
    Superhero     = {Idle=616111295, Idle2=616113536, Idle3=885535855, Walk=616122287, Run=616117076, Jump=616115533, Climb=616104706, Fall=616108001, Swim=616119360, SwimIdle=616120861},
    Mage          = {Idle=707742142, Idle2=707855907, Idle3=885508740, Walk=707897309, Run=707861613, Jump=707853694, Climb=707826056, Fall=707829716, Swim=707876443, SwimIdle=707894699},
    Levitation    = {Idle=616006778, Idle2=616008087, Idle3=886862142, Walk=616013216, Run=616010382, Jump=616008936, Climb=616003713, Fall=616005863, Swim=616011509, SwimIdle=616012453},
    Vampire       = {Idle=1083445855, Idle2=1083450166, Idle3=1088037547, Walk=1083473930, Run=1083462077, Jump=1083455352, Climb=1083439238, Fall=1083443587, Swim=1083464683, SwimIdle=1083467779},
    Elder         = {Idle=845397899, Idle2=845400520, Idle3=901160519, Walk=845403856, Run=845386501, Jump=845398858, Climb=845392038, Fall=845396048, Swim=845401742, SwimIdle=845403127},
    Werewolf      = {Idle=1083195517, Idle2=1083214717, Idle3=1099492820, Walk=1083178339, Run=1083216690, Jump=1083218792, Climb=1083182000, Fall=1083189019, Swim=1083222527, SwimIdle=1083225406},
    Knight        = {Idle=657595757, Idle2=657568135, Idle3=885499184, Walk=657552124, Run=657564596, Jump=658409194, Climb=658360781, Fall=657600338, Swim=657560551, SwimIdle=657557095},
    Astronaut     = {Idle=891621366, Idle2=891633237, Idle3=1047759695, Walk=891667138, Run=891636393, Jump=891627522, Climb=891609353, Fall=891617961, Swim=891639666, SwimIdle=891663592},
    Bubbly        = {Idle=910004836, Idle2=910009958, Idle3=1018536639, Walk=910034870, Run=910025107, Jump=910016857, Climb=909997997, Fall=910001910, Swim=910028158, SwimIdle=910030921},
    Pirate        = {Idle=750781874, Idle2=750782770, Idle3=885515365, Walk=750785693, Run=750783738, Jump=750782230, Climb=750779899, Fall=750780242, Swim=750784579, SwimIdle=750785176},
    Rthro         = {Idle=2510196951, Idle2=2510197257, Idle3=3711062489, Walk=2510202577, Run=2510198475, Jump=2510197830, Climb=2510192778, Fall=2510195892, Swim=2510199791, SwimIdle=2510201162},
    Ninja         = {Idle=656117400, Idle2=656118341, Idle3=886742569, Walk=656121766, Run=656118852, Jump=656117878, Climb=656114359, Fall=656115606, Swim=656119721, SwimIdle=656121397},
    Oldschool     = {Idle=5319828216, Idle2=5319831086, Idle3=5392107832, Walk=5319847204, Run=5319844329, Jump=5319841935, Climb=5319816685, Fall=5319839762, Swim=5319850266, SwimIdle=5319852613},
    Princess      = {Idle=941003647, Idle2=941013098, Idle3=1159195712, Walk=941028902, Run=941015281, Jump=941008832, Climb=940996062, Fall=941000007, Swim=941018893, SwimIdle=941025398},
    Confident     = {Idle=1069977950, Idle2=1069987858, Idle3=1116160740, Walk=1070017263, Run=1070001516, Jump=1069984524, Climb=1069946257, Fall=1069973677, Swim=1070009914, SwimIdle=1070012133},
    Popstar       = {Idle=1212900985, Idle2=1150842221, Idle3=1239733474, Walk=1212980338, Run=1212980348, Jump=1212954642, Climb=1213044953, Fall=1212900995, Swim=1212852603, SwimIdle=1070012133},
    Patrol        = {Idle=1149612882, Idle2=1150842221, Idle3=1159573567, Walk=1151231493, Run=1150967949, Jump=1150944216, Climb=1148811837, Fall=1148863382, Swim=1151204998, SwimIdle=1151221899},
    Sneaky        = {Idle=1132473842, Idle2=1132477671, Idle3=1132510133, Walk=1132510133, Run=1132494274, Jump=1132489853, Climb=1132461372, Fall=1132469004, Swim=1132500520, SwimIdle=1132506407},
    Cowboy        = {Idle=1014390418, Idle2=1014398616, Idle3=1159487651, Walk=1014421541, Run=1014401683, Jump=1014394726, Climb=1014380606, Fall=1014384571, Swim=1014406523, SwimIdle=1014411816},
    Ghost         = {Idle=616006778, Idle2=616008087, Idle3=616008087, Walk=616013216, Run=616013216, Jump=616008936, Climb=0, Fall=616005863, Swim=616011509, SwimIdle=616012453},
}

--// ============================================================
--//  EMOTES (популярні, скорочений список)
--// ============================================================
local Emotes = {
    ["Fashion"]      = 3333331310,
    ["Baby Dance"]   = 4265725525,
    ["Cha-Cha"]      = 6862001787,
    ["Monkey"]       = 3333499508,
    ["Shuffle"]      = 4349242221,
    ["Top Rock"]     = 3361276673,
    ["Fancy Feet"]   = 3333432454,
    ["Hype Dance"]   = 3695333486,
    ["Bodybuilder"]  = 3333387824,
    ["Idol"]         = 4101966434,
    ["Curtsy"]       = 4555816777,
    ["Happy"]        = 4841405708,
    ["Sleep"]        = 4686925579,
    ["Floss Dance"]  = 5917459365,
    ["Shy"]          = 3337978742,
    ["Godlike"]      = 3337994105,
    ["Hero Landing"] = 5104344710,
    ["Cower"]        = 4940563117,
    ["Bored"]        = 5230599789,
    ["Celebrate"]    = 3338097973,
    ["Dash"]         = 582855105,
    ["Beckon"]       = 5230598276,
    ["Haha"]         = 3337966527,
    ["Line Dance"]   = 4049037604,
    ["Shrug"]        = 3334392772,
    ["Stadium"]      = 3338055167,
    ["Confused"]     = 4940561610,
    ["Side to Side"] = 3333136415,
    ["Hello"]        = 3344650532,
    ["Dolphin Dance"]= 5918726674,
    ["Samba"]        = 6869766175,
    ["Break Dance"]  = 5915648917,
    ["Greatest"]     = 3338042785,
    ["Sad"]          = 4841407203,
    ["Twirl"]        = 3334968680,
    ["Jumping Wave"] = 4940564896,
    ["Dizzy"]        = 3361426436,
    ["Fast Hands"]   = 4265701731,
    ["Tree"]         = 4049551434,
    ["Agree"]        = 4841397952,
    ["Power Blast"]  = 4841403964,
    ["Swoosh"]       = 3361481910,
    ["Jumping Cheer"]= 5895324424,
    ["Disagree"]     = 4841401869,
    ["Rock On"]      = 5915714366,
    ["Dorky Dance"]  = 4212455378,
    ["Zombie"]       = 4210116953,
    ["T"]            = 3338010159,
    ["Fishing"]      = 3334832150,
    ["Robot"]        = 3338025566,
    ["Keeping Time"] = 4555808220,
    ["Air Dance"]    = 4555782893,
    ["Swan Dance"]   = 7465997989,
    ["Louder"]       = 3338083565,
    ["Swish"]        = 3361481910,
    ["Sneaky"]       = 3334424322,
    ["Heisman Pose"] = 3695263073,
    ["Jacks"]        = 3338066331,
    ["Cha-Cha 2"]    = 3695322025,
    ["Superhero Reveal"] = 3695373233,
    ["Air Guitar"]   = 3695300085,
    ["Dismissive Wave"] = 3333272779,
    ["Salute"]       = 3333474484,
    ["Applaud"]      = 5915693819,
    ["Get Out"]      = 3333272779,
    ["Bunny Hop"]    = 4641985101,
    ["Sandwich Dance"]= 4406555273,
    ["Tantrum"]      = 5104341999,
    ["High Hands"]   = 9710985298,
    ["Tilt"]         = 3334538554,
    ["Chicken Dance"]= 4841399916,
    ["Super Charge"] = 10478338114,
    ["Swag Walk"]    = 10478341260,
    ["Festive Dance"]= 15679621440,
    ["Rock n Roll"]  = 15505458452,
    ["Victory Dance"]= 15505456446,
    ["Flex Walk"]    = 15505459811,
    ["Mini Kong"]    = 17000021306,
    ["Vans Ollie"]   = 18305395285,
    ["Vroom Vroom"]  = 18526397037,
    ["TMNT Dance"]   = 18665811005,
    ["Olympic Dismount"] = 18665825805,
    ["Skibidi Toilet"] = 134283166482394,
    ["Rasputin – Boney M."] = 114872820353992,
}

--// ============================================================
--//  R6 EMOTES
--// ============================================================
local R6Emotes = {
    ["Balloon Float"] = 148840371,
    ["Idle"]          = 180435571,
    ["Arm Turbine"]   = 259438880,
    ["Floating Head"] = 121572214,
    ["Scream"]        = 180611870,
    ["Party Time"]    = 33796059,
    ["Chop"]          = 33169596,
    ["Goal!"]         = 28488254,
    ["Rotation"]      = 136801964,
    ["Spin"]          = 188632011,
    ["Cry"]           = 180612465,
    ["Zombie Arms"]   = 183294396,
    ["Flying"]        = 46196309,
    ["Stab"]          = 66703241,
    ["Dance"]         = 35654637,
    ["Hmmm"]          = 33855276,
    ["Sword"]         = 35978879,
    ["Kick"]          = 45737360,
    ["Crouch"]        = 287325678,
    ["Beat Box"]      = 45504977,
    ["Charleston"]    = 429703734,
    ["Moon Dance"]    = 27789359,
    ["Roar"]          = 163209885,
    ["Bow Down"]      = 204292303,
    ["Dab"]           = 183412246,
    ["Hero Jump"]     = 184574340,
}

--// ============================================================
--//  ORIGINAL ANIMATIONS (збереження)
--// ============================================================
local function saveOriginalAnimations()
    local char = LocalPlayer.Character
    if not char then return end
    local animate = char:FindFirstChild("Animate")
    if not animate then return end

    originalAnimations = {}
    if animate:FindFirstChild("idle") then
        originalAnimations[1] = animate.idle.Animation1.AnimationId
        originalAnimations[2] = animate.idle.Animation2.AnimationId
    end
    if animate:FindFirstChild("pose") then
        local poseAnim = animate.pose:FindFirstChildOfClass("Animation")
        if poseAnim then originalAnimations[3] = poseAnim.AnimationId end
    end
    if animate:FindFirstChild("walk") then
        originalAnimations[4] = animate.walk:FindFirstChildOfClass("Animation").AnimationId
    end
    if animate:FindFirstChild("run") then
        originalAnimations[5] = animate.run:FindFirstChildOfClass("Animation").AnimationId
    end
    if animate:FindFirstChild("jump") then
        originalAnimations[6] = animate.jump:FindFirstChildOfClass("Animation").AnimationId
    end
    if animate:FindFirstChild("climb") then
        originalAnimations[7] = animate.climb:FindFirstChildOfClass("Animation").AnimationId
    end
    if animate:FindFirstChild("fall") then
        originalAnimations[8] = animate.fall:FindFirstChildOfClass("Animation").AnimationId
    end
    if animate:FindFirstChild("swim") then
        originalAnimations[9] = animate.swim:FindFirstChildOfClass("Animation").AnimationId
        originalAnimations[10] = animate.swimidle:FindFirstChildOfClass("Animation").AnimationId
    end
end

--// ============================================================
--//  PLAY ANIMATION SET
--// ============================================================
function Animation:playAnimationSet(name)
    if not Animations[name] then return false end

    local char = LocalPlayer.Character
    if not char then return false end
    local animate = char:FindFirstChild("Animate")
    if not animate then return false end

    if #originalAnimations == 0 then
        saveOriginalAnimations()
    end

    local set = Animations[name]

    pcall(function()
        if animate:FindFirstChild("idle") then
            animate.idle.Animation1.AnimationId = URL .. set.Idle
            animate.idle.Animation2.AnimationId = URL .. set.Idle2
        end
        if animate:FindFirstChild("pose") and set.Idle3 then
            animate.pose:FindFirstChildOfClass("Animation").AnimationId = URL .. set.Idle3
        end
        animate.walk:FindFirstChildOfClass("Animation").AnimationId = URL .. set.Walk
        animate.run:FindFirstChildOfClass("Animation").AnimationId = URL .. set.Run
        animate.jump:FindFirstChildOfClass("Animation").AnimationId = URL .. set.Jump
        animate.climb:FindFirstChildOfClass("Animation").AnimationId = URL .. set.Climb
        animate.fall:FindFirstChildOfClass("Animation").AnimationId = URL .. set.Fall
        if animate:FindFirstChild("swim") then
            animate.swim:FindFirstChildOfClass("Animation").AnimationId = URL .. set.Swim
            animate.swimidle:FindFirstChildOfClass("Animation").AnimationId = URL .. set.SwimIdle
        end
    end)

    currentAnim = name
    print("[Animation] Set: " .. name)
    return true
end

--// ============================================================
--//  PLAY EMOTE (one-shot)
--// ============================================================
function Animation:playEmote(name)
    local id = Emotes[name] or R6Emotes[name]
    if not id then return false end

    local char = LocalPlayer.Character
    if not char then return false end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return false end

    -- Stop попередні
    if loadedAnim then
        pcall(function() loadedAnim:Stop() end)
    end

    local anim = Instance.new("Animation")
    anim.AnimationId = "rbxassetid://" .. id
    local track = hum:LoadAnimation(anim)
    track.Priority = Enum.AnimationPriority.Action
    track:Play(0)

    if animationSpeed ~= 1 then
        track:AdjustSpeed(animationSpeed)
    end

    loadedAnim = track
    print("[Animation] Emote: " .. name .. " (id: " .. id .. ")")
    return true
end

--// ============================================================
--//  PLAY CUSTOM EMOTE (by ID)
--// ============================================================
function Animation:playCustomEmote(id)
    if type(id) == "string" then
        id = tonumber(id) or id
    end

    local char = LocalPlayer.Character
    if not char then return false end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return false end

    if loadedAnim then
        pcall(function() loadedAnim:Stop() end)
    end

    local anim = Instance.new("Animation")
    anim.AnimationId = "rbxassetid://" .. tostring(id)
    local track = hum:LoadAnimation(anim)
    track.Priority = Enum.AnimationPriority.Action
    track:Play(0)

    loadedAnim = track
    return true
end

--// ============================================================
--//  RESET — повернути оригінальні анімації
--// ============================================================
function Animation:reset()
    if loadedAnim then
        pcall(function() loadedAnim:Stop() end)
        loadedAnim = nil
    end

    local char = LocalPlayer.Character
    if not char then return end
    local animate = char:FindFirstChild("Animate")
    if not animate then return end

    pcall(function()
        if animate:FindFirstChild("idle") then
            animate.idle.Animation1.AnimationId = originalAnimations[1] or ""
            animate.idle.Animation2.AnimationId = originalAnimations[2] or ""
        end
        if animate:FindFirstChild("pose") and originalAnimations[3] then
            animate.pose:FindFirstChildOfClass("Animation").AnimationId = originalAnimations[3]
        end
        if originalAnimations[4] then
            animate.walk:FindFirstChildOfClass("Animation").AnimationId = originalAnimations[4]
        end
        if originalAnimations[5] then
            animate.run:FindFirstChildOfClass("Animation").AnimationId = originalAnimations[5]
        end
        if originalAnimations[6] then
            animate.jump:FindFirstChildOfClass("Animation").AnimationId = originalAnimations[6]
        end
        if originalAnimations[7] then
            animate.climb:FindFirstChildOfClass("Animation").AnimationId = originalAnimations[7]
        end
        if originalAnimations[8] then
            animate.fall:FindFirstChildOfClass("Animation").AnimationId = originalAnimations[8]
        end
        if animate:FindFirstChild("swim") then
            animate.swim:FindFirstChildOfClass("Animation").AnimationId = originalAnimations[9] or ""
            animate.swimidle:FindFirstChildOfClass("Animation").AnimationId = originalAnimations[10] or ""
        end
    end)

    currentAnim = nil
    print("[Animation] Reset")
end

--// ============================================================
--//  GET LISTS
--// ============================================================
function Animation:getAnimationList()
    local list = {}
    for name, _ in pairs(Animations) do
        table.insert(list, name)
    end
    table.sort(list)
    return list
end

function Animation:getEmoteList()
    local list = {}
    for name, _ in pairs(Emotes) do
        table.insert(list, name)
    end
    table.sort(list)
    return list
end

function Animation:getR6EmoteList()
    local list = {}
    for name, _ in pairs(R6Emotes) do
        table.insert(list, name)
    end
    table.sort(list)
    return list
end

--// ============================================================
--//  SPEED
--// ============================================================
function Animation:setSpeed(speed)
    animationSpeed = speed or 1
    if loadedAnim then
        pcall(function() loadedAnim:AdjustSpeed(animationSpeed) end)
    end
end

function Animation:setEnabled(state)
    enabled = state
    if state and #originalAnimations == 0 then
        saveOriginalAnimations()
    end
end

function Animation:getCurrent() return currentAnim end

--// ============================================================
--//  AUTO-SAVE ON SPAWN
--// ============================================================
LocalPlayer.CharacterAdded:Connect(function()
    task.wait(1)
    saveOriginalAnimations()
    if currentAnim then
        Animation:playAnimationSet(currentAnim)
    end
end)

if LocalPlayer.Character then
    task.wait(1)
    saveOriginalAnimations()
end

--// ============================================================
--//  MODULE
--// ============================================================
function Animation.new()
    return setmetatable({}, Animation)
end

print("[Animation] Loaded — " .. Animation:getAnimationList and #Animation:getAnimationList() or 0 .. " anims, " .. (#Animation:getEmoteList() + #Animation:getR6EmoteList()) .. " emotes")

return Animation.new()
