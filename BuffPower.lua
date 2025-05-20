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

-- Helper function to initialize spell names from spell IDs
local function _InitializeSpellNameCache()
    if BuffPower_Buffs then
        for class, buffs in pairs(BuffPower_Buffs) do
            for buffKey, buffDef in pairs(buffs) do
                buffDef.spellNames = {}
                for _, id in ipairs(buffDef.spellIDs or {}) do
                    local spellName = GetSpellInfo(id)
                    if spellName and not tContains(buffDef.spellNames, spellName) then
                        if class == "MAGE" and buffKey == "INTELLECT" then
                            if spellName == "Arcane Intellect" or spellName == "Arcane Brilliance" then
                                table.insert(buffDef.spellNames, spellName)
                            end
                        else
                            table.insert(buffDef.spellNames, spellName)
                        end
                    end
                end
            end
        end
    end
end

-- Helper function to create and configure a group header frame
local function _CreateGroupHeaderFrame(groupIndex, parentFrame, previousHeader, constants, groupData)
    local groupHeader = CreateFrame("Frame", nil, parentFrame, BackdropTemplateMixin and "BackdropTemplate")
    groupHeader:SetSize(constants.COL_WIDTH, constants.HEADER_HEIGHT_EFFECTIVE or 32) -- Assuming HEADER_HEIGHT_EFFECTIVE includes padding or use a fixed size like 32
    groupHeader:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 8, insets = {left=1, right=1, top=1, bottom=1}
    })
    groupHeader:SetBackdropColor(0.2, 1, 0.2, 0.6) -- Default PallyPower green

    if groupIndex == 1 then
        -- Position Group 1 directly below the parentFrame (the anchor)
        groupHeader:SetPoint("TOPLEFT", parentFrame, "BOTTOMLEFT", 0, -constants.V_SPACING)
    else
        -- Position subsequent groups directly below the previous group header
        groupHeader:SetPoint("TOPLEFT", previousHeader, "BOTTOMLEFT", 0, -constants.V_SPACING)
    end
    groupData.groupHeaders[groupIndex] = groupHeader

    groupHeader.buffIcons = {}
    for iconIdx = 1, 5 do
        local icon = groupHeader:CreateTexture(nil, "ARTWORK")
        icon:SetSize(16, 16)
        icon:SetPoint("RIGHT", groupHeader, "RIGHT", -(iconIdx-1)*16 - 5, 0) -- Added small padding from edge
        icon:SetAlpha(0)
        groupHeader.buffIcons[iconIdx] = icon
    end

    local headerLabel = groupHeader:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    headerLabel:SetPoint("LEFT", groupHeader, "LEFT", 5, 0)
    headerLabel:SetPoint("RIGHT", groupHeader.buffIcons[5], "LEFT", -5, 0) -- Anchor to the left of the icons
    headerLabel:SetText("Group " .. groupIndex)
    headerLabel:SetJustifyH("LEFT")
    groupHeader.label = headerLabel

    return groupHeader
end

-- Helper function to create and configure player row frames for a group
local function _CreatePlayerRowFrames(groupIndex, groupHeader, constants, groupData)
    groupData.groupRows[groupIndex] = {}
    for rowIndex = 1, constants.ROWS_PER_GROUP do
        local playerRow = CreateFrame("Frame", nil, groupHeader, BackdropTemplateMixin and "BackdropTemplate")
        playerRow:SetSize(constants.COL_WIDTH, constants.ROW_HEIGHT_EFFECTIVE or 32) -- Assuming ROW_HEIGHT_EFFECTIVE or a fixed size like 32
        playerRow:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
        playerRow:SetBackdropColor(0, 0, 0, 0)

        if rowIndex == 1 then
            -- Position the first player row to the TOPRIGHT of the groupHeader
            playerRow:SetPoint("TOPLEFT", groupHeader, "TOPRIGHT", constants.H_SPACING, 0)
        else
            -- Subsequent rows are positioned below the previous row
            playerRow:SetPoint("TOPLEFT", groupData.groupRows[groupIndex][rowIndex-1], "BOTTOMLEFT", 0, -constants.V_SPACING)
        end

        playerRow.buffIcons = {}
        for iconIdx = 1, 5 do
            local icon = playerRow:CreateTexture(nil, "ARTWORK")
            icon:SetSize(16, 16)
            icon:SetPoint("RIGHT", playerRow, "RIGHT", -(iconIdx-1)*16 - 5, 0) -- Added small padding
            icon:SetAlpha(0)
            playerRow.buffIcons[iconIdx] = icon
        end

        local playerLabel = playerRow:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        playerLabel:SetPoint("LEFT", playerRow, "LEFT", 5, 0)
        playerLabel:SetPoint("RIGHT", playerRow.buffIcons[5], "LEFT", -5, 0) -- Anchor to the left of the icons
        playerLabel:SetText("")
        playerLabel:SetJustifyH("LEFT")
        playerRow.label = playerLabel
        playerRow:Hide()
        groupData.groupRows[groupIndex][rowIndex] = playerRow
    end

    -- Mouseover logic for showing/hiding player rows for this group
    groupHeader:SetScript("OnEnter", function(self)
        for _, rowFrame in ipairs(groupData.groupRows[groupIndex]) do rowFrame:Show() end
    end)
    groupHeader:SetScript("OnLeave", function(self)
        for _, rowFrame in ipairs(groupData.groupRows[groupIndex]) do rowFrame:Hide() end
    end)
    -- Ensure rows are hidden initially
    for _, rowFrame in ipairs(groupData.groupRows[groupIndex]) do rowFrame:Hide() end
