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
--// ЗАВАНТАЖЕННЯ МОДУЛЯ
--// ==================================================
local function loadModule(path)
    local url = BASE_URL .. path .. ".lua"
    log("Завантажую: " .. path)
    
    local ok, code = pcall(function()
        return game:HttpGet(url)
    end)
    
    if not ok then
        log("❌ HTTP FAIL: " .. path)
        notify("TrustHub Error", "HTTP: " .. path)
        return nil
    end
    
    if not code or #code < 10 then
        log("❌ ПУСТИЙ КОД: " .. path)
        return nil
    end
    
    if code:find("404: Not Found") then
        log("❌ 404: " .. path)
        notify("TrustHub Error", "404: " .. path)
        return nil
    end
    
    local fn, err = loadstring(code)
    if not fn then
        log("❌ COMPILE FAIL: " .. path .. " → " .. tostring(err))
        notify("TrustHub Error", "Compile: " .. path)
        return nil
    end
    
    local ok2, result = pcall(fn)
    if not ok2 then
        log("❌ RUN FAIL: " .. path .. " → " .. tostring(result))
        notify("TrustHub Error", "Run: " .. path)
        return nil
    end
    
    log("✅ OK: " .. path .. " → " .. type(result))
    return result
end

--// ==================================================
--// ЗАВАНТАЖЕННЯ ВСІХ МОДУЛІВ
--// ==================================================
log("=== СТАРТ ===")
log("loadstring: " .. tostring(loadstring ~= nil))
log("getsenv: " .. tostring(getsenv ~= nil))
log("Drawing: " .. tostring(Drawing ~= nil))
log("gethui: " .. tostring(gethui ~= nil))

local UI = loadModule("ui")
if not UI then
    log("❌ UI НЕ ЗАВАНТАЖЕНО — стоп")
    notify("TrustHub", "UI не завантажено. Перевір консоль.", 10)
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
notify("TrustHub", "Завантажено! Перевір консоль для деталей.", 5)
