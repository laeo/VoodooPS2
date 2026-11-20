#!/bin/bash
#
# build.sh - build the patched VoodooPS2 2.3.8 (ps2ro) as a Release kext
# without Xcode, using CLT clang + MacKernelSDK.
#
# Usage: ./build.sh
#   Expects MacKernelSDK/ at the repository root.
#   Output: build/Release/VoodooPS2Controller.kext
#
# Only the controller and keyboard plugin are built.  Mouse/trackpad plugins
# need VoodooInput headers, which are not part of this keyboard-safety test.
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

SDK="$(xcrun --sdk macosx --show-sdk-path)"
CXX="$(xcrun --find clang++)"
CC="$(xcrun --find clang)"
MODULE_VERSION="2.3.8"
BUILD="$ROOT/build/Release"
BUNDLE="$BUILD/VoodooPS2Controller.kext"
KEXT_ID="as.acidanthera.voodoo.driver.PS2Controller"
KBD_ID="as.acidanthera.voodoo.driver.PS2Keyboard"

if [ ! -f "$ROOT/MacKernelSDK/Headers/IOKit/IOService.h" ]; then
  echo "ERROR: MacKernelSDK not found at $ROOT/MacKernelSDK" >&2
  exit 1
fi

COMMON_FLAGS=(
  -arch x86_64
  -mmacosx-version-min=10.13
  -isysroot "$SDK"
  -mkernel -fapple-kext
  -fno-stack-protector
  -fno-exceptions -fno-rtti
  -fno-common
  -nostdlib -fno-builtin
  -fno-asynchronous-unwind-tables -fno-unwind-tables
  -fomit-frame-pointer
  -D_FORTIFY_SOURCE=0
  -DKERNEL -D__STRICT_BSD__
  -DLOGNAME=\"xe3\"
  -I"$ROOT/MacKernelSDK/Headers"
  -I"$SDK/usr/include"
  -I"$ROOT/VoodooPS2Controller"
  -I"$ROOT/VoodooPS2Keyboard"
  -Wno-deprecated-declarations
  -Wno-unused-private-field
  -O2
)
C_FLAGS=( "${COMMON_FLAGS[@]}" -std=gnu11 )
CXX_FLAGS=( "${COMMON_FLAGS[@]}" -std=c++14 )

LDFLAGS=(
  -arch x86_64
  -mmacosx-version-min=10.13
  -isysroot "$SDK"
  -mkernel
  -nostdlib
  -Xlinker -kext
  -Xlinker -dead_strip
)

rm -rf "$ROOT/build"
mkdir -p "$BUILD" "$BUNDLE/Contents/MacOS" "$BUNDLE/Contents/PlugIns"
mkdir -p "$BUILD/obj"

echo "== building VoodooPS2Controller =="
CTRL_SRCS=(
  VoodooPS2Controller/VoodooPS2Controller.cpp
  VoodooPS2Controller/AppleACPIPS2Nub.cpp
  VoodooPS2Controller/ApplePS2Device.cpp
  VoodooPS2Controller/ApplePS2KeyboardDevice.cpp
  VoodooPS2Controller/ApplePS2MouseDevice.cpp
)
CTRL_OBJS=()
for src in "${CTRL_SRCS[@]}"; do
  obj="$BUILD/obj/$(basename "${src%.cpp}").o"
  echo "  CXX $src"
  "$CXX" "${CXX_FLAGS[@]}" -c -o "$obj" "$src"
  CTRL_OBJS+=("$obj")
done
echo "  CC VoodooPS2Controller/kmod_info.c"
"$CC" "${C_FLAGS[@]}" -c -o "$BUILD/obj/ctrl_kmod_info.o" VoodooPS2Controller/kmod_info.c
CTRL_OBJS+=("$BUILD/obj/ctrl_kmod_info.o")
"$CXX" "${LDFLAGS[@]}" -o "$BUNDLE/Contents/MacOS/VoodooPS2Controller" \
  "${CTRL_OBJS[@]}" "$ROOT/MacKernelSDK/Library/x86_64/libkmod.a"

python3 - "$ROOT/VoodooPS2Controller/VoodooPS2Controller-Info.plist" \
          "$BUNDLE/Contents/Info.plist" "$MODULE_VERSION" "$KEXT_ID" <<'PY'
import sys
src, dst, ver, bid = sys.argv[1:5]
s = open(src).read()
s = s.replace('${MODULE_VERSION}', ver).replace('$(PRODUCT_BUNDLE_IDENTIFIER)', bid)
open(dst, 'w').write(s)
PY

echo "== building VoodooPS2Keyboard =="
KBD_BUNDLE="$BUNDLE/Contents/PlugIns/VoodooPS2Keyboard.kext"
mkdir -p "$KBD_BUNDLE/Contents/MacOS"
"$CXX" "${CXX_FLAGS[@]}" -c -o "$BUILD/obj/VoodooPS2Keyboard.o" \
  VoodooPS2Keyboard/VoodooPS2Keyboard.cpp
echo "  CC VoodooPS2Keyboard/kmod_info.c"
"$CC" "${C_FLAGS[@]}" -c -o "$BUILD/obj/kbd_kmod_info.o" VoodooPS2Keyboard/kmod_info.c
"$CXX" "${LDFLAGS[@]}" -o "$KBD_BUNDLE/Contents/MacOS/VoodooPS2Keyboard" \
  "$BUILD/obj/VoodooPS2Keyboard.o" "$BUILD/obj/kbd_kmod_info.o" \
  "$ROOT/MacKernelSDK/Library/x86_64/libkmod.a"

python3 - "$ROOT/VoodooPS2Keyboard/VoodooPS2Keyboard-Info.plist" \
          "$KBD_BUNDLE/Contents/Info.plist" "$MODULE_VERSION" "$KBD_ID" <<'PY'
import sys
src, dst, ver, bid = sys.argv[1:5]
s = open(src).read()
s = s.replace('${MODULE_VERSION}', ver).replace('$(PRODUCT_BUNDLE_IDENTIFIER)', bid)
open(dst, 'w').write(s)
PY

chmod -R go-w "$BUNDLE"
echo "== ad-hoc signing =="
codesign --force --deep --sign - "$BUNDLE"
codesign --verify --strict --verbose=2 "$BUNDLE" || true

echo "== artifacts =="
file "$BUNDLE/Contents/MacOS/VoodooPS2Controller"
otool -hv "$BUNDLE/Contents/MacOS/VoodooPS2Controller" | head -5
plutil -lint "$BUNDLE/Contents/Info.plist"
plutil -lint "$KBD_BUNDLE/Contents/Info.plist"
plutil -p "$BUNDLE/Contents/Info.plist" | grep -E 'CFBundleVersion|CFBundleIdentifier' | head -4
shasum -a 256 "$BUNDLE/Contents/MacOS/VoodooPS2Controller" \
             "$KBD_BUNDLE/Contents/MacOS/VoodooPS2Keyboard" \
             "$BUNDLE/Contents/Info.plist" "$KBD_BUNDLE/Contents/Info.plist"
echo "BUILD OK: $BUNDLE"
