# BuffPower - Plan for Enhanced Interaction & Click Casting

This document outlines the steps to implement click-to-cast functionality as described in Sections 3.3 and 3.4 of `BuffPower_Plan_v4.md`.

## Phase 1: Implement Clicking Specific Buff Icons

This phase focuses on allowing users to click the small buff icons displayed on group headers and player rows to cast the corresponding buff.

1.  **Modify Icon Creation in `BuffPower.lua`:**
    *   The current small buff icons (`groupHeader.buffIcons` and `playerRow.buffIcons`) are created as `Texture` objects. These need to be changed to `Button` objects to handle clicks.
    *   **Action:**
        *   In `_CreateGroupHeaderFrame` (around line 158 in `BuffPower.lua`), change `groupHeader:CreateTexture(...)` to `CreateFrame("Button", nil, groupHeader)`. A descriptive template name like `"BuffPowerSmallBuffIconButtonTemplate"` could be used if a standard XML template is preferred, but direct Lua creation is also fine.
        *   In `_CreatePlayerRowFrames` (around line 194 in `BuffPower.lua`), change `playerRow:CreateTexture(...)` to `CreateFrame("Button", nil, playerRow)`.
    *   **Button Structure:** Each new button will need its own child `Texture` to display the actual buff icon.
        *   Example: `local iconTexture = button:CreateTexture(nil, "ARTWORK")`
        *   The existing logic in `UpdateRosterUI` for setting the icon's texture (`:SetTexture()`), alpha (`:SetAlpha()`), desaturation (`:SetDesaturated()`), and vertex color (`:SetVertexColor()`) will now apply to this `iconTexture` child of the button.
    *   **Sizing and Anchoring:** Ensure the new buttons and their child icon textures are correctly sized and positioned where the old textures were.

2.  **Define Casting Functions in `BuffPower.lua`:**
    *   Create two new functions within the `BuffPower` addon table:
    *   **`function BuffPower:CastSpecificGroupBuff(buffKey, groupNum)`**
        *   **Purpose:** Casts the group version of a specified buff on the entire raid/party.
        *   **Logic:**
            1.  Get the player's class: `local PLAYER_CLASS = select(2, UnitClass("player")):upper()`
            2.  Get buff details: `local buffData = BuffPower_Buffs[PLAYER_CLASS] and BuffPower_Buffs[PLAYER_CLASS][buffKey]`
            3.  If `buffData` is nil, print an error or return.
            4.  Determine the group spell ID. Based on current `BuffPowerValues.lua` and `UpdateRosterUI` logic (e.g., `BuffPower.lua` line 568), this is likely `buffData.spellIDs[1]` (the first spell ID in the list for that buff).
            5.  Get the spell name: `local spellName = GetSpellInfo(groupSpellID)`
            6.  If `spellName` is valid, cast the spell: `CastSpellByName(spellName)` (no target needed for group buffs).
    *   **`function BuffPower:CastSpecificSingleBuff(buffKey, unitid)`**
        *   **Purpose:** Casts the single-target version of a specified buff on a specific unit.
        *   **Logic:**
            1.  Get player's class: `local PLAYER_CLASS = select(2, UnitClass("player")):upper()`
            2.  Get buff details: `local buffData = BuffPower_Buffs[PLAYER_CLASS] and BuffPower_Buffs[PLAYER_CLASS][buffKey]`
            3.  If `buffData` is nil, print an error or return.
            4.  Determine the single-target spell ID. Based on current logic (e.g., `BuffPower.lua` line 449), this is likely `buffData.spellIDs[#buffData.spellIDs]` (the last spell ID in the list).
            5.  Get the spell name: `local spellName = GetSpellInfo(singleSpellID)`
            6.  If `spellName` and `unitid` are valid, cast the spell: `CastSpellByName(spellName, unitid)`.

