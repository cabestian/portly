#!/usr/bin/env bash
# Build Portly.app without Xcode (Command Line Tools only).
# Output: build/Portly.app
set -euo pipefail
cd "$(dirname "$0")/.."

SDK=$(xcrun --show-sdk-path --sdk macosx)
TARGET="arm64-apple-macos14.0"
BUILD=build
APP="$BUILD/Portly.app"

rm -rf "$BUILD"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

echo "[1/4] Build PortScanCore"
CORE_LIB="$BUILD/libPortScanCore.dylib"
swiftc \
  -emit-library \
  -emit-module \
  -module-name PortScanCore \
  -module-link-name PortScanCore \
  -emit-module-path "$BUILD/PortScanCore.swiftmodule" \
  -o "$CORE_LIB" \
  -sdk "$SDK" -target "$TARGET" \
  -Xlinker -install_name -Xlinker @rpath/libPortScanCore.dylib \
  -O \
  PortScanCore/Sources/PortScanCore/*.swift

echo "[2/4] Build Portly binary"
cp "$CORE_LIB" "$APP/Contents/MacOS/libPortScanCore.dylib"
swiftc \
  -sdk "$SDK" -target "$TARGET" \
  -F "$SDK/System/Library/Frameworks" \
  -I "$BUILD" -L "$BUILD" -lPortScanCore \
  -Xlinker -rpath -Xlinker @loader_path \
  -O \
  -o "$APP/Contents/MacOS/Portly" \
  PortlyApp/main.swift \
  PortlyApp/AppDelegate.swift \
  PortlyApp/StatusBarController.swift \
  PortlyApp/ScanRunner.swift \
  PortlyApp/PortListView.swift \
  PortlyApp/Preferences.swift

echo "[3/4] Write Info.plist"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleDevelopmentRegion</key><string>en</string>
  <key>CFBundleExecutable</key><string>Portly</string>
  <key>CFBundleIdentifier</key><string>app.portly</string>
  <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
  <key>CFBundleName</key><string>Portly</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>0.1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSApplicationCategoryType</key><string>public.app-category.developer-tools</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
</dict></plist>
PLIST

echo "[4/4] Ad-hoc sign"
APP_ENT="$BUILD/Portly.entitlements"
cat > "$APP_ENT" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>com.apple.security.app-sandbox</key><false/>
</dict></plist>
EOF
codesign --force --deep --sign - --entitlements "$APP_ENT" "$APP"

echo "Built: $APP"
