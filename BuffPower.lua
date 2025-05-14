-- BuffPower.lua
-- Core logic for BuffPower addon

local addonName = "BuffPower"

-- Attempt to get AceAddon-3.0
local AceAddon = LibStub("AceAddon-3.0")
if not AceAddon then
    print("|cffeda55fBuffPower:|r AceAddon-3.0 not found! Please ensure Ace3 library is installed.")
    return
end

-- Create the addon object using AceAddon-3.0
local BuffPower = AceAddon:NewAddon(addonName, "AceConsole-3.0", "AceEvent-3.0")

-- Get Locale table *after* NewAddon, similar to PallyPower
local L = LibStub("AceLocale-3.0"):GetLocale(addonName) 

-- Constants
local MAX_RAID_MEMBERS = 40
local MAX_PARTY_MEMBERS = 5
local MAX_RAID_GROUPS = 8
local ORB_SIZE = 15 -- Size of the central draggable orb
local BUTTON_RADIUS_DEFAULT = 70 -- Default distance of group buttons from the orb
local BUTTON_ANGLE_OFFSET_DEFAULT = -90 -- Start buttons at the top (-90 degrees)

-- Icon Paths (assuming they are in BuffPower/Icons/ folder)
local ICON_PATH_ORB_UNLOCKED = "Interface\\AddOns\\BuffPower\\Icons\\draghandle.tga"
local ICON_PATH_ORB_LOCKED = "Interface\\AddOns\\BuffPower\\Icons\\draghandle-checked.tga"
-- local ICON_PATH_RESIZE_GRIP = "Interface\\AddOns\\BuffPower\\Icons\\ResizeGrip.tga" -- For future use if resizing is added

-- Ace3 Stubs
local LibStub = _G.LibStub

