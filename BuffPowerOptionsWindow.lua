-- BuffPowerStandaloneOptions.lua
-- A minimal, always-available standalone config window for WoW Classic Era and all clients

local function BuffPower_ShowStandaloneOptions()
    if BuffPowerStandaloneOptionsFrame and BuffPowerStandaloneOptionsFrame:IsShown() then
        BuffPowerStandaloneOptionsFrame:Hide()
        return
    end

    if not BuffPowerStandaloneOptionsFrame then
        local f = CreateFrame("Frame", "BuffPowerStandaloneOptionsFrame", UIParent, "BackdropTemplate")
        f:SetSize(600, 410)
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
        title:SetText("BuffPower Assignment Grid")

        -- Close Button
        local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)
        close:SetScript("OnClick", function()
            f:Hide()
        end)

        -- Make ScrollFrame for grid
        local scrollFrame = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
        scrollFrame:SetPoint("TOPLEFT", f, 20, -45)
        scrollFrame:SetPoint("BOTTOMRIGHT", f, -30, 48)
        local content = CreateFrame("Frame", nil, scrollFrame)
        content:SetSize(530, 1000)
        scrollFrame:SetScrollChild(content)

        -- PallyPower grid class order and icon paths
        local gridClasses = {
            "WARRIOR", "ROGUE", "PRIEST", "DRUID", "PALADIN", "HUNTER", "MAGE", "WARLOCK", "PET"
        }
        local CLASS_ICON_ATLAS = "Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES"
        local CLASS_ICON_TCOORDS = {
            WARRIOR = {0, 0.25, 0, 0.25},
            MAGE = {0.25, 0.5, 0, 0.25},
            ROGUE = {0.5, 0.75, 0, 0.25},
            DRUID = {0.75, 1, 0, 0.25},
            HUNTER = {0, 0.25, 0.25, 0.5},
            SHAMAN = {0.25, 0.5, 0.25, 0.5},
            PRIEST = {0.5, 0.75, 0.25, 0.5},
            WARLOCK = {0.75, 1, 0.25, 0.5},
            PALADIN = {0, 0.25, 0.5, 0.75},
            PET = nil, -- no CLASS_ICON mapping, use icon as texture
        }
        local gridClassIcons = {
            PET = "Interface\\ICONS\\Ability_Hunter_BeastCall", -- separate icon for pet
        }
        local gridClassNames = {
            WARRIOR = "Warrior", ROGUE = "Rogue", PRIEST = "Priest", DRUID = "Druid", PALADIN = "Paladin",
            HUNTER = "Hunter", MAGE = "Mage", WARLOCK = "Warlock", PET = "Pet"
        }

        local buffTypes = BuffPower.BuffTypes or {}

        -- Get the player's class
        local _, playerClass = UnitClass("player")

        -- Top grid: show class icons & names as headers above columns
        for j, class in ipairs(gridClasses) do
            local icon = content:CreateTexture(nil, "ARTWORK")
            icon:SetSize(32, 32)
            icon:SetPoint("TOPLEFT", 80 + (j-1)*60, 0)
            if class ~= "PET" and CLASS_ICON_TCOORDS[class] then
                icon:SetTexture(CLASS_ICON_ATLAS)
                icon:SetTexCoord(unpack(CLASS_ICON_TCOORDS[class]))
            else
                -- Pet or fallback
                local petPath = gridClassIcons.PET or "Interface\\Icons\\Ability_Hunter_BeastCall"
                icon:SetTexture(petPath)
                icon:SetTexCoord(0, 1, 0, 1)
            end

            -- Class label below icon
            local lbl = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            lbl:SetPoint("TOPLEFT", 80 + (j-1)*60, 32)
            lbl:SetText(gridClassNames[class] or class)
        end

        -- Group icon header
        local groupLbl = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        groupLbl:SetPoint("TOPLEFT", 80 + (#gridClasses)*60, 22)
        groupLbl:SetText("Group")

        -- Only show buffs you can cast
        local gridBuffs = {}
        if playerClass == "PRIEST" then
            -- Fixed order for priest: FORTITUDE, SPIRIT, SHADOW
            local priestOrder = {"FORTITUDE", "SPIRIT", "SHADOW"}
            for _, key in ipairs(priestOrder) do
                local info = buffTypes[key]
                if info and info.buffer_class == "PRIEST" then
                    table.insert(gridBuffs, {key=key, info=info})
                end
            end
            -- Add any other priest buffs, preserving future extensibility
            for buffKey, buffInfo in pairs(buffTypes) do
                if buffInfo.buffer_class == "PRIEST" and not (buffKey == "FORTITUDE" or buffKey == "SPIRIT" or buffKey == "SHADOW") then
                    table.insert(gridBuffs, {key=buffKey, info=buffInfo})
                end
            end
        else
            for buffKey, buffInfo in pairs(buffTypes) do
                if buffInfo.buffer_class == playerClass then
                    table.insert(gridBuffs, {key=buffKey, info=buffInfo})
                end
            end
        end

        -- Grid rows: only buffs current player can cast
        local row = 0
        for _, buffRow in ipairs(gridBuffs) do
            local buffKey, buffInfo = buffRow.key, buffRow.info
            local y = -54 - (row*50)
            -- Buff icon (left)
            local icon = content:CreateTexture(nil, "ARTWORK")
            icon:SetSize(32, 32)
            icon:SetPoint("TOPLEFT", 15, y)
            icon:SetTexture(buffInfo.icon or "")
            local lbl = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            lbl:SetPoint("LEFT", icon, "RIGHT", 8, 2)
            lbl:SetText(buffInfo.name or buffKey)

            -- Per-class assignment cells
            for j, class in ipairs(gridClasses) do
                local eligible = false
                for _, c in ipairs(buffInfo.eligible_target_classes or {}) do
                    if c == class then eligible = true break end
                end
                local btn = CreateFrame("Button", nil, content)
                btn:SetSize(32,32)
                btn:SetPoint("TOPLEFT", 80 + (j-1)*60, y + 2)
                btn.buffKey = buffKey
                btn.class = class

                if eligible then
                    local state = BuffPowerDB and BuffPowerDB.buffAssignment and BuffPowerDB.buffAssignment[class] and BuffPowerDB.buffAssignment[class][buffKey]
                    btn.icon = btn:CreateTexture(nil, "OVERLAY")
                    btn.icon:SetAllPoints()
                    btn.icon:SetTexture(buffInfo.icon)
                    if state then
                        btn.icon:SetVertexColor(1, 1, 1, 1) -- selected: normal icon colors
                    else
                        btn.icon:SetVertexColor(1, 0.2, 0.2, 1) -- unselected: reddish
                    end
                    btn:SetScript("OnClick", function(self)
                        if not BuffPowerDB.buffAssignment then BuffPowerDB.buffAssignment = {} end
                        if not BuffPowerDB.buffAssignment[self.class] then BuffPowerDB.buffAssignment[self.class] = {} end
                        local val = not BuffPowerDB.buffAssignment[self.class][self.buffKey]
                        BuffPowerDB.buffAssignment[self.class][self.buffKey] = val
                        if val then
                            self.icon:SetVertexColor(1, 1, 1, 1)
                        else
                            self.icon:SetVertexColor(1, 0.2, 0.2, 1)
                        end
                        if BuffPower and BuffPower.UpdateUI then BuffPower:UpdateUI() end
                    end)
                    btn:SetScript("OnEnter", function(self)
                        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                        GameTooltip:SetText((buffInfo.name or buffKey).." ("..(gridClassNames[class] or class)..")")
                        GameTooltip:AddLine("Click to "..((BuffPowerDB.buffAssignment and BuffPowerDB.buffAssignment[class] and BuffPowerDB.buffAssignment[class][buffKey]) and "disable" or "enable").." assignment.", 1, 1, 1)
                        GameTooltip:Show()
                    end)
                    btn:SetScript("OnLeave", function(self) GameTooltip:Hide() end)
                else
                    btn.icon = btn:CreateTexture(nil, "OVERLAY")
                    btn.icon:SetAllPoints()
                    btn.icon:SetTexture(buffInfo.icon)
                    btn.icon:SetVertexColor(0.2,0.2,0.2,0.6)
                    btn:Disable()
                end
            end

            -- Group buff icon (right of row)
            if buffInfo.group_spell_name and buffInfo.group_spell_id then
                local groupBtn = CreateFrame("Button", nil, content)
                groupBtn:SetSize(32,32)
                groupBtn:SetPoint("TOPLEFT", 80 + (#gridClasses)*60, y + 2)
                local icon = groupBtn:CreateTexture(nil, "OVERLAY")
                icon:SetAllPoints()
                icon:SetTexture(buffInfo.group_icon or buffInfo.icon)
                groupBtn:SetScript("OnClick", function(self)
                    local _, plClass = UnitClass("player")
                    if plClass == buffInfo.buffer_class then
                        CastSpellByName(buffInfo.group_spell_name)
                    else
                        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                        GameTooltip:ClearLines()
                        GameTooltip:AddLine(buffInfo.group_spell_name)
                        GameTooltip:AddLine("Only "..(gridClassNames[buffInfo.buffer_class] or buffInfo.buffer_class).." can cast this group buff.",1,1,1)
                        GameTooltip:Show()
                    end
                end)
                groupBtn:SetScript("OnEnter", function(self)
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:SetText(buffInfo.group_spell_name or "Group Buff")
                    GameTooltip:AddLine("Click to cast if your class can.", 1, 1, 1)
                    GameTooltip:Show()
                end)
                groupBtn:SetScript("OnLeave", function(self) GameTooltip:Hide() end)
            end

            row = row + 1
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