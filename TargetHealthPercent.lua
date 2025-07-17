-- Create addon using AceAddon-3.0
local TargetHealthPercent = LibStub("AceAddon-3.0"):NewAddon("TargetHealthPercent", "AceEvent-3.0", "AceConsole-3.0")
local L = TargetHealthPercent_Locale or {}

-- Export to global scope
_G["TargetHealthPercent"] = TargetHealthPercent

-- Default settings
local defaults = {
	profile = {
		showAlways = true,
		showTarget = true,
		showCombat = true,
		thresholds = {},  -- Empty threshold array by default
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
	-- Migration from old TargetHealthPercentConfig to TargetHealthPercentDB format
	if _G["TargetHealthPercentConfig"] and not _G["TargetHealthPercentDB"] then
		print("TargetHealthPercent: Migrating data from old format...")
		_G["TargetHealthPercentDB"] = _G["TargetHealthPercentConfig"]
		_G["TargetHealthPercentConfig"] = nil
	end

	-- Initialize database
	self.db = LibStub("AceDB-3.0"):New("TargetHealthPercentDB", defaults, "Default")

	-- Ensure threshold array is initialized
	if not self.db.profile.thresholds then
		self.db.profile.thresholds = {}
	end

	-- Perform migration
	self:MigrateOldThresholds()

	-- Register slash commands
	self:RegisterChatCommand("thp", "SlashCmdHandler")

	print("TargetHealthPercent v5.3 Loaded. Type /thp for usage")
end

function TargetHealthPercent:OnEnable()
	-- Create UI
	TargetHealthPercentUI.CreatethpBar()

	-- Initialize bar
	self:InitializeBar()

	-- Initialize configuration with small delay
	C_Timer.After(0.1, function()
		if TargetHealthPercent.InitializeConfig then
			TargetHealthPercent.InitializeConfig()
		end
	end)
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

    -- Format percentage with needed decimal places
    local formatStr = "%." .. math.min(math.max(barDec, 0), 3) .. "f%%"
    text = string.format(formatStr, TargetsPercentOfHealth)

    -- Add maximum health if enabled
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

	-- handle color
	self:HandleBarColor(TargetsPercentOfHealth)
	self:ShowOrHideBar();
end

function TargetHealthPercent:ShowOrHideBar()
	if not self.db then
		return -- Exit if database is not ready
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



-- Migration of old thresholds to thresholds array (one time)
function TargetHealthPercent:MigrateOldThresholds()
    local db = self.db.profile
    -- Check if migration was already completed
    if db.migrationCompleted then
        return
    end

    if not db.thresholds then
        db.thresholds = {}
        -- Standard threshold
        if db.enableColorThreshold4 and db.colorThreshold4 and db.color4 and db.textColor4 then
            table.insert(db.thresholds, {
                value = db.colorThreshold4,
                color = db.color4,
                textColor = db.textColor4,
                enabled = db.enableColorThreshold4,
                name = "Standard Threshold"
            })
        end
        -- Threshold 1
        if db.enableColorThreshold1 and db.colorThreshold1 and db.color1 and db.textColor1 then
            table.insert(db.thresholds, {
                value = db.colorThreshold1,
                color = db.color1,
                textColor = db.textColor1,
                enabled = db.enableColorThreshold1,
                name = "Threshold 1"
            })
        end
        -- Threshold 2
        if db.enableColorThreshold2 and db.colorThreshold2 and db.color2 and db.textColor2 then
            table.insert(db.thresholds, {
                value = db.colorThreshold2,
                color = db.color2,
                textColor = db.textColor2,
                enabled = db.enableColorThreshold2,
                name = "Threshold 2"
            })
        end
        -- Threshold 3
        if db.enableColorThreshold3 and db.colorThreshold3 and db.color3 and db.textColor3 then
            table.insert(db.thresholds, {
                value = db.colorThreshold3,
                color = db.color3,
                textColor = db.textColor3,
                enabled = db.enableColorThreshold3,
                name = "Threshold 3"
            })
        end
    end

    -- Mark migration as completed
    db.migrationCompleted = true
end

-- Регистрируем AceConfig (конфигурация регистрируется в TargetHealthPercent_Config.lua)

function TargetHealthPercent:GetConfigValue(key)
    if not self.db then
        -- Return default values if database is not ready
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
        return -- Ignore if database is not ready
    end
    self.db.profile[key] = value
    -- Don't call UpdateBar() here to avoid recursion
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
		-- If position is not saved, set to center
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
	print("Resetting config to defaults")
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
	-- AceDB automatically saves data, just force write
	if self.db then
		-- Force write to SavedVariables
		self.db:RegisterDefaults(defaults)
	end
end

function TargetHealthPercent:ShowHelp()
	print(L["Slash commands (/thp):"])
	print(" " .. L["/thp lock: Locks Target Health Percent bar's position"])
	print(" " .. L["/thp unlock: unLocks Target Health Percent bar's position"])
	print(" " .. L["/thp config: Open addon config menu (also found in Addon tab in Blizzard's Interface menu)"])
	print(" " .. L["/thp reset:  Resets your config to defaults"])
end


-- Fix HandleBarColor: remove shadow and make colors brighter
function TargetHealthPercent:HandleBarColor(TargetsPercentOfHealth)
    if not self.db then
        return -- Exit if database is not ready
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

    -- Set background with customizable color - use white texture for bright colors
    self.barBackground:SetTexture("Interface\\Buttons\\WHITE8X8")
    local healthColor = self:GetConfigValue("healthBarColor")
    if healthColor and type(healthColor) == "table" and #healthColor >= 3 then
        self.barBackground:SetVertexColor(healthColor[1], healthColor[2], healthColor[3], self:GetConfigValue("barAlpha"))
    else
        self.barBackground:SetVertexColor(0, 0, 0, self:GetConfigValue("barAlpha")) -- Black by default
    end

    -- Completely remove text shadow
    self.barText:SetShadowOffset(0, 0)
    self.barText:SetShadowColor(0, 0, 0, 0)

    -- Set white color by default
    self.barText:SetTextColor(1, 1, 1, 1)

    -- At 0% health don't apply thresholds, use standard settings
    if TargetsPercentOfHealth <= 0 then
        -- Use standard health bar background color
        local healthColor = self:GetConfigValue("healthBarColor")
        local alpha = self:GetConfigValue("barAlpha")
        if healthColor and type(healthColor) == "table" and #healthColor >= 3 then
            self.barBackground:SetVertexColor(healthColor[1], healthColor[2], healthColor[3], alpha)
        else
            self.barBackground:SetVertexColor(0, 0, 0, alpha) -- Black by default
        end
        -- Use standard percent text color
        local pct = self:GetConfigValue("percentTextColor")
        if pct and type(pct) == "table" and #pct >= 3 then
            self.barText:SetTextColor(pct[1], pct[2], pct[3], 1)
        else
            self.barText:SetTextColor(1, 1, 1, 1)
        end
        return
    end

    -- Create copy of threshold array and sort by ascending values
    -- This ensures that lower threshold values take priority over higher threshold values
    local sortedThresholds = {}
    for _, threshold in ipairs(db.thresholds or {}) do
        if threshold.enabled then
            table.insert(sortedThresholds, threshold)
        end
    end

    -- Sort by ascending values (from smaller to larger)
    -- This means that if multiple thresholds apply to current health, the lowest HP% threshold will be used
    table.sort(sortedThresholds, function(a, b) return a.value < b.value end)

    -- Find thresholds that apply to current health (where current HP is below or equal to the threshold value)
    -- A threshold triggers when current HP is below or equal to the threshold value
    -- Floor HP to avoid floating point precision issues (75.887% becomes 75%)
    local flooredHP = math.floor(TargetsPercentOfHealth)

    for _, threshold in ipairs(sortedThresholds) do
        if flooredHP <= threshold.value then
            local bgColor = safeColor(threshold.color, {1,1,1})
            local textColor = safeColor(threshold.textColor, {1,1,1})
            -- Alpha for texture is set via SetVertexColor with 4th parameter
            local alpha = self:GetConfigValue("barAlpha")
            self.barBackground:SetVertexColor(bgColor[1], bgColor[2], bgColor[3], alpha)
            self.barText:SetTextColor(textColor[1], textColor[2], textColor[3], 1)
            return
        end
    end
    -- If no threshold triggered, use percentTextColor
    local pct = self:GetConfigValue("percentTextColor")
    if pct and type(pct) == "table" and #pct >= 3 then
        self.barText:SetTextColor(pct[1], pct[2], pct[3], 1)
    else
        self.barText:SetTextColor(1, 1, 1, 1)
    end
end
