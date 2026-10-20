-- BuffPower.lua
-- Author: Ruuddie
-- Main addon logic for BuffPower
-- Buff management for Mages, Priests, and Druids

-------------------------------------------------------------------
-- Addon Creation
-------------------------------------------------------------------
BuffPower = LibStub("AceAddon-3.0"):NewAddon("BuffPower", "AceConsole-3.0", "AceEvent-3.0", "AceBucket-3.0", "AceTimer-3.0")

local tinsert = table.insert
local tsort = table.sort
local format = string.format

-------------------------------------------------------------------
-- API Compatibility
--
-- WoW Forever runs on the Mainline API family, where the Classic-era
-- globals below were replaced by the C_Spell / C_SpellBook namespaces. Each wrapper prefers the global where it still exists, so
-- Classic behaviour is unchanged, and keeps the Classic return signature
-- so the rest of the addon does not need to branch on game version.
-------------------------------------------------------------------
local GetSpellInfo = GetSpellInfo
if not GetSpellInfo and C_Spell and C_Spell.GetSpellInfo then
    GetSpellInfo = function(spell)
        local info = C_Spell.GetSpellInfo(spell)
        if not info then return nil end
        return info.name, nil, info.iconID, info.castTime, info.minRange, info.maxRange, info.spellID
    end
end

local IsSpellKnown = IsSpellKnown
if not IsSpellKnown and C_SpellBook and C_SpellBook.IsSpellKnown then
    IsSpellKnown = C_SpellBook.IsSpellKnown
end

-- Classic returns 1/0/nil, Mainline returns true/false/nil, and the deprecated
-- Mainline global is inconsistent between builds. Callers test `~= 0`, so coerce
-- whatever comes back to the numeric form (nil still means "range unknown").
local IsSpellInRangeRaw = IsSpellInRange or (C_Spell and C_Spell.IsSpellInRange)
local function IsSpellInRange(spell, unit)
    if not IsSpellInRangeRaw then return nil end
    local inRange = IsSpellInRangeRaw(spell, unit)
    if inRange == true then return 1 end
    if inRange == false then return 0 end
    return inRange
end

-- The WoW Forever beta (1.60.1) ships a RestrictedExecution.lua that captures
-- loadstring_untainted, a function that build does not provide, so the client cannot
-- compile secure snippets at all - every SecureHandlerExecute and _on* attribute
-- throws. Without snippets the addon still works, it just cannot expand a group's
-- player list while in combat.
--
-- Every client's RestrictedExecution.lua (Classic Era, Classic and Retail alike)
-- compiles snippets through that global, so its presence is an exact test. Don't
-- probe by running a snippet instead: the failure is reported to the error handler
-- before it unwinds, so it shows up on screen even inside a pcall.
local function CanUseSecureSnippets()
    return loadstring_untainted ~= nil
end

-- Forever makes auras secret in combat, and the aura API then refuses addon reads
-- ("Auras cannot be accessed when secret while tainted"), so every buff would look
-- missing. Classic clients have no C_Secrets and can always read auras.
local function AurasAreSecret()
    return C_Secrets and C_Secrets.ShouldAurasBeSecret and C_Secrets.ShouldAurasBeSecret()
end

-------------------------------------------------------------------
-- Visual Style
-------------------------------------------------------------------
-- Every colour the grid uses, so the look can be changed in one place.
local COLORS = {
    background = { 0.15, 0.15, 0.15, 0.9 }, -- before the first status update
    border = { 0, 0, 0, 1 },
    -- Status: a dark tinted fill keeps text and icons readable
    buffed = { 0.05, 0.20, 0.05, 0.9 },
    missing = { 0.28, 0.04, 0.04, 0.9 },
    inactive = { 0.12, 0.12, 0.12, 0.9 }, -- offline or dead
    iconEdge = { 0, 0, 0, 1 },
    iconBuffed = { 1, 1, 1 },
    iconMissing = { 0.8, 0.8, 0.8 }, -- on top of desaturation
    textShadow = { 0, 0, 0, 1 },
}

-- Buff icon size, and the distance from one icon's left edge to the next
local ICON_SIZE = 22
local ICON_SPACING = 26

-- Flat fill with a 1px edge, instead of the tooltip background and border textures
local BUTTON_BACKDROP = {
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    edgeSize = 1,
}

local function StyleButton(button)
    button:SetBackdrop(BUTTON_BACKDROP)
    button:SetBackdropColor(unpack(COLORS.background))
    button:SetBackdropBorderColor(unpack(COLORS.border))
end

-- Blizzard icon textures have a grey bevel baked in; crop it off and draw a thin dark edge instead
local function CreateIconTexture(icon, path)
    icon.edge = icon:CreateTexture(nil, "BACKGROUND")
    icon.edge:SetPoint("TOPLEFT", icon, "TOPLEFT", -1, 1)
    icon.edge:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 1, -1)
    icon.edge:SetColorTexture(unpack(COLORS.iconEdge))

    icon.texture = icon:CreateTexture(nil, "ARTWORK")
    icon.texture:SetAllPoints()
    icon.texture:SetTexture(path)
    icon.texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    -- Hover feedback; the button shows it by itself, so it also works in combat
    icon:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
    icon:GetHighlightTexture():SetBlendMode("ADD")
end

-- A solid shadow keeps text readable on the red and green fills
local function StyleText(fontString, sizeDelta)
    fontString:SetShadowColor(unpack(COLORS.textShadow))
    fontString:SetShadowOffset(1, -1)
    if sizeDelta then
        local face, size, flags = fontString:GetFont()
        if face and size then
            fontString:SetFont(face, size + sizeDelta, flags or "")
        end
    end
end

-- The remaining buff time sits on the bottom of the icon, like an action bar count, so
-- neighbouring icons' timers can't run together. The outlined number font stays
-- readable on top of the icon art.
local function CreateTimerText(icon)
    icon.timer = icon:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    icon.timer:SetPoint("BOTTOM", icon, "BOTTOM", 0, 1)
    StyleText(icon.timer)
end

-- State variables
BuffPower.player = UnitName("player")
BuffPower.playerClass = nil
BuffPower.availableBuffs = {}
BuffPower.raidComposition = {}
BuffPower.groupBuffStatus = {}
BuffPower.initialized = false

-------------------------------------------------------------------
-- Ace Framework Events
-------------------------------------------------------------------
function BuffPower:OnInitialize()
    -- Get player class FIRST (needed for options)
    local _, englishClass = UnitClass("player")
    self.playerClass = englishClass

    -- Check if player is a supported class
    if not BuffPower_Spells[self.playerClass] then
        -- Don't create UI for unsupported classes
        return
    end

    -- Initialize database (global settings plus a few per-character ones, no profiles)
    self.db = LibStub("AceDB-3.0"):New("BuffPowerDB", BUFFPOWER_DEFAULT_VALUES)
    self.opt = self.db.global
    self.charOpt = self.db.char
    self:MigrateCharacterSettings()

    -- Initialize default group responsibilities
    self:InitializeDefaultResponsibilities()

    -- Setup options panel
    self:SetupOptions()

    -- Register slash commands
    self:RegisterChatCommand("bp", "SlashCommand")

    -- Create UI layout
    self:CreateLayout()

    -- Tell the user why in-combat behaviour is reduced on clients that cannot
    -- compile secure snippets, rather than letting it look like a bug.
    if not CanUseSecureSnippets() then
        self:Print("This client cannot run secure addon code, so group player lists will not expand while you are in combat.")
    end

    -- Setup minimap icon
    self:SetupMinimapIcon()

    self.initialized = true
end

function BuffPower:OnEnable()
    -- Check if player is a supported class
    if not BuffPower_Spells[self.playerClass] then
        self:Print("BuffPower is designed for Mages, Priests, and Druids.")
        return
    end

    -- Initialize default assignments for this class
    self:InitializeDefaultAssignments()

    -- Scan available buffs
    self:ScanPlayerBuffs()

    -- Register events
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnPlayerEnteringWorld")
    self:RegisterBucketEvent({"GROUP_ROSTER_UPDATE", "UNIT_PET"}, 1, "UpdateRoster")
    self:RegisterBucketEvent({"UNIT_AURA"}, 0.5, "OnUnitAura")
    self:RegisterEvent("SPELLS_CHANGED", "ScanPlayerBuffs")
    self:RegisterEvent("PLAYER_TALENT_UPDATE", "ScanPlayerBuffs")
    self:RegisterEvent("ZONE_CHANGED", "UpdateRoster")
    self:RegisterEvent("ZONE_CHANGED_NEW_AREA", "UpdateRoster")
    self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnCombatEnded")

    -- Schedule repeating timer for UI updates (every 0.2 seconds for smooth range updates)
    self.updateTimer = self:ScheduleRepeatingTimer("OnTimerTick", 0.2)

    -- Initial update
    self:UpdateRoster()

    self:Print("BuffPower enabled for " .. self.playerClass)
