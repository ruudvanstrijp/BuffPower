# Contributing to BuffPower

Bug reports, ideas and pull requests are welcome. Please open an issue before starting on
a larger change, so we can agree on the approach first.

## Only contribute code you may share under MIT

BuffPower is released under the [MIT License](LICENSE), and so is every contribution.

- Submit only code and artwork you made yourself, or that comes from a source whose license
  is compatible with MIT. In that case, name the source and its license in the pull request.
- Never copy code or artwork from PallyPower. BuffPower is inspired by its layout, but
  PallyPower is "All Rights Reserved".
- The same goes for other addons: learning from how they solve a problem is fine, copying
  their code is not unless their license allows it. When in doubt, write it yourself from
  the [WoW API documentation](https://warcraft.wiki.gg/wiki/World_of_Warcraft_API).

## Setup

BuffPower is plain Lua 5.1 and XML on Ace3, with no build step. The scripts are Windows
PowerShell and are also available as VS Code tasks (Ctrl+Shift+B deploys to all clients).

```powershell
.\scripts\deploy.ps1                                   # copy to TBC Anniversary (default)
.\scripts\deploy.ps1 -Flavor forever                   # WoW Forever
.\scripts\deploy.ps1 -Flavor anniversary,classic_era,forever  # all three clients
.\scripts\lint.ps1                                     # luacheck, must report 0 warnings
```

`deploy.ps1` finds your WoW install automatically; pass `-WowRoot` or set `WOW_ROOT` to
override it. In-game, `/reload` picks up Lua and XML changes; changes to the `.toc` file
need a client restart. The lint also runs on every push.

[CLAUDE.md](CLAUDE.md) describes the architecture and the rules that are easy to break:
secure buttons can't be changed in combat, spells are cast by their localized name, and
new WoW API calls go through the compatibility layer so they work on all three clients.

## Testing

One `.toc` serves Classic Era, TBC Anniversary and WoW Forever, and the maintainer
tests on all three. So:

- Say in your pull request which clients you tested on.
- A change counts as untested on a client until someone has tried it there. The
  "Testing status" line under Unreleased in [CHANGELOG.md](CHANGELOG.md) tracks this.

## Libraries

The Ace3 and other libraries in `Libs/` are committed to this repository, and `.pkgmeta`
lists them under `embedded-libraries` rather than `externals`. The packager therefore
ships exactly the files in `Libs/`, so a release contains what was tested locally.
A library is only loaded when it is listed in [embeds.xml](embeds.xml).

> **Important:** the packager only ships files tracked by git. A library that is on disk
> but not committed works locally and is silently missing from the release zip.

To update them:

1. Run `.\scripts\install-libs.ps1` (or the "Install Libs Locally" task). It fetches every
   library from the upstream URLs listed in the script, using an svn client when one is
   installed (`winget install Slik.Subversion`) and plain HTTP otherwise.
2. Review the diff; `git status` shows exactly what upstream changed, including removed
   files.
3. Deploy to all three clients and check that the addon loads without errors, the minimap
   button and options work, group detection, buff status and casting work, and settings
   survive a `/reload`.
4. Commit `Libs/`.

## Pull requests

- Target `main`, one topic per pull request.
- Add a line under `## [Unreleased]` in [CHANGELOG.md](CHANGELOG.md) for anything a player
  would notice. It becomes the release notes.
- Don't change `## Version:` in `BuffPower.toc`; that is what triggers a release.

## Releases (maintainer)

1. Bump `## Version:` in `BuffPower.toc` and rename the `[Unreleased]` section of
   `CHANGELOG.md` to that version.
2. Commit or merge to `main`; a release needs no pull request of its own. A workflow
   creates the version tag, and the tag runs the BigWigs packager, which publishes the
   GitHub release and uploads to CurseForge and Wago for all three clients. Versions
   containing `beta` or `alpha` become prereleases and beta/alpha files.
