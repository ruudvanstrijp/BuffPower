-- Luacheck configuration. Run with .\scripts\lint.ps1 (also the "Lint" VS Code task);
-- CI runs the same check on every push and pull request.

std = "lua51"
max_line_length = false

exclude_files = {
    "Libs/",
    ".examples/",
    ".tools/",
}

ignore = {
    "212",      -- unused argument: handler signatures are fixed by the caller
    "432/self", -- function(self) frame-script closures inside methods
}

-- Defined by this addon and shared between its files.
globals = {
    "BuffPower",
    "BuffPower_BuffPriority",
    "BuffPower_ClassNames",
    "BuffPower_ClassOrder",
    "BuffPower_Spells",
    "BUFFPOWER_CONSTANTS",
    "BUFFPOWER_DEFAULT_VALUES",
}

-- Game API the addon uses. Kept as an explicit list rather than a full WoW API dump
-- so that a typo, or a call missing on one of the clients, shows up as a warning:
-- new API belongs in the compatibility layer at the top of BuffPower.lua first.
read_globals = {
    -- Frames created in BuffPower.xml
    "BuffPowerAnchor",
    "BuffPowerFrame",

    -- Libraries
    "LibStub",

    -- Lua aliases provided by the game
    "format",

    -- Frames and UI
    "CreateFrame",
    "GameTooltip",
    "RAID_CLASS_COLORS",
    "UIParent",

    -- Secure execution
    "InCombatLockdown",
    "loadstring_untainted",
    "SecureHandlerExecute",
    "SecureHandlerSetFrameRef",

    -- Spells and auras
    "AuraUtil",
    "C_Secrets",
    "C_Spell",
    "C_SpellBook",
    "GetSpellInfo",
    "IsSpellInRange",
    "IsSpellKnown",

    -- Group and units
    "Ambiguate",
    "C_NameUtil",
    "GetNumGroupMembers",
    "GetRaidRosterInfo",
    "GetUnitName",
    "IsInRaid",
    "UnitClass",
    "UnitExists",
    "UnitInRange",
    "UnitIsConnected",
    "UnitIsDeadOrGhost",
    "UnitIsVisible",
    "UnitName",

    -- Timing
    "C_Timer",
    "GetTime",
}
