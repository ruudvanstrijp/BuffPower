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

-- 2. Buff Definitions
-- NOTE: Replace SPELL_ID_X with actual Spell IDs and icon paths with correct ones.
BuffPower.MageBuffs = {
    name = "Arcane Intellect", -- Generic name for the buff type
    group_spell_name = "Arcane Brilliance",
    group_spell_id = 1459, -- Placeholder for Arcane Brilliance Spell ID
    single_spell_name = "Arcane Intellect",
    single_spell_id = 1461, -- Placeholder for Arcane Intellect Spell ID
    icon = "Interface\\Icons\\Spell_Holy_ArcaneIntellect", -- Main icon for this buff type
    group_icon = "Interface\\Icons\\Spell_Holy_ArcaneIntellect", -- Often same as single or specific group version
    single_icon = "Interface\\Icons\\Spell_Holy_ArcaneIntellect"
}

BuffPower.PriestBuffs = {
    name = "Power Word: Fortitude",
    group_spell_name = "Prayer of Fortitude",
    group_spell_id = 21562, -- Placeholder for Prayer of Fortitude Spell ID
    single_spell_name = "Power Word: Fortitude",
    single_spell_id = 21564, -- Placeholder for Power Word: Fortitude Spell ID
    icon = "Interface\\Icons\\Spell_Holy_WordFortitude",
    group_icon = "Interface\\Icons\\Spell_Holy_PrayerOfFortitude",
    single_icon = "Interface\\Icons\\Spell_Holy_WordFortitude"
}

BuffPower.DruidBuffs = {
    name = "Mark of the Wild",
    group_spell_name = "Gift of the Wild",
    group_spell_id = 21849, -- Placeholder for Gift of the Wild Spell ID
    single_spell_name = "Mark of the Wild",
    single_spell_id = 21850, -- Placeholder for Mark of the Wild Spell ID
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
    }
}

DEFAULT_CHAT_FRAME:AddMessage("BuffPowerValues.lua loaded")
