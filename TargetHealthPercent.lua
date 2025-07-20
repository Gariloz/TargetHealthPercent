-- Создаем аддон используя AceAddon-3.0
local TargetHealthPercent = LibStub("AceAddon-3.0"):NewAddon("TargetHealthPercent", "AceEvent-3.0", "AceConsole-3.0")
local L = TargetHealthPercent_Locale or {}

-- Экспортируем в глобальную область видимости
_G["TargetHealthPercent"] = TargetHealthPercent

-- Настройки по умолчанию
local defaults = {
	profile = {
		showAlways = true,
		showTarget = true,
		showCombat = true,
		thresholds = {},  -- Пустой массив порогов по умолчанию
		showHP = false,
		barAlpha = 1.0,
		barScale = 2.0,
		barDec = 0,
		locked = false,
		percentTextColor = {1, 1, 1},
		healthBarColor = {0, 0, 0},
		barPosition = nil,
		migrationCompleted = false
	}
}

-- Вместо глобальных переменных используем таблицу TargetHealthPercent для хранения объектов бара
TargetHealthPercent.barWidth = 38
TargetHealthPercent.barHight = 12

function TargetHealthPercent:OnInitialize()
	-- Миграция из старого формата TargetHealthPercentConfig в TargetHealthPercentDB
	if _G["TargetHealthPercentConfig"] and not _G["TargetHealthPercentDB"] then
		print("TargetHealthPercent: Миграция данных из старого формата...")
		_G["TargetHealthPercentDB"] = _G["TargetHealthPercentConfig"]
		_G["TargetHealthPercentConfig"] = nil
	end

	-- Инициализация базы данных
	self.db = LibStub("AceDB-3.0"):New("TargetHealthPercentDB", defaults, "Default")

	-- Убеждаемся что массив порогов инициализирован
	if not self.db.profile.thresholds then
		self.db.profile.thresholds = {}
	end

	-- Выполняем миграцию
	self:MigrateOldThresholds()

	-- Регистрируем slash команды
	self:RegisterChatCommand("thp", "SlashCmdHandler")

	print("TargetHealthPercent v5.3 Загружен. Введите /thp для использования")
end

function TargetHealthPercent:OnEnable()
	-- Создаем UI
	TargetHealthPercentUI.CreatethpBar()

	-- Инициализируем бар
	self:InitializeBar()

	-- Инициализируем конфигурацию сразу, без задержки
	if TargetHealthPercent.InitializeConfig then
		TargetHealthPercent.InitializeConfig()
	end
end

function TargetHealthPercent:InitializeBar()
    -- Используем локальные переменные через self
    if self.bar and self.bar.SetScale then
        self.bar:SetScale(self:GetConfigValue("barScale"))
    end
    if self.barBackground and self.barBackground.SetAlpha then
        self.barBackground:SetAlpha(self:GetConfigValue("barAlpha"))
    end
    self:RestoreBarPosition()
    self:ShowOrHideBar()
    self.UPDATE_INTERVAL = 0.09
    self.TIME_SINCE_LAST_UPDATE = 0
    if not self.updateFrame then
        self.updateFrame = CreateFrame("Frame")
        self.updateFrame:SetScript("OnUpdate", function(frame, elapsed)
            if self.db then
                self:OnUpdate(elapsed)
            end
        end)
    end
    -- Удаляем collectgarbage(collect) и UpdateAddOnMemoryUsage()
end

function TargetHealthPercent:OnUpdate(elapsed)
	self.TIME_SINCE_LAST_UPDATE = self.TIME_SINCE_LAST_UPDATE + elapsed
	while (self.TIME_SINCE_LAST_UPDATE > self.UPDATE_INTERVAL) do
		self:UpdateBar()
		self.TIME_SINCE_LAST_UPDATE = self.TIME_SINCE_LAST_UPDATE - self.UPDATE_INTERVAL
	end
end

