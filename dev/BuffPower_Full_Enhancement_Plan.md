# BuffPower Full Enhancement Plan

**Overall Goals:**

1.  Implement dynamic group coloring based on buff coverage.
2.  Display the shortest remaining buff duration for each group.
3.  Modernize the UI to be "sleeker," drawing inspiration from PallyPower's visual elements like larger group displays and thin, dark borders.

---

## Phase 0: Preparation &amp; Understanding

*   **0.1. Backup Project:**
    *   **Action:** Create a complete backup of your current BuffPower addon directory.
    *   **Rationale:** Safeguard against any issues during development.
*   **0.2. Review `BuffPower.lua` Core Logic:**
    *   **Action:** Identify key functions related to:
        *   Creating and updating group/player UI elements.
        *   Detecting player buffs (likely using `UnitAura`).
        *   Handling mouse clicks for buffing.
        *   Iterating through groups and raid/party members.
    *   **Rationale:** Understand where new logic and UI changes will integrate.
*   **0.3. Analyze `PallyPower.lua` for UI Styling (if available and relevant):**
    *   **Action:** If PallyPower's code is accessible, focus on these sections:
        *   `CreateLayout`: How frames (groups, player popups) are initially created.
        *   `UpdateLayout`: How frames are positioned and configured.
        *   `ApplySkin`: How base textures for borders and backgrounds are applied.
        *   `ApplyBackdrop`: How backdrop colors are dynamically changed (e.g., based on buff need).
        *   Note the use of `LSM3` (LibSharedMedia-3.0) for fetching textures and fonts.
        *   Note default values for colors, sizes, etc.
    *   **Rationale:** Understand the techniques PallyPower uses to achieve its look, which will inform BuffPower's redesign. If PallyPower code isn't available, focus on visual analysis of its UI.

---

## Phase 1: Feature - Group Color Status (Red/Green)

*   **1.1. Define Buffs to Track:**
    *   **Action:**
        *   Ensure `BuffPowerValues.lua` (or a similar configuration area within `BuffPower.lua`) clearly defines the primary group buff spell ID(s) for each supported class.
        *   **Mages:** Arcane Brilliance (group), Arcane Intellect (single-target for fallback/individual logic).
        *   **Priests:** Prayer of Fortitude (group), Power Word: Fortitude (single-target).
        *   **Druids:** Gift of the Wild (group), Mark of the Wild (single-target).
        *   Verify these spell IDs are correct for the target WoW expansion.
    *   **Rationale:** The addon needs precise spell IDs to correctly identify the buffs.
*   **1.2. Implement Buff Checking Logic:**
    *   **Action: Create/Refine `BuffPower:IsUnitMissingBuff(unitId, class, buffSpellId)`**
        *   Takes `unitId`, `class` of the unit, and the specific `buffSpellId` to check.
        *   Use `UnitAura(unitId, GetSpellInfo(buffSpellId))` or iterate auras.
        *   Return `true` if buff is missing/expired, `false` otherwise.
    *   **Action: Create `BuffPower:IsGroupMissingBuff(groupIndex)`**
        *   Determines overall buff status for a `groupIndex`.
        *   Identify player's class (`UnitClass("player")`) to know which buff *they* provide.
        *   Iterate valid and present members of `groupIndex`.
        *   For each member, call `BuffPower:IsUnitMissingBuff(memberUnitId, memberClass, relevantGroupBuffSpellId)`.
        *   If *any* member is missing the buff (and should receive it), return `true`.
        *   Else, return `false`.
    *   **Rationale:** Core logic for determining group status.
