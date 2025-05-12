-- BuffPower.lua
-- Core logic for BuffPower addon

BuffPower = BuffPower or {}
local L = BuffPower.L -- For localization, will be set up later

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

-- Default Database Structure
BuffPowerDB = BuffPowerDB or {}

-- Flag to ensure options panel is created only once
BuffPower.optionsPanelCreated = false

-- Helper function for debugging
local function DebugPrint(...)
    -- print("|cffeda55fBuffPower:|r", ...) -- Uncomment for debugging
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
    if not buffInfo then return end

    local spellIdToCast, spellNameToCast, castTarget = targetName and buffInfo.single_spell_id or buffInfo.group_spell_id, targetName and buffInfo.single_spell_name or buffInfo.group_spell_name, targetName

    if spellIdToCast then
        if playerClass == "MAGE" and not targetName then
            local reagentName = "Arcane Powder"
            if GetItemCount(reagentName) == 0 then
                DEFAULT_CHAT_FRAME:AddMessage((L["Missing reagent: "] or "Missing reagent: ") .. reagentName)
                return
            end
        end
        CastSpellByID(spellIdToCast, castTarget)
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
    local orbTexture = BuffPowerOrbFrame.texture
    if not orbTexture then return end

    if BuffPowerDB and BuffPowerDB.locked then
        orbTexture:SetTexture(ICON_PATH_ORB_LOCKED)
    else
        orbTexture:SetTexture(ICON_PATH_ORB_UNLOCKED)
    end
end

