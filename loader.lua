--// TrustHub - Loader
--// Author: rshonchar9292-ai
--// Version: 1.0.0

local BASE_URL = "https://raw.githubusercontent.com/rshonchar9292-ai/trusthub/main/"

--// Функція завантаження модулів
local function load(module)
    local url = BASE_URL .. module .. ".lua"
    local success, result = pcall(function()
        return game:HttpGet(url)
    end)
    if not success then
        warn("[TrustHub] Не вдалося завантажити: " .. module)
        return nil
    end
    local fn, err = loadstring(result)
    if not fn then
        warn("[TrustHub] Помилка компіляції " .. module .. ": " .. tostring(err))
        return nil
    end
    return fn()
end

--// Перевірка версії
local CURRENT_VERSION = "1.0.0"
pcall(function()
    local remoteVersion = game:HttpGet(BASE_URL .. "version.txt")
    if remoteVersion and remoteVersion ~= CURRENT_VERSION then
        print("[TrustHub] Доступне оновлення: " .. remoteVersion)
    end
end)

--// Завантаження UI
local UI = load("ui")
if not UI then
    warn("[TrustHub] Критична помилка: UI не завантажено")
    return
end

--// Завантаження фіч
local Features = {
    SilentAim = load("features.silentaim"),
    ESP       = load("features.esp"),
    Speed     = load("features.speed"),
}

--// Ініціалізація UI з фічами
UI:init(Features)

print("[TrustHub] v" .. CURRENT_VERSION .. " успішно завантажено ✓")
