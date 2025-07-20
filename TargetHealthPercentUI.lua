--
TargetHealthPercentUI = {}

function TargetHealthPercentUI.CreatethpBar()
    local self = TargetHealthPercent
    self.barWidth = 38
    self.barHight = 12
    self.bar = CreateFrame("Frame", "TargetHealthPercentBar", UIParent)
    self.bar:SetMovable(true)
    self.bar:EnableMouse(true)
    self.bar:SetSize(self.barWidth, self.barHight+4)
    self.bar:SetScript("OnMouseDown", function (frame, button)
        if button == "LeftButton" and not (self.db and self:GetConfigValue("locked")) then
            frame:StartMoving();
        end
    end)
    self.bar:SetScript("OnMouseUp", function (frame, button)
        if button == "LeftButton" then
            frame:StopMovingOrSizing();
            if self and self.db then
                local point, relativeTo, relativePoint, xOfs, yOfs = frame:GetPoint()
                self.db.profile.barPosition = {
                    point = point,
                    relativeTo = relativeTo and relativeTo:GetName() or "UIParent",
                    relativePoint = relativePoint,
                    xOfs = xOfs,
                    yOfs = yOfs
                }
            end
        end
    end)
    self.bar:SetPoint("CENTER", 0, 0)
    self.bar:Hide()
    self.bar:EnableMouse(false)
    self.barBackground = self.bar:CreateTexture("TargetHealthPercentBarBackground", "BACKGROUND")
    self.barBackground:SetSize(self.barWidth, self.barHight+10)
    self.barBackground:SetTexture("Interface\\Buttons\\WHITE8X8")
    self.barBackground:SetVertexColor(0, 0, 0, 1.0)
    self.barBackground:SetPoint("TOP", 0, -2)
    self.barText = self.bar:CreateFontString("TargetHealthPercentText", "OVERLAY")
    self.barText:SetFont("Fonts\\FRIZQT__.TTF", 11)
    self.barText:SetSize(self.barWidth, self.barHight+0.5)
    self.barText:SetPoint("TOP", 0, -2)
    self.barText:SetShadowOffset(0, 0)
    self.barText:SetShadowColor(0, 0, 0, 0)
    self.barStatus = CreateFrame("StatusBar", "TargetHealthPercentStatusBar", self.bar)
    self.barStatus:SetSize(self.barWidth, self.barHight-2)
    self.barStatus:SetPoint("TOP", 0, -2)
    self.barStatus:SetFrameLevel(self.barStatus:GetParent():GetFrameLevel())
    self.barStatusTexture = self.barStatus:CreateTexture("TargetHealthPercentStatusBarTexture", "BACKGROUND")
end 