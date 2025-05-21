-------------------------------------------------------------------------------
-- BuffPower - Core Addon Skeleton Initialization
-------------------------------------------------------------------------------

local ADDON_NAME = ...
local MAJOR, MINOR = "BuffPower", 1

-- Localization support
local L = LibStub("AceLocale-3.0"):GetLocale("BuffPower")

-- Ace3 core: Instantiate our addon with AceConsole and AceEvent mixins.
local AceAddon = LibStub("AceAddon-3.0")
local AceConsole = LibStub("AceConsole-3.0")
local AceEvent = LibStub("AceEvent-3.0")

BuffPower = AceAddon:NewAddon("BuffPower", "AceConsole-3.0", "AceEvent-3.0")
-- TODO: Support for modular extensions via AceAddon (Not Implemented)

-- External libraries (stubs for future use)
local AceDB = LibStub("AceDB-3.0")
local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0", true)
local AceComm = LibStub("AceComm-3.0")
local LibCD = LibStub("LibClassicDurations", true)
local LibSharedMedia = LibStub("LibSharedMedia-3.0", true)
local LibDBIcon = LibStub("LibDBIcon-1.0", true)

-- Persistent saved variables placeholder
BuffPower.db = nil

-------------------------------------------------------------------------------
-- OnInitialize: called once per session after savedvars loaded.
-------------------------------------------------------------------------------
function BuffPower:OnInitialize()
    -- DONE: Register saved variables / database (AceDB-3.0)
    -- AceDB defaults: ensure all buff toggles default to enabled, plus anchor position
    local buffDefaults = {}
    if BuffPower_Buffs then
        for className, buffs in pairs(BuffPower_Buffs) do
            for buffKey, buffDef in pairs(buffs) do
                buffDefaults["buffcheck_"..buffKey:lower()] = true
            end
        end
    end
    self.db = AceDB:New("BuffPowerDB", {
        profile = buffDefaults,
        global = {},
        char = {}
        -- anchor not allowed in AceDB defaults, handle fallback in code below!
    }, true)
    -- self:RegisterOptions() -- Removed call to empty placeholder

    self:RegisterChatCommand("bp", function()
      AceConfigDialog:Open("BuffPower")
    end)

    -- DONE: Register events (e.g., PLAYER_LOGIN, etc.)
    self:RegisterEvents()

    -- TODO: Register persistent minimap icon (LibDBIcon-1.0) (Not Implemented)

    -- PARTIALLY DONE: Set up comm channel prefix (AceComm-3.0) (SetupComm function has further TODO)
    self:SetupComm()

    -- DONE: Load persistent user options and initialize UI as needed
    -- self:SetupUI() -- Removed call to empty placeholder
end

-------------------------------------------------------------------------------
-- Placeholder: Event Registration/Handling
-------------------------------------------------------------------------------
function BuffPower:RegisterEvents()
    self:RegisterEvent("PLAYER_LOGIN", "OnPlayerLogin")
    self:RegisterEvent("GROUP_ROSTER_UPDATE", "OnGroupRosterUpdate")
    self:RegisterEvent("UNIT_AURA", "OnUnitAura")
    -- You can add RAID_ROSTER_UPDATE here if needed for Classic
end

-- Update UI whenever a unit's buffs change
function BuffPower:OnUnitAura(event, unit)
    -- Only care about raid/party units and player (perf: could filter to self.roster units)
    self:UpdateRosterUI()
end

function BuffPower:OnPlayerLogin()
    -- self:RegisterChatCommand("bp", function() ... end) -- MOVED to OnInitialize

    self:CreateAnchorFrame()
    self:UpdateRosterUI()
end

function BuffPower:OnGroupRosterUpdate()
    self:UpdateRosterUI()
end

-------------------------------------------------------------------------------
-- Placeholder: AceComm Setup
-------------------------------------------------------------------------------
function BuffPower:SetupComm()
    -- TODO: Register AceComm prefix/channel for group comms (Not Implemented - self:RegisterComm is commented out)
    -- self:RegisterComm("BuffPower")
end

-------------------------------------------------------------------------------
-- TODO: Assignment System (future), syncing, localization hooks, etc. (Not Implemented)
-- TODO: Implement core assignment algorithms and comm logic in separate modules. (Not Implemented)
-- PARTIALLY DONE: Implement group frames and display logic in UI module(s). (Implemented in main file, not separate modules)
-- DONE: Integrate localization using AceLocale-3.0 or similar.
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Anchor Frame (root UI)
-------------------------------------------------------------------------------

