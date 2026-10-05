#!/bin/bash
# SPDX-License-Identifier: LGPL-2.1-or-later
set -euo pipefail
export MACOSX_DEPLOYMENT_TARGET=13.0
if [[ $(uname -s) != Darwin ]]; then echo 'This app requires macOS and Xcode command-line tools.' >&2; exit 1; fi
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
OUT=${CHEWING_MAC_BUILD_DIR:-"$ROOT/build-macos"}
PREFIX="$OUT/core-install"
APP="$OUT/ChewingMac.app"
for tool in cmake cargo xcrun; do command -v "$tool" >/dev/null || { echo "Missing $tool" >&2; exit 1; }; done
[[ -f "$ROOT/data/CMakeLists.txt" ]] || { echo 'Initialize the upstream data submodule before building.' >&2; exit 1; }
cmake -S "$ROOT" -B "$OUT/core" -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=ON -DWITH_SQLITE3=OFF -DBUILD_DOC=OFF -DBUILD_TESTING=ON -DCMAKE_INSTALL_PREFIX="$PREFIX"
cmake --build "$OUT/core" --parallel
ctest --test-dir "$OUT/core" --output-on-failure
cmake --install "$OUT/core"
mkdir -p "$APP/Contents/"{MacOS,Frameworks,Resources/libchewing} "$OUT/module"
cp "$ROOT/contrib/macos/Info.plist" "$APP/Contents/Info.plist"
cp "$PREFIX/share/libchewing/"* "$APP/Contents/Resources/libchewing/"
cp "$ROOT/COPYING" "$APP/Contents/Resources/COPYING.libchewing"
cp "$ROOT/AUTHORS" "$APP/Contents/Resources/AUTHORS.libchewing"
# The app uses the existing public CChewing interface to the Rust core.
cp "$ROOT/capi/include/chewing.h" "$OUT/module/chewing.h"
cp "$ROOT/contrib/macos/Sources/KeyRoute.h" "$OUT/module/KeyRoute.h"
cat > "$OUT/module/module.modulemap" <<'MAP'
module CChewing { header "chewing.h" header "KeyRoute.h" export * }
MAP
LIBRARY=$(find "$PREFIX/lib" -maxdepth 1 -type f -name 'libchewing.*.dylib' | head -n 1)
[[ -n "$LIBRARY" ]] || { echo 'No built libchewing dylib found' >&2; exit 1; }
cp "$LIBRARY" "$APP/Contents/Frameworks/libchewing.dylib"
install_name_tool -id '@rpath/libchewing.dylib' "$APP/Contents/Frameworks/libchewing.dylib"
SDK=$(xcrun --sdk macosx --show-sdk-path)
ARCH=$(uname -m)
TARGET="$ARCH-apple-macosx13.0"
xcrun clang -target "$TARGET" -isysroot "$SDK" -Wall -Wextra -Werror -c "$ROOT/contrib/macos/Sources/KeyRoute.c" -o "$OUT/KeyRoute.o"
xcrun swiftc -swift-version 5 -target "$TARGET" -sdk "$SDK" -I "$OUT/module" \
  "$ROOT/contrib/macos/Sources/"*.swift "$OUT/KeyRoute.o" \
  -L "$APP/Contents/Frameworks" -lchewing -framework AppKit -framework InputMethodKit \
  -Xlinker -rpath -Xlinker '@executable_path/../Frameworks' -o "$APP/Contents/MacOS/ChewingMac"
# Local development signing only; no Developer ID, notarization, or installation.
codesign --force --sign - "$APP/Contents/Frameworks/libchewing.dylib"
codesign --force --sign - "$APP"
plutil -lint "$APP/Contents/Info.plist"
codesign --verify --deep --strict "$APP"
otool -L "$APP/Contents/MacOS/ChewingMac"
otool -L "$APP/Contents/Frameworks/libchewing.dylib"
# A development bundle must not depend on the build machine's Homebrew prefix.
if otool -L "$APP/Contents/Frameworks/libchewing.dylib" | grep -E '^[[:space:]]+/(opt/|usr/local/|Users/)'; then
  echo 'Non-system dylib dependency must be bundled before distributing.' >&2
  exit 1
fi
bash "$ROOT/contrib/macos/test.sh"
xcrun swiftc -swift-version 5 -target "$TARGET" -sdk "$SDK" -I "$OUT/module" \
  "$ROOT/contrib/macos/Sources/Composition.swift" "$ROOT/contrib/macos/Sources/ChewingEngine.swift" \
  "$ROOT/contrib/macos/Tests/engine_test.swift" -L "$APP/Contents/Frameworks" -lchewing \
  -Xlinker -rpath -Xlinker "$APP/Contents/Frameworks" -o "$OUT/engine-test"
"$OUT/engine-test" "$APP/Contents/Resources/libchewing"
echo "Built development app: $APP"
echo 'Build success is not an InputMethodKit runtime/typing test. See README.md.'
