#!/bin/bash
set -euo pipefail
TASK_ROOT=$(cd "$(dirname "$0")/.." && pwd -P)
source "$TASK_ROOT/scripts/pins.env"
CORE="${BRICK_MIC_CACHE:-$TASK_ROOT/build/pocketjs-port}"
UPSTREAM="$CORE/upstream"
QJS="$CORE/quickjs/libquickjs-sys/embed/quickjs"
export RUSTUP_HOME="$CORE/mac-toolchain/rustup" CARGO_HOME="$CORE/mac-toolchain/cargo"
export PATH="$CARGO_HOME/bin:$PATH"
if [ ! -x "$CARGO_HOME/bin/cargo" ]; then
    mkdir -p "$CORE/mac-toolchain"
    case "$(uname -m)" in arm64) RUST_HOST=aarch64-apple-darwin ;; x86_64) RUST_HOST=x86_64-apple-darwin ;; *) exit 1 ;; esac
    curl --fail --location --retry 3 "https://static.rust-lang.org/rustup/dist/$RUST_HOST/rustup-init" -o "$CORE/mac-toolchain/rustup-init"
    chmod +x "$CORE/mac-toolchain/rustup-init"
    "$CORE/mac-toolchain/rustup-init" -y --no-modify-path --profile minimal --default-toolchain "$RUST_CHANNEL"
fi
rustup toolchain install "$RUST_CHANNEL" --profile minimal
TARGET=$(rustc +"$RUST_CHANNEL" -vV | sed -n 's/^host: //p')
cargo +"$RUST_CHANNEL" build --release --locked --no-default-features \
    --manifest-path "$UPSTREAM/engine/ui-cabi/Cargo.toml" --features bare-platform,software-only \
    --target "$TARGET" --target-dir "$CORE/mac-target"
mkdir -p "$CORE/mac-preview/objects"
for source in quickjs cutils libregexp libunicode dtoa; do
    clang -std=gnu11 -O2 -D_GNU_SOURCE -DCONFIG_VERSION=\""$QUICKJS_VERSION"\" -I"$QJS" \
        -c "$QJS/$source.c" -o "$CORE/mac-preview/objects/$source.o"
done
