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
      spellIDs   (table)  : Classic spellIDs for ranks - can be single (highest) or all (for logic needs)
      assignable (bool)   : Can this buff be assigned to a class/role (for group manager UI)
      perClass   (bool)   : Can assignment be toggled per class
      perGroup   (bool)   : Can assignment be toggled per group/index
      -- No display strings: must use key for lookup into localization!
  --------------------------------------------]]
  MAGE = {
    INTELLECT = {
      key = "INTELLECT",                             -- localization key for 'Intellect'
      spellIDs = {23028, 10157, 10156, 10155},       -- Classic Arcane Brilliance, descending by rank
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
      spellIDs = { 10938, 21562, 1243, 1245, 2791 }, -- Power Word: Fortitude (single & group ranks); can trim as needed
      assignable = true,
      perClass = true,
      perGroup = true,
    },
    SPIRIT = {
      key = "SPIRIT",                                -- localization key for 'Spirit'
      spellIDs = { 27681, 14819, 14818 },            -- Divine Spirit ranks (group & highest single)
      assignable = true,
      perClass = true,
      perGroup = true,
    },
    SHADOW_PROTECTION = {
      key = "SHADOW_PROTECTION",                     -- localization key for 'Shadow Protection'
      spellIDs = { 39374, 27683, 10958 },            -- Prayer of Shadow Protection (Classic & TBCC/Wrath backport support)
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
      spellIDs = { 21850, 26990, 9885 },             -- Gift of the Wild + Mark (add more as required)
      assignable = true,
      perClass = true,
      perGroup = true,
    },
    THORNS = {
      key = "THORNS",                                -- localization key for 'Thorns'
      spellIDs = { 9910, 1075, 8914 },               -- Thorns ranks (no group buff, but per-group option may be UI-useful)
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