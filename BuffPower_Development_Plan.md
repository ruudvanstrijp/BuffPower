# BuffPower Addon Development Plan

## Current State Analysis

*   **Working/Partially Implemented:**
    *   Basic Addon Structure (Ace3, initialization, events).
    *   Roster management and class identification.
    *   Storage of buff data (spell names, IDs).
    *   Main anchor frame: draggable, lockable, right-click to open options.
    *   Vertical display of group buttons.
    *   Right-clicking a group button to cast a group buff (if player is assigned or eligible).
    *   Tooltip on group buttons showing assigned buffer and listing group members (but members are not directly clickable from tooltip for buffing).
    *   Basic options panel for show/hide, lock, scale.
    *   Basic assignment synchronization.

*   **Missing/Needs Rework:**
    1.  **Interactive Group Member Display:** The core PallyPower-like feature of mousing over a group to see *clickable* members for single-target buffs is missing. Currently, members are only listed in a non-interactive tooltip.
    2.  **Right-Click Group Member to Buff:** Dependent on the above. The mechanism to right-click a specific member representation to cast a single-target buff needs to be built.
    3.  **Advanced Buff Assignment in Options:** The current assignment (left-click group button) is player-centric. The ability for a leader to assign *any* eligible buffer (Mage, Priest, Druid) to any group via the options panel is not implemented.
    4.  **UI/Logic Inconsistencies:** Some minor issues like `BuffPowerFrame` vs. `BuffPowerOrbFrame` naming.

## Proposed Plan

**Phase 1: Implement Interactive Group Member Display and Buffing**
   This phase focuses on the core interaction of mousing over a group and buffing individual members.

   *   **Task 1.1: Create `GroupMemberFrame`**
        *   When a main group button (e.g., "Group 1") is moused over, a new, separate frame (`BuffPowerGroupMemberFrame`) will be displayed.
        *   This frame will list all members of the moused-over group.
        *   It should hide when the mouse leaves the parent group button or the `BuffPowerGroupMemberFrame` itself (unless the mouse moves onto a clickable member within it).
   *   **Task 1.2: Make Group Members Clickable for Buffing**
        *   Each player listed in the `BuffPowerGroupMemberFrame` will be represented by a clickable element (e.g., a small button or frame).
        *   This element will display the member's name and class (color-coded).
        *   **Action:** Right-clicking on a member's element will call `BuffPower:CastBuff(groupId, memberName)` to cast the appropriate single-target buff on that member.
        *   The `BuffPower:CastBuff` function already has logic for single-target casting, which should be leveraged.

   *Diagram for Mouse-over Interaction:*
   ```mermaid
   graph TD
       A[Mouse Over Group Button] --> B{Show GroupMemberFrame};
       B --> C[Populate with Group Members];
       C --> D{Member 1 (Clickable)};
       C --> E{Member 2 (Clickable)};
       C --> F{...};
       D -- Right-Click --> G[Cast Single-Target Buff on Member 1];
       E -- Right-Click --> H[Cast Single-Target Buff on Member 2];
   ```

**Phase 2: Enhance Buff Assignment System (via Options Panel)**
   This phase allows a designated player to assign which buffer is responsible for which group.

   *   **Task 2.1: Design and Implement Buff Assignment UI in Options Panel**
        *   Modify `BuffPowerOptions.lua`.
        *   Display a list of all raid groups (1-8).
        *   For each group, provide a dropdown or list to select an eligible buffer (Mage, Priest, or Druid) from the current raid roster (`BuffPower.Roster`).
        *   Display the currently assigned buffer for each group.
        *   Include a "Clear Assignment" button for each group.
   *   **Task 2.2: Populate Eligible Buffers**
        *   The options panel UI will need to dynamically fetch and display eligible buffers from `BuffPower:GetEligibleBuffers()` or a similar roster-scanning function.
   *   **Task 2.3: Save and Synchronize Assignments**
        *   When an assignment is made, changed, or cleared in the options panel:
            *   Update `BuffPowerDB.assignments`.
            *   Call `BuffPower:SendAssignmentUpdate()` to communicate the change to other addon users in the raid/party.
            *   The main UI (group buttons) should automatically reflect these changes via existing update mechanisms.

**Phase 3: Refinements, Bug Fixing, and Code Cleanup**
   *   **Task 3.1: UI Consistency and Naming**
        *   Standardize frame names (e.g., ensure `BuffPowerOrbFrame` is used consistently for the main anchor).
        *   Review layout and appearance for clarity and adherence to WoW's UI style.
   *   **Task 3.2: Robustness of Buff Casting**
        *   Thoroughly test `BuffPower:CastBuff()` for all scenarios: player assigned, another player assigned, group unassigned, player eligible/ineligible, reagent checks.
   *   **Task 3.3: Synchronization Testing**
        *   Verify that assignments made through the options panel and actions like clearing assignments are correctly synchronized across all addon users.
   *   **Task 3.4: Debugging Output**
        *   Implement a toggle in the options (or a slash command) to enable/disable `DebugPrint` messages, or remove them if development is complete.
   *   **Task 3.5: Tooltip Enhancements**
        *   Ensure tooltips on group buttons clearly show who is assigned and which buff they provide.
        *   Tooltips on individual members in the `BuffPowerGroupMemberFrame` (if any) should be minimal, as the member element itself will convey most info.

**Clarification on "Assign Buff Groups":**
Based on your description ("mage A does group 1, 2 and 3"), the plan assumes that for each raid group, one specific player (Mage, Priest, or Druid) will be assigned as the buffer for that group. This assignment will be managed in the options panel (Phase 2). So, Mage A could be assigned to Group 1, Group 2, and Group 3 via three separate assignments in the UI.