-- Helper function to initialize spell names from spell IDs (Keep as is or adapt if BuffPower_Buffs structure changes)
local function _InitializeSpellNameCache()
    if BuffPower_Buffs then
        for class, buffs in pairs(BuffPower_Buffs) do
            for buffKey, buffDef in pairs(buffs) do
                buffDef.spellNames = {}
                for _, id in ipairs(buffDef.spellIDs or {}) do
                    local spellName = GetSpellInfo(id)
                    if spellName and not tContains(buffDef.spellNames, spellName) then
                        -- Simplified logic for now, PallyPower has more complex buff type handling
                        table.insert(buffDef.spellNames, spellName)
                    end
                end
            end
        end
    end
end

-- Function to save anchor position
function BuffPower:SaveAnchorPosition(frame)
    if not self.db or not self.db.profile then return end
    local point, _, relativePoint, x, y = frame:GetPoint()
    self.db.profile.anchor = {
        point = point,
        relativeFrame = "UIParent", -- Assuming anchor is always to UIParent for simplicity
        relativePoint = relativePoint,
        x = x,
        y = y
    }
end

-- Helper function to create and configure a group header frame
-- groupType will be a CLASS name (e.g., "WARRIOR", "MAGE") instead of a numerical groupIndex
local function _CreateClassGroupHeaderFrame(classKey, parentFrame, previousHeader, constants, groupData)
    local headerName = "BuffPowerClassGroupHeader_" .. classKey
    local groupHeader = CreateFrame("Button", headerName, parentFrame, "BuffPowerGroupButtonTemplate")
    groupHeader.classKey = classKey -- Store the class this header represents

    groupHeader:SetSize(constants.COL_WIDTH, constants.HEADER_HEIGHT_EFFECTIVE)

    if previousHeader then
        groupHeader:SetPoint("TOPLEFT", previousHeader, "BOTTOMLEFT", 0, -(constants.V_SPACING))
    else
        groupHeader:SetPoint("TOPLEFT", parentFrame, "TOPLEFT", constants.anchorPadX, constants.anchorPadY)
    end

    groupData.groupHeaders[classKey] = groupHeader

    -- Get child elements by parentKey if defined in XML, otherwise by name convention
    groupHeader.label = groupHeader.HeaderText -- Changed from groupHeader.TextWidget
    if groupHeader.label then
        groupHeader.label:SetText(L[classKey] or classKey) -- Use localized class name if available
    end

    groupHeader.buffIcons = {}
    if groupHeader.BuffIcon1 then groupHeader.buffIcons[1] = groupHeader.BuffIcon1 end
    if groupHeader.BuffIcon2 then groupHeader.buffIcons[2] = groupHeader.BuffIcon2 end
    for _, icon in ipairs(groupHeader.buffIcons) do
        icon:SetTexture(nil)
        icon:Hide()
    end

    return groupHeader
end

-- Helper function to create and configure player row frames for a class group
local function _CreatePlayerRowFramesForClassGroup(classKey, groupHeader, constants, groupData)
    groupData.groupRows[classKey] = {}
    for rowIndex = 1, constants.MAX_PLAYERS_PER_CLASS_DISPLAY do -- Max players to show per class column
        local name = "BuffPowerPlayerRow_" .. classKey .. "_" .. rowIndex
        local playerRow = CreateFrame("Button", name, groupHeader, "BuffPowerPlayerButtonTemplate")
        playerRow:SetSize(constants.COL_WIDTH, constants.ROW_HEIGHT_EFFECTIVE)

        if rowIndex == 1 then
            playerRow:SetPoint("TOPLEFT", groupHeader, "BOTTOMLEFT", 0, -(constants.V_SPACING_PLAYER_ROWS or 1))
        else
            playerRow:SetPoint("TOPLEFT", groupData.groupRows[classKey][rowIndex - 1], "BOTTOMLEFT", 0, -(constants.V_SPACING_PLAYER_ROWS or 1))
        end

        playerRow.label = playerRow.PlayerNameText -- Changed from playerRow.PlayerName
        playerRow.classIcon = playerRow.ClassIcon -- XML uses $parentClassIcon

        playerRow.buffIcons = {}
        if playerRow.BuffIcon1 then playerRow.buffIcons[1] = playerRow.BuffIcon1 end
        if playerRow.BuffIcon2 then playerRow.buffIcons[2] = playerRow.BuffIcon2 end
        for _, icon in ipairs(playerRow.buffIcons) do
            icon:SetTexture(nil)
            icon:Hide()
        end

        playerRow:Hide()
        groupData.groupRows[classKey][rowIndex] = playerRow
    end
