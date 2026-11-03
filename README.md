# BuffPower

Buff management for Mages, Priests and Druids, inspired by PallyPower.

BuffPower shows your raid or party grouped the way the game groups it, with each group's
buff status at a glance, and lets you buff straight from that overview. It works for
5-man dungeons as well as 40-man raids, and supports WoW Classic Era, Burning Crusade
Classic Anniversary and WoW Forever.

## Installation

Install BuffPower from [CurseForge](https://www.curseforge.com/wow/addons/buffpower) or
[Wago](https://addons.wago.io/addons/buffpower) with their apps, or by hand:

1. Download the latest release from the [Releases page](../../releases).
2. Extract the `BuffPower` folder into your WoW `Interface\AddOns` directory.

## Features

- **Raid overview**: A compact, group-based view of the whole raid. A group shows green
  when everyone has your buffs and red when someone is missing one, with the time left on
  each buff.
- **Smart buffing**: Picks the group or single-target version of a buff based on your
  assignments and on which spells you have learned.
- **Manual overrides**: Want Thorns only on the tanks? Scroll the mouse wheel over a player
  to assign utility buffs to individuals.
- **Combat-safe**: Built on Blizzard's secure action buttons, so click-to-cast works in
  combat without "action blocked" errors.
- **Class filtering**: Choose which classes get which buff (for example, skip Intellect on
  Warriors and Rogues) from a simple options grid.
- **Your groups**: Pick the groups you are responsible for. This is saved per character, so
  your priest and your mage can cover different groups.
- **Pets**: Optionally list pets under their owner's group and buff them too.
- **Adjustable size**: Scale the whole frame, and widen the group and player buttons to
  make room for long names.

## Supported classes

- **Mage**: Arcane Intellect / Arcane Brilliance, Amplify Magic, Dampen Magic
- **Priest**: Power Word: Fortitude / Prayer of Fortitude, Divine Spirit / Prayer of
  Spirit, Shadow Protection / Prayer of Shadow Protection
- **Druid**: Mark of the Wild / Gift of the Wild, Thorns

## How to use

- **Hover over a group**: Opens its player list, in combat too.
- **Left-click a group**: Casts the group-wide version of the buff, or the single-target
  version if you haven't learned the group spell yet.
- **Right-click a group**: Casts the single-target buff on the next player in that group
  who needs it.
- **Click a buff icon next to a player**: Casts that buff on that player.
- **Mouse wheel over a player**: Cycles through manual utility assignments (for example,
  forcing Thorns on).
- **The light next to the groups**: Click it to lock (red) or unlock (green) the frame;
  drag it to move the frame while unlocked. Right-click it for the options.
- **Minimap button**: Click to show or hide the window, right-click for the options.
- **`/bp`**: Shows or hides the window. `/bp options` opens the options, and `/bp reset`
  moves the window back to the middle of the screen.

The window and the options can also be bound to keys, under Key Bindings > AddOns.

## Compatibility

- WoW Classic Era (including Hardcore and Season of Discovery)
- Burning Crusade Classic Anniversary
- WoW Forever

On WoW Forever, the game hides buffs from addons during combat. BuffPower keeps showing
the status it saw before the fight, and buffs cast during combat show up once it ends.

## Contributing

Bug reports and ideas are welcome in the [issues](../../issues). For code, see
[CONTRIBUTING.md](CONTRIBUTING.md): it covers setup, testing, libraries, releases and the
licensing rules for contributions.

## License

BuffPower is released under the [MIT License](LICENSE).

The libraries in `Libs/` are third-party code under their own licenses: Ace3 and
CallbackHandler use a BSD-style license, LibStub and LibDataBroker are public domain, and
LibDBIcon is distributed by its authors for embedding in addons.

The idea and layout are inspired by PallyPower, but BuffPower contains none of its code
or artwork.
