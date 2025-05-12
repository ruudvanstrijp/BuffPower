-- BuffPowerOptions.lua
-- Configuration options for BuffPower

BuffPower = BuffPower or {}
local L = BuffPower.L -- Localization

function BuffPower:CreateOptionsPanel()
    local panel = CreateFrame("Frame", "BuffPowerOptionsPanel")
    panel.name = "BuffPower" -- Name that appears in the AddOns list

    -- Title
    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("BuffPower " .. L["Configuration"])

    local yOffset = -40

    -- General Settings
    local generalLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    generalLabel:SetPoint("TOPLEFT", 20, yOffset)
    generalLabel:SetText(L["General Settings"])
    yOffset = yOffset - 20

    -- Checkbox: Enable Addon
    local enableAddonCheckbox = CreateFrame("CheckButton", "BuffPowerEnableAddonCheckbox", panel, "UICheckButtonTemplate")
    enableAddonCheckbox:SetPoint("TOPLEFT", 30, yOffset)
    getglobal(enableAddonCheckbox:GetName() .. "Text"):SetText(L["Enable BuffPower"])
    enableAddonCheckbox:SetChecked(BuffPowerDB.enabled)
    enableAddonCheckbox:SetScript("OnClick", function(self)
        BuffPowerDB.enabled = self:GetChecked()
        if BuffPowerDB.enabled then
            BuffPower:OnEnable() -- Re-run enable logic if it was off
        else
            BuffPower:OnDisable() -- Run disable logic
            if BuffPowerFrame then BuffPowerFrame:Hide() end
        end
    end)
    yOffset = yOffset - 30

    -- Checkbox: Show Window
    local showWindowCheckbox = CreateFrame("CheckButton", "BuffPowerShowWindowCheckbox", panel, "UICheckButtonTemplate")
    showWindowCheckbox:SetPoint("TOPLEFT", 30, yOffset)
    getglobal(showWindowCheckbox:GetName() .. "Text"):SetText(L["Show Buff Window"])
    showWindowCheckbox:SetChecked(BuffPowerDB.showWindow)
    showWindowCheckbox:SetScript("OnClick", function(self)
        BuffPowerDB.showWindow = self:GetChecked()
        if BuffPowerDB.showWindow then
            if not BuffPowerFrame then BuffPower:CreateUI() end
            BuffPowerFrame:Show()
            BuffPower:UpdateRoster()
        else
            if BuffPowerFrame then BuffPowerFrame:Hide() end
        end
    end)
    yOffset = yOffset - 30

    -- Checkbox: Lock Window
    local lockWindowCheckbox = CreateFrame("CheckButton", "BuffPowerLockWindowCheckbox", panel, "UICheckButtonTemplate")
    lockWindowCheckbox:SetPoint("TOPLEFT", 30, yOffset)
    getglobal(lockWindowCheckbox:GetName() .. "Text"):SetText(L["Lock Window Position"])
    lockWindowCheckbox:SetChecked(BuffPowerDB.locked)
    lockWindowCheckbox:SetScript("OnClick", function(self)
        BuffPowerDB.locked = self:GetChecked()
    end)
    yOffset = yOffset - 30

    -- Checkbox: Show Tooltips
    local showTooltipsCheckbox = CreateFrame("CheckButton", "BuffPowerShowTooltipsCheckbox", panel, "UICheckButtonTemplate")
    showTooltipsCheckbox:SetPoint("TOPLEFT", 30, yOffset)
    getglobal(showTooltipsCheckbox:GetName() .. "Text"):SetText(L["Show Tooltips on Group Buttons"])
    showTooltipsCheckbox:SetChecked(BuffPowerDB.showTooltips)
    showTooltipsCheckbox:SetScript("OnClick", function(self)
        BuffPowerDB.showTooltips = self:GetChecked()
    end)
    yOffset = yOffset - 30

     -- Checkbox: Show Group Member Names in Tooltip
    local showGroupMemberNamesCheckbox = CreateFrame("CheckButton", "BuffPowerShowGroupMemberNamesCheckbox", panel, "UICheckButtonTemplate")
    showGroupMemberNamesCheckbox:SetPoint("TOPLEFT", 30, yOffset)
    getglobal(showGroupMemberNamesCheckbox:GetName() .. "Text"):SetText(L["Show Group Member Names in Tooltip"])
    showGroupMemberNamesCheckbox:SetChecked(BuffPowerDB.showGroupMemberNames)
    showGroupMemberNamesCheckbox:SetScript("OnClick", function(self)
        BuffPowerDB.showGroupMemberNames = self:GetChecked()
    end)
    yOffset = yOffset - 30

    -- Slider: Window Scale
    yOffset = yOffset - 10
    local scaleLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    scaleLabel:SetPoint("TOPLEFT", 30, yOffset)
    scaleLabel:SetText(L["Window Scale:"] .. string.format(" %.2f", BuffPowerDB.scale or 1.0))
    yOffset = yOffset - 25

    local scaleSlider = CreateFrame("Slider", "BuffPowerScaleSlider", panel, "OptionsSliderTemplate")
    scaleSlider:SetPoint("TOPLEFT", generalLabel, "BOTTOMLEFT", 20, -160) -- Adjust positioning
    scaleSlider:SetMinMaxValues(0.5, 2.0)
    scaleSlider:SetValueStep(0.05)
    scaleSlider:SetValue(BuffPowerDB.scale or 1.0)
    _G[scaleSlider:GetName() .. "Low"]:SetText("0.5x")
    _G[scaleSlider:GetName() .. "High"]:SetText("2.0x")
    _G[scaleSlider:GetName() .. "Text"]:SetText(L["Window Scale"]) -- This is the label above the slider itself
    scaleSlider:SetScript("OnValueChanged", function(self, value)
        BuffPowerDB.scale = value
        if BuffPowerFrame then BuffPowerFrame:SetScale(BuffPowerDB.scale) end
        scaleLabel:SetText(L["Window Scale:"] .. string.format(" %.2f", BuffPowerDB.scale))
    end)
    yOffset = yOffset - 40 -- Account for slider height

    -- Class Enable/Disable Settings
    yOffset = yOffset - 20
    local classSettingsLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    classSettingsLabel:SetPoint("TOPLEFT", 20, yOffset)
    classSettingsLabel:SetText(L["Class Settings (for current player)"])
    yOffset = yOffset - 25

    local function createClassToggle(className, parent, x, currentY)
        local checkbox = CreateFrame("CheckButton", "BuffPowerClassEnable" .. className .. "Checkbox", parent, "UICheckButtonTemplate")
        checkbox:SetPoint("TOPLEFT", x, currentY)
        getglobal(checkbox:GetName() .. "Text"):SetText(L["Enable for "] .. BuffPower.ClassRealNames[className])

        if not BuffPowerDB.classSettings then BuffPowerDB.classSettings = {} end
        if BuffPowerDB.classSettings[className] == nil then BuffPowerDB.classSettings[className] = { enabled = true } end

        checkbox:SetChecked(BuffPowerDB.classSettings[className].enabled)
        checkbox:SetScript("OnClick", function(self)
            BuffPowerDB.classSettings[className].enabled = self:GetChecked()
            local _, myClass = UnitClass("player")
            if myClass == className then -- If changing setting for current player's class
                if BuffPowerDB.classSettings[className].enabled then
                    BuffPower:OnEnable()
                else
                    BuffPower:OnDisable()
                     if BuffPowerFrame then BuffPowerFrame:Hide() end
                end
            end
        end)
        return checkbox
    end

    createClassToggle("MAGE", panel, 30, yOffset)
    yOffset = yOffset - 30
    createClassToggle("PRIEST", panel, 30, yOffset)
    yOffset = yOffset - 30
    createClassToggle("DRUID", panel, 30, yOffset)
    yOffset = yOffset - 40


    -- Reset Button
    local resetButton = CreateFrame("Button", "BuffPowerResetButton", panel, "UIPanelButtonTemplate")
    resetButton:SetText(L["Reset Settings"])
    resetButton:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -16, 16)
    resetButton:SetSize(120, 22)
    resetButton:SetScript("OnClick", function()
        -- Reset BuffPowerDB to defaults (deep copy needed)
        BuffPowerDB = BuffPower.deepcopy(BuffPower.defaults.profile) -- Assuming deepcopy is available globally or via BuffPower
        -- Refresh options panel to show default values
        InterfaceOptionsFrame_OpenToCategory(panel.name) -- Re-opens the current panel to refresh it
        -- Apply changes
        if BuffPowerFrame then
             BuffPowerFrame:ClearAllPoints()
             BuffPowerFrame:SetPoint(BuffPowerDB.position.a1, UIParent, BuffPowerDB.position.a2, BuffPowerDB.position.x, BuffPowerDB.position.y)
             BuffPowerFrame:SetScale(BuffPowerDB.scale)
             if BuffPowerDB.showWindow then BuffPowerFrame:Show() else BuffPowerFrame:Hide() end
        end
        BuffPower:UpdateRoster() -- Update UI based on new settings
        DEFAULT_CHAT_FRAME:AddMessage("BuffPower: " .. L["Settings reset to default."])
    end)


    -- Add the panel to the Interface Options
    InterfaceOptions_AddCategory(panel)
    DEFAULT_CHAT_FRAME:AddMessage("BuffPowerOptions.lua loaded, panel created.")
end

-- Call this when the addon loads, specifically after BuffPowerDB is initialized.
-- It's often called from the main .lua file after DB setup.
-- For now, we'll assume it's called correctly.
-- BuffPower:CreateOptionsPanel() -- This should be called from BuffPower.lua after DB init and L is ready.
-- To ensure L is ready and DB is initialized, this is typically deferred.
-- A simple way is to call it on PLAYER_LOGIN for the first time, or from OnInitialize of main addon.

local optionsPanelInitializer = CreateFrame("Frame")
optionsPanelInitializer:RegisterEvent("PLAYER_LOGIN")
optionsPanelInitializer:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        -- Ensure L is populated by now
        if not BuffPower.L then
            BuffPower.L = setmetatable({}, { __index = function(t, k) return k end })
        end
        BuffPower:CreateOptionsPanel()
        self:UnregisterEvent("PLAYER_LOGIN") -- Run only once
    end
end)
