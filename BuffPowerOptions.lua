-- BuffPowerOptions.lua
-- Author: Ruuddie
-- Options panel for BuffPower using AceConfig

-------------------------------------------------------------------
-- Options Setup
-------------------------------------------------------------------
function BuffPower:SetupOptions()
    local options = {
        type = "group",
        name = "BuffPower",
        handler = BuffPower,
        args = {
            general = {
                type = "group",
                name = "General Settings",
                order = 1,
                args = self:GetGeneralOptions(),
            },
            assignments = {
                type = "group",
                name = "Group Assignments",
                order = 2,
                args = self:GetGroupAssignmentOptions(),
            },
            classAssignments = {
                type = "group",
                name = "Class Assignments",
                order = 3,
                childGroups = "tab",
                args = self:GetClassAssignmentOptions(),
            },
            authorFooter = {
                type = "description",
                name = "|cffffffffAuthor:|r |cfff58cbaRuuddie|r",
                fontSize = "medium",
                order = 1000,
                width = "full",
            },
        },
    }

    LibStub("AceConfig-3.0"):RegisterOptionsTable("BuffPower", options)
    LibStub("AceConfigDialog-3.0"):AddToBlizOptions("BuffPower", "BuffPower")
end

-------------------------------------------------------------------
-- General Options
-------------------------------------------------------------------
function BuffPower:GetGeneralOptions()
    return {
        description = {
            type = "description",
            name = "These settings apply to all your characters.",
            order = 1,
        },
        headerVisibility = {
            type = "header",
            name = "Visibility",
            order = 10,
        },
        ShowWhenSolo = {
            type = "toggle",
            name = "Show When Solo",
            desc = "Show BuffPower when you are not in a group",
            get = function() return BuffPower.opt.ShowWhenSolo end,
            set = function(_, value)
                BuffPower.opt.ShowWhenSolo = value
                BuffPower:UpdateRoster()
            end,
            order = 11,
        },
        ShowInParty = {
            type = "toggle",
            name = "Show In Party",
            desc = "Show BuffPower when in a party (not raid)",
            get = function() return BuffPower.opt.ShowInParty end,
            set = function(_, value)
                BuffPower.opt.ShowInParty = value
                BuffPower:UpdateRoster()
            end,
            order = 12,
        },
        ShowPets = {
            type = "toggle",
            name = "Show Pets",
            desc = "Include pets in the buff display",
            get = function() return BuffPower.opt.ShowPets end,
            set = function(_, value)
                BuffPower.opt.ShowPets = value
                BuffPower:UpdateRoster()
            end,
            order = 13,
        },
        headerDisplay = {
            type = "header",
            name = "Display",
            order = 20,
        },
        ShowTooltips = {
            type = "toggle",
            name = "Show Tooltips",
            desc = "Show tooltips when hovering over buttons",
            get = function() return BuffPower.opt.ShowTooltips end,
            set = function(_, value)
                BuffPower.opt.ShowTooltips = value
            end,
            order = 21,
        },
        FirstNamesOnly = {
            type = "toggle",
            name = "First Names Only",
            desc = "Show players by their first name, without their last name.",
            -- Only WoW Forever has last names; Blizzard shows its own surname option on the same check
            hidden = function() return not (RegionalUniqueNamesEnabled and RegionalUniqueNamesEnabled()) end,
            get = function() return BuffPower.opt.FirstNamesOnly end,
            set = function(_, value)
                BuffPower.opt.FirstNamesOnly = value
                BuffPower:UpdateRoster()
            end,
            order = 22,
        },
        headerSize = {
            type = "header",
            name = "Size",
            order = 30,
        },
        buffscale = {
            type = "range",
            name = "UI Scale",
            desc = "Scale of the BuffPower UI",
            min = 0.5,
            max = 2.0,
            step = 0.05,
            get = function() return BuffPower.opt.buffscale end,
            set = function(_, val)
                BuffPower.opt.buffscale = val
                BuffPower:UpdateScale()
            end,
            order = 31,
        },
        groupButtonWidth = {
            type = "range",
            name = "Group Button Width",
            desc = "Width of the group buttons. Takes effect out of combat.",
            -- 115 still fits the group label next to three buff icons
            min = 115,
            max = 180,
            step = 5,
            get = function() return BuffPower.opt.groupButtonWidth end,
            set = function(_, val)
                BuffPower.opt.groupButtonWidth = val
                BuffPower:UpdateLayout()
            end,
            order = 32,
        },
        playerButtonWidth = {
            type = "range",
            name = "Player Button Width",
            desc = "Width of the player buttons, to make room for longer names. Takes effect out of combat.",
            min = 120,
            max = 225,
            step = 5,
            get = function() return BuffPower.opt.playerButtonWidth end,
            set = function(_, val)
                BuffPower.opt.playerButtonWidth = val
                BuffPower:UpdateLayout()
            end,
            order = 33,
        },
        resetSizes = {
            type = "execute",
            name = "Reset Sizes",
            desc = "Set the UI scale and both button widths back to their defaults. Other settings are kept.",
            func = function()
                local defaults = BUFFPOWER_DEFAULT_VALUES.global
                BuffPower.opt.buffscale = defaults.buffscale
                BuffPower.opt.groupButtonWidth = defaults.groupButtonWidth
                BuffPower.opt.playerButtonWidth = defaults.playerButtonWidth
                BuffPower:UpdateScale()
                BuffPower:UpdateLayout()
            end,
            order = 34,
        },
        minimapHide = {
            type = "toggle",
            name = "Hide Minimap Icon",
            desc = "Hide the minimap icon",
            get = function() return BuffPower.opt.minimap.hide end,
            set = function(_, value)
                BuffPower.opt.minimap.hide = value
                local LDBIcon = LibStub("LibDBIcon-1.0", true)
                if LDBIcon then
                    if value then
                        LDBIcon:Hide("BuffPower")
                    else
                        LDBIcon:Show("BuffPower")
                    end
                end
            end,
            order = 23,
        },
    }
