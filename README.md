# Mini Interrupt Tracker

A lightweight World of Warcraft (Retail) addon that shows your party's interrupt
cooldowns on a compact set of bars, so you always know who's available to kick.

## Features

- **Party-wide interrupt bars** — one bar per party member (including yourself),
  showing their interrupt's icon, remaining cooldown, and readiness at a glance.
- **No manual setup** — automatically detects each member's spec and picks the
  right interrupt ability and cooldown for them.
- **Smart ordering** — ready members are listed first (shortest cooldown, then
  tank → melee → ranged, then name); members on cooldown follow, soonest-ready
  first, so the bar you need most is always near the top.
- **Works without everyone having the addon** — members without Mini Interrupt
  Tracker installed are still listed, so you know who you can't track.
- **Configurable** — lock/unlock and drag the bar position, resize bars,
  reverse growth direction, and choose which content types show the tracker.
- **Shows in Open World and Mythic Dungeons** (including Mythic Keystone runs).

## How it works

Party members running the addon exchange lightweight addon messages over the
party channel:

- On login/spec change/joining a party, each client announces its version and
  spec so others can resolve the correct interrupt ability to track.
- When a tracked interrupt is cast, the caster broadcasts it to the party so
  everyone's bars update immediately — no combat log guessing required.
- A member who hasn't been heard from is shown as "Checking..." for a short
  grace period, then flips to "No Addon" if they never respond.

## Installation

1. Download the latest release from the [GitHub Releases page](../../releases)
   (also published automatically to CurseForge).
2. Extract the `MiniInterruptTracker` folder into your
   `World of Warcraft/_retail_/Interface/AddOns/` directory.
3. Restart or reload the game client.

## Usage

- `/mit` — open the configuration panel.
- `/mitdebug` — toggle verbose debug logging (for troubleshooting).

## Configuration

The config panel (`/mit`) lets you control:

- Whether the tracker shows in the open world, and/or in Mythic dungeons
  (including Mythic+).
- Locking the bars in place, or dragging them to reposition.
- Bar width, height, and spacing.
- Reversing the direction the bars fill/grow.
- Test Mode, which populates the bars with fake data so you can preview and
  arrange your layout outside of a real party.

## Contributing

Issues and pull requests are welcome. If you're adding or adjusting a tracked
interrupt/cooldown, `MiniInterruptTracker/Data.lua` is the single source of
truth for per-spec interrupt data.

## License

Licensed under the [Apache License 2.0](LICENSE).
