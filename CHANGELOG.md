# BuffPower Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

**Testing status**: checked visually on the WoW Forever beta, solo only. Not yet tested on Classic Era or TBC Anniversary; that is planned for November 2026. The rewritten in-combat player list only runs on Classic Era and TBC Anniversary (Forever has no secure snippets), so it has not been tested anywhere yet.

### Added
- **Button Width Sliders**: Two new sliders in the options set the width of the group buttons (115 to 180 pixels) and the player buttons (120 to 225 pixels), for example to make room for longer names. Unlike the UI scale slider they leave icons and text at their size. A Reset Sizes button sets the scale and both widths back to their defaults.

### Changed
- **New Drag Handle**: The lock/unlock handle next to the groups is now a green (unlocked) or red (locked) light in a metal socket.
- **In-Combat Player List Rewritten**: The code that opens a group's player list when you hover over it in combat has been rewritten. It should behave exactly as before; please report anything that looks different.
- **MIT License**: BuffPower's source is now available under the MIT License.
- **Tidier Options**: General Settings are grouped into Visibility, Display and Size, and say that they apply to all your characters; Group Assignments say that each character has its own selection. Class names in Class Assignments are shown in their class colours, the "Mana Users" quick select is now "Mana" so it is no longer cut off, and the group buttons are now "All" and "None".
- **Buff Timers on the Icons**: The remaining buff time now sits on the bottom of each icon, like the count on an action button, instead of underneath it, and the icons are slightly larger. With two or more buffs, the timers below neighbouring icons ran together into one unreadable string.

## [v1.1.0-beta5] - 2026-10-07

**Testing status**: checked visually on the WoW Forever beta, solo only; not yet seen with a full group, with very long names, or with three buff icons on one button. Not yet tested on Classic Era or TBC Anniversary; that is planned for November 2026. Until then this should ship as a Forever-only beta.