end

function BuffPower:OnDisable()
    self:UnregisterAllEvents()
    self:UnregisterAllBuckets()
    self:CancelAllTimers()

    -- Hide UI
    if BuffPowerFrame then
        BuffPowerFrame:Hide()
    end
end

-------------------------------------------------------------------
-- Slash Commands
-------------------------------------------------------------------
function BuffPower:SlashCommand(input)
    if not input or input == "" then
        -- Toggle main frame
        if BuffPowerFrame and BuffPowerFrame:IsShown() then
            BuffPowerFrame:Hide()
            self.isManuallyHidden = true
        else
            if BuffPowerFrame then
                self.isManuallyHidden = false
                BuffPowerFrame:Show()
                self:UpdateLayout()
            end
        end
    elseif input == "options" or input == "opt" then
        self:OpenConfigWindow()
    elseif input == "reset" then
        self:ResetFramePosition()
    elseif input == "debug" then
        self.opt.debug = not self.opt.debug
        self:Print("Debug mode: " .. (self.opt.debug and "ON" or "OFF"))
    else
        self:Print("Usage: /bp [opt||options||debug||reset]")
    end
end

function BuffPower:OpenConfigWindow()
    LibStub("AceConfigDialog-3.0"):Open("BuffPower")
end

function BuffPower:ResetFramePosition()
    if InCombatLockdown() then return end

    local display = self.opt.display
    display.point, display.relativePoint, display.offsetX, display.offsetY = "CENTER", "CENTER", 0, 0
    self:RestoreFramePosition()
end

-- StartMoving re-anchors the frame (often to TOPLEFT), so DragStop saves the anchor
-- points along with the offsets. Positions saved by older versions have no points
-- and were always restored as CENTER, which the defaults keep doing.
function BuffPower:RestoreFramePosition()
    local display = self.opt.display
    self.Frame:ClearAllPoints()
    self.Frame:SetPoint(display.point, UIParent, display.relativePoint, display.offsetX, display.offsetY)
end

-------------------------------------------------------------------
-- Event Handlers
-------------------------------------------------------------------
function BuffPower:OnPlayerEnteringWorld()
    self:ScanPlayerBuffs()
    self:UpdateRoster()
end

function BuffPower:OnUnitAura(units)
    -- Update buff status when auras change
    self:UpdateBuffStatus()
    self:UpdateUI()
end

-- Layout, roster and spell changes are skipped while in combat, so catch up on them now.
-- A player list whose hide timer fired during combat could not be hidden then either.
function BuffPower:OnCombatEnded()
    self:UpdateRoster()
    for groupNum, playerButtons in pairs(self.playerButtons) do
        if not self:IsMouseOverGroup(groupNum) then
            for _, playerButton in pairs(playerButtons) do
                playerButton:Hide()
            end
        end
    end
end

function BuffPower:OnTimerTick()
    -- Every 0.2s only redraw colours, countdowns and range fading. Every 5th tick (1s)
    -- rescan auras as a safety net for changes UNIT_AURA does not report (deaths,
    -- disconnects, players coming into view) and re-pick the secure click targets, which
    -- depend on who is in range.
    self.tickCount = (self.tickCount or 0) + 1
    if self.tickCount % 5 == 0 then
        self:UpdateBuffStatus()
        self:UpdateUI()
    else
        self:UpdateUI(true)
    end
end

-- In combat only the text/colour "Display" updates are allowed; out of combat the
-- full updates run unless displayOnly is set, and they call the Display updates themselves.
function BuffPower:UpdateUI(displayOnly)
    displayOnly = displayOnly or InCombatLockdown()

    for groupNum, button in pairs(self.groupButtons) do
        if button:IsShown() then
            if displayOnly then
                self:UpdateGroupButtonDisplay(button, groupNum)
            else
                self:UpdateGroupButton(button, groupNum)
            end
        end
    end

    for groupNum, playerButtons in pairs(self.playerButtons) do
        local members = self.raidComposition[groupNum]
        for i, playerButton in pairs(playerButtons) do
            if playerButton:IsShown() and members and members[i] then
                if displayOnly then
                    self:UpdatePlayerButtonDisplay(playerButton, members[i], groupNum)
                else
                    self:UpdatePlayerButton(playerButton, members[i], groupNum)
                end
            end
        end
    end
end

-------------------------------------------------------------------
-- Default Assignments Initialization
-------------------------------------------------------------------
function BuffPower:InitializeDefaultAssignments()
    local classSpells = BuffPower_Spells[self.playerClass]
    if not classSpells then return end

    -- Fill in any class without a saved choice, so classes added later (PET) get defaults too.
    -- Optional buffs (Thorns, Amplify, Dampen) and ineligible classes default to off.
    for buffKey, buffData in pairs(classSpells) do
        local assignments = self.opt.assignments[buffKey] or {}
        self.opt.assignments[buffKey] = assignments
        for _, targetClass in ipairs(BuffPower_ClassOrder) do
            if assignments[targetClass] == nil then
                local ineligible = buffData.ineligibleClasses and buffData.ineligibleClasses[targetClass]
                assignments[targetClass] = not (buffData.optional or ineligible)
            end
        end
    end
end

function BuffPower:InitializeDefaultResponsibilities()
    -- Default: responsible for all groups
    for i = 1, BUFFPOWER_CONSTANTS.MAX_RAID_GROUPS do
        if self.charOpt.myResponsibleGroups["Group " .. i] == nil then
            self.charOpt.myResponsibleGroups["Group " .. i] = true
        end
    end
end

-- Up to v1.1.0-beta2 group responsibilities and player overrides were shared by all
-- characters, and an override was stored as a position in the current class's list of
-- optional buffs. Each character copies them once, converting positions with its own
-- class, so it keeps exactly what it showed before. The global copies are left in
-- place for characters that have not logged in since.
function BuffPower:MigrateCharacterSettings()
    local char, global = self.charOpt, self.opt
    if char.migratedFromGlobal then return end
    char.migratedFromGlobal = true

    for group, value in pairs(global.myResponsibleGroups or {}) do
        char.myResponsibleGroups[group] = value
    end

    local keys = self:GetAssignableBuffKeys()
    for name, index in pairs(global.playerAssignments or {}) do
        if type(index) == "number" and keys[index] then
            char.playerAssignments[name] = keys[index]
        end
    end
end

-------------------------------------------------------------------
-- Player Buff Scanning
-------------------------------------------------------------------
-- Highest known rank of a spell variant (rankIDs run high to low), or nil when none is learned.
local function FirstKnownRank(variant)
    for _, id in ipairs(variant.rankIDs or { variant.spellID }) do
        if IsSpellKnown(id) then return id end
    end
end

function BuffPower:ScanPlayerBuffs()
    self.availableBuffs = {}
    self.rangeSpell = nil

    for buffKey, buffData in pairs(BuffPower_Spells[self.playerClass]) do
        for _, variant in ipairs({ buffData.single, buffData.group }) do
            local id = FirstKnownRank(variant)
            variant.isKnown = id ~= nil
            variant.spellID = id or variant.spellID
            -- Always the localized name: it is what gets cast and what auras are matched against.
            variant.name = GetSpellInfo(variant.spellID) or variant.name
        end

        self.availableBuffs[buffKey] = buffData.single.isKnown
        self:Debug("ScanPlayerBuffs: " .. buffKey .. " = " .. tostring(buffData.single.isKnown))

        -- The first available single buff is used for range checking
        if buffData.single.isKnown and not self.rangeSpell then
            self.rangeSpell = buffData.single.name
        end
    end

    self:UpdateLayout()
end