end

function BuffPower:CreateAnchorFrame()
    _InitializeSpellNameCache()

    local uiConstants = {
        -- NUM_GROUPS is now dynamic based on classes with relevant buffs for the player's class
        MAX_PLAYERS_PER_CLASS_DISPLAY = 10, -- Max players to show in a class column before scrolling/hiding
        HEADER_HEIGHT_EFFECTIVE = 28, -- Adjusted to match PallyPower style more closely
        ROW_HEIGHT_EFFECTIVE = 18,    -- Adjusted
        COL_WIDTH = 130,              -- Adjusted
        V_SPACING = 5,                -- Spacing between class group headers
        V_SPACING_PLAYER_ROWS = 1,    -- Spacing between player rows within a class group
        H_SPACING_CLASS_GROUPS = 5,   -- Horizontal spacing between class columns
        anchorPadX = 5,
        anchorPadY = -5,
        BUFF_ICON_SIZE_HEADER = 18,
        BUFF_ICON_SIZE_PLAYER = 14,
    }
    self.uiConstants = uiConstants -- Store for later use

    local f = _G.BuffPowerFrame
    if not f then
        error("BuffPowerFrame XML root missing")
        return
    end
    self.anchorFrame = f -- Store reference

    f:Show()
    -- Drag and save logic is in XML and SaveAnchorPosition

    local ap = self.db and self.db.profile and self.db.profile.anchor
    if ap and ap.point and ap.x and ap.y then
        f:ClearAllPoints()
        f:SetPoint(ap.point, UIParent, ap.relativePoint or ap.point, ap.x, ap.y)
    else
        f:ClearAllPoints()
        f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end

    -- Group & Player Matrix UI Setup (PallyPower style: by class)
    self.groupData = {
        groupHeaders = {}, -- indexed by classKey (e.g., "WARRIOR")
        groupRows = {}     -- indexed by classKey, then by rowIndex
    }

    -- Determine which classes to display based on BuffPower_Assignments (or a similar structure)
    -- For now, let's use a predefined list or all classes in BuffPower_Buffs for the player's class
    -- This part needs to be adapted to your specific logic for which classes are relevant.
    local playerClass, playerClassFile = UnitClass("player")
    playerClassFile = playerClassFile:upper()

    local relevantClasses = {}
    if BuffPower_Assignments and BuffPower_Assignments[playerClassFile] then
        for classKey, _ in pairs(BuffPower_Assignments[playerClassFile]) do
            table.insert(relevantClasses, classKey)
        end
        table.sort(relevantClasses) -- Ensure consistent order
    else
        -- Fallback: display all classes that the current player class can buff, if no assignments exist
        -- This is a placeholder; PallyPower has a more defined set of classes it shows.
        -- You'll need to define which classes BuffPower should display columns for.
        -- Example: local displayableClasses = {"WARRIOR", "PALADIN", "ROGUE", "PRIEST", "MAGE", "WARLOCK", "DRUID", "HUNTER"}
        -- For now, let's just iterate over a fixed list for structure.
        -- This should be replaced by logic that determines which class columns to show.
        local fixedClassOrder = {"WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID"}
        for _, classKey in ipairs(fixedClassOrder) do
            table.insert(relevantClasses, classKey)
        end
    end

    local previousClassHeader = nil
    local totalWidth = 0
    local maxHeight = 0

    for i, classKey in ipairs(relevantClasses) do
        local classHeader = _CreateClassGroupHeaderFrame(classKey, f, previousClassHeader, uiConstants, self.groupData)
        _CreatePlayerRowFramesForClassGroup(classKey, classHeader, uiConstants, self.groupData)
        if classHeader then
            if i == 1 then -- First header, position relative to anchor
                 classHeader:ClearAllPoints()
                 classHeader:SetPoint("TOPLEFT", f, "TOPLEFT", uiConstants.anchorPadX, uiConstants.anchorPadY)
            else -- Subsequent headers, position relative to the previous one horizontally
                if previousClassHeader then
                    classHeader:ClearAllPoints()
                    classHeader:SetPoint("TOPLEFT", previousClassHeader, "TOPRIGHT", uiConstants.H_SPACING_CLASS_GROUPS, 0)
                end
            end
            previousClassHeader = classHeader
            totalWidth = totalWidth + uiConstants.COL_WIDTH + (i > 1 and uiConstants.H_SPACING_CLASS_GROUPS or 0)
            local currentColumnHeight = uiConstants.HEADER_HEIGHT_EFFECTIVE + (uiConstants.MAX_PLAYERS_PER_CLASS_DISPLAY * (uiConstants.ROW_HEIGHT_EFFECTIVE + uiConstants.V_SPACING_PLAYER_ROWS)) + uiConstants.anchorPadY
            if currentColumnHeight > maxHeight then
                maxHeight = currentColumnHeight
            end
        end
    end

    -- Adjust anchor frame size based on content
    if previousClassHeader then -- if any headers were created
        totalWidth = totalWidth + uiConstants.anchorPadX * 2 -- Add padding on both sides
        maxHeight = maxHeight + uiConstants.anchorPadY * 2 -- Add padding top and bottom
        f:SetSize(totalWidth, maxHeight)
    else
        f:SetSize(uiConstants.COL_WIDTH + uiConstants.anchorPadX * 2, uiConstants.HEADER_HEIGHT_EFFECTIVE + uiConstants.anchorPadY*2) -- Default small size if no classes
    end

    -- Store references for easy access
    f.GroupHeaders = self.groupData.groupHeaders
    f.GroupRows = self.groupData.groupRows
