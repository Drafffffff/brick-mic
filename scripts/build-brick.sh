#!/bin/bash
set -euo pipefail
TASK_ROOT=$(cd "$(dirname "$0")/.." && pwd -P)
OUTPUT="$TASK_ROOT/build/brick-mic"
PKG="$OUTPUT/Brick Mic.pak"
mkdir -p "$PKG"
(cd "$TASK_ROOT/brick" && GOOS=linux GOARCH=arm64 CGO_ENABLED=0 go build -trimpath -ldflags='-s -w' -o "$PKG/brick-micd" .)
"$TASK_ROOT/scripts/build-ui.sh" brick
cp "$TASK_ROOT/scripts/launch.sh" "$TASK_ROOT/scripts/start-services.sh" "$TASK_ROOT/scripts/resume.sync.sh" "$PKG/"
cp "$TASK_ROOT/LICENSE" "$PKG/LICENSE.txt"
cp "$TASK_ROOT/README.md" "$PKG/README.md"
cp -Rf "$TASK_ROOT/licenses" "$PKG/"
python3 - "$PKG" "$OUTPUT/pak-sha256.tmp" <<'PYTHON'
from pathlib import Path
import hashlib,sys
folder=Path(sys.argv[1])
lines=[hashlib.sha256(p.read_bytes()).hexdigest()+"  "+p.relative_to(folder).as_posix()+"\n" for p in sorted(folder.rglob('*')) if p.is_file() and p.name!='SHA256SUMS']
Path(sys.argv[2]).write_text(''.join(lines))
PYTHON
chmod +x "$PKG/launch.sh" "$PKG/start-services.sh" "$PKG/resume.sync.sh" "$PKG/pocketjs-mic.elf" "$PKG/brick-micd"

mv "$OUTPUT/pak-sha256.tmp" "$PKG/SHA256SUMS"
printf 'Built: %s\n' "$PKG"
