-- BuffPowerValues.lua
-- Author: Ruuddie
-- Constants, spell definitions, and default values for BuffPower

-------------------------------------------------------------------
-- Constants
-------------------------------------------------------------------
BUFFPOWER_CONSTANTS = {
    MAX_RAID_GROUPS = 8,
    MAX_PLAYERS_PER_GROUP = 10,  -- 5 players + up to 5 pets
}

-- Class display order for options grid. PET covers every pet when Show Pets is on.
BuffPower_ClassOrder = {
    "WARRIOR", "ROGUE", "PRIEST", "DRUID", "PALADIN", "HUNTER", "MAGE", "WARLOCK", "SHAMAN", "PET"
}

BuffPower_ClassNames = {
    WARRIOR = "Warrior",
    ROGUE = "Rogue",
    PRIEST = "Priest",
    DRUID = "Druid",
    PALADIN = "Paladin",
    HUNTER = "Hunter",
    MAGE = "Mage",
    WARLOCK = "Warlock",
    SHAMAN = "Shaman",
    PET = "Pet",
}

-------------------------------------------------------------------
-- Spell Definitions
--
-- Spell IDs are for TBC Classic (2.5.x). rankIDs run from the highest rank
-- down, so lower-level characters and lower ranks are still detected. At
-- runtime ScanPlayerBuffs overwrites spellID with the highest known rank and
-- name with the localized name. Classes in ineligibleClasses never receive
-- the buff; optional buffs default to off for every class.
-------------------------------------------------------------------
BuffPower_Spells = {
    MAGE = {
        intellect = {
            displayName = "Arcane Intellect",
            priority = 1,
            single = {
                spellID = 27126,  -- Arcane Intellect (Max Rank)
                rankIDs = { 27126, 10157, 10156, 1461, 1460, 1459 }, -- Rank 6 down to 1
                name = "Arcane Intellect",
                icon = "Interface\\Icons\\Spell_Holy_MagicalSentry",
            },
            group = {
                spellID = 27127,  -- Arcane Brilliance (Max Rank)
                rankIDs = { 27127, 23028 }, -- Rank 2 down to 1
                name = "Arcane Brilliance",
                icon = "Interface\\Icons\\Spell_Holy_ArcaneIntellect",
            },
            ineligibleClasses = { WARRIOR = true, ROGUE = true },
        },
        amplify_magic = {
            displayName = "Amplify Magic",
            priority = 2,
            optional = true,
            single = {
                spellID = 33946, -- Amplify Magic (Max Rank)
                rankIDs = { 33946, 27130, 10170, 10169, 8455, 1008 }, -- Rank 6 down to 1
                name = "Amplify Magic",
                icon = "Interface\\Icons\\Spell_Holy_FlashHeal",
            },
        },
        dampen_magic = {
            displayName = "Dampen Magic",
            priority = 3,
            optional = true,
            single = {
                spellID = 33944, -- Dampen Magic (Max Rank)
                rankIDs = { 33944, 27131, 10174, 10173, 674, 453 }, -- Rank 6 down to 1
                name = "Dampen Magic",
                icon = "Interface\\Icons\\Spell_Nature_AbolishMagic",
            },
        },
    },

    PRIEST = {
        fortitude = {
            displayName = "Fortitude",
            priority = 1,
            single = {
                spellID = 25389,  -- Power Word: Fortitude (Max Rank)
                rankIDs = { 25389, 10938, 10937, 2791, 1245, 1244, 1243 }, -- Rank 7 down to 1
                name = "Power Word: Fortitude",
                icon = "Interface\\Icons\\Spell_Holy_WordFortitude",
            },
            group = {
                spellID = 25392,  -- Prayer of Fortitude (Max Rank)
                rankIDs = { 25392, 21564, 21562 }, -- Rank 3 down to 1
                name = "Prayer of Fortitude",
                icon = "Interface\\Icons\\Spell_Holy_PrayerOfFortitude",
            },
        },
        spirit = {
            displayName = "Divine Spirit",
            priority = 2,
            single = {
                spellID = 25312,  -- Divine Spirit (Max Rank)
                rankIDs = { 25312, 27841, 14819, 14818, 14752 }, -- Rank 5 down to 1
                name = "Divine Spirit",
                icon = "Interface\\Icons\\Spell_Holy_DivineSpirit",
            },
            group = {
                spellID = 32999,  -- Prayer of Spirit (Max Rank)
                rankIDs = { 32999, 27681 }, -- Rank 2 down to 1
                name = "Prayer of Spirit",
                icon = "Interface\\Icons\\Spell_Holy_PrayerOfSpirit",
            },
            ineligibleClasses = { WARRIOR = true, ROGUE = true },
        },
        shadow_protection = {
            displayName = "Shadow Protection",
            priority = 3,
            optional = true,
            single = {
                spellID = 25433,  -- Shadow Protection (Max Rank)
                rankIDs = { 25433, 10958, 10957, 976 }, -- Rank 4 down to 1
                name = "Shadow Protection",
                icon = "Interface\\Icons\\Spell_Shadow_AntiShadow",
            },
            group = {
                spellID = 39374,  -- Prayer of Shadow Protection (Max Rank)
                rankIDs = { 39374, 27683 }, -- Rank 2 down to 1
                name = "Prayer of Shadow Protection",
                icon = "Interface\\Icons\\Spell_Holy_PrayerofShadowProtection",
            },
        },
    },

    DRUID = {
        wild = {
            displayName = "Mark of the Wild",
            priority = 1,
            single = {
                spellID = 26990,  -- Mark of the Wild (Max Rank)
                rankIDs = { 26990, 9885, 9884, 8907, 5234, 6756, 5232, 1126 }, -- Rank 8 down to 1
                name = "Mark of the Wild",
                icon = "Interface\\Icons\\Spell_Nature_Regeneration",
            },
            group = {
                spellID = 26991,  -- Gift of the Wild (Max Rank)
                rankIDs = { 26991, 21850, 21849 }, -- Rank 3 down to 1
                name = "Gift of the Wild",
                icon = "Interface\\Icons\\Spell_Nature_GiftoftheWild",
            },
        },
        thorns = {
            displayName = "Thorns",
            priority = 2,
            optional = true,
            single = {
                spellID = 26992,  -- Thorns (Max Rank)
                rankIDs = { 26992, 9910, 9756, 8914, 1075, 782, 467 }, -- Rank 7 down to 1
                name = "Thorns",
                icon = "Interface\\Icons\\Spell_Nature_Thorns",
            },
            ineligibleClasses = {
                ROGUE = true, PRIEST = true, HUNTER = true,
                MAGE = true, WARLOCK = true, SHAMAN = true
            },
        },
    },
}