end

-------------------------------------------------------------------------------
-- Roster/Player population functions + Buff status (NEEDS BUFF indicator)
-------------------------------------------------------------------------------
local CLASS_COLORS = CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS

-- Include buff tables (global for now)
if not BuffPower_Buffs then
    if _G.BuffPower_Buffs then
        BuffPower_Buffs = _G.BuffPower_Buffs
    else
        BuffPower_Buffs = {}
    end
end

-- Helper to check if unit has one of the provided buffs (by name)
-- DEBUG: Wrapped for the user's own player row to print all buff names and all spellNames
local function HasAnyBuffByName(unit, spellNames)
    if not unit or not spellNames then return false end
    for i=1,40 do
        local name, icon, count = UnitBuff(unit, i)
        if not name then break end
        for _, targetName in ipairs(spellNames) do
            if name == targetName then return true end
        end
    end
    return false
end

-- Shared ordered class buff keys table for consistent, DRY logic
local CLASS_BUFF_ORDER = {
    PRIEST = {"FORTITUDE", "SPIRIT", "SHADOW_PROTECTION"},
    MAGE   = {"INTELLECT"},
    DRUID  = {"MARK", "THORNS"},
}

function BuffPower:UpdateRosterUI()
    if not self.anchorFrame or not self.groupData then
        self:CreateAnchorFrame()
        if not self.anchorFrame then return end -- Still couldn't create
    end
    local anchor = self.anchorFrame
    local profile = self.db and self.db.profile
    if not profile then return end

    local playerClass, playerClassFile = UnitClass("player")
    playerClassFile = playerClassFile:upper()
    local buffsForMyClass = BuffPower_Buffs[playerClassFile] or {}

    -- Collect roster data, but organize it by class
    local rosterByClass = {}
    -- Initialize for all relevant classes based on groupData headers
    if not self.groupData or not self.groupData.groupHeaders then 
        self:CreateAnchorFrame() 
        if not self.groupData or not self.groupData.groupHeaders then return end
    end
    for classKey, _ in pairs(self.groupData.groupHeaders) do
        rosterByClass[classKey] = {}
    end

    local numGroupMembers = GetNumGroupMembers()
    local inRaid = IsInRaid()

    if numGroupMembers > 0 then
        for i = 1, numGroupMembers do
            local unit = inRaid and ("raid"..i) or ("party"..i)
            if UnitExists(unit) then
                local name, _, _, _, classFileName, _, _, _, _, _, _ = GetRaidRosterInfo(i) -- Works for party too if in party
                if not name and not inRaid then -- Fallback for party if GetRaidRosterInfo fails
                    name = UnitName(unit)
                    _, classFileName = UnitClass(unit)
                end

                if name and classFileName then
                    classFileName = classFileName:upper()
                    if rosterByClass[classFileName] then
                        table.insert(rosterByClass[classFileName], {name=name, classFile=classFileName, unit=unit})
                    end
                end
            end
        end
    end
    -- Add player self to their class list
    if rosterByClass[playerClassFile] then
        local alreadyAdded = false
        for _, pdata in ipairs(rosterByClass[playerClassFile]) do
            if pdata.unit == "player" then alreadyAdded = true; break end
        end
        if not alreadyAdded then
            table.insert(rosterByClass[playerClassFile], {name=UnitName("player"), classFile=playerClassFile, unit="player"})
        end
    end

    -- Sort players within each class list alphabetically (optional)
    for classKey, classRoster in pairs(rosterByClass) do
        table.sort(classRoster, function(a,b) return a.name < b.name end)
    end

    -- Now update the UI based on rosterByClass
    local previousClassHeader = nil
    local totalWidth = 0
    local maxHeight = self.uiConstants.HEADER_HEIGHT_EFFECTIVE + self.uiConstants.anchorPadY * 2

    for classKey, classHeader in pairs(self.groupData.groupHeaders) do
        local classRoster = rosterByClass[classKey] or {}
        local playerRowsForClass = self.groupData.groupRows[classKey] or {}

        if #classRoster > 0 then
            classHeader:Show()
            -- Position class headers horizontally
            if previousClassHeader == nil then
                classHeader:ClearAllPoints()
                classHeader:SetPoint("TOPLEFT", anchor, "TOPLEFT", self.uiConstants.anchorPadX, self.uiConstants.anchorPadY)
            else
                classHeader:ClearAllPoints()
                classHeader:SetPoint("TOPLEFT", previousClassHeader, "TOPRIGHT", self.uiConstants.H_SPACING_CLASS_GROUPS, 0)
            end
            previousClassHeader = classHeader
            totalWidth = totalWidth + self.uiConstants.COL_WIDTH + (totalWidth > 0 and self.uiConstants.H_SPACING_CLASS_GROUPS or 0)

            for _, icon in ipairs(classHeader.buffIcons) do icon:Hide() end

            local currentColumnHeight = self.uiConstants.HEADER_HEIGHT_EFFECTIVE + self.uiConstants.anchorPadY

            for r = 1, #playerRowsForClass do
                local playerRow = playerRowsForClass[r]
                local playerData = classRoster[r]

                if playerData then
                    playerRow:Show()
                    playerRow.playerUnit = playerData.unit -- Store playerUnit

                    if playerRow.label then 
                        playerRow.label:SetText(playerData.name)
                        if CLASS_COLORS and CLASS_COLORS[playerData.classFile] then
                            playerRow.label:SetTextColor(CLASS_COLORS[playerData.classFile].r, CLASS_COLORS[playerData.classFile].g, CLASS_COLORS[playerData.classFile].b)
                        else
                            playerRow.label:SetTextColor(1,1,1)
                        end
                    end

                    local classIconPath = "Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES"
                    local classCoords = CLASS_ICON_TCOORDS[playerData.classFile]
                    if playerRow.classIcon and classCoords then
                        playerRow.classIcon:SetTexture(classIconPath)
                        playerRow.classIcon:SetTexCoord(unpack(classCoords))
                        playerRow.classIcon:Show()
                    elseif playerRow.classIcon then
                        playerRow.classIcon:Hide()
                    end

                    local assignedBuffKeys = {}
                    if BuffPower_Assignments and BuffPower_Assignments[playerClassFile] and BuffPower_Assignments[playerClassFile][classKey] then
                        assignedBuffKeys = BuffPower_Assignments[playerClassFile][classKey]
                    end

                    local iconIdx = 1
                    for _, buffKey in ipairs(assignedBuffKeys) do
                        if iconIdx > #playerRow.buffIcons then break end
                        local buffDef = buffsForMyClass[buffKey]
                        local iconFrame = playerRow.buffIcons[iconIdx]

                        if buffDef and profile["buffcheck_"..buffKey:lower()] ~= false then
                            local spellIdToDisplay = buffDef.spellIDs and buffDef.spellIDs[#buffDef.spellIDs] 
                            local spellNameDisplay = buffDef.spellNames and buffDef.spellNames[#buffDef.spellNames] -- Get highest rank name
                            local texture = spellIdToDisplay and select(3, GetSpellInfo(spellIdToDisplay))
                            if texture then
                                iconFrame:SetTexture(texture)
                                iconFrame.spellName = spellNameDisplay -- Store spell name for tooltip
                                -- TODO: Store spellRank if available/needed for tooltip
                                local hasBuff = HasAnyBuffByName(playerData.unit, buffDef.spellNames)
                                if hasBuff then
                                    iconFrame:SetVertexColor(1,1,1)
                                else
                                    iconFrame:SetVertexColor(1,0.2,0.2) -- Red tint if missing
                                end
                                iconFrame:Show()
                                iconIdx = iconIdx + 1
                            else
                                iconFrame:Hide()
                            end
                        else
                            iconFrame:Hide()
                        end
                    end
                    for i = iconIdx, #playerRow.buffIcons do playerRow.buffIcons[i]:Hide() end
                    currentColumnHeight = currentColumnHeight + self.uiConstants.ROW_HEIGHT_EFFECTIVE + self.uiConstants.V_SPACING_PLAYER_ROWS
                else
                    playerRow:Hide()
                    playerRow.playerUnit = nil -- Clear playerUnit if row is hidden
                end
            end
            if currentColumnHeight > maxHeight then maxHeight = currentColumnHeight end
        else
            classHeader:Hide()
            for _, playerRow in ipairs(playerRowsForClass) do
                playerRow:Hide()
                playerRow.playerUnit = nil -- Clear playerUnit
            end
        end
    end

    if totalWidth == 0 then 
        anchor:SetSize(self.uiConstants.COL_WIDTH + self.uiConstants.anchorPadX * 2, self.uiConstants.HEADER_HEIGHT_EFFECTIVE + self.uiConstants.anchorPadY*2)
    else
        anchor:SetSize(totalWidth + self.uiConstants.anchorPadX, maxHeight + self.uiConstants.anchorPadY) 
    end
end

-- Placeholder for Script Handlers defined in XML
function BuffPower:GroupHeaderClick(frame, button)
    -- print("GroupHeaderClick:", frame:GetName(), frame.classKey, button)
    -- TODO: Implement logic for clicking on a class group header
end

function BuffPower:GroupHeader_OnEnter(frame)
    GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
    GameTooltip:SetText(L[frame.classKey] or frame.classKey)
    -- TODO: Show relevant tooltip, maybe assigned group buffs
    GameTooltip:Show()
end

function BuffPower:GroupHeader_OnLeave(frame)
    GameTooltip:Hide()
end

function BuffPower:PlayerButton_OnClick(frame, button)
    -- print("PlayerButtonClick:", frame:GetName(), frame.playerUnit, button)
    if not frame.playerUnit then 
        print("BuffPower: PlayerButton_OnClick - frame.playerUnit is nil for", frame:GetName())
        return 
    end
    -- TODO: Implement logic for clicking on a player row
    -- Example: Cast a specific buff on frame.playerUnit, or open assignment menu
end

function BuffPower:PlayerButton_OnEnter(frame)
    if not frame.playerUnit then return end -- Don't show tooltip if no player
    GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
    local playerName = frame.label:GetText()
    GameTooltip:SetText(playerName)
    -- TODO: Show detailed buff status for this player
    GameTooltip:Show()
end

function BuffPower:PlayerButton_OnLeave(frame)
    GameTooltip:Hide()
end

function BuffPower:BuffIcon_OnClick(frame, button)
    -- print("BuffIconClick:", frame:GetName(), button, "Spell:", frame.spellName)
    local targetUnit = frame:GetParent().playerUnit 
    if not targetUnit and frame:GetParent():GetParent() then targetUnit = frame:GetParent():GetParent().playerUnit end 

    if frame.spellName and targetUnit then
        print("Attempting to cast:", frame.spellName, "on", targetUnit)
        CastSpellByName(frame.spellName, targetUnit) -- Be careful with secure actions in combat
    else
        print("BuffPower: BuffIcon_OnClick - spellName or targetUnit not found.", frame.spellName, targetUnit)
    end
end

function BuffPower:BuffIcon_OnEnter(frame)
    if not frame.spellName then return end -- Don't show tooltip if no spell
    GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
    GameTooltip:SetText(frame.spellName)
    -- TODO: Add more info like rank, who casts it, duration, etc.
    GameTooltip:Show()
end

function BuffPower:BuffIcon_OnLeave(frame)
    GameTooltip:Hide()
end

-- End BuffPower skeleton.