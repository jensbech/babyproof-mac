#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
APP="Baby Mode.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
swiftc -O -swift-version 5 \
    Sources/Core/*.swift Sources/App/*.swift \
    -o "$APP/Contents/MacOS/BabyMode" \
    -framework Cocoa -framework IOKit -framework ApplicationServices -framework QuartzCore
cp Resources/Info.plist "$APP/Contents/Info.plist"
printf 'APPL????' > "$APP/Contents/PkgInfo"
codesign --force --sign - --identifier no.bechsor.babymode "$APP"
echo "Built $(pwd)/$APP"