function TargetHealthPercent:UpdateBar()
    if not self.db then
        return
    end
    -- Применяем scale только если bar существует
    if self.bar and self.bar.SetScale then
        self.bar:SetScale(self:GetConfigValue("barScale"))
    end

    local barDec = self:GetConfigValue("barDec")
    local showHP = self:GetConfigValue("showHP")
    local maxHealth = UnitHealthMax("target")
    local currentHealth = UnitHealth("target")

    local TargetsPercentOfHealth = maxHealth > 0 and (currentHealth / maxHealth * 100) or 0
    local text = ""

    -- Форматируем процент с нужным количеством знаков после запятой
    local formatStr = "%." .. math.min(math.max(barDec, 0), 3) .. "f%%"
    text = string.format(formatStr, TargetsPercentOfHealth)

    -- Добавляем максимальное здоровье если включено
    if showHP then
        text = text .. " " .. self:FormatNumber(maxHealth)
    end

    -- Проверяем существование текстового объекта
    if self.barText and self.barText.SetText then
        self.barText:SetText(text)
        local textWidth = self.barText:GetStringWidth()
        local minWidth = self.barWidth
        local actualWidth = math.max(minWidth, textWidth + 20)
        if self.bar and self.bar.SetSize then
            self.bar:SetSize(actualWidth, self.barHight+4)
        end
        if self.barBackground and self.barBackground.SetSize then
            self.barBackground:SetSize(actualWidth, self.barHight)
        end
        if self.barText and self.barText.SetSize then
            self.barText:SetSize(actualWidth, self.barHight+0.5)
        end
    end

	-- обрабатываем цвет
	self:HandleBarColor(TargetsPercentOfHealth)
	self:ShowOrHideBar();
end

function TargetHealthPercent:ShowOrHideBar()
	if not self.db then
		return -- Выходим если база данных не готова
	end

	if self:GetConfigValue("locked") then
		self:SetLock(true)
		if self.bar and self.bar.EnableMouse then
			self.bar:EnableMouse(false)
		end
	else
		self:SetLock(false)
		if self.bar and self.bar.EnableMouse then
			self.bar:EnableMouse(true)
		end
	end

	if self:GetConfigValue("showAlways") then
		if self.bar then self.bar:Show() end
		return
	end

	if self:GetConfigValue("showTarget") and self:GetConfigValue("showCombat") then
		if UnitHealthMax("target") > 0 and UnitAffectingCombat("player")  then
			if self.bar then self.bar:Show() end
		else
			if self.bar then self.bar:Hide() end
		end
		return
	end

	if self:GetConfigValue("showTarget") then
		if UnitHealthMax("target") > 0   then
			if self.bar then self.bar:Show() end
			return
		end
	end

	if self:GetConfigValue("showCombat") then
		if UnitAffectingCombat("player") then
			if self.bar then self.bar:Show() end
			return
		end
	end
	if self.bar then self.bar:Hide() end
end

function TargetHealthPercent:SetLock(newValue)
	self:SetConfigValue("locked", newValue)
end



-- Миграция старых порогов в массив порогов (одноразово)
function TargetHealthPercent:MigrateOldThresholds()
    local db = self.db.profile
    -- Проверяем была ли миграция уже выполнена
    if db.migrationCompleted then
        return
    end

    if not db.thresholds then
        db.thresholds = {}
        -- Стандартный порог
        if db.enableColorThreshold4 and db.colorThreshold4 and db.color4 and db.textColor4 then
            table.insert(db.thresholds, {
                value = db.colorThreshold4,
                color = db.color4,
                textColor = db.textColor4,
                enabled = db.enableColorThreshold4,
                name = "Стандартный порог"
            })
        end
        -- Порог 1
        if db.enableColorThreshold1 and db.colorThreshold1 and db.color1 and db.textColor1 then
            table.insert(db.thresholds, {
                value = db.colorThreshold1,
                color = db.color1,
                textColor = db.textColor1,
                enabled = db.enableColorThreshold1,
                name = "Порог 1"
            })
        end
        -- Порог 2
        if db.enableColorThreshold2 and db.colorThreshold2 and db.color2 and db.textColor2 then
            table.insert(db.thresholds, {
                value = db.colorThreshold2,
                color = db.color2,
                textColor = db.textColor2,
                enabled = db.enableColorThreshold2,
                name = "Порог 2"
            })
        end
        -- Порог 3
        if db.enableColorThreshold3 and db.colorThreshold3 and db.color3 and db.textColor3 then
            table.insert(db.thresholds, {
                value = db.colorThreshold3,
                color = db.color3,
                textColor = db.textColor3,
                enabled = db.enableColorThreshold3,
                name = "Порог 3"
            })
        end
    end

    -- Отмечаем миграцию как завершенную
    db.migrationCompleted = true