end

function BuffPower:CreateAnchorFrame()
    -- Root frame for BuffPower UI
    if _G.BuffPowerAnchor then
        _G.BuffPowerAnchor:Show()
        return
    end

    _InitializeSpellNameCache() -- Call the helper to set up spell names

    -- Define UI constants earlier to use for anchor sizing
    local uiConstants = {
        NUM_GROUPS = 8,
        ROWS_PER_GROUP = 6,
        HEADER_HEIGHT = 16, -- Actual visual height of the header bar itself
        ROW_HEIGHT = 14,    -- Actual visual height of the player row bar itself
        HEADER_HEIGHT_EFFECTIVE = 32, -- Total space for header frame (including internal padding for icons etc)
        ROW_HEIGHT_EFFECTIVE = 20, -- Total space for player row (adjust as needed)
        COL_WIDTH = 120,
        V_SPACING = 2,
        H_SPACING = 12,
        anchorPadX = 12, -- Kept for potential future use, but not for Group 1 positioning relative to anchor
        anchorPadY = -34 -- Kept for potential future use
    }

    local f = CreateFrame("Frame", "BuffPowerAnchor", UIParent, BackdropTemplateMixin and "BackdropTemplate")
    -- Set anchor size to match group headers
    f:SetSize(uiConstants.COL_WIDTH, uiConstants.HEADER_HEIGHT_EFFECTIVE)

    local ap = BuffPower.db and BuffPower.db.profile and BuffPower.db.profile.anchor
    if ap and ap.point and ap.x and ap.y then
        f:SetPoint(ap.point, UIParent, ap.point, ap.x, ap.y)
    else
        f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
    f:SetFrameStrata("HIGH")
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(frame) frame:StartMoving() end)
    f:SetScript("OnDragStop", function(frame)
        frame:StopMovingOrSizing()
        if BuffPower.db and BuffPower.db.profile then
            local point, _, _, x, y = frame:GetPoint()
            BuffPower.db.profile.anchor = { point = point or "CENTER", x = x or 0, y = y or 0 }
        end
    end)
    f:SetScript("OnMouseUp", function(frame, button)
      if button == "RightButton" then
        AceConfigDialog:Open("BuffPower")
      end
    end)

    -- Simple visible backdrop and border for the main anchor - styled like group headers
    f:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8", -- Changed from UI-DialogBox-Background
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", -- Changed from UI-DialogBox-Border
        edgeSize = 8, 
        insets = {left=1, right=1, top=1, bottom=1} -- Changed from {left=3, right=3, top=3, bottom=3}
        -- Removed tile = true, tileSize = 32
    })
    f:SetBackdropColor(0, 0, 0, 0.80) -- Keep the background color for now, or adjust if needed

    local label = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    label:SetPoint("CENTER")
    label:SetText(L["ANCHOR_LABEL"])

    -------------------------------------------------------------------------------
    -- Group & Player Matrix UI Setup
    -------------------------------------------------------------------------------
    -- uiConstants already defined above

    local groupData = {
        groupHeaders = {},
        groupRows = {}
    }

    for group = 1, uiConstants.NUM_GROUPS do
        local previousHeader = (group > 1) and groupData.groupHeaders[group-1] or nil
        local groupHeader = _CreateGroupHeaderFrame(group, f, previousHeader, uiConstants, groupData)
        _CreatePlayerRowFrames(group, groupHeader, uiConstants, groupData)
    end

    f.GroupHeaders = groupData.groupHeaders
    f.GroupRows = groupData.groupRows

    f:Show()
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

