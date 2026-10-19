**Unofficial test build.** It is not made or supported by the Madeira developers. Report problems with it here, not to them.

This is Madeira (willfaust/madeira `main` at `279fd0f`) plus the fixes of the earlier test builds, and now a much faster **Red Dead Redemption 2 (Steam)**, plus **Call of Duty: Black Ops II** running.

## Install

- Download `Madeira-279fd0f-bo3-611924f-unsigned.ipa` below. It is **unsigned**: sideload it the same way as an official Madeira IPA.
- Use **install IPA**, not refresh. The build label in Madeira should read `upstream-279fd0f 611924f`.
- **RDR2:** if you changed its settings yourself, tap **Reset to Recommended** at the bottom of the game's settings, or add these two lines to its Advanced config (an unchanged config updates by itself):
  ```
  env.MADEIRA_SWAP_COVERAGE = classic
  env.MADEIRA_CHILD_ARGS = RDR2.exe -cpuLoadRebalancing -disableSchedulingContentionReduction
  ```
- **Black Ops II:** add this line to its Advanced config, or the sound is choppy:
  ```
  env.MADEIRA_AUDIO_LEAD_MS = 150
  ```

## What's changed

- **RDR2 frame rate (new):** each ExecuteIndirect call in the Direct3D 12 runtime read a clock that, on iOS, costs a fault every time (~27 µs), about 530 times a frame. That is gone: those calls went from ~31 µs to ~2.4 µs and the frame's translation time dropped by about 15 ms. In testing RDR2 held a locked 30 fps (Half V-Sync) for most of a session that ran 17–22 fps before, 22–27 in the heaviest stretch.
- **Direct3D 12 runtime built from source (new):** `d3d12.dll` is now compiled in this build instead of shipped prebuilt. It keeps the same shader cache, so no recompile on first launch.
- **Black Ops II (new):** runs, including Zombies. A 16-byte write into the game's code buffer used to loop the emulator into a crash on older Madeira builds; this build handles it. Choppy sound is fixed with the line above.
- **Fewer RDR2 freezes, launch options, cloud saves:** as in the previous build.
- **Black Ops III (work in progress, not playable yet):** it now gets past several anti-tamper stages but still crashes during unpacking.

## Tested

On one iPhone: RDR2 for about 9 minutes, locked 30 fps most of the time, no crash. Black Ops II Zombies played with clean sound.

## Source

GPL-3.0-or-later. The source for this build is the `bo3-build` branch of this repository at `611924f`, with its submodules.
