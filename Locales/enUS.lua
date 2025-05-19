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
-- Example: L["YOUR_KEY_NAME"] = "Visible Name"
-- Do not add spell names, class names, or game logic text here.

-- End of enUS localization for BuffPower