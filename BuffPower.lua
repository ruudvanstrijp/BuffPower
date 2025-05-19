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
-- TODO: Support for modular extensions via AceAddon

-- Slash command to open options window
BuffPower:RegisterChatCommand("bp", function()
  if InterfaceOptionsFrame_OpenToCategory then
    InterfaceOptionsFrame_OpenToCategory("BuffPower")
    InterfaceOptionsFrame_OpenToCategory("BuffPower")
  end
end)

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
    -- TODO: Register saved variables / database (AceDB-3.0)
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
    self:RegisterOptions()

    -- options table registration now happens above (after AceDB is ready)
    -- self:RegisterOptions()

    -- TODO: Register events (e.g., PLAYER_LOGIN, etc.)
    self:RegisterEvents()

    -- TODO: Register persistent minimap icon (LibDBIcon-1.0)

    -- TODO: Set up comm channel prefix (AceComm-3.0)
    self:SetupComm()

    -- TODO: Load persistent user options and initialize UI as needed
    self:SetupUI()
end

-------------------------------------------------------------------------------
-- Placeholder: UI Setup
-------------------------------------------------------------------------------
function BuffPower:SetupUI()
    -- TODO: Create and anchor all root UI frames (bars, panels, group display, etc)
    -- TODO: Register UI with options window (AceConfigDialog)
end

-------------------------------------------------------------------------------
-- Placeholder: Options Registration
-------------------------------------------------------------------------------
function BuffPower:RegisterOptions()
    -- TODO: Register AceConfig options table for /buffpower and Interface Options
    -- TODO: Support profile switching via AceDBOptions
    -- TODO: Integrate LibSharedMedia-3.0 options for bar textures/sounds/colors
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
    -- TODO: Register AceComm prefix/channel for group comms
    -- self:RegisterComm("BuffPower")
end

