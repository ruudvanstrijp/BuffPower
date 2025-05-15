-- BuffPowerOptions.lua
-- Configuration options for BuffPower

local L = BuffPower.L or setmetatable({}, {__index=function(t,k) return k end}) -- Robust Localization fallback

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
-- Extra Buff Options section (dynamic/optional buffs)
    local extraBuffLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    extraBuffLabel:SetPoint("TOPLEFT", 20, yOffset)
    extraBuffLabel:SetText("Buff Options")
    yOffset = yOffset - 20

    -- Ensure BuffPowerDB.buffEnableOptions exists & has defaults for optional buffs
    if not BuffPowerDB.buffEnableOptions then BuffPowerDB.buffEnableOptions = {} end
    if BuffPower.BuffTypes then
        for key, info in pairs(BuffPower.BuffTypes) do
            if info.is_optional and BuffPowerDB.buffEnableOptions[key] == nil then
                BuffPowerDB.buffEnableOptions[key] = true
            end
            -- Enable Spirit by default for priests if it exists
            if key == "SPIRIT" and BuffPowerDB.buffEnableOptions[key] == nil then
                BuffPowerDB.buffEnableOptions[key] = true
            end
        end
    end

    -- Helper for creating a buff enable checkbox
    local function createBuffEnableCheckbox(buffKey, label, parent, y)
        local enable = true
        if BuffPowerDB and BuffPowerDB.buffEnableOptions and BuffPowerDB.buffEnableOptions[buffKey] ~= nil then
            enable = BuffPowerDB.buffEnableOptions[buffKey]
        end
        local cb = CreateFrame("CheckButton", "BuffPowerBuffEnable"..buffKey.."Checkbox", parent, "UICheckButtonTemplate")
        cb:SetPoint("TOPLEFT", 30, y)
        getglobal(cb:GetName() .. "Text"):SetText("Enable " .. label)
        cb:SetChecked(enable)
        cb:SetScript("OnClick", function(self)
            if not BuffPowerDB.buffEnableOptions then BuffPowerDB.buffEnableOptions = {} end
            BuffPowerDB.buffEnableOptions[buffKey] = self:GetChecked() and true or false
            if BuffPower and BuffPower.UpdateUI then BuffPower:UpdateUI() end
        end)
    end

    -- Add checkboxes for optional buffs
    local optionYOffset = yOffset
    if BuffPower.BuffTypes then
        for key, info in pairs(BuffPower.BuffTypes) do
            if info.is_optional or key == "SPIRIT" then
                createBuffEnableCheckbox(key, info.name, panel, optionYOffset)
                optionYOffset = optionYOffset - 25
            end
        end
    end
    yOffset = optionYOffset - 10

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

    -- === Enhancement: Group Button Layout Sliders ===
    yOffset = yOffset - 10
    local display = BuffPowerDB and BuffPowerDB.display or BuffPower.defaults.profile.display

    -- Button Width Slider
    local buttonWidthLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    buttonWidthLabel:SetPoint("TOPLEFT", 30, yOffset)
    local currButtonWidth = (display and display.buttonWidth) or 120
    buttonWidthLabel:SetText("Group Button Width: " .. currButtonWidth)
    yOffset = yOffset - 25
    local buttonWidthSlider = CreateFrame("Slider", "BuffPowerButtonWidthSlider", panel, "OptionsSliderTemplate")
    buttonWidthSlider:SetPoint("TOPLEFT", 30, yOffset)
    buttonWidthSlider:SetWidth(160)
    buttonWidthSlider:SetMinMaxValues(60, 280)
    buttonWidthSlider:SetValueStep(2)
    buttonWidthSlider:SetValue(currButtonWidth)
    _G[buttonWidthSlider:GetName() .. "Low"]:SetText("60")
    _G[buttonWidthSlider:GetName() .. "High"]:SetText("280")
    _G[buttonWidthSlider:GetName() .. "Text"]:SetText("Button Width")
    buttonWidthSlider:SetScript("OnValueChanged", function(self, value)
        if not BuffPowerDB.display then BuffPowerDB.display = {} end
        BuffPowerDB.display.buttonWidth = value
        buttonWidthLabel:SetText("Group Button Width: " .. value)
        if BuffPower and BuffPower.UpdateUI then BuffPower:UpdateUI() end
    end)
    yOffset = yOffset - 40

    -- Button Height Slider
    local buttonHeightLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    buttonHeightLabel:SetPoint("TOPLEFT", 30, yOffset)
    local currButtonHeight = (display and display.buttonHeight) or 28
    buttonHeightLabel:SetText("Group Button Height: " .. currButtonHeight)
    yOffset = yOffset - 25
    local buttonHeightSlider = CreateFrame("Slider", "BuffPowerButtonHeightSlider", panel, "OptionsSliderTemplate")
    buttonHeightSlider:SetPoint("TOPLEFT", 30, yOffset)
    buttonHeightSlider:SetWidth(160)
    buttonHeightSlider:SetMinMaxValues(16, 60)
    buttonHeightSlider:SetValueStep(1)
    buttonHeightSlider:SetValue(currButtonHeight)
    _G[buttonHeightSlider:GetName() .. "Low"]:SetText("16")
    _G[buttonHeightSlider:GetName() .. "High"]:SetText("60")
    _G[buttonHeightSlider:GetName() .. "Text"]:SetText("Button Height")
    buttonHeightSlider:SetScript("OnValueChanged", function(self, value)
        if not BuffPowerDB.display then BuffPowerDB.display = {} end
        BuffPowerDB.display.buttonHeight = value
        buttonHeightLabel:SetText("Group Button Height: " .. value)
        if BuffPower and BuffPower.UpdateUI then BuffPower:UpdateUI() end
    end)
    yOffset = yOffset - 40

    -- Button Spacing Slider
    local buttonSpacingLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    buttonSpacingLabel:SetPoint("TOPLEFT", 30, yOffset)
    local currSpacing = (display and display.buttonSpacing) or 2
    buttonSpacingLabel:SetText("Group Button Spacing: " .. currSpacing)
    yOffset = yOffset - 25
    local buttonSpacingSlider = CreateFrame("Slider", "BuffPowerButtonSpacingSlider", panel, "OptionsSliderTemplate")
    buttonSpacingSlider:SetPoint("TOPLEFT", 30, yOffset)
    buttonSpacingSlider:SetWidth(160)
    buttonSpacingSlider:SetMinMaxValues(0, 20)
    buttonSpacingSlider:SetValueStep(1)
    buttonSpacingSlider:SetValue(currSpacing)
    _G[buttonSpacingSlider:GetName() .. "Low"]:SetText("0")
    _G[buttonSpacingSlider:GetName() .. "High"]:SetText("20")
    _G[buttonSpacingSlider:GetName() .. "Text"]:SetText("Button Spacing")
    buttonSpacingSlider:SetScript("OnValueChanged", function(self, value)
        if not BuffPowerDB.display then BuffPowerDB.display = {} end
        BuffPowerDB.display.buttonSpacing = value
        buttonSpacingLabel:SetText("Group Button Spacing: " .. value)
        if BuffPower and BuffPower.UpdateUI then BuffPower:UpdateUI() end
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
    -- Blizzard options registration disabled: handled by standalone window (BuffPowerOptionsWindow.lua)
end

--[[
Removed the optionsPanelInitializer Frame and its PLAYER_LOGIN event.
The BuffPower:CreateOptionsPanel() function will now be called from BuffPower.lua
after BuffPowerDB is initialized.
Added some nil checks and fallbacks for L[] strings just in case, though
.toc order should handle L.
Added nil checks for BuffPowerDB before accessing its fields during initial setup of checkboxes/sliders.
]]
