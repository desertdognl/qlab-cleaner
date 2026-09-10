#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
SRC="$ROOT/QLabCleaner/Sources"
RES="$ROOT/QLabCleaner/Resources"
DIST="$ROOT/dist"
APP="$DIST/QLab Cleaner.app"
BIN="$APP/Contents/MacOS"
RESOURCES="$APP/Contents/Resources"
INSTALL="/Applications/QLab Cleaner.app"
SDK="$(xcrun --show-sdk-path)"
TARGET="arm64-apple-macos13"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$ROOT/QLabCleaner/Info.plist")"
DMG="$DIST/QLab-Cleaner-${VERSION}.dmg"

mkdir -p "$DIST" "$ROOT/bin"

SHARED=(
  "$SRC/AppInfo.swift"
  "$SRC/Localization.swift"
  "$SRC/Models.swift"
  "$SRC/KeyedArchive.swift"
  "$SRC/QLabParser.swift"
  "$SRC/Analyzer.swift"
)

echo "→ Parser-test bouwen"
cat > "$SRC/.CLIMain.swift" <<'EOF'
@main
struct CLIMain {
    static func main() {
        ParseCLI.run()
    }
}
EOF

swiftc -O -target "$TARGET" -sdk "$SDK" \
  -framework CryptoKit \
  -o "$ROOT/bin/qlab-parse" \
  "${SHARED[@]}" \
  "$SRC/ParseCLI.swift" \
  "$SRC/.CLIMain.swift"
rm -f "$SRC/.CLIMain.swift"

echo "→ Voorbeelden analyseren"
"$ROOT/bin/qlab-parse" "$ROOT/Examples/qlab example 1/qlab example 1.qlab5"
echo "-----"
"$ROOT/bin/qlab-parse" "$ROOT/Examples/Example 2/Example 2.qlab5" "$ROOT/Examples/Content folder"
echo "-----"
"$ROOT/bin/qlab-parse" --backups "$ROOT/Examples/qlab example 1/qlab example 1.qlab5"

echo "→ App bundelen"
rm -rf "$APP"
mkdir -p "$BIN" "$RESOURCES"

swiftc -O -parse-as-library -target "$TARGET" -sdk "$SDK" \
  -framework SwiftUI -framework AppKit -framework Foundation -framework UniformTypeIdentifiers -framework Quartz -framework CryptoKit \
  -o "$BIN/QLabCleaner" \
  "${SHARED[@]}" \
  "$SRC/Theme.swift" \
  "$SRC/AppStore.swift" \
  "$SRC/QLabProcess.swift" \
  "$SRC/QuickLookSupport.swift" \
  "$SRC/QLabCleanerApp.swift" \
  "$SRC/SetupViews.swift" \
  "$SRC/ResultsView.swift"

cp "$ROOT/QLabCleaner/Info.plist" "$APP/Contents/Info.plist"
cp "$RES/logo_full_white.png" "$RESOURCES/logo_full_white.png"
cp "$RES/bmc-button.png" "$RESOURCES/bmc-button.png"

echo "→ App-icoon"
ICONSET="$DIST/AppIcon.iconset"
rm -rf "$ICONSET"
mkdir -p "$ICONSET"
sips -s format png -z 16 16     "$RES/AppIcon.png" --out "$ICONSET/icon_16x16.png" >/dev/null
sips -s format png -z 32 32     "$RES/AppIcon.png" --out "$ICONSET/icon_16x16@2x.png" >/dev/null
sips -s format png -z 32 32     "$RES/AppIcon.png" --out "$ICONSET/icon_32x32.png" >/dev/null
sips -s format png -z 64 64     "$RES/AppIcon.png" --out "$ICONSET/icon_32x32@2x.png" >/dev/null
sips -s format png -z 128 128   "$RES/AppIcon.png" --out "$ICONSET/icon_128x128.png" >/dev/null
sips -s format png -z 256 256   "$RES/AppIcon.png" --out "$ICONSET/icon_128x128@2x.png" >/dev/null
sips -s format png -z 256 256   "$RES/AppIcon.png" --out "$ICONSET/icon_256x256.png" >/dev/null
sips -s format png -z 512 512   "$RES/AppIcon.png" --out "$ICONSET/icon_256x256@2x.png" >/dev/null
sips -s format png -z 512 512   "$RES/AppIcon.png" --out "$ICONSET/icon_512x512.png" >/dev/null
sips -s format png -z 1024 1024 "$RES/AppIcon.png" --out "$ICONSET/icon_512x512@2x.png" >/dev/null
iconutil -c icns "$ICONSET" -o "$RESOURCES/AppIcon.icns"
rm -rf "$ICONSET"

printf 'APPL????' > "$APP/Contents/PkgInfo"
chmod +x "$BIN/QLabCleaner"
codesign --force --sign - "$APP" >/dev/null

echo "→ Oude lokale releases wissen"
find "$DIST" -maxdepth 1 -name 'QLab-Cleaner-*.dmg' -delete
rm -rf "$DIST/dmg-stage"

echo "→ Installer (DMG)"
STAGE="$DIST/dmg-stage"
mkdir -p "$STAGE"
ditto "$APP" "$STAGE/QLab Cleaner.app"
ln -s /Applications "$STAGE/Applications"
hdiutil create \
  -volname "QLab Cleaner" \
  -srcfolder "$STAGE" \
  -ov \
  -format UDZO \
  -imagekey zlib-level=9 \
  "$DMG" >/dev/null
rm -rf "$STAGE"

echo "→ Kopiëren naar Programma's"
osascript -e 'tell application "QLab Cleaner" to quit' >/dev/null 2>&1 || true
killall QLabCleaner >/dev/null 2>&1 || true
for _ in {1..25}; do
  pgrep -x QLabCleaner >/dev/null 2>&1 || break
  sleep 0.1
done
rm -rf "$INSTALL"
ditto "$APP" "$INSTALL"
codesign --force --sign - "$INSTALL" >/dev/null

echo "→ App herstarten"
open "$INSTALL"

echo "✓ Klaar: $INSTALL (v$VERSION)"
echo "  DMG: $DMG"
