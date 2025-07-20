local L = {}
local locale = GetLocale()

if locale == "ruRU" then
    -- Main settings
    L["TargetHealthPercent"] = "Проценты Здоровья Цели"
    L["General"] = "Общее"
    L["Locked"] = "Закрепить"
    L["Locks or unlocks bar"] = "Закрепляет или открепляет полосу"
    L["Always Show"] = "Всегда показывать"
    L["Show bar always"] = "Показывать полосу всегда"
    L["Show When Target"] = "Показывать при цели"
    L["Show bar only when you have a target"] = "Показывать полосу только при наличии цели"
    L["Show In Combat"] = "Показывать в бою"
    L["Show bar while in combat"] = "Показывать полосу в бою"
    L["Bar Alpha (Opacity)"] = "Прозрачность полосы"
    L["Bar background opacity"] = "Прозрачность фона полосы"
    L["Bar Scale"] = "Масштаб полосы"
    L["Bar scale"] = "Масштаб полосы"
    L["Decimal Places"] = "Знаков после запятой"
    L["Number of places past the decimal"] = "Сколько знаков после запятой"
    L["Show Max HP"] = "Показывать макс. HP"
    L["Show maximum health value"] = "Показывать максимальное значение здоровья"

    -- Thresholds
    L["Thresholds"] = "Пороги"
    L["Add Threshold"] = "Добавить порог"
    L["Threshold"] = "Порог"
    L["Enable"] = "Включить"
    L["Threshold (%)"] = "Порог (%)"
    L["Background RGB"] = "Фон RGB"
    L["Text RGB"] = "Текст RGB"
    L["Name"] = "Название"
    L["Move Up"] = "Вверх"
    L["Move Down"] = "Вниз"
    L["Remove"] = "Удалить"
    L["Remove this threshold?"] = "Удалить этот порог?"

    -- Colors
    L["Health Bar Color"] = "Цвет фона полосы"
    L["Health bar background color"] = "Цвет фона полосы здоровья"

    -- Slash commands
    L["Slash commands (/thp):"] = "Команды (/thp):"
    L["/thp lock: Locks Target Health Percent bar's position"] = "/thp lock: Закрепить позицию полосы"
    L["/thp unlock: unLocks Target Health Percent bar's position"] = "/thp unlock: Открепить позицию полосы"
    L["/thp config: Open addon config menu (also found in Addon tab in Blizzard's Interface menu)"] = "/thp config: Открыть меню настроек"
    L["/thp reset:  Resets your config to defaults"] = "/thp reset: Сбросить настройки"
else
    -- English (default)
    L["Move Up"] = "Move Up"
    L["Move Down"] = "Move Down"
end

setmetatable(L, {__index = function(t, k) return k end})
TargetHealthPercent_Locale = L
