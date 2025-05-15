-- BuffPowerStandaloneOptions.lua
-- A minimal, always-available standalone config window for WoW Classic Era and all clients

local function BuffPower_ShowStandaloneOptions()
    if BuffPowerStandaloneOptionsFrame and BuffPowerStandaloneOptionsFrame:IsShown() then
        BuffPowerStandaloneOptionsFrame:Hide()
        return
    end

    if not BuffPowerStandaloneOptionsFrame then
        local f = CreateFrame("Frame", "BuffPowerStandaloneOptionsFrame", UIParent, "BackdropTemplate")
        f:SetSize(340, 330)
        f:SetPoint("CENTER")
        f:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 10,
            insets = { left = 3, right = 3, top = 3, bottom = 3 }
        })
        f:SetBackdropColor(0.1,0.1,0.2,0.95)
        f:SetMovable(true)
        f:EnableMouse(true)
        f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", function(self) self:StartMoving() end)
        f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
        f:SetFrameStrata("DIALOG")
        BuffPowerStandaloneOptionsFrame = f

        -- Title
        local title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
        title:SetPoint("TOP", 0, -15)
        title:SetText("BuffPower Settings")

        -- Close Button
        local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)
        close:SetScript("OnClick", function()
            f:Hide()
        end)

        -- Option Y offset
        local y = -40
        -- Helper for buff toggles
        local function addBuffCheckbox(label, key)
            local cb = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
            cb:SetPoint("TOPLEFT", 18, y)
            local text = cb:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            text:SetPoint("LEFT", cb, "RIGHT", 4, 0)
            text:SetText(label)
            cb:SetChecked(BuffPowerDB and BuffPowerDB.buffEnableOptions and BuffPowerDB.buffEnableOptions[key])
            cb:SetScript("OnClick", function(self)
                if not BuffPowerDB.buffEnableOptions then BuffPowerDB.buffEnableOptions = {} end
                BuffPowerDB.buffEnableOptions[key] = self:GetChecked()
                if BuffPower and BuffPower.UpdateUI then BuffPower:UpdateUI() end
            end)
            y = y - 32
        end

        -- All buffs listed with names per BuffPower.BuffTypes; show Spirit, Thorns, ShadowProtection for priest/druid
        for key, info in pairs(BuffPower.BuffTypes or {}) do
            if key == "SPIRIT" or key == "THORNS" or key == "SHADOW" then
                addBuffCheckbox("Enable " .. (info.name or key), key)
            end
        end

        -- Main class/feature toggles
        local classLabel = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        classLabel:SetPoint("TOPLEFT", 18, y - 4)
        classLabel:SetText("Class Module Toggles")
        y = y - 22
        local classes = { "MAGE", "PRIEST", "DRUID" }
        for _, c in ipairs(classes) do
            local cb = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
            cb:SetPoint("TOPLEFT", 18, y)
            local text = cb:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            text:SetPoint("LEFT", cb, "RIGHT", 4, 0)
            text:SetText("Enable for "..(BuffPower.ClassRealNames and BuffPower.ClassRealNames[c] or c))
            cb:SetChecked(BuffPowerDB and BuffPowerDB.classSettings and BuffPowerDB.classSettings[c] and BuffPowerDB.classSettings[c].enabled)
            cb:SetScript("OnClick", function(self)
                if not BuffPowerDB.classSettings then BuffPowerDB.classSettings = {} end
                if not BuffPowerDB.classSettings[c] then BuffPowerDB.classSettings[c] = {} end
                BuffPowerDB.classSettings[c].enabled = self:GetChecked()
                local _, myClass = UnitClass("player")
                if myClass == c then
                    if BuffPowerDB.classSettings[c].enabled then
                        BuffPower:OnEnable()
                    else
                        BuffPower:OnDisable()
                        if BuffPowerFrame then BuffPowerFrame:Hide() end
                    end
                end
            end)
            y = y - 28
        end

        -- Reset to Defaults Button
        local resetB = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        resetB:SetSize(120, 22)
        resetB:SetText("Reset Settings")
        resetB:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 16, 12)
        resetB:SetScript("OnClick", function()
            if BuffPowerDB and BuffPower.defaults and BuffPower.deepcopy then
                BuffPowerDB = BuffPower.deepcopy(BuffPower.defaults.profile)
                if BuffPowerFrame then
                    BuffPowerFrame:ClearAllPoints()
                    BuffPowerFrame:SetPoint(BuffPowerDB.position.a1, UIParent, BuffPowerDB.position.a2, BuffPowerDB.position.x, BuffPowerDB.position.y)
                    BuffPowerFrame:SetScale(BuffPowerDB.scale or 1.0)
                    if BuffPowerDB.showWindow then BuffPowerFrame:Show() else BuffPowerFrame:Hide() end
                end
                BuffPower:UpdateRoster()
                DEFAULT_CHAT_FRAME:AddMessage("BuffPower: Settings reset to default.")
                f:Hide()
            end
        end)

        -- Version / info
        local ver = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        ver:SetPoint("BOTTOMRIGHT", -8, 10)
        ver:SetText("BuffPower Classic, |cffaaaaaa" .. (GetAddOnMetadata and GetAddOnMetadata("BuffPower", "Version") or "") .. "|r")
    end
    BuffPowerStandaloneOptionsFrame:Show()
end

BuffPower.ShowStandaloneOptions = BuffPower_ShowStandaloneOptions