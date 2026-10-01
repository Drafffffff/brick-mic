#!/bin/bash
set -euo pipefail
TASK_ROOT=$(cd "$(dirname "$0")/.." && pwd -P)
VERSION=$(cat "$TASK_ROOT/VERSION")
OUTPUT="$TASK_ROOT/build/brick-mic"
DEST="$TASK_ROOT/releases/v$VERSION"
APP="$OUTPUT/Brick Mic.app"
PAK="$OUTPUT/Brick Mic.pak"
[ "$(uname -s)" = Darwin ] || { echo 'Release packaging requires macOS (ditto).' >&2; exit 1; }
test -x "$APP/Contents/MacOS/BrickMic"
test -x "$PAK/pocketjs-mic.elf"
test -x "$PAK/brick-micd"
codesign --verify --deep --strict "$APP"
ARCH=$(lipo -archs "$APP/Contents/MacOS/BrickMic")
[ "$ARCH" = arm64 ] || { echo 'Current release asset name is for arm64; update the filename for a different architecture.' >&2; exit 1; }
mkdir -p "$DEST"
# No personal configuration or diagnostic files enter the distribution.
/usr/bin/ditto -c -k --keepParent --norsrc --noextattr "$APP" "$DEST/BrickMic-macOS-arm64.zip"
/usr/bin/ditto -c -k --keepParent --norsrc --noextattr "$PAK" "$DEST/BrickMic-TrimUI-Brick-NextUI.zip"
{
    printf 'Brick Mic v%s\n' "$VERSION"
    printf 'Source commit: %s\n' "$(git -C "$TASK_ROOT" rev-parse HEAD)"
    printf 'Mac: macOS 13+, arm64, local ad-hoc signature, not notarized\n'
    swiftc --version
    go version
    printf '\nBrick build inputs and receipt:\n'
    cat "$OUTPUT/brick-build-receipt.txt"
} > "$DEST/BUILD-INFO.txt"
(cd "$DEST" && shasum -a 256 BrickMic-macOS-arm64.zip BrickMic-TrimUI-Brick-NextUI.zip BUILD-INFO.txt > SHA256SUMS.txt)
printf 'Release assets: %s\n' "$DEST"
