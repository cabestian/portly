#!/usr/bin/env bash
# Build PortlyApp.app + embedded PortlyWidget.appex without Xcode (CLT only).
# Output: build/PortlyApp.app
set -euo pipefail
cd "$(dirname "$0")/.."

SDK=$(xcrun --show-sdk-path --sdk macosx)
TARGET="arm64-apple-macos14.0"
BUILD=build
APP="$BUILD/PortlyApp.app"
APPEX="$APP/Contents/PlugIns/PortlyWidget.appex"

rm -rf "$BUILD"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" \
         "$APPEX/Contents/MacOS" "$APPEX/Contents/Resources"

echo "[1/5] Build PortScanCore"
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

echo "[2/5] Build PortlyApp binary"
# Copy dylib next to the binary so @rpath/loader_path finds it.
cp "$CORE_LIB" "$APP/Contents/MacOS/libPortScanCore.dylib"
swiftc \
  -sdk "$SDK" -target "$TARGET" \
  -F "$SDK/System/Library/Frameworks" \
  -I "$BUILD" -L "$BUILD" -lPortScanCore \
  -Xlinker -rpath -Xlinker @loader_path \
  -O \
  -o "$APP/Contents/MacOS/PortlyApp" \
  PortlyApp/main.swift \
  PortlyApp/AppDelegate.swift \
  PortlyApp/StatusBarController.swift \
  PortlyApp/ScanRunner.swift \
  PortlyApp/PortListView.swift \
  PortlyApp/Preferences.swift

echo "[3/5] Build PortlyWidget binary"
cp "$CORE_LIB" "$APPEX/Contents/MacOS/libPortScanCore.dylib"
swiftc \
  -sdk "$SDK" -target "$TARGET" \
  -F "$SDK/System/Library/Frameworks" \
  -I "$BUILD" -L "$BUILD" -lPortScanCore \
  -Xlinker -rpath -Xlinker @loader_path \
  -O \
  -o "$APPEX/Contents/MacOS/PortlyWidget" \
  PortlyWidget/PortlyWidget.swift \
  PortlyWidget/PortRowView.swift \
  PortlyWidget/OpenLocalPortIntent.swift

echo "[4/5] Write Info.plists"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleDevelopmentRegion</key><string>en</string>
  <key>CFBundleExecutable</key><string>PortlyApp</string>
  <key>CFBundleIdentifier</key><string>com.cabestian.portly</string>
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

cat > "$APPEX/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleDevelopmentRegion</key><string>en</string>
  <key>CFBundleExecutable</key><string>PortlyWidget</string>
  <key>CFBundleIdentifier</key><string>com.cabestian.portly.widget</string>
  <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
  <key>CFBundleName</key><string>PortlyWidget</string>
  <key>CFBundlePackageType</key><string>XPC!</string>
  <key>CFBundleShortVersionString</key><string>0.1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>NSExtension</key><dict>
    <key>NSExtensionPointIdentifier</key><string>com.apple.widgetkit-extension</string>
  </dict>
</dict></plist>
PLIST

echo "[5/5] Ad-hoc sign"
APP_ENT="$BUILD/PortlyApp.entitlements"
APPEX_ENT="$BUILD/PortlyWidget.entitlements"
cat > "$APP_ENT" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>com.apple.security.app-sandbox</key><false/>
  <key>com.apple.security.application-groups</key><array><string>group.com.cabestian.portly</string></array>
</dict></plist>
EOF
cat > "$APPEX_ENT" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>com.apple.security.app-sandbox</key><true/>
  <key>com.apple.security.application-groups</key><array><string>group.com.cabestian.portly</string></array>
</dict></plist>
EOF

# Sign with --deep so all nested binaries get re-signed coherently.
# No --options runtime: hardened runtime breaks ad-hoc dylib loading on dev builds
# (dyld then enforces Team-ID match between binary and library, which ad-hoc randomises).
codesign --force --deep --sign - --entitlements "$APPEX_ENT" "$APPEX"
codesign --force --deep --sign - --entitlements "$APP_ENT" "$APP"

echo "Built: $APP"