-------------------------------------------------------------------
-- Roster Management
-------------------------------------------------------------------
function BuffPower:UpdateRoster()
    -- Clear existing composition
    for i = 1, BUFFPOWER_CONSTANTS.MAX_RAID_GROUPS do
        self.raidComposition[i] = {}
    end

    local numMembers = GetNumGroupMembers()

    -- Check display conditions
    if numMembers == 0 then
        -- Solo play
        if self.opt.ShowWhenSolo then
            local playerInfo = self:GetPlayerInfo("player")
            playerInfo.subgroup = 1
            tinsert(self.raidComposition[1], playerInfo)
        end
    elseif IsInRaid() then
        -- Raid
        for i = 1, numMembers do
            local _, _, subgroup = GetRaidRosterInfo(i)
            if subgroup then
                local playerInfo = self:GetPlayerInfo("raid" .. i)
                playerInfo.subgroup = subgroup
                tinsert(self.raidComposition[subgroup], playerInfo)
            end
        end

        -- Add raid pets if enabled
        if self.opt.ShowPets then
            for i = 1, numMembers do
                local petUnitid = "raidpet" .. i
                if UnitExists(petUnitid) then
                    local _, _, subgroup = GetRaidRosterInfo(i)
                    if subgroup then
                        local playerInfo = self:GetPlayerInfo(petUnitid)
                        playerInfo.subgroup = subgroup
                        tinsert(self.raidComposition[subgroup], playerInfo)
                    end
                end
            end
        end
    else
        -- Party
        if self.opt.ShowInParty then
            -- Player is always in group 1
            local playerInfo = self:GetPlayerInfo("player")
            playerInfo.subgroup = 1
            tinsert(self.raidComposition[1], playerInfo)

            for i = 1, 4 do
                local unitid = "party" .. i
                if UnitExists(unitid) then
                    local partyInfo = self:GetPlayerInfo(unitid)
                    partyInfo.subgroup = 1
                    tinsert(self.raidComposition[1], partyInfo)
                end
            end

            -- Party pets
            if self.opt.ShowPets then
                if UnitExists("pet") then
                    local petInfo = self:GetPlayerInfo("pet")
                    petInfo.subgroup = 1
                    tinsert(self.raidComposition[1], petInfo)
                end
                for i = 1, 4 do
                    local petUnitid = "partypet" .. i
                    if UnitExists(petUnitid) then
                        local petInfo = self:GetPlayerInfo(petUnitid)
                        petInfo.subgroup = 1
                        tinsert(self.raidComposition[1], petInfo)
                    end
                end
            end
        end
    end

    self:UpdateBuffStatus()
    self:UpdateLayout()
end

-- Pets ("pet", "partypetN", "raidpetN") are classed as PET so the Pet checkbox in
-- Class Assignments decides their buffs, rather than the class the client reports for them.
function BuffPower:GetPlayerInfo(unitid)
    local isPet = unitid:find("pet") ~= nil
    local _, classFilename = UnitClass(unitid)
    return {
        name = GetUnitName(unitid, true),
        unitid = unitid,
        classFilename = isPet and "PET" or classFilename,
        isDead = UnitIsDeadOrGhost(unitid),
        isOnline = UnitIsConnected(unitid),
        isPet = isPet,
    }
end

function BuffPower:GetPlayerInfoByUnitID(unitid)
    for _, members in pairs(self.raidComposition) do
        for _, playerInfo in ipairs(members) do
            if playerInfo.unitid == unitid then
                return playerInfo
            end
        end
    end
    return nil
end

-------------------------------------------------------------------
-- Buff Status Checking
-------------------------------------------------------------------
function BuffPower:UpdateBuffStatus()
    -- While auras can't be read, each unit keeps the status last read (see CheckPlayerBuffs)
    local lastStatus
    if AurasAreSecret() then
        lastStatus = {}
        for _, groupStatus in pairs(self.groupBuffStatus) do
            for unitid, memberStatus in pairs(groupStatus.memberStatus) do
                lastStatus[unitid] = memberStatus
            end
        end
    end

    self.groupBuffStatus = {}

    for groupNum, members in pairs(self.raidComposition) do
        if #members > 0 then
            local groupStatus = { memberStatus = {}, buffCounts = {}, allBuffed = true }
            self.groupBuffStatus[groupNum] = groupStatus

            for buffKey in pairs(BuffPower_Spells[self.playerClass]) do
                groupStatus.buffCounts[buffKey] = { buffed = 0, needed = 0, minExpires = math.huge }
            end

            for _, playerInfo in ipairs(members) do
                playerInfo.isDead = UnitIsDeadOrGhost(playerInfo.unitid)
                playerInfo.isOnline = UnitIsConnected(playerInfo.unitid)

                -- Keyed by unit ID: names are not unique (two pets called "Wolf")
                local memberStatus = self:CheckPlayerBuffs(playerInfo,
                    lastStatus and (lastStatus[playerInfo.unitid] or { buffStatus = {} }))
                groupStatus.memberStatus[playerInfo.unitid] = memberStatus

                for buffKey, status in pairs(memberStatus.buffStatus) do
                    local counts = groupStatus.buffCounts[buffKey]
                    if status.hasBuff then
                        counts.buffed = counts.buffed + 1
                        counts.minExpires = math.min(counts.minExpires, status.expires)
                    else
                        counts.needed = counts.needed + 1
                        groupStatus.allBuffed = false
                    end
                end
            end
        end
    end
end

-- With lastStatus (auras secret), buffs are not read but carried over from it, dropping
-- those whose expiration time has passed. A unit seen for the first time shows as missing.
function BuffPower:CheckPlayerBuffs(playerInfo, lastStatus)
    local status = { needsAny = false, buffStatus = {}, isPet = playerInfo.isPet }

    -- Skip dead or offline players
    if playerInfo.isDead or not playerInfo.isOnline then
        return status
    end

    -- Only buffs we can cast, on units that should receive them (class assignment + player override)
    for buffKey, buffData in pairs(BuffPower_Spells[self.playerClass]) do
        if self.availableBuffs[buffKey] and self:ShouldBuffUnit(buffKey, playerInfo.name, playerInfo.classFilename) then
            local hasBuff, expires
            if lastStatus then
                local last = lastStatus.buffStatus[buffKey]
                hasBuff = last and last.hasBuff and last.expires > GetTime() or false
                expires = hasBuff and last.expires or math.huge
            else
                hasBuff, expires = self:UnitHasBuff(playerInfo.unitid, buffData)
            end
            status.buffStatus[buffKey] = { hasBuff = hasBuff, expires = expires }
            if not hasBuff then
                status.needsAny = true
            end
        end
    end

    return status
end

function BuffPower:ShouldBuffClass(buffKey, classFilename)
    local buffData = BuffPower_Spells[self.playerClass][buffKey]
    if not buffData then return false end

    -- Check options assignment
    local assignments = self.opt.assignments[buffKey]
    if assignments and assignments[classFilename] == false then
        return false
    end

    -- Check eligibility
    if buffData.ineligibleClasses and buffData.ineligibleClasses[classFilename] then
        return false
    end

    return true
end

-- The optional single-target-only buffs (Thorns, Amplify Magic, Dampen Magic) that the
-- scroll wheel can force on a player, sorted. The class never changes, so it is built once.
function BuffPower:GetAssignableBuffKeys()
    if not self.assignableBuffKeys then
        local keys = {}
        for k, v in pairs(BuffPower_Spells[self.playerClass] or {}) do
            if v.optional and not v.group then
                tinsert(keys, k)
            end
        end
        tsort(keys)
        self.assignableBuffKeys = keys
    end
    return self.assignableBuffKeys
end

-- A forced buff is added on top of the class assignments, so a player can get, say,
-- Arcane Intellect from their class and Amplify Magic from the override.
function BuffPower:ShouldBuffUnit(buffKey, unitName, unitClass)
    if self.charOpt.playerAssignments[unitName] == buffKey then
        return true
    end
    return self:ShouldBuffClass(buffKey, unitClass)
end

-- All ranks of a buff share one name, so matching on the (localized) name covers every rank.
-- Returns the expiration time, math.huge for a buff that does not expire.
local function FindBuff(unitid, variant)
    if not variant then return end
    local name, _, _, _, _, expirationTime = AuraUtil.FindAuraByName(variant.name, unitid, "HELPFUL")
    if not name then return end
    return true, (expirationTime and expirationTime > 0) and expirationTime or math.huge
