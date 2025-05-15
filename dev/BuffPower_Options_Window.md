# BuffPower Options Window: PallyPower-Style Assignment Grid Plan

---

## Objective

Replace the basic BuffPower options window (formerly simple checkboxes) with a full-featured "assignment grid" for configuring which buffs are tracked and enabled per class, mirroring the PallyPower approach but for all buffer classes.

---

## Features & Requirements

1. **Grid Layout**
    - **Columns:** All player classes. (Warrior, Rogue, Priest, Druid, Paladin, Hunter, Mage, Warlock, Pet)
    - **Rows:** All buffable spells, grouped by caster type (Mage, Priest, Druid, ...).
    - **Cells:** 
        - If the intersecting class can receive the buff, show icon & state.
        - If not, grey out the cell.
    - **Icons:** 
        - Assigned (enabled): single-target buff icon.
        - Unassigned: empty slot/grey.
        - Group buff icon (right of row): always visible if the group spell exists.

2. **Interactivity**
    - **Click cell icon:** Enable/disable the buff for the class (update BuffPowerDB and UI).
    - **Click group icon:** Try to buff the group (if buffer class/player, cast appropriate group spell; otherwise, show tooltip).
    - **Hover:** Tooltip displays buff and class info.
    - **Cell background:** Green = enabled/assigned, Red = missing/disabled, Grey = ineligible.

3. **Behavior**
    - Changes are saved to BuffPowerDB and persist per character/profile.
    - Assignment settings only determine which buff buttons/backgrounds are shown; group buffs can always be cast as long as spell is known, regardless of assignment status.
    - When a buff is enabled for a class, the main UI shows the buff button and signals missing/coverage.

---

## Technical Approach

### Data Layer

- Store per-class, per-buff assignments in BuffPowerDB:
    ```lua
    BuffPowerDB.buffAssignment[class][buffKey] = true/false
    ```
- Existing structure `BuffPower.BuffTypes` defines caster, target eligibility, spell names/IDs, icons, etc. Use this for grid row/col population.
- Use fixed, sorted class list for columns.

### UI Rendering

1. **Main Frame**  
   Refactor or replace the content of `BuffPower.ShowStandaloneOptions()` in [`BuffPowerOptionsWindow.lua`](../BuffPowerOptionsWindow.lua):
   - Remove checkboxes/class enable toggles.
   - Dynamically build the grid based on current data.

2. **Grid Construction**
    - For each buff type (buff row):
        - For each class (class column):
            - If eligible, draw interactive icon (enable/disable based on assignment).
            - If not eligible, draw empty/grey cell.
        - Draw a group buff icon at end of row if applicable.

3. **State/Updates**
    - On icon click, update assignments and persist to BuffPowerDB.
    - On hover, show tooltip with details.
    - When casting group buffs, run spellcast if player is buffer class.

4. **UI Patterns**
    - Use WoW’s frame API for compatibility, or (recommended for future extensibility) migrate the grid rendering to AceGUI.

---

## Mermaid Flowchart

```mermaid
flowchart TD
    A[BuffPower Options Window]
    A --> B1[Header: "Buff Assignment Grid"]
    B1 --> B2[Columns: All Classes]
    B1 --> B3[Rows: Buffs per Caster]
    B3 --> B4["Mage: Arcane Intellect"]
    B3 --> B5["Priest: Fortitude, Spirit, Shadow Prot"]
    B3 --> B6["Druid: Mark of the Wild, Thorns"]
    B4 --> C1[Icon for Each Class]
    B5 --> C2[Icon for Each Class]
    B6 --> C3[Icon for Each Class]
    B4 --> D1[Group Buff Icon]
    B5 --> D2[Group Buff Icon]
    B6 --> D3[Group Buff Icon]
    A --> E[State & Handlers]
    E --> F1[Icon Click: Toggle Enable/Disable]
    E --> F2[Group Icon: Try Cast]
    E --> F3[Tooltip]
    E --> F4[Read/Write BuffPowerDB]
```

---

## Implementation Steps

1. Remove placeholder checkboxes and class toggles in [`BuffPowerOptionsWindow.lua`](../BuffPowerOptionsWindow.lua).
2. In their place, render the new dynamic buff assignment grid.
3. Store state changes immediately in BuffPowerDB.
4. Update related display logic to reference the new assignment DB for which player buff buttons/backgrounds to show.
5. Optionally modularize grid building/layout for clarity.
6. Ensure the grid supports extensibility for possible future features (like per-group buffer assignments).

---

## Notes

- There will no longer be a "basic" or "advanced" options split—the grid becomes the main config interface.
- All current options for class/buff enabling are subsumed into the grid.
- Group buff assignment/casting is always possible from the grid row’s group icon as per requested; the grid only manages UI signals, not the actual ability to cast.
- UI major code will reside in [`BuffPowerOptionsWindow.lua`](../BuffPowerOptionsWindow.lua). Data structures leveraged/extended are defined in [`BuffPowerValues.lua`](../BuffPowerValues.lua).

---

_Last updated: 2025-05-15_