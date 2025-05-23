--[[--------------------------------------------------------------------
BuffPower enUS localization (AceLocale-3.0)
-----------------------------------------------------------------------
This file provides the enUS (US English) locale for BuffPower,
using AceLocale-3.0. It establishes a pattern for future translation
contributors. Please follow the guidelines below:

* Define only generic, UI-structure, or organizational keys here.
* NO class names, spell names, buff names, or gameplay-specific keys.
* DO NOT include any business logic or content strings—these belong
  in separate or more specialized localization files.
* Add new UI terms, section headers, or general-purpose labels as needed.
* Each key should be self-explanatory and paired with clear, neutral
  values in US English.

Example expansion keys (update/add as needed):
  ["SOME_LABEL_KEY"] = "Some Label",

---------------------------------------------------------------------]]

local L = LibStub("AceLocale-3.0"):NewLocale("BuffPower", "enUS", true)
if not L then return end

-- Generic UI/structure/localization keys for BuffPower
L["OPTIONS"]        = "Options"
L["GROUPS"]         = "Groups"
L["ASSIGNMENTS"]    = "Assignments"
L["BUFFS"]          = "Buffs"
L["UI_LABEL_SAMPLE"]= "Sample Label"
-- Add new UI/general structure keys below this line.
L["ANCHOR_LABEL"]   = "BuffPower"

-- Options panel labels
L["OPTIONS_GENERAL"] = "General"
L["OPTIONS_GENERAL_DESC"] = "General BuffPower settings"
L["OPTIONS_ASSIGNMENTS"] = "Assignments"
L["OPTIONS_ASSIGNMENTS_DESC"] = "Buff assignment configuration"
L["OPTIONS_BUFFTOGGLES"] = "Buff Toggles"
L["OPTIONS_BUFFTOGGLES_DESC"] = "Enable/disable individual buffs"

-- Class names
L["CLASS_MAGE"] = "Mage"
L["CLASS_PRIEST"] = "Priest"
L["CLASS_DRUID"] = "Druid"
L["CLASS_MAGE_DESC"] = "Mage buff settings"
L["CLASS_PRIEST_DESC"] = "Priest buff settings"
L["CLASS_DRUID_DESC"] = "Druid buff settings"

-- Buff names
L["INTELLECT"] = "Intellect"
L["INTELLECT_DESC"] = "Arcane Intellect / Arcane Brilliance"
L["FORTITUDE"] = "Fortitude"
L["FORTITUDE_DESC"] = "Power Word: Fortitude / Prayer of Fortitude"
L["SPIRIT"] = "Spirit"
L["SPIRIT_DESC"] = "Divine Spirit / Prayer of Spirit"
L["SHADOW_PROTECTION"] = "Shadow Protection"
L["SHADOW_PROTECTION_DESC"] = "Shadow Protection / Prayer of Shadow Protection"
L["MARK"] = "Mark of the Wild"
L["MARK_DESC"] = "Mark of the Wild / Gift of the Wild"
L["THORNS"] = "Thorns"
L["THORNS_DESC"] = "Thorns"

-- End of enUS localization for BuffPower