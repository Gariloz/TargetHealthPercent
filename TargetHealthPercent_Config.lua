TargetHealthPercent = TargetHealthPercent or {}
local L = TargetHealthPercent_Locale or {}
local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local AceConfigRegistry = LibStub("AceConfigRegistry-3.0")

-- Резервная локализация если основная не загрузилась
if not L or not L["TargetHealthPercent"] then
    L = {}
    setmetatable(L, {__index = function(t, k) return k end})
end

local options = nil

local function get(info)
    if not TargetHealthPercent.db then
        return nil
    end
    return TargetHealthPercent.db.profile[info[#info]]
end
local function set(info, value)
    if not TargetHealthPercent.db then
        return
    end
    TargetHealthPercent.db.profile[info[#info]] = value
    if TargetHealthPercent.UpdateBar then
        TargetHealthPercent:UpdateBar()
    end
end

-- Динамическая генерация опций порогов
local function GenerateThresholdOptions()
    if not TargetHealthPercent.db then
        return {}
    end
    local db = TargetHealthPercent.db.profile
    local args = {}
    -- Инициализируем массив порогов если он не существует
    if not db.thresholds then
        db.thresholds = {}
    end
    -- Добавляем кнопку порога
    args.addThreshold = {
        type = "execute",
        name = L["Add Threshold"],
        order = 0,
        func = function()
            if not TargetHealthPercent.db then
                print("ОШИБКА: База данных не инициализирована при добавлении порога!")
                return
            end

            local newThreshold = {
                value = 10,
                color = {1, 1, 1},
                textColor = {1, 1, 1},
                enabled = true,
                name = L["Threshold"] .. " " .. tostring(#TargetHealthPercent.db.profile.thresholds + 1)
            }

            table.insert(TargetHealthPercent.db.profile.thresholds, newThreshold)
            print("Добавлен порог: " .. newThreshold.name .. " (" .. newThreshold.value .. "%)")
            print("Всего порогов: " .. #TargetHealthPercent.db.profile.thresholds)

            -- Принудительно сохраняем данные
            TargetHealthPercent:ForceSave()

            recreateOptions()
            AceConfigRegistry:NotifyChange("TargetHealthPercent")
        end,
    }
    -- Для каждого порога
    for i, threshold in ipairs(db.thresholds) do
        args["threshold"..i] = {
            type = "group",
            name = threshold.name or (L["Threshold"].." "..i),
            order = i,
            args = {
                enabled = {
                    type = "toggle",
                    name = L["Enable"],
                    order = 1,
                    get = function() return threshold.enabled end,
                    set = function(_, v)
                        threshold.enabled = v
                        TargetHealthPercent:ForceSave()

                        -- Принудительно обновляем интерфейс
                        recreateOptions()
                        AceConfigRegistry:NotifyChange("TargetHealthPercent")

                        if TargetHealthPercent.UpdateBar then
                            TargetHealthPercent:UpdateBar()
                        end
                    end,
                },
                value = {
                    type = "range",
                    name = L["Threshold (%)"],
                    min = 0, max = 100, step = 1,
                    order = 2,
                    get = function() return threshold.value end,
                    set = function(_, v)
                        threshold.value = v
                        TargetHealthPercent:ForceSave()
                        if TargetHealthPercent.UpdateBar then
                            TargetHealthPercent:UpdateBar()
                        end
                    end,
                },
                color = {
                    type = "color",
                    name = L["Background RGB"],
                    hasAlpha = false,
                    order = 3,
                    get = function() return unpack(threshold.color) end,
                    set = function(_, r, g, b)
                        threshold.color = {r, g, b}
                        TargetHealthPercent:ForceSave()
                        if TargetHealthPercent.UpdateBar then
                            TargetHealthPercent:UpdateBar()
                        end
                    end,
                },
                textColor = {
                    type = "color",
                    name = L["Text RGB"],
                    hasAlpha = false,
                    order = 4,
                    get = function() return unpack(threshold.textColor) end,
                    set = function(_, r, g, b)
                        threshold.textColor = {r, g, b}
                        TargetHealthPercent:ForceSave()
                        if TargetHealthPercent.UpdateBar then
                            TargetHealthPercent:UpdateBar()
                        end
                    end,
                },
                name = {
                    type = "input",
                    name = L["Name"],
                    order = 5,
                    get = function() return threshold.name or (L["Threshold"].." "..i) end,
                    set = function(_, v)
                        threshold.name = v
                        TargetHealthPercent:ForceSave()

                        recreateOptions()
                        AceConfigRegistry:NotifyChange("TargetHealthPercent")
                    end,
                },
                moveUp = {
                    type = "execute",
                    name = L["Move Up"],
                    order = 6,
                    disabled = function() return i == 1 end,
                    func = function()
                        if i > 1 then
                            local temp = TargetHealthPercent.db.profile.thresholds[i]
                            TargetHealthPercent.db.profile.thresholds[i] = TargetHealthPercent.db.profile.thresholds[i-1]
                            TargetHealthPercent.db.profile.thresholds[i-1] = temp

                            TargetHealthPercent:ForceSave()
                            recreateOptions()
                            AceConfigRegistry:NotifyChange("TargetHealthPercent")
                        end
                    end,
                },
                moveDown = {
                    type = "execute",
                    name = L["Move Down"],
                    order = 7,
                    disabled = function() return i == #TargetHealthPercent.db.profile.thresholds end,
                    func = function()
                        if i < #TargetHealthPercent.db.profile.thresholds then
                            local temp = TargetHealthPercent.db.profile.thresholds[i]
                            TargetHealthPercent.db.profile.thresholds[i] = TargetHealthPercent.db.profile.thresholds[i+1]
                            TargetHealthPercent.db.profile.thresholds[i+1] = temp

                            TargetHealthPercent:ForceSave()
                            recreateOptions()
                            AceConfigRegistry:NotifyChange("TargetHealthPercent")
                        end
                    end,
                },
                remove = {
                    type = "execute",
                    name = L["Remove"],
                    order = 8,
                    confirm = true,
                    confirmText = L["Remove this threshold?"],
                    func = function()
                        table.remove(TargetHealthPercent.db.profile.thresholds, i)
                        print("Порог удален. Оставшиеся пороги: " .. #TargetHealthPercent.db.profile.thresholds)

                        -- Принудительно сохраняем данные
                        TargetHealthPercent:ForceSave()

                        recreateOptions()
                        AceConfigRegistry:NotifyChange("TargetHealthPercent")
                        if TargetHealthPercent.UpdateBar then
                            TargetHealthPercent:UpdateBar()
                        end
                    end,
                },
            },
        }
    end
    return args
end

function recreateOptions()
    if not TargetHealthPercent.db then
        return
    end
    options = {
        type = "group",
        name = L["TargetHealthPercent"],
        args = {
            general = {
                type = "group",
                name = L["General"],
                order = 1,
                args = {
                    locked = {
                        type = "toggle",
                        name = L["Locked"],
                        desc = L["Locks or unlocks bar"],
                        order = 1,
                        get = get,
                        set = set,
                    },
                    showAlways = {
                        type = "toggle",
                        name = L["Always Show"],
                        desc = L["Show bar always"],
                        order = 2,
                        get = get,
                        set = set,
                    },
                    showTarget = {
                        type = "toggle",
                        name = L["Show When Target"],
                        desc = L["Show bar only when you have a target"],
                        order = 3,
                        get = get,
                        set = set,
                    },
                    showCombat = {
                        type = "toggle",
                        name = L["Show In Combat"],
                        desc = L["Show bar while in combat"],
                        order = 4,
                        get = get,
                        set = set,
                    },
                    barAlpha = {
                        type = "range",
                        name = L["Bar Alpha (Opacity)"],
                        desc = L["Bar background opacity"],
                        min = 0, max = 1, step = 0.01,
                        order = 5,
                        get = get,
                        set = set,
                    },
                    barScale = {
                        type = "range",
                        name = L["Bar Scale"],
                        desc = L["Bar scale"],
                        min = 0.25, max = 3, step = 0.01,
                        order = 6,
                        get = get,
                        set = set,
                    },
                    barDec = {
                        type = "range",
                        name = L["Decimal Places"],
                        desc = L["Number of places past the decimal"],
                        min = 0, max = 3, step = 1,
                        order = 7,
                        get = get,
                        set = set,
                    },
                    showHP = {
                        type = "toggle",
                        name = L["Show Max HP"],
                        desc = L["Show maximum health value"],
                        order = 8,
                        get = get,
                        set = set,
                    },
                }
            },
            thresholds = {
                type = "group",
                name = L["Thresholds"],
                order = 2,
                args = GenerateThresholdOptions()
            },
            percentTextColor = {
                type = "color",
                name = L["Percent Text Color"],
                desc = L["Color of percent text if no threshold applies"],
                order = 3,
                hasAlpha = false,
                get = function()
                    local c = TargetHealthPercent.db.profile.percentTextColor
                    return c[1], c[2], c[3]
                end,
                set = function(_, r, g, b)
                    local c = TargetHealthPercent.db.profile.percentTextColor
                    c[1], c[2], c[3] = r, g, b
                    TargetHealthPercent:ForceSave()
                    if TargetHealthPercent.UpdateBar then
                        TargetHealthPercent:UpdateBar()
                    end
                end,
            },
            healthBarColor = {
                type = "color",
                name = L["Health Bar Color"],
                desc = L["Health bar background color"],
                order = 4,
                hasAlpha = false,
                get = function()
                    local c = TargetHealthPercent.db.profile.healthBarColor
                    return c[1], c[2], c[3]
                end,
                set = function(_, r, g, b)
                    local c = TargetHealthPercent.db.profile.healthBarColor
                    c[1], c[2], c[3] = r, g, b
                    TargetHealthPercent:ForceSave()
                    if TargetHealthPercent.UpdateBar then
                        TargetHealthPercent:UpdateBar()
                    end
                end,
            },
        }
    }
    AceConfig:RegisterOptionsTable("TargetHealthPercent", options)
end

-- Функция инициализации конфигурации (вызывается после загрузки аддона)
function TargetHealthPercent.InitializeConfig()
    recreateOptions()
    AceConfigDialog:AddToBlizOptions("TargetHealthPercent", "TargetHealthPercent")
end

-- Если база данных уже инициализирована, создаем конфигурацию немедленно
if TargetHealthPercent.db then
    TargetHealthPercent.InitializeConfig()
end