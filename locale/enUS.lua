-- locale/enUS.lua
-- English localization for BuffPower

-- Ensure the addon name used here matches the one in NewAddon and the .toc file exactly.
local addonName = "BuffPower" 

-- Get the AceLocale-3.0 library.
local AceLocale = LibStub("AceLocale-3.0")

-- Register the localization table with AceLocale.
-- The third argument, true, makes this the default locale if no other is found.
local L = AceLocale:NewLocale(addonName, "enUS", true)

if not L then return end -- If NewLocale fails (e.g., already registered), exit.

-- General
L["Configuration"] = "Configuration"
L["Enable BuffPower"] = "Enable BuffPower"
L["Show Buff Window"] = "Show Buff Window"
L["Lock Window Position"] = "Lock Window Position"
L["Window Scale:"] = "Window Scale:"
L["Window locked."] = "Window locked."
L["Window unlocked."] = "Window unlocked."
L["Settings reset to default."] = "Settings reset to default."
L["Usage: /bp [show|hide|lock|unlock|config|reset]"] = "Usage: /bp [show|hide|lock|unlock|config|reset]"
L["Options panel not yet implemented via slash command."] = "Options panel not yet implemented via slash command. Open Interface->Addons."
L["Reset Settings"] = "Reset Settings"
L["Show Tooltips on Group Buttons"] = "Show Tooltips on Group Buttons"
L["Show Group Member Names in Tooltip"] = "Show Group Member Names in Tooltip"

-- Class Settings
L["Class Settings (for current player)"] = "Class Settings (for current player)"
L["Enable for "] = "Enable for " -- e.g., "Enable for Mage"

-- Main Window & Groups
L["Group %d"] = "Group %d" -- %d will be group number
L[" (Empty)"] = " (Empty)"
L[": Unassigned"] = ": Unassigned"
L[" (Unknown Class)"] = " (Unknown Class)"
L["Group %d: Assigned to %s%s|r"] = "Group %d: Assigned to %s%s|r" -- Group num, color, player name
L["Buff: %s%s|r (%s)"] = "Buff: %s%s|r (%s)" -- Color, Buff Name, Class Name
L["Group %d: Unassigned"] = "Group %d: Unassigned"
L["Right-click to assign a buffer."] = "Right-click to assign a buffer."
L["Group Members:"] = "Group Members:"
L["No members in this group (or not in a group)."] = "No members in this group (or not in a group)."
L["You are not assigned to buff this group."] = "You are not assigned to buff this group."
L["Group is assigned to: "] = "Group is assigned to: "
L["This group is not assigned or you cannot buff."] = "This group is not assigned or you cannot buff."
L["You are not a class that can provide this type of buff."] = "You are not a class that can provide this type of buff."
L["Missing reagent: "] = "Missing reagent: "

-- Assignment Menu
L["Clear Assignment"] = "Clear Assignment"
L["----- Buffers -----"] = "----- Buffers -----"
L["No eligible buffers in group/raid."] = "No eligible buffers in group/raid."

DEFAULT_CHAT_FRAME:AddMessage("BuffPower enUS locale registered with AceLocale.")