-------------------------------------------------------------------------------
-- TODO: Assignment System (future), syncing, localization hooks, etc.
-- TODO: Implement core assignment algorithms and comm logic in separate modules.
-- TODO: Implement group frames and display logic in UI module(s).
-- TODO: Integrate localization using AceLocale-3.0 or similar.
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Anchor Frame (root UI)
-------------------------------------------------------------------------------
function BuffPower:CreateAnchorFrame()
    -- Root frame for BuffPower UI
    -- TODO: This anchor is the root for future group/buff frames!
    if _G.BuffPowerAnchor then
        _G.BuffPowerAnchor:Show()
        return
    end

    local f = CreateFrame("Frame", "BuffPowerAnchor", UIParent, BackdropTemplateMixin and "BackdropTemplate")
    f:SetSize(180, 44)
    -- Restore saved anchor position if present
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
        -- Save anchor position to DB
        if BuffPower.db and BuffPower.db.profile then
            local point, _, _, x, y = frame:GetPoint()
            BuffPower.db.profile.anchor = { point = point or "CENTER", x = x or 0, y = y or 0 }
        end
    end)
    -- Removed RegisterForClicks: only Button frames implement this; not valid here
    f:SetScript("OnMouseUp", function(frame, button)
      if button == "RightButton" then
        if InterfaceOptionsFrame_OpenToCategory then
          InterfaceOptionsFrame_OpenToCategory("BuffPower")
          InterfaceOptionsFrame_OpenToCategory("BuffPower")
        end
      end
    end)

    --[[
      Build spell name map at load time:
      For each buff's spellIDs, add a 'spellNames' array via GetSpellInfo.
      (Classic WoW: matching by name is more reliable than by spellID)
    --]]
    if BuffPower_Buffs then
      for class, buffs in pairs(BuffPower_Buffs) do
        for buffKey, buffDef in pairs(buffs) do
          buffDef.spellNames = {}
          for _, id in ipairs(buffDef.spellIDs or {}) do
            local spellName = GetSpellInfo(id)
            -- Filter: Only keep expected buff names for INTELLECT, prevent "Fireball" misdetection
            if spellName and not tContains(buffDef.spellNames, spellName) then
              if class == "MAGE" and buffKey == "INTELLECT" then
                if spellName == "Arcane Intellect" or spellName == "Arcane Brilliance" then
                  table.insert(buffDef.spellNames, spellName)
                else
                  -- skip any other spellName (like "Fireball")
                end
              else
                table.insert(buffDef.spellNames, spellName)
              end
            end
          end
        end
      end
    end

    -- Simple visible backdrop and border
    f:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        edgeSize = 8, tile = true, tileSize = 32, insets = {left=3, right=3, top=3, bottom=3}
    })
    f:SetBackdropColor(0, 0, 0, 0.80)

    -- Anchor label (localizable)
    local label = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    label:SetPoint("CENTER")
    label:SetText(L["ANCHOR_LABEL"])

    -------------------------------------------------------------------------------
    -- Minimal Group & Player Matrix UI (visual only, no live data yet)
    -- All frames below are parented to BuffPowerAnchor ('f').
    -- Each group gets a header ("Group N") and 6 blank player rows below.
    --
    -- TODO: Replace placeholder player rows with real names and group assignments.
    -- TODO: Localize group header labels for all languages (currently English only).
    -- TODO: Hook live roster/buff logic up to these stubs in future.
    -------------------------------------------------------------------------------

    local NUM_GROUPS = 8
    local ROWS_PER_GROUP = 6      -- 6 stubs per group; adjust as needed
    local HEADER_HEIGHT = 16
    local ROW_HEIGHT = 14
    local COL_WIDTH = 120 -- widened for group label + icons
    local V_SPACING = 2
    local H_SPACING = 12
    local groupHeaders = {}
    local groupRows = {}

    -- Matrix anchor positioning (anchors top-left group to anchor frame)
    local anchorPadX, anchorPadY = 12, -34  -- Horizontal/vertical offset from anchor center

    for group = 1, NUM_GROUPS do
        -- Create a group header FRAME (not FontString, so we can use mouse events)
        local groupHeader = CreateFrame("Frame", nil, f, BackdropTemplateMixin and "BackdropTemplate")
        groupHeader:SetSize(120, 32)
        -- Set backdrop for visual feedback on hover
        groupHeader:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 8, insets = {left=1, right=1, top=1, bottom=1}
        })
        groupHeader:SetBackdropColor(0.2, 1, 0.2, 0.6) -- PallyPower green style (default)

        -- Y-stack: anchor each group below previous, first is at top offset from anchor frame
        if group == 1 then
            groupHeader:SetPoint("TOPLEFT", f, "CENTER", anchorPadX, anchorPadY)
        else
            groupHeader:SetPoint("TOPLEFT", groupHeaders[group-1], "BOTTOMLEFT", 0, -V_SPACING*6 - HEADER_HEIGHT)
        end
        groupHeaders[group] = groupHeader
        groupRows[group] = {}

        -- Buff icons (max 5) for groupHeader
        groupHeader.buffIcons = {}
        for iconIdx = 1, 5 do
            local icon = groupHeader:CreateTexture(nil, "ARTWORK")
            icon:SetSize(16, 16)
            icon:SetPoint("RIGHT", groupHeader, "RIGHT", -(iconIdx-1)*16, 0)
            icon:SetAlpha(0)
            groupHeader.buffIcons[iconIdx] = icon
        end
        -- Header label, shifted right for buff icons
        local headerLabel = groupHeader:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        -- Remove static offset for label, instead reposition in UpdateRosterUI after icons
        headerLabel:SetPoint("LEFT", groupHeader, "LEFT", 5, 0) -- default, will be reset dynamically per update
        headerLabel:SetPoint("RIGHT", groupHeader, "RIGHT")
        headerLabel:SetText("Group " .. group)
        headerLabel:SetJustifyH("LEFT")
        groupHeader.label = headerLabel -- Save reference for later group UI

        -- Player row stubs: create but hide, show only on mouseover
        for row = 1, ROWS_PER_GROUP do
            local playerRow = CreateFrame("Frame", nil, groupHeader, BackdropTemplateMixin and "BackdropTemplate")
            playerRow:SetSize(120, 32)
            -- Backdrop needed for SetBackdropColor (always set, even if alpha 0)
            playerRow:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
            playerRow:SetBackdropColor(0, 0, 0, 0)
            -- Place each player row under the group header
            if row == 1 then
                playerRow:SetPoint("TOPLEFT", groupHeader, "BOTTOMLEFT", 0, -V_SPACING)
            else
                playerRow:SetPoint("TOPLEFT", groupRows[group][row-1], "BOTTOMLEFT", 0, -V_SPACING)
            end
            -- Buff icons for each enabled buff (max 5 per class)
            playerRow.buffIcons = {}
            for iconIdx = 1, 5 do
                local icon = playerRow:CreateTexture(nil, "ARTWORK")
                icon:SetSize(16, 16) -- square
                icon:SetPoint("RIGHT", playerRow, "RIGHT", -(iconIdx-1)*16, 0)
                icon:SetAlpha(0) -- hide by default
                playerRow.buffIcons[iconIdx] = icon
            end
            -- Set a simple label for now, shift right for icons
            local playerLabel = playerRow:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            playerLabel:SetPoint("LEFT", playerRow, "LEFT", 5, 0)
            playerLabel:SetPoint("RIGHT", playerRow, "RIGHT")
            playerLabel:SetText("") -- Will be set by UpdateRosterUI
            playerLabel:SetJustifyH("LEFT")
            playerRow.label = playerLabel  -- Store reference for updates
            playerRow:Hide()
            groupRows[group][row] = playerRow
        end

        -- Mouseover logic for showing player rows
        groupHeader:SetScript("OnEnter", function(self)
            for _, rowFrame in ipairs(groupRows[group]) do rowFrame:Show() end
            -- No hover color: preserve current background (green/red per group status)
            -- DO NOT set any backdrop color
        end)
        groupHeader:SetScript("OnLeave", function(self)
            for _, rowFrame in ipairs(groupRows[group]) do rowFrame:Hide() end
            -- No hover color: preserve current background (green/red per group status)
            -- DO NOT set any backdrop color
        end)

        -- Hide player rows initially (just to be sure)
        for _, rowFrame in ipairs(groupRows[group]) do rowFrame:Hide() end
    end

    -- Make frames discoverable for future logic (optional)
    f.GroupHeaders = groupHeaders
    f.GroupRows = groupRows

    -- Show the frame
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