-------------------------------------------------------------------
-- Buff Priority Order (for cycle-clicking)
-------------------------------------------------------------------
BuffPower_BuffPriority = {
    MAGE = { "intellect", "amplify_magic", "dampen_magic" },
    PRIEST = { "fortitude", "spirit", "shadow_protection" },
    DRUID = { "wild", "thorns" },
}

-------------------------------------------------------------------
-- Default Values for AceDB
-------------------------------------------------------------------
BUFFPOWER_DEFAULT_VALUES = {
    global = {
        buffscale = 1.0,
        groupButtonWidth = 120,
        playerButtonWidth = 150, -- room for longer names
        locked = false,
        ShowWhenSolo = true,
        ShowInParty = true,
        ShowPets = false,
        ShowTooltips = true,
        FirstNamesOnly = false, -- WoW Forever: hide players' last names
        debug = false,

        -- Frame position: BuffPowerFrame's anchor point on UIParent
        display = {
            point = "CENTER",
            relativePoint = "CENTER",
            offsetX = 0,
            offsetY = 0,
        },

        -- Buff assignments (per buff key, per target class) - defaults set dynamically
        assignments = {},

        -- LibDBIcon state
        minimap = {
            minimapPos = 190,
            hide = false,
        },
    },

    -- Per character: two characters (often of different classes) buff different groups and players
    char = {
        -- Raid groups this character is responsible for buffing
        myResponsibleGroups = {},

        -- Player name -> optional buff key forced on that player (scroll-wheel override)
        playerAssignments = {},
    },
}
