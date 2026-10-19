**Unofficial test build.** It is not made or supported by the Madeira developers. Report problems with it here, not to them.

This is Madeira (willfaust/madeira `main` at `279fd0f`) plus the fixes of the earlier RDR2 test builds, and now fewer freezes in **Red Dead Redemption 2 (Steam)**.

## Install

- Download `Madeira-279fd0f-bo3-unsigned.ipa` below. It is **unsigned**: sideload it the same way as an official Madeira IPA.
- Use **install IPA**, not refresh. The build label in Madeira should read `upstream-279fd0f b9d0694`.
- You need to own RDR2 on Steam.
- **If you changed RDR2's settings yourself**, tap **Reset to Recommended** at the bottom of the game's settings, or add these two lines to its Advanced config. An unchanged config updates by itself.
  ```
  env.MADEIRA_SWAP_COVERAGE = classic
  env.MADEIRA_CHILD_ARGS = RDR2.exe -cpuLoadRebalancing -disableSchedulingContentionReduction
  ```

## What's changed

- **Fewer RDR2 freezes (new):** the multi-second hangs came from the swap file. Each time the game released memory, the swap system freed that space in its file while holding a lock the game's threads were waiting on. RDR2's recommended settings now use the "classic" swap mode, which doesn't do that. In testing, half as many freezes and no memory kill.
- **RDR2 launch options (new):** the recommended settings pass `-cpuLoadRebalancing -disableSchedulingContentionReduction` to RDR2.exe, which a Steam launch can't do on its own.
- **Cloud saves:** the Rockstar launcher no longer crashes while it uploads a save (from the previous build).
- **Black Ops III (work in progress, not playable yet):** module load order, a hang after its unpacker, and code run from a second copy of a system DLL are fixed. It gets further but doesn't reach the game yet.
- **Freeze diagnostics:** `env.MADEIRA_LEAN_DIAG = 1` plus `env.MADEIRA_STALL_SAMPLE = 1` logs every thread when the game stops presenting frames. Off by default.
- Earlier fixes: the memory guard for Social Club's reservations, emulator (FEX) and rpmalloc fixes, and the Madeira Dock service manager.

## Tested

On one iPhone, RDR2 played for 17 minutes with no crash and no memory kill. There were 3 short freezes, down from 6.

## Source

GPL-3.0-or-later. The source for this build is the `bo3-build` branch of this repository at `b9d0694`, with its submodules.