end

-- Регистрируем AceConfig (конфигурация регистрируется в TargetHealthPercent_Config.lua)

function TargetHealthPercent:GetConfigValue(key)
    if not self.db then
        -- Возвращаем значения по умолчанию если база данных не готова
        local defaultValues = {
            showAlways = true,
            showTarget = true,
            showCombat = true,
            thresholds = {},
            showHP = false,
            barAlpha = 1.0,
            barScale = 2.0,
            barDec = 0,
            locked = false,
            percentTextColor = {1, 1, 1},
            healthBarColor = {0, 0, 0},
            barPosition = nil,
            migrationCompleted = false
        }
        return defaultValues[key]
    end
    return self.db.profile[key]
end

function TargetHealthPercent:SetConfigValue(key, value)
    if not self.db then
        return -- Игнорируем если база данных не готова
    end
    self.db.profile[key] = value
    -- Не вызываем UpdateBar() здесь чтобы избежать рекурсии
end

function TargetHealthPercent:RestoreBarPosition()
	if not TargetHealthPercentBar then
		return
	end

	local pos = self:GetConfigValue("barPosition")
	if pos and pos.point then
		TargetHealthPercentBar:ClearAllPoints()
		local relativeTo = _G[pos.relativeTo] or UIParent
		TargetHealthPercentBar:SetPoint(pos.point, relativeTo, pos.relativePoint, pos.xOfs, pos.yOfs)
	else
		-- Если позиция не сохранена, устанавливаем в центр
		TargetHealthPercentBar:ClearAllPoints()
		TargetHealthPercentBar:SetPoint('CENTER', UIParent, 'CENTER', 0, 0)
	end
end

function TargetHealthPercent:FormatNumber(num)
    if num <= 999 then
        return tostring(num)
    elseif num < 999999 then
        return string.format("%.1fk", num / 1000)
    elseif num < 999999999 then
        return string.format("%.1fm", num / 1000000)
    else
        return string.format("%.1fb", num / 1000000000)
    end
end

function TargetHealthPercent:SetConfigToDefaults()
	print("Сброс конфигурации к значениям по умолчанию")
	self.db:ResetProfile()
	TargetHealthPercentBar:ClearAllPoints()
	TargetHealthPercentBar:SetPoint('CENTER', UIParent)
	TargetHealthPercentBar:SetScale(self:GetConfigValue("barScale"))
	self:ShowOrHideBar()
end

function TargetHealthPercent:SlashCmdHandler(msg)
	local cmd = string.lower(msg)
	if cmd == "config" then
		InterfaceOptionsFrame_OpenToCategory("TargetHealthPercent")
	elseif cmd == "lock" then
		self:SetLock(true)
	elseif cmd == "unlock" then
		self:SetLock(false)
	elseif cmd == "reset" then
		self:SetConfigToDefaults()
	else
		self:ShowHelp()
	end
end

function TargetHealthPercent:ForceSave()
	-- AceDB автоматически сохраняет данные, просто принудительно записываем
	if self.db then
		-- Принудительная запись в SavedVariables
		self.db:RegisterDefaults(defaults)
	end
end

function TargetHealthPercent:ShowHelp()
	print(L["Slash команды (/thp):"])
	print(" " .. L["/thp lock: Блокирует позицию бара Target Health Percent"])
	print(" " .. L["/thp unlock: Разблокирует позицию бара Target Health Percent"])
	print(" " .. L["/thp config: Открывает меню конфигурации аддона (также находится во вкладке Аддоны в меню Интерфейс Blizzard)"])
	print(" " .. L["/thp reset: Сбрасывает вашу конфигурацию к значениям по умолчанию"])
end