end

-- Returns whether the unit has the buff and when it expires (math.huge when missing or permanent).
function BuffPower:UnitHasBuff(unitid, buffData)
    if not UnitExists(unitid) then return false, math.huge end
    local hasBuff, expires = FindBuff(unitid, buffData.single)
    if not hasBuff then
        hasBuff, expires = FindBuff(unitid, buffData.group)
    end
    return hasBuff or false, expires or math.huge
end

-- Whether any player in the group is missing this buff. Pets are ignored here:
-- they are buffed single-target, so a missing pet buff never triggers a group cast.
function BuffPower:GroupNeedsBuff(groupNum, buffKey)
    local groupStatus = self.groupBuffStatus[groupNum]
    if not groupStatus then return false end

    for _, memberStatus in pairs(groupStatus.memberStatus) do
        local buffStatus = memberStatus.buffStatus[buffKey]
        if buffStatus and not buffStatus.hasBuff and not memberStatus.isPet then
            return true
        end
    end

    return false
end

-------------------------------------------------------------------
-- Buff Casting Logic
-------------------------------------------------------------------
function BuffPower:GetSmartBuffsForGroup(groupNum, targetUnit)
    local priority = BuffPower_BuffPriority[self.playerClass]
    if not priority then return nil, nil, nil, nil end

    local members = self.raidComposition[groupNum]
    if not members then return nil, nil, nil, nil end

    local singleSpell, singleUnit
    local groupSpell, groupUnit

    -- Find the first missing single buff or the one expiring soonest
    local soonestExpires = math.huge
    local fallbackSingleSpell, fallbackSingleUnit

    for _, playerInfo in ipairs(members) do
        local isPlayer = (playerInfo.unitid == "player")
        if playerInfo.isOnline and not playerInfo.isDead and (isPlayer or UnitIsVisible(playerInfo.unitid)) then
            for _, buffKey in ipairs(priority) do
                local buffData = BuffPower_Spells[self.playerClass][buffKey]
                if buffData and self.availableBuffs[buffKey] and self:ShouldBuffUnit(buffKey, playerInfo.name, playerInfo.classFilename) then
                    local mStatus = self.groupBuffStatus[groupNum].memberStatus[playerInfo.unitid]
                    if mStatus then
                        local bStatus = mStatus.buffStatus[buffKey]
                        if bStatus then
                            -- Check range: nil means "unknown" (not on action bar), 1 means "in range", 0 means "out of range"
                            local inRange = not buffData.single or (IsSpellInRange(buffData.single.name, playerInfo.unitid) ~= 0)
                            if inRange then
                                if not bStatus.hasBuff then
                                    if not singleSpell then
                                        singleSpell = buffData.single.name
                                        singleUnit = playerInfo.unitid
                                    end
                                elseif bStatus.expires < soonestExpires then
                                    soonestExpires = bStatus.expires
                                    fallbackSingleSpell = buffData.single.name
                                    fallbackSingleUnit = playerInfo.unitid
                                end
                            end
                        end
                    end
                end
            end
        end
        if singleSpell then break end
    end

    if not singleSpell then
        singleSpell = fallbackSingleSpell
        singleUnit = fallbackSingleUnit
    end

    -- If still no singleSpell found (e.g. everyone fully buffed & same duration),
    -- default to the first available single buff for targetUnit (if targetUnit exists)
    if not singleSpell and targetUnit then
        local targetPlayer = self:GetPlayerInfoByUnitID(targetUnit)
        if targetPlayer then
            for _, buffKey in ipairs(priority) do
                local buffData = BuffPower_Spells[self.playerClass][buffKey]
                if buffData and self.availableBuffs[buffKey] and buffData.single and self:ShouldBuffUnit(buffKey, targetPlayer.name, targetPlayer.classFilename) then
                    singleSpell = buffData.single.name
                    singleUnit = targetUnit
                    break
                end
            end
        end
    end

    -- Find the first missing group buff
    for _, buffKey in ipairs(priority) do
        if self.availableBuffs[buffKey] then
            local buffData = BuffPower_Spells[self.playerClass][buffKey]
            if buffData and buffData.group and buffData.group.isKnown then
                if self:GroupNeedsBuff(groupNum, buffKey) then
                    groupSpell = buffData.group.name
                    groupUnit = targetUnit
                    break
                end
            end
        end
    end

    -- Left click: group buff when one is needed, otherwise the single buff. Right click: always the single buff.
    if groupSpell then
        return groupSpell, groupUnit, singleSpell, singleUnit
    end
    return singleSpell, singleUnit, singleSpell, singleUnit
end

-------------------------------------------------------------------
-- UI Creation
-------------------------------------------------------------------
function BuffPower:CreateLayout()
    if InCombatLockdown() then return end

    -- Frames from BuffPower.xml: BuffPowerFrame is the movable root, BuffPowerAnchor
    -- the drag handle and BuffPowerHeader the parent of all group buttons.
    self.Frame = _G["BuffPowerFrame"]
    self.Anchor = _G["BuffPowerAnchor"]
    self.Header = _G["BuffPowerHeader"]

    -- Dragging the anchor moves the whole frame
    self.Frame:SetMovable(true)
    self.Frame:SetClampedToScreen(true)

    self:RestoreFramePosition()

    -- Create group buttons
    self.groupButtons = {}
    self.playerButtons = {}

    for i = 1, BUFFPOWER_CONSTANTS.MAX_RAID_GROUPS do
        self:CreateGroupButton(i)
    end

    self:SetUpCombatPlayerLists()

    self:UpdateScale()
    self:UpdateLayout()
end

-------------------------------------------------------------------
-- Player lists in combat
-------------------------------------------------------------------
-- Out of combat, GroupButton_OnEnter shows a group's player buttons from Lua. In
-- combat that is forbidden, so the same is done by snippets that run in the
-- restricted environment. Each frame's snippet environment holds:
--   group button:    "players"     its own player buttons, in order
--                    "otherFirsts" player button 1 of every other group
--   player button 1: "rest"        player buttons 2..N of its group
-- UpdateLayout sets the "hasMember" attribute to 1 on the player buttons that show
-- a member; those always come first.

-- Entering a group closes the other groups' lists and opens this one. The list
-- auto-hides 2 seconds after the mouse leaves both it and the group button.
local GROUP_ONENTER = [[
    for i = 1, #otherFirsts do
        otherFirsts[i]:Hide()
    end
    local first = players[1]
    if first:GetAttribute("hasMember") ~= 1 then return end
    first:Show()
    first:RegisterAutoHide(2)
    first:AddToAutoHide(self)
    for i = 2, #players do
        local player = players[i]
        if player:GetAttribute("hasMember") ~= 1 then break end
        player:Show()
        first:AddToAutoHide(player)
    end
]]

-- Player button 1 carries the auto-hide, so hiding it closes the whole list.
local FIRST_PLAYER_ONHIDE = [[
    for i = 1, #rest do
        rest[i]:Hide()
    end
]]

-- Appends frame to the list called listName in owner's snippet environment.
local function AppendFrameRef(owner, listName, frame)
    SecureHandlerSetFrameRef(owner, "entry", frame)
    SecureHandlerExecute(owner, listName .. "[#" .. listName .. " + 1] = self:GetFrameRef(\"entry\")")
end

function BuffPower:SetUpCombatPlayerLists()
    -- Purely secure-handler wiring; without snippet support there is nothing to set up.
    if not CanUseSecureSnippets() then return end

    local numGroups = BUFFPOWER_CONSTANTS.MAX_RAID_GROUPS
    for groupNum = 1, numGroups do
        local groupButton = self.groupButtons[groupNum]
        local players = self.playerButtons[groupNum]
        local first = players[1]

        SecureHandlerExecute(groupButton, [[players = newtable(); otherFirsts = newtable()]])
        SecureHandlerExecute(first, [[rest = newtable()]])

        for i, playerButton in ipairs(players) do
            AppendFrameRef(groupButton, "players", playerButton)
            if i > 1 then
                AppendFrameRef(first, "rest", playerButton)
            end
        end
        for otherNum = 1, numGroups do
            if otherNum ~= groupNum then
                AppendFrameRef(groupButton, "otherFirsts", self.playerButtons[otherNum][1])
            end
        end

        groupButton:SetAttribute("_onenter", GROUP_ONENTER)
        first:SetAttribute("_onhide", FIRST_PLAYER_ONHIDE)
    end

    self:Debug("SetUpCombatPlayerLists: " .. numGroups .. " groups")