*   **1.3. UI Update for Group Color:**
    *   **Action:** In the main UI update function (e.g., `BuffPower:UpdateDisplay()`):
        *   For each group frame:
            *   Call `BuffPower:IsGroupMissingBuff(groupIndex)`.
            *   If `true`, set group frame background to **red** (e.g., `groupFrame:SetBackdropColor(unpack(self.db.profile.colors.groupMissingBuff))`).
            *   If `false`, set to **green** (e.g., `groupFrame:SetBackdropColor(unpack(self.db.profile.colors.groupBuffed))`).
    *   **Action: Define Color Constants/Configuration:**
        *   Store colors in `BuffPowerValues.lua` or SavedVariables (`self.db.profile.colors`).
        *   Example defaults:
          ```lua
          BuffPower.defaults.profile.colors = {
              groupMissingBuff = {0.8, 0.2, 0.2, 0.7}, -- Red
              groupBuffed = {0.2, 0.8, 0.2, 0.7},     -- Green
          }
          ```
    *   **Rationale:** Visually represent buff status; allow customization.
*   **1.4. Event Triggers:**
    *   **Action:** Ensure UI update is called on:
        *   `UNIT_AURA` (use `AceBucket-3.0` for throttling if needed).
        *   `GROUP_ROSTER_UPDATE`.
        *   `PLAYER_ENTERING_WORLD`.
        *   Custom event after BuffPower casts a buff.
    *   **Rationale:** Keep display accurate and responsive.

---

## Phase 2: Feature - Group Buff Timer

*   **2.1. Implement Buff Duration Logic:**
    *   **Action: Create `BuffPower:GetShortestGroupBuffDuration(groupIndex)`**
        *   Initialize `minDuration` to `math.huge` or `nil`.
        *   Identify the relevant group buff spell ID based on the player's class.
        *   Iterate valid/present members of `groupIndex`.
        *   For each member, find the relevant group buff using `UnitAura`.
        *   If buff present, get `expirationTime`. If `expirationTime > 0`, calculate `remaining = expirationTime - GetTime()`.
        *   If `remaining > 0`, update `minDuration = math.min(minDuration or remaining, remaining)`.
        *   Return `minDuration` (or `nil`/0 if no relevant buff or all expired/infinite).
    *   **Rationale:** Determine the shortest time before a re-buff might be needed for the group.
*   **2.2. Create Timer UI Element:**
    *   **Action:** For each group frame, create a `FontString` for the timer.
        *   Example: `groupFrame.durationText = groupFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")`
        *   Position it (e.g., bottom right of group frame).
    *   **Rationale:** Visual element for the timer.
*   **2.3. UI Update for Timer:**
    *   **Action:** In the main UI update function (or a dedicated timer update function called by it):
        *   For each group frame:
            *   Call `BuffPower:GetShortestGroupBuffDuration(groupIndex)`.
            *   If a valid `duration > 0`:
                *   Format: `local m = math.floor(duration / 60); local s = math.fmod(duration, 60); groupFrame.durationText:SetText(string.format("%d:%02d", m, s));`
                *   Show `durationText`.
            *   Else:
                *   `groupFrame.durationText:SetText("")` or hide it.
    *   **Rationale:** Display the calculated shortest duration.
*   **2.4. Periodic Timer Update:**
    *   **Action:** Use `AceTimer-3.0` to schedule a repeating function (e.g., `BuffPower:UpdateAllGroupTimers()`) to run every second. This function iterates through groups and updates their `durationText` by recalculating or decrementing.
        *   Alternatively, the main `UpdateDisplay` (if throttled by AceBucket for `UNIT_AURA`) can update timers, and a separate 1-second AceTimer can *force* an update if no other events occurred.
    *   **Rationale:** Keep timers ticking down accurately without excessive `OnUpdate` load.

---

## Phase 3: Visual Design Overhaul (Sleeker UI)

*   **3.1. Adopt PallyPower's Frame Structure (Conceptual):**
    *   **Reference:** PallyPower's main `Header` frame, with "Class" buttons (your "Group" buttons) parented to it. "Player" buttons parented to "Class" buttons, shown on mouseover.
    *   **Action:** Ensure BuffPower group frames are well-defined. Style the mouseover player list.
