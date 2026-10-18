#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Madeira Converter Exception: see LICENSE-EXCEPTION.md
# CI: build the ARM64EC FEX module (xtajit64.dll) from the pinned FEX with
# Madeira's patches, in place of the committed prebuilt
# app/Madeira/arm64ec-windows/xtajit64.dll.
#
#   build/patches/rpmalloc/*.patch   `git apply` in FEX/External/rpmalloc
#   build/patches/fex/*.patch        `git apply` in FEX
#
# Patches apply in C-locale name order; one that does not apply fails the build.
# Run this after build/fex-ios/build.sh and build/fex-wow64/build.sh, which build
# the unpatched tree. The patches are reverted when this script exits, since the
# app's Xcode build compiles against FEX's headers beside the unpatched
# FEX/build-ios libraries. The DLL must carry the rpmalloc span marker named by
# MADEIRA_EXPECT_RPMALLOC_MARKER (default: the 4 MiB span marker of
# willfaust/rpmalloc pull request #2; empty skips the check) and no other one.
# Commits, patch hashes, `git diff --stat` and the DLL sha256 are written to $1.
set -euo pipefail
export LC_ALL=C
R="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="${1:-$R/FEX/build-arm64ec/madeira-fex-arm64ec-source.txt}"
EXPECT="${MADEIRA_EXPECT_RPMALLOC_MARKER-rpmalloc-span4 madeira-bcd}"
DLL="$R/app/Madeira/arm64ec-windows/xtajit64.dll"
TC="$R/toolchains/llvm-mingw-20260421-ucrt-macos-universal/bin"
FEX="$R/FEX"
RPM="$R/FEX/External/rpmalloc"

for tool in cmake ninja python3 git shasum; do
    command -v "$tool" >/dev/null || { echo "error: $tool is not on PATH" >&2; exit 1; }
done
STRINGS="$(command -v strings || echo "$TC/llvm-strings")"
[ -x "$TC/arm64ec-w64-mingw32-clang" ] || { echo "error: no LLVM-MinGW in $TC" >&2; exit 1; }
[ -f "$RPM/rpmalloc/rpmalloc.c" ] ||
    { echo "error: FEX and its External/rpmalloc submodule are not checked out" >&2; exit 1; }
echo "python3: $(command -v python3); ccache: $(command -v ccache || echo 'none (FEX builds without it)')"

# Tracked changes already in the trees would end up in the DLL unrecorded.
PRIOR="$(git -C "$FEX" status --porcelain --untracked-files=no --ignore-submodules=all
         git -C "$RPM" status --porcelain --untracked-files=no)"
if [ -n "$PRIOR" ]; then
    echo "::warning::FEX has tracked changes before the patches are applied:"
    echo "$PRIOR"
fi

APPLIED=()   # "<repo>|<patch>", in the order applied
revert() {
    local rc=$? i entry
    trap - EXIT
    for ((i = ${#APPLIED[@]} - 1; i >= 0; i--)); do
        entry="${APPLIED[i]}"
        git -C "${entry%%|*}" apply -R "${entry#*|}" ||
            { echo "error: could not revert ${entry#*|}" >&2; rc=1; }
    done
    exit "$rc"
}
trap revert EXIT

apply_dir() { # <repo> <patch dir>
    local p
    for p in "$2"/*.patch; do
        [ -e "$p" ] || continue
        if ! git -C "$1" apply --check "$p"; then
            if git -C "$1" apply -R --check "$p" 2>/dev/null; then
                echo "error: ${p#"$R"/} is already applied in ${1#"$R"/} (an interrupted run?)" >&2
            else
                echo "error: ${p#"$R"/} does not apply to ${1#"$R"/}" >&2
            fi
            exit 1
        fi
        git -C "$1" apply "$p"
        APPLIED+=("$1|$p")
        echo "applied ${p#"$R"/} to ${1#"$R"/}"
    done
}

PREBUILT="$( [ -f "$DLL" ] && shasum -a 256 "$DLL" | cut -d' ' -f1 || echo none)"
apply_dir "$RPM" "$R/build/patches/rpmalloc"
apply_dir "$FEX" "$R/build/patches/fex"

bash "$R/build/fex-arm64ec/build.sh"

MARKERS="$("$STRINGS" -a "$DLL" | grep -F 'rpmalloc-span' || true)"
echo "rpmalloc span markers in xtajit64.dll: ${MARKERS:-none}"
if [ -n "$EXPECT" ]; then
    grep -qF "$EXPECT" <<<"$MARKERS" ||
        { echo "error: xtajit64.dll does not carry '$EXPECT'" >&2; exit 1; }
    if grep -vF "$EXPECT" <<<"$MARKERS" | grep -q .; then
        echo "error: xtajit64.dll carries another rpmalloc span marker beside '$EXPECT'" >&2
        exit 1
    fi
fi

mkdir -p "$(dirname "$OUT")"
{
    echo "fex-arm64ec=built-from-source"
    echo "fex-arm64ec-fex=$(git -C "$FEX" rev-parse HEAD)"
    echo "fex-arm64ec-rpmalloc=$(git -C "$RPM" rev-parse HEAD)"
    for ((i = 0; i < ${#APPLIED[@]}; i++)); do
        p="${APPLIED[i]#*|}"
        echo "fex-arm64ec-patch=${p#"$R"/} sha256=$(shasum -a 256 "$p" | cut -d' ' -f1)"
    done
    echo "fex-arm64ec-rpmalloc-marker=${MARKERS//$'\n'/;}"
    echo "xtajit64.dll-sha256=$(shasum -a 256 "$DLL" | cut -d' ' -f1)"
    echo "xtajit64.dll-replaced-prebuilt-sha256=$PREBUILT"
    [ -z "$PRIOR" ] || { echo "fex-arm64ec-prior-changes:"; echo "$PRIOR"; }
    echo "git -C FEX diff --stat:"
    git -C "$FEX" diff --stat=200
    echo "git -C FEX/External/rpmalloc diff --stat:"
    git -C "$RPM" diff --stat=200
} > "$OUT"
cat "$OUT"