3.  **Attach Click Scripts in `UpdateRosterUI` (within `BuffPower.lua`):**
    *   Modify the sections where buff icons are updated to attach click scripts to the new icon buttons.
    *   **For Group Header Icon Buttons** (around `BuffPower.lua` line 561, where `groupHeader.buffIcons` are handled):
        *   When iterating through `iconIdx` for `groupHeader.buffIcons[iconIdx]`:
            *   Let `iconButton = groupHeader.buffIcons[iconIdx]`.
            *   Store necessary data on the button:
                *   `iconButton:SetAttribute("buffKey", enabledBuffListGroup[iconIdx])` (or the relevant `buffKey`)
                *   `iconButton:SetAttribute("groupNum", g)` (the current group number)
            *   Set the click script:
                ```lua
                iconButton:SetScript("OnClick", function(self)
                    local bKey = self:GetAttribute("buffKey")
                    local gNum = self:GetAttribute("groupNum")
                    if bKey and gNum then
                        BuffPower:CastSpecificGroupBuff(bKey, gNum)
                    end
                end)
                ```
    *   **For Player Row Icon Buttons** (around `BuffPower.lua` line 443, where `playerRow.buffIcons` are handled):
        *   When iterating through `iconIdx` for `playerRow.buffIcons[iconIdx]`:
            *   Let `iconButton = playerRow.buffIcons[iconIdx]`.
            *   Store necessary data on the button:
                *   `iconButton:SetAttribute("buffKey", enabledBuffList[iconIdx])` (or the relevant `buffKey`)
                *   `iconButton:SetAttribute("unitid", info.unit)` (where `info` is `roster[g][r]`)
            *   Set the click script:
                ```lua
                iconButton:SetScript("OnClick", function(self)
                    local bKey = self:GetAttribute("buffKey")
                    local uId = self:GetAttribute("unitid")
                    if bKey and uId then
                        BuffPower:CastSpecificSingleBuff(bKey, uId)
                    end
                end)
                ```

## Phase 2: Implement Cycle-Click Functionality (General Area Click)

This phase allows clicking the general area of a group header or a player row to cycle through applying needed buffs in a prioritized order.

1.  **Define Cycle-Cast Functions in `BuffPower.lua`:**
    *   Create two new functions within the `BuffPower` addon table:
    *   **`function BuffPower:CycleGroupBuffs(groupNum)`**
        *   **Purpose:** Cycles through prioritized group buffs and casts the first one needed by the specified group.
        *   **Logic:**
            1.  Get player's class: `local PLAYER_CLASS = select(2, UnitClass("player")):upper()`
            2.  Get buff priority order: `local orderedBuffs = CLASS_BUFF_ORDER[PLAYER_CLASS]` (from `BuffPower.lua` line 342). If nil, return.
            3.  Get roster for the group: `local groupMembers = roster[groupNum]` (ensure `roster` is accessible or passed).
            4.  Iterate through `orderedBuffs` (e.g., `for _, buffKey in ipairs(orderedBuffs) do ... end`).
            5.  For each `buffKey`:
                *   Check if this buff is enabled in options: `local isEnabled = BuffPower.db.profile["buffcheck_"..buffKey:lower()] ~= false`.
                *   If `isEnabled`:
                    *   Get `buffData = BuffPower_Buffs[PLAYER_CLASS][buffKey]`.
                    *   **Simplified "Needs Buff" Check for Group:**
                        *   Assume the group needs the buff if *any* member in `groupMembers` is missing it.
                        *   `local groupActuallyNeedsBuff = false`
                        *   `for _, playerInfo in ipairs(groupMembers) do`
                            *   `if playerInfo.unit and buffData.spellNames and #buffData.spellNames > 0 and (not HasAnyBuffByName(playerInfo.unit, buffData.spellNames)) then`
                                *   `groupActuallyNeedsBuff = true; break`
                            *   `end`
                        *   `end`
                    *   If `groupActuallyNeedsBuff`:
                        *   Determine group spell ID (e.g., `buffData.spellIDs[1]`).
                        *   Get spell name: `local spellName = GetSpellInfo(groupSpellID)`.
                        *   If `spellName`, cast it: `CastSpellByName(spellName)`.
                        *   `return` (to cast only one buff per cycle-click).
    *   **`function BuffPower:CycleSingleTargetBuffs(unitid)`**
        *   **Purpose:** Cycles through prioritized single-target buffs and casts the first one needed by the specified unit.
        *   **Logic:**
            1.  Get player's class: `local PLAYER_CLASS = select(2, UnitClass("player")):upper()`
            2.  Get buff priority order: `local orderedBuffs = CLASS_BUFF_ORDER[PLAYER_CLASS]`. If nil, return.
            3.  Iterate through `orderedBuffs`.
            4.  For each `buffKey`:
                *   Check if enabled in options: `local isEnabled = BuffPower.db.profile["buffcheck_"..buffKey:lower()] ~= false`.
                *   If `isEnabled`:
                    *   Get `buffData = BuffPower_Buffs[PLAYER_CLASS][buffKey]`.
                    *   **Simplified "Needs Buff" Check for Unit:**
                        *   `local unitActuallyNeedsBuff = buffData.spellNames and #buffData.spellNames > 0 and (not HasAnyBuffByName(unitid, buffData.spellNames))`
                    *   If `unitActuallyNeedsBuff`:
                        *   Determine single-target spell ID (e.g., `buffData.spellIDs[#buffData.spellIDs]`).
                        *   Get spell name: `local spellName = GetSpellInfo(singleSpellID)`.
                        *   If `spellName`, cast it: `CastSpellByName(spellName, unitid)`.
                        *   `return`.