-- UI Frames
local BuffPowerOrbFrame -- The central draggable orb
local BuffPowerGroupButtons = {} -- Array to hold the group button frames
-- Main group member popout frame (created on demand)
local BuffPowerGroupMemberFrame -- Will be managed in CreateUI and group button handlers
local function BuffPower_ShowGroupMemberFrame(anchorButton, groupId)
    -- Create the member frame if needed
    if not BuffPowerGroupMemberFrame then
        BuffPowerGroupMemberFrame = CreateFrame("Frame", "BuffPowerGroupMemberFrame", UIParent, BackdropTemplateMixin and "BackdropTemplate")
        BuffPowerGroupMemberFrame:SetFrameStrata("TOOLTIP")
        BuffPowerGroupMemberFrame:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 8,
            insets = { left = 2, right = 2, top = 2, bottom = 2 }
        })
        BuffPowerGroupMemberFrame:SetBackdropColor(0,0,0,0.9)
        BuffPowerGroupMemberFrame:SetMovable(false)

        -- Hide frame on mouse leave unless mouse hovers child
        BuffPowerGroupMemberFrame:SetScript("OnLeave", function(self)
            self:Hide()
        end)
    end

    -- Remove old member buttons
    if BuffPowerGroupMemberFrame.buttons then
        for _, btn in ipairs(BuffPowerGroupMemberFrame.buttons) do btn:Hide() btn:SetParent(nil) end
    end
    BuffPowerGroupMemberFrame.buttons = {}

    local members = BuffPower:GetGroupMembers(groupId)
    local buttonHeight, buttonWidth, verticalSpacing = 22, 120, 1
    local yOffset = -8
    for idx, member in ipairs(members) do
        local btn = CreateFrame("Button", "BuffPowerGroupMemberButton"..idx, BuffPowerGroupMemberFrame, "OptionsButtonTemplate")
        btn:SetSize(buttonWidth, buttonHeight)
        btn:SetPoint("TOPLEFT", 8, yOffset)
        yOffset = yOffset - (buttonHeight + verticalSpacing)

        local classColorHex = (BuffPower.ClassColors and BuffPower.ClassColors[member.class] and BuffPower.ClassColors[member.class].hex) or "|cffffffff"
        btn:SetText(classColorHex..member.name.."|r")

        btn:SetScript("OnClick", function(selfB, mouseButton)
            if mouseButton == "RightButton" then
                BuffPower:CastBuff(groupId, member.name)
                BuffPowerGroupMemberFrame:Hide()
            end
        end)
        btn:SetScript("OnEnter", function(selfB) selfB:LockHighlight() end)
        btn:SetScript("OnLeave", function(selfB) selfB:UnlockHighlight() end)
        btn:Show()
        btn:RegisterForClicks("AnyUp")
        BuffPowerGroupMemberFrame.buttons[#BuffPowerGroupMemberFrame.buttons+1] = btn
    end

    -- Set frame size based on members
    local h = (#members > 0 and (#members * (buttonHeight + verticalSpacing) + 16)) or 20
    BuffPowerGroupMemberFrame:SetSize(buttonWidth + 16, h)

    -- Position the frame to the right of the anchor button
    local x, y = anchorButton:GetRight(), select(2, anchorButton:GetCenter())
    BuffPowerGroupMemberFrame:SetPoint("LEFT", anchorButton, "RIGHT", 8, 0)
    BuffPowerGroupMemberFrame:Show()
end

-- Default Database Structure
-- BuffPowerDB = BuffPowerDB or {} -- This will be handled by AceDB in OnInitialize

-- Flag to ensure options panel is created only once
BuffPower.optionsPanelCreated = false
BuffPower.optionsPanelName = "BuffPower" -- Add this line to set the correct options panel name

-- Helper function for debugging (modified to always print)
local function DebugPrint(...)
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
                local groupID = GetRaidSubgroup(unitid)
                if not isInRaid then groupID = 1 end
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
            local group = GetRaidSubgroup("player") or 1
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

    local buffInfo = (BuffPower.ClassBuffInfo and playerClass) and BuffPower.ClassBuffInfo[playerClass]
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
    -- Create the main Frame if it doesn't exist (formerly BuffPowerOrbFrame)
    if not BuffPowerOrbFrame then
        BuffPowerOrbFrame = CreateFrame("Frame", "BuffPowerOrbFrame", UIParent)
        -- Size will be set dynamically by PositionGroupButtons
        BuffPowerOrbFrame:SetMovable(true)
        BuffPowerOrbFrame:EnableMouse(true)
        BuffPowerOrbFrame:RegisterForDrag("LeftButton")
        BuffPowerOrbFrame:SetClampedToScreen(true)

        -- Apply Backdrop directly to the main frame
        if BackdropTemplateMixin then
            Mixin(BuffPowerOrbFrame, BackdropTemplateMixin)
        end
        local backdropInfo = {
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, tileSize = 32, edgeSize = 16,
            insets = { left = 5, right = 5, top = 5, bottom = 5 }
        }
        if BuffPowerOrbFrame.SetBackdrop then
            BuffPowerOrbFrame:SetBackdrop(backdropInfo)
            BuffPowerOrbFrame:SetBackdropColor(0.1, 0.1, 0.1, 0.85) -- Darker background
        end
        
        -- Add a title text at the top of the frame
        BuffPowerOrbFrame.title = BuffPowerOrbFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        BuffPowerOrbFrame.title:SetPoint("TOP", BuffPowerOrbFrame, "TOP", 0, -8) -- Adjusted for insets
        BuffPowerOrbFrame.title:SetText("BuffPower")

        -- Create the main container frame for buttons inside the main frame
        BuffPowerOrbFrame.container = CreateFrame("Frame", "BuffPowerContainerFrame", BuffPowerOrbFrame)
        BuffPowerOrbFrame.container:SetPoint("TOPLEFT", BuffPowerOrbFrame, "TOPLEFT", 8, -28) -- Below title, adjusted for insets
        -- Container size will be set by PositionGroupButtons

        BuffPowerOrbFrame:SetScript("OnDragStart", function(self)
            if BuffPowerDB and not BuffPowerDB.locked then
                self:StartMoving()
            end
        end)
        BuffPowerOrbFrame:SetScript("OnDragStop", function(self)
            self:StopMovingOrSizing()
            if BuffPowerDB and BuffPowerDB.orbPosition then -- Keep using orbPosition for now
                BuffPowerDB.orbPosition.a1, _, BuffPowerDB.orbPosition.a2, BuffPowerDB.orbPosition.x, BuffPowerDB.orbPosition.y = self:GetPoint()
                -- Repositioning buttons is implicitly handled by Show/Hide or UpdateUI calls
            end
        end)

        BuffPowerOrbFrame:SetScript("OnMouseDown", function(self_frame, mouseButton)
            if mouseButton == "RightButton" then
                DebugPrint("RightButton clicked on BuffPowerOrbFrame.")

                if BuffPowerDB and BuffPowerDB.locked then
                    DebugPrint("UI is locked. Aborting options panel opening.")
                    DEFAULT_CHAT_FRAME:AddMessage(L["UI is locked. Unlock via options or command."] or "UI is locked.")
                    return
                end

                DebugPrint("UI is not locked. Proceeding to open options panel.")
                DebugPrint("Value of BuffPower.optionsPanelName:", BuffPower.optionsPanelName)
                DebugPrint("Type of InterfaceOptionsFrame_OpenToCategory:", type(InterfaceOptionsFrame_OpenToCategory))
                DebugPrint("Type of _G[\"BuffPowerOptionsFrame_Toggle\"]:", type(_G["BuffPowerOptionsFrame_Toggle"]))

                local panelNameToOpen = BuffPower.optionsPanelName -- Use the one set globally

                if panelNameToOpen and type(InterfaceOptionsFrame_OpenToCategory) == "function" then
                    DebugPrint("Attempting: InterfaceOptionsFrame_OpenToCategory('", panelNameToOpen, "')")
                    InterfaceOptionsFrame_OpenToCategory(panelNameToOpen)
                    DebugPrint("Called InterfaceOptionsFrame_OpenToCategory. Check if options panel appeared.")
                elseif type(_G["BuffPowerOptionsFrame_Toggle"]) == "function" then
                    DebugPrint("Attempting: _G[\"BuffPowerOptionsFrame_Toggle\"]()")
                    _G["BuffPowerOptionsFrame_Toggle"]()
                    DebugPrint("Called _G[\"BuffPowerOptionsFrame_Toggle\"]. Check if options panel appeared.")
                else
                    DebugPrint("All methods failed. Displaying 'Options panel not found.' message.")
                    DEFAULT_CHAT_FRAME:AddMessage(L["Options panel not found. Right-click to configure."] or "Options panel not found.")
                end
            end
            -- LeftButton drag is handled by RegisterForDrag
        end)
        
        -- Set initial position from DB or default
        local pos = (BuffPowerDB and BuffPowerDB.orbPosition) or { a1 = "CENTER", a2 = "CENTER", x = 0, y = 0 }
        BuffPowerOrbFrame:SetPoint(pos.a1, UIParent, pos.a2, pos.x, pos.y)
    end

    -- Set initial appearance (e.g., border for lock state)
    BuffPower:UpdateOrbAppearance()

    -- Create Group Buttons if they don't exist
    for i = 1, MAX_RAID_GROUPS do
        if not BuffPowerGroupButtons[i] then
            local groupButton = CreateFrame("Button", "BuffPowerGroupButton" .. i, BuffPowerOrbFrame.container)
            groupButton:SetSize(80, 28) -- Smaller buttons like in PallyPower
            groupButton.groupID = i
            
            -- Create a colored background texture
            groupButton.bg = groupButton:CreateTexture(nil, "BACKGROUND")
            groupButton.bg:SetAllPoints()
            groupButton.bg:SetColorTexture(0.1, 0.1, 0.1, 0.7) -- Dark background            -- Add a border
            groupButton.border = CreateFrame("Frame", nil, groupButton)
            -- Apply BackdropTemplate if available
            if BackdropTemplateMixin then
                Mixin(groupButton.border, BackdropTemplateMixin)
            end
            groupButton.border:SetPoint("TOPLEFT", groupButton, "TOPLEFT", -1, 1)
            groupButton.border:SetPoint("BOTTOMRIGHT", groupButton, "BOTTOMRIGHT", 1, -1)
            
            local borderBackdropInfo = {
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                edgeSize = 8,
                insets = {left = 0, right = 0, top = 0, bottom = 0}
            }
            
            if groupButton.border.SetBackdrop then
                groupButton.border:SetBackdrop(borderBackdropInfo)
                groupButton.border:SetBackdropBorderColor(0.6, 0.6, 0.6, 0.8)
            end
            
            -- Class icon on left
            groupButton.icon = groupButton:CreateTexture(nil, "ARTWORK")
            groupButton.icon:SetSize(20, 20)
            groupButton.icon:SetPoint("LEFT", 4, 0)
            groupButton.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93) -- Trim the icon edges
            
            -- Timer text on right (for buff duration)
            groupButton.time = groupButton:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
            groupButton.time:SetPoint("RIGHT", -4, 0)
            groupButton.time:SetText("")
            
            -- Group text in center
            groupButton.text = groupButton:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
            groupButton.text:SetPoint("LEFT", groupButton.icon, "RIGHT", 4, 0)
            groupButton.text:SetPoint("RIGHT", groupButton.time, "LEFT", -2, 0)
            groupButton.text:SetJustifyH("LEFT")
            
            groupButton:SetScript("OnClick", function(self_button, mouseButton)
                if mouseButton == "RightButton" then -- Cast buff on RightButton
                    local assignment = (BuffPowerDB and BuffPowerDB.assignments) and BuffPowerDB.assignments[self_button.groupID]
                    local _, playerClass = UnitClass("player")
                    local myName = UnitName("player")
                    if (assignment and assignment.playerName == myName) or
                       ((not assignment or not assignment.playerName) and BuffPower.ClassBuffInfo and BuffPower.ClassBuffInfo[playerClass]) then
                        if BuffPower.ClassBuffInfo and BuffPower.ClassBuffInfo[playerClass] then
                            BuffPower:CastBuff(self_button.groupID)
                        else
                            DEFAULT_CHAT_FRAME:AddMessage(L["You are not a class that can provide this type of buff."] or "Cannot provide buff.")
                        end
                    elseif assignment and assignment.playerName ~= myName then
                         DEFAULT_CHAT_FRAME:AddMessage((L["Group is assigned to: "] or "Group assigned to: ") .. assignment.playerName)
                    else
                        DEFAULT_CHAT_FRAME:AddMessage(L["This group is not assigned or you cannot buff."] or "Group not assigned/cannot buff.")
                    end
                elseif mouseButton == "LeftButton" then -- Open assignment menu on LeftButton
                    BuffPower:OpenAssignmentMenu(self_button.groupID, self_button)
                end
            end)
            
            groupButton:SetScript("OnEnter", function(self_button)
                -- Hide tooltip and show the interactive member frame instead
                if BuffPowerGroupMemberFrame and BuffPowerGroupMemberFrame:IsShown() then BuffPowerGroupMemberFrame:Hide() end
                BuffPower_ShowGroupMemberFrame(self_button, self_button.groupID)
            end)

            groupButton:SetScript("OnLeave", function(self_button)
                -- Hide frame after short delay if the mouse truly left all related widgets
                C_Timer.After(0.1, function()
                    if (not MouseIsOver(self_button)) and (not (BuffPowerGroupMemberFrame and MouseIsOver(BuffPowerGroupMemberFrame))) then
                        if BuffPowerGroupMemberFrame then BuffPowerGroupMemberFrame:Hide() end
                    end
                end)
            end)
            -- Also ensure member frame hides itself properly on mouseleave (already set above)
            groupButton:Hide() -- Initially hide
            BuffPowerGroupButtons[i] = groupButton
        end
    end

    -- Show/Hide Orb and trigger button positioning
    if BuffPowerDB and BuffPowerDB.showWindow then
        BuffPowerOrbFrame:Show()
        BuffPower:PositionGroupButtons() -- This will also show the necessary buttons
    elseif BuffPowerOrbFrame then
        BuffPowerOrbFrame:Hide()
        for _, btn in ipairs(BuffPowerGroupButtons) do
            if btn then btn:Hide() end
        end
    end
end

function BuffPower:PositionGroupButtons()
    DebugPrint("BuffPower:PositionGroupButtons called")
    if not BuffPowerOrbFrame or not BuffPowerOrbFrame:IsVisible() or not BuffPowerOrbFrame.container then
        for _, btn in pairs(BuffPowerGroupButtons) do if btn then btn:Hide() end end
        return
    end

    local effectiveGroupsToDisplay = {}
    if IsInRaid() then
        local numSubgroups = GetNumSubgroups()
        if numSubgroups == 0 and GetNumGroupMembers() > 0 then numSubgroups = math.ceil(GetNumGroupMembers() / MAX_PARTY_MEMBERS) end
        if numSubgroups == 0 and GetNumGroupMembers() > 0 then numSubgroups = 1 end -- Should be at least 1 if in a group

        for i = 1, numSubgroups do
            table.insert(effectiveGroupsToDisplay, i)
        end
         -- Fallback if GetNumSubgroups was 0 but we are in a raid group with members
        if #effectiveGroupsToDisplay == 0 and GetNumGroupMembers() > 0 then
            local numActualGroups = 0
            for i=1,MAX_RAID_MEMBERS do
                if UnitInRaid("raid"..i) then
                    numActualGroups = math.max(numActualGroups, select(5, GetRaidRosterInfo(i)) or 0)
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
    elseif BuffPowerDB and BuffPowerDB.showWindowForSolo then -- Show for solo if option enabled
        table.insert(effectiveGroupsToDisplay, 1) 
    end

    if #effectiveGroupsToDisplay == 0 then
        for _, button in pairs(BuffPowerGroupButtons) do if button then button:Hide() end end
        BuffPowerOrbFrame.container:SetSize(10,10) -- Minimal size
        BuffPowerOrbFrame:SetSize(30,30) -- Minimal size for anchor
        return
    end

    -- Layout parameters for vertical list
    local buttonWidth = 80 
    local buttonHeight = 28
    local verticalSpacing = 2
    
    -- Padding for the container inside the main frame
    local containerInternalPaddingX = 0 -- No horizontal padding needed for a single column
    local containerInternalPaddingY = 0 -- No vertical padding needed for a single column

    -- Hide all buttons initially, then show only the ones needed
    for _, button in pairs(BuffPowerGroupButtons) do 
        if button then button:Hide() end
    end

    local currentYOffset = 0
    local maxWidth = 0

    for i, groupId in ipairs(effectiveGroupsToDisplay) do
        local button = BuffPowerGroupButtons[groupId]
        if button then
            button:ClearAllPoints()
            button:SetPoint("TOPLEFT", BuffPowerOrbFrame.container, "TOPLEFT", 0, -currentYOffset)
            button:Show()
            BuffPower:UpdateGroupButtonContent(button, groupId) -- Ensure content is up-to-date
            
            currentYOffset = currentYOffset + buttonHeight + verticalSpacing
            maxWidth = math.max(maxWidth, buttonWidth) -- All buttons have same width here
        else
            DebugPrint("Button for groupID", groupId, "not found in PositionGroupButtons")
        end
    end
    
    -- Calculate container size
    local containerWidth = maxWidth + (containerInternalPaddingX * 2)
    local containerHeight = math.max(0, currentYOffset - verticalSpacing) + (containerInternalPaddingY * 2) -- Subtract last spacing
    
    BuffPowerOrbFrame.container:SetSize(containerWidth, containerHeight)
    
    -- Resize main frame (BuffPowerOrbFrame) to fit container plus its own padding/title
    -- Main frame's SetPoint for container: TOPLEFT, 8, -28
    local mainFramePaddingX = 8 -- Left padding for container
    local mainFramePaddingTitle = 28 -- Top padding for container (includes title area)
    local mainFramePaddingBottom = 8 -- Bottom padding for main frame
    local mainFramePaddingRight = 8 -- Right padding for main frame

    local totalWidth = containerWidth + mainFramePaddingX + mainFramePaddingRight
    local totalHeight = containerHeight + mainFramePaddingTitle + mainFramePaddingBottom
    
    BuffPowerOrbFrame:SetSize(totalWidth, totalHeight)

    -- Ensure all non-displayed group buttons are hidden
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
    
    -- Reset appearance
    button.bg:SetColorTexture(0.1, 0.1, 0.1, 0.7) -- Default dark background
    button.time:SetText("") -- Clear timer text
    
    if assignment and assignment.playerName and assignment.playerClass and
       BuffPower.ClassBuffInfo and BuffPower.ClassBuffInfo[assignment.playerClass] and
       BuffPower.ClassColors and BuffPower.ClassColors[assignment.playerClass] then
        -- We have an assignment with valid class information
        local buffInfo = BuffPower.ClassBuffInfo[assignment.playerClass]
        local classColor = BuffPower.ClassColors[assignment.playerClass]
        
        -- Set class-colored background
        button.bg:SetColorTexture(classColor.r * 0.3, classColor.g * 0.3, classColor.b * 0.3, 0.7)
          -- Update border color to match class
        if button.border and button.border.SetBackdropBorderColor then
            button.border:SetBackdropBorderColor(classColor.r * 0.8, classColor.g * 0.8, classColor.b * 0.8, 0.8)
        end
        
        -- Set class icon
        button.icon:SetTexture(buffInfo.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
        
        -- Set shortened display name
        local displayName = assignment.playerName
        if string.len(displayName) > 5 then displayName = string.sub(displayName, 1, 4) .. ".." end
        button.text:SetText(groupText .. ": " .. displayName)
        
        -- Set time display (could be updated dynamically in a real implementation)
        -- This is placeholder for buff duration
        if assignment.playerName == UnitName("player") then
            -- If this player is the assigned buffer, show R (Ready) as in your screenshot
            button.time:SetText("R")
            button.time:SetTextColor(0, 1, 0) -- Green for ready
        else
            -- For this mockup we'll just show placeholder times like in the screenshot
            local mockTime = groupId + 10 -- Just a placeholder value
            button.time:SetText(mockTime .. "m")
            if mockTime < 5 then
                button.time:SetTextColor(1, 0, 0) -- Red for low time
            else
                button.time:SetTextColor(1, 1, 1) -- White for normal time
            end
        end
    else
        -- Unassigned group
        button.text:SetText(groupText .. ": " .. (numGroupMembers > 0 and "None" or "Empty"))
        button.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
          -- Reset border color
        if button.border and button.border.SetBackdropBorderColor then
            button.border:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.8) -- Gray for unassigned
        end
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
    local groupMembers = BuffPower:GetGroupMembers(groupId)
    if #groupMembers > 0 then
        table.insert(menuList, { text = "-----", notCheckable=true, disabled=true })
        table.insert(menuList, { text = L["Buff Single Member"] or "Buff Single Member", isTitle = true, notCheckable = true, disabled = true })
        for _, member in ipairs(groupMembers) do
            local classColorHex = (BuffPower.ClassColors and BuffPower.ClassColors[member.class] and BuffPower.ClassColors[member.class].hex) or "|cffffffff"
            table.insert(menuList, {
                text = string.format("%s%s|r", classColorHex, member.name),
                func = function() BuffPower:CastBuff(groupId, member.name) end,
                notCheckable = true
            })
        end
    end
    EasyMenu(menuList, assignmentMenu, anchorFrame, 0, 0, "MENU")
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
            radius = BUTTON_RADIUS_DEFAULT, -- Old setting, can be phased out
            start_angle_offset_degrees = BUTTON_ANGLE_OFFSET_DEFAULT, -- Old setting
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
    DebugPrint("BuffPower OnInitialize finished.") -- Changed message for clarity
end

function BuffPower:OnEnable()
    local _, playerClass = UnitClass("player")
    if not BuffPowerDB or not BuffPowerDB.classSettings or not BuffPowerDB.classSettings[playerClass] or not BuffPowerDB.classSettings[playerClass].enabled then 
        DebugPrint("Addon not enabled for class: " .. playerClass)
        return 
    end
    self:RegisterEvent("PLAYER_LOGIN"); 
    self:RegisterEvent("GROUP_ROSTER_UPDATE")
    self:RegisterEvent("PLAYER_ENTERING_WORLD"); 
    self:RegisterEvent("CHAT_MSG_ADDON", "OnAddonMessage") -- Directly map CHAT_MSG_ADDON
    self:RegisterEvent("ADDON_LOADED") -- Register ADDON_LOADED event
    
    -- Register slash commands with AceConsole-3.0
    self:RegisterChatCommand("buffpower", "ChatCommand")
    self:RegisterChatCommand("bp", "ChatCommand")

    if BuffPowerDB and BuffPowerDB.showWindow then
        self:CreateUI(); self:UpdateRoster()
    end
    DebugPrint("BuffPower Enabled via Ace3.")
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

        if InterfaceOptionsFrame_OpenToCategory and panelToShow and panelToShow.name then
            InterfaceOptionsFrame_OpenToCategory(panelToShow.name)
        elseif InterfaceOptionsFrame_OpenToCategory and _G["BuffPowerOptionsPanel"] then -- Fallback
             InterfaceOptionsFrame_OpenToCategory(_G["BuffPowerOptionsPanel"].name or "BuffPower")
        else
            DEFAULT_CHAT_FRAME:AddMessage("BuffPower: Options panel not available or not fully initialized.")
            DebugPrint("BuffPower: Config attempt. InterfaceOptionsFrame_OpenToCategory:", InterfaceOptionsFrame_OpenToCategory, "Panel to show:", panelToShow, "BuffPower.optionsPanelName:", BuffPower.optionsPanelName)
        end
    elseif input == "reset" then
        if BuffPower.defaults and BuffPower.deepcopy then
            local defaultProfile = BuffPower.deepcopy(BuffPower.defaults.profile)
            if not defaultProfile.orbPosition then defaultProfile.orbPosition = { a1 = "CENTER", a2 = "CENTER", x = 0, y = 0 } end
            if not defaultProfile.layout then defaultProfile.layout = { radius = BUTTON_RADIUS_DEFAULT, start_angle_offset_degrees = BUTTON_ANGLE_OFFSET_DEFAULT } end
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