end

-------------------------------------------------------------------
-- Class Assignment Options (Dynamic)
-------------------------------------------------------------------
-- Class names in their class colour; pets have no class colour and stay white
local function ClassColoredName(classFilename)
    local name = BuffPower_ClassNames[classFilename]
    local color = RAID_CLASS_COLORS[classFilename]
    if not color then return name end
    return format("|cff%02x%02x%02x%s|r", color.r * 255, color.g * 255, color.b * 255, name)
end

function BuffPower:GetClassAssignmentOptions()
    local args = {
        description = {
            type = "description",
            name = "Configure which classes should receive specific buffs. These settings are shared by your characters of the same class.",
            order = 1,
        },
    }

    -- Quick-select presets. Hybrids appear in several sets because spec cannot be
    -- known without inspection; the user can refine with the checkboxes.
    local presets = {
        { key = "setAll",       name = "All",        desc = "Select all classes" },
        { key = "setMelee",     name = "Melee",      desc = "Select Warrior, Rogue, Paladin, Shaman, Druid",
          classes = { WARRIOR = true, ROGUE = true, PALADIN = true, DRUID = true, SHAMAN = true } },
        { key = "setTanks",     name = "Tanks",      desc = "Select Warrior, Paladin, Druid",
          classes = { WARRIOR = true, DRUID = true, PALADIN = true } },
        { key = "setManaUsers", name = "Mana",       desc = "Select all classes that use mana",
          classes = { MAGE = true, WARLOCK = true, PRIEST = true, DRUID = true, SHAMAN = true, PALADIN = true, HUNTER = true } },
        { key = "clearAll",     name = "None",       desc = "Deselect all classes", classes = {} },
    }

    for buffKey, buffData in pairs(BuffPower_Spells[self.playerClass]) do
        local groupArgs = {
            presetHeader = { type = "description", name = "Quick Select:", order = 1 },
            classesHeader = { type = "header", name = "Classes", order = 10 },
        }

        for i, preset in ipairs(presets) do
            groupArgs[preset.key] = {
                type = "execute",
                name = preset.name,
                desc = preset.desc,
                width = "half",
                order = 1 + i,
                func = function()
                    for class in pairs(BuffPower_ClassNames) do
                        self.opt.assignments[buffKey][class] = not preset.classes or preset.classes[class] == true
                    end
                    self:ScanPlayerBuffs()
                    self:UpdateRoster()
                end,
            }
        end

        for i, classFilename in ipairs(BuffPower_ClassOrder) do
            groupArgs[classFilename] = {
                type = "toggle",
                name = ClassColoredName(classFilename),
                desc = format("Cast %s on %s", buffData.displayName, BuffPower_ClassNames[classFilename]),
                get = function()
                    -- Unset means the default: on for normal buffs, off for optional ones
                    local value = self.opt.assignments[buffKey][classFilename]
                    if value == nil then return not buffData.optional end
                    return value
                end,
                set = function(_, value)
                    self.opt.assignments[buffKey][classFilename] = value
                    self:ScanPlayerBuffs()
                    self:UpdateRoster()
                end,
                order = 19 + i,
                width = "half",
            }
        end

        args[buffKey] = {
            type = "group",
            name = buffData.displayName,
            order = buffData.priority,
            args = groupArgs,
        }
    end

    return args
end

-------------------------------------------------------------------
-- Group Assignment Options (Dynamic)
-------------------------------------------------------------------
function BuffPower:GetGroupAssignmentOptions()
    local args = {
        description = {
            type = "description",
            name = "Select which raid groups this character is responsible for buffing. Each of your characters has its own selection.",
            order = 1,
        },
    }

    for i = 1, BUFFPOWER_CONSTANTS.MAX_RAID_GROUPS do
        local key = "Group " .. i
        args["group" .. i] = {
            type = "toggle",
            name = key,
            desc = "You are responsible for buffing " .. key,
            get = function()
                return self.charOpt.myResponsibleGroups[key] ~= false
            end,
            set = function(_, value)
                self.charOpt.myResponsibleGroups[key] = value
                self:UpdateLayout()
            end,
            order = 10 + i,
        }
    end

    -- Full width, so the buttons below start on a row of their own
    args.quickSelect = {
        type = "description",
        name = "Quick Select:",
        width = "full",
        order = 99,
    }

    local bulk = {
        selectAll  = { name = "All",  desc = "Take responsibility for all groups",   value = true,  order = 100 },
        selectNone = { name = "None", desc = "Remove responsibility for all groups", value = false, order = 101 },
    }
    for key, entry in pairs(bulk) do
        args[key] = {
            type = "execute",
            name = entry.name,
            desc = entry.desc,
            width = "half",
            order = entry.order,
            func = function()
                for i = 1, BUFFPOWER_CONSTANTS.MAX_RAID_GROUPS do
                    self.charOpt.myResponsibleGroups["Group " .. i] = entry.value
                end
                self:UpdateLayout()
            end,
        }
    end

    return args
end
