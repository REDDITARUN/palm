#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
python3 Scripts/generate-project.py
app_name=Palm
bundle_id=app.plam.learning
configuration=Debug
for option in "$@"; do
    case "$option" in
        --test) app_name=PalmTest; bundle_id=app.plam.learning.test ;;
        --release) configuration=Release ;;
        *) echo "Usage: $0 [--test] [--release]" >&2; exit 2 ;;
    esac
done
version=$(cat VERSION)
DISABLE_SWIFTLINT=1 xcodebuild -project Palm.xcodeproj -scheme PalmMac -configuration "$configuration" -destination 'platform=macOS,arch=arm64' -derivedDataPath .build/Xcode -clonedSourcePackagesDirPath .build/XcodePackages -skipPackagePluginValidation PRODUCT_BUNDLE_IDENTIFIER="$bundle_id" MARKETING_VERSION="$version" build
mkdir -p dist
if [ -d "dist/$app_name.app" ]; then chmod -R u+w "dist/$app_name.app"; rm -rf "dist/$app_name.app"; fi
ditto ".build/Xcode/Build/Products/$configuration/Palm.app" "dist/$app_name.app"
python3 Scripts/portable-bundle.py "dist/$app_name.app" "$configuration"
/usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string Palm.icns" "dist/$app_name.app/Contents/Info.plist" 2>/dev/null || /usr/libexec/PlistBuddy -c "Set :CFBundleIconFile Palm.icns" "dist/$app_name.app/Contents/Info.plist"
# Xcode can copy changed SwiftPM resources without invalidating the outer
# incremental code-sign step. Seal the final artifact after all copies finish.
codesign --force --sign - "dist/$app_name.app"
codesign --verify --deep --strict "dist/$app_name.app"
printf 'Built %s/dist/%s.app\n' "$PWD" "$app_name"
