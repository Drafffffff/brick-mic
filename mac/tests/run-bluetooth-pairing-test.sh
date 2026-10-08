#!/bin/sh
set -eu
taskTestsDir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
taskMacDir=$(CDPATH= cd -- "$taskTestsDir/.." && pwd)
taskTempDir=$(mktemp -d "${TMPDIR:-/tmp}/brick-mic-pairing.XXXXXX")
trap 'rm -rf "$taskTempDir"' EXIT HUP INT TERM
python3 - "$taskMacDir/Bluetooth.swift" "$taskTestsDir/BluetoothPairingHarness.swift" "$taskTempDir/Harness.swift" <<'PY'
from pathlib import Path
import sys
production=Path(sys.argv[1]).read_text().replace('import CoreBluetooth','').replace('UserDefaults.standard','fixtureDefaults')
fixture=Path(sys.argv[2]).read_text()
assert fixture.count('// INJECT_PRODUCTION_BLUETOOTH')==1
Path(sys.argv[3]).write_text(fixture.replace('// INJECT_PRODUCTION_BLUETOOTH',production))
PY
swiftc -parse-as-library "$taskMacDir/Codec.swift" "$taskTempDir/Harness.swift" -o "$taskTempDir/test"
"$taskTempDir/test"