-- Исправляем HandleBarColor: убираем тень и делаем цвета ярче
function TargetHealthPercent:HandleBarColor(TargetsPercentOfHealth)
    if not self.db then
        return -- Выходим если база данных не готова
    end

    local function safeColor(c, def)
        if type(c) == "table" and #c == 3 then
            return c
        end
        if type(c) == "table" and c[1] and c[2] and c[3] then
            return {c[1], c[2], c[3]}
        end
        return def
    end
    local db = self.db.profile

    -- Устанавливаем фон с настраиваемым цветом - используем белую текстуру для ярких цветов
    self.barBackground:SetTexture("Interface\\Buttons\\WHITE8X8")
    local healthColor = self:GetConfigValue("healthBarColor")
    if healthColor and type(healthColor) == "table" and #healthColor >= 3 then
        self.barBackground:SetVertexColor(healthColor[1], healthColor[2], healthColor[3], self:GetConfigValue("barAlpha"))
    else
        self.barBackground:SetVertexColor(0, 0, 0, self:GetConfigValue("barAlpha")) -- Черный по умолчанию
    end

    -- Полностью убираем тень текста
    self.barText:SetShadowOffset(0, 0)
    self.barText:SetShadowColor(0, 0, 0, 0)

    -- Устанавливаем белый цвет по умолчанию
    self.barText:SetTextColor(1, 1, 1, 1)

    -- При 0% здоровья не применяем пороги, используем стандартные настройки
    if TargetsPercentOfHealth <= 0 then
        -- Используем стандартный цвет фона бара здоровья
        local healthColor = self:GetConfigValue("healthBarColor")
        local alpha = self:GetConfigValue("barAlpha")
        if healthColor and type(healthColor) == "table" and #healthColor >= 3 then
            self.barBackground:SetVertexColor(healthColor[1], healthColor[2], healthColor[3], alpha)
        else
            self.barBackground:SetVertexColor(0, 0, 0, alpha) -- Черный по умолчанию
        end
        -- Используем стандартный цвет текста процентов
        local pct = self:GetConfigValue("percentTextColor")
        if pct and type(pct) == "table" and #pct >= 3 then
            self.barText:SetTextColor(pct[1], pct[2], pct[3], 1)
        else
            self.barText:SetTextColor(1, 1, 1, 1)
        end
        return
    end

    -- Создаем копию массива порогов и сортируем по возрастанию значений
    -- Это гарантирует что пороги с меньшими значениями имеют приоритет над порогами с большими значениями
    local sortedThresholds = {}
    for _, threshold in ipairs(db.thresholds or {}) do
        if threshold.enabled then
            table.insert(sortedThresholds, threshold)
        end
    end

    -- Сортируем по возрастанию значений (от меньшего к большему)
    -- Это означает что если несколько порогов применяются к текущему здоровью, будет использован порог с наименьшим процентом HP
    table.sort(sortedThresholds, function(a, b) return a.value < b.value end)

    -- Находим пороги которые применяются к текущему здоровью (где текущий HP ниже или равен значению порога)
    -- Порог срабатывает когда текущий HP ниже или равен значению порога
    -- Округляем HP вниз чтобы избежать проблем с точностью чисел с плавающей точкой (75.887% становится 75%)
    local flooredHP = math.floor(TargetsPercentOfHealth)

    for _, threshold in ipairs(sortedThresholds) do
        if flooredHP <= threshold.value then
            local bgColor = safeColor(threshold.color, {1,1,1})
            local textColor = safeColor(threshold.textColor, {1,1,1})
            -- Альфа для текстуры устанавливается через SetVertexColor с 4-м параметром
            local alpha = self:GetConfigValue("barAlpha")
            self.barBackground:SetVertexColor(bgColor[1], bgColor[2], bgColor[3], alpha)
            self.barText:SetTextColor(textColor[1], textColor[2], textColor[3], 1)
            return
        end
    end
    -- Если ни один порог не сработал, используем percentTextColor
    local pct = self:GetConfigValue("percentTextColor")
    if pct and type(pct) == "table" and #pct >= 3 then
        self.barText:SetTextColor(pct[1], pct[2], pct[3], 1)
    else
        self.barText:SetTextColor(1, 1, 1, 1)
    end
end
