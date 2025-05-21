# BuffPower Addon: Outstanding Feature Checklist  
*Audit vs. [`BuffPower_Plan_v4.md`](dev/BuffPower_Plan_v4.md)*  
_Last audit: 2025-05-20_

---

## 🚦 Status Table

| Feature / Plan Section                                                    | Status              | Gap / Implementation Notes |
|---------------------------------------------------------------------------|---------------------|---------------------------|
| **Ace3 Addon setup & event handling**                                     | ❌ Not implemented  | No AceAddon, AceDB, OnInitialize/OnEnable, event registration, or slash command logic |
| **Group-centric UI (8 groups, group/player buttons, icons, cycles)**      | ⚠️ Partial / stub   | Only header/player row functions, no full SetupFrames, UpdateRoster, frame creations, or Lua↔XML linkage |
| **Buff definitions/constants**                                            | ✔️ Complete         | [`BuffPowerValues.lua`](BuffPowerValues.lua:1) holds base data |
| **Assignment grid (per-buff, per-class options grid)**                    | ❌ Not implemented  | No assignment grid, toggles, or dynamic option population code |
| **Optional buff control**                                                 | ❌ Not implemented  | No `optionalBuffsEnabled` or toggles present |
| **Dynamic buff logic (NeedsBuff, Spell/Talent detection, application)**   | ❌ Not implemented  | No `NeedsBuff`, `ScanPlayerBuffsAndTalents`, `PlayerHasTalent`, or application logic for cycles |
| **Cycle buffing (cycle group/player click, cast handlers)**               | ❌ Not implemented  | No cycle/cast logic found |
| **AceEvent handler integration**                                          | ❌ Not implemented  | No event registration for roster/talents/auras or updates |
| **Responsibility sync (AceComm)**                                         | ❌ Not implemented  | No sync, comm, or responsibility code present |
| **Minimap icon/LDB support**                                              | ❌ Not implemented  | No LDB, AceDBIcon logic |
| **Localization (AceLocale, user-facing strings)**                         | ⚠️ Scaffold only    | [`enUS.lua`](Locales/enUS.lua:1) exists but not integrated in code |
| **Options window (AceConfig-3.0)**                                        | ❌ Not implemented  | No AceConfig logic, only table stub |
| **Testing/QA scaffolds, polish, documentation**                           | ❌ Not present      | No scaffolding, code polish/evidence of QA routines |

---

## Detailed TODOs

### 1. Ace3 Boilerplate & Setup
- Integrate with AceAddon-3.0, AceConsole-3.0, AceDB-3.0, and AceEvent-3.0
- Create OnInitialize, OnEnable, OnDisable handlers
- Register `/bp` and `/buffpower` slash commands

### 2. Main UI (Group-Based)
- Implement dynamic creation & placement of 8 group headers and buttons
- Mouse-over group headers for player button display
- Per-group and per-player clickable buff icons (group & single-target abilities)
- Cycle-click logic for group/player buttons

### 3. Buff Logic & Data
- Implement buff eligibility logic (`NeedsBuff`)
- Detect spells and relevant talents
- Ensure buff check, application, and assignment logic per plan

### 4. Options / Assignment UI
- Add AceConfig-3.0 driven options window
- Implement assignment grid (buffs x classes), with toggle logic
- Add optional buff toggles

### 5. Event, Roster & State Management
- Register for all planned WoW events (roster, talent changes, auras)
- Implement raid/group roster tracking and update flows

### 6. Responsibility Sync
- Implement AceComm sync of group responsibilities
- Show responsibility state in UI

### 7. Minimap Icon & LDB Support
- Add LibDataBroker-1.1 integration and AceDBIcon-1.0 handling

### 8. Localization
- Integrate AceLocale and shift all user-facing strings to L[] lookups

### 9. Testing, Polish, Documentation
- Add code comments, cleanup, and polish steps
- Prepare QA/test cases as stated in the plan

---

## Legend  
✔️ = Fully present  
⚠️ = Partial/stub/minimal  
❌ = Not implemented