Okay, I understand. We'll remove the keybinding section and add the "right-click to single-target buff first needy member" feature to the `dev/BuffPower_Further_Enhancements_Plan.md`.

Here's the revised content for the plan:

```markdown
# BuffPower Further Enhancements Plan (Inspired by PallyPower)

This plan outlines additional features and improvements for BuffPower, drawing inspiration from common functionalities and a polished user experience found in addons like PallyPower.

## 1. Enhanced Buff Timer Display on Group Buttons

*   **Objective:** Provide a clear, at-a-glance indication of the buff status for an entire group directly on the main group buttons, including the shortest remaining duration.
*   **Current State:** `BuffPower` has a function `GetShortestGroupBuffDuration` (around line 753) but doesn't prominently display this on the group buttons. Group buttons primarily show color status and icons for player-castable group buffs.
*   **Proposed Action:**
    1.  **Modify `BuffPower:UpdateGroupButtonContent` (around line 1344):**
        *   Call `self:GetShortestGroupBuffDuration(groupId)`.
        *   If a valid duration is returned, format it (e.g., "M:SS" or "SSs") and display it on the group button's timer text element (`button.time`).
        *   Ensure the timer text is clearly visible and updates with the 1-second `RefreshUIVisuals` cycle.
        *   If no relevant buffs are active or all are missing for the assigned buff type, the timer text should be cleared or show "N/A".
    2.  **Visuals:**
        *   The timer could change color (e.g., to yellow/red) when duration is low (e.g., < 60 seconds, < 30 seconds). This can be configured in options.
*   **PallyPower Inspiration:** PallyPower clearly shows buff timers, making it easy to see when rebuffs are needed.

## 2. Visual Cues for Player Status (Range/Dead/Offline)

*   **Objective:** Make it easier for the user to see if group members (in the popout) or entire groups (on the main buttons) are unbuffable due to being out of range, dead, or offline.
*   **Current State:** Roster updates check `UnitExists`. Member buttons show name/class. Group buttons show overall buff status.
*   **Proposed Action:**
    1.  **Modify `UpdateMemberButtonAppearance` (for individual member buttons in popout, around line 157):**
        *   For each member, check:
            *   `UnitIsConnected(member.unitid)`
            *   `UnitIsDeadOrGhost(member.unitid)`
            *   `CheckInteractDistance(member.unitid, 3)` (for buffing range - typically 30-40 yards, use appropriate distance unit for `CheckInteractDistance`).
        *   If offline: Fade the button significantly, change text color to grey.
        *   If dead/ghost: Fade the button, perhaps add a small skull icon or change border color.
        *   If out of range: Slightly fade the button or change text color to a muted version.
        *   These visual changes should take precedence over missing buff colors if the player is unbuffable.
    2.  **Modify `BuffPower:UpdateGroupButtonContent` (for main group buttons):**
        *   If *all* eligible members of a group are dead/offline/out-of-range, the main group button could also adopt a distinct visual state (e.g., heavily desaturated background) to indicate the group is largely unbuffable. This is more complex as it requires iterating all members. A simpler approach might be to just rely on the member popout for this detail.
    3.  **Roster Data:** Ensure `BuffPower:UpdateRoster` gathers the necessary `unitid`s that work reliably with these status check functions.
*   **PallyPower Inspiration:** Many unit frame and raid addons provide clear visual distinctions for player status.

## 3. Right-Click Group Button for Single-Target Buffing

*   **Objective:** Allow users to right-click a main group button to cast the appropriate single-target buff on the first member of that group who needs it and is eligible.
*   **Current State:** Group buttons are SecureActionButtons primarily configured for group buffs. Right-click functionality is not specifically defined for this purpose.
*   **Proposed Action:**
    1.  **Modify Group Button Setup (`BuffPower:CreateUI` or `UpdateGroupButtonContent` where buttons are configured, around line 1158):**
        *   The group buttons (`BuffPowerGroupButton<n>`) are already `SecureActionButtonTemplate`. We need to ensure right-click can trigger a different behavior or a conditional spell cast.
        *   One approach is to use the `type2`, `spell2`, `unit2` attributes if they can be made conditional or point to a macro.
        *   A more flexible approach might involve changing the `type` attribute on right-click or using a more complex macro. However, secure action templates have limitations on dynamic attribute changes during combat.
    2.  **Preferred Secure Method: Macro-based approach:**
        *   Set the group button's right-click action to execute a macro.
        *   `groupButton:SetAttribute("type2", "macro")`
        *   `groupButton:SetAttribute("macrotext2", "/click BuffPowerSingleTargetHelper <groupID>")` (or similar, where `<groupID>` is the actual group ID).
    3.  **Create a Helper Frame/Button (`BuffPowerSingleTargetHelper`):**
        *   This would be a hidden, small, secure button.
        *   `BuffPowerSingleTargetHelper = CreateFrame("Button", "BuffPowerSingleTargetHelper", UIParent, "SecureActionButtonTemplate")`
        *   `BuffPowerSingleTargetHelper:SetAttribute("type", "spell")`
        *   This helper button's `OnClick` script (non-secure part) would be:
            ```lua
            BuffPowerSingleTargetHelper:SetScript("OnClick", function(self, button, down, groupId) -- groupId passed from macro
                local playerClass = select(2, UnitClass("player"))
                local members = BuffPower:GetGroupMembers(tonumber(groupId))
                local buffToCast = nil
                local targetUnit = nil

                -- Iterate through all buff types the player can cast
                for buffKey, buffData in pairs(BuffPower.BuffTypes or {}) do
                    if buffData.buffer_class == playerClass and buffData.single_spell_name then
                        -- Check if this buff is enabled (if optional)
                        local enabled = true
                        if buffData.is_optional then
                            if not BuffPowerDB or not BuffPowerDB.buffEnableOptions or BuffPowerDB.buffEnableOptions[buffKey] == false then
                                enabled = false
                            end
                        end
                        -- Check talent requirement
                        if buffData.requires_talent and playerClass == "PRIEST" and not BuffPower:PlayerHasDivineSpiritTalent() then
                            enabled = false
                        end

                        if enabled then
                            for _, member in ipairs(members) do
                                if BuffPower:NeedsBuffFrom(playerClass, member.class, buffKey) then
                                    local isMissing = true -- Assume missing, then verify
                                    local idx = 1
                                    while true do
                                        local name, _, _, _, _, _, _, _, _, spellId = UnitAura(member.unitid, idx, "HELPFUL")
                                        if not name then break end
                                        if (spellId == buffData.single_spell_id or spellId == buffData.group_spell_id) or
                                           (name == buffData.single_spell_name or name == buffData.group_spell_name) then
                                            isMissing = false
                                            break
                                        end
                                        idx = idx + 1
                                    end

                                    if isMissing and UnitIsConnected(member.unitid) and not UnitIsDeadOrGhost(member.unitid) and CheckInteractDistance(member.unitid, 3) then
                                        buffToCast = buffData.single_spell_name
                                        targetUnit = member.unitid -- or member.name if unitid isn't reliable for CastSpellByName target
                                        goto found_target_and_buff -- Exit both loops
                                    end
                                end
                            end
                        end
                    end
                end
                ::found_target_and_buff::

                if buffToCast and targetUnit then
                    self:SetAttribute("spell", buffToCast)
                    self:SetAttribute("unit", targetUnit)
                    -- The macro click will now execute this configured spell/unit
                else
                    -- No one needs a buff, or no valid target. Clear attributes.
                    self:SetAttribute("spell", nil)
                    self:SetAttribute("unit", nil)
                    if BuffPower.debug then BuffPower:Print("No eligible member found needing a single-target buff in group " .. groupId) end
                end
            end)
            ```
    4.  **Registration for Clicks:**
        *   The main group buttons (`BuffPowerGroupButton<n>`) need to be registered for right-clicks: `groupButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")`.
        *   Their `OnClick` or `PostClick` script would need to differentiate between left and right clicks if the left click still performs the group buff directly. If left-click also uses a macro, then `macrotext` and `macrotext2` would be used.
        *   The current group buttons are set up with `SecureActionButtonTemplate` and attributes for group buffs on left-click. This new right-click macro should not interfere if `type2` and `macrotext2` are used.
