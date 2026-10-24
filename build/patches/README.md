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

`build/ci-ntdll-arm64ec.sh` likewise builds the ARM64EC PE `ntdll.dll` from the pinned wine
with `build/patches/wine/*.patch`, in place of the committed prebuilt (without the patches the
build reproduces the prebuilt's `.text` byte for byte):

| Patch | Repo | What it does |
|---|---|---|
| `wine/0001-ldr-windows-order.patch` | `wine` | `MADEIRA_LDR_WINDOWS_ORDER=1` (off by default, set per game): ntdll heads the initialization-order list and the emulator's modules move behind kernel32/kernelbase in the load- and memory-order lists, as on Windows. Call of Duty Black Ops III looked up an ntdll routine in the first initialized module, found kernelbase there and crashed. Log marker `[ldr-order]`. |

| `wine/0004-ldr-lock-fixme-once.patch` | `wine` | `LdrLockLoaderLock` warns about its unsupported flag 0x1 once per process instead of on every call: Red Dead Redemption 2 takes the loader lock that way ~110 times a second (40,000 log lines in six minutes). |

| `wine/0005-cs-tls-x64-fastpath.patch` | `wine` | willfaust/wine#50, unchanged: `MADEIRA_CS_X64=1` / `MADEIRA_TLS_X64=1` (off by default) run the uncontended critical-section and `TlsGetValue` paths in x64 inside the JIT code instead of leaving it for the ARM64EC export each call. Red Dead Redemption 2 makes ~850,000 x64-to-EC calls a second. |
| `wine/0006-sync-lean.patch` | `wine` | willfaust/wine#51, unchanged: `MADEIRA_SYNC_LEAN=1` (off by default) drops the SRW history ring and the WaitOnAddress counters (diagnostic interlocked increments on shared cache lines). |

`build/dxmt-ios/build.sh` applies `build/patches/dxmt/*.patch` to the pinned DXMT before it
compiles winemetal's unix side (a patch already in the tree is left alone):

| Patch | Repo | What it does |
|---|---|---|
| `dxmt/0001-framegen-d3d12-pacing.patch` | `dxmt` | Frame generation (`MADEIRA_FRAMEGEN=1`) serves the game only: threads of the process whose D3D12 runtime presents (`ios_framegen_game_thread`, ntdll unix), never a hidden window's layer (Winios `-madeiraWindowHidden`), one at a time. The Rockstar Games Launcher's and Social Club's windows presented through the one global interpolator from their own threads, re-sized it under each other and Metal aborted (a copy between textures of different sizes, 2026-10-22). A stall now drops the history after `MADEIRA_FRAMEGEN_STALL_MS` (125 ms) instead of 66.7 ms, so a game capped at 15 fps keeps its generated frames. With an FPS limit on, the generated and the real frame each stay one slot (`afterMinimumDuration`), so `env.MADEIRA_FPS_CAP = 15` with the 30 limit shows an even 30. Log marker `[framegen] layer ... owns the interpolator`. |

`build/ntdll-unix/virtual_ios.c` also carries `[arena-guard]`: a fixed or hinted guest
reservation (Social Club's V8 asks for 4 GB at random hints) is refused when it overlaps the
FEX arena, so the caller places it elsewhere. `MADEIRA_ARENA_GUARD=0` restores the old placement.

Device markers to look for in a log: `rpmalloc-span4 madeira-bcd`, `callret-skip-reserve-v1`,
`[pool-null] armed ... rev=pns2`, `[arena-guard]` and, with the switch on, `[ldr-order]`.

None of these have run on a device yet. The three FEX/rpmalloc patches were built together
into `libarm64ecfex.dll` with llvm-mingw 20260421 (Linux) and compared against the committed
prebuilt: the log strings differ only by the build time, the span marker and these patches.
