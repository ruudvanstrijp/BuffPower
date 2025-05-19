# BuffPower Addon - Design & Implementation Plan (Comprehensive V3)

## 1. Introduction & Goals

### 1.1. Overview
BuffPower is a World of Warcraft addon designed to assist Mages, Priests, and Druids in managing their group and single-target buffs. It draws inspiration from PallyPower's UI aesthetic and Ace3 framework usage but implements a core paradigm shift from class-based to raid group-based assignments. This version includes enhanced direct buff control via multiple clickable icons and a prioritized cycle-click system.

### 1.2. Target Audience & Classes
* **Mage:** Arcane Intellect / Arcane Brilliance
* **Priest:** Power Word: Fortitude / Prayer of Fortitude, Divine Spirit / Prayer of Spirit, Shadow Protection / Prayer of Shadow Protection
* **Druid:** Mark of the Wild / Gift of the Wild, Thorns

### 1.3. Core Design Shift: Class-based to Group-based UI
The fundamental change is the main display: BuffPower will feature buttons for each of the 8 raid groups. Mouse-over a group button will reveal its members for targeted buffing.

### 1.4. Key Features
* Group-centric main display (Groups 1-8).
* Mouse-over group to see members with buff status.
* **Enhanced Interaction:**
    * Display of all applicable, castable *group buff icons* directly on each group header (e.g., Prayer of Fortitude, Prayer of Spirit for Priests). Clicking a specific icon casts that group buff.
    * Display of all applicable, castable *single-target buff icons* directly on each player button (e.g., Power Word: Fortitude, Divine Spirit, Thorns for Druids). Clicking a specific icon casts that single-target buff.
    * Clicking the general area of a group header cycles through applying *needed group buffs* in a prioritized order.
    * Clicking the general area of a player button cycles through applying *needed single-target buffs* in a prioritized order.
* UI styling inspired by PallyPower's button appearance and information density.
* Configurable options window to enable/disable buffs per target class (this determines "need").
* Dynamic buff eligibility based on target class and caster's talents/spell knowledge.
* Support for optional buffs.
* Syncing of group responsibilities between BuffPower users.