end

function BuffPower:CreateGroupButton(groupNum)
    -- The SecureHandler templates expand the player list in combat, SecureActionButtonTemplate does the casting.
    local button = CreateFrame("Button", "BuffPowerGroupButton" .. groupNum, self.Header, "SecureHandlerShowHideTemplate, SecureHandlerEnterLeaveTemplate, SecureActionButtonTemplate, BackdropTemplate")

    -- Group label - G1..G8 on the left
    button.text = button:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    button.text:SetPoint("LEFT", button, "LEFT", 3, 0)
    button.text:SetText("G" .. groupNum)
    button.text:SetWidth(28)
    button.text:SetJustifyH("CENTER")
    StyleText(button.text)

    button.groupNum = groupNum
    button.buffIcons = {}

    button:RegisterForClicks("AnyUp", "AnyDown")

    -- Non-secure scripts (tooltip etc). No OnClick script: it would override the secure attributes.
    button:HookScript("OnEnter", function(self) BuffPower:GroupButton_OnEnter(self) end)
    button:HookScript("OnLeave", function(self) BuffPower:GroupButton_OnLeave(self) end)

    button:SetSize(self.opt.groupButtonWidth, 38)
    StyleButton(button)
    button:Hide()

    self.groupButtons[groupNum] = button
    self:CreateGroupBuffIcons(button, groupNum)

    self.playerButtons[groupNum] = {}
    for j = 1, BUFFPOWER_CONSTANTS.MAX_PLAYERS_PER_GROUP do
        self:CreatePlayerButton(groupNum, j)
    end
end

function BuffPower:CreateGroupBuffIcons(groupButton, groupNum)
    -- One icon per buff regardless of assignments; UpdateGroupButton shows and hides them.
    for buffKey, buffData in pairs(BuffPower_Spells[self.playerClass]) do
        -- SecureActionButtonTemplate for protected casting; parented to UIParent to avoid secure anchor issues
        local icon = CreateFrame("Button", "BuffPowerGroup" .. groupNum .. "BuffIcon_" .. buffKey, UIParent, "SecureActionButtonTemplate")
        icon:SetSize(ICON_SIZE, ICON_SIZE)
        icon:SetFrameStrata("MEDIUM")

        CreateIconTexture(icon, (buffData.group and buffData.group.icon) or buffData.single.icon)

        icon.buffKey = buffKey

        -- Left click: group spell when known, otherwise single. Right click: single on a specific player.
        icon:SetAttribute("type1", "spell")
        icon:SetAttribute("spell1", (buffData.group and buffData.group.isKnown) and buffData.group.name or buffData.single.name)
        icon:SetAttribute("type2", "spell")
        icon:SetAttribute("spell2", buffData.single.name)

        CreateTimerText(icon)

        icon:SetScript("OnEnter", function(self) BuffPower:BuffIcon_OnEnter(self) end)
        icon:SetScript("OnLeave", function() GameTooltip:Hide() end)
        icon:RegisterForClicks("AnyUp", "AnyDown")
        icon:Hide()

        groupButton.buffIcons[buffKey] = icon
    end
end

function BuffPower:PerformPlayerCycle(delta, groupNum, playerIndex)
    if InCombatLockdown() then return end

    local members = self.raidComposition[groupNum]
    if not members or not members[playerIndex] then return end

    local playerInfo = members[playerIndex]
    local unitName = playerInfo.name

    local keys = self:GetAssignableBuffKeys()
    local numKeys = #keys

    -- If no assignable buffs for this class, do nothing
    if numKeys == 0 then return end

    -- Positions 0..N: 0 is Auto, 1..N force that key. Stored as the key itself (nil for Auto).
    local current = 0
    for i, key in ipairs(keys) do
        if self.charOpt.playerAssignments[unitName] == key then current = i end
    end

    current = (current + (delta > 0 and 1 or -1)) % (numKeys + 1)
    self.charOpt.playerAssignments[unitName] = keys[current]

    -- Feedback
    local statusText = "Auto"
    if current > 0 then
        statusText = "Force " .. BuffPower_Spells[self.playerClass][keys[current]].displayName
    end
    self:Print("Assignment for " .. unitName .. ": " .. statusText)

    -- Trigger Update
    self:UpdateBuffStatus()
    self:UpdateUI()
end

function BuffPower:CreatePlayerButton(groupNum, playerIndex)
    -- Created on UIParent and then reparented to the group button
    local button = CreateFrame("Button", "BuffPowerGroup" .. groupNum .. "Player" .. playerIndex, UIParent, "SecureHandlerShowHideTemplate, SecureHandlerEnterLeaveTemplate, SecureActionButtonTemplate, BackdropTemplate")
    button:SetFrameStrata("DIALOG")
    button:SetSize(self.opt.playerButtonWidth, 38)
    StyleButton(button)

    -- Player name; UpdatePlayerBuffIcons moves its right edge to make room for the shown buff icons
    button.playerName = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    button.playerName:SetPoint("LEFT", button, "LEFT", 5, 0)
    button.playerName:SetPoint("RIGHT", button, "RIGHT", -78, 0)
    button.playerName:SetJustifyH("LEFT")
    button.playerName:SetWordWrap(false)
    StyleText(button.playerName, 1)

    button.groupNum = groupNum
    button.playerIndex = playerIndex
    button.buffIcons = {}
    self:CreatePlayerBuffIcons(button)

    button:RegisterForClicks("AnyUp", "AnyDown")
    button:EnableMouseWheel(true)
    button:SetScript("OnMouseWheel", function(self, delta)
        BuffPower:PerformPlayerCycle(delta, self.groupNum, self.playerIndex)
    end)
    button:HookScript("OnEnter", function(self) BuffPower:PlayerButton_OnEnter(self) end)
    button:HookScript("OnLeave", function(self) BuffPower:PlayerButton_OnLeave(self) end)

    button:SetParent(self.groupButtons[groupNum])
    button:Hide()

    self.playerButtons[groupNum][playerIndex] = button
end

function BuffPower:CreatePlayerBuffIcons(playerButton)
    local classSpells = BuffPower_Spells[self.playerClass]
    if not classSpells then return end

    -- Create/update icons for all single-target buffs
    for buffKey, buffData in pairs(classSpells) do
        if buffData.single then
            -- Use buffKey-based naming to ensure icons are persistent per buff type
            local iconName = playerButton:GetName() .. "_" .. buffKey
            local icon = playerButton.buffIcons[buffKey]

            if not icon then
                -- Use SecureActionButtonTemplate for protected spell casting
                -- Parent to UIParent initially to avoid secure anchor issues
                icon = CreateFrame("Button", iconName, UIParent, "SecureActionButtonTemplate")
                icon:SetSize(ICON_SIZE, ICON_SIZE)
                icon:SetFrameStrata("MEDIUM")

                CreateIconTexture(icon, buffData.single.icon)

                icon:RegisterForClicks("AnyUp", "AnyDown")

                icon:SetScript("OnEnter", function(self)
                    BuffPower:PlayerBuffIcon_OnEnter(self)
                end)
                icon:SetScript("OnLeave", function(self)
                    GameTooltip:Hide()
                end)

                icon:Hide()

                icon.buffKey = buffKey
                icon.playerButton = playerButton

                -- Set up secure spell casting attributes - will be updated with unit in UpdatePlayerBuffIcons
                icon:SetAttribute("type1", "spell")
                icon:SetAttribute("spell1", buffData.single.name)
                icon:SetAttribute("type2", "spell")
                icon:SetAttribute("spell2", buffData.single.name)

                CreateTimerText(icon)

                playerButton.buffIcons[buffKey] = icon
            end
        end
    end
end

-------------------------------------------------------------------
-- Anchor/Drag Handle Functions
-------------------------------------------------------------------
function BuffPower:AnchorClick(anchor, button, down)
    -- If button is nil (possible in some contexts if caught early), don't error
    if not button then return end

    if button == "LeftButton" then
        -- Toggle lock state
        BuffPower.opt.locked = not BuffPower.opt.locked
        BuffPowerAnchor:SetChecked(BuffPower.opt.locked)
        BuffPower:Print(BuffPower.opt.locked and "Position locked" or "Position unlocked - drag to move")
    elseif button == "RightButton" then
        -- Undo the native check toggle, then open options
        anchor:SetChecked(BuffPower.opt.locked)
        BuffPower:OpenConfigWindow()
    end
