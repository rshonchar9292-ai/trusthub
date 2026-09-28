--// ============================================================
--// TrustHub Animation Module — R15 Sets Only
--// ============================================================

local Players     = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local Animation = {}
Animation.__index = Animation

local URL = "http://www.roblox.com/asset/?id="

local currentAnim = nil
local originalAnimations = {}

--// ============================================================
--//  ANIMATION SETS (45 R15 sets)
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
    Bold          = {Idle=16738333868, Idle2=16738334710, Idle3=16738335517, Walk=16738340646, Run=16738337225, Jump=16738336650, Climb=16738332169, Fall=16738333171, Swim=16738339158, SwimIdle=16738339817},
    Astronaut     = {Idle=891621366, Idle2=891633237, Idle3=1047759695, Walk=891667138, Run=891636393, Jump=891627522, Climb=891609353, Fall=891617961, Swim=891639666, SwimIdle=891663592},
    Bubbly        = {Idle=910004836, Idle2=910009958, Idle3=1018536639, Walk=910034870, Run=910025107, Jump=910016857, Climb=909997997, Fall=910001910, Swim=910028158, SwimIdle=910030921},
    Pirate        = {Idle=750781874, Idle2=750782770, Idle3=885515365, Walk=750785693, Run=750783738, Jump=750782230, Climb=750779899, Fall=750780242, Swim=750784579, SwimIdle=750785176},
    Rthro         = {Idle=2510196951, Idle2=2510197257, Idle3=3711062489, Walk=2510202577, Run=2510198475, Jump=2510197830, Climb=2510192778, Fall=2510195892, Swim=2510199791, SwimIdle=2510201162},
    Ninja         = {Idle=656117400, Idle2=656118341, Idle3=886742569, Walk=656121766, Run=656118852, Jump=656117878, Climb=656114359, Fall=656115606, Swim=656119721, SwimIdle=656121397},
    Oldschool     = {Idle=5319828216, Idle2=5319831086, Idle3=5392107832, Walk=5319847204, Run=5319844329, Jump=5319841935, Climb=5319816685, Fall=5319839762, Swim=5319850266, SwimIdle=5319852613},
    Realistic     = {Idle=17172918855, Idle2=17173014241, Idle3=17173014241, Walk=11600249883, Run=11600211410, Jump=11600210487, Climb=11600205519, Fall=11600206437, Swim=11600212676, SwimIdle=11600213505},
    ["No Boundaries"] = {Idle=18747067405, Idle2=18747063918, Idle3=18747063918, Walk=18747074203, Run=18747070484, Jump=18747069148, Climb=18747060903, Fall=18747062535, Swim=18747073181, SwimIdle=18747071682},
    ["NFL Animation"] = {Idle=92080889861410, Idle2=74451233229259, Idle3=80884010501210, Walk=110358958299415, Run=117333533048078, Jump=119846112151352, Climb=134630013742019, Fall=129773241321032, Swim=132697394189921, SwimIdle=79090109939093},
    ["Adidas Aura"] = {Idle=110211186840347, Idle2=114191137265065, Idle3=99129837931148, Walk=83842218823011, Run=118320322718866, Jump=109996626521204, Climb=97824616490448, Fall=95603166884636, Swim=134530128383903, SwimIdle=94922130551805},
    ["Adidas Sports"] = {Idle=18537376492, Idle2=18537371272, Idle3=18537374150, Walk=18537392113, Run=18537384940, Jump=18537380791, Climb=18537363391, Fall=18537367238, Swim=18537389531, SwimIdle=18537387180},
    ["Adidas Community"] = {Idle=122257458498464, Idle2=102357151005774, Idle3=89262795687364, Walk=122150855457006, Run=82598234841035, Jump=75290611992385, Climb=88763136693023, Fall=98600215928904, Swim=133308483266208, SwimIdle=109346520324160},
    ["Wickled Popular"] = {Idle=118832222982049, Idle2=76049494037641, Idle3=138255200176080, Walk=92072849924640, Run=72301599441680, Jump=104325245285198, Climb=131326830509784, Fall=121152442762481, Swim=99384245425157, SwimIdle=113199415118199},
    ["Catwalk Glam"] = {Idle=133806214992291, Idle2=94970088341563, Idle3=87105332133518, Walk=109168724482748, Run=81024476153754, Jump=116936326516985, Climb=119377220967554, Fall=92294537340807, Swim=134591743181628, SwimIdle=98854111361360},
    Princess      = {Idle=941003647, Idle2=941013098, Idle3=1159195712, Walk=941028902, Run=941015281, Jump=941008832, Climb=940996062, Fall=941000007, Swim=941018893, SwimIdle=941025398},
    Confident     = {Idle=1069977950, Idle2=1069987858, Idle3=1116160740, Walk=1070017263, Run=1070001516, Jump=1069984524, Climb=1069946257, Fall=1069973677, Swim=1070009914, SwimIdle=1070012133},
    Popstar       = {Idle=1212900985, Idle2=1150842221, Idle3=1239733474, Walk=1212980338, Run=1212980348, Jump=1212954642, Climb=1213044953, Fall=1212900995, Swim=1212852603, SwimIdle=1070012133},
    Patrol        = {Idle=1149612882, Idle2=1150842221, Idle3=1159573567, Walk=1151231493, Run=1150967949, Jump=1150944216, Climb=1148811837, Fall=1148863382, Swim=1151204998, SwimIdle=1151221899},
    Sneaky        = {Idle=1132473842, Idle2=1132477671, Idle3=1132510133, Walk=1132510133, Run=1132494274, Jump=1132489853, Climb=1132461372, Fall=1132469004, Swim=1132500520, SwimIdle=1132506407},
    Cowboy        = {Idle=1014390418, Idle2=1014398616, Idle3=1159487651, Walk=1014421541, Run=1014401683, Jump=1014394726, Climb=1014380606, Fall=1014384571, Swim=1014406523, SwimIdle=1014411816},
    Ghost         = {Idle=616006778, Idle2=616008087, Idle3=616008087, Walk=616013216, Run=616013216, Jump=616008936, Climb=0, Fall=616005863, Swim=616011509, SwimIdle=616012453},
    ["Ghost 2"]   = {Idle=1151221899, Idle2=1151221899, Idle3=1151221899, Walk=1151221899, Run=1151221899, Jump=1151221899, Climb=0, Fall=1151221899, Swim=16738339158, SwimIdle=1151221899},
    ["Mr. Toilet"] = {Idle=4417977954, Idle2=4417978624, Idle3=4441285342, Walk=2510202577, Run=4417979645, Jump=2510197830, Climb=2510192778, Fall=2510195892, Swim=2510199791, SwimIdle=2510201162},
    Udzal         = {Idle=3303162274, Idle2=3303162549, Idle3=3710161342, Walk=3303162967, Run=3236836670, Jump=2510197830, Climb=2510192778, Fall=2510195892, Swim=2510199791, SwimIdle=2510201162},
    ["Oinan Thickhoof"] = {Idle=657595757, Idle2=657568135, Idle3=885499184, Walk=2510202577, Run=3236836670, Jump=2510197830, Climb=2510192778, Fall=2510195892, Swim=2510199791, SwimIdle=2510201162},
    Borock        = {Idle=3293641938, Idle2=3293642554, Idle3=3710131919, Walk=2510202577, Run=3236836670, Jump=2510197830, Climb=2510192778, Fall=2510195892, Swim=2510199791, SwimIdle=2510201162},
    ["Blocky Mech"] = {Idle=4417977954, Idle2=4417978624, Idle3=4441285342, Walk=2510202577, Run=4417979645, Jump=2510197830, Climb=2510192778, Fall=2510195892, Swim=2510199791, SwimIdle=2510201162},
    ["Stylized Female"] = {Idle=4708191566, Idle2=4708192150, Idle3=121221, Walk=4708193840, Run=4708192705, Jump=4708188025, Climb=4708184253, Fall=4708186162, Swim=4708189360, SwimIdle=4708190607},
    R15           = {Idle=4211217646, Idle2=4211218409, Idle3=4211218409, Walk=4211223236, Run=4211220381, Jump=4211219390, Climb=4211214992, Fall=4211216152, Swim=4211221314, SwimIdle=4374694239},
    Mocap         = {Idle=913367814, Idle2=913373430, Idle3=913373430, Walk=913402848, Run=913376220, Jump=913370268, Climb=913362637, Fall=913365531, Swim=913384386, SwimIdle=913389285},
    ["Wicked Dancing Through Life"] = {Idle=92849173543269, Idle2=132238900951109, Idle3=87867222929430, Walk=73718308412641, Run=135515454877967, Jump=78508480717326, Climb=129447497744818, Fall=78147885297412, Swim=110657013921774, SwimIdle=129183123083281},
    Unboxed       = {Idle=98281136301627, Idle2=138183121662404, Idle3=133117300343405, Walk=90478085024465, Run=134824450619865, Jump=121454505477205, Climb=121145883950231, Fall=94788218468396, Swim=105962919001086, SwimIdle=129126268464847},
}

