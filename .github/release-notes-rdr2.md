**Unofficial test build.** It is not made or supported by the Madeira developers. Report problems with it here, not to them.

This is Madeira (willfaust/madeira `main` at `279fd0f`) plus fixes that get **Red Dead Redemption 2 (Steam)** past launch and into the game on an iPhone. Before them, the emulator's shared memory space ran out while the game started and it crashed.

## Install

- Download `Madeira-279fd0f-dockscm-unsigned.ipa` below. It is **unsigned**: sideload it the same way as an official Madeira IPA.
- Use **install IPA**, not refresh. The build label in Madeira should read `upstream-279fd0f 8efe633`.
- You need to own RDR2 on Steam. No extra config is needed: Madeira's recommended settings for the RDR2 Steam entry already cover it.

## What's changed

- **Memory guard:** stops Social Club's 4 GB reservations from landing in the emulator's memory space. Sent to Madeira as willfaust/madeira#386.
- **Emulator (FEX):** no call-return stack reservation when it is unused; a failed buffer claim recovers or exits cleanly instead of crashing.
- **rpmalloc:** 4 MiB spans for ARM64EC (willfaust/rpmalloc#2).
- **Madeira Dock:** a service manager for the game session, so the Rockstar service starts (willfaust/madeira-dock#5).

## Tested

On one iPhone: in game for over 6 minutes, about 25–30 fps, no crash. The emulator's memory space peaked at 46% (90% without the fixes). The app used about 5.9 GB of RAM in game, so close other apps first; devices with less memory may not manage it.

## Source

GPL-3.0-or-later. The source for this build is the `rdr2-dock-scm-build` branch of this repository at `8efe633`, with its submodules.
