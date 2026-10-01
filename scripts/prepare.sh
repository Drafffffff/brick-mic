#!/bin/bash
set -euo pipefail
TASK_ROOT=$(cd "$(dirname "$0")/.." && pwd -P)
source "$TASK_ROOT/scripts/pins.env"
CORE="${BRICK_MIC_CACHE:-$TASK_ROOT/build/pocketjs-port}"
mkdir -p "$CORE"
checkout() {
    local url="$1" revision="$2" destination="$3"
    if [ ! -d "$destination/.git" ]; then
        git clone --no-checkout --depth 1 "$url" "$destination"
    fi
    if [ -n "$(git -C "$destination" status --porcelain)" ]; then
        echo "Dependency has local changes: $destination" >&2; exit 1
    fi
    if [ "$(git -C "$destination" rev-parse HEAD 2>/dev/null || true)" != "$revision" ]; then
        git -C "$destination" fetch --depth 1 origin "$revision"
        git -C "$destination" checkout --detach "$revision"
    fi
}
checkout "$POCKETJS_URL" "$POCKETJS_REV" "$CORE/upstream"
checkout "$QUICKJS_URL" "$QUICKJS_REV" "$CORE/quickjs"
test "$(cat "$CORE/quickjs/libquickjs-sys/embed/quickjs/VERSION")" = "$QUICKJS_VERSION"
case "$(uname -s)-$(uname -m)" in
    Darwin-arm64) BUN_ASSET=bun-darwin-aarch64 ;;
    Darwin-x86_64) BUN_ASSET=bun-darwin-x64 ;;
    Linux-aarch64) BUN_ASSET=bun-linux-aarch64 ;;
    Linux-x86_64) BUN_ASSET=bun-linux-x64 ;;
    *) echo 'Unsupported host; set POCKETJS_BUN to the pinned Bun binary.' >&2; exit 1 ;;
esac
BUN="${POCKETJS_BUN:-$CORE/bun/$BUN_ASSET/bun}"
if [ ! -x "$BUN" ]; then
    mkdir -p "$CORE/bun"
    curl --fail --location --retry 3 "https://github.com/oven-sh/bun/releases/download/bun-v$BUN_VERSION/$BUN_ASSET.zip" -o "$CORE/bun/$BUN_ASSET.zip"
    unzip -qo "$CORE/bun/$BUN_ASSET.zip" -d "$CORE/bun"
fi
test "$("$BUN" --version)" = "$BUN_VERSION"
"$BUN" install --frozen-lockfile --cwd "$CORE/upstream"
printf 'Pinned PocketJS, QuickJS and Bun ready.\n'