end

function BuffPower:Anchor_OnEnter(anchor)
    if self.opt.ShowTooltips then
        GameTooltip:SetOwner(anchor, "ANCHOR_RIGHT")
        GameTooltip:SetText("BuffPower")
        GameTooltip:AddLine("Left-click: Lock/Unlock position", 1, 1, 1)
        GameTooltip:AddLine("Drag: Move frame", 1, 1, 1)
        GameTooltip:AddLine("Right-click: Open options", 1, 1, 1)
        GameTooltip:Show()
    end
end

function BuffPower:DragStart(anchor, button)
    -- Drag BuffPowerFrame, not the anchor, so everything moves together
    if not BuffPower.opt.locked and not InCombatLockdown() then
        _G["BuffPowerFrame"]:StartMoving()
        BuffPowerFrame:SetClampedToScreen(true)
    end
end

function BuffPower:DragStop(anchor, button)
    _G["BuffPowerFrame"]:StopMovingOrSizing()
    -- Save position, including the anchor points StartMoving may have switched to
    local display = BuffPower.opt.display
    local point, _, relativePoint, x, y = BuffPowerFrame:GetPoint()
    display.point, display.relativePoint, display.offsetX, display.offsetY = point, relativePoint, x, y
end

-- Show the drag handle to the left of the Header
function BuffPower:UpdateAnchor()
    self.Anchor:SetChecked(self.opt.locked or false)
    self.Anchor:ClearAllPoints()
    self.Anchor:SetPoint("TOPRIGHT", self.Header, "TOPLEFT", -2, 0)
    self.Anchor:Show()
end

-------------------------------------------------------------------
-- UI Scale
-------------------------------------------------------------------
function BuffPower:UpdateScale()
    if self.Frame then
        self.Frame:SetScale(self.opt.buffscale)
    end
end

-------------------------------------------------------------------
-- UI Update
-------------------------------------------------------------------
function BuffPower:UpdateLayout()
    if InCombatLockdown() then return end
    if not self.Header then return end
    if self.isManuallyHidden then return end
    if not self.groupButtons then return end

    -- Position and update group buttons
    local visibleGroups = 0
    local buttonHeight = 38
    local groupButtonWidth = self.opt.groupButtonWidth
    local playerButtonWidth = self.opt.playerButtonWidth

    for groupNum = 1, BUFFPOWER_CONSTANTS.MAX_RAID_GROUPS do
        local button = self.groupButtons[groupNum]
        if button then
            local members = self.raidComposition[groupNum]
            local isResponsible = self.charOpt.myResponsibleGroups["Group " .. groupNum] ~= false

            if members and #members > 0 and isResponsible then
                visibleGroups = visibleGroups + 1
                button:SetSize(groupButtonWidth, buttonHeight)
                button:ClearAllPoints()
                button:SetPoint("TOPLEFT", self.Header, "TOPLEFT", 0, -((visibleGroups - 1) * (buttonHeight + 2)))
                button:Show()

                -- Update group button content
                self:UpdateGroupButton(button, groupNum)

                -- Pre-position the player buttons and set the hasMember attribute the combat
                -- snippets read. Positioned relative to Header even though parented to groupButton.
                local playerButtonHeight = buttonHeight
                local groupOffsetX = 0  -- Group button is at TOPLEFT of Header
                local groupOffsetY = -((visibleGroups - 1) * (buttonHeight + 2))
                local playerOffsetX = groupOffsetX + groupButtonWidth + 2

                for j = 1, BUFFPOWER_CONSTANTS.MAX_PLAYERS_PER_GROUP do
                    local playerButton = self.playerButtons[groupNum][j]
                    if playerButton then
                        if members[j] then
                            -- Position relative to Header for consistent coordinate space
                            playerButton:SetSize(playerButtonWidth, buttonHeight)
                            playerButton:ClearAllPoints()
                            -- Use clean spacing (2px gap to avoid overlap and borders merging)
                            -- 38px height + 2px gap = 40px stride
                            playerButton:SetPoint("TOPLEFT", self.Header, "TOPLEFT", playerOffsetX, groupOffsetY - ((j - 1) * (playerButtonHeight + 2)))
                            playerButton:SetAttribute("hasMember", 1)
                            -- Pre-update the player button with current data
                            self:UpdatePlayerButton(playerButton, members[j], groupNum)
                        else
                            playerButton:SetAttribute("hasMember", 0)
                            playerButton:Hide()
                        end
                    end
                end
            else
                button:Hide()
                -- Hide player buttons and clear hasMember
                for j = 1, BUFFPOWER_CONSTANTS.MAX_PLAYERS_PER_GROUP do
                    if self.playerButtons[groupNum] and self.playerButtons[groupNum][j] then
                        self.playerButtons[groupNum][j]:SetAttribute("hasMember", 0)
                        self.playerButtons[groupNum][j]:Hide()
                    end
                end
            end
        end
    end

    -- Resize main frame and show/hide Frame
    if visibleGroups > 0 then
        self.Header:SetSize(groupButtonWidth + 10, visibleGroups * (buttonHeight + 2) + 10)
        self.Header:Show()
        self.Frame:Show()
        self:UpdateAnchor()
    else
        self.Header:Hide()

        local numMembers = GetNumGroupMembers()
        local shouldHideCompletely = false

        if numMembers == 0 and not self.opt.ShowWhenSolo then
            shouldHideCompletely = true
        elseif numMembers > 0 and not IsInRaid() and not self.opt.ShowInParty then
            shouldHideCompletely = true
        end

        if shouldHideCompletely then
            self.Frame:Hide()
        else
            -- Keep Frame shown so anchor can be seen when active but empty
            self.Frame:Show()
            self:UpdateAnchor()
        end
    end
end

-- Buff icons are in full colour when the buff is present and greyed out when it is
-- missing; the button's red fill already signals the missing buff
local function Tint(icon, hasBuff)
    icon.texture:SetDesaturated(not hasBuff)
    icon.texture:SetVertexColor(unpack(hasBuff and COLORS.iconBuffed or COLORS.iconMissing))
end

