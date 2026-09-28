--// TrustHub - Loader v2
--// Author: rshonchar9292-ai

local BASE_URL = "https://raw.githubusercontent.com/rshonchar9292-ai/trusthub/main/"

--// ==================================================
--// ДІАГНОСТИКА
--// ==================================================
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

--// ==================================================
--// ЗАВАНТАЖЕННЯ МОДУЛЯ (крапки → слеші)
--// ==================================================
local function loadModule(path)
    -- 🔥 ГОЛОВНИЙ ФІКС
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

--// ==================================================
--// ЗАВАНТАЖЕННЯ ВСІХ МОДУЛІВ
--// ==================================================
log("=== СТАРТ ===")

local UI = loadModule("ui")
if not UI then
    log("❌ UI НЕ ЗАВАНТАЖЕНО — стоп")
    return
end
log("✅ UI OK")

local Features = {
    SilentAim = loadModule("features.silentaim"),
    ESP       = loadModule("features.esp"),
    Speed     = loadModule("features.speed"),
}

log("SilentAim: " .. type(Features.SilentAim))
log("ESP: "       .. type(Features.ESP))
log("Speed: "     .. type(Features.Speed))

--// ==================================================
--// ЗАПУСК UI
--// ==================================================
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
notify("TrustHub", "Завантажено успішно!", 5)
