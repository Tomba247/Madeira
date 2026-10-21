#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Madeira Converter Exception: see LICENSE-EXCEPTION.md
# CI: build the ARM64EC d3d12.dll (madeira-d3d12) from source in place of the
# committed prebuilt app/Madeira/arm64ec-windows/d3d12.dll (and its copy
# madeira_d3d12.dll), the way build/madeira-d3d12/build-pe.sh does, with two
# differences:
#   - winemetal's import library comes from the shipped winemetal.dll's exports
#     (CI does not build DXMT's ARM64EC half);
#   - the shader cache's converter identity is the shipped build's, so a device
#     keeps its converted shaders: the converter (the unix side) is built from
#     the same pinned sources as before.
# The helper kernels must build (the shipped DLL carries them). The app's DLLs
# are replaced only once the build and its checks pass, so a failure here leaves
# the prebuilt in place. Writes the DLL's sha256 to $1.
set -euo pipefail
export LC_ALL=C
R="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTF="${1:-$R/build/madeira-d3d12/out-ci/madeira-d3d12-arm64ec-source.txt}"
TC="$R/toolchains/llvm-mingw-20260421-ucrt-macos-universal/bin"
SRC="$R/madeira-d3d12/src/pe"
OUT="$R/build/madeira-d3d12/out-ci"
APP="$R/app/Madeira/arm64ec-windows"
SCID=3b05fa2b31d16c7d   # "madeira_d3d12 bc1 converter <id>" in the shipped d3d12.dll

[ -x "$TC/arm64ec-w64-mingw32-clang" ] || { echo "error: no LLVM-MinGW in $TC" >&2; exit 1; }
[ -f "$R/dxmt/src/winemetal/winemetal.h" ] || { echo "error: the dxmt submodule is not checked out" >&2; exit 1; }
mkdir -p "$OUT" "$(dirname "$OUTF")"

echo "=== winemetal import library (from the shipped winemetal.dll) ==="
python3 - "$APP/winemetal.dll" "$OUT/winemetal.def" <<'PY'
import struct, sys
d = open(sys.argv[1], 'rb').read()
pe = struct.unpack_from('<I', d, 0x3c)[0]
nsec = struct.unpack_from('<H', d, pe + 6)[0]
opt = pe + 24
so = opt + struct.unpack_from('<H', d, pe + 20)[0]
secs = [struct.unpack_from('<IIII', d, so + i * 40 + 8) for i in range(nsec)]
def off(rva):
    for vs, va, rs, ra in secs:
        if va <= rva < va + max(vs, rs):
            return rva - va + ra
    raise SystemExit('rva 0x%x is in no section' % rva)
e = off(struct.unpack_from('<I', d, opt + 112)[0])
nn, anp = struct.unpack_from('<I', d, e + 24)[0], struct.unpack_from('<I', d, e + 32)[0]
names = [d[off(struct.unpack_from('<I', d, off(anp) + 4 * i)[0]):].split(b'\0')[0].decode() for i in range(nn)]
if not names:
    raise SystemExit('winemetal.dll exports nothing')
with open(sys.argv[2], 'w') as f:
    f.write('LIBRARY winemetal.dll\nEXPORTS\n' + ''.join('  %s\n' % n for n in names))
print('  %d exports' % len(names))
PY
if [ -x "$TC/arm64ec-w64-mingw32-dlltool" ]; then
    "$TC/arm64ec-w64-mingw32-dlltool" -d "$OUT/winemetal.def" -l "$OUT/libwinemetal.a"
else
    "$TC/llvm-dlltool" -m arm64ec -d "$OUT/winemetal.def" -l "$OUT/libwinemetal.a"
fi

# as build-pe.sh: the stub tables follow the toolchain's d3d12.h
python3 "$SRC/gen_vtables.py" \
    "$R/toolchains/llvm-mingw-20260421-ucrt-macos-universal/generic-w64-mingw32/include/d3d12.h" \
    "$SRC/madeira_d3d12_stubs.h" > /dev/null

echo "=== helper kernels (metallib) ==="
mad_kernels_metal() {
    xcrun -sdk iphoneos metal -std=metal3.0 "$@" -o "$OUT/mad_kernels.metallib" "$SRC/mad_kernels.metal" 2> "$OUT/mad_kernels.err"
}
if ! { mad_kernels_metal ||
       mad_kernels_metal -DMAD_NO_TEXBUF_PROBE ||
       mad_kernels_metal -DMAD_NO_CLEAR_RECTS ||
       mad_kernels_metal -DMAD_NO_TEXBUF_PROBE -DMAD_NO_CLEAR_RECTS; }; then
    head -40 "$OUT/mad_kernels.err" >&2 || true
    echo "error: the helper kernels did not build; the shipped d3d12.dll carries them" >&2
    exit 1
fi
(cd "$OUT" && xxd -i mad_kernels.metallib > mad_kernels_metallib.h)
echo "  $(wc -c < "$OUT/mad_kernels.metallib" | tr -d ' ') bytes"

echo "=== d3d12.dll (arm64ec) ==="
"$TC/arm64ec-w64-mingw32-clang" -shared -O2 -Wall \
    -DMAD_SC_CONVERTER_ID="\"$SCID\"" -DMAD_HAVE_KERNELS -I"$OUT" \
    -o "$OUT/madeira_d3d12.dll" "$SRC/madeira_d3d12.c" "$SRC/d3d12.def" \
    -I"$SRC" -I"$R/madeira-d3d12/src" -I"$R/dxmt/src/winemetal" \
    -L"$OUT" -lwinemetal -luuid -lole32

DLL="$OUT/madeira_d3d12.dll"
grep -aq "madeira_d3d12 bc1 converter $SCID" "$DLL" ||
    { echo "error: $DLL does not carry the shader cache identity $SCID" >&2; exit 1; }
grep -aq '\[perf\] indirect split per frame' "$DLL" ||
    { echo "error: $DLL does not carry the [perf] indirect split line" >&2; exit 1; }
grep -aq '\[perf\] draw steps, us per draw' "$DLL" ||
    { echo "error: $DLL does not carry the [perf] draw steps line" >&2; exit 1; }
grep -aq '\[perf\] table-reuse per frame' "$DLL" ||
    { echo "error: $DLL does not carry the [perf] table-reuse line" >&2; exit 1; }
echo "  built $(wc -c < "$DLL" | tr -d ' ') bytes (shipped: $(wc -c < "$APP/d3d12.dll" | tr -d ' '))"
cp "$DLL" "$APP/d3d12.dll"
cp "$DLL" "$APP/madeira_d3d12.dll"
echo "d3d12.dll $(shasum -a 256 "$APP/d3d12.dll" | cut -d' ' -f1) converter $SCID" | tee "$OUTF"
