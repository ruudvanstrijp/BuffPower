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
    title:SetText("BuffPower " .. (L["Configuration"] or "Configuration")) -- Added fallback for L

    local yOffset = -40

    -- General Settings
    local generalLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    generalLabel:SetPoint("TOPLEFT", 20, yOffset)
    generalLabel:SetText(L["General Settings"] or "General Settings")
    yOffset = yOffset - 20

    -- Checkbox: Enable Addon
    local enableAddonCheckbox = CreateFrame("CheckButton", "BuffPowerEnableAddonCheckbox", panel, "UICheckButtonTemplate")
    enableAddonCheckbox:SetPoint("TOPLEFT", 30, yOffset)
    getglobal(enableAddonCheckbox:GetName() .. "Text"):SetText(L["Enable BuffPower"] or "Enable BuffPower")
    -- Ensure BuffPowerDB and its fields exist before accessing
    if BuffPowerDB and BuffPowerDB.enabled ~= nil then
        enableAddonCheckbox:SetChecked(BuffPowerDB.enabled)
    else
        enableAddonCheckbox:SetChecked(true) -- Default to true if DB not ready (should be by now with fix)
    end
    enableAddonCheckbox:SetScript("OnClick", function(self)
        if BuffPowerDB then
            BuffPowerDB.enabled = self:GetChecked()
            if BuffPowerDB.enabled then
                BuffPower:OnEnable() -- Re-run enable logic if it was off
            else
                BuffPower:OnDisable() -- Run disable logic
                if BuffPowerFrame then BuffPowerFrame:Hide() end
            end
        end
    end)
    yOffset = yOffset - 30

    -- Checkbox: Show Window
    local showWindowCheckbox = CreateFrame("CheckButton", "BuffPowerShowWindowCheckbox", panel, "UICheckButtonTemplate")
    showWindowCheckbox:SetPoint("TOPLEFT", 30, yOffset)
    getglobal(showWindowCheckbox:GetName() .. "Text"):SetText(L["Show Buff Window"] or "Show Buff Window")
    if BuffPowerDB and BuffPowerDB.showWindow ~= nil then
        showWindowCheckbox:SetChecked(BuffPowerDB.showWindow)
    else
        showWindowCheckbox:SetChecked(true)
    end
    showWindowCheckbox:SetScript("OnClick", function(self)
        if BuffPowerDB then
            BuffPowerDB.showWindow = self:GetChecked()
            if BuffPowerDB.showWindow then
                if not BuffPowerFrame then BuffPower:CreateUI() end
                if BuffPowerFrame then BuffPowerFrame:Show() end
                BuffPower:UpdateRoster()
            else
                if BuffPowerFrame then BuffPowerFrame:Hide() end
            end
        end
    end)
    yOffset = yOffset - 30

    -- Checkbox: Lock Window
    local lockWindowCheckbox = CreateFrame("CheckButton", "BuffPowerLockWindowCheckbox", panel, "UICheckButtonTemplate")
    lockWindowCheckbox:SetPoint("TOPLEFT", 30, yOffset)
    getglobal(lockWindowCheckbox:GetName() .. "Text"):SetText(L["Lock Window Position"] or "Lock Window Position")
    if BuffPowerDB and BuffPowerDB.locked ~= nil then
        lockWindowCheckbox:SetChecked(BuffPowerDB.locked)
    else
        lockWindowCheckbox:SetChecked(false)
    end
    lockWindowCheckbox:SetScript("OnClick", function(self)
        if BuffPowerDB then BuffPowerDB.locked = self:GetChecked() end
    end)
    yOffset = yOffset - 30

    -- Checkbox: Show Tooltips
    local showTooltipsCheckbox = CreateFrame("CheckButton", "BuffPowerShowTooltipsCheckbox", panel, "UICheckButtonTemplate")
    showTooltipsCheckbox:SetPoint("TOPLEFT", 30, yOffset)
    getglobal(showTooltipsCheckbox:GetName() .. "Text"):SetText(L["Show Tooltips on Group Buttons"] or "Show Tooltips on Group Buttons")
    if BuffPowerDB and BuffPowerDB.showTooltips ~= nil then
        showTooltipsCheckbox:SetChecked(BuffPowerDB.showTooltips)
    else
        showTooltipsCheckbox:SetChecked(true)
    end
    showTooltipsCheckbox:SetScript("OnClick", function(self)
        if BuffPowerDB then BuffPowerDB.showTooltips = self:GetChecked() end
    end)
    yOffset = yOffset - 30

     -- Checkbox: Show Group Member Names in Tooltip
    local showGroupMemberNamesCheckbox = CreateFrame("CheckButton", "BuffPowerShowGroupMemberNamesCheckbox", panel, "UICheckButtonTemplate")
    showGroupMemberNamesCheckbox:SetPoint("TOPLEFT", 30, yOffset)
    getglobal(showGroupMemberNamesCheckbox:GetName() .. "Text"):SetText(L["Show Group Member Names in Tooltip"] or "Show Group Member Names in Tooltip")
    if BuffPowerDB and BuffPowerDB.showGroupMemberNames ~= nil then
        showGroupMemberNamesCheckbox:SetChecked(BuffPowerDB.showGroupMemberNames)
    else
        showGroupMemberNamesCheckbox:SetChecked(true)
    end
    showGroupMemberNamesCheckbox:SetScript("OnClick", function(self)
        if BuffPowerDB then BuffPowerDB.showGroupMemberNames = self:GetChecked() end
    end)
    yOffset = yOffset - 30

    -- Slider: Window Scale
    yOffset = yOffset - 10
    local scaleLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    scaleLabel:SetPoint("TOPLEFT", 30, yOffset)
    local currentScale = (BuffPowerDB and BuffPowerDB.scale) or 1.0
    scaleLabel:SetText((L["Window Scale:"] or "Window Scale:") .. string.format(" %.2f", currentScale))
    yOffset = yOffset - 25

    local scaleSlider = CreateFrame("Slider", "BuffPowerScaleSlider", panel, "OptionsSliderTemplate")
    scaleSlider:SetPoint("TOPLEFT", 30, yOffset) -- Adjusted positioning relative to previous element
    scaleSlider:SetWidth(180) -- Typical width for options sliders
    scaleSlider:SetMinMaxValues(0.5, 2.0)
    scaleSlider:SetValueStep(0.05)
    scaleSlider:SetValue(currentScale)
    _G[scaleSlider:GetName() .. "Low"]:SetText("0.5x")
    _G[scaleSlider:GetName() .. "High"]:SetText("2.0x")
    _G[scaleSlider:GetName() .. "Text"]:SetText(L["Window Scale"] or "Window Scale")
    scaleSlider:SetScript("OnValueChanged", function(self, value)
        if BuffPowerDB then BuffPowerDB.scale = value end
        if BuffPowerFrame then BuffPowerFrame:SetScale(value) end
        scaleLabel:SetText((L["Window Scale:"] or "Window Scale:") .. string.format(" %.2f", value))
    end)
    yOffset = yOffset - 40

    -- Class Enable/Disable Settings
    yOffset = yOffset - 20
    local classSettingsLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    classSettingsLabel:SetPoint("TOPLEFT", 20, yOffset)
    classSettingsLabel:SetText(L["Class Settings (for current player)"] or "Class Settings (for current player)")
    yOffset = yOffset - 25

    local function createClassToggle(className, parent, x, currentYVal)
        local checkbox = CreateFrame("CheckButton", "BuffPowerClassEnable" .. className .. "Checkbox", parent, "UICheckButtonTemplate")
        checkbox:SetPoint("TOPLEFT", x, currentYVal)
        local classDisplayName = (BuffPower.ClassRealNames and BuffPower.ClassRealNames[className]) or className
        getglobal(checkbox:GetName() .. "Text"):SetText((L["Enable for "] or "Enable for ") .. classDisplayName)

        local isChecked = true -- Default
        if BuffPowerDB and BuffPowerDB.classSettings and BuffPowerDB.classSettings[className] then
            isChecked = BuffPowerDB.classSettings[className].enabled
        end
        checkbox:SetChecked(isChecked)

        checkbox:SetScript("OnClick", function(self)
            if BuffPowerDB then
                if not BuffPowerDB.classSettings then BuffPowerDB.classSettings = {} end
                if not BuffPowerDB.classSettings[className] then BuffPowerDB.classSettings[className] = {} end
                BuffPowerDB.classSettings[className].enabled = self:GetChecked()

                local _, myClass = UnitClass("player")
                if myClass == className then
                    if BuffPowerDB.classSettings[className].enabled then
                        BuffPower:OnEnable()
                    else
                        BuffPower:OnDisable()
                        if BuffPowerFrame then BuffPowerFrame:Hide() end
                    end
                end
            end
        end)
        return checkbox
    end

    if BuffPower.ClassRealNames then -- Ensure ClassRealNames is available
      for _, classKey in pairs({"MAGE", "PRIEST", "DRUID"}) do -- Iterate defined classes
          if BuffPower.ClassRealNames[classKey] then
              createClassToggle(classKey, panel, 30, yOffset)
              yOffset = yOffset - 30
          end
      end
    end
    yOffset = yOffset - 10 -- Extra spacing


    -- Reset Button
    local resetButton = CreateFrame("Button", "BuffPowerResetButton", panel, "UIPanelButtonTemplate")
    resetButton:SetText(L["Reset Settings"] or "Reset Settings")
    resetButton:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 16, 16) -- Changed to bottom left
    resetButton:SetSize(120, 22)
    resetButton:SetScript("OnClick", function()
        if BuffPowerDB and BuffPower.defaults and BuffPower.deepcopy then
            BuffPowerDB = BuffPower.deepcopy(BuffPower.defaults.profile)
            if InterfaceOptionsFrame_OpenToCategory and panel.name then
                 InterfaceOptionsFrame_OpenToCategory(panel.name)
            end
            if BuffPowerFrame then
                 BuffPowerFrame:ClearAllPoints()
                 BuffPowerFrame:SetPoint(BuffPowerDB.position.a1, UIParent, BuffPowerDB.position.a2, BuffPowerDB.position.x, BuffPowerDB.position.y)
                 BuffPowerFrame:SetScale(BuffPowerDB.scale or 1.0)
                 if BuffPowerDB.showWindow then BuffPowerFrame:Show() else BuffPowerFrame:Hide() end
            end
            BuffPower:UpdateRoster()
            DEFAULT_CHAT_FRAME:AddMessage("BuffPower: " .. (L["Settings reset to default."] or "Settings reset to default."))
        end
    end)


    -- Add the panel to the Interface Options
    InterfaceOptions_AddCategory(panel)
    -- DEFAULT_CHAT_FRAME:AddMessage("BuffPowerOptions.lua: Panel registered.") -- For debugging
end

--[[
Removed the optionsPanelInitializer Frame and its PLAYER_LOGIN event.
The BuffPower:CreateOptionsPanel() function will now be called from BuffPower.lua
after BuffPowerDB is initialized.
Added some nil checks and fallbacks for L[] strings just in case, though
.toc order should handle L.
Added nil checks for BuffPowerDB before accessing its fields during initial setup of checkboxes/sliders.
]]