### 1.5. Development Principles
* **DRY (Don't Repeat Yourself):** Utilize functions, templates, and shared logic.
* **KISS (Keep It Simple, Stupid):** Focus on clear, maintainable code.
* **Purposeful Integration:** Selectively use elements from PallyPower (located in `Addons/BuffPower/PallyPower/`) as a reference for styling, Ace3 patterns, and API examples. Build BuffPower's logic tailored to its specific design.
* **WoW Classic API Focus:** Utilize appropriate API functions for Classic-era WoW.

## 2. Project Foundation & Initial Setup

### 2.1. Setting Up the BuffPower Environment
* **Action:** Ensure the main addon directory `Addons/BuffPower/` exists.
* **Action (`BuffPower.toc`):** Create a new `BuffPower.toc` file in the `Addons/BuffPower/` directory.
    * Define essential metadata:
        ```toc
        ## Interface: 11503 ## Or your target WoW Classic/WotLK Classic version number
        ## Title: BuffPower
        ## Author: YourName
        ## Version: 0.1.0
        ## Notes: Manages Mage, Priest, and Druid buffs for raid groups with enhanced control.
        ## SavedVariables: BuffPowerDB
        ## X-Category: Raid
        ## X-Curse-Project-ID: ## Optional: For CurseForge
        ## X-WoWI-ID: ## Optional: For WoWInterface
        ```
    * List core files as they are created:
        ```toc
        # Libraries
        embeds.xml

        # Core Logic
        BuffPowerValues.lua
        BuffPower.lua

        # UI Definition
        BuffPower.xml

        # Options
        BuffPowerOptions.lua

        # Localization
        Locales\enUS.lua
        # Locales\deDE.lua ## etc.
        ```
    * *Reference:* Look at `Addons/BuffPower/PallyPower/PallyPower.toc` for structure and standard Ace3 library listings if needed, but tailor content for BuffPower.
* **Action (Libraries `/Libs/`):**
    * Copy the *entire* `Addons/BuffPower/PallyPower/Libs/` folder to `Addons/BuffPower/Libs/`. Libraries are generally self-contained and reusable.
* **Action (`embeds.xml`):**
    * Create `Addons/BuffPower/embeds.xml`.
    * *Reference:* Copy the content from `Addons/BuffPower/PallyPower/embeds.xml`. This file typically lists XML files for each library to load them.
    * **Verify paths:** Ensure all `<Include file="Libs\\AceAddon-3.0\\AceAddon-3.0.xml"/>` (or similar) paths correctly point to the libraries within `Addons/BuffPower/Libs/`. Adjust backslashes to forward slashes (`Libs/AceAddon-3.0/AceAddon-3.0.xml`) if WoW prefers that format (it's usually flexible).

### 2.2. Establishing Core Lua Files (Selective Adaptation & New Creation)

* **File: `BuffPowerValues.lua`**
    * **Action:** Create `Addons/BuffPower/BuffPowerValues.lua`.
    * **Content:**
        * Define `BUFFPOWER_CONSTANTS`:
            ```lua
            BUFFPOWER_CONSTANTS = {
                MAX_RAID_GROUPS = 8,
                MAX_PLAYERS_PER_GROUP_DISPLAY = 5, -- Max players shown on mouseover a group
            }
            ```
        * Define `BuffPower_Spells` (ensure spell IDs are for the target WoW version, e.g., WotLK Classic):
            ```lua
            -- Use GetSpellInfo(spellID) for name and GetSpellTexture(spellID) for icon if preferred for runtime accuracy/localization
            BuffPower_Spells = {
                MAGE = {
                    intellect = {
                        id = "MAGE_INTELLECT",
                        single = { spellID = 1459, name = "Arcane Intellect", icon = "Interface\\Icons\\Spell_Holy_ArcaneIntellect" },
                        group = { spellID = 27127, name = "Arcane Brilliance", icon = "Interface\\Icons\\Spell_Holy_ArcaneIntellect" } -- WotLK Rank 2 ID
                    }
                },
                PRIEST = {
                    fortitude = {
                        id = "PRIEST_FORTITUDE",
                        single = { spellID = 1243, name = "Power Word: Fortitude", icon = "Interface\\Icons\\Spell_Holy_WordFortitude" },
                        group = { spellID = 25389, name = "Prayer of Fortitude", icon = "Interface\\Icons\\Spell_Holy_PrayerOfFortitude" } -- WotLK Rank 3 ID
                    },
                    spirit = {
                        id = "PRIEST_SPIRIT",
                        single = { spellID = 14752, name = "Divine Spirit", icon = "Interface\\Icons\\Spell_Holy_DivineSpirit" },
                        group = { spellID = 27841, name = "Prayer of Spirit", icon = "Interface\\Icons\\Spell_Holy_PrayerOfSpirit" }, -- WotLK Rank 1 ID
                        talentRequired = 14777 -- Talent ID for Divine Spirit (Discipline tree) - Verify ID for WotLK
                    },
                    shadow_protection = {
                        id = "PRIEST_SHADOW_PROTECTION",
                        single = { spellID = 976, name = "Shadow Protection", icon = "Interface\\Icons\\Spell_Shadow_ShadowProtection" },
                        group = { spellID = 27683, name = "Prayer of Shadow Protection", icon = "Interface\\Icons\\Spell_Shadow_PrayerOfShadowProtection" }, -- WotLK Rank 1 ID
                        optional = true
                    }
                },
                DRUID = {
                    wild = {
                        id = "DRUID_WILD",
                        single = { spellID = 1126, name = "Mark of the Wild", icon = "Interface\\Icons\\Spell_Nature_Regeneration" },
                        group = { spellID = 26992, name = "Gift of the Wild", icon = "Interface\\Icons\\Spell_Nature_Regeneration" } -- WotLK Rank 2 ID
                    },
                    thorns = {
                        id = "DRUID_THORNS",
                        single = { spellID = 467, name = "Thorns", icon = "Interface\\Icons\\Spell_Nature_Thorns" },
                        group = nil, -- Thorns is single-target only
                        optional = true
                    }
                }
            }
            ```
        * Define `BuffPower_ClassKeys` and `BuffPower_ClassColors`:
            ```lua
            BuffPower_ClassKeys = {
                WARRIOR = "WARRIOR", MAGE = "MAGE", PRIEST = "PRIEST", DRUID = "DRUID",
                ROGUE = "ROGUE", HUNTER = "HUNTER", WARLOCK = "WARLOCK",
                PALADIN = "PALADIN", SHAMAN = "SHAMAN", DEATHKNIGHT = "DEATHKNIGHT", PET = "PET"
            }
            BuffPower_ClassColors = RAID_CLASS_COLORS -- Standard WoW global
            ```
        * Define `BUFFPOWER_DEFAULT_VALUES` for AceDB-3.0:
            ```lua
            BUFFPOWER_DEFAULT_VALUES = {
                profile = {
                    framePosition = { x = 100, y = -200 },
                    locked = false,
                    scale = 1.0,
                    assignments = {}, -- { [buffKey] = { [targetClassKey] = true/false } }
                    optionalBuffsEnabled = {}, -- { [buffKey] = true/false }
                    myResponsibleGroups = {}, -- { [groupNum] = true/false }
                }
            }
            ```
        * Define `BuffPower_BuffPriority`:
            ```lua
            BuffPower_BuffPriority = {
                PRIEST = {
                    group = { "PRIEST_FORTITUDE", "PRIEST_SPIRIT", "PRIEST_SHADOW_PROTECTION" },
                    single = { "PRIEST_FORTITUDE", "PRIEST_SPIRIT", "PRIEST_SHADOW_PROTECTION" }
                },
                MAGE = {
                    group = { "MAGE_INTELLECT" },
                    single = { "MAGE_INTELLECT" }
                },
                DRUID = {
                    group = { "DRUID_WILD" },
                    single = { "DRUID_WILD", "DRUID_THORNS" }
                }
            }
            ```
    * *Reference:* `Addons/BuffPower/PallyPower/PallyPowerValues.lua` for organizational ideas, but data is BuffPower-specific.

* **File: `BuffPower.lua` (Main Logic)**
    * **Action:** Create `Addons/BuffPower/BuffPower.lua`.
    * **Content:**
        * Implement Ace3 addon boilerplate:
            ```lua
            local addonName, addon = ... -- Uses the folder name for addonName if TOC Title is simple
            if addonName ~= "BuffPower" then LibStub("AceAddon-3.0"):NewAddon(addonName, "BuffPower", "AceConsole-3.0", "AceEvent-3.0", "AceTimer-3.0") end -- Allow for manual naming
            local BuffPower = LibStub("AceAddon-3.0"):GetAddon("BuffPower")
            BuffPower.db = nil -- AceDB-3.0 will initialize this
            BuffPower.playerClass = nil
            BuffPower.availableBuffs = {} -- { [buffKey] = true/false }
            BuffPower.raidComposition = {} -- { [groupNum] = { playerInfo1, ... } }
            BuffPower.syncedResponsibilities = {} -- { [playerName] = { [groupNum]=true } }

            function BuffPower:OnInitialize()
                self.db = LibStub("AceDB-3.0"):New("BuffPowerDB", BUFFPOWER_DEFAULT_VALUES, true) -- true for per-character by default
                -- Slash command registration
                self:RegisterChatCommand("bp", "SlashCmdHandler")
                self:RegisterChatCommand("buffpower", "SlashCmdHandler")
                -- Further initialization
                self:SetupFrames() -- Placeholder for UI creation
            end

            function BuffPower:OnEnable()
                local _, englishClass = UnitClass("player")
                self.playerClass = englishClass
                if not BuffPower_Spells[self.playerClass] then
                    self:Print("BuffPower is designed for Mages, Priests, and Druids.")
                    -- self:Disable() -- Consider if disabling is appropriate or just no functionality
                    return
                end

                self:ScanPlayerBuffsAndTalents()
                self:RegisterEvent("GROUP_ROSTER_UPDATE", "FullUpdate")
                self:RegisterEvent("PLAYER_ENTERING_WORLD", "HandlePlayerEnteringWorld")
                self:RegisterEvent("UNIT_AURA", "HandleUnitAura")
                self:RegisterEvent("SPELLS_CHANGED", "ScanPlayerBuffsAndTalents") -- Recheck known spells
                self:RegisterEvent("PLAYER_TALENT_UPDATE", "HandleTalentUpdate") -- Recheck talents

                self:UpdateRoster() -- Initial roster scan
                self:UpdateLayout() -- Initial UI draw
                self:Print(addonName .. " enabled.")
            end

            function BuffPower:OnDisable()
                self:UnregisterAllEvents()
                self:Print(addonName .. " disabled.")
            end

            function BuffPower:SlashCmdHandler(input)
                if not input or input == "" then
                    -- Toggle main frame or open options
                    if BuffPowerFrame and BuffPowerFrame:IsShown() then BuffPowerFrame:Hide() else BuffPowerFrame:Show() end
                elseif input == "options" or input == "config" then
                    LibStub("AceConfigDialog-3.0"):Open("BuffPower") -- Ensure correct options name
                else
                    self:Print("Usage: /bp [options|config]")
                end
            end
            -- Other core functions will be defined below (ScanPlayerBuffsAndTalents, UpdateRoster, UpdateLayout, NeedsBuff, etc.)
            ```
        * Implement BuffPower-specific logic as defined in subsequent sections (player class detection, spell/talent scanning, event registration, UI creation, roster management, buff logic).
    * *Reference:* `Addons/BuffPower/PallyPower/PallyPower.lua` for Ace3 setup, slash command examples, event registration patterns, and generic utility functions.

* **File: `BuffPowerOptions.lua` (Configuration)**
    * **Action:** Create `Addons/BuffPower/BuffPowerOptions.lua`.
    * **Content:**
        * Implement AceConfig-3.0 options table registration boilerplate:
            ```lua
            local addonName = "BuffPower" -- Or get it from BuffPower object
            local L = LibStub("AceLocale-3.0"):GetLocale(addonName) -- Assuming locales are set up

            local function getOptions()
                local options = {
                    name = L["BuffPower Options"] or addonName, -- Use localized name
                    handler = BuffPower, -- Assumes BuffPower object has getter/setter methods or refers to db
                    type = "group",
                    args = {
                        general = {
                            type = "group", name = L["General Settings"], order = 1,
                            args = {
                                locked = { type = "toggle", name = L["Lock Frame Position"], order = 1, get = function(info) return BuffPower.db.profile.locked end, set = function(info, val) BuffPower.db.profile.locked = val; BuffPower:LockUnlockFrame() end },
                                scale = { type = "range", name = L["Frame Scale"], order = 2, min = 0.5, max = 2, step = 0.05, get = function(info) return BuffPower.db.profile.scale end, set = function(info, val) BuffPower.db.profile.scale = val; BuffPower:ScaleFrame() end },
                                -- Add profile options if using AceDB-3.0 profiles
                            }
                        },
                        assignments = {
                            type = "group", name = L["Buff Assignments"], order = 2, guiInline = true, args = { /* To be populated by a function */ }
                        },
                        optionalBuffs = {
                            type = "group", name = L["Optional Buffs"], order = 3, args = { /* To be populated */ }
                        }
                        -- Add other options groups as needed
                    }
                }
                -- Dynamically populate assignments grid and optional buffs
                BuffPower:PopulateOptionsAssignments(options.args.assignments.args)
                BuffPower:PopulateOptionsOptionalBuffs(options.args.optionalBuffs.args)
                return options
            end

            function BuffPower:SetupOptions()
                LibStub("AceConfig-3.0"):RegisterOptionsTable("BuffPower", getOptions) -- Main options table
                self.optionsFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("BuffPower", addonName)
                -- For slash command access to specific sub-tables if needed later:
                -- LibStub("AceConfigCmd-3.0"):HandleCommand("/bp", "BuffPower", "BuffPower")
            end
            ```
        * Design and implement the Buff Assignment Grid and Optional Buff Toggles as detailed in Section 4.3.
    * *Reference:* `Addons/BuffPower/PallyPower/PallyPowerOptions.lua` for AceConfig setup patterns.

### 2.3. Localization Setup
* **Action:** Create directory `Addons/BuffPower/Locales/`.
* **File: `Locales/enUS.lua`** (don't implement any other languages yet)
    * **Action:** Create this file.
    * **Content:**
        ```lua
        -- Locale for enUS
        local L = LibStub("AceLocale-3.0"):NewLocale("BuffPower", "enUS", true) -- true makes it the default
        if not L then return end

        L["BuffPower Options"] = "BuffPower Options"
        L["General Settings"] = "General Settings"
        L["Lock Frame Position"] = "Lock Frame Position"
        L["Frame Scale"] = "Frame Scale"
        L["Buff Assignments"] = "Buff Assignments"
        L["Optional Buffs"] = "Optional Buffs"
        -- Add all other user-facing strings for BuffPower here.
        -- Example for dynamic options:
        -- L["PRIEST_FORTITUDE_NAME"] = BuffPower_Spells and BuffPower_Spells.PRIEST and BuffPower_Spells.PRIEST.fortitude.single.name or "Fortitude"
        ```
    * *Reference:* `Addons/BuffPower/PallyPower/Locales/` for AceLocale setup and string key examples.

## 3. UI Design & Implementation: Group-Based Display (Enhanced Interaction)

### 3.1. UI Styling Strategy: Learning from PallyPower
* **Analysis:** Carefully examine `Addons/BuffPower/PallyPower/PallyPower.xml` and any Lua code in `PallyPower.lua` related to UI creation, skinning, and styling (e.g., functions like `ApplySkin`, `ApplyBackdrop`, button creation).
    * Identify textures (border, background, gloss), border styles, fonts (name, size, outline), icon sizes, and the layout of text/icons on PallyPower's buttons.
* **Goal:** Understand *how* PallyPower achieves its look and feel, to replicate the *aesthetic* for BuffPower's components.

### 3.2. Building `BuffPower.xml` (Main UI Definition)
* **Action:** Create a new `Addons/BuffPower/BuffPower.xml` file.
* **Content:**
    * Define main addon frame, script handlers, and necessary templates:
    ```xml
    <Ui xmlns="[http://www.blizzard.com/wow/ui/](http://www.blizzard.com/wow/ui/)" xmlns:xsi="[http://www.w3.org/2001/XMLSchema-instance](http://www.w3.org/2001/XMLSchema-instance)" xsi:schemaLocation="[http://www.blizzard.com/wow/ui/](http://www.blizzard.com/wow/ui/)
    ..\FrameXML\UI.xsd">
        <Script file="BuffPower.lua"/> <Frame name="BuffPowerFrame" parent="UIParent" movable="true" enableMouse="true" ClampedToScreen="true" hidden="true">
            <Size x="200" y="400"/> <Anchors>
                <Anchor point="CENTER"/>
            </Anchors>
            <Backdrop bgFile="Interface\DialogFrame\UI-DialogBox-Background" edgeFile="Interface\DialogFrame\UI-DialogBox-Border" tile="true">
                <BackgroundInsets>
                    <AbsInset left="11" right="12" top="12" bottom="11"/>
                </BackgroundInsets>
                <TileSize>
                    <AbsValue val="32"/>
                </TileSize>
                <EdgeSize>
                    <AbsValue val="32"/>
                </EdgeSize>
            </Backdrop>
            <Layers>
                <Layer level="ARTWORK">
                    <FontString name="$parentTitle" inherits="GameFontNormal" text="BuffPower">
                        <Anchors>
                            <Anchor point="TOP" y="-6"/>
                        </Anchors>
                    </FontString>
                </Layer>
            </Layers>
            <Frames>
                </Frames>
            <Scripts>
                <OnLoad function="BuffPower.OnFrameLoad"/>
                <OnDragStart function="BuffPower.OnFrameDragStart"/>
                <OnDragStop function="BuffPower.OnFrameDragStop"/>
                <OnHide function="BuffPower.OnFrameHide"/>
            </Scripts>
        </Frame>

        <Button name="BuffPowerGroupButtonTemplate" virtual="true">
            <Size x="180" y="40"/> <Layers>
                <Layer level="BACKGROUND">
                    <Texture name="$parentBackground" parentKey="background">
                        <Color r="0.1" g="0.1" b="0.1" a="0.8"/>
                    </Texture>
                </Layer>
                <Layer level="BORDER">
                     <Texture name="$parentBorder" parentKey="border" file="Interface\Buttons\UI-Quickslot-Depress">
                        <TexCoords left="0" right="1" top="0" bottom="1"/>
                    </Texture>
                </Layer>
                <Layer level="ARTWORK">
                    <FontString name="$parentText" inherits="GameFontNormalSmall" parentKey="text" text="Group N">
                        <Anchors><Anchor point="LEFT" x="5" y="0"/></Anchors>
                    </FontString>
                </Layer>
            </Layers>
            <Frames>
                <Frame name="$parentIconContainer" parentKey="iconContainer"> <Anchors><Anchor point="RIGHT" relativePoint="LEFT" relativeKey="$parentText" x="0" y="0"/></Anchors>
                    <Size x="100" y="20"/> </Frame>
            </Frames>
            </Button>

        <Button name="BuffPowerPlayerButtonTemplate" virtual="true">
            <Size x="160" y="25"/> <Layers>
                <Layer level="BACKGROUND">
                    <Texture name="$parentBackground" parentKey="background">
                        <Color r="0.2" g="0.2" b="0.2" a="0.8"/>
                    </Texture>
                </Layer>
                <Layer level="BORDER">
                     <Texture name="$parentBorder" parentKey="border" file="Interface\Buttons\UI-Quickslot">
                        <TexCoords left="0" right="1" top="0" bottom="1"/>
                    </Texture>
                </Layer>
                <Layer level="ARTWORK">
                    <FontString name="$parentPlayerName" inherits="GameFontHighlightSmall" parentKey="playerName" text="Player Name">
                         <Anchors><Anchor point="LEFT" x="5" y="0"/></Anchors>
                    </FontString>
                    </Layer>
            </Layers>
             <Frames>
                <Frame name="$parentIconContainer" parentKey="iconContainer"> <Anchors><Anchor point="RIGHT" relativePoint="LEFT" relativeKey="$parentPlayerName" x="0" y="0"/></Anchors>
                    <Size x="100" y="20"/> </Frame>
            </Frames>
            </Button>

        <Button name="BuffPowerSmallBuffIconTemplate" virtual="true">
            <Size x="20" y="20"/>
            <Layers>
                <Layer level="BORDER">
                    <Texture name="$parentIcon" parentKey="icon"/>
                    <Texture name="$parentBorder" parentKey="border" file="Interface\Buttons\UI-Quickslot-Depress">
                         <TexCoords left="0" right="1" top="0" bottom="1"/>
                    </Texture>
                </Layer>
                <Layer level="OVERLAY">
                    <FontString name="$parentCooldown" inherits="GameFontNormalSmall" parentKey="cooldown" hidden="true">
                        <Anchors><Anchor point="CENTER"/></Anchors>
                    </FontString>
                    <Texture name="$parentShine" parentKey="shine" file="Interface\Cooldown\UISpellShine" alphaMode="ADD" hidden="true">
                         <Size x="20" y="20"/> <Anchors><Anchor point="CENTER"/></Anchors>
                    </Texture>
                </Layer>
            </Layers>
            </Button>
    </Ui>
    ```
    * Populate these templates by adapting styling attributes (textures, font objects, backdrop settings) found in PallyPower's XML templates. The *structure* of elements within these templates is tailored for BuffPower.

### 3.3. Group Button Design & Functionality - Enhanced
* In `BuffPower.lua` (`BuffPower:SetupFrames` or a dedicated `BuffPower:CreateGroupButtons` function):
    * Loop `i = 1, BUFFPOWER_CONSTANTS.MAX_RAID_GROUPS`.
    * Create `groupButton = CreateFrame("Button", "BuffPowerGroupButton"..i, BuffPowerFrame, "BuffPowerGroupButtonTemplate")`.
    * Set its position, text (`groupButton.text:SetText("Group "..i)`).
    * Store these buttons (e.g., `self.groupButtons[i] = groupButton`).
* **Display of Small Group Buff Icons:**
    * In `BuffPower:UpdateLayout` (or a dedicated `BuffPower:UpdateGroupButtonIcons(groupButton, groupNum)`):
        * Iterate through `BuffPower_Spells[self.playerClass]`.
        * For each buff that has a `.group` component and is in `self.availableBuffs`:
            * Create/reuse a small icon button from `BuffPowerSmallBuffIconTemplate` parented to `groupButton.iconContainer`.
            * Set its icon texture: `smallIcon.icon:SetTexture(buffDetails.group.icon)`.
            * Position these icons in a row.
            * Set `smallIcon:SetScript("OnClick", function() BuffPower:CastSpecificGroupBuff(buffKey, groupNum) end)`.
* **Interaction Logic (Lua):**
    * **Specific Icon Click Handler (`BuffPower:CastSpecificGroupBuff(buffKey, groupNum)`):**
        * `local spellDetails = BuffPower_Spells[self.playerClass][buffKey]`
        * `CastSpellByName(spellDetails.group.name)`
    * **General Area Click Script (set on `groupButton`):**
        ```lua
        groupButton:SetScript("OnClick", function(self, button)
            if button == "RightButton" then -- Or your chosen button for cycle
                BuffPower:CycleGroupBuffs(groupNum) -- groupNum needs to be accessible
            end
        end)
        ```
    * **`BuffPower:CycleGroupBuffs(groupNum)` Function:**
        1.  Iterate `buffKey` in `BuffPower_BuffPriority[self.playerClass].group`.
        2.  Check if group needs this buff: Iterate members in `self.raidComposition[groupNum]`. For each eligible member (`playerInfo`), if `self:NeedsBuff(playerInfo, buffKey)` is true, then the group needs it.
        3.  If needed, `local spellDetails = BuffPower_Spells[self.playerClass][buffKey]`, `CastSpellByName(spellDetails.group.name)`, then `return` (stop cycle).
* **Mouseover/Mouseout Logic (Lua, set on `groupButton`):**
    ```lua
    groupButton:SetScript("OnEnter", function(self) BuffPower:ShowPlayerButtonsForGroup(groupNum) end)
    groupButton:SetScript("OnLeave", function(self) BuffPower:HidePlayerButtonsForGroup(groupNum) end)
    ```

### 3.4. Player Button Design & Functionality (within Group Mouseover) - Enhanced
* In `BuffPower:ShowPlayerButtonsForGroup(groupNum)`:
    * Loop through `playerInfo` in `self.raidComposition[groupNum]`.
    * Create/reuse `playerButton = CreateFrame("Button", nil, BuffPowerFrame, "BuffPowerPlayerButtonTemplate")`. Make it visible and position it.
    * Set player name (`playerButton.playerName:SetText(playerInfo.name)`), class color.
    * Store `playerButton:SetAttribute("unit", playerInfo.unitid)`.
    * Call `BuffPower:UpdatePlayerButtonIcons(playerButton, playerInfo)`.
* **Display of Small Single-Target Buff Icons:**
    * In `BuffPower:UpdatePlayerButtonIcons(playerButton, playerInfo)`:
        * Iterate `buffKey` in `BuffPower_Spells[self.playerClass]`.
        * For each buff in `self.availableBuffs` and eligible for `playerInfo.classFilename` (from options):
            * Create/reuse a small icon from `BuffPowerSmallBuffIconTemplate` parented to `playerButton.iconContainer`.
            * Set texture: `smallIcon.icon:SetTexture(buffDetails.single.icon)`.
            * Position icons.
            * Set `smallIcon:SetScript("OnClick", function() BuffPower:CastSpecificSingleBuff(buffKey, playerInfo.unitid) end)`.
* **Interaction Logic (Lua):**
    * **Specific Icon Click Handler (`BuffPower:CastSpecificSingleBuff(buffKey, unitid)`):**
        * `local spellDetails = BuffPower_Spells[self.playerClass][buffKey]`
        * `CastSpellByName(spellDetails.single.name, unitid)`
    * **General Area Click Script (set on `playerButton`):**
        ```lua
        playerButton:SetScript("OnClick", function(self, button)
            if button == "RightButton" then -- Or your chosen button
                local unitid = self:GetAttribute("unit")
                BuffPower:CycleSingleTargetBuffs(unitid)
            end
        end)
        ```
    * **`BuffPower:CycleSingleTargetBuffs(unitid)` Function:**
        1.  `local playerInfo = BuffPower:GetPlayerInfoByUnitID(unitid)` (helper needed)
        2.  Iterate `buffKey` in `BuffPower_BuffPriority[self.playerClass].single`.
        3.  If `self:NeedsBuff(playerInfo, buffKey)` is true:
            * `local spellDetails = BuffPower_Spells[self.playerClass][buffKey]`
            * `CastSpellByName(spellDetails.single.name, unitid)`, then `return`.
* **Status Indicators:** In `BuffPower:UpdatePlayerButtonIcons` or a general update function, set visual cues (transparency, color) on `playerButton` for dead/offline/OOR states.
* **Attribute Storage:** `playerButton:SetAttribute("unit", playerInfo.unitid)` is crucial for click handlers.

### 3.5. Raid Roster Management (`BuffPower:UpdateRoster()` & `BuffPower:UpdateLayout()`)
* **`BuffPower:UpdateRoster()` Function (in `BuffPower.lua`):**
    * Called on `GROUP_ROSTER_UPDATE`, `PLAYER_ENTERING_WORLD`.
    * Clear `self.raidComposition`.
    * Loop `i = 1, GetNumGroupMembers()`.
    * For each member, use `GetRaidRosterInfo(raidIndex)` to get `name, rank, subgroup, level, class, fileName, zone, online, isDead, role, isML, combatRole`.
        * Ensure `fileName` (English class name) is used for internal keys. `subgroup` is 1-8.
    * Populate `self.raidComposition[subgroup]` with `playerInfo` objects containing these details and `unitid` (e.g., "raid"..`raidIndex`).
    * After updating `self.raidComposition`, call `self:FullUpdate()` (which might encompass `self:UpdateLayout()` and other checks).
* **`BuffPower:FullUpdate()` / `BuffPower:UpdateLayout()` Function:**
    * This is the main redraw handler.
    * Iterate `groupNum = 1, BUFFPOWER_CONSTANTS.MAX_RAID_GROUPS`.
    * Update visibility and text of each `self.groupButtons[groupNum]`.
    * Call `BuffPower:UpdateGroupButtonSlots(self.groupButtons[groupNum], groupNum)` to refresh its small buff icons.
    * If player buttons for a group are currently shown, iterate through them and call `BuffPower:UpdatePlayerButtonIcons()` for each.

### 3.6. Buff State Visualization (`BuffPower:UpdatePlayerButtonIcons()` & `BuffPower:UpdateGroupButtonSlots()`)
* **`BuffPower:UpdatePlayerButtonIcons(playerButton, playerInfo)` (enhanced from 3.4):**
    * For each small single-target buff icon displayed on `playerButton`:
        * Check `UnitAura(playerInfo.unitid, spellName, nil, "HELPFUL")` or iterate auras with `AuraUtil.FindAuraByName`.
        * If buff is active, update its icon with a timer (using cooldown frame logic on the small icon) or a visual "active" state.
        * If buff is missing but needed (from `NeedsBuff`), ensure icon reflects this (e.g., normal brightness).
        * If buff is not applicable/assigned, icon might be hidden or greyed out.
* **`BuffPower:UpdateGroupButtonSlots(groupButton, groupNum)` (enhanced from 3.3):**
    * For each small group buff icon on `groupButton`:
        * Determining if a *group* has a buff is tricky. Simplest: check a few key members (e.g., leader if in their group, or first few members of `self.raidComposition[groupNum]`).
        * Update icon's visual state (timer if found on a representative member, or just castable state).

## 4. Extended Buff Logic & Configuration

### 4.1. Talent Integration
* **`BuffPower:PlayerHasTalent(talentIdToCheck)` Function (in `BuffPower.lua`):**
    ```lua
    function BuffPower:PlayerHasTalent(talentIdToCheck)
        if not talentIdToCheck then return true end -- Assume available if no talent specified
        for tab = 1, GetNumTalentTabs() do
            for index = 1, GetNumTalents(tab) do
                -- name, iconTexture, pointsSpent, background, _, _, _, _, talentID
                local _, _, _, _, _, _, _, _, currentTalentId = GetTalentInfo(tab, index)
                if currentTalentId == talentIdToCheck and select(3, GetTalentInfo(tab, index)) > 0 then -- pointsSpent > 0
                    return true
                end
            end
        end
        return false
    end
    ```
* **`BuffPower:ScanPlayerBuffsAndTalents()` Function (in `BuffPower.lua`):**
    * Clear `self.availableBuffs`.
    * Iterate `buffKey, buffDetails in pairs(BuffPower_Spells[self.playerClass] or {})`.
    * Check `IsSpellKnown(buffDetails.single.spellID)` (or group spell if no single).
    * If spell known, check `self:PlayerHasTalent(buffDetails.talentRequired)`.
    * If all checks pass, `self.availableBuffs[buffKey] = true`.
    * Call this on enable and relevant events (`SPELLS_CHANGED`, `PLAYER_TALENT_UPDATE`).
    * After scan, trigger `self:FullUpdate()` if changes occurred.

### 4.2. Dynamic Buff Eligibility (`BuffPower:NeedsBuff(playerInfo, buffKey)`)
* **Function Signature:** `BuffPower:NeedsBuff(playerInfo, buffKey)` (in `BuffPower.lua`).
* **Logic:**
    1.  `local buffDetails = BuffPower_Spells[self.playerClass] and BuffPower_Spells[self.playerClass][buffKey]`
    2.  If not `buffDetails`, return `false`.
    3.  **Caster Capability:** If not `self.availableBuffs[buffKey]`, return `false`.
    4.  **Optional Buff Enabled:** If `buffDetails.optional` and not `self.db.profile.optionalBuffsEnabled[buffKey]`, return `false`.
    5.  **Assignment:**
        * `local targetClassKey = BuffPower_ClassKeys[playerInfo.classFilename]` (or `playerInfo.petType` if it's a pet).
        * If not `self.db.profile.assignments[buffKey]` or not `self.db.profile.assignments[buffKey][targetClassKey]`, return `false`.
    6.  **Target Specific Checks (e.g. Mana Users for Intellect):** Add any hardcoded class-specific logic if the assignment grid isn't granular enough (e.g., Spirit is generally not for Warriors/Rogues irrespective of assignment). This should ideally be handled by smart defaults in the assignment grid.
    7.  **Buff Presence Check:**
        * `local spellToCheck = buffDetails.single.name` (or `.group.name` if checking for a group context, though `NeedsBuff` is usually per-player).
        * Use `AuraUtil.FindAuraByName(playerInfo.unitid, spellToCheck, "HELPFUL")` or iterate auras.
        * If buff is found (check for any rank or stronger versions if applicable):
            * `local _, _, _, _, duration, expirationTime, source = UnitAura(...)`
            * If `source == "player"` (or from self) and `duration > 0` and `expirationTime - GetTime() > 30` (e.g., more than 30s left), return `false` (already buffed sufficiently). Adjust threshold as needed.
        * If buff not found or expires soon, return `true`.
* Return `true` if buff is needed, `false` otherwise.

### 4.3. Options Window (`BuffPowerOptions.lua` - Dynamic Population)
* **`BuffPower:PopulateOptionsAssignments(argsTable)` Function (in `BuffPower.lua` or `BuffPowerOptions.lua`):**
    * Called by `getOptions()` in `BuffPowerOptions.lua`.
    * Iterate `buffKey, buffDetails in pairs(BuffPower_Spells[self.playerClass] or {})`.
    * If not `self.availableBuffs[buffKey]`, skip.
    * Create a group for this buff: `argsTable[buffKey] = { type = "group", name = buffDetails.single.name, order = ..., inline = true, args = {} }`.
    * Inside this group, iterate `targetClassEnum, targetClassName` (e.g., from `PALLYPOWER_CLASSES` structure adapted for BuffPower, or `BuffPower_ClassKeys`).
    * Create a toggle: `argsTable[buffKey].args[targetClassEnum] = { type = "toggle", name = L[targetClassName] or targetClassName, image = buffDetails.single.icon, order = ..., get = get_func, set = set_func }`.
        * `get_func = function(info) return self.db.profile.assignments[buffKey] and self.db.profile.assignments[buffKey][targetClassEnum] end`
        * `set_func = function(info, value) self.db.profile.assignments[buffKey] = self.db.profile.assignments[buffKey] or {}; self.db.profile.assignments[buffKey][targetClassEnum] = value; self:FullUpdate() end`
* **`BuffPower:PopulateOptionsOptionalBuffs(argsTable)` Function:**
    * Iterate `buffKey, buffDetails in pairs(BuffPower_Spells[self.playerClass] or {})`.
    * If `buffDetails.optional` and `self.availableBuffs[buffKey]`:
        * Create a toggle: `argsTable[buffKey] = { type = "toggle", name = L["Enable"] .. " " .. buffDetails.single.name, order = ..., get = ..., set = ... }`.
        * Getter/setter for `self.db.profile.optionalBuffsEnabled[buffKey]`.

### 4.4. Linking Options to Core Logic
* The `BuffPower:NeedsBuff()` function (Section 4.2) already incorporates checks against `self.db.profile.assignments` and `self.db.profile.optionalBuffsEnabled`.
* UI update functions (`UpdatePlayerButtonIcons`, `UpdateGroupButtonSlots`) will use `NeedsBuff` to determine visual states (e.g., highlighting a needed buff's small icon).

## 5. Advanced Features & Sync

### 5.1. Main Window: Group-Level Buff Icons
* This is now integrated into Section 3.3 (Group Button Design) and 3.6 (`UpdateGroupButtonSlots`).

### 5.2. Group Responsibility Sync (AceComm-3.0)
* **Self-Assignment UI (in `BuffPower.lua`):**
    * Modify Group Button `OnClick` script: if Ctrl-Key + RightButton (or another combo) is pressed, toggle responsibility for that `groupNum`.
    * `self.db.profile.myResponsibleGroups[groupNum] = not self.db.profile.myResponsibleGroups[groupNum]`
    * Visually indicate responsibility on the group button (e.g., border highlight, small star icon).
    * Call `self:SendResponsibilityUpdate()`.
* **Data Storage:**
    * `self.db.profile.myResponsibleGroups = { [groupNum] = true/false, ... }`
    * `self.syncedResponsibilities = { [playerName] = { [groupNum] = true/false, ... }, ... }` (transient, populated by comms)
* **Communication (AceComm-3.0 - in `BuffPower.lua`):**
    * In `OnInitialize` or `OnEnable`: `self:RegisterComm("BUFFPOWERSYNC", "OnCommReceived")`
    * `function BuffPower:SendResponsibilityUpdate()`
        * `self:SendCommMessage("BUFFPOWERSYNC", self.db.profile.myResponsibleGroups, "RAID", nil)`
    * `function BuffPower:OnCommReceived(prefix, messageTable, distribution, sender)`
        * If `prefix == "BUFFPOWERSYNC"` and `sender ~= UnitName("player")`:
            * `self.syncedResponsibilities[sender] = messageTable` (ensure `messageTable` is a valid table).
            * `self:UpdateLayout()` to refresh UI with others' responsibilities (e.g., show names on group buttons).
    * On joining a raid or player entering world, potentially send an initial responsibility update.

## 6. Finalization & Polish

### 6.1. Localization
* **Action:** Ensure all user-facing strings in Lua and XML are wrapped in `L["StringKey"]` or retrieved via localization methods.
* **Action:** Populate `Locales/enUS.lua` (and other language files) with translations for all these keys.
* **Action:** Test the addon with different client locales to verify localization works.

### 6.2. Minimap Icon & LDB Integration
* **Action:** If PallyPower has LibDataBroker (LDB) or minimap icon code, adapt it. Otherwise, implement using AceDBIcon-1.0 and LibDataBroker-1.1.
* **LDB Object:**
    * Create an LDB data object: `local ldb = LibStub("LibDataBroker-1.1"):NewDataObject("BuffPower", { type = "launcher", label = "BuffPower", icon = "Interface\\Icons\\Spell_Holy_ArcaneIntellect", OnClick = function(self, button) ... end })`
    * `OnClick` function should toggle `BuffPowerFrame` or open options.
* **Minimap Icon (AceDBIcon):**
    * `LibStub("AceDBIcon-1.0"):Register("BuffPower", ldb, self.db.profile.minimap)` (assuming `minimap` settings in DB).
    * Provide options to show/hide minimap icon.

### 6.3. Comprehensive Testing Strategy - Amended
* **Class Combinations:** Test as Mage, Priest, and Druid.
* **Group Scenarios:** Test solo, in parties (5-man), and in various raid sizes (up to 8 full groups).
* **Functionality Checks:** All options, buff assignment grid, correct display and clickability of all small buff icons, cycle-click logic for group/player buttons, talent detection, group responsibility syncing.
* **New test cases from V2:**
    * Verify correct display of all applicable small buff icons on group and player buttons for each caster class.
    * Test click functionality of each individual small buff icon on groups and players.
    * Thoroughly test the cycle-click logic for both group and player buttons, ensuring correct priority and "needed" checks.
    * Verify UI responsiveness with multiple icons, especially during roster updates or combat.
* **Edge Cases:** Players joining/leaving raid, disconnecting/reconnecting, changing talents mid-session (requires re-scan), player pets, UI scaling, frame locking.

### 6.4. Code Quality & Documentation
* **Action:** Review all code for adherence to DRY/KISS principles.
* **Action:** Remove any commented-out old code or debug `print()` statements.
* **Action:** Add inline comments for complex algorithms, non-obvious logic, or critical sections. Use descriptive variable and function names.
* **Action:** Ensure consistent formatting and style.
* **Action:** Profile CPU usage if any performance concerns arise, particularly with frequent UI updates or roster scanning.

## 7. Future Considerations
* **Advanced Assignment Sync:** "Buffers can select the groups for which they are responsible and can assign others of the same class to groups." This would require a more complex sync system, potentially with roles (leader/member), a UI for assigning other players, and more robust conflict resolution for assignments. This is a significant feature extension beyond the current plan.
* **Buff Strength/Rank Awareness:** More sophisticated logic to understand if a target has a weaker/stronger version of a buff from another source.
* **Reagent Tracking:** Visual cues for reagents required by group buffs.
* **Customizable Buff Priority:** Allow users to re-order the `BuffPower_BuffPriority` via the options panel.