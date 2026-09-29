--// ╔══════════════════════════════════════════════════════════════╗
--// ║  TrustHub - Loader v6.0                                      ║
--// ║  Author: rshonchar9292-ai                                    ║
--// ╚══════════════════════════════════════════════════════════════╝

local BASE_URL = "https://raw.githubusercontent.com/rshonchar9292-ai/trusthub/main/"

--// ============================================================
--//  LOG HELPERS
--// ============================================================
local function log(msg)
    print("[TrustHub] " .. tostring(msg))
end

local function notify(title, text, duration)
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = title,
            Text = text,
            Duration = duration or 5,
        })
    end)
end

--// ============================================================
--//  MODULE LOADER (крапки → слеші)
--// ============================================================
local function loadModule(path)
    local urlPath = path:gsub("%.", "/")
    local url = BASE_URL .. urlPath .. ".lua"

    log("Завантажую: " .. urlPath)

    local ok, code = pcall(function()
        return game:HttpGet(url)
    end)

    if not ok then
        log("❌ HTTP FAIL: " .. urlPath)
        return nil
    end

    if not code or #code < 10 then
        log("❌ ПУСТИЙ КОД: " .. urlPath)
        return nil
    end

    if code:find("404: Not Found") then
        log("❌ 404: " .. urlPath)
        return nil
    end

    local fn, err = loadstring(code)
    if not fn then
        log("❌ COMPILE FAIL: " .. urlPath .. " → " .. tostring(err))
        return nil
    end

    local ok2, result = pcall(fn)
    if not ok2 then
        log("❌ RUN FAIL: " .. urlPath .. " → " .. tostring(result))
        return nil
    end

    log("✅ OK: " .. urlPath .. " → " .. type(result))
    return result
end

--// ============================================================
--//  LOAD UI
--// ============================================================
log("=== СТАРТ ===")

local UI = loadModule("ui")
if not UI then
    log("❌ UI НЕ ЗАВАНТАЖЕНО — стоп")
    notify("TrustHub", "UI не завантажено. Перевір консоль.", 10)
    return
end
log("✅ UI OK")

--// ============================================================
--//  LOAD ALL FEATURES
--// ============================================================
local Features = {
    -- Combat
    SilentAim = loadModule("features.silentaim"),
    Fling     = loadModule("features.fling"),
    Murderer  = loadModule("features.murderer"),
    AutoFarm  = loadModule("features.autofarm"),

    -- Visual
    ESP       = loadModule("features.esp"),
    FOV       = loadModule("features.fov"),

    -- Movement
    Speed     = loadModule("features.speed"),
    Noclip    = loadModule("features.noclip"),
    AutoGun   = loadModule("features.autogun"),
    Fly       = loadModule("features.fly"),
    InfJump   = loadModule("features.infjump"),

    -- Other
    Animation = loadModule("features.animation"),
}

--// ============================================================
--//  LOG FEATURES STATUS
--// ============================================================
log("─────────────────────────────")
log("SilentAim: "  .. type(Features.SilentAim))
log("Fling: "      .. type(Features.Fling))
log("Murderer: "   .. type(Features.Murderer))
log("AutoFarm: "   .. type(Features.AutoFarm))
log("ESP: "        .. type(Features.ESP))
log("FOV: "        .. type(Features.FOV))
log("Speed: "      .. type(Features.Speed))
log("Noclip: "     .. type(Features.Noclip))
log("AutoGun: "    .. type(Features.AutoGun))
log("Fly: "        .. type(Features.Fly))
log("InfJump: "    .. type(Features.InfJump))
log("Animation: "  .. type(Features.Animation))
log("─────────────────────────────")

-- Make Features global for debugging
_G.TrustHubFeatures = Features

--// ============================================================
--//  INIT UI
--// ============================================================
local ok, err = pcall(function()
    UI:init(Features)
end)

if not ok then
    log("❌ UI INIT FAIL: " .. tostring(err))
    notify("TrustHub Error", "UI init: " .. tostring(err), 15)
    return
end

log("✅ UI INIT OK")
log("=== ГОТОВО ===")
notify("TrustHub v6.0", "Завантажено! F4 — меню", 5)
