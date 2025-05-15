-- BuffPower.lua
-- Core logic for BuffPower addon

local addonName = "BuffPower"
-- For accurate raid-wide buff tracking (like PallyPower), use LibClassicDurations if available
local LCD = LibStub("LibClassicDurations", true)
local UnitAura = LCD and LCD.UnitAuraWrapper or _G.UnitAura
if LCD then _G.UnitAura = LCD.UnitAuraWrapper end
if LCD then LCD:Register(addonName) end

-- Attempt to get AceAddon-3.0
local AceAddon = LibStub("AceAddon-3.0")
if not AceAddon then
    print("|cffeda55fBuffPower:|r AceAddon-3.0 not found! Please ensure Ace3 library is installed.")
    return
end

-- Create the addon object using AceAddon-3.0
local BuffPower = AceAddon:NewAddon(addonName, "AceConsole-3.0", "AceEvent-3.0")
-- Merge BuffPowerValues static fields into the AceAddon object and preserve the global (fixes static table overwrite bug)
if _G.BuffPower then
    for k, v in pairs(_G.BuffPower) do BuffPower[k] = v end
end
_G.BuffPower = BuffPower
BuffPower.debug = false  -- Set true for verbose debug messages in development.

-- Get Locale table *after* NewAddon, similar to PallyPower
local L = LibStub("AceLocale-3.0"):GetLocale(addonName) 

-- Constants
local MAX_RAID_MEMBERS = 40
-- Returns true if bufferClass should buff memberClass using their main buff
-- Returns true if bufferClass should buff memberClass with buffKey (dynamic, considers options/talent/eligible)
function BuffPower:NeedsBuffFrom(bufferClass, memberClass, buffKey)
    bufferClass = bufferClass and bufferClass:upper()
    memberClass = memberClass and memberClass:upper()
    -- Legacy fallback: if no buffKey provided, keep original logic
    if not buffKey or not BuffPower.BuffTypes or not BuffPower.BuffTypes[buffKey] then
        if bufferClass == "MAGE" then
            return memberClass ~= "WARRIOR" and memberClass ~= "ROGUE"
        elseif bufferClass == "PRIEST" or bufferClass == "DRUID" then
            return true
        end
        return false
    end

    local buff = BuffPower.BuffTypes[buffKey]
    -- Only buffers of correct class may provide this buff
    if buff.buffer_class ~= bufferClass then
        return false
    end

    -- User options: If optional, only buff if enabled
    if buff.is_optional then
        if not BuffPowerDB or not BuffPowerDB.buffEnableOptions or BuffPowerDB.buffEnableOptions[buffKey] == false then
            return false
        end
    end

    -- Class eligibility
    local eligible = false
    for _, c in ipairs(buff.eligible_target_classes) do
        if c == memberClass then
            eligible = true
            break
        end
    end
    if not eligible then
        return false
    end

    -- If requires_talent (Spirit), check the buffer has the talent
    if buff.requires_talent and bufferClass == "PRIEST" then
        if not BuffPower:PlayerHasDivineSpiritTalent() then
            return false
        end
    end

    return true
end

-- Returns true if the player (priest) has Divine Spirit talent
function BuffPower:PlayerHasDivineSpiritTalent()
    -- Classic Talent: Discipline tree, "Divine Spirit"
    -- For Classic: Talent points: 2nd row, 4th talent in Discipline (tab=1)
    -- Try name-based fallback:
    local _, class = UnitClass("player")
    if class ~= "PRIEST" then return false end
    for tIdx = 1, GetNumTalentTabs() do
        local numTalents = GetNumTalents(tIdx)
        for i = 1, numTalents do
            local name, _, _, _, rank = GetTalentInfo(tIdx, i)
            if name == "Divine Spirit" and rank and rank > 0 then
                return true
            end
        end
    end
    return false
end
local MAX_PARTY_MEMBERS = 5
local MAX_RAID_GROUPS = 8

-- Helper to check for presence of a buff by name or spellId on a unit
local function HasBuff(unit, spellNameOrId)
    if not unit or not spellNameOrId then return false end
    local i = 1
    while true do
        local name, _, _, _, _, _, _, _, _, spellId = UnitAura(unit, i, "HELPFUL")
        if not name then break end
        if spellNameOrId == name or spellNameOrId == spellId then
            return true
        end
        i = i + 1
    end
    return false
end

-- Returns true if the unit has either the single or group buff for given class
function BuffPower:GetUnitBuffState(unitId, class)
    if not BuffPower.ClassBuffInfo or not class then return false end
    local buffInfo = BuffPower.ClassBuffInfo[class]
    if not buffInfo then return false end
    if HasBuff(unitId, buffInfo.single_spell_name) or HasBuff(unitId, buffInfo.group_spell_name) then
        return true
    end
    return false
end

-- LibUIDropDownMenu compatibility
local L_UIDropDown = LibStub and LibStub("LibUIDropDownMenu-4.0", true)

-- UI Frames
local BuffPowerOrbFrame -- The central draggable orb
local BuffPowerGroupButtons = {} -- Array to hold the group button frames
-- Main group member popout frame (created on demand)
local BuffPowerGroupMemberFrame -- Will be managed in CreateUI and group button handlers

-- Helper: Ensures frame exists, resets properties
-- Helper: Hides all member buttons for group popout (removes container frame entirely)
local function HideGroupMemberButtons()
    if BuffPower.MemberPopoutTicker then
        BuffPower.MemberPopoutTicker:Cancel()
        BuffPower.MemberPopoutTicker = nil
    end
    BuffPower.MemberPopoutGroupId = nil
    for i = 1, 40 do
        local btn = _G["BuffPowerGroupMemberButton" .. i]
        if btn then
            btn:Hide()
            btn:SetParent(UIParent)
        end
    end
end

