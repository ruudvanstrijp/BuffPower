--[[
BuffPower Buff Definition Tables
--------------------------------
Defines core data for all non-Paladin raid buffs managed by BuffPower.
This file contains tables for each relevant class with group buffs: Mage, Priest, Druid.
* Each buff uses a localization key ONLY for display.
* Only Classic spellIDs used.
* No implementation, Paladin, PallyPower, or logic here.

Extensible structure: add new classes or buffs in same format below.
]]

BuffPower_Buffs = {
  --[[-------------------------------------------
    MAGE GROUP BUFFS
    INTELLECT (Arcane Intellect/Brilliance group buff)
    Fields:
      key        (string) : Localization key, no hardcoded English
      spellIDs   (table)  : Classic spellIDs for ranks - GROUP spells first, then single-target
      groupSpellIDs (table) : Specific group buff spell IDs
      singleSpellIDs (table) : Specific single-target buff spell IDs
      assignable (bool)   : Can this buff be assigned to a class/role (for group manager UI)
      perClass   (bool)   : Can assignment be toggled per class
      perGroup   (bool)   : Can assignment be toggled per group/index
      -- No display strings: must use key for lookup into localization!
  --------------------------------------------]]
  MAGE = {
    INTELLECT = {
      key = "INTELLECT",                             -- localization key for 'Intellect'
      spellIDs = {23028, 1459},                      -- Group first (Arcane Brilliance), then single (Arcane Intellect)
      groupSpellIDs = {23028},                       -- Arcane Brilliance
      singleSpellIDs = {1459, 1460, 1461, 10156, 10157}, -- Arcane Intellect ranks
      assignable = true,                             -- can be group/class assigned in UI
      perClass = true,                               -- per-class toggling enabled
      perGroup = true,                               -- per-group toggling enabled
    },
  },

  --[[-------------------------------------------
    PRIEST GROUP BUFFS
    FORTITUDE, SPIRIT, SHADOW PROTECTION
  --------------------------------------------]]
  PRIEST = {
    FORTITUDE = {
      key = "FORTITUDE",                             -- localization key for 'Fortitude'
      spellIDs = {21562, 1243},                      -- Group first (Prayer of Fortitude), then single (Power Word: Fortitude)
      groupSpellIDs = {21562},                       -- Prayer of Fortitude
      singleSpellIDs = {1243, 1245, 2791, 10937, 10938}, -- Power Word: Fortitude ranks
      assignable = true,
      perClass = true,
      perGroup = true,
    },
    SPIRIT = {
      key = "SPIRIT",                                -- localization key for 'Spirit'
      spellIDs = {27681, 14819},                     -- Group first (Prayer of Spirit), then single (Divine Spirit)
      groupSpellIDs = {27681},                       -- Prayer of Spirit
      singleSpellIDs = {14752, 14818, 14819, 27841}, -- Divine Spirit ranks
      assignable = true,
      perClass = true,
      perGroup = true,
    },
    SHADOW_PROTECTION = {
      key = "SHADOW_PROTECTION",                     -- localization key for 'Shadow Protection'
      spellIDs = {27683, 976},                       -- Group first (Prayer of Shadow Protection), then single (Shadow Protection)
      groupSpellIDs = {27683},                       -- Prayer of Shadow Protection
      singleSpellIDs = {976, 10957, 10958},          -- Shadow Protection ranks
      assignable = true,
      perClass = true,
      perGroup = true,
    },
  },

  --[[-------------------------------------------
    DRUID GROUP BUFFS
    MARK OF THE WILD (Mark/Gift), THORNS
  --------------------------------------------]]
  DRUID = {
    MARK = {
      key = "MARK",                                  -- localization key for 'Mark of the Wild'
      spellIDs = {21850, 1126},                      -- Group first (Gift of the Wild), then single (Mark of the Wild)
      groupSpellIDs = {21850, 26990},                -- Gift of the Wild ranks
      singleSpellIDs = {1126, 5232, 6756, 5234, 8907, 9884, 9885}, -- Mark of the Wild ranks
      assignable = true,
      perClass = true,
      perGroup = true,
    },
    THORNS = {
      key = "THORNS",                                -- localization key for 'Thorns'
      spellIDs = {1075},                             -- Single target only (no group Thorns)
      groupSpellIDs = {},                            -- No group version
      singleSpellIDs = {467, 782, 1075, 8914, 9756, 9910}, -- Thorns ranks
      assignable = true,
      perClass = true,
      perGroup = true,
    },
  },

  --[[
    Extend with additional classes/buffs as needed.
    Only add group/raid-wise assignable buffs; single-target short buffs not included here.
  ]]
}