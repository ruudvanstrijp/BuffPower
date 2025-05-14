# BuffPower Improvement Plan

This document outlines the plan to address issues and improve the BuffPower World of Warcraft addon.

## 1. Fix Unreliable Mouse-over for Group Members (Issue #2)

The current mouse-over logic for showing group members in `BuffPower.lua` is complex, leading to unreliability.

*   **Problem Area in `BuffPower.lua`:**
    *   `BuffPowerGroupMemberFrame:SetScript("OnLeave", ...)` (lines 67-73)
    *   `groupButton:SetScript("OnEnter", ...)` (lines 773-776)
    *   `groupButton:SetScript("OnLeave", ...)` (lines 777-783) - Primary handler.
    *   `groupButton:SetScript("OnLeave", ...)` (lines 807-813) - Redundant and conflicting handler.

*   **Proposed Solution:**
    1.  **Remove Redundant Handler:** Delete the `groupButton:SetScript("OnLeave", ...)` block at lines 807-813 in `BuffPower.lua`.
    2.  **Simplify Hiding Logic:**
        *   Modify the remaining `groupButton:SetScript("OnLeave", ...)` (around line 777) and the `BuffPowerGroupMemberFrame:SetScript("OnLeave", ...)` (around line 67).
        *   The goal is to hide `BuffPowerGroupMemberFrame` if the mouse is neither over the `groupButton` that triggered it NOR over the `BuffPowerGroupMemberFrame` itself.
        *   A single, slightly longer timer (e.g., 0.15s or 0.2s) in the `groupButton`'s `OnLeave` handler should be sufficient.

    *Visualizing the Mouse-Out Logic:*
    ```mermaid
    graph TD
        A[Mouse leaves GroupButton] --> B{Timer Starts (e.g., 0.15s)};
        B -- Timer Elapses --> C{Check Mouse Position};
        C -- Mouse NOT over GroupButton AND NOT over MemberFrame --> D[Hide MemberFrame];
        C -- Mouse IS over GroupButton OR MemberFrame --> E[Do Nothing / Keep MemberFrame Visible];

        F[Mouse leaves MemberFrame] --> G{Timer Starts (e.g., 0.05s, shorter)};
        G -- Timer Elapses --> H{Check Mouse Position};
        H -- Mouse NOT over GroupButton AND NOT over MemberFrame --> D;
        H -- Mouse IS over GroupButton OR MemberFrame --> E;
    ```

## 2. Fix Right-Click on Group Button for Group Buff (Issue #3)

Right-clicking a group button currently doesn't cast the group buff because `SecureActionButton_OnClick` isn't called.

*   **Problem Area in `BuffPower.lua`:**
    *   `groupButton:SetScript("OnClick", ...)` (lines 789-806).
    *   The `if mouseButton == "RightButton"` block (lines 790-797) identifies the macro but doesn't execute it.

*   **Proposed Solution:**
    1.  Modify the `OnClick` handler for `BuffPowerGroupButton`s in `BuffPower.lua`.
    2.  Inside the `if mouseButton == "RightButton" then` block, add the line:
        ```lua
        SecureActionButton_OnClick(self_button, "RightButton")
        ```

## 3. Review and Verify

*   **Single-Target Buffs (Working):** The logic for right-clicking a *member button* (lines 237-243 in `BuffPower.lua`) correctly uses `SecureActionButton_OnClick(selfB, "RightButton")` and its `type2`/`macrotext2` attributes. This serves as a good reference.
*   **Group Button Attributes:** Confirm that the `type = "macro"` and `macrotext` attributes on the group buttons (lines 768-769 in `BuffPower.lua`) are intended for the right-click action. The current `OnClick` script (lines 798-804) uses left-click to toggle the member frame.