function BuffPower:UpdateGroupButton(button, groupNum)
    local groupStatus = self.groupBuffStatus[groupNum]
    if not groupStatus then return end

    -- Call Display update first for text
    self:UpdateGroupButtonDisplay(button, groupNum)

    -- Find first member of this group for group buff targeting
    local members = self.raidComposition[groupNum]
    local targetUnit = nil
    if members and #members > 0 then
        -- Default to first member as fallback
        targetUnit = members[1].unitid

        -- Try to find someone valid and in range (generic check) to avoid casting on self if target is OOR
        for _, playerInfo in ipairs(members) do
             local isPlayer = (playerInfo.unitid == "player")
             if playerInfo.isOnline and not playerInfo.isDead and (isPlayer or (UnitIsVisible(playerInfo.unitid) and UnitInRange(playerInfo.unitid))) then
                targetUnit = playerInfo.unitid
                break
             end
        end
    end

    -- Smart buffs for the group button itself (attributes can only change out of combat)
    if not InCombatLockdown() then
        local leftSpell, leftUnit, rightSpell, rightUnit = self:GetSmartBuffsForGroup(groupNum, targetUnit)
        button:SetAttribute("type1", leftSpell and "spell" or nil)
        button:SetAttribute("spell1", leftSpell)
        button:SetAttribute("unit1", leftUnit)
        button:SetAttribute("type2", rightSpell and "spell" or nil)
        button:SetAttribute("spell2", rightSpell)
        button:SetAttribute("unit2", rightUnit)
    end

    -- Collect valid icons for correct right-to-left positioning
    local validIcons = {}

    for buffKey, icon in pairs(button.buffIcons) do
        -- Show the icon if ANY member of this group should get this buff (class assignment OR player override)
        local shouldShowIcon = false
        if members then
             for _, playerInfo in ipairs(members) do
                if self:ShouldBuffUnit(buffKey, playerInfo.name, playerInfo.classFilename) then
                    shouldShowIcon = true
                    break
                end
             end
        end

        if self.availableBuffs[buffKey] and shouldShowIcon then
            -- Update attributes (only outside combat)
            if not InCombatLockdown() then
                icon:SetParent(button)
                icon:SetFrameLevel(button:GetFrameLevel() + 1)

                local buffData = BuffPower_Spells[self.playerClass][buffKey]
                local groupKnown = buffData.group and buffData.group.isKnown
                if groupKnown then
                    icon:SetAttribute("spell1", buffData.group.name)
                    -- Group buff targeting: first member of the group
                    if targetUnit then
                        icon:SetAttribute("unit1", targetUnit)
                    end
                else
                    -- No group buff known, so left click behaves like right click (smart single target)
                    icon:SetAttribute("spell1", buffData.single.name)
                end
                icon:SetAttribute("spell2", buffData.single.name)

                -- Right-click unit: the first assigned member missing this buff, else the one expiring soonest.
                -- Range nil means unknown (e.g. spell not on the action bar), so it counts as in range.
                local missingUnit = nil
                local soonestExpires = math.huge
                for _, playerInfo in ipairs(members) do
                    local mStatus = groupStatus.memberStatus[playerInfo.unitid]
                    local bStatus = mStatus and mStatus.buffStatus[buffKey]
                    if bStatus and self:ShouldBuffUnit(buffKey, playerInfo.name, playerInfo.classFilename)
                        and IsSpellInRange(buffData.single.name, playerInfo.unitid) ~= 0 then
                        if not bStatus.hasBuff then
                            missingUnit = playerInfo.unitid
                            break -- Prioritize completely missing buffs
                        elseif bStatus.expires < soonestExpires then
                            soonestExpires = bStatus.expires
                            missingUnit = playerInfo.unitid
                        end
                    end
                end

                -- If everyone has it, fall back to the group target so a rebuff is still possible
                local unit2 = missingUnit or targetUnit
                if unit2 then
                    icon:SetAttribute("unit2", unit2)
                    if not groupKnown then
                        icon:SetAttribute("unit1", unit2)
                    end
                end
            end

            tinsert(validIcons, {key = buffKey, icon = icon})
        else
            icon:Hide()
        end
    end

    -- Position icons right-aligned: [Icon 1][Icon 2][Icon 3]| with a 24px step (18px icon + 6px gap)
    local numIcons = #validIcons
    for i, item in ipairs(validIcons) do
        local icon = item.icon

        if not InCombatLockdown() then
            icon:ClearAllPoints()
            icon:SetPoint("RIGHT", button, "RIGHT", -6 - ((numIcons - i) * ICON_SPACING), 0)
        end

        icon:Show()

        -- Refresh tooltip if mouse is over to update target names immediately
        if icon:IsMouseOver() then
            self:BuffIcon_OnEnter(icon)
        end

        local counts = groupStatus.buffCounts[item.key]
        Tint(icon, not (counts and counts.needed > 0))
    end
end

-- Safe version that only updates text/colors (can run in combat)
function BuffPower:UpdateGroupButtonDisplay(button, groupNum)
    local groupStatus = self.groupBuffStatus[groupNum]
    if not groupStatus then return end

    for buffKey, icon in pairs(button.buffIcons) do
        if icon:IsShown() then
            local counts = groupStatus.buffCounts[buffKey]
            Tint(icon, not (counts and counts.needed > 0))
            if counts and counts.buffed > 0 then
                icon.timer:SetText(self:FormatTimeCompact(counts.minExpires - GetTime()))
            else
                icon.timer:SetText("")
            end
        end
    end

    -- Green when all buffed, red when buffs are needed
    button:SetBackdropColor(unpack(groupStatus.allBuffed and COLORS.buffed or COLORS.missing))
end

-- Safe version that only updates text/colors for player buttons (can run in combat)
function BuffPower:UpdatePlayerButtonDisplay(playerButton, playerInfo, groupNum)
    local memberStatus = self.groupBuffStatus[groupNum]
    memberStatus = memberStatus and memberStatus.memberStatus[playerInfo.unitid]

    for buffKey, icon in pairs(playerButton.buffIcons) do
        if icon:IsShown() then
            local buffStatus = memberStatus and memberStatus.buffStatus[buffKey]
            local hasBuff = buffStatus and buffStatus.hasBuff
            Tint(icon, hasBuff)
            if hasBuff then
                icon.timer:SetText(self:FormatTimeCompact(buffStatus.expires - GetTime()))
            else
                icon.timer:SetText("")
            end
        end
    end

    -- Update backdrop color based on needs (safe in combat) - match group button colors
    local color = COLORS.buffed
    if not playerInfo.isOnline or playerInfo.isDead then
        color = COLORS.inactive
    elseif memberStatus and memberStatus.needsAny then
        color = COLORS.missing
    end

    -- Check range logic
    local inRange = true
    if playerInfo.unitid then
        if self.rangeSpell then
            -- nil means unknown (e.g. spell not on action bar), so we treat it as in range
            inRange = (IsSpellInRange(self.rangeSpell, playerInfo.unitid) ~= 0)
        end
        -- Also check visibility (if not visible, definitely out of range)
        local isPlayer = (playerInfo.unitid == "player")
        if not isPlayer and not UnitIsVisible(playerInfo.unitid) then
            inRange = false
        end
    end

    if not inRange then
        playerButton:SetAlpha(0.4)
    else
        playerButton:SetAlpha(1.0)
    end

    playerButton:SetBackdropColor(unpack(color))
end

-------------------------------------------------------------------
-- Button Event Handlers
-------------------------------------------------------------------
function BuffPower:GroupButton_OnEnter(button)
    local groupNum = button.groupNum
    local members = self.raidComposition[groupNum]
    if not members or #members == 0 then return end

    -- In combat, secure handler shows player buttons via _onenter attribute
    -- Outside combat, we handle it manually for more control
    if not InCombatLockdown() then
        -- Show player buttons at a fixed size
        local buttonHeight = 38
        local offsetX = button:GetWidth() + 2

        for i, playerInfo in ipairs(members) do
            if i <= BUFFPOWER_CONSTANTS.MAX_PLAYERS_PER_GROUP then
                local playerButton = self.playerButtons[groupNum][i]
                if playerButton then
                    playerButton:SetSize(self.opt.playerButtonWidth, buttonHeight)
                    playerButton:ClearAllPoints()
                    -- Use clean spacing (2px gap to avoid overlap and borders merging)
                    -- 38px height + 2px gap = 40px stride
                    playerButton:SetPoint("TOPLEFT", button, "TOPLEFT", offsetX, -((i - 1) * (buttonHeight + 2)))

                    -- Update player info
                    self:UpdatePlayerButton(playerButton, playerInfo, groupNum)
                    playerButton:Show()
                end
            end
        end

        -- Hide unused player buttons
        for i = #members + 1, BUFFPOWER_CONSTANTS.MAX_PLAYERS_PER_GROUP do
            if self.playerButtons[groupNum] and self.playerButtons[groupNum][i] then
                self.playerButtons[groupNum][i]:Hide()
            end
        end
    end

    -- Tooltip (always show)
    if self.opt.ShowTooltips then
        local memberCount = 0
        for _, playerInfo in ipairs(members) do
            if not playerInfo.isPet or self.opt.ShowPets then
                memberCount = memberCount + 1
            end
        end

        -- Anchored left: the player list opens to the right of the group button
        GameTooltip:SetOwner(button, "ANCHOR_LEFT")
        GameTooltip:SetText("Group " .. groupNum)
        GameTooltip:AddLine(memberCount == 1 and "1 member" or memberCount .. " members", 1, 1, 1)
        GameTooltip:Show()
    end
end

-- Hide a group's player list 0.5s after the mouse leaves it, unless the mouse has
-- moved onto another part of the same group. Secure frames cannot hide in combat.
function BuffPower:HidePlayerButtonsLater(groupNum)
    C_Timer.After(0.5, function()
        if InCombatLockdown() or self:IsMouseOverGroup(groupNum) then return end
        for _, playerButton in pairs(self.playerButtons[groupNum]) do
            playerButton:Hide()
        end
    end)
end

function BuffPower:GroupButton_OnLeave(button)
    self:HidePlayerButtonsLater(button.groupNum)
    GameTooltip:Hide()
