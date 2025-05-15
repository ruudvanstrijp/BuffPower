# BuffPower Main Panel: Group Buff/Assignment & Cast Features

_Last updated: 2025-05-15_

---

## Clarified Requirements for Main (Group Buff) Window

### 6. **Group Buff Icons in Main Window**
- **For each group row** (party/raid): display all group buff icons for which the current player is eligible to cast, alongside member buff icons.
    - *Example*: Mage sees Arcane Brilliance (group) icon next to group, Priest sees Prayer of Fortitude/Spirit/Shadow Prot, Druid sees Gift of the Wild, etc.
    - Icon is always visible if you can cast that group buff, regardless of "assigned" status in the options config.

### 7. **Mage Buff Logic**
- **Single:** Arcane Intellect (single target) shown on appropriate members/slots.
- **Group:** Arcane Brilliance group icon; pressing the icon casts group buff on group.

### 8. **Priest Buff Logic**
- **Single:** Fortitude, Spirit, Shadow Protection (per-player where enabled).
- **Group:** Prayer of Fortitude, Prayer of Spirit, Prayer of Shadow Protection icons for group; pressing icon casts on whole group.

### 9. **Druid Buff Logic**
- **Single:** Mark of the Wild, Thorns (as per individual eligibility).
- **Group:** Gift of the Wild group icon (casts for full group); Thorns remains single-target.

### **User Interaction Rules**
- **Clicking group icon always buffs the group**—regardless of assignment grid settings.
- **The assignment grid in options only controls which player/member buff buttons and highlighting are visible, not group-cast availability.**
- *Visuals and UI behaviors for group buffs should align with PallyPower: show icons, highlight missing, support tooltips, etc.*

---

## Implementation Steps

1. **UI Updates**
    - Augment group rows to show all eligible group buff icons.
    - Match the row layout, spacing, and visuals to those of PallyPower for maximum familiarity.
    - Always show available group buff icons, even if the buff isn’t “assigned” in config grid.

2. **Buffing Logic**
    - Clicking a group icon attempts to cast the group buff spell for the entire group.
    - Support “fallbacks” if group buff not known (e.g., if not learned yet).
    - Tooltips show the spell name, reagent requirements, etc.

3. **Role Separation**
    - Make sure the assignment grid (options) code and main panel buffing/group logic are decoupled except that enabled buffs in config grid control which individual buttons/highlighting appear for players.
    - Group buffing is always available from the main window, reflecting the real spells your character knows.

---

## Example

| Group | ... |  Arcane Brilliance | Prayer of Fortitude | Gift of the Wild |
|-------|-----|--------------------|---------------------|------------------|
|  1    | ... |        [Icon]      |       [Icon]        |     [Icon]       |
|  2    | ... |        [Icon]      |       [Icon]        |     [Icon]       |
| ...   |     |                    |                     |                  |

Click any [Icon] to cast the group buff, regardless of the “assignment grid” in the options panel.

---

## Separation from Config/Options Logic

- All logic regarding “who should get which buff” (for tracking, red/green status, player buff buttons) remains controlled by the options window grid.
- All logic regarding **who can buff the group** (cast, visibility of group icons, spell IDs) is handled in the main/group window as above.

---

## Mermaid Diagram

```mermaid
flowchart TD
    A[Main BuffPower Panel]
    A --> B[Group Rows]
    B --> C[Player Member Buff Buttons]
    B --> D[Group Buff Icons (Arcane Brilliance, Prayer of Fortitude, Gift of the Wild, ...)]
    D --> E[On Click: Attempt Cast Group Buff]
    D --> F[Always visible if you know the spell]
    A -.-> G[Config Grid (Options Panel) only affects player button & highlight visibility, not group buff buttons]
```

---