2.  **Attach Click Scripts in UI Creation Functions (within `BuffPower.lua`):**
    *   **To Group Header Frames** (in `_CreateGroupHeaderFrame`, around `BuffPower.lua` line 139):
        *   Ensure the `groupIndex` is stored as an attribute: `groupHeader:SetAttribute("groupNum", groupIndex)`.
        *   Set the click script (using LeftButton, can be changed to RightButton if preferred):
            ```lua
            groupHeader:SetScript("OnClick", function(self, button)
                if button == "LeftButton" then -- Or "RightButton"
                    local gNum = self:GetAttribute("groupNum")
                    if gNum then
                        BuffPower:CycleGroupBuffs(gNum)
                    end
                end
            end)
            ```
    *   **To Player Row Frames** (in `_CreatePlayerRowFrames`, around `BuffPower.lua` line 178, but attributes set in `UpdateRosterUI`):
        *   In `UpdateRosterUI` (around `BuffPower.lua` line 414), when `info` (player data) is available for a `playerRow`, ensure the unit ID is stored: `playerRow:SetAttribute("unitid", info.unit)`.
        *   In `_CreatePlayerRowFrames`, set the click script for `playerRow`:
            ```lua
            playerRow:SetScript("OnClick", function(self, button)
                if button == "LeftButton" then -- Or "RightButton"
                    local uId = self:GetAttribute("unitid")
                    if uId then
                        BuffPower:CycleSingleTargetBuffs(uId)
                    end
                end
            end)
            ```

## Important Considerations for this Phase:

*   **Mouse Button for Cycle-Click:** The plan above defaults to `LeftButton` for cycle-clicks for intuitiveness. This can be changed to `RightButton` if preferred, by modifying the `if button == "..."` condition in the `OnClick` scripts.
*   **Simplified "Needs Buff" Logic:** This plan uses the existing `HasAnyBuffByName` function and basic option checks. A more comprehensive `NeedsBuff` function (checking talents, detailed assignments per target class, buff duration, stronger buffs from others, etc. as per Plan Section 4.2) is a separate, more complex task to be addressed later.
*   **`BuffPowerValues.lua` Dependency:** The logic for determining group vs. single spell IDs relies on the conventions observed in the current `BuffPowerValues.lua` (e.g., first ID for group, last for single). If this structure changes, the casting functions will need adjustment.
*   **Error Handling & Feedback:** Basic error checks (e.g., `buffData` being nil) are included. More robust user feedback (e.g., "Spell not ready," "Out of range," "Not enough mana") is not part of this immediate plan but should be considered for future polish.
*   **Testing:** Thorough testing will be required for each class (Mage, Priest, Druid) in solo, party, and raid scenarios.

This plan provides a focused approach to implementing the core click-casting features.