--// ============================================================
--//  SAVE ORIGINAL
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
--//  PLAY SET
--// ============================================================
function Animation:playAnimationSet(name)
    if not Animations[name] then
        warn("[Animation] Set not found: " .. tostring(name))
        return false
    end

    local char = LocalPlayer.Character
    if not char then return false end
    local animate = char:FindFirstChild("Animate")
    if not animate then
        warn("[Animation] No Animate script (maybe R6?)")
        return false
    end

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
        if animate:FindFirstChild("walk") then
            animate.walk:FindFirstChildOfClass("Animation").AnimationId = URL .. set.Walk
        end
        if animate:FindFirstChild("run") then
            animate.run:FindFirstChildOfClass("Animation").AnimationId = URL .. set.Run
        end
        if animate:FindFirstChild("jump") then
            animate.jump:FindFirstChildOfClass("Animation").AnimationId = URL .. set.Jump
        end
        if animate:FindFirstChild("climb") then
            animate.climb:FindFirstChildOfClass("Animation").AnimationId = URL .. set.Climb
        end
        if animate:FindFirstChild("fall") then
            animate.fall:FindFirstChildOfClass("Animation").AnimationId = URL .. set.Fall
        end
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
--//  RESET
--// ============================================================
function Animation:reset()
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
--//  GET LIST
--// ============================================================
function Animation:getAnimationList()
    local list = {}
    for name, _ in pairs(Animations) do
        table.insert(list, name)
    end
    table.sort(list)
    return list
end

--// ============================================================
--//  STUBS (для сумісності з UI)
--// ============================================================
function Animation:setEnabled() end
function Animation:setSpeed() end
function Animation:playEmote() end
function Animation:playCustomEmote() end
function Animation:getEmoteList() return {} end
function Animation:getR6EmoteList() return {} end
function Animation:getCurrent() return currentAnim end

--// ============================================================
--//  AUTO-REAPPLY ON RESPAWN
--// ============================================================
LocalPlayer.CharacterAdded:Connect(function()
    task.wait(1.5)
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

local count = 0
for _ in pairs(Animations) do count = count + 1 end
print("[Animation] Loaded — " .. count .. " R15 sets")

return Animation.new()
