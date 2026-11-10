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
ICONTMP="$(mktemp -d)"
trap 'rm -rf "$ICONTMP"' EXIT
swiftc -O -swift-version 5 Tools/make_icon.swift -o "$ICONTMP/make_icon"
"$ICONTMP/make_icon" "$ICONTMP/AppIcon.iconset"
iconutil -c icns "$ICONTMP/AppIcon.iconset" -o "$APP/Contents/Resources/AppIcon.icns"
cp Resources/Info.plist "$APP/Contents/Info.plist"
printf 'APPL????' > "$APP/Contents/PkgInfo"
codesign --force --sign - --identifier no.bechsor.babymode "$APP"
echo "Built $(pwd)/$APP"