### Added
- **First Names Only** ([#13](https://github.com/ruudvanstrijp/BuffPower/issues/13)): On WoW Forever, where characters have a first and a last name, you can now choose to show players by their first name only. The full name still shows in the tooltip. The option is off by default, applies to all your characters, and only appears on Forever.

### Changed
- **Longer Player Names** ([#13](https://github.com/ruudvanstrijp/BuffPower/issues/13)): A player name now uses all the space next to the buff icons that are actually shown. Before, it always left room for three icons, so names were cut off even on buttons with a single icon.
- **Modernised Look** ([#15](https://github.com/ruudvanstrijp/BuffPower/issues/15)): Group and player buttons have a flat background with a thin edge instead of the tooltip border, buff icons are cropped with a thin dark edge, and text has a solid shadow. The green and red status colours are darker, so names and icons stay readable on them. Icons for missing buffs are now greyed out instead of tinted red, so they no longer blend into the red background. Buff icons now light up when you hover over them, in combat too.

## [v1.1.0-beta4] - 2026-10-01

**Testing status**: the combat fix is verified on the WoW Forever beta. Not yet tested on Classic Era or TBC Anniversary, which take the unchanged code path; that is planned for November 2026. Until then this should ship as a Forever-only beta.

### Fixed
- **Everything Red in Combat on WoW Forever** ([#12](https://github.com/ruudvanstrijp/BuffPower/issues/12)): Forever hides auras from addons during combat, so every buff looked missing and the whole grid turned red. While auras are hidden, BuffPower now keeps the status it last read and only marks a buff missing once its known expiration time has passed. Buffs cast during combat show up when combat ends.

## [v1.1.0-beta3] - 2026-09-24

**Testing status**: loads without errors on the WoW Forever beta; the individual fixes have not been exercised in a group yet. Not yet tested on Classic Era or TBC Anniversary; that is planned for November 2026. Until then this should ship as a Forever-only beta.

### Fixed
- **Changes During Combat**: Roster changes, group moves and newly learned spells during combat are now applied as soon as combat ends. Before, the grid stayed out of date until the next roster change.
- **Player List Stuck Open**: A group's player list no longer stays open for a whole fight when combat starts just after the mouse leaves it; it now closes when combat ends.
- **Player Overrides Between Characters**: Scroll-wheel overrides were shared by all characters and saved as a position in the list of optional buffs, so "Force Amplify Magic" set on a mage became "Force Thorns" on a druid. They are now saved per character, by buff. Existing overrides are carried over for each character exactly as it showed them before.
- **Pets With the Same Name**: Two pets with the same name in one group (for example two hunters' "Wolf") shared a single buff status. Buff status is now tracked per unit.
- **Frame Position**: The saved position now includes the anchor points, so the frame no longer shifts after a `/reload` when dragging had re-anchored it.

### Changed
- **Group Responsibilities per Character**: The groups you are responsible for are now set per character, so your priest and mage can cover different groups. Each character starts from the previously shared setting.
- **Group Tooltip**: The group tooltip now opens to the left so it no longer covers the player list.
- **Performance**: The 0.2-second refresh now only redraws colours, countdowns and range fading; auras are rescanned and click targets re-picked once a second as before. Buff timers are stored as expiration times, so countdowns now tick smoothly instead of once a second, and less work is repeated for every raid member.

## [v1.1.0-beta2] - 2026-09-22

**Testing status**: verified on the WoW Forever beta only (level 2 mage and priest, rank 1 Arcane Intellect and Power Word: Fortitude). Not yet tested on Classic Era or TBC Anniversary; that is planned for November 2026. Until then this should ship as a Forever-only beta.

### Fixed
- **Rebuff Keybinding**: Removed the "rebuff" keybinding. It called a function that was removed in v1.0.0, because spells cannot be cast from a keybinding without a secure button, so pressing it only produced a Lua error. The toggle and options keybindings are unchanged.
- **Single-Target Icon Fallback**: When the group version of a buff is not learned, a group icon's left click now targets the same player as its right click, instead of keeping a stale target.

### Added
- **Pet Buffing**: The "Show Pets" option now works; it was silently reset to off on every login. Pets are listed under their owner's group and get a "Pet" checkbox per buff on the Class Assignments tab (on by default for normal buffs, off for optional ones). Pets are buffed single-target only: a pet missing a buff never triggers a group cast.

### Changed
- **Buff Detection**: Auras are matched with `AuraUtil.FindAuraByName` on the localized spell name instead of a hand-rolled scan, which also removes the `UnitBuff` compatibility shim.
- **Smaller Package**: Removed libraries that were shipped but never loaded (LibClassicDurations, LibSharedMedia-3.0, AceGUI-3.0-SharedMediaWidgets, AceDBOptions-3.0) or loaded but never used (LibUIDropDownMenu, AceComm-3.0, AceLocale-3.0), the unused `Skins/` textures, and the placeholder addon-message prefix. UI strings are now plain literals; the addon only ever shipped an English locale.
- **Cleanup**: Removed dead code and unused settings throughout, with no change to behaviour.

## [v1.1.0-beta1] - 2026-09-21

### Fixed
- **WoW Forever Support**: The addon failed to load on the WoW Forever beta with `attempt to call a nil value` in `RestrictedExecution.lua`, aborting setup before the UI was built. That build cannot compile secure snippets at all - its `RestrictedExecution.lua` captures `loadstring_untainted`, which the client does not provide, so every addon using secure handlers is affected. BuffPower now detects this and skips its secure wiring instead of erroring, so the addon loads and works normally out of combat; only expanding a group's player list while in combat is unavailable. The behaviour returns by itself once Blizzard fixes the client.
- **Restricted Environment**: The secure snippets now use `newtable()` rather than `table.new()`, which does not exist in the Mainline restricted environment that Forever uses.
- **Mainline Aura API**: `UnitBuff` no longer exists in the Mainline API family that Forever runs on. Buff scanning now falls back to `C_UnitAuras.GetBuffDataByIndex`, with `C_Spell` / `C_SpellBook` fallbacks for `GetSpellInfo`, `IsSpellKnown` and `IsSpellInRange`. Classic Era and TBC keep using the original globals, so their behaviour is unchanged.
- **Minimap Button**: LibDataBroker-1.1 was never packaged, so `LibStub("LibDataBroker-1.1", true)` returned nil and the minimap button silently never registered unless another addon happened to load the library. It is now an explicit dependency.

### Changed
- **Interface Versions**: Added `16001` (WoW Forever) to the TOC.
- **Libraries**: Updated all embedded libraries. Notably AceDB-3.0 (33 to 36), AceDBOptions-3.0 (15 to 17), LibDBIcon-1.0, LibSharedMedia-3.0 and LibUIDropDownMenu.
- **Library Installer**: `scripts/install-libs.ps1` now locates an svn client that is not yet on the PATH, and falls back to mirroring the CurseForge repositories over HTTP when no svn client is installed at all.

## [v1.0.9] - 2026-06-29

### Fixed
- **Group Buff Right-Click Fallback**: Corrected an issue where right-clicking the group button would fall back to casting group-wide buffs (wasting mana and reagents like Arcane Powder) when the addon assumed everyone was buffed or if range checks failed. Right-clicking will now strictly target individual players with single-target buffs.
- **Improved Range Checks (`IsSpellInRange`)**: Fixed a bug where the UI range indicators and single-target smart buff selectors would fail to recognize group members as in-range if the required buff spell (e.g. Arcane Intellect) was not actively placed on the player's action bars.
- **Unlearned Group Spell Fallback**: Added dynamic detection for learned group-wide spells. Lower-level players who have not yet learned the group version of a spell (like Arcane Brilliance) will now gracefully fall back to casting the single-target version on both left and right clicks, instead of attempting to cast an unlearned spell.

## [v1.0.8] - 2026-05-13

### Fixed
- **Group Buff Right-Click**: Resolved an issue where right-clicking a group's buff icon on non-English clients failed to cast the single-target version of the buff due to missing localized spell attribute updates.
- **Click Handler Differentiation**: Updated the main group button logic to properly distinguish between Left-Click (Smart/Group Buff) and Right-Click (Single Target Buff), preventing both buttons from casting the group version in certain scenarios.

## [v1.0.7] - 2026-05-04

### Fixed
- **Localization Bug**: Fixed a bug where the addon's buff buttons did not cast properly for users on non-English clients (e.g., French clients) by dynamically fetching the localized spell names via `GetSpellInfo`.
- **Combat Button Interactions**: Fixed a critical bug causing clicks on buff icons to fail for users with "Cast action on key down" settings disabled. The `SecureActionButton` click handlers were updated to properly process `"AnyUp"` and `"AnyDown"`.
- **Solo Play Bug Context**: Corrected an issue where the game's `UnitIsVisible` API checks intermittently failed to recognize the player's own unit, stopping the user from clicking and testing their buffs while playing solo.

## [v1.0.6] - 2026-03-09

### Improved
- **Player State Indications**: Updated player button display colors to better reflect when players are offline or dead.
- **Buff Detection Optimization**: Optimized the internal aura scanner, making it more performant by caching spell IDs and names, which should remove localization-caused issues. 

### Fixed
- **Addon Visibility**: Fixed a bug where the addon frame would reappear unexpectedly while zoning or flying, even if completely hidden with `/bp`.
- **Downranked Buffs**: Fixed an issue where the addon wouldn't recognize low-level downranked versions of buffs (like Rank 1 Fortitude) properly on some non-English clients.

## [v1.0.5] - 2026-03-03

### Added
- **Range Check Feature**: Added support for checking the range of party members.
  - Players out of range now have their member card's transparency reduced to 40%.
  - Uses class-specific spells (Arcane Intellect, Mark of the Wild, etc.) for accurate range detection.
  - Visuals update dynamically as you or party members move (every 0.2s).

### Improved
- **User Interface Responsiveness**: Increased the UI update frequency from 1.0s to 0.2s for smoother feedback.
- **Layout Enhancements**: 
  - Redesigned player buttons to accommodate long names without truncation.
  - Switched to a smaller font for player names.
  - Adjusted button and container sizes (Group width: 120, Player width: 150) for better spacing.
- **Usability**: Increased the delay before player lists hide to 0.5s, allowing more time to hover over player-specific buff icons.
- **Mouse Interaction**: Expanded mouse detection to include buff icons, preventing accidental menu closing.

## [v1.0.4] - 2026-02-26

### Improved
- **Smart Target Logic**: Buff icons will now prioritize members missing a buff first. If everyone has it, the person with the shortest remaining duration will be targeted.
  - This allows for easy buff refreshing (e.g., Thorns) before expiry.
- **Member UI Clicks**: All buff icons in the member panel now support both Left and Right-click to cast buffs on the associated player.
- **Tooltip Clarity**: Added hints for scroll-wheel buff cycling in member tooltips.
- **Translation Fixes**: Changed all strings to use the localization system.

### Fixed
- Fixed group tooltip member count to correctly say "1 member" instead of "1 members" and to respect the "Show Pets" setting.

## [v1.0.3] - 2026-02-19

### Improved
- **Spell Rank Detection**: Implemented explicit rank checking for all supported buffs (Intellect, Fortitude, MotW, etc.).
- Addon now correctly identifies and uses the highest rank spell known by the player, ensuring full compatibility from level 1 to 70.
- Replaced fragile name-based spell detection with robust ID-based rank scanning.

## [v1.0.2] - 2026-02-11

### Added
- **Manual Player Assignments**: Introduced PallyPower-like manual buff overrides.
  - Cycle through utility buffs (Thorns, Amplify/Dampen Magic) by scrolling over a member's card.
  - Manual assignments are saved per player name and override class-wide defaults.
- **Mage Utility Spells**: Added support for **Amplify Magic** and **Dampen Magic**.
- **Dynamic Group UI**: Group buttons now dynamically update to show/hide icons based on individual member assignments (both class-based and manual overrides).

### Fixed
- Improved UI responsiveness when changing class assignments; these changes now reflect immediately without requiring a `/reload`.
- Fixed an initialization issue where group-level buff icons would occasionally fail to display after layout updates.

## [v1.0.1] - 2026-02-11

### Changed
- Improved UI update frequency from 5 seconds to 1 second.
- Refactored update logic to use a repeating timer for more reliable buff tracking.

### Fixed
- Resolved an issue where member buff statuses (timers) would occasionally become stuck or fail to update when buffs expired.

## [v1.0.0] - 2026-02-04

### Added
- **Initial Release**: Comprehensive buff management system for Mages, Priests, and Druids.
- **Multi-Expansion Support**: Full compatibility with Classic Era and Burning Crusade Classic.
- **Raid Overview**: Visual dashboard showing buff status for all raid groups.
- **Smart Buffing**:
    - Group-based assignments.
    - Class-specific buff assignments.
    - Automatic rank selection based on level.
- **Pet Support**: Toggleable option to include/exclude hunter and warlock pets in buff tracking.
- **Visibility Options**: Configurable display settings for Solo, Party, and Raid environments.
- **Minimap Icon**: Integrated `LibDBIcon` for easy access to options.
- **Development Workflow**:
    - `.pkgmeta` for automated library management via BigWigs Packager.
    - GitHub Actions for automated tagging and releasing.
    - Detailed documentation for library maintenance.
