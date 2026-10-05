#!/bin/bash
# SPDX-License-Identifier: LGPL-2.1-or-later
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
OUT=$(mktemp -d)
trap 'rm -rf "$OUT"' EXIT
cc -std=c11 -Wall -Wextra -Werror -pedantic -I "$HERE/Sources" "$HERE/Sources/KeyRoute.c" "$HERE/Tests/key_route_test.c" -o "$OUT/key-test"
"$OUT/key-test"
if command -v swiftc >/dev/null; then
  swiftc "$HERE/Sources/Composition.swift" "$HERE/Tests/composition_test.swift" -o "$OUT/composition-test"
  "$OUT/composition-test"
else
  echo 'SKIPPED: Swift composition tests (swiftc unavailable)'
fi
