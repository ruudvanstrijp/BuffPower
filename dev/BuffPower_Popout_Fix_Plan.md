You're right, it seems the file writing is being problematic. I'll provide the full content for `dev/BuffPower_Popout_Fix_Plan.md` here so you can copy it manually.

```markdown
# BuffPower Popout Reliability Fix Plan

## 1. Problem Description

The group member popout (`BuffPowerGroupMemberFrame`) in `BuffPower.lua` does not close reliably under certain conditions:
*   If the mouse moves from a group button directly away from the addon UI, the popout closes correctly.
*   If the mouse moves from a group button onto the popout itself, and then the mouse leaves the popout, the popout often fails to close. It may require mousing over a group button again to trigger a close.

The goal is to make the popout closing mechanism robust and predictable, similar to patterns observed in addons like PallyPower.

## 2. Analysis of Current `BuffPower.lua` Logic

*   The popout frame (`BuffPowerGroupMemberFrame`) uses `SecureHandlerEnterLeaveTemplate` with `_onenter`, `_onleave`, and `_onshow` attributes set to `self:RegisterAutoHide(0.3)`. This Blizzard mechanism is intended to hide the frame when the mouse leaves it after a delay, provided the mouse doesn't enter another frame in the same auto-hide chain.
*   The group buttons (`BuffPowerGroupButton<n>`) and their internal clickable buff icons have custom `OnLeave` handlers that use `C_Timer.After` to check if the mouse is over the button or the popout, and then conditionally hide the popout.
*   The function `HideGroupMemberButtons()` is responsible for hiding individual member buttons and resetting state, but a comment explicitly states "Do not forcibly hide BuffPowerGroupMemberFrame here!", which is problematic if `RegisterAutoHide` isn't working as expected in all scenarios.
*   The current mix of `RegisterAutoHide` on the popout and custom timer logic on the trigger buttons might be conflicting or not forming a reliable auto-hide chain, leading to the observed issues.

## 3. Inspiration from `PallyPower.lua`

PallyPower uses a more explicit timer-based approach for its popouts:
*   When the mouse enters a trigger button OR the popout itself, any pending hide timer for the popout is cancelled.
*   When the mouse leaves a trigger button OR the popout itself, a timer is scheduled to hide the popout after a short delay (e.g., 0.3 seconds).
*   This ensures the popout remains visible as long as the mouse is interacting with either the trigger or the popout, and closes cleanly when the mouse moves away from both.

## 4. Proposed Solution for `BuffPower.lua`

Adopt a PallyPower-style explicit timer management system for the `BuffPowerGroupMemberFrame`.

### 4.1. Modify `BuffPowerGroupMemberFrame` (Popout Frame)

*   **Location:** Around lines 388-400 in `PopulateGroupMemberButtons` where `BuffPowerGroupMemberFrame` is created/configured.
*   **Changes:**
    *   Remove the `SecureHandlerEnterLeaveTemplate` attributes:
        *   Remove `BuffPowerGroupMemberFrame:SetAttribute("_onenter", [[self:RegisterAutoHide(0.3)]])`
        *   Remove `BuffPowerGroupMemberFrame:SetAttribute("_onleave", [[self:RegisterAutoHide(0.3)]])`
        *   Remove `BuffPowerGroupMemberFrame:SetAttribute("_onshow", [[self:RegisterAutoHide(0.3)]])`
    *   Add `OnEnter` script:
        ```lua
        BuffPowerGroupMemberFrame:SetScript("OnEnter", function(self)
            if BuffPower.hideMemberPopoutTimer then
                BuffPower:CancelTimer(BuffPower.hideMemberPopoutTimer)
                BuffPower.hideMemberPopoutTimer = nil
            end
        end)
        ```
    *   Add `OnLeave` script:
        ```lua
        BuffPowerGroupMemberFrame:SetScript("OnLeave", function(self)
            BuffPower.hideMemberPopoutTimer = BuffPower:ScheduleTimer("ActualHideGroupMemberPopout", 0.3) -- Call a new/refactored hide function
        end)
        ```

### 4.2. Modify Group Buttons (`BuffPowerGroupButton<n>`)

*   **Location:** `OnEnter` and `OnLeave` scripts for `BuffPowerGroupButton<n>` (around lines 1219-1238).
*   **Changes to `OnEnter` (currently calls `BuffPower_ShowGroupMemberFrame`):**
    *   Before calling `BuffPower_ShowGroupMemberFrame`, cancel any pending hide timer:
        ```lua
        -- Inside the OnEnter script, before showing the popout
        if BuffPower.hideMemberPopoutTimer then
            BuffPower:CancelTimer(BuffPower.hideMemberPopoutTimer)
            BuffPower.hideMemberPopoutTimer = nil
        end
        BuffPower_ShowGroupMemberFrame(self_button, self_button.groupID) -- Existing call
        ```
*   **Changes to `OnLeave`:**
    *   Replace the existing complex `C_Timer.After` logic with a simple schedule to hide:
        ```lua
        groupButton:SetScript("OnLeave", function(self_button)
            BuffPower.hideMemberPopoutTimer = BuffPower:ScheduleTimer("ActualHideGroupMemberPopout", 0.3)
        end)
        ```

### 4.3. Modify Internal Buff Icons on Group Buttons

*   **Location:** `OnEnter` and `OnLeave` scripts for the clickable buff icons created in `UpdateGroupButtonContent` (around lines 1495-1523).
*   **Changes to `OnEnter`:**
    *   Cancel any pending hide timer:
        ```lua
        -- Inside the OnEnter script for iconBtn
        if BuffPower.hideMemberPopoutTimer then
            BuffPower:CancelTimer(BuffPower.hideMemberPopoutTimer)
            BuffPower.hideMemberPopoutTimer = nil
        end
        -- Existing tooltip logic and call to BuffPower_ShowGroupMemberFrame follows
        ```
*   **Changes to `OnLeave`:**
    *   Replace existing logic with a simple schedule to hide:
        ```lua
        iconBtn:SetScript("OnLeave", function(self_icon)
            BuffPower.hideMemberPopoutTimer = BuffPower:ScheduleTimer("ActualHideGroupMemberPopout", 0.3)
            -- GameTooltip:Hide() -- Keep this if it's for the icon's own tooltip
        end)
        ```
    *   The existing GameTooltip:Hide() for the icon's specific tooltip should likely remain.

### 4.4. Create/Refactor Hide Function: `BuffPower:ActualHideGroupMemberPopout()`

*   This function will be called by the `AceTimer-3.0` scheduled by the `OnLeave` events.
*   It should replace or augment the current `HideGroupMemberButtons()` logic.
*   **Definition:**
    ```lua
    function BuffPower:ActualHideGroupMemberPopout()
        -- Check click lock: if locked, reschedule and exit
        if BuffPower._popoverLockUntil and GetTime() < BuffPower._popoverLockUntil then
            -- Reschedule the hide check shortly after the lock should expire
            local remainingLockTime = BuffPower._popoverLockUntil - GetTime()
            self.hideMemberPopoutTimer = self:ScheduleTimer("ActualHideGroupMemberPopout", remainingLockTime + 0.05) -- Reschedule just after lock
            return
        end

        if BuffPowerGroupMemberFrame and BuffPowerGroupMemberFrame:IsShown() then
            BuffPowerGroupMemberFrame:Hide()
        end

        -- Cancel the member popout's own content update ticker
        if self.MemberPopoutTicker then -- Assuming MemberPopoutTicker is stored on self (BuffPower)
            if type(self.MemberPopoutTicker.Cancel) == "function" then -- Check if it's a C_Timer object
                 self.MemberPopoutTicker:Cancel()
            elseif type(self.MemberPopoutTicker) == "table" and self.MemberPopoutTicker.handle then -- AceTimer handle
                 self:CancelTimer(self.MemberPopoutTicker.handle)
            end
            self.MemberPopoutTicker = nil
        end
        self.MemberPopoutGroupId = nil -- Reset the active group ID

        -- Hiding individual member buttons (children of BuffPowerGroupMemberFrame)
        -- is usually automatic when the parent is hidden.
        -- However, if they are managed separately or for explicit cleanup:
        for i = 1, MAX_RAID_MEMBERS do -- Or a more appropriate upper limit
            local btn = _G["BuffPowerGroupMemberButton" .. i]
            if btn and btn:IsShown() then -- Only hide if it's somehow still shown
                btn:Hide()
            end
        end

        -- Clear the timer handle that called this function
        self.hideMemberPopoutTimer = nil
    end
    ```
*   **Integration:**
    *   Replace calls to `HideGroupMemberButtons()` in the new timer logic with `BuffPower:ActualHideGroupMemberPopout()`.
    *   The original `HideGroupMemberButtons()` (lines 141-153) might still be called by `BuffPower:UpdateRoster()` (line 667) to clear popouts during roster changes. This is acceptable, as it's an immediate clear, not a mouse-event-driven one. Ensure it doesn't interfere with the new timer logic (e.g., by also clearing `BuffPower.hideMemberPopoutTimer`). It might be better for `UpdateRoster` to also call `ActualHideGroupMemberPopout`.

### 4.5. Preserve Click Lock (`_popoverLockUntil`)

*   The `_popoverLockUntil` mechanism (currently set in `PostClick` for group buff icons, line 1527) is important to prevent the popout from closing while a secure action is being processed.
*   The proposed `ActualHideGroupMemberPopout` includes a check for this lock and reschedules itself if the lock is active.

## 5. Implementation Notes

*   Ensure `BuffPower.hideMemberPopoutTimer` is consistently used to store the handle for the AceTimer scheduled to hide the popout.
*   The `0.3` second delay is a suggestion; it can be tuned.
*   The `MemberPopoutTicker` (lines 507, 1770) needs to be correctly referenced and cancelled. If it's a `C_Timer.NewTicker` object, it has a `:Cancel()` method. If it's an AceTimer handle, use `self:CancelTimer()`. The current code uses `C_Timer.NewTicker`, so `BuffPower.MemberPopoutTicker:Cancel()` should work if `BuffPower.MemberPopoutTicker` stores the ticker object.
*   The re-parenting of member buttons in the old `HideGroupMemberButtons` (`btn:SetParent(UIParent)`) should be re-evaluated. If they are always children of `BuffPowerGroupMemberFrame`, this is unnecessary and potentially inefficient. Hiding the parent frame hides its children.

By implementing these changes, the popout hiding logic will be more explicit and aligned with common robust UI patterns, resolving the reported reliability issues.
```