# BuffPower Refactoring Plan

**Overall Goals:**

1.  **Improve Code Clarity and Maintainability:** Apply DRY (Don't Repeat Yourself) and KISS (Keep It Simple, Stupid) principles.
2.  **Fix Functional Issues:** Specifically address the button color update problem for group members.
3.  **Enhance Efficiency:** Streamline UI updates and event handling.
4.  **Ensure Robustness:** Make the addon less prone to errors.

---

### Phase 1: Analysis and Deep Dive into `BuffPower.lua`

*   **1.1. Full Code Read-Through & Annotation:**
    *   Go line-by-line through `BuffPower.lua`.
    *   Identify unused local variables, global variables that could be localized, and functions that are declared but never called.
    *   Mark sections with repetitive logic (e.g., buff checking, UI element creation).
    *   Note down any overly complex functions that could be broken down.
*   **1.2. Button Color Update Investigation:**
    *   Focus on `BuffPower_ShowGroupMemberFrame` (lines 48-243), specifically the buff detection logic (lines 88-104) and the subsequent color setting (lines 106-112, 142-146).
    *   Examine the `UpdateBackdrop` function within `BuffPowerGroupMemberFrame` (lines 149-178) and its `C_Timer.NewTicker` (lines 186-190). This is a prime suspect for color update issues, as frequent polling can be problematic and might not always reflect the latest state immediately after a buff.
    *   Analyze the `PostClick` event for member buttons (lines 213-230) and group buttons (lines 764-771) to see how and when roster/UI updates are triggered. The `C_Timer.After` calls might introduce delays or race conditions.
*   **1.3. UI Update Flow Mapping:**
    *   Trace the calls from events like `GROUP_ROSTER_UPDATE` to `UpdateRoster`, then to `UpdateUI`, and finally to `PositionGroupButtons` and `UpdateGroupButtonContent`.
    *   Visualize this flow (potentially with a Mermaid sequence diagram) to identify bottlenecks or redundant updates.
    *   ```mermaid
        sequenceDiagram
            participant Event
            participant BuffPower
            participant UIParent
            Event->>BuffPower: GROUP_ROSTER_UPDATE
            BuffPower->>BuffPower: UpdateRoster()
            BuffPower->>BuffPower: UpdateUI()
            BuffPower->>BuffPower: PositionGroupButtons()
            loop For each visible group button
                BuffPower->>BuffPower: UpdateGroupButtonContent(button, groupId)
            end
            BuffPower->>UIParent: Modify UI Frames
            Note right of BuffPower: Button color logic resides here
        ```
*   **1.4. Data Management Review:**
    *   How is `BuffPowerDB` (the AceDB profile) accessed and modified? Look for direct modifications versus using AceDB API methods if applicable.
    *   How is static data from `BuffPowerValues.lua` (e.g., `BuffPower.ClassBuffInfo`, `BuffPower.ClassColors`) used? Is it accessed efficiently?

---

### Phase 2: Refactoring Strategy & Proposed Changes

*   **2.1. General Cleanup:**
    *   **Remove Unused Code:** Delete identified unused variables and functions.
    *   **Consolidate Constants:** Review constants at the top of `BuffPower.lua` (lines 24-35). Some might be better placed in `BuffPowerValues.lua` or derived dynamically if they relate to UI element sizes that change.
    *   **Function Decomposition:**
        *   `BuffPower_ShowGroupMemberFrame` is very long. Break it down:
            *   `CreateOrResetGroupMemberFrame()`: Handles frame creation/clearing.
            *   `PopulateGroupMemberButtons(groupId, members, buffInfo)`: Handles creating and setting up individual member buttons.
            *   `UpdateMemberButtonAppearance(button, member, buffInfo)`: Handles setting text, color, and tooltip for a single member button (this will be key for the color fix).
        *   `CreateUI` can also be broken down:
            *   `CreateMainAnchorFrame()`
            *   `CreateGroupButtonFrames()`
    *   **Helper Functions:** Create helper functions for common tasks, e.g., a robust `HasBuff(unitId, spellNameOrId)` function that can be used consistently.
*   **2.2. Fixing Button Color Updates & UI Reactivity:**
    *   **Event-Driven Updates:** Instead of relying heavily on `C_Timer.NewTicker` in `BuffPowerGroupMemberFrame` for buff status, make updates more event-driven.
        *   After a buff is cast (successfully), explicitly trigger a refresh of the relevant UI elements. The `UNIT_AURA` event could be leveraged to detect buff changes on units in the roster.
        *   The `PostClick` scripts for buff buttons should directly call a function to update the appearance of the affected member button(s) or the entire group member frame if necessary, rather than just `UpdateRoster` which is a heavier operation.
    *   **Centralized Buff State Check:**
        *   Create a function `BuffPower:GetUnitBuffState(unitId, class)` that checks if a unit has the relevant buff for their class (or the player's class if checking for player buffs). This function would encapsulate the `UnitAura` iteration.
    *   **Refactor `UpdateMemberButtonAppearance` (from 2.1):**
        *   This new function will take a member button, the member's data, and buff info.
        *   It will call `BuffPower:GetUnitBuffState` to determine `needsBuff`.
        *   It will then set the `label` text color and `bg` texture color accordingly.
    *   **Immediate Feedback on Click:**
        *   When a member button is clicked to cast a spell:
            1.  Play the animation.
            2.  *Immediately* update that specific button's appearance to "buffed" optimistically (or based on a quick local check if possible, though `UNIT_AURA` is more reliable for actual application).
            3.  Schedule a more thorough `UpdateRoster` or targeted UI refresh after a short delay (e.g., 0.5-1s) to catch any discrepancies or if the buff failed. This addresses the perceived lag.
*   **2.3. Streamlining UI Management:**
    *   **Frame Creation:** Ensure frames are created only once and reused. The current code seems to do this for `BuffPowerGroupMemberFrame` (line 50) and `BuffPowerOrbFrame` (line 575), which is good.
    *   **`UpdateUI` Simplification:** `UpdateUI` should primarily decide if the main frame is shown/hidden and then call `PositionGroupButtons`. The actual content update of buttons should be more targeted.
    *   **`PositionGroupButtons` and `UpdateGroupButtonContent`:**
        *   `PositionGroupButtons` determines which group buttons are visible and their positions.
        *   `UpdateGroupButtonContent` updates the text, icon, and *assigned buffer* status of a group button. This seems mostly fine but ensure it's called efficiently.
*   **2.4. Roster Management (`UpdateRoster`):**
    *   The logic in `UpdateRoster` (lines 291-370) for handling solo, party, and raid scenarios, including fallbacks for different API availabilities (e.g., `GetRaidSubgroup` vs `GetRaidRosterInfo`), is inherently complex in WoW.
    *   Review for clarity and potential micro-optimizations, but major changes might be risky if it's currently working correctly for all group types. Ensure `DebugPrint` statements are removed or conditional for release.
    *   The check `BuffPower:IsPlayerInRoster()` and subsequent re-adding of the player if not found (lines 341-366) seems a bit defensive; investigate if the initial loop can reliably include the player.
*   **2.5. Data Access:**
    *   Continue using `BuffPower.ClassBuffInfo` etc., from `BuffPowerValues.lua` as it centralizes static data.
    *   Ensure all `BuffPowerDB` access is consistent (e.g., `BuffPowerDB.assignments`).
*   **2.6. Event Handling:**
    *   Review all registered events in `OnEnable`.
    *   Ensure `ADDON_LOADED` (line 1116) correctly handles options panel creation. The current logic with `BuffPower.optionsPanelCreated` seems okay.
    *   Consider if `UNIT_AURA` should be registered (perhaps only when the group member frame is visible, or for all roster members) to provide more reactive updates to buff states. This needs careful handling to avoid performance issues.

---

### Phase 3: Verification and Testing (Conceptual)

*   **Unit Testing (Mental or Actual):** For each refactored function, mentally walk through its logic with different inputs.
*   **Functional Testing In-Game:**
    *   **Solo, Party, Raid:** Test all functionalities in these three scenarios.
    *   **Button Color Updates:**
        *   Buff a member: Does their button color change immediately and correctly?
        *   Buff expires: Does the color revert (this might require `UNIT_AURA` or more frequent checks if the member frame is open)?
        *   Another player buffs: Does the UI reflect this after a roster/UI update?
    *   **Mouseover Functionality:** Group buttons show member lists, member buttons are clickable.
    *   **Buff Casting:** Group buffs and single-target buffs work as intended.
    *   **Assignments:** Assigning buffers works, and UI updates accordingly.
    *   **Options Panel:** All options in `BuffPowerOptions.lua` work and save correctly.
    *   **Slash Commands:** Test all slash commands.
    *   **No Lua Errors:** Use a bug-catching addon or `/console scriptErrors 1`.