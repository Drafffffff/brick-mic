# Third-party notices

Brick Mic code is distributed under GPL-3.0, as in the original [next-ui-AItranslate](https://github.com/Drafffffff/next-ui-AItranslate) project. Runtime adapters originated there; the standalone extraction changes source layout and build paths. NextUI itself is a separate installed system and is not included in these packages.

| Component | Source / version | License / notice |
| --- | --- | --- |
| PocketJS | https://github.com/pocket-nexus/pocketjs at `ed2d84af39fc0adc6a688cf0a1bef801a3084e26` | MIT, `licenses/POCKETJS-LICENSE.txt` |
| QuickJS | https://github.com/pocket-nexus/quickjs-rs at `ba5bdd0dc013518768e76cd9e05cd30ed53dd35b`, engine 2026-06-04 | MIT, `licenses/QUICKJS-LICENSE.txt` |
| Solid | Locked by pinned PocketJS bun.lock | MIT, `licenses/SOLID-LICENSE.txt` |
| godbus/dbus/v5 | v5.2.0 | BSD-2-Clause, `licenses/GODBUS-LICENSE.txt` |
| golang.org/x/sys | v0.27.0 | BSD-3-Clause, `licenses/GO-X-SYS-LICENSE.txt` |
| Go runtime | Compiler version recorded in Release build info | BSD-3-Clause, `licenses/GO-LICENSE.txt` |
| Rust standard library | rustc 1.98.0-nightly, `4c9d2bfe4` | MIT / Apache-2.0, `licenses/RUST-LICENSE-*.txt` |
| Rust dependencies | Locked by pinned PocketJS Cargo.lock | Individual notices in `licenses/rust/` |
| SDL2 / SDL2_ttf | Dynamically linked to NextUI's existing libraries | zlib, `licenses/SDL2-LICENSE.txt`, `licenses/SDL2-TTF-LICENSE.txt` |
| Lucide menu icons | https://github.com/lucide-icons/lucide | ISC, `mac/assets/lucide/LICENSE.txt` |
| Chinese fonts | See `fonts/README.md` | SIL OFL 1.1; notices in `fonts/` and Brick package |

The tg5040 Docker build environment is pinned by image digest in `scripts/pins.env`. Dependency acquisition and checks are part of the build scripts; upstream source is not copied into this repository. License texts from the pinned runtime dependencies accompany the compiled Brick package. Font software retains its own OFL license rather than the code's GPL license.

The macOS app uses Apple's system frameworks; they are not bundled. API Key and personal configuration are not part of either distribution.
