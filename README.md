# BuffPower

**Author:** Ruuddie

**BuffPower** is a World of Warcraft addon for managing buff assignments for **Mages**, **Priests**, and **Druids**.

Similar to the popular *PallyPower* addon, BuffPower adapts the interface to handle group-based buffs (Arcane Brilliance, Prayer of Fortitude, Gift of the Wild).

## Features

-   **Group-based Buffing:** Manage buffs by raid group (1-8).
-   **Class Support:**
    -   **Mages:** Arcane Brilliance (Group) / Arcane Intellect (Single)
    -   **Priests:** 
        -   Prayer of Fortitude (Group) / Power Word: Fortitude (Single)
        -   Prayer of Spirit (Group) / Divine Spirit (Single)
        -   Prayer of Shadow Protection (Group) / Shadow Protection (Single)
    -   **Druids:** 
        -   Gift of the Wild (Group) / Mark of the Wild (Single)
        -   Thorns (Single)
-   **Smart Casting:** Left-click a group to cast the group buff; Left-click a player name to cast the single-target buff.

## Installation

1.  Download the latest release from the [Releases page](../../releases).
2.  Extract the `BuffPower` folder into your WoW `Interface\AddOns` directory.

## Development & Release Workflow

This repository includes automation to build and release the addon automatically using GitHub Actions.

### How to Release a New Version

The release process is fully automated. The workflow monitors the `BuffPower.toc` file for version changes.

#### Step 1: Update Version & Changelog
1.  Open `BuffPower.toc` and increment the `## Version:` field (e.g., to `v1.0.1`).
2.  Update `CHANGELOG.md` with the new version and release notes.

#### Step 2: Commit & Push
Commit these changes and push to the `main` branch.

**That's it!**
GitHub Actions will automatically:
1.  Detect the version change in `BuffPower.toc`.
2.  Create a git tag for that version (e.g., `v1.0.1`).
3.  Trigger the release workflow.
4.  Package the addon and publish a new release on GitHub.

*(Note: You can still manually create tags if you prefer, which will also trigger a release.)*

## Managing Ace Libraries

BuffPower uses the Ace3 libraries for core addon functionality. To ensure the addon remains compatible with WoW updates and receives bug fixes, you should keep these libraries up to date.

### Understanding Ace Libraries

The addon uses these Ace3 libraries located in the `Libs` folder:
- **LibStub** - Library loader
- **CallbackHandler-1.0** - Event handling
- **AceAddon-3.0** - Addon framework
- **AceEvent-3.0** - Event management
- **AceBucket-3.0** - Event bucketing
- **AceTimer-3.0** - Timer management
- **AceDB-3.0** - SavedVariables database management
- **AceConsole-3.0** - Console command handling
- **AceGUI-3.0** - GUI widget framework
- **AceConfig-3.0** - Configuration system
- **LibDataBroker-1.1** - Data source the minimap icon registers with
- **LibDBIcon-1.0** - Minimap icon management

### Should You Update Ace Libraries?

**Yes!** You should update Ace libraries regularly because:

1. **Bug Fixes:** Ace libraries receive bug fixes for issues that affect many addons
2. **WoW Compatibility:** Libraries are updated for new WoW patches and expansions
3. **Security:** Updates may include security improvements
4. **Performance:** Libraries are optimized over time for better performance

### How to Update Ace Libraries

Libraries are **committed to this repository**, and `.pkgmeta` declares them as
`embedded-libraries` rather than `externals`. The BigWigs Packager therefore ships the
exact files in `Libs/`, so a release contains precisely what was tested locally. Library
updates are a deliberate, reviewable step rather than something that changes underneath a
release.

> **Important:** the packager only ships files tracked by git - it runs
> `git ls-files --others --directory` and ignores everything untracked. A library that is
> present on disk but not committed will work locally and be silently missing from the
> release zip. Always commit the library files.

**To update the libraries:**

1. Run the updater, which fetches every library from the upstream sources listed in
   `scripts/install-libs.ps1`:
   ```powershell
   .\scripts\install-libs.ps1
   ```
   Or use the **Install Libs Locally** task in VS Code. An svn client is used when one is
   available (`winget install Slik.Subversion`); without one it falls back to mirroring the
   same repositories over HTTP.

2. Review the diff. `git status` will show exactly what upstream changed, including any
   files that were removed.

3. Test in-game before committing:
   ```powershell
   .\scripts\deploy.ps1 -Flavor anniversary,classic_beta
   ```

4. Commit the result:
   ```bash
   git add Libs/
   git commit -m "Update embedded libraries"
   ```

### Update Frequency Recommendations

- **Before major WoW patches:** Always update libraries 1-2 weeks before a major patch
- **Quarterly:** Check for updates every 3 months during stable periods
- **When users report issues:** Library bugs may be fixed in newer versions
- **After long breaks:** If you haven't updated in 6+ months, check for updates

### Testing After Updates

After updating libraries, always test these core features:
1. Addon loads without errors
2. Minimap icon appears and functions
3. Configuration options can be accessed
4. Raid/party detection works
5. Buff assignment and casting works
6. SavedVariables persist across sessions

## Contributing

Bug reports, ideas and pull requests are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md)
for setup, testing and the licensing rules for contributions.

## License

BuffPower is released under the [MIT License](LICENSE).

The libraries in `Libs/` are third-party code under their own licenses: Ace3 and
CallbackHandler use a BSD-style license, LibStub and LibDataBroker are public domain, and
LibDBIcon is distributed by its authors for embedding in addons.

The idea and layout are inspired by PallyPower, but BuffPower contains none of its code
or artwork.