function BuffPower:UpdateRosterUI()
    -- Defensive: skip if anchor/group refs missing
    local anchor = _G.BuffPowerAnchor
    if not anchor or not anchor.GroupRows then return end
    -- Defensive: skip if db/profile uninitialized to avoid nil errors
    local profile = BuffPower.db and BuffPower.db.profile
    if not profile then return end

    -- Determine player class for which buffs we can provide
    local PLAYER_CLASS = select(2, UnitClass("player")):upper()
    local buffsTable = BuffPower_Buffs[PLAYER_CLASS] or {}

    -- Collect roster data
    local roster = {} -- [groupNum] = { {name=, class=, unit=, file=} ... }
    for g = 1, 8 do roster[g] = {} end

    local numRaid = GetNumGroupMembers and GetNumGroupMembers() or 0
    if numRaid > 0 and IsInRaid() then
        -- RAID: group->members
        for i = 1, numRaid do
            local name, rank, subgroup, level, class, fileName, zone, online, isDead, role, isML = GetRaidRosterInfo(i)
            if name and subgroup and class and fileName then
                local unit = "raid"..i
                tinsert(roster[subgroup], {name=name, class=class, file=fileName, unit=unit})
            end
        end
    else
        -- PARTY/SOLO
        local myselfName = UnitName("player")
        local myselfClass = select(2, UnitClass("player"))
        tinsert(roster[1], {name=myselfName, class=LOCALIZED_CLASS_NAMES_MALE[myselfClass] or myselfClass, file=myselfClass, unit="player"})
        local numParty = GetNumSubgroupMembers and GetNumSubgroupMembers() or 0
        for i=1, numParty do
            local unit = "party"..i
            if UnitExists(unit) then
                local pname = UnitName(unit)
                local pclass, classFile = UnitClass(unit)
                tinsert(roster[1], {name=pname, class=pclass, file=classFile, unit=unit})
            end
        end
    end

    local inRaid = IsInRaid()
    for g = 1, 8 do
        local groupHeader = anchor.GroupHeaders and anchor.GroupHeaders[g]
        local groupRowsForGroup = anchor.GroupRows[g]

        if (not inRaid) and g > 1 then
            if groupHeader then groupHeader:Hide() end
            if groupRowsForGroup then
                for _, rowFrame in ipairs(groupRowsForGroup) do rowFrame:Hide() end
            end
        else -- Group is active (in raid, or group 1 if not in raid)
            if groupHeader then groupHeader:Show() end
            local groupNeedsBuff = false

            -- Process Player Rows for this group
            if groupRowsForGroup then
                for r = 1, #groupRowsForGroup do
                    local playerRow = groupRowsForGroup[r]
                    local label = playerRow.label
                    local info = roster[g][r]

                    playerRow:SetBackdropColor(0,0,0,0) -- Reset visuals

                    if info then
                        -- Color by class
                        if CLASS_COLORS and CLASS_COLORS[info.file] then
                            label:SetTextColor(CLASS_COLORS[info.file].r, CLASS_COLORS[info.file].g, CLASS_COLORS[info.file].b)
                        else
                            label:SetTextColor(1,1,1)
                        end
                        label:SetText(info.name)

                        -- Display player buff icons
                        local enabledBuffList = {}
                        if PLAYER_CLASS == "PRIEST" then
                            local ordered = {"FORTITUDE", "SPIRIT", "SHADOW_PROTECTION"}
                            for i = #ordered, 1, -1 do
                                local buffKey = ordered[i]
                                local profileKey = "buffcheck_"..buffKey:lower()
                                if buffsTable[buffKey] and profile[profileKey] ~= false then
                                    table.insert(enabledBuffList, buffKey)
                                end
                            end
                        else
                            for buffKey, buffData in pairs(buffsTable) do
                                local profileKey = "buffcheck_"..buffKey:lower()
                                if profile[profileKey] ~= false then
                                    table.insert(enabledBuffList, buffKey)
                                end
                            end
                        end

                        local visiblePlayerIcons = 0
                        for iconIdx = 1, 5 do
                            local icon = playerRow.buffIcons and playerRow.buffIcons[iconIdx]
                            if icon and enabledBuffList[iconIdx] then
                                local buffKey = enabledBuffList[iconIdx]
                                local buffData = buffsTable[buffKey]
                                local singleID = buffData and buffData.spellIDs and buffData.spellIDs[#buffData.spellIDs]
                                local texture = singleID and select(3, GetSpellInfo(singleID))
                                icon:SetAlpha(1)
                                if texture then
                                    icon:SetTexture(texture)
                                else
                                    icon:SetTexture(nil)
                                end
                                local missing = buffData and buffData.spellNames and #buffData.spellNames > 0 and (not HasAnyBuffByName(info.unit, buffData.spellNames))
                                if missing then
                                    icon:SetDesaturated(true)
                                    icon:SetVertexColor(1, 0.2, 0.2)
                                else
                                    icon:SetDesaturated(false)
                                    icon:SetVertexColor(1, 1, 1)
                                end
                                icon:Show()
                                visiblePlayerIcons = visiblePlayerIcons + 1
                            elseif icon then
                                icon:SetAlpha(0)
                                icon:Hide()
                            end
                        end
                        playerRow.label:ClearAllPoints()
                        playerRow.label:SetPoint("LEFT", playerRow, "LEFT", 5, 0)
                        playerRow.label:SetPoint("RIGHT", playerRow, "RIGHT")

                        -- Buff detection for this player
                        local needsAnyPlayerBuff = false
                        if PLAYER_CLASS == "PRIEST" then
                            local anyMissing = false
                            for buffKey, buffData in pairs(buffsTable) do
                                local profileKey = "buffcheck_"..buffKey:lower()
                                local enabled = profile[profileKey] ~= false
                                local missing = enabled and buffData.spellNames and #buffData.spellNames > 0 and (not HasAnyBuffByName(info.unit, buffData.spellNames))
                                -- Debug print logic removed for brevity, can be re-added if needed
                                if missing then
                                    anyMissing = true
                                end
                            end
                            needsAnyPlayerBuff = anyMissing
                        elseif PLAYER_CLASS == "MAGE" then
                            local buffData = buffsTable.INTELLECT
                            local enabled = profile["buffcheck_intellect"] ~= false
                            if enabled and buffData and buffData.spellNames and #buffData.spellNames > 0 then
                                if not HasAnyBuffByName(info.unit, buffData.spellNames) then
                                    needsAnyPlayerBuff = true
                                end
                            end
                        elseif PLAYER_CLASS == "DRUID" then
                            for buffKey, buffData in pairs(buffsTable) do
                                local enabled = profile["buffcheck_"..buffKey:lower()] ~= false
                                if enabled and buffData.spellNames and #buffData.spellNames > 0 then
                                    if not HasAnyBuffByName(info.unit, buffData.spellNames) then
                                        needsAnyPlayerBuff = true
                                        break
                                    end
                                end
                            end
                        end

                        if needsAnyPlayerBuff then
                            playerRow:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8x8"})
                            playerRow:SetBackdropColor(1, 0.15, 0.15, 0.5) -- PallyPower red style
                            label:SetText(info.name or "")
                            groupNeedsBuff = true -- Mark the group as needing a buff
                        else
                            playerRow:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8x8"})
                            playerRow:SetBackdropColor(0.2, 1, 0.2, 0.6) -- PallyPower green style
                        end
                    else -- No player info for this row
                        label:SetText("")
                    end
                end -- End of player row loop
            end -- End of check for groupRowsForGroup

            -- Process Group Header for this group
            if groupHeader then
                groupHeader:SetBackdrop({
                    bgFile = "Interface\\Buttons\\WHITE8x8",
                    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                    edgeSize = 8, insets = {left=1, right=1, top=1, bottom=1}
                })
                -- Default to green, will be overridden if groupNeedsBuff is true
                groupHeader:SetBackdropColor(0.2, 1, 0.2, 0.6)

                local enabledBuffListGroup = {}
                if PLAYER_CLASS == "PRIEST" then
                    local ordered = {"FORTITUDE", "SPIRIT", "SHADOW_PROTECTION"}
                    for i = #ordered, 1, -1 do
                        local buffKey = ordered[i]
                        local profileKey = "buffcheck_"..buffKey:lower()
                        if buffsTable[buffKey] and profile[profileKey] ~= false then
                            table.insert(enabledBuffListGroup, buffKey)
                        end
                    end
                else
                    for buffKey, buffData in pairs(buffsTable) do
                        local profileKey = "buffcheck_"..buffKey:lower()
                        if profile[profileKey] ~= false then
                            table.insert(enabledBuffListGroup, buffKey)
                        end
                    end
                end

                if groupHeader.buffIcons then
                    local visibleGroupIcons = 0
                    for iconIdx = 1, 5 do
                        local icon = groupHeader.buffIcons[iconIdx]
                        if icon and enabledBuffListGroup[iconIdx] then
                            local buffKey = enabledBuffListGroup[iconIdx]
                            local buffData = buffsTable[buffKey]
                            local groupSpellID = (buffData and buffData.spellIDs and #buffData.spellIDs > 1)
                                and buffData.spellIDs[1]
                                or (buffData and buffData.spellIDs and buffData.spellIDs[#buffData.spellIDs])
                            local texture = groupSpellID and select(3, GetSpellInfo(groupSpellID))
                            icon:SetAlpha(1)
                            if texture then
                                icon:SetTexture(texture)
                            else
                                if buffKey == "SHADOW_PROTECTION" then
                                    icon:SetTexture("Interface\\Icons\\Spell_Shadow_AntiShadow")
                                else
                                    icon:SetTexture(nil)
                                end
                            end

                            local groupIconMissingBuff = false
                            local onlySingle = buffData and buffData.spellIDs and #buffData.spellIDs == 1
                            -- local groupSpellName = onlySingle and buffData.spellNames and buffData.spellNames[1] or (buffData.spellIDs and GetSpellInfo(buffData.spellIDs[1])) -- Not directly used for logic here

                            if groupRowsForGroup then -- Ensure roster data is available
                                for rIdx = 1, #groupRowsForGroup do
                                    local playerInfo = roster[g][rIdx]
                                    if playerInfo and buffData and buffData.spellNames and #buffData.spellNames > 0 then
                                        if onlySingle then
                                            if not HasAnyBuffByName(playerInfo.unit, buffData.spellNames) then
                                                groupIconMissingBuff = true
                                                break
                                            end
                                        else
                                            local allSpellNames = {}
                                            if buffData and buffData.spellNames then
                                                for _, n in ipairs(buffData.spellNames) do table.insert(allSpellNames, n) end
                                            end
                                            if not HasAnyBuffByName(playerInfo.unit, allSpellNames) then
                                                groupIconMissingBuff = true
                                                break
                                            end
                                        end
                                    end
                                end
                            end

                            if groupIconMissingBuff then
                                icon:SetDesaturated(true)
                                icon:SetVertexColor(1, 0.2, 0.2)
                            else
                                icon:SetDesaturated(false)
                                icon:SetVertexColor(1, 1, 1)
                            end
                            icon:Show()
                            visibleGroupIcons = iconIdx -- Track the last visible icon index
                        elseif icon then
                            icon:SetAlpha(0)
                            icon:Hide()
                        end
                    end -- End of group header icon loop

                    -- Update group header label position and color
                    if groupHeader.label and groupHeader:IsShown() then
                        -- visibleGroupIcons now correctly reflects the index of the last shown icon,
                        -- or 0 if no icons are shown. This can be used for dynamic label positioning if needed in future.
                        -- For now, keeping the static positioning.
                        groupHeader.label:ClearAllPoints()
                        groupHeader.label:SetPoint("LEFT", groupHeader, "LEFT", 5, 0)
                        groupHeader.label:SetPoint("RIGHT", groupHeader, "RIGHT")

                        if groupNeedsBuff then
                            groupHeader:SetBackdropColor(1, 0.15, 0.15, 0.5) -- PallyPower red style
                        else
                            groupHeader:SetBackdropColor(0.2, 1, 0.2, 0.6) -- PallyPower green style
                        end
                        groupHeader.label:SetText("Group "..g)
                    end
                end -- End of check for groupHeader.buffIcons
            end -- End of check for groupHeader
        end -- End of active group processing (else branch)
    end -- End of main group loop (g = 1, 8)
end
-- End BuffPower skeleton.