#!/bin/bash
set -euo pipefail
TASK_ROOT=$(cd "$(dirname "$0")/.." && pwd -P)
source "$TASK_ROOT/scripts/pins.env"
MODE="${1:-brick}"
[ "$MODE" = brick ] || [ "$MODE" = mac ] || { echo 'Usage: build-ui.sh [brick|mac]' >&2; exit 1; }
OUTPUT="$TASK_ROOT/build/brick-mic"
CORE="${BRICK_MIC_CACHE:-$TASK_ROOT/build/pocketjs-port}"
UPSTREAM="$CORE/upstream"
QJS="$CORE/quickjs/libquickjs-sys/embed/quickjs"
"$TASK_ROOT/scripts/prepare.sh"
case "$(uname -s)-$(uname -m)" in
    Darwin-arm64) BUN_ASSET=bun-darwin-aarch64 ;; Darwin-x86_64) BUN_ASSET=bun-darwin-x64 ;;
    Linux-aarch64) BUN_ASSET=bun-linux-aarch64 ;; Linux-x86_64) BUN_ASSET=bun-linux-x64 ;; *) exit 1 ;;
esac
BUN="${POCKETJS_BUN:-$CORE/bun/$BUN_ASSET/bun}"
if [ "$MODE" = mac ]; then PKG="$OUTPUT/pocketjs-preview"; else PKG="$OUTPUT/Brick Mic.pak"; fi
mkdir -p "$PKG"
"$BUN" "$UPSTREAM/tools/build.ts" "$TASK_ROOT/ui/app.tsx" \
    --framework=solid --no-config --density=1 --hz=60 \
    --font-regular="$TASK_ROOT/fonts/font1.ttf" --font-bold="$TASK_ROOT/fonts/font1.ttf" \
    --project-root="$TASK_ROOT" --outdir="$OUTPUT/ui-bundle"
cp "$OUTPUT/ui-bundle/app.js" "$PKG/brick-app.js"
cp "$OUTPUT/ui-bundle/app.pak" "$PKG/brick-app.pak"
cp "$TASK_ROOT/fonts/NotoSansSC-Regular.otf" "$TASK_ROOT/fonts/NotoSansSC-OFL.txt" "$PKG/"
cp "$UPSTREAM/LICENSE" "$PKG/POCKETJS-LICENSE.txt"
cp "$QJS/LICENSE" "$PKG/QUICKJS-LICENSE.txt"
cp "$UPSTREAM/node_modules/solid-js/LICENSE" "$PKG/SOLID-LICENSE.txt"
cp "$TASK_ROOT/fonts/ChillRound-OFL.txt" "$TASK_ROOT/fonts/RoundedMplus-OFL.txt" "$TASK_ROOT/fonts/ZenMaruGothic-OFL.txt" "$PKG/"
cp "$TASK_ROOT/THIRD_PARTY_NOTICES.md" "$PKG/"
if [ "$MODE" = mac ]; then
    [ "$(uname -s)" = Darwin ] || { echo 'Preview requires macOS.' >&2; exit 1; }
    pkg-config --exists sdl2 SDL2_ttf
    "$TASK_ROOT/scripts/build-preview-runtime.sh"
    case "$(uname -m)" in arm64) TARGET=aarch64-apple-darwin ;; x86_64) TARGET=x86_64-apple-darwin ;; *) exit 1 ;; esac
    clang -std=gnu11 -O2 -Wall -Wextra -Werror -Wno-unused-parameter \
        -I"$UPSTREAM/engine/ui-cabi/include" -I"$UPSTREAM/engine/quickjs-c" \
        -I"$UPSTREAM/hosts/nokia-e7/runtime" -I"$UPSTREAM/contracts/generated" -I"$QJS" \
        -I"$TASK_ROOT/native" $(pkg-config --cflags sdl2 SDL2_ttf) \
        -DPOCKET_RUNTIME_EXTENSION -DPOCKETJS_CUSTOM_EXTENSION -DDYNAMIC_PX=40 \
        -DPOCKETJS_TARGET_ID=\"brick-experimental\" -DPOCKETJS_HOST_ABI=1 -DPOCKETJS_REV=\""$POCKETJS_REV"\" \
        "$TASK_ROOT/brick/host/pocket-host.c" "$TASK_ROOT/brick/host/mic-native.c" "$TASK_ROOT/brick/host/mic-power.c" \
        "$TASK_ROOT/native/brick-services.c" "$TASK_ROOT/native/brick-hardware.c" \
        "$UPSTREAM/engine/quickjs-c/pocket_runtime.c" "$UPSTREAM/engine/quickjs-c/rust_eh_personality.c" \
        "$CORE/mac-preview/objects/"*.o "$CORE/mac-target/$TARGET/release/libpocketjs_symbian_core.a" \
        $(pkg-config --libs sdl2 SDL2_ttf) -lm -lpthread -o "$PKG/pocketjs-mic"
    APP="$PKG/Brick Mic UI Preview.app"
    mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
    cp "$PKG/pocketjs-mic" "$APP/Contents/MacOS/pocketjs-mic"
    cp "$PKG/brick-app.js" "$PKG/brick-app.pak" "$PKG/NotoSansSC-Regular.otf" "$APP/Contents/Resources/"
    cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?><plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>pocketjs-mic</string>
<key>CFBundleIdentifier</key><string>com.nextui.brickmic.preview</string>
<key>CFBundleName</key><string>Brick Mic UI Preview</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
    codesign --force --sign - "$APP"
else
    docker run --rm --platform linux/arm64 -v "$TASK_ROOT:/work" -v "$CORE:/work/build/pocketjs-port" \
        "$TOOLCHAIN_IMAGE" /bin/bash /work/scripts/container-build.sh
fi
printf 'Built UI: %s\n' "$PKG"