*   **3.2. Group Frame Styling:**
    *   **A. Larger Group UI Elements:**
        *   **Action:** In `BuffPower.lua` (where group frames are sized), increase `width` and `height`. Define these in `BuffPowerValues.lua` or `self.db.profile.display` for configurability (e.g., `buttonWidth`, `buttonHeight`).
    *   **B. Thin, Darker Border:**
        *   **Action:** Apply a backdrop with a thin edge.
            ```lua
            -- In BuffPowerValues.lua or defaults
            -- self.db.profile.display.borderColor = {0.1, 0.1, 0.1, 1} -- Nearly black
            -- self.db.profile.display.borderTexture = "Interface\\ChatFrame\\ChatFrameBackground"
            -- self.db.profile.display.edgeSize = 1

            -- Inside group frame setup:
            groupFrame:SetBackdrop({
                bgFile = nil, -- Background controlled by red/green status or a default sleek texture
                edgeFile = self.db.profile.display.borderTexture or "Interface\\ChatFrame\\ChatFrameBackground",
                tile = false,
                tileSize = 16,
                edgeSize = self.db.profile.display.edgeSize or 1,
                insets = { left = 0, right = 0, top = 0, bottom = 0 }
            });
            groupFrame:SetBackdropBorderColor(unpack(self.db.profile.display.borderColor or {0.1,0.1,0.1,1}));
            ```
        *   **Note:** Consider using `LSM3:Fetch("border", self.db.profile.borderSkin)` for user skinning if LSM is integrated.
    *   **C. Sleek Background:**
        *   **Action:** The red/green color feature will now dominate the background. Ensure alpha provides good readability.
        *   Define a default background color/texture in `self.db.profile.display.backgroundColor` if not red/green.
*   **3.3. Player List (Mouseover) Styling:**
    *   **Action:** Apply similar styling to the mouseover player list frames:
        *   Thin, dark border.
        *   Clean background (perhaps a slightly darker/desaturated shade).
        *   Clear, legible player names.
*   **3.4. Font and Text Styling:**
    *   **Action:**
        *   Use `LSM3` to select/allow configuration of a clean font (e.g., `self.db.profile.display.fontFace`). Default to a standard game font like `GameFontNormal`.
        *   Ensure consistent font sizes for group names/numbers, player names, timer. Make these configurable.
        *   Text color should contrast well. White or light gray is often safe. Configurable via `self.db.profile.display.fontColor`.
*   **3.5. Spacing and Padding:**
    *   **Action:** Review overall layout.
        *   Ensure configurable spacing between group buttons (`self.db.profile.display.buttonSpacing`).
        *   Ensure text/icons within buttons have padding.

---

## Phase 4: Integration, Testing &amp; Refinement

*   **4.1. Code Integration:**
    *   **Action:** Carefully merge new feature logic (Phases 1 & 2) into existing UI update routines.
    *   Apply visual style changes (Phase 3) to all relevant UI elements.
*   **4.2. Event Handling Review:**
    *   **Action:** Confirm all necessary WoW API events and AceEvent-3.0 events are registered and correctly trigger UI updates.
*   **4.3. Performance Considerations:**
    *   **Action:** Be mindful of CPU usage. Avoid redundant calculations in frequently called updates. Profile if necessary.
*   **4.4. Comprehensive Testing:**
    *   **Action:** Test thoroughly in various scenarios:
        *   Solo, party (5-man), raid (10/25/40-man).
        *   Players joining/leaving, dying, offline, out of range.
        *   Buffs expiring, dispelled, reapplied.
        *   All supported classes and their buffs.
        *   Interaction with existing right-click buffing.
        *   Anchor dragging, locking, scaling.
        *   Test all configuration options.
*   **4.5. Iterative Refinement:**
    *   **Action:** Adjust sizes, colors, fonts, positions based on testing and feedback until it feels right and looks "sleek."
    *   Update `BuffPowerOptions.lua` to include new configurable settings (colors, fonts, sizes, spacing).

---
This plan provides a structured approach. Tackle one major feature or aspect at a time, testing as you go.