*   **PallyPower Inspiration:** PallyPower's right-click functionality on assignments provides a quick way to buff individuals.

## 4. Version Checking in Addon Communication

*   **Objective:** Help users diagnose issues when interacting with other BuffPower users who might have an incompatible addon version.
*   **Current State:** No version checking in comms.
*   **Proposed Action:**
    1.  **Define Addon Version:** Store a simple version number (e.g., `BuffPower.version = "1.2.3"`) at the top of `BuffPower.lua`.
    2.  **Include Version in Messages:**
        *   When sending `ASSIGN_GROUP` or `REQ_ASSIGN` messages, append the version:
            `msg = string.format("ASSIGN_GROUP %d %s %s V:%s", groupId, playerName, playerClass, BuffPower.version)`
    3.  **Process Version in `OnAddonMessage`:**
        *   When receiving a message, parse out the sender's version.
        *   If the sender's version is significantly different (e.g., major version mismatch, or if a known compatibility break exists between minor versions), print a one-time, throttled warning to the user:
            `"BuffPower: User [SenderName] is using version [SenderVersion], which may be incompatible with your version [MyVersion]."`
    4.  **Optional: Version Request/Reply:**
        *   A dedicated `VERSION_CHECK` message could be sent on group join to proactively check versions with other BuffPower users.
*   **PallyPower Inspiration:** Many communication-heavy addons include version checking to aid troubleshooting.

## Implementation Considerations:

*   These features can be implemented incrementally.
*   UI changes for status (range/dead) should be tested for performance impact, ensuring they don't add significant overhead to the UI refresh cycle.
*   The right-click single-target buffing logic needs careful implementation to respect secure action button limitations and correctly identify the target and buff. The macro helper button approach is generally robust.
*   Version checking should be simple and non-intrusive.

By implementing these enhancements, BuffPower can offer a more informative, accessible, and robust user experience.
```