end

function BuffPower:IsMouseOverGroup(groupNum)
    local button = self.groupButtons[groupNum]
    if button and button:IsMouseOver() then return true end

    for i = 1, BUFFPOWER_CONSTANTS.MAX_PLAYERS_PER_GROUP do
        local playerButton = self.playerButtons[groupNum] and self.playerButtons[groupNum][i]
        if playerButton and playerButton:IsShown() and playerButton:IsMouseOver() then
            return true
        end
        -- Also check if mouse is over any icons inside the player button (since they extend out)
        if playerButton then
             for _, icon in pairs(playerButton.buffIcons) do
                 if icon and icon:IsShown() and icon:IsMouseOver() then
                     return true
                 end
             end
        end
    end

    return false
end

function BuffPower:UpdatePlayerButton(button, playerInfo, groupNum)
    -- Set player name with class color
    local classColor = RAID_CLASS_COLORS[playerInfo.classFilename]
    if classColor then
        button.playerName:SetTextColor(classColor.r, classColor.g, classColor.b)
    else
        button.playerName:SetTextColor(1, 1, 1)
    end

    local displayName = Ambiguate(playerInfo.name, "short")
    -- On WoW Forever names are "First Last"; elsewhere a character name never contains a space
    if self.opt.FirstNamesOnly and not playerInfo.isPet then
        displayName = displayName:match("^[^ ]+") or displayName
    end
    if playerInfo.isPet then
        displayName = "|T132242:0|t " .. displayName
    end
    button.playerName:SetText(displayName)

    -- Store unit info
    button.unitid = playerInfo.unitid
    button.playerInfo = playerInfo
    button.groupNum = groupNum

    self:UpdatePlayerBuffIcons(button, playerInfo)

    -- Update visual state (colors, alpha, range)
    self:UpdatePlayerButtonDisplay(button, playerInfo, groupNum)
end

function BuffPower:UpdatePlayerBuffIcons(playerButton, playerInfo)
    if InCombatLockdown() then return end  -- Can't modify secure attributes in combat

    local memberStatus = self.groupBuffStatus[playerButton.groupNum]
    memberStatus = memberStatus and memberStatus.memberStatus[playerInfo.unitid]

    -- Collect valid icons first for right-alignment calculation
    local validIcons = {}
    for buffKey, icon in pairs(playerButton.buffIcons) do
        -- Check if buff is available (player has the spell)
        -- AND if we should buff this class (based on assignments)
        -- AND check individual player assignments
        if self.availableBuffs[buffKey] and self:ShouldBuffUnit(buffKey, playerInfo.name, playerInfo.classFilename) then
            tinsert(validIcons, {key = buffKey, icon = icon})
        else
            icon:Hide()
        end
    end

    -- Position icons right-aligned to avoid overlapping with long names
    local numIcons = #validIcons

    -- The name gets all the width the shown icons leave free
    local nameRight = numIcons > 0 and -(6 + (numIcons - 1) * ICON_SPACING + ICON_SIZE + 6) or -5
    playerButton.playerName:SetPoint("RIGHT", playerButton, "RIGHT", nameRight, 0)
    for i, item in ipairs(validIcons) do
        local icon = item.icon
        local buffKey = item.key

        -- Position icon relative to player button (Right aligned)
        icon:ClearAllPoints()
        -- Right align: [Icon 1][Icon 2][Icon 3]|
        -- Icon 1 is at -(numIcons-1)*ICON_SPACING - pad
        -- Icon 3 is at -0*ICON_SPACING - pad
        local rightPadding = 6
        local xOffset = -rightPadding - ((numIcons - i) * ICON_SPACING)

        icon:SetPoint("RIGHT", playerButton, "RIGHT", xOffset, 0)
        icon:SetParent(playerButton)
        icon:SetFrameLevel(playerButton:GetFrameLevel() + 1)

        -- Update the unit target for this spell
        icon:SetAttribute("unit1", playerInfo.unitid)
        icon:SetAttribute("unit2", playerInfo.unitid)

        icon:Show()

        local buffStatus = memberStatus and memberStatus.buffStatus[buffKey]
        Tint(icon, buffStatus and buffStatus.hasBuff)
    end
end

function BuffPower:PlayerButton_OnEnter(button)
    if self.opt.ShowTooltips then
        GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
        -- The full name, including the last name the button may leave out
        GameTooltip:SetText(Ambiguate(button.playerInfo.name, "short"))
        GameTooltip:AddLine("Click buff icon to cast on this player.", 1, 1, 1, true)
        GameTooltip:AddLine("Scroll wheel to cycle buff assignment.", 1, 1, 1, true)
        GameTooltip:Show()
    end
end

function BuffPower:PlayerButton_OnLeave(button)
    GameTooltip:Hide()
    self:HidePlayerButtonsLater(button.groupNum)
end

function BuffPower:BuffIcon_OnEnter(icon)
    if self.opt.ShowTooltips then
        local buffData = BuffPower_Spells[self.playerClass][icon.buffKey]
        if buffData then
            GameTooltip:SetOwner(icon, "ANCHOR_RIGHT")
            if buffData.group then
                GameTooltip:SetText(buffData.group.name)
                GameTooltip:AddLine("Left-click: Cast Group Buff", 0, 1, 0)
            else
                GameTooltip:SetText(buffData.single.name)
                GameTooltip:AddLine("Left-click: Cast Single Buff (Smart)", 0, 1, 0)
                local unit1 = icon:GetAttribute("unit1")
                if unit1 then
                    GameTooltip:AddLine("Target: " .. GetUnitName(unit1, true), 1, 1, 1)
                end
            end

            local unit2 = icon:GetAttribute("unit2")
            GameTooltip:AddLine("Right-click: Cast Single Buff", 0, 1, 0)
            if unit2 then
                GameTooltip:AddLine("Target: " .. GetUnitName(unit2, true), 1, 1, 1)
            end
            GameTooltip:Show()
        end
    end
end

function BuffPower:PlayerBuffIcon_OnEnter(icon)
    if self.opt.ShowTooltips then
        local buffData = BuffPower_Spells[self.playerClass][icon.buffKey]
        if buffData and buffData.single then
            GameTooltip:SetOwner(icon, "ANCHOR_RIGHT")
            GameTooltip:SetText(buffData.single.name)
            GameTooltip:AddLine("Left/Right-click to cast on this player", 1, 1, 1)
            GameTooltip:Show()
        end
    end
end

-------------------------------------------------------------------
-- Minimap Icon
-------------------------------------------------------------------
function BuffPower:SetupMinimapIcon()
    local LDB = LibStub("LibDataBroker-1.1", true)
    local LDBIcon = LibStub("LibDBIcon-1.0", true)

    if LDB and LDBIcon then
        local dataObj = LDB:NewDataObject("BuffPower", {
            type = "data source",
            text = "BuffPower",
            icon = "Interface\\AddOns\\BuffPower\\Icons\\icon",
            OnTooltipShow = function(tooltip)
                tooltip:SetText("BuffPower")
                tooltip:AddLine("|cffeda55fClick|r to toggle main window.\n|cffeda55fRight-Click|r to open options.", 1, 1, 1, true)
                tooltip:Show()
            end,
            OnClick = function(_, button)
                if button == "LeftButton" then
                    BuffPower:SlashCommand("")
                else
                    BuffPower:OpenConfigWindow()
                end
            end,
        })

        LDBIcon:Register("BuffPower", dataObj, self.opt.minimap)

        if self.opt.minimap.hide then
            LDBIcon:Hide("BuffPower")
        else
            LDBIcon:Show("BuffPower")
        end
    end
end

-------------------------------------------------------------------
-- Utility Functions
-------------------------------------------------------------------
function BuffPower:FormatTimeCompact(seconds)
    if not seconds or seconds < 0 or seconds >= 99999 then return "" end

    if seconds >= 3600 then
        return format("%dh", math.ceil(seconds / 3600))
    elseif seconds >= 60 then
        return format("%dm", math.ceil(seconds / 60))
    else
        return format("%ds", seconds)
    end
end

-------------------------------------------------------------------
-- Debug
-------------------------------------------------------------------
function BuffPower:Debug(msg)
    if self.opt and self.opt.debug then
        self:Print("|cffff00ff[Debug]|r " .. tostring(msg))
    end
end
