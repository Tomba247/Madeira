# Patches applied at CI build time

`build/ci-fex-arm64ec.sh` builds the ARM64EC FEX module (`xtajit64.dll`) from the pinned
FEX with these patches, in place of the committed prebuilt DLL. Patches apply in name
order with `git apply`; one that does not apply fails the build.

Why: on an iPhone every Windows process of a session shares FEX's 15 GB address-space
arena `[0x7c40000000, 0x8000000000)`. With Steam, the Rockstar launcher and Social Club
running (about 166 FEX threads at roughly 63 MB of reservations each) the arena is nearly
full before Red Dead Redemption 2 starts. A failed 16 MB claim then writes through a NULL
buffer (`libarm64ecfex.dll+0xfe770`, access violation at `0x800010`) and the process dies.

| Patch | Repo | What it does | Source |
|---|---|---|---|
| `rpmalloc/0001-rpmalloc-span4.patch` | `FEX/External/rpmalloc` | 4 MiB spans for ARM64EC processes instead of 16 MiB. Only the ARM64EC + `FEX_IOS_HOST` build changes; the WoW64 object is byte-identical. | willfaust/rpmalloc pull request #2 (76e17c6), unchanged |
| `fex/0001-callret-skip-reserve.patch` | `FEX` | Does not reserve the 8 MB + 8 KB call-return stack per thread when the stack is elided (the default). `MADEIRA_FEX_CALLRET_SKIP_RESERVE=0` keeps the reservation. | new |
| `fex/0002-pool-null-safety.patch` | `FEX` | A failed pooled buffer claim reuses an idle buffer, retries for a few seconds, then ends the process with a clear log line instead of faulting through NULL. | new |

`build/ntdll-unix/virtual_ios.c` also carries `[arena-guard]`: a fixed or hinted guest
reservation (Social Club's V8 asks for 4 GB at random hints) is refused when it overlaps the
FEX arena, so the caller places it elsewhere. `MADEIRA_ARENA_GUARD=0` restores the old placement.

Device markers to look for in a log: `rpmalloc-span4 madeira-bcd`, `callret-skip-reserve-v1`,
`[pool-null] armed ... rev=pns2` and `[arena-guard]`.

None of these have run on a device yet. The three FEX/rpmalloc patches were built together
into `libarm64ecfex.dll` with llvm-mingw 20260421 (Linux) and compared against the committed
prebuilt: the log strings differ only by the build time, the span marker and these patches.