function BuffPower:CreateUI()
    -- Create the central Orb Frame if it doesn't exist
    if not BuffPowerOrbFrame then
        BuffPowerOrbFrame = CreateFrame("Frame", "BuffPowerOrbFrame", UIParent)
        BuffPowerOrbFrame:SetSize(ORB_SIZE, ORB_SIZE)
        BuffPowerOrbFrame:SetMovable(true)
        BuffPowerOrbFrame:EnableMouse(true)
        BuffPowerOrbFrame:RegisterForDrag("LeftButton")
        BuffPowerOrbFrame:SetClampedToScreen(true)        -- Store the texture on the frame for easy access
        BuffPowerOrbFrame.texture = BuffPowerOrbFrame:CreateTexture(nil, "ARTWORK") -- Use ARTWORK for icons
        BuffPowerOrbFrame.texture:SetAllPoints(BuffPowerOrbFrame)
          -- Create a background frame first (like PallyPower's main frame)
        -- Use BackdropTemplateMixin if available, for compatibility with newer WoW versions
        BuffPowerOrbFrame.backdrop = CreateFrame("Frame", "BuffPowerBackdrop", BuffPowerOrbFrame)
        -- Apply BackdropTemplate if available (for WoW Shadowlands and later)
        if BackdropTemplateMixin then
            Mixin(BuffPowerOrbFrame.backdrop, BackdropTemplateMixin)
        end
        BuffPowerOrbFrame.backdrop:SetPoint("TOPLEFT", BuffPowerOrbFrame, "BOTTOMLEFT", -5, 0)
        BuffPowerOrbFrame.backdrop:SetSize(210, 210) -- Will be resized based on content
        
        local backdropInfo = {
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true,
            tileSize = 32,
            edgeSize = 16,
            insets = { left = 5, right = 5, top = 5, bottom = 5 }
        }
        
        if BuffPowerOrbFrame.backdrop.SetBackdrop then
            BuffPowerOrbFrame.backdrop:SetBackdrop(backdropInfo)
        end
        
        -- Create the main container frame for buttons inside the backdrop
        BuffPowerOrbFrame.container = CreateFrame("Frame", "BuffPowerContainerFrame", BuffPowerOrbFrame.backdrop)
        BuffPowerOrbFrame.container:SetPoint("TOPLEFT", BuffPowerOrbFrame.backdrop, "TOPLEFT", 10, -10)
        BuffPowerOrbFrame.container:SetSize(190, 190) -- Will be resized based on content

        BuffPowerOrbFrame:SetScript("OnDragStart", function(self)
            if BuffPowerDB and not BuffPowerDB.locked then
                self:StartMoving()
            end
        end)
        BuffPowerOrbFrame:SetScript("OnDragStop", function(self)
            self:StopMovingOrSizing()
            if BuffPowerDB and BuffPowerDB.orbPosition then
                BuffPowerDB.orbPosition.a1, _, BuffPowerDB.orbPosition.a2, BuffPowerDB.orbPosition.x, BuffPowerDB.orbPosition.y = self:GetPoint()
                BuffPower:PositionGroupButtons() -- Reposition buttons relative to new orb position
            end
        end)
        
        -- Set initial position from DB or default
        local pos = (BuffPowerDB and BuffPowerDB.orbPosition) or { a1 = "CENTER", a2 = "CENTER", x = 0, y = 0 }
        BuffPowerOrbFrame:SetPoint(pos.a1, UIParent, pos.a2, pos.x, pos.y)
        
        -- Add a title text at the top of the backdrop
        BuffPowerOrbFrame.title = BuffPowerOrbFrame.backdrop:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        BuffPowerOrbFrame.title:SetPoint("TOP", BuffPowerOrbFrame.backdrop, "TOP", 0, -5)
        BuffPowerOrbFrame.title:SetText("BuffPower")
    end

    -- Set initial orb appearance
    BuffPower:UpdateOrbAppearance() -- Call this to set the correct initial texture

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
                if mouseButton == "LeftButton" then
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
                elseif mouseButton == "RightButton" then
                    BuffPower:OpenAssignmentMenu(self_button.groupID, self_button)
                end
            end)
            
            groupButton:SetScript("OnEnter", function(self_button)
                if not BuffPowerDB or not BuffPowerDB.showTooltips then return end
                GameTooltip:SetOwner(self_button, "ANCHOR_RIGHT")
                local assignment = (BuffPowerDB and BuffPowerDB.assignments) and BuffPowerDB.assignments[self_button.groupID]
                local title
                if assignment and assignment.playerName and BuffPower.ClassColors and BuffPower.ClassBuffInfo and BuffPower.ClassBuffInfo[assignment.playerClass] then
                    local classColorHex = BuffPower.ClassColors[assignment.playerClass].hex or "|cffffffff"
                    title = string.format(L["Group %d: Assigned to %s%s|r"] or "Group %d: Assigned to %s%s|r", self_button.groupID, classColorHex, assignment.playerName)
                    local buffInfo = BuffPower.ClassBuffInfo[assignment.playerClass]
                    GameTooltip:AddLine(string.format(L["Buff: %s%s|r (%s)"] or "Buff: %s%s|r (%s)", classColorHex, buffInfo.name, assignment.playerClass),1,1,1)
                else
                    title = string.format(L["Group %d: Unassigned"] or "Group %d: Unassigned", self_button.groupID)
                    GameTooltip:AddLine(L["Right-click to assign a buffer."] or "Right-click to assign.",1,1,1)
                end
                GameTooltip:AddLine(title, 1,1,1, true)
                if BuffPowerDB.showGroupMemberNames then
                    local members = BuffPower:GetGroupMembers(self_button.groupID)
                    if #members > 0 then
                        GameTooltip:AddLine(" ")
                        GameTooltip:AddLine(L["Group Members:"] or "Group Members:")
                        for _, member in ipairs(members) do
                            local classColorHex = (BuffPower.ClassColors and BuffPower.ClassColors[member.class] and BuffPower.ClassColors[member.class].hex) or "|cffffffff"
                            GameTooltip:AddLine(string.format("- %s%s|r", classColorHex, member.name))
                        end
                    else
                         GameTooltip:AddLine(L["No members in this group (or not in a group)."] or "No members in group.")
                    end
                end
                GameTooltip:Show()
            end)
            
            groupButton:SetScript("OnLeave", function(self_button) GameTooltip:Hide() end)
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
    if not BuffPowerOrbFrame or not BuffPowerOrbFrame:IsVisible() or not BuffPowerOrbFrame.container then
        return
    end

    local effectiveGroupsToDisplay = {}
    if IsInRaid() then
        local numSubgroups = GetNumSubgroups()
        -- In some cases, GetNumSubgroups might be 0 even if GetNumGroupMembers > 0 (e.g. during raid formation)
        if numSubgroups == 0 and GetNumGroupMembers() > 0 then numSubgroups = math.ceil(GetNumGroupMembers() / MAX_PARTY_MEMBERS) end
        if numSubgroups == 0 and GetNumGroupMembers() > 0 then numSubgroups = 1 end

        for i = 1, numSubgroups do
            table.insert(effectiveGroupsToDisplay, i)
        end
        -- Fallback if GetNumSubgroups was 0 but we are in a raid group
        if #effectiveGroupsToDisplay == 0 and GetNumGroupMembers() > 0 then
            table.insert(effectiveGroupsToDisplay, 1)
        end
    elseif IsInGroup() then -- This covers being in a party
        table.insert(effectiveGroupsToDisplay, 1) -- "Group 1" represents the player's party
    elseif GetNumGroupMembers() == 0 then -- Solo (not in a party or raid)
        table.insert(effectiveGroupsToDisplay, 1) -- Show one button for self buffs / solo context
    end

    -- Ensure at least one button is considered if the window is shown (e.g. for a solo player)
    if #effectiveGroupsToDisplay == 0 and BuffPowerDB and BuffPowerDB.showWindow then
        table.insert(effectiveGroupsToDisplay, 1)
    end

    if #effectiveGroupsToDisplay == 0 then
        for _, button in pairs(BuffPowerGroupButtons) do button:Hide() end -- Hide all if no groups
        return
    end

    -- Layout parameters
    local buttonWidth = 80
    local buttonHeight = 28
    local horizontalSpacing = 2
    local verticalSpacing = 2
    local buttonsPerRow = 4 -- Number of buttons in each row for the grid
    
    -- Calculate padding for the container inside backdrop
    local containerPaddingX = 10
    local containerPaddingY = 20 -- Extra padding for the title at top

    -- Hide all buttons initially
    for _, button in pairs(BuffPowerGroupButtons) do 
        if button then button:Hide() end
    end

    -- Set container size based on number of groups
    local numRows = math.ceil(#effectiveGroupsToDisplay / buttonsPerRow)
    local containerWidth = (buttonWidth * math.min(buttonsPerRow, #effectiveGroupsToDisplay)) + 
                           (horizontalSpacing * (math.min(buttonsPerRow, #effectiveGroupsToDisplay) - 1))
    local containerHeight = (buttonHeight * numRows) + (verticalSpacing * (numRows - 1))
    
    BuffPowerOrbFrame.container:SetSize(containerWidth, containerHeight)
    
    -- Resize backdrop to fit container plus padding
    if BuffPowerOrbFrame.backdrop then
        BuffPowerOrbFrame.backdrop:SetSize(
            containerWidth + (containerPaddingX * 2), 
            containerHeight + (containerPaddingY + containerPaddingX) -- More padding on top for title
        )
    end

    -- Position buttons in a grid pattern
    local currentRow = 0
    local currentCol = 0
    
    for i, groupId in ipairs(effectiveGroupsToDisplay) do
        local button = BuffPowerGroupButtons[groupId]
        
        if not button then
            -- Attempt to use the i-th button as a fallback
            if BuffPowerGroupButtons[i] then
                button = BuffPowerGroupButtons[i]
            end
        end
        
        if button then
            currentRow = math.floor((i-1) / buttonsPerRow)
            currentCol = (i-1) % buttonsPerRow
            
            button:ClearAllPoints()
            button:SetSize(buttonWidth, buttonHeight)
            
            local xPos = (currentCol * (buttonWidth + horizontalSpacing))
            local yPos = -(currentRow * (buttonHeight + verticalSpacing))
            
            button:SetPoint("TOPLEFT", BuffPowerOrbFrame.container, "TOPLEFT", xPos, yPos)
            button:Show()
            
            self:UpdateGroupButtonContent(button, groupId)
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
    EasyMenu(menuList, assignmentMenu, anchorFrame, 0, 0, "MENU")
end

--------------------------------------------------------------------------------
-- Addon Lifecycle
--------------------------------------------------------------------------------
function BuffPower:OnInitialize()
    if LibStub and LibStub:GetLibrary("AceDB-3.0", true) then
        self.db = LibStub("AceDB-3.0"):New("BuffPowerDB", BuffPower.defaults, true)
        BuffPowerDB = self.db.profile
    else
        BuffPowerDB = BuffPowerDB or {}
        local defaults = (BuffPower.defaults and BuffPower.defaults.profile) or {}
        for k, v in pairs(defaults) do
            if BuffPowerDB[k] == nil then BuffPowerDB[k] = (BuffPower.deepcopy and BuffPower.deepcopy(v)) or v end
        end
    end
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
            listOffsetX = 0,  -- Horizontal offset of the list from the anchor's left
            listOffsetY = -5  -- Vertical offset of the list from the anchor's bottom (negative is downwards)
        }
    else
        -- Add new settings if layout table exists but is missing them (for existing users)
        if BuffPowerDB.layout.buttonWidth == nil then BuffPowerDB.layout.buttonWidth = 180 end
        if BuffPowerDB.layout.buttonHeight == nil then BuffPowerDB.layout.buttonHeight = 25 end
        if BuffPowerDB.layout.verticalSpacing == nil then BuffPowerDB.layout.verticalSpacing = 2 end
        if BuffPowerDB.layout.listOffsetX == nil then BuffPowerDB.layout.listOffsetX = 0 end
        if BuffPowerDB.layout.listOffsetY == nil then BuffPowerDB.layout.listOffsetY = -5 end
    end

    if BuffPowerDB.showWindow == nil then BuffPowerDB.showWindow = true end
    if BuffPowerDB.locked == nil then BuffPowerDB.locked = false end
    if not BuffPowerDB.assignments then BuffPowerDB.assignments = {} end
    if not BuffPowerDB.classSettings then BuffPowerDB.classSettings = { MAGE = {enabled=true}, PRIEST = {enabled=true}, DRUID = {enabled=true}} end

    L = BuffPower.L or setmetatable({}, { __index = function(t, k) return k end })
    self:RegisterChatCommand("buffpower", "ChatCommand")
    self:RegisterChatCommand("bp", "ChatCommand")
    if not BuffPower.optionsPanelCreated and self.CreateOptionsPanel then
        self:CreateOptionsPanel(); BuffPower.optionsPanelCreated = true
    end
    DebugPrint("BuffPower Initialized.")
end

function BuffPower:OnEnable()
    local _, playerClass = UnitClass("player")
    if not BuffPowerDB or not BuffPowerDB.classSettings or not BuffPowerDB.classSettings[playerClass] or not BuffPowerDB.classSettings[playerClass].enabled then return end
    self:RegisterEvent("PLAYER_LOGIN"); self:RegisterEvent("GROUP_ROSTER_UPDATE")
    self:RegisterEvent("PLAYER_ENTERING_WORLD"); self:RegisterEvent("CHAT_MSG_ADDON")
    if BuffPowerDB and BuffPowerDB.showWindow then
        self:CreateUI(); self:UpdateRoster()
    end
    DebugPrint("BuffPower Enabled.")
end

function BuffPower:OnDisable()
    self:UnregisterAllEvents()
    if BuffPowerOrbFrame then BuffPowerOrbFrame:Hide() end
    for _, btn in ipairs(BuffPowerGroupButtons) do if btn then btn:Hide() end end
    DebugPrint("BuffPower Disabled.")
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
        self:UpdateRoster()
        if BuffPowerDB and BuffPowerDB.showWindow then
            if not BuffPowerOrbFrame then self:CreateUI()
            elseif BuffPowerOrbFrame and not BuffPowerOrbFrame:IsVisible() then
                BuffPowerOrbFrame:Show()
                BuffPower:UpdateOrbAppearance() -- Update appearance on show
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
        if InterfaceOptionsFrame_OpenToCategory and _G["BuffPowerOptionsPanel"] then
            InterfaceOptionsFrame_OpenToCategory(_G["BuffPowerOptionsPanel"].name or "BuffPower")
        else
            DEFAULT_CHAT_FRAME:AddMessage("BuffPower: Options panel not available.")
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

-- Event Frame and Registration (Simplified Ace3-like)
local eventFrame = CreateFrame("Frame", "BuffPowerEventFrame")
BuffPower.eventFrame = eventFrame
BuffPower.eventHandlers = BuffPower.eventHandlers or {}

function BuffPower:RegisterEvent(event, method)
    if not method then method = event end
    self.eventFrame:RegisterEvent(event)
    if not self.eventHandlers[event] then self.eventHandlers[event] = {} end
    table.insert(self.eventHandlers[event], method)
end

function BuffPower:UnregisterAllEvents()
    if self.eventFrame then self.eventFrame:UnregisterAllEvents() end
    self.eventHandlers = {}
end

BuffPower.eventFrame:SetScript("OnEvent", function(frame, event, ...)
    if BuffPower.eventHandlers and BuffPower.eventHandlers[event] then
        for _, handlerName in ipairs(BuffPower.eventHandlers[event]) do
            local handlerFunc = BuffPower[handlerName]
            if type(handlerFunc) == "function" then
                handlerFunc(BuffPower, ...)
            end
        end
    end
end)

function BuffPower:RegisterChatCommand(cmd, handlerMethodName)
    if cmd == "buffpower" then SLASH_BUFFPOWER1 = "/buffpower" end
    if cmd == "bp" then SLASH_BUFFPOWER2 = "/bp" end
    if not SlashCmdList then SlashCmdList = {} end
    SlashCmdList["BUFFPOWER"] = function(msg)
        if BuffPower[handlerMethodName] then BuffPower[handlerMethodName](BuffPower, msg) end
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
BuffPower:OnInitialize()
BuffPower:OnEnable()

DEFAULT_CHAT_FRAME:AddMessage("BuffPower.lua loaded (UI Overhaul with Custom Icons)")
