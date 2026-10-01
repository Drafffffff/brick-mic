#!/bin/bash
set -euo pipefail
cd /work
source scripts/pins.env
CORE=/work/build/pocketjs-port
UPSTREAM="$CORE/upstream"
QJS="$CORE/quickjs/libquickjs-sys/embed/quickjs"
PKG='/work/build/brick-mic/Brick Mic.pak'
export RUSTUP_HOME="$CORE/rustup" CARGO_HOME="$CORE/cargo"
export PATH="$CARGO_HOME/bin:$PATH"
if [ ! -x "$CARGO_HOME/bin/rustup" ]; then
    wget --https-only -q https://static.rust-lang.org/rustup/dist/aarch64-unknown-linux-gnu/rustup-init -O "$CORE/rustup-init"
    chmod +x "$CORE/rustup-init"
    "$CORE/rustup-init" -y --no-modify-path --profile minimal --default-toolchain "$RUST_CHANNEL"
fi
rustup toolchain install "$RUST_CHANNEL" --profile minimal
export CARGO_TARGET_AARCH64_UNKNOWN_LINUX_GNU_LINKER=aarch64-nextui-linux-gnu-gcc
export RUSTFLAGS='-C target-cpu=cortex-a53'
cargo +"$RUST_CHANNEL" build --release --locked --no-default-features \
    --manifest-path "$UPSTREAM/engine/ui-cabi/Cargo.toml" --features bare-platform,software-only \
    --target aarch64-unknown-linux-gnu --target-dir "$CORE/rust-app-target"
mkdir -p "$CORE/quickjs-objects" "$PKG"
for source in quickjs cutils libregexp libunicode dtoa; do
    aarch64-nextui-linux-gnu-gcc -std=gnu11 -O2 -mcpu=cortex-a53 -D_GNU_SOURCE \
        -DCONFIG_VERSION=\""$QUICKJS_VERSION"\" -I"$QJS" \
        -c "$QJS/$source.c" -o "$CORE/quickjs-objects/$source.o"
done
aarch64-nextui-linux-gnu-gcc -std=gnu11 -O2 -Wall -Wextra -Werror -Wno-unused-parameter -mcpu=cortex-a53 \
    -I"$UPSTREAM/engine/ui-cabi/include" -I"$UPSTREAM/engine/quickjs-c" \
    -I"$UPSTREAM/hosts/nokia-e7/runtime" -I"$UPSTREAM/contracts/generated" -I"$QJS" \
    -I/work/native $(pkg-config --cflags sdl2) \
    -DPOCKET_RUNTIME_EXTENSION -DPOCKETJS_CUSTOM_EXTENSION -DDYNAMIC_PX=40 \
    -DPOCKETJS_TARGET_ID=\"brick-experimental\" -DPOCKETJS_HOST_ABI=1 -DPOCKETJS_REV=\""$POCKETJS_REV"\" \
    brick/host/pocket-host.c brick/host/mic-native.c brick/host/mic-power.c \
    native/brick-services.c native/brick-hardware.c native/compat.c \
    "$UPSTREAM/engine/quickjs-c/pocket_runtime.c" "$UPSTREAM/engine/quickjs-c/rust_eh_personality.c" \
    "$CORE/quickjs-objects/"*.o "$CORE/rust-app-target/aarch64-unknown-linux-gnu/release/libpocketjs_symbian_core.a" \
    $(pkg-config --libs sdl2) -lSDL2_ttf -lm -ldl -lpthread -o "$PKG/pocketjs-mic.elf"
{
    printf 'PocketJS=%s\nQuickJS=%s\nBun=%s\nToolchain=%s\nRust=%s\n' "$POCKETJS_REV" "$QUICKJS_REV" "$BUN_VERSION" "$TOOLCHAIN_IMAGE" "$RUST_CHANNEL"
    sha256sum "$PKG/pocketjs-mic.elf" "$PKG/brick-micd" "$PKG/brick-app.js" "$PKG/brick-app.pak"
    aarch64-nextui-linux-gnu-readelf -d "$PKG/pocketjs-mic.elf" | sed -n '/NEEDED/p'
    aarch64-nextui-linux-gnu-readelf --version-info "$PKG/pocketjs-mic.elf"
} > /work/build/brick-mic/brick-build-receipt.txt
