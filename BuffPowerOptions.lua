-- BuffPower - Options/Config Initialization (Ace3 Scaffold)
-- Sets up AceConfig-3.0, AceConfigDialog-3.0, and AceDBOptions-3.0 for BuffPower.
-- Organized: "General", "Assignments", "Buff Toggles" (subgroups: Mage, Priest, Druid).
-- Uses BuffPowerValues.lua for class/buff data. All labels use localization keys ONLY.
-- Extensible, heavily commented per main plan. No Paladin/PallyPower logic. No hardcoded English UI.

-- Libraries
local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local AceDBOptions = LibStub("AceDBOptions-3.0")

local L = LibStub("AceLocale-3.0"):GetLocale("BuffPower")
-- Do NOT create a local BuffPower reference here; always use the global (already initialized) BuffPower
-- This fixes closure issues and guarantees AceDB is live/consistent across all gets/sets.
-- local BuffPower = LibStub("AceAddon-3.0"):GetAddon("BuffPower")
local BuffPower_Buffs = BuffPower_Buffs  -- from BuffPowerValues.lua

-- Main Ace3 options registry table
local options = {
  type = "group",
  name = "BuffPower",             -- Name in UI: Use localization in real refactor if needed
  childGroups = "tab",
  args = {
    general = {
      order = 1,
      type = "group",
      name = "OPTIONS_GENERAL",   -- Localization key
      desc = "OPTIONS_GENERAL_DESC", -- Localization key
      -- TODO: Add actual general settings here - e.g., global UI toggles, minimap button, scale, etc.
      args = {
        -- Example stub: Enable/disable BuffPower (future)
        -- enable = {
        --   order = 1,
        --   type = "toggle",
        --   name = "ENABLE",         -- Localization key
        --   desc = "ENABLE_DESC",    -- Localization key
        --   get = function() return BuffPower.db.profile.enabled end,
        --   set = function(_, val) BuffPower.db.profile.enabled = val end,
        -- },
        -- TODO: Add further global/user options as required by plan.
        spacer = { order = 10, type = "description", name = " " },
        _comment = {
          order = 100,
          type = "description",
          name = "-- TODO: Populate General panel with global settings when designed.",
        },
      },
    },

    assignments = {
      order = 2,
      type = "group",
      name = "OPTIONS_ASSIGNMENTS",     -- Localization key
      desc = "OPTIONS_ASSIGNMENTS_DESC",-- Localization key
      -- TODO: Scaffold for assignment matrix/options. Comment with expansion plan.
      args = {
        assignmentMatrixStub = {
          order = 1,
          type = "description",
          name = "-- TODO: Class/group assignment matrix will go here.\n"
            .. "-- Feature Plan: UI matrix toggle for which class does which group (per-buff),\n"
            .. "-- support mouse drag, priority settings, auto-assign.\n"
            .. "-- UI to match plan in BuffPower_Plan_v4.md, with highlighting and save/restore logic.",
        }
      },
    },

    bufftoggles = {
      order = 3,
      type = "group",
      name = "OPTIONS_BUFFTOGGLES",     -- Localization key
      desc = "OPTIONS_BUFFTOGGLES_DESC",-- Localization key
      childGroups = "tree",
      args = {
        -- Dynamically creates one group per relevant class
      },
    },
  },
}

-- Helper: Filter classes to only Mage, Priest, Druid for scaffold
local CLASSES = { "MAGE", "PRIEST", "DRUID" }

for _, class in ipairs(CLASSES) do
  local classBuffs = BuffPower_Buffs[class]
  local classKey = "CLASS_" .. class                           -- e.g., CLASS_MAGE
  local classGroup = {
    order = _,
    type = "group",
    name = classKey,           -- Pure localization key for class label
    desc = classKey .. "_DESC",-- Pure localization key for panel desc
    args = {},
  }

  -- For each buff: create stub toggle and detailed comment for UI
  for buffKey, buffInfo in pairs(classBuffs) do
    local _buffKey = buffKey -- localize for closure!
    local locKey = buffInfo.key    -- Localization key e.g. "INTELLECT"
    classGroup.args["buff_".._buffKey] = {
      order = 1,
      type = "toggle",             -- Toggle stub: future logic/UI to be implemented
      name = locKey,               -- Use only localization key for label
      desc = locKey.." _DESC",     -- Use only localization key for description
      get = function()
        local key = "buffcheck_".._buffKey:lower()
        if BuffPower.db and BuffPower.db.profile and BuffPower.db.profile[key] ~= nil then
          return BuffPower.db.profile[key]
        else
          return true -- default to true
        end
      end,
      set = function(_, val)
        local key = "buffcheck_".._buffKey:lower()
        print("[BuffPower][OPTIONS][DEBUG] set:", key, "=", tostring(val), "profileTable:", tostring(BuffPower.db.profile))
        if BuffPower.db and BuffPower.db.profile then
          BuffPower.db.profile[key] = (val == true)
          print("[BuffPower][OPTIONS][DEBUG] Now profile[key]:", key, "=", tostring(BuffPower.db.profile[key]))
          if BuffPower.UpdateRosterUI then
            BuffPower:UpdateRosterUI()
          end
        end
      end,
      -- When implementing, wire up these toggles to per-buff enable/disable,
      -- and consider per-group, per-class, and assignment responsibilities.
    }

    -- Add matrix UI stub/plan as description
    classGroup.args["buff_"..buffKey.."_matrix_stub"] = {
      order = 2,
      type = "description",
      name = "-- TODO: Add per-group (1-8) and per-class toggles here,\n"
        .. "-- as described in BuffPower_Plan_v4.md. Intended: Matrix UI similar to PallyPower, but only for Mages, Priests, Druids (no Paladins).\n"
        .. "-- Also plan advanced assignment/prio input, keyboard controls, and save/restore profile support.",
      fontSize = "medium",
    }
  end
  -- Insert class group into Buff Toggles panel
  options.args.bufftoggles.args[class] = classGroup
end

-- Register options table with Ace3
AceConfig:RegisterOptionsTable("BuffPower", options)
AceConfigDialog:AddToBlizOptions("BuffPower", "BuffPower")
AceConfigDialog:AddToBlizOptions("BuffPower", "OPTIONS_GENERAL", "BuffPower", "general")
AceConfigDialog:AddToBlizOptions("BuffPower", "OPTIONS_ASSIGNMENTS", "BuffPower", "assignments")
AceConfigDialog:AddToBlizOptions("BuffPower", "OPTIONS_BUFFTOGGLES", "BuffPower", "bufftoggles")

-- DB Options: For future DB interface (not visible unless added)
-- Removed duplicate AddToBlizOptions call to prevent options registration error (only register "BuffPower" once)

-- TODOs for future development (see assigned comments in each group above):
-- - General: Add actual global/user settings (minimap button, scale, keybinds, reset profile, etc).
-- - Assignments: Build full class-group-buff responsibility matrix, with interactive assignment logic, save/restore, and advanced settings as per BuffPower_Plan_v4.md.
-- - Buff Toggles: For each class (Mage, Priest, Druid), enable per-buff toggling (enable/disable), then per-group, then full UI for assignment/prio/drag/etc.
-- - Integrate localization: All names/descs must resolve from L[] locale table, never hardcoded.
-- - Extendable: Add new classes/buffs by editing BuffPowerValues.lua and/or localization only -- no code change here needed except for new class in CLASSES table.