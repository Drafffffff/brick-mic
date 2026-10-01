#!/bin/bash
set -euo pipefail
TASK_ROOT=$(cd "$(dirname "$0")/.." && pwd -P)
APP_VERSION=$(cat "$TASK_ROOT/VERSION")
MAC_ARCH=$(uname -m)
MAC_SDK=$(xcrun --sdk macosx --show-sdk-path)
OUTPUT="$TASK_ROOT/build/brick-mic"
APP="$OUTPUT/Brick Mic.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
swiftc -swift-version 5 -framework AppKit "$TASK_ROOT/mac/Brand.swift" "$TASK_ROOT/mac/render-icon.swift" -o "$OUTPUT/render-icon"
"$OUTPUT/render-icon" "$OUTPUT/BrickMic.iconset"
iconutil -c icns "$OUTPUT/BrickMic.iconset" -o "$APP/Contents/Resources/BrickMic.icns"
swiftc -swift-version 5 -O -target "$MAC_ARCH-apple-macosx13.0" -sdk "$MAC_SDK" -framework AppKit -framework CoreBluetooth -framework ApplicationServices \
  "$TASK_ROOT/mac/Credentials.swift" \
  "$TASK_ROOT/mac/Codec.swift" "$TASK_ROOT/mac/ASR.swift" \
  "$TASK_ROOT/mac/Bluetooth.swift" "$TASK_ROOT/mac/Brand.swift" \
  "$TASK_ROOT/mac/Interface.swift" "$TASK_ROOT/mac/main.swift" \
  -o "$APP/Contents/MacOS/BrickMic"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>com.nextui.brickmic</string>
<key>CFBundleName</key><string>Brick Mic</string>
<key>CFBundleIconFile</key><string>BrickMic</string>
<key>CFBundleExecutable</key><string>BrickMic</string>
<key>CFBundleVersion</key><string>2</string>
<key>CFBundleShortVersionString</key><string>$APP_VERSION</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>LSUIElement</key><true/>
<key>NSBluetoothAlwaysUsageDescription</key><string>通过蓝牙接收你在 TrimUI Brick 上按键录制的语音。</string>
<key>NSBluetoothPeripheralUsageDescription</key><string>连接 TrimUI Brick 语音输入设备。</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
codesign --force --sign - --identifier com.nextui.brickmic "$APP"
printf 'Built: %s\n' "$APP"