-- Helper: Update all per-button visual/logic; called by Populator and by ticker
-- UpdateMemberButtonAppearance: Now supports multiple buffs per member via SecureActionButton icons (safe click-to-buff)
local function UpdateMemberButtonAppearance(btn, member, buffInfo, bufferClass)
    -- UI layout constants for icons
    local ICON_SIZE = 18
    local ICON_PADDING = 2
    local MAX_BUFFS = 4

    local colorConfig = (BuffPower.db and BuffPower.db.colors) or (BuffPower.defaults and BuffPower.defaults.profile.colors) or {}
    local groupBuffed = colorConfig.groupBuffed or {0.2, 0.8, 0.2, 0.7}
    local groupBuffedA = groupBuffed[4] or 0.7

    local classColorHex = (BuffPower.ClassColors and BuffPower.ClassColors[member.class] and BuffPower.ClassColors[member.class].hex) or "|cffffffff"

    -- Find all buffs this bufferClass could cast for this member
    local buffsToCheck = {}
    for buffKey, buff in pairs(BuffPower.BuffTypes or {}) do
        if BuffPower:NeedsBuffFrom(bufferClass, member.class, buffKey) then
            table.insert(buffsToCheck, { key = buffKey, info = buff })
        end
    end

    -- Visual border (rounded) for each button
    if not btn.border then
        btn.border = CreateFrame("Frame", nil, btn)
        btn.border:SetFrameLevel(btn:GetFrameLevel() - 1)
        btn.border:SetPoint("TOPLEFT", btn, "TOPLEFT", -1, 1)
        btn.border:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 1, -1)
        if BackdropTemplateMixin then
            Mixin(btn.border, BackdropTemplateMixin)
        end
        btn.border:SetBackdrop({
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 8,
            insets = {left = 0, right = 0, top = 0, bottom = 0},
        })
        btn.border:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.9)
    end

    -- Clear old multi-buff icons/buttons and tooltips
    btn.buffIcons = btn.buffIcons or {}
    for i, icon in ipairs(btn.buffIcons) do
        if icon then icon:Hide() end
    end

    -- Add new SecureActionButton icons for each buff (for secure click-to-buff)
    local iconsDisplayed = 0
    local tooltipLines = {}

    for i, buffData in ipairs(buffsToCheck) do
        local buffKey = buffData.key
        local buff = buffData.info
        local iconBtn = btn.buffIcons[i]
        if not iconBtn then
            iconBtn = CreateFrame("Button", (btn:GetName() or "").."BuffBtn"..i, btn, "SecureActionButtonTemplate")
            btn.buffIcons[i] = iconBtn
            iconBtn:SetFrameLevel(btn:GetFrameLevel() + 1)
            iconBtn:SetSize(ICON_SIZE, ICON_SIZE)
            iconBtn.texture = iconBtn:CreateTexture(nil, "ARTWORK")
            iconBtn.texture:SetAllPoints()
            iconBtn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
        end
        iconBtn:SetPoint("LEFT", btn, "LEFT", ICON_PADDING + (i-1)*(ICON_SIZE+ICON_PADDING), 0)
        iconBtn:Show()

        -- Default/fallback for icon
        iconBtn.texture:SetTexture(buff.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
        iconBtn.texture:SetVertexColor(1,1,1,1)

        -- Setup secure attributes
        iconBtn:SetAttribute("type", "spell")
        iconBtn:SetAttribute("spell", buff.single_spell_name)
        local target = member.unitid or member.name
        iconBtn:SetAttribute("unit", target)

        -- Check if member is missing this buff
        local hasBuff = false
        local timerText = ""
        local critical = false
        if member.unitid then
            local idx = 1
            while true do
                local name, iconTex, _, _, _, _, expirationTime, _, _, spellId = UnitAura(member.unitid, idx, "HELPFUL")
                if not name then break end
                local valid = (spellId == buff.single_spell_id or spellId == buff.group_spell_id)
                  or (name == buff.single_spell_name or name == buff.group_spell_name)
                if valid then
                    hasBuff = true
                    if iconTex then
                        iconBtn.texture:SetTexture(iconTex)
                    else
                        iconBtn.texture:SetTexture(buff.icon)
                    end
                    if type(expirationTime) == "number" and expirationTime > 0 then
                        local remain = expirationTime - GetTime()
                        if remain > 0 then
                            local m = math.floor(remain / 60)
                            local s = math.fmod(remain, 60)
                            timerText = string.format("%d:%02d", m, s)
                            if remain < 30 then critical = true end
                        end
                    end
                    break
                end
                idx = idx + 1
            end
        end
        if not hasBuff then
            iconBtn.texture:SetTexture(buff.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
            iconBtn.texture:SetVertexColor(1, 0.2, 0.2, 1) -- Red
            table.insert(tooltipLines, "|cffFF4040"..buff.name.."|r: |cffff3333Missing|r")
        else
            iconBtn.texture:SetVertexColor(0.7,1,0.7, 0.9)
            table.insert(tooltipLines, "|cffA0FFA0"..buff.name.."|r: |cff33ff33Buffed|r "..(timerText or ""))
        end

        -- Tooltip for each buff icon
        iconBtn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(buff.name)
            if hasBuff then
                GameTooltip:AddLine("|cff33ff33Buffed|r "..(timerText or ""), 1,1,1)
            else
                GameTooltip:AddLine("|cffff3333Missing|r", 1,0.6,0.6)
            end
            GameTooltip:Show()
        end)
        iconBtn:SetScript("OnLeave", function(self)
            GameTooltip:Hide()
        end)

        iconsDisplayed = iconsDisplayed + 1
        if iconsDisplayed >= MAX_BUFFS then break end
    end

    -- Show main member label right of final icon
    if not btn.label then
        btn.label = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    end
    local nameLabelOffset = ICON_PADDING + iconsDisplayed * (ICON_SIZE + ICON_PADDING)
    btn.label:SetPoint("LEFT", btn, "LEFT", nameLabelOffset, 0)
    btn.label:SetText(classColorHex..member.name.."|r")
    btn.label:SetTextColor(1,1,1)

    -- Hide unused icons/buttons
    for i = iconsDisplayed+1, #btn.buffIcons do
        btn.buffIcons[i]:Hide()
    end

    -- Timer and background based on worst buff (missing = red, all buffed = green)
    local missingCount = 0
    for i, buffData in ipairs(buffsToCheck) do
        local buff = buffData.info
        local hasBuff = false
        if member.unitid then
            local idx = 1
            while true do
                local name, _, _, _, _, _, _, _, _, spellId = UnitAura(member.unitid, idx, "HELPFUL")
                if not name then break end
                local valid = (spellId == buff.single_spell_id or spellId == buff.group_spell_id)
                  or (name == buff.single_spell_name or name == buff.group_spell_name)
                if valid then
                    hasBuff = true
                    break
                end
                idx = idx + 1
            end
        end
        if not hasBuff then missingCount = missingCount + 1 end
    end

    -- If no relevant buffs, fade
    if #buffsToCheck == 0 then
        if not btn.bg then
            btn.bg = btn:CreateTexture(nil, "BACKGROUND")
            btn.bg:SetAllPoints()
        end
        btn.bg:SetColorTexture(0.5,0.5,0.5, 0.5)
        btn.label:SetTextColor(0.5,0.5,0.5)
    else
        if not btn.bg then
            btn.bg = btn:CreateTexture(nil, "BACKGROUND")
            btn.bg:SetAllPoints()
        end
        if missingCount == 0 then
            btn.bg:SetColorTexture(0.2, 0.8, 0.2, groupBuffedA)
            btn.label:SetTextColor(0.1,1,0.1)
        else
            btn.bg:SetColorTexture(1, 0.2, 0.2, 0.5)
            btn.label:SetTextColor(1,0.2,0.2)
        end
    end

    -- Tooltip for the whole line (merged)
    btn.tooltip = table.concat(tooltipLines, "\n")
    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(member.name)
        GameTooltip:AddLine(self.tooltip, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)
    -- Disable generic click on this main button
    btn:SetAttribute("type", nil)
    btn:SetAttribute("spell", nil)
    btn:SetAttribute("unit", nil)
end

-- Helper: Populates/reset all member buttons
local function PopulateGroupMemberButtons(anchorButton, members, buffInfo, playerClass)
    -- Show member buttons aligned vertically right of anchorButton (no container)
    local displayConfig = (BuffPower.db and BuffPower.db.profile and BuffPower.db.profile.display) or (BuffPower.defaults and BuffPower.defaults.profile and BuffPower.defaults.profile.display) or {}
    local buttonWidth = (displayConfig.buttonWidth ~= nil) and displayConfig.buttonWidth or 120
    local buttonHeight = (displayConfig.buttonHeight ~= nil) and displayConfig.buttonHeight or 28
    local verticalSpacing = (displayConfig.verticalSpacing ~= nil) and displayConfig.verticalSpacing or 1

    -- Hide any old buttons from previous popouts
    for i = #members + 1, 40 do
        local btn = _G["BuffPowerGroupMemberButton" .. i]
        if btn then btn:Hide() end
    end

    -- Layout member buttons in a vertical stack, anchored to anchorButton (the group button)
    for idx, member in ipairs(members) do
        local btn = _G["BuffPowerGroupMemberButton" .. idx] or CreateFrame("Button", "BuffPowerGroupMemberButton"..idx, UIParent, "SecureActionButtonTemplate")
        btn:SetSize(buttonWidth, buttonHeight)
        btn:ClearAllPoints()
        if idx == 1 then
            btn:SetPoint("LEFT", anchorButton, "RIGHT", 8, 0)
        else
            local prevBtn = _G["BuffPowerGroupMemberButton" .. (idx-1)]
            btn:SetPoint("TOPLEFT", prevBtn, "BOTTOMLEFT", 0, -verticalSpacing)
        end
        UpdateMemberButtonAppearance(btn, member, buffInfo, playerClass)
        btn:Show()
        btn:RegisterForClicks("AnyUp")
        -- Feedback animation group (as before)
        if not btn.anim then
            btn.anim = btn:CreateAnimationGroup()
            btn.anim.fade = btn.anim:CreateAnimation("Alpha")
            btn.anim.fade:SetFromAlpha(1)
            btn.anim.fade:SetToAlpha(0.5)
            btn.anim.fade:SetDuration(0.08)
            btn.anim.fade:SetOrder(1)
            btn.anim.fade2 = btn.anim:CreateAnimation("Alpha")
            btn.anim.fade2:SetFromAlpha(0.5)
            btn.anim.fade2:SetToAlpha(1)
            btn.anim.fade2:SetDuration(0.16)
            btn.anim.fade2:SetOrder(2)
        end
        btn:SetScript("PostClick", function(selfB)
            if selfB.anim then selfB.anim:Play() end
            C_Timer.After(0.6, function()
                if BuffPower and BuffPower.UpdateRoster then
                    BuffPower:UpdateRoster()
                end
            end)
        end)
    end
end

-- Main: Show and fill the group member frame
local function BuffPower_ShowGroupMemberFrame(anchorButton, groupId)
    -- Remove all previous member buttons (popouts)
    HideGroupMemberButtons()
    local members = BuffPower:GetGroupMembers(groupId)

    -- Determine which class to use for group logic
    local assignment = (BuffPowerDB and BuffPowerDB.assignments) and BuffPowerDB.assignments[groupId]
    local groupBuffClass
    if assignment and assignment.playerClass then
        groupBuffClass = assignment.playerClass
    else
        local numGroupMembers = GetNumGroupMembers() or 0
        local _, playerClass = UnitClass("player")
        if playerClass == "MAGE" or playerClass == "PRIEST" or playerClass == "DRUID" then
            groupBuffClass = playerClass
        elseif numGroupMembers == 0 or (not IsInRaid() and groupId == 1) then
            groupBuffClass = playerClass
        elseif IsInRaid() then
            for _, member in ipairs(members) do
                if member.class == "MAGE" or member.class == "PRIEST" or member.class == "DRUID" then
                    groupBuffClass = member.class
                    break
                end
            end
        end
    end
    local buffInfo = groupBuffClass and BuffPower.ClassBuffInfo and BuffPower.ClassBuffInfo[groupBuffClass] or nil
    PopulateGroupMemberButtons(anchorButton, members, buffInfo, groupBuffClass)

    -- Set group id for live refresh
    BuffPower.MemberPopoutGroupId = groupId
    -- Ticker to update member buttons while popout is open
    BuffPower.MemberPopoutTicker = C_Timer.NewTicker(0.5, function()
        if BuffPower.MemberPopoutGroupId == groupId then
            local members = BuffPower:GetGroupMembers(groupId)
            local groupBuffClass = nil
            local assignment = (BuffPowerDB and BuffPowerDB.assignments) and BuffPowerDB.assignments[groupId]
            if assignment and assignment.playerClass then
                groupBuffClass = assignment.playerClass
            else
                local numGroupMembers = GetNumGroupMembers() or 0
                local _, playerClass = UnitClass("player")
                if playerClass == "MAGE" or playerClass == "PRIEST" or playerClass == "DRUID" then
                    groupBuffClass = playerClass
                elseif numGroupMembers == 0 or (not IsInRaid() and groupId == 1) then
                    groupBuffClass = playerClass
                elseif IsInRaid() then
                    for _, member in ipairs(members) do
                        if member.class == "MAGE" or member.class == "PRIEST" or member.class == "DRUID" then
                            groupBuffClass = member.class
                            break
                        end
                    end
                end
            end
            local buffInfo = groupBuffClass and BuffPower.ClassBuffInfo and BuffPower.ClassBuffInfo[groupBuffClass] or nil
            for idx, member in ipairs(members) do
                local btn = _G["BuffPowerGroupMemberButton" .. idx]
                if btn and btn:IsShown() then
                    UpdateMemberButtonAppearance(btn, member, buffInfo, groupBuffClass)
                end
            end
        end
    end)
end

-- Default Database Structure
-- BuffPowerDB = BuffPowerDB or {} -- This will be handled by AceDB in OnInitialize

-- Flag to ensure options panel is created only once
BuffPower.optionsPanelCreated = false
BuffPower.optionsPanelName = "BuffPower" -- Add this line to set the correct options panel name

-- Helper function for debugging (modified to always print)
local function DebugPrint(...)
    if not BuffPower.debug then return end
    local args = {...}
    local t = {}
    for i = 1, #args do
        t[i] = tostring(args[i])
    end
    print("|cffeda55fBuffPower:|r", table.concat(t, " "))
end

--------------------------------------------------------------------------------
-- III. Core Logic Changes (Sections I and II from plan are mostly data/naming)
--------------------------------------------------------------------------------

-- 1. Player Class Identification
function BuffPower:PlayerCanBuff()
    local _, playerClass = UnitClass("player")
    return playerClass == "MAGE" or playerClass == "PRIEST" or playerClass == "DRUID"
end

function BuffPower:GetPlayerBuffType()
    local _, playerClass = UnitClass("player")
    if BuffPower.MageBuffs and playerClass == "MAGE" then return BuffPower.MageBuffs.name
    elseif BuffPower.PriestBuffs and playerClass == "PRIEST" then return BuffPower.PriestBuffs.name
    elseif BuffPower.DruidBuffs and playerClass == "DRUID" then return BuffPower.DruidBuffs.name
    end
    return nil
end

function BuffPower:GetBuffInfoByClass(className)
    if BuffPower.ClassBuffInfo then
        return BuffPower.ClassBuffInfo[className]
    end
    return nil
end

-- 2. Roster and Group Handling
BuffPower.Roster = {}

function BuffPower:UpdateRoster()
    wipe(BuffPower.Roster)
    local numGroupMembers = GetNumGroupMembers()
    local isInRaid = IsInRaid()

    if numGroupMembers == 0 and not isInRaid then -- Solo
        local name, _ = UnitName("player")
        local _, class = UnitClass("player")
        if name and class then
            table.insert(BuffPower.Roster, { name = name, class = class, group = 1, unitid = "player", isPlayer = true })
        end
    else -- Party or Raid
        local maxMembersToIterate = isInRaid and MAX_RAID_MEMBERS or MAX_PARTY_MEMBERS
        for i = 1, maxMembersToIterate do
            local unitid = isInRaid and ("raid" .. i) or ("party" .. i)
            if not isInRaid and i == 1 and not UnitExists(unitid) and UnitExists("player") then
                if numGroupMembers > 0 then unitid = "player" end
            end

            if UnitExists(unitid) then
                local name, realm = UnitName(unitid)
                if realm and realm ~= "" then name = name .. "-" .. realm end
                local _, class = UnitClass(unitid)
                local groupID
                if isInRaid then
                    if GetRaidSubgroup then
                        groupID = GetRaidSubgroup(unitid)
                    elseif GetRaidRosterInfo then
                        groupID = 1
                        for r=1,MAX_RAID_MEMBERS do
                            local n, _, subgroup = GetRaidRosterInfo(r)
                            if n == name then
                                groupID = subgroup
                                break
                            end
                        end
                    else
                        groupID = 1
                    end
                else
                    groupID = 1
                end
                local isPlayer = UnitIsUnit(unitid, "player")
                if name and class and groupID then
                    table.insert(BuffPower.Roster, { name = name, class = class, group = groupID, unitid = unitid, isPlayer = isPlayer })
                end
            else
                if not isInRaid and i > numGroupMembers and numGroupMembers > 0 then break end
            end
        end
        if (IsInGroup() or IsInRaid()) and not BuffPower:IsPlayerInRoster() then
            local name, _ = UnitName("player")
            local _, class = UnitClass("player")
            local group
            if isInRaid then
                if GetRaidSubgroup then
                    group = GetRaidSubgroup("player")
                elseif GetRaidRosterInfo then
                    group = 1
                    for r=1,MAX_RAID_MEMBERS do
                        local n, _, subgroup = GetRaidRosterInfo(r)
                        if n == name then
                            group = subgroup
                            break
                        end
                    end
                else
                    group = 1
                end
            else
                group = 1
            end
            if name and class then
                table.insert(BuffPower.Roster, { name = name, class = class, group = group, unitid = "player", isPlayer = true })
            end
        end
    end
    DebugPrint("Roster updated. Members:", #BuffPower.Roster)
    BuffPower:UpdateUI()
end

function BuffPower:IsPlayerInRoster()
    local myName = UnitName("player")
    for _, p_info in ipairs(BuffPower.Roster) do
        if p_info.name == myName then return true end
    end
    return false
end

function BuffPower:GetGroupMembers(groupId)
    local members = {}
    for _, p_info in ipairs(BuffPower.Roster) do
        if p_info.group == groupId then table.insert(members, p_info) end
    end
    return members
end

-- Enhancement Plan: Returns true if unitId is missing the specified group buff
function BuffPower:IsUnitMissingBuff(unitId, class, groupBuffSpellId, singleBuffSpellId)
    if not unitId or not class or not groupBuffSpellId then return true end
    local groupName = GetSpellInfo and GetSpellInfo(groupBuffSpellId) or groupBuffSpellId
    local singleName = singleBuffSpellId and (GetSpellInfo(singleBuffSpellId) or singleBuffSpellId) or nil
    local i = 1
    while true do
        local name, _, _, _, _, _, _, _, _, spellId = UnitAura(unitId, i, "HELPFUL")
        if not name then break end
        if (spellId == groupBuffSpellId or name == groupName) or (singleBuffSpellId and (spellId == singleBuffSpellId or name == singleName)) then
            return false -- Has the group or single buff
        end
        i = i + 1
    end
    return true -- Missing both
end

-- Enhancement Plan: Returns true if any valid member of the group is missing the group buff
function BuffPower:IsGroupMissingBuff(groupId)
    local members = self:GetGroupMembers(groupId)
    if #members == 0 then return true end -- treat empty group as "unbuffed"

    -- Determine the buffer class (assignment, fallback logic as in timer function)
    -- (Aim: match group bar coloring to what assignment/group is for)
    local assignment = (BuffPowerDB and BuffPowerDB.assignments) and BuffPowerDB.assignments[groupId]
    local groupBuffClass
    if assignment and assignment.playerClass then
        groupBuffClass = assignment.playerClass
    else
        local numGroupMembers = GetNumGroupMembers() or 0
        local _, playerClass = UnitClass("player")
        if playerClass == "MAGE" or playerClass == "PRIEST" or playerClass == "DRUID" then
            groupBuffClass = playerClass
        elseif numGroupMembers == 0 or (not IsInRaid() and groupId == 1) then
            groupBuffClass = playerClass
        elseif IsInRaid() then
            -- Fallback: raid, use first eligible buffer class in group
            for _, member in ipairs(members) do
                if member.class == "MAGE" or member.class == "PRIEST" or member.class == "DRUID" then
                    groupBuffClass = member.class
                    break
                end
            end
        end
    end

    if not groupBuffClass then return true end

    local classBuffInfos = self.ClassBuffInfo or {}
    local eligibleCount = 0
    for _, member in ipairs(members) do
        -- Only require buff if this class should get it from this buffer
        if self:NeedsBuffFrom(groupBuffClass, member.class) and classBuffInfos[groupBuffClass] then
            eligibleCount = eligibleCount + 1
            if self:IsUnitMissingBuff(
                member.unitid, member.class,
                classBuffInfos[groupBuffClass].group_spell_id, classBuffInfos[groupBuffClass].single_spell_id
            ) then
                return true -- eligible, but missing
            end
        end
    end
    if eligibleCount == 0 then return "grey" end
    return false -- all eligible buffer-targets buffed for group type
end

-- Enhancement Plan: Returns shortest remaining group buff duration for the group (seconds)
function BuffPower:GetShortestGroupBuffDuration(groupId)
    local members = self:GetGroupMembers(groupId)
    -- Prefer assignment, fallback to player class in solo/party if no assignment
    local assignment = (BuffPowerDB and BuffPowerDB.assignments) and BuffPowerDB.assignments[groupId]
    local groupBuffClass
    if assignment and assignment.playerClass then
        groupBuffClass = assignment.playerClass
    else
        local numGroupMembers = GetNumGroupMembers() or 0
        if numGroupMembers == 0 or (not IsInRaid() and groupId == 1) then
            local _, playerClass = UnitClass("player")
            groupBuffClass = playerClass
        elseif IsInRaid() then
            -- Fallback: raid, use first eligible buffer class in group
            for _, member in ipairs(members) do
                if member.class == "MAGE" or member.class == "PRIEST" or member.class == "DRUID" then
                    groupBuffClass = member.class
                    break
                end
            end
        end
    end
    local buffInfo = (groupBuffClass and self.ClassBuffInfo) and self.ClassBuffInfo[groupBuffClass] or nil
    if not buffInfo then return nil end
    local groupSpellId = buffInfo.group_spell_id
    local singleSpellId = buffInfo.single_spell_id
    if not groupSpellId then return nil end

    local minDuration = nil
    for _, member in ipairs(members) do
        local foundBuff = false
        local i = 1
        while true do
            local name, _, _, _, _, _, expirationTime, _, _, auraSpellId = UnitAura(member.unitid, i, "HELPFUL")
            if not name then break end
            if (auraSpellId == groupSpellId or (singleSpellId and auraSpellId == singleSpellId)) then
                if expirationTime and expirationTime > 0 then
                    local remaining = expirationTime - GetTime()
                    if remaining > 0 then
                        if not minDuration or remaining < minDuration then
                            minDuration = remaining
                        end
                        foundBuff = true
                        break -- found a valid buff, don't need to check more
                    end
                end
            end
            i = i + 1
        end
    end
    return minDuration -- may be nil if no group/single buff found
end

function BuffPower:GetEligibleBuffers()
    local buffers = {}
    for _, p_info in ipairs(BuffPower.Roster) do
        if p_info.class and (p_info.class == "MAGE" or p_info.class == "PRIEST" or p_info.class == "DRUID") then
            table.insert(buffers, p_info)
        end
    end
    return buffers
end

-- 3. Buff Assignment Logic
function BuffPower:AssignBufferToGroup(groupId, playerName, playerClass)
    if not BuffPowerDB then BuffPowerDB = {} end
    if not BuffPowerDB.assignments then BuffPowerDB.assignments = {} end
    BuffPowerDB.assignments[groupId] = { playerName = playerName, playerClass = playerClass }
    BuffPower:UpdateUI()
    BuffPower:SendAssignmentUpdate(groupId, playerName, playerClass)
end

function BuffPower:ClearGroupAssignment(groupId)
    if BuffPowerDB and BuffPowerDB.assignments and BuffPowerDB.assignments[groupId] then
        BuffPowerDB.assignments[groupId] = nil
        BuffPower:UpdateUI()
        BuffPower:SendAssignmentUpdate(groupId, "nil", "nil")
    end
end

-- 5. Buff Casting Logic
--[[
    Casts a group or single-target buff. If spell info is missing or not implemented,
    prints a placeholder message to notify the user, suitable for UI prototype/UX demonstration.
    groupId: number (1-8)
    targetName: string or nil (for single-target)
]]
function BuffPower:CastBuff(groupId, targetName)
    local _, playerClass = UnitClass("player")
    local assignment = (BuffPowerDB and BuffPowerDB.assignments) and BuffPowerDB.assignments[groupId]
    local canPlayerBuffThisGroup = false

    if assignment and assignment.playerName == UnitName("player") then
        canPlayerBuffThisGroup = true
    elseif (not assignment or not assignment.playerName) and BuffPower:PlayerCanBuff() then
        canPlayerBuffThisGroup = true
    end

    if not canPlayerBuffThisGroup and not targetName then
        DEFAULT_CHAT_FRAME:AddMessage(L["You are not assigned to buff this group."] or "Not assigned to buff this group.")
        return
    end

    -- DEBUGGING: Record what's going on with class and buff lookup
    print("BuffPower DEBUG: playerClass:", tostring(playerClass), "targetName:", tostring(targetName))
    local _clbt = BuffPower.ClassBuffInfo
    if _clbt then
        for k,v in pairs(_clbt) do print("BuffPower DEBUG: ClassBuffInfo key:", k, "value exists:", v and "yes" or "nil") end
    else
        print("BuffPower DEBUG: ClassBuffInfo is nil!")
    end

    local buffInfo = (BuffPower.ClassBuffInfo and playerClass) and BuffPower.ClassBuffInfo[playerClass]
    print("BuffPower DEBUG: buffInfo exists?", buffInfo and "yes" or "nil")
    if not buffInfo then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff9933BuffPower:|r You are not a supported class for buffing.")
        return
    end

    local isGroup = (not targetName)
    local spellNameToCast = isGroup and buffInfo.group_spell_name or buffInfo.single_spell_name

    -- Check if player knows spell
    local spellKnown = IsSpellKnown and IsSpellKnown(isGroup and buffInfo.group_spell_id or buffInfo.single_spell_id)
    if not spellKnown then
        DEFAULT_CHAT_FRAME:AddMessage(
            string.format("|cffff9933BuffPower:|r You do not know the spell '%s'.", spellNameToCast)
        )
        return
    end

    -- Reagent checks for group buffs
    if isGroup then
        if playerClass == "MAGE" then
            local reagent = "Arcane Powder"
            if GetItemCount(reagent) == 0 then
                DEFAULT_CHAT_FRAME:AddMessage(
                    string.format("|cffff9933BuffPower:|r Missing reagent: %s.", reagent)
                )
                return
            end
        elseif playerClass == "PRIEST" then
            local reagent = "Sacred Candle"
            if GetItemCount(reagent) == 0 then
                DEFAULT_CHAT_FRAME:AddMessage(
                    string.format("|cffff9933BuffPower:|r Missing reagent: %s.", reagent)
                )
                return
            end
        elseif playerClass == "DRUID" then
            local reagent = "Wild Thornroot"
            if GetItemCount(reagent) == 0 then
                DEFAULT_CHAT_FRAME:AddMessage(
                    string.format("|cffff9933BuffPower:|r Missing reagent: %s.", reagent)
                )
                return
            end
        end
    end

    -- Attempt casting
    if isGroup then
        CastSpellByName(buffInfo.group_spell_name)
    else
        if not targetName or targetName == "" then
            DEFAULT_CHAT_FRAME:AddMessage("|cffff9933BuffPower:|r Invalid target for single-target buff.")
            return
        end
        -- Attempt to target the correct unit (may need adjustment for cross-group)
        -- Use the character name, WoW handles it if in group/raid
        CastSpellByName(buffInfo.single_spell_name, targetName)
    end
end

--------------------------------------------------------------------------------
-- IV. Synchronization Logic
--------------------------------------------------------------------------------
local COMM_CHANNEL_RAID = "RAID"
local COMM_CHANNEL_PARTY = "PARTY"

function BuffPower:SendAssignmentUpdate(groupId, playerName, playerClass)
    if not BuffPowerDB or not BuffPowerDB.classSettings or not BuffPowerDB.classSettings[select(2, UnitClass("player"))] or not BuffPowerDB.classSettings[select(2, UnitClass("player"))].enabled then return end
    if type(SendAddonMessage) ~= "function" then return end
    local msg = string.format("ASSIGN_GROUP %d %s %s", groupId, playerName or "nil", playerClass or "nil")
    local channel = IsInRaid() and COMM_CHANNEL_RAID or (IsInGroup() and COMM_CHANNEL_PARTY)
    if channel then SendAddonMessage(BuffPower.commPrefix, msg, channel) end
end

function BuffPower:RequestAssignments()
    if not BuffPowerDB or not BuffPowerDB.classSettings or not BuffPowerDB.classSettings[select(2, UnitClass("player"))] or not BuffPowerDB.classSettings[select(2, UnitClass("player"))].enabled then return end
    if type(SendAddonMessage) ~= "function" then return end
    local channel = IsInRaid() and COMM_CHANNEL_RAID or (IsInGroup() and COMM_CHANNEL_PARTY)
    if channel then SendAddonMessage(BuffPower.commPrefix, "REQ_ASSIGN", channel)
    else DebugPrint("Not in a group, not requesting assignments.") end
end

function BuffPower:OnAddonMessage(prefix, message, channel, sender)
    if prefix ~= BuffPower.commPrefix or sender == UnitName("player") then return end
    local cmd, gIdStr, pName, pClass = message:match("^(ASSIGN_GROUP) (%d+) ([%w%-%_]+) ([%w_]+)$")
    if cmd == "ASSIGN_GROUP" then
        local gId = tonumber(gIdStr)
        if not gId then return end
        pName = (pName == "nil") and nil or pName
        pClass = (pClass == "nil") and nil or pClass
        if not BuffPowerDB then BuffPowerDB = {} end
        if not BuffPowerDB.assignments then BuffPowerDB.assignments = {} end
        BuffPowerDB.assignments[gId] = (pName and pClass) and { playerName = pName, playerClass = pClass } or nil
        BuffPower:UpdateUI()
    elseif message == "REQ_ASSIGN" then
        if BuffPowerDB and BuffPowerDB.assignments and BuffPower:PlayerCanBuff() then
            for groupId, data in pairs(BuffPowerDB.assignments) do
                if data and data.playerName and data.playerClass then
                    local respChannel = IsInRaid() and COMM_CHANNEL_RAID or (IsInGroup() and COMM_CHANNEL_PARTY)
                    if respChannel then
                        SendAddonMessage(BuffPower.commPrefix, string.format("ASSIGN_GROUP %d %s %s", groupId, data.playerName, data.playerClass), respChannel)
                    end
                end
            end
        end
    end
end

--------------------------------------------------------------------------------
-- V. UI Changes (Orb and Circular Layout)
--------------------------------------------------------------------------------

-- Helper function to update the orb's texture based on lock state
function BuffPower:UpdateOrbAppearance()
    if not BuffPowerOrbFrame then return end
    -- No longer an orb texture, let's change border color for lock state
    if BuffPowerDB and BuffPowerDB.locked then
        BuffPowerOrbFrame:SetBackdropBorderColor(0.8, 0.2, 0.2, 1) -- Reddish border when locked
    else
        BuffPowerOrbFrame:SetBackdropBorderColor(0.6, 0.6, 0.6, 0.8) -- Default border
    end
end

function BuffPower:CreateUI()
    DebugPrint("BuffPower:CreateUI called")

    -- Create movable "BuffPower" anchor button
    if not self.AnchorButton then
        -- Create anchor as true "group-style" button, not WoW template
        local displayConfig = (BuffPower.db and BuffPower.db.profile and BuffPower.db.profile.display) or BuffPower.defaults.profile.display
        local buttonWidth = (displayConfig and displayConfig.buttonWidth) or 120
        local buttonHeight = (displayConfig and displayConfig.buttonHeight) or 28
        local fontFace = (displayConfig and displayConfig.fontFace) or "GameFontNormalSmall"
        local fontSize = (displayConfig and displayConfig.fontSize) or 12
        local borderColor = (displayConfig and displayConfig.borderColor) or {0.1, 0.1, 0.1, 1}
        local borderTexture = (displayConfig and displayConfig.borderTexture) or "Interface\\ChatFrame\\ChatFrameBackground"
        local edgeSize = (displayConfig and displayConfig.edgeSize) or 1
        local backgroundColor = (displayConfig and displayConfig.backgroundColor) or {0.1, 0.1, 0.1, 0.7}
        local fontColor = (displayConfig and displayConfig.fontColor) or {1,1,1,1}

        local anchor = CreateFrame("Button", "BuffPowerAnchorButton", UIParent)
        anchor:SetSize(buttonWidth, buttonHeight)
        anchor:SetMovable(true)
        anchor:EnableMouse(true)
        anchor:RegisterForDrag("LeftButton")
        anchor:SetClampedToScreen(true)

        -- --- Custom group button look ---
        -- Background
        anchor.bg = anchor:CreateTexture(nil, "BACKGROUND")
        anchor.bg:SetAllPoints()
        anchor.bg:SetColorTexture(unpack(backgroundColor))

        -- Border
        anchor.border = CreateFrame("Frame", nil, anchor)
        anchor.border:SetFrameLevel(anchor:GetFrameLevel() - 1)
        if BackdropTemplateMixin then
            Mixin(anchor.border, BackdropTemplateMixin)
        end
        anchor.border:SetPoint("TOPLEFT", anchor, "TOPLEFT", -1, 1)
        anchor.border:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", 1, -1)
        local borderBackdropInfo = {
            edgeFile = borderTexture,
            edgeSize = edgeSize,
            insets = {left = 0, right = 0, top = 0, bottom = 0}
        }
        if anchor.border.SetBackdrop then
            anchor.border:SetBackdrop(borderBackdropInfo)
            anchor.border:SetBackdropBorderColor(unpack(borderColor))
        end

        -- Label as central FontString
        anchor.text = anchor:CreateFontString(nil, "ARTWORK", fontFace)
        anchor.text:SetText("BuffPower")
        anchor.text:SetJustifyH("CENTER")
        anchor.text:SetPoint("LEFT", anchor, "LEFT", 10, 0)
        anchor.text:SetPoint("RIGHT", anchor, "RIGHT", -10, 0)
        if fontSize and anchor.text.SetFont then anchor.text:SetFont(GameFontNormal:GetFont(), fontSize) end
        if fontColor then anchor.text:SetTextColor(unpack(fontColor)) end

        -- No icon/timer for anchor

        -- Restore saved position or center
        local pos = (BuffPowerDB and BuffPowerDB.anchorPosition) or { a1 = "CENTER", a2 = "CENTER", x = 0, y = 0 }
        anchor:SetPoint(pos.a1 or "CENTER", UIParent, pos.a2 or "CENTER", pos.x or 0, pos.y or 0)

        anchor:SetScript("OnDragStart", function(self)
            if BuffPowerDB and not BuffPowerDB.locked then
                self:StartMoving()
            end
        end)
        anchor:SetScript("OnDragStop", function(self)
            self:StopMovingOrSizing()
            if BuffPowerDB then
                if not BuffPowerDB.anchorPosition then
                    BuffPowerDB.anchorPosition = { a1 = "CENTER", a2 = "CENTER", x = 0, y = 0 }
                end
                local a1, _, a2, x, y = self:GetPoint()
                BuffPowerDB.anchorPosition.a1 = a1 or "CENTER"
                BuffPowerDB.anchorPosition.a2 = a2 or "CENTER"
                BuffPowerDB.anchorPosition.x = x or 0
                BuffPowerDB.anchorPosition.y = y or 0
            end
        end)
        anchor:SetScript("OnClick", function(self, button)
            if button == "RightButton" then
                if BuffPowerDB and BuffPowerDB.locked then
                    DEFAULT_CHAT_FRAME:AddMessage((L and L["UI is locked. Unlock via options or command."]) or "UI is locked.")
                    return
                end
                -- Open standalone options window, not Blizzard config
                -- Always call global at click time to ensure up-to-date reference
                if _G.BuffPower and _G.BuffPower.ShowStandaloneOptions then
                    _G.BuffPower.ShowStandaloneOptions()
                else
                    DEFAULT_CHAT_FRAME:AddMessage("BuffPower: Standalone options are not available or not fully initialized.")
                end
            end
        end)
        -- Add right-click-to-options directly on the BuffPower text as well
        if anchor.text then
            anchor.text:EnableMouse(true)
            anchor.text:SetScript("OnMouseUp", function(self, button)
                if button == "RightButton" then
                    if BuffPowerDB and BuffPowerDB.locked then
                        DEFAULT_CHAT_FRAME:AddMessage((L and L["UI is locked. Unlock via options or command."]) or "UI is locked.")
                        return
                    end
                    -- Always call global at click time to ensure up-to-date reference
                    if _G.BuffPower and _G.BuffPower.ShowStandaloneOptions then
                        _G.BuffPower.ShowStandaloneOptions()
                    else
                        DEFAULT_CHAT_FRAME:AddMessage("BuffPower: Standalone options are not available or not fully initialized.")
                    end
                end
            end)
        end
    
        self.AnchorButton = anchor
    end

    -- Create group buttons if needed
    for i = 1, MAX_RAID_GROUPS do
        if not BuffPowerGroupButtons[i] then
            local displayConfig = (BuffPower.db and BuffPower.db.profile and BuffPower.db.profile.display) or BuffPower.defaults.profile.display
            local buttonWidth = (displayConfig and displayConfig.buttonWidth) or 120
            local buttonHeight = (displayConfig and displayConfig.buttonHeight) or 28
            local fontFace = (displayConfig and displayConfig.fontFace) or "GameFontNormalSmall"
            local fontSize = (displayConfig and displayConfig.fontSize) or 12
            local timerFontSize = (displayConfig and displayConfig.timerFontSize) or 12
            local borderColor = (displayConfig and displayConfig.borderColor) or {0.1, 0.1, 0.1, 1}
            local borderTexture = (displayConfig and displayConfig.borderTexture) or "Interface\\ChatFrame\\ChatFrameBackground"
            local edgeSize = (displayConfig and displayConfig.edgeSize) or 1
            local backgroundColor = (displayConfig and displayConfig.backgroundColor) or {0.1, 0.1, 0.1, 0.7}
            local fontColor = (displayConfig and displayConfig.fontColor) or {1,1,1,1}
            local groupButton = CreateFrame("Button", "BuffPowerGroupButton" .. i, UIParent, "SecureActionButtonTemplate")
            groupButton:SetSize(buttonWidth, buttonHeight)
            groupButton.groupID = i

            -- Background
            groupButton.bg = groupButton:CreateTexture(nil, "BACKGROUND")
            groupButton.bg:SetAllPoints()
            groupButton.bg:SetColorTexture(unpack(backgroundColor))

            -- Border
            groupButton.border = CreateFrame("Frame", nil, groupButton)
            groupButton.border:SetFrameLevel(groupButton:GetFrameLevel() - 1)
            if BackdropTemplateMixin then
                Mixin(groupButton.border, BackdropTemplateMixin)
            end
            groupButton.border:SetPoint("TOPLEFT", groupButton, "TOPLEFT", -1, 1)
            groupButton.border:SetPoint("BOTTOMRIGHT", groupButton, "BOTTOMRIGHT", 1, -1)
            local borderBackdropInfo = {
                edgeFile = borderTexture,
                edgeSize = edgeSize,
                insets = {left = 0, right = 0, top = 0, bottom = 0}
            }
            if groupButton.border.SetBackdrop then
                groupButton.border:SetBackdrop(borderBackdropInfo)
                groupButton.border:SetBackdropBorderColor(unpack(borderColor))
            end

            -- Class icon
            groupButton.icon = groupButton:CreateTexture(nil, "ARTWORK")
            groupButton.icon:SetSize(buttonHeight-4, buttonHeight-4)
            groupButton.icon:SetPoint("LEFT", 4, 0)
            groupButton.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

            -- Timer text (right)
            groupButton.time = groupButton:CreateFontString(nil, "ARTWORK", fontFace)
            groupButton.time:SetPoint("RIGHT", -4, 0)
            groupButton.time:SetText("")
            if fontSize and groupButton.time.SetFont then groupButton.time:SetFont(GameFontNormal:GetFont(), timerFontSize) end

            -- Group label (center)
            groupButton.text = groupButton:CreateFontString(nil, "ARTWORK", fontFace)
            groupButton.text:SetPoint("LEFT", groupButton.icon, "RIGHT", 4, 0)
            groupButton.text:SetPoint("RIGHT", groupButton.time, "LEFT", -2, 0)
            groupButton.text:SetJustifyH("LEFT")
            if fontSize and groupButton.text.SetFont then groupButton.text:SetFont(GameFontNormal:GetFont(), fontSize) end
            if fontColor then groupButton.text:SetTextColor(unpack(fontColor)) end

            -- SecureActionButton: assign buffs
            local _, playerClass = UnitClass("player")
            local buffInfo = BuffPower.ClassBuffInfo and BuffPower.ClassBuffInfo[playerClass]
            if buffInfo then
                groupButton:SetAttribute("type", "spell")
                groupButton:SetAttribute("spell", buffInfo.group_spell_name)
                groupButton:SetAttribute("unit", "player")
                groupButton:SetAttribute("type2", "spell")
                groupButton:SetAttribute("spell2", buffInfo.group_spell_name)
                groupButton:SetAttribute("unit2", "player")
                groupButton.tooltip = "Left or right click to group buff with " .. buffInfo.group_spell_name
            else
                groupButton.tooltip = "Your class cannot group buff."
            end
            groupButton:SetScript("OnEnter", function(self_button)
                BuffPower_ShowGroupMemberFrame(self_button, self_button.groupID)
            end)
            groupButton:SetScript("OnLeave", function(self_button)
                if BuffPowerGroupMemberFrame then
                    BuffPowerGroupMemberFrame._popoutShowId = (BuffPowerGroupMemberFrame._popoutShowId or 0) + 1
                    local myShowId = BuffPowerGroupMemberFrame._popoutShowId
                    C_Timer.After(0.15, function()
                        if BuffPowerGroupMemberFrame and BuffPowerGroupMemberFrame:IsShown() and BuffPowerGroupMemberFrame._popoutShowId == myShowId then
                            if not self_button:IsMouseOver() and not BuffPowerGroupMemberFrame:IsMouseOver() then
                                BuffPowerGroupMemberFrame:Hide()
                            end
                        end
                    end)
                end
            end)
            groupButton:SetScript("PostClick", function(selfB)
                C_Timer.After(0.6, function()
                    if BuffPower and BuffPower.UpdateRoster then
                        BuffPower:UpdateRoster()
                    end
                end)
            end)
            groupButton:Hide() -- Initially hide
            BuffPowerGroupButtons[i] = groupButton
        end
    end

    BuffPower:PositionGroupButtons()
end

function BuffPower:PositionGroupButtons()
    DebugPrint("BuffPower:PositionGroupButtons called")
    if not self.AnchorButton or not self.AnchorButton:IsVisible() then
        for _, btn in pairs(BuffPowerGroupButtons) do if btn then btn:Hide() end end
        return
    end

    local effectiveGroupsToDisplay = {}
    if IsInRaid() then
        local numSubgroups = 0
        if GetNumSubgroups then
            numSubgroups = GetNumSubgroups()
        elseif GetNumGroupMembers then
            for i=1,MAX_RAID_MEMBERS do
                if UnitInRaid and UnitInRaid("raid"..i) and GetRaidRosterInfo then
                    local _, _, subgroup = GetRaidRosterInfo(i)
                    if subgroup and subgroup > numSubgroups then
                        numSubgroups = subgroup
                    end
                end
            end
        end
        if numSubgroups == 0 and GetNumGroupMembers and GetNumGroupMembers() > 0 then
            numSubgroups = math.ceil(GetNumGroupMembers() / MAX_PARTY_MEMBERS)
        end
        if numSubgroups == 0 and GetNumGroupMembers and GetNumGroupMembers() > 0 then numSubgroups = 1 end

        for i = 1, numSubgroups do
            table.insert(effectiveGroupsToDisplay, i)
        end
        if #effectiveGroupsToDisplay == 0 and GetNumGroupMembers and GetNumGroupMembers() > 0 then
            local numActualGroups = 0
            if GetRaidRosterInfo then
                for i=1,MAX_RAID_MEMBERS do
                    if UnitInRaid and UnitInRaid("raid"..i) then
                        numActualGroups = math.max(numActualGroups, select(5, GetRaidRosterInfo(i)) or 0)
                    end
                end
            end
            if numActualGroups == 0 and GetNumGroupMembers() > 0 then numActualGroups = 1 end

            for i = 1, numActualGroups do
                if not tContains(effectiveGroupsToDisplay, i) then table.insert(effectiveGroupsToDisplay, i) end
            end
            if #effectiveGroupsToDisplay == 0 and GetNumGroupMembers() > 0 then table.insert(effectiveGroupsToDisplay, 1) end
        end
    elseif IsInGroup() then
        table.insert(effectiveGroupsToDisplay, 1)
    elseif BuffPowerDB and BuffPowerDB.showWindowForSolo then
        table.insert(effectiveGroupsToDisplay, 1)
    end

    if #effectiveGroupsToDisplay == 0 then
        for _, button in pairs(BuffPowerGroupButtons) do if button then button:Hide() end end
        return
    end

    -- Layout: anchor at AnchorButton, stack group buttons
    local displayConfig = (BuffPower.db and BuffPower.db.profile and BuffPower.db.profile.display) or BuffPower.defaults.profile.display
    local buttonHeight = (displayConfig and displayConfig.buttonHeight) or 28
    local verticalSpacing = (displayConfig and displayConfig.verticalSpacing) or 2

    for _, button in pairs(BuffPowerGroupButtons) do
        button:Hide()
        button:ClearAllPoints()
    end

    local parent = self.AnchorButton
    for i, groupId in ipairs(effectiveGroupsToDisplay) do
        local button = BuffPowerGroupButtons[groupId]
        if button then
            if i == 1 then
                button:SetPoint("TOP", parent, "BOTTOM", 0, 0)
            else
                button:SetPoint("TOP", parent, "BOTTOM", 0, -verticalSpacing)
            end
            button:Show()
            BuffPower:UpdateGroupButtonContent(button, groupId)
            parent = button
        end
    end

    -- Hide unused group buttons
    for i=1, MAX_RAID_GROUPS do
        if not tContains(effectiveGroupsToDisplay, i) and BuffPowerGroupButtons[i] then
            BuffPowerGroupButtons[i]:Hide()
        end
    end
end

function BuffPower:UpdateGroupButtonContent(button, groupId)
    local assignment = (BuffPowerDB and BuffPowerDB.assignments) and BuffPowerDB.assignments[groupId]
    local membersInGroup = BuffPower:GetGroupMembers(groupId)
    local numGroupMembers = #membersInGroup
    local groupText = string.format("G%d", groupId) -- Shorter format like PallyPower

    -- Set button state
    button:Enable()

    -- Empty group handling
    if numGroupMembers == 0 then
        if not (IsInRaid() or IsInGroup()) and groupId > 1 then button:Disable() end
    end

    -- Enhancement Plan: Group color/status logic
    local missingBuff = self:IsGroupMissingBuff(groupId)
    local color = (self.db and self.db.colors) or BuffPower.defaults.profile.colors
    if missingBuff == "grey" then
        if button.bg then
            button.bg:SetColorTexture(0.5, 0.5, 0.5, 0.5)
        end
    elseif missingBuff then
        if button.bg then
            button.bg:SetColorTexture(unpack((color and color.groupMissingBuff) or {0.8, 0.2, 0.2, 0.7}))
        end
    else
        if button.bg then
            button.bg:SetColorTexture(unpack((color and color.groupBuffed) or {0.2, 0.8, 0.2, 0.7}))
        end
    end

    -- Border styling (use color from config if available, else fallback)
    local displayStyle = (self.db and self.db.display) or BuffPower.defaults.profile.display
    if button.border and button.border.SetBackdropBorderColor then
        if displayStyle and displayStyle.borderColor then
            button.border:SetBackdropBorderColor(unpack(displayStyle.borderColor))
        else
            button.border:SetBackdropBorderColor(0.1, 0.1, 0.1, 1)
        end
    end

    -- Set class icon if we have assignment
    if assignment and assignment.playerName and assignment.playerClass and
       BuffPower.ClassBuffInfo and BuffPower.ClassBuffInfo[assignment.playerClass] and
       BuffPower.ClassColors and BuffPower.ClassColors[assignment.playerClass] then

        local buffInfo = BuffPower.ClassBuffInfo[assignment.playerClass]
        -- Icon
        button.icon:SetTexture(buffInfo.icon or "Interface\\Icons\\INV_Misc_QuestionMark")

        -- Set shortened display name
        local displayName = assignment.playerName
        if displayName and string.len(displayName) > 5 then displayName = string.sub(displayName, 1, 4) .. ".." end
        button.text:SetText(groupText .. ": " .. displayName)

        -- Enhancement Plan: Show actual timer for shortest group buff
        local duration = self:GetShortestGroupBuffDuration(groupId)
        if duration and duration > 0 then
            local m = math.floor(duration / 60)
            local s = math.fmod(duration, 60)
            button.time:SetText(string.format("%d:%02d", m, s))
            if duration < 30 then
                button.time:SetTextColor(1, 0, 0) -- Red for critical
            else
                button.time:SetTextColor(1, 1, 1)
            end
        else
            button.time:SetText("") -- Hide if missing buff
        end
    else
        -- Unassigned group
        button.text:SetText(groupText .. ": " .. (numGroupMembers > 0 and "None" or "Empty"))
        button.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        -- Reset border color
        if button.border and button.border.SetBackdropBorderColor then
            button.border:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.8) -- Gray for unassigned
        end
        button.time:SetText("") -- No timer if no assignment
    end
end

function BuffPower:UpdateUI()
    DebugPrint("BuffPower:UpdateUI called. showWindow:", tostring(BuffPowerDB and BuffPowerDB.showWindow))
    if not BuffPowerDB then return end
    if BuffPowerDB.showWindow then
        if not BuffPowerOrbFrame then self:CreateUI()
        elseif BuffPowerOrbFrame and not BuffPowerOrbFrame:IsVisible() then
             BuffPowerOrbFrame:Show()
             if BuffPowerOrbFrame.backdrop then BuffPowerOrbFrame.backdrop:Show() end
             if BuffPowerOrbFrame.container then BuffPowerOrbFrame.container:Show() end
             BuffPower:UpdateOrbAppearance() -- Ensure orb appearance is correct when shown
        end
        BuffPower:PositionGroupButtons()
    else
        if BuffPowerOrbFrame and BuffPowerOrbFrame:IsVisible() then
            BuffPowerOrbFrame:Hide()
            if BuffPowerOrbFrame.backdrop then BuffPowerOrbFrame.backdrop:Hide() end
            if BuffPowerOrbFrame.container then BuffPowerOrbFrame.container:Hide() end
            for _, btn in ipairs(BuffPowerGroupButtons) do if btn then btn:Hide() end end
        end
    end
    -- New: Immediately refresh member popout if open, to avoid laggy update
    if BuffPower.RefreshMemberPopoutImmediate then
        BuffPower:RefreshMemberPopoutImmediate()
    end
end

-- Refreshes member popout buttons instantly if popout is open
function BuffPower:RefreshMemberPopoutImmediate()
    local groupId = BuffPower.MemberPopoutGroupId
    if not groupId then return end
    local members = BuffPower:GetGroupMembers(groupId)
    local groupBuffClass = nil
    local assignment = (BuffPowerDB and BuffPowerDB.assignments) and BuffPowerDB.assignments[groupId]
    if assignment and assignment.playerClass then
        groupBuffClass = assignment.playerClass
    else
        local numGroupMembers = GetNumGroupMembers() or 0
        local _, playerClass = UnitClass("player")
        if playerClass == "MAGE" or playerClass == "PRIEST" or playerClass == "DRUID" then
            groupBuffClass = playerClass
        elseif numGroupMembers == 0 or (not IsInRaid() and groupId == 1) then
            groupBuffClass = playerClass
        elseif IsInRaid() then
            for _, member in ipairs(members) do
                if member.class == "MAGE" or member.class == "PRIEST" or member.class == "DRUID" then
                    groupBuffClass = member.class
                    break
                end
            end
        end
    end
    local buffInfo = groupBuffClass and BuffPower.ClassBuffInfo and BuffPower.ClassBuffInfo[groupBuffClass] or nil
    for idx, member in ipairs(members) do
        local btn = _G["BuffPowerGroupMemberButton" .. idx]
        if btn and btn:IsShown() then
            UpdateMemberButtonAppearance(btn, member, buffInfo, groupBuffClass)
        end
    end
end

local assignmentMenu = CreateFrame("Frame", "BuffPowerAssignmentMenu", UIParent, "UIDropDownMenuTemplate")
function BuffPower:OpenAssignmentMenu(groupId, anchorFrame)
    local eligibleBuffers = BuffPower:GetEligibleBuffers()
    local menuList = {}
    table.insert(menuList, { text = L["Clear Assignment"] or "Clear Assignment", func = function() BuffPower:ClearGroupAssignment(groupId) end, notCheckable = true })
    table.insert(menuList, { text = "-----", notCheckable=true, disabled=true})
    if #eligibleBuffers == 0 then
        table.insert(menuList, {text = L["No eligible buffers in group/raid."] or "No eligible buffers.", notCheckable = true, disabled = true})
    else
        for _, buffer in ipairs(eligibleBuffers) do
            if buffer.class and BuffPower.ClassColors and BuffPower.ClassColors[buffer.class] and BuffPower.ClassBuffInfo and BuffPower.ClassBuffInfo[buffer.class] then
                local classColor = BuffPower.ClassColors[buffer.class]
                local buffInfo = BuffPower.ClassBuffInfo[buffer.class]
                table.insert(menuList, { text = string.format("%s%s|r (%s)", classColor.hex, buffer.name, buffInfo.name), func = function() BuffPower:AssignBufferToGroup(groupId, buffer.name, buffer.class) end, notCheckable = true })
            end
        end
    end
    -- Add group members for single-target buffing
    -- (Removed 'Buff Single Member' entry and all single buff items. Member buffing is now only via group UI.)
    if L_UIDropDown and L_UIDropDown.EasyMenu then
        L_UIDropDown:EasyMenu(menuList, assignmentMenu, anchorFrame, 0, 0, "MENU")
    else
        DEFAULT_CHAT_FRAME:AddMessage("BuffPower: LibUIDropDownMenu-4.0 not found or not loaded. Assignment menu cannot be displayed.")
    end
end

--------------------------------------------------------------------------------
-- Addon Lifecycle
--------------------------------------------------------------------------------
function BuffPower:OnInitialize()
    -- Use self.name when inside an AceAddon method to get the locale table
    local L = LibStub("AceLocale-3.0"):GetLocale(self.name)
    
    -- AceDB initialization
    self.db = LibStub("AceDB-3.0"):New("BuffPowerDB", BuffPower.defaults, true)
    BuffPowerDB = self.db.profile -- Make DB readily accessible

    -- Force window to show for debugging
    BuffPowerDB.showWindow = true
    DebugPrint("BuffPower:OnInitialize - Forcing showWindow = true")

    if not BuffPowerDB.orbPosition then BuffPowerDB.orbPosition = { a1 = "CENTER", a2 = "CENTER", x = 0, y = 0 } end
    
    -- Update layout defaults
    if not BuffPowerDB.layout then
        BuffPowerDB.layout = {
            radius = BuffPower.BUTTON_RADIUS_DEFAULT, -- Old setting, can be phased out
            start_angle_offset_degrees = BuffPower.BUTTON_ANGLE_OFFSET_DEFAULT, -- Old setting
            -- New settings for list layout
            buttonWidth = 180,
            buttonHeight = 25,
            verticalSpacing = 2,
            listOffsetX = 0,
            listOffsetY = -5
        }
    else
        if BuffPowerDB.layout.buttonWidth == nil then BuffPowerDB.layout.buttonWidth = 180 end
        if BuffPowerDB.layout.buttonHeight == nil then BuffPowerDB.layout.buttonHeight = 25 end
        if BuffPowerDB.layout.verticalSpacing == nil then BuffPowerDB.layout.verticalSpacing = 2 end
        if BuffPowerDB.layout.listOffsetX == nil then BuffPowerDB.layout.listOffsetX = 0 end
        if BuffPowerDB.layout.listOffsetY == nil then BuffPowerDB.layout.listOffsetY = -5 end
    end

    if BuffPowerDB.showWindow == nil then BuffPowerDB.showWindow = true end
    if BuffPowerDB.showWindowForSolo == nil then BuffPowerDB.showWindowForSolo = true end
    if BuffPowerDB.locked == nil then BuffPowerDB.locked = false end
    if not BuffPowerDB.assignments then BuffPowerDB.assignments = {} end
    if not BuffPowerDB.classSettings then BuffPowerDB.classSettings = { MAGE = {enabled=true}, PRIEST = {enabled=true}, DRUID = {enabled=true}} end

    BuffPower.optionsPanelName = "BuffPower" -- Ensure this is set
    
    self:RegisterChatCommand("buffpower", "ChatCommand")
    self:RegisterChatCommand("bp", "ChatCommand")

    -- CRITICAL: Ensure no call to self:CreateOptionsPanel() or similar is present here.
    -- The options panel creation is handled by the ADDON_LOADED event.
    --[[ 
        -- This block should remain commented or removed:
        if not BuffPower.optionsPanelCreated and self.CreateOptionsPanel then
            self:CreateOptionsPanel(); BuffPower.optionsPanelCreated = true
        end
    --]]
    -- Ensure options panel is created every time OnInitialize runs!
    if self.CreateOptionsPanel and not BuffPower.optionsPanelCreated then
        self:CreateOptionsPanel()
        BuffPower.optionsPanelCreated = true
        DEFAULT_CHAT_FRAME:AddMessage("|cffeda55fBuffPower:|r Options panel registered.")
    end
    DebugPrint("BuffPower OnInitialize finished.") -- Changed message for clarity
end

function BuffPower:OnEnable()
    local _, playerClass = UnitClass("player")
    if not BuffPowerDB or not BuffPowerDB.classSettings or not BuffPowerDB.classSettings[playerClass] or not BuffPowerDB.classSettings[playerClass].enabled then
        DebugPrint("Addon not enabled for class: " .. playerClass)
        return
    end
    self:RegisterEvent("PLAYER_LOGIN")
    self:RegisterEvent("GROUP_ROSTER_UPDATE")
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    self:RegisterEvent("CHAT_MSG_ADDON", "OnAddonMessage")
    self:RegisterEvent("ADDON_LOADED")

    -- Enhancement: Register for buffs/debuffs for group UI refresh
    self:RegisterEvent("UNIT_AURA", "OnAuraEvent")

    -- Register slash commands with AceConsole-3.0
    self:RegisterChatCommand("buffpower", "ChatCommand")
    self:RegisterChatCommand("bp", "ChatCommand")

    if BuffPowerDB and BuffPowerDB.showWindow then
        self:CreateUI(); self:UpdateRoster()
    end
    DebugPrint("BuffPower Enabled via Ace3.")
end

-- Handler: Updates UI on unit aura change (buff/debuff)
function BuffPower:OnAuraEvent(event, arg1)
    if self.UpdateUI then self:UpdateUI() end
end

function BuffPower:OnDisable()
    self:UnregisterAllEvents()
    if BuffPowerOrbFrame then BuffPowerOrbFrame:Hide() end
    for _, btn in ipairs(BuffPowerGroupButtons) do if btn then btn:Hide() end end
    DebugPrint("BuffPower Disabled.")
end

function BuffPower:ADDON_LOADED(event, addonName) -- event arg is passed by the OnEvent script
    if addonName == "BuffPower" then
        if not BuffPower.optionsPanelCreated and self.CreateOptionsPanel then
            DebugPrint("ADDON_LOADED(" .. addonName .. "): Attempting to create options panel.")
            self:CreateOptionsPanel()
            BuffPower.optionsPanelCreated = true -- Set flag after successful call attempt
            DebugPrint("ADDON_LOADED(" .. addonName .. "): Options panel creation process called.")
        elseif BuffPower.optionsPanelCreated then
            DebugPrint("ADDON_LOADED(" .. addonName .. "): Options panel already created.")
        elseif not self.CreateOptionsPanel then
             DebugPrint("ADDON_LOADED(" .. addonName .. "): self.CreateOptionsPanel is nil. BuffPowerOptions.lua might not have loaded or attached it correctly.")
        end
    end
end

function BuffPower:PLAYER_LOGIN()
    self:UpdateRoster()
    if BuffPowerDB and BuffPowerDB.showWindow then
        if not BuffPowerOrbFrame then self:CreateUI()
        elseif BuffPowerOrbFrame and not BuffPowerOrbFrame:IsVisible() then
            BuffPowerOrbFrame:Show()
            BuffPower:UpdateOrbAppearance() -- Update appearance on show
        end
        self:UpdateUI()
    end
    DebugPrint("BuffPower: PLAYER_LOGIN event processed.")
end

function BuffPower:GROUP_ROSTER_UPDATE()
    self:UpdateRoster() -- This calls UpdateUI, which calls PositionGroupButtons
    DebugPrint("BuffPower: GROUP_ROSTER_UPDATE event processed.")
end

function BuffPower:PLAYER_ENTERING_WORLD(isInitialLogin, isReloadingUi)
    if isInitialLogin then self:RequestAssignments() end
    if isInitialLogin or isReloadingUi then
        -- Options panel creation is now handled by ADDON_LOADED
        -- Ensure no attempt to create options panel here.
        --[[
        if not BuffPower.optionsPanelCreated and self.CreateOptionsPanel then
            DebugPrint("PLAYER_ENTERING_WORLD: Attempting to create options panel.")
            self:CreateOptionsPanel()
            BuffPower.optionsPanelCreated = true
            DebugPrint("PLAYER_ENTERING_WORLD: Options panel creation process called.")
        elseif BuffPower.optionsPanelCreated then
            DebugPrint("PLAYER_ENTERING_WORLD: Options panel already created.")
        elseif not self.CreateOptionsPanel then
            DebugPrint("PLAYER_ENTERING_WORLD: self.CreateOptionsPanel is nil.")
        end
        ]]

        self:UpdateRoster()
        if BuffPowerDB and BuffPowerDB.showWindow then
            if not BuffPowerOrbFrame then self:CreateUI()
            elseif BuffPowerOrbFrame and not BuffPowerOrbFrame:IsVisible() then
                BuffPowerOrbFrame:Show()
                BuffPower:UpdateOrbAppearance()
            end
            self:UpdateUI()
        end
    end
end

function BuffPower:CHAT_MSG_ADDON(prefix, message, channel, sender)
    self:OnAddonMessage(prefix, message, channel, sender)
end

--------------------------------------------------------------------------------
-- Slash Commands
--------------------------------------------------------------------------------
function BuffPower:ChatCommand(input)
    input = input and input:lower():trim() or ""
    if not BuffPowerDB then DEFAULT_CHAT_FRAME:AddMessage("BuffPower: DB not ready.") return end

    if input == "show" or input == "" then
        BuffPowerDB.showWindow = true
        if not BuffPowerOrbFrame then self:CreateUI() else BuffPowerOrbFrame:Show() end
        BuffPower:UpdateOrbAppearance() -- Update appearance on show
        BuffPower:UpdateUI() 
    elseif input == "hide" then
        BuffPowerDB.showWindow = false
        if BuffPowerOrbFrame then BuffPowerOrbFrame:Hide() end
        for _, btn in ipairs(BuffPowerGroupButtons) do if btn then btn:Hide() end end
    elseif input == "lock" then
        BuffPowerDB.locked = true
        BuffPower:UpdateOrbAppearance() -- Update texture
        DEFAULT_CHAT_FRAME:AddMessage("BuffPower: " .. (L["Window locked."] or "Orb locked."))
    elseif input == "unlock" then
        BuffPowerDB.locked = false
        BuffPower:UpdateOrbAppearance() -- Update texture
        DEFAULT_CHAT_FRAME:AddMessage("BuffPower: " .. (L["Window unlocked."] or "Orb unlocked."))
    elseif input == "config" or input == "options" then
        -- Check if the options panel object exists and has a name
        local panelToShow = _G[(BuffPower.optionsPanelName or "BuffPower") .. "OptionsPanel"] or _G["BuffPowerOptionsPanel"]

        -- Classic Era & hard fallback: always shows standalone options window
        if BuffPower and BuffPower.ShowStandaloneOptions then
            BuffPower:ShowStandaloneOptions()
        else
            DEFAULT_CHAT_FRAME:AddMessage("BuffPower: Standalone options are not available or not fully initialized.")
        end
    elseif input == "reset" then
        if BuffPower.defaults and BuffPower.deepcopy then
            local defaultProfile = BuffPower.deepcopy(BuffPower.defaults.profile)
            if not defaultProfile.orbPosition then defaultProfile.orbPosition = { a1 = "CENTER", a2 = "CENTER", x = 0, y = 0 } end
            if not defaultProfile.layout then defaultProfile.layout = { radius = BuffPower.BUTTON_RADIUS_DEFAULT, start_angle_offset_degrees = BuffPower.BUTTON_ANGLE_OFFSET_DEFAULT } end
            if self.db and self.db.ResetProfile then
                self.db:ResetProfile()
                BuffPowerDB = self.db.profile
                BuffPowerDB.orbPosition = BuffPower.deepcopy(defaultProfile.orbPosition)
                BuffPowerDB.layout = BuffPower.deepcopy(defaultProfile.layout)
            else
                for k,v in pairs(defaultProfile) do BuffPowerDB[k] = v end
            end
            if BuffPowerOrbFrame then
                 BuffPowerOrbFrame:ClearAllPoints()
                 BuffPowerOrbFrame:SetPoint(BuffPowerDB.orbPosition.a1, UIParent, BuffPowerDB.orbPosition.a2, BuffPowerDB.orbPosition.x, BuffPowerDB.orbPosition.y)
                 BuffPower:UpdateOrbAppearance() -- Update appearance after reset
            end
            if _G["BuffPowerOptionsPanel"] and InterfaceOptionsFrame_OpenToCategory then
                InterfaceOptionsFrame_OpenToCategory(_G["BuffPowerOptionsPanel"].name or "BuffPower")
            end
            self:UpdateUI()
            DEFAULT_CHAT_FRAME:AddMessage("BuffPower: " .. (L["Settings reset to default."] or "Settings reset."))
        end
    elseif input == "testassign" then
        local _, myClass = UnitClass("player")
        if myClass then self:AssignBufferToGroup(1, UnitName("player"), myClass) end
    else
        DEFAULT_CHAT_FRAME:AddMessage("BuffPower: Usage: /bp [show|hide|lock|unlock|config|reset|testassign]")
    end
end

function BuffPower.deepcopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[BuffPower.deepcopy(orig_key)] = BuffPower.deepcopy(orig_value)
        end
        setmetatable(copy, BuffPower.deepcopy(getmetatable(orig)))
    else copy = orig end
    return copy
end

L = BuffPower.L or setmetatable({}, { __index = function(t,k) return k end })
