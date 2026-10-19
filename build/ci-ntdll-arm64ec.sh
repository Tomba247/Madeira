#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Madeira Converter Exception: see LICENSE-EXCEPTION.md
# CI: build the ARM64EC PE ntdll.dll from the pinned wine with Madeira's patches,
# in place of the committed prebuilt app/Madeira/arm64ec-windows/ntdll.dll.
#
#   build/patches/wine/*.patch   `git apply` in wine
#
# Patches apply in C-locale name order; one that does not apply fails the build.
# build/wine-pe/build-ntdll.sh does the build, strip and padding. The patches are
# reverted when this script exits. The DLL must carry the [ldr-order] marker of
# 0001-ldr-windows-order.patch. Patch hashes and the DLL sha256 are written to $1.
set -euo pipefail
export LC_ALL=C
R="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="${1:-$R/wine/build-arm64ec/madeira-ntdll-arm64ec-source.txt}"
DLL="$R/app/Madeira/arm64ec-windows/ntdll.dll"
TC="$R/toolchains/llvm-mingw-20260421-ucrt-macos-universal/bin"
WINE="$R/wine"

[ -x "$TC/arm64ec-w64-mingw32-clang" ] || { echo "error: no LLVM-MinGW in $TC" >&2; exit 1; }
[ -f "$WINE/dlls/ntdll/loader.c" ] || { echo "error: the wine submodule is not checked out" >&2; exit 1; }
# Wine's parsers need bison 3; macOS ships 2.3.
if command -v brew >/dev/null && [ -x "$(brew --prefix bison)/bin/bison" ]; then
    export PATH="$(brew --prefix bison)/bin:$PATH"
fi
STRINGS="$(command -v strings || echo "$TC/llvm-strings")"

APPLIED=()
revert() {
    local rc=$? i
    trap - EXIT
    for ((i = ${#APPLIED[@]} - 1; i >= 0; i--)); do
        git -C "$WINE" apply -R "${APPLIED[i]}" || { echo "error: could not revert ${APPLIED[i]}" >&2; rc=1; }
    done
    exit "$rc"
}
trap revert EXIT

mkdir -p "$(dirname "$OUT")"
{
    echo "wine $(git -C "$WINE" rev-parse HEAD)"
    for p in "$R"/build/patches/wine/*.patch; do
        git -C "$WINE" apply --check "$p"
        git -C "$WINE" apply "$p"
        APPLIED+=("$p")
        echo "applied $(basename "$p") $(shasum -a 256 "$p" | cut -d' ' -f1)"
    done
} | tee "$OUT"

bash "$R/build/wine-pe/build-ntdll.sh"

"$STRINGS" "$DLL" | grep -q '\[ldr-order\]' ||
    { echo "error: $DLL does not carry the [ldr-order] marker" >&2; exit 1; }
echo "ntdll.dll $(shasum -a 256 "$DLL" | cut -d' ' -f1)" | tee -a "$OUT"
