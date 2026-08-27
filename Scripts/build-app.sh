#!/bin/zsh
set -euo pipefail

project_root="${0:A:h:h}"
app_bundle="$project_root/dist/DesktopCat.app"
sdk_path="${SDKROOT:-/Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk}"
cache_root="${TMPDIR:-/private/tmp}/desktop-cat-build-cache"

mkdir -p "$cache_root/clang" "$cache_root/swiftpm"
export SDKROOT="$sdk_path"
export CLANG_MODULE_CACHE_PATH="$cache_root/clang"
export SWIFTPM_MODULECACHE_OVERRIDE="$cache_root/swiftpm"

cd "$project_root"
swift build -c release --disable-sandbox --sdk "$sdk_path"
binary_path="$(swift build -c release --show-bin-path --disable-sandbox --sdk "$sdk_path")/DesktopCat"

rm -rf "$app_bundle"
mkdir -p "$app_bundle/Contents/MacOS"
cp "$binary_path" "$app_bundle/Contents/MacOS/DesktopCat"

cat > "$app_bundle/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDisplayName</key>
    <string>Desktop Cat</string>
    <key>CFBundleExecutable</key>
    <string>DesktopCat</string>
    <key>CFBundleIdentifier</key>
    <string>com.desktopcat.app</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>Desktop Cat</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

codesign --force --sign - "$app_bundle"
echo "Built $app_bundle"
