-- BuffPowerValues.lua
-- Stores static data for BuffPower

BuffPower = BuffPower or {}

-- I. Core Name and Branding Changes (Relevant parts for this file)
-- (Reflected in file name and table names)

-- II. Data Structure Modifications

-- 1. Class Definitions
BuffPower.ClassToID = {
    ["MAGE"]   = 1,
    ["PRIEST"] = 2,
    ["DRUID"]  = 3,
}

BuffPower.ClassID = {
    [1] = "MAGE",
    [2] = "PRIEST",
    [3] = "DRUID",
}

BuffPower.ClassRealNames = {
    ["MAGE"]   = "Mage",
    ["PRIEST"] = "Priest",
    ["DRUID"]  = "Druid",
}

BuffPower.ClassColors = {
    ["MAGE"]   = { r = 0.25, g = 0.78, b = 0.92, hex = "|cff3FC7EB" },
    ["PRIEST"] = { r = 1.0,  g = 1.0,  b = 1.0,  hex = "|cffFFFFFF" },
    ["DRUID"]  = { r = 1.0,  g = 0.49, b = 0.04, hex = "|cffFF7D0A" },
}

-- Icons for classes (example paths, replace with actual .tga or .blp)
BuffPower.ClassIcons = {
    ["MAGE"]   = "Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES_MAGE",
    ["PRIEST"] = "Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES_PRIEST",
    ["DRUID"]  = "Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES_DRUID",
}

-- General UI layout constants (used in profile/layout defaults)
BuffPower.BUTTON_RADIUS_DEFAULT = 70   -- Default distance of group buttons from the orb
BuffPower.BUTTON_ANGLE_OFFSET_DEFAULT = -90 -- Start buttons at the top (-90 degrees)

-- 2. Buff Definitions
-- NOTE: Replace SPELL_ID_X with actual Spell IDs and icon paths with correct ones.
BuffPower.MageBuffs = {
    name = "Arcane Intellect", -- Generic name for the buff type
    group_spell_name = "Arcane Brilliance",
    group_spell_id = 23028, -- Arcane Brilliance Rank 2 (Classic max)
    single_spell_name = "Arcane Intellect",
    single_spell_id = 10157, -- Arcane Intellect Rank 5 (Classic max)
    icon = "Interface\\Icons\\Spell_Holy_ArcaneIntellect", -- Main icon for this buff type
    group_icon = "Interface\\Icons\\Spell_Holy_ArcaneIntellect", -- Often same as single or specific group version
    single_icon = "Interface\\Icons\\Spell_Holy_ArcaneIntellect"
}

BuffPower.PriestBuffs = {
    name = "Power Word: Fortitude",
    group_spell_name = "Prayer of Fortitude",
    group_spell_id = 21564, -- Prayer of Fortitude Rank 2 (Classic max)
    single_spell_name = "Power Word: Fortitude",
    single_spell_id = 10938, -- Power Word: Fortitude Rank 6 (Classic max)
    icon = "Interface\\Icons\\Spell_Holy_WordFortitude",
    group_icon = "Interface\\Icons\\Spell_Holy_PrayerOfFortitude",
    single_icon = "Interface\\Icons\\Spell_Holy_WordFortitude"
}

BuffPower.DruidBuffs = {
    name = "Mark of the Wild",
    group_spell_name = "Gift of the Wild",
    group_spell_id = 21850, -- Gift of the Wild Rank 2 (Classic max)
    single_spell_name = "Mark of the Wild",
    single_spell_id = 9885, -- Mark of the Wild Rank 7 (Classic max)
    icon = "Interface\\Icons\\Spell_Nature_Regeneration",
    group_icon = "Interface\\Icons\\Spell_Nature_Regeneration", -- Often same or specific group version
    single_icon = "Interface\\Icons\\Spell_Nature_Regeneration"
}

-- Combined structure for easier access by class
BuffPower.ClassBuffInfo = {
    ["MAGE"]   = BuffPower.MageBuffs,
    ["PRIEST"] = BuffPower.PriestBuffs,
    ["DRUID"]  = BuffPower.DruidBuffs,
}

-- 3. Assignment Data Structure (Conceptual - actual data stored in BuffPowerDB)
-- BuffPowerDB.groupAssignments = {
--     [1] = { assigned_player_name = "PlayerMage", assigned_player_class = "MAGE", buff_type = "Arcane Intellect" }, -- Group 1
--     [2] = { assigned_player_name = "PlayerPriest", assigned_player_class = "PRIEST", buff_type = "Power Word: Fortitude" }, -- Group 2
--     -- etc. for up to 8 groups (raid) or fewer for party
-- }

-- Communication prefix
BuffPower.commPrefix = "BPWR" -- Updated from "PLPWR"

-- Default settings (can be overridden by BuffPowerDB)
BuffPower.defaults = {
    profile = {
        enabled = true,
        showWindow = true,
        showWindowForSolo = true, -- Show Group 1 even when solo!
        locked = false,
        scale = 1.0,
        position = { a1 = "CENTER", a2 = "CENTER", x = 0, y = 0 },
        assignments = {}, -- Will store group assignments: { [groupId] = {playerName = "", playerClass = ""} }
        classSettings = {
            MAGE = { enabled = true },
            PRIEST = { enabled = true },
            DRUID = { enabled = true },
        },
        showTooltips = true,
        showGroupMemberNames = true,
        smartBuff = true, -- Re-evaluate if this concept still applies well

        -- === BuffPower Enhancement Plan: UI and Color Defaults ===
        colors = {
            groupMissingBuff = {0.8, 0.2, 0.2, 0.7}, -- Red, used for group missing buff
            groupBuffed = {0.2, 0.8, 0.2, 0.7},      -- Green, used for group buffed
        },
        display = {
            buttonWidth   = 120,      -- Width of group buttons
            buttonHeight  = 28,       -- Height of group buttons
            buttonSpacing = 2,        -- Spacing between group buttons
            fontFace      = "GameFontNormalSmall", -- Default font, can be set to LSM3 font key
            fontSize      = 12,
            fontColor     = {1, 1, 1, 1}, -- Text color (white)
            borderColor   = {0.1, 0.1, 0.1, 1}, -- Near-black border
            borderTexture = "Interface\\ChatFrame\\ChatFrameBackground", -- Simple dark border texture
            edgeSize      = 1,
            backgroundColor = {0.12, 0.12, 0.12, 1}, -- Sleek dark background (fallback/default)
            timerFontSize = 12,       -- Size for timer text (group buff duration)
            playerListBackground = {0.15, 0.15, 0.15, 0.95}, -- Mouseover player frame bg
            playerListFontColor = {1, 1, 1, 1},
            playerListBorderColor = {0.1, 0.1, 0.1, 1},
            playerListFontSize = 11,
        }
        -- Add further fields as needed for expandability
    }
}

DEFAULT_CHAT_FRAME:AddMessage("BuffPowerValues.lua loaded")
if BuffPower and BuffPower.ClassBuffInfo then
    print("BuffPowerValues DEBUG (end of file): ClassBuffInfo keys:")
    for k,v in pairs(BuffPower.ClassBuffInfo) do print("  key:", k, "value:", v and "table" or "nil") end
else
    print("BuffPowerValues DEBUG (end of file): BuffPower.ClassBuffInfo is nil")
end
