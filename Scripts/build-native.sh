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
# Sparkle is a dynamic binary package. Embed its complete signed framework,
# preserving helper applications, XPC services, and symlinks.
mkdir -p "dist/$app_name.app/Contents/Frameworks"
ditto ".build/XcodePackages/artifacts/sparkle/Sparkle/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework" "dist/$app_name.app/Contents/Frameworks/Sparkle.framework"
python3 Scripts/portable-bundle.py "dist/$app_name.app" "$configuration"
/usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string Palm.icns" "dist/$app_name.app/Contents/Info.plist" 2>/dev/null || /usr/libexec/PlistBuddy -c "Set :CFBundleIconFile Palm.icns" "dist/$app_name.app/Contents/Info.plist"
# Xcode can copy changed SwiftPM resources without invalidating the outer
# incremental code-sign step. Seal the final artifact after all copies finish.
python3 - "dist/$app_name.app" <<'PYCODE'
import pathlib,plistlib,sys
app=pathlib.Path(sys.argv[1]); info=plistlib.loads((app/'Contents/Info.plist').read_bytes())
assert info.get('SUFeedURL') == 'https://redditarun.github.io/palm/appcast.xml', 'Missing Sparkle feed URL'
assert info.get('SUPublicEDKey') == pathlib.Path('Assets/UpdatePublicKey.txt').read_text().strip(), 'Missing Sparkle update verification key'
assert info.get('SUVerifyUpdateBeforeExtraction') is True
assert info.get('CFBundleVersion') == pathlib.Path('VERSION').read_text().strip()
assert info.get('NSMicrophoneUsageDescription'), 'Missing microphone consent explanation'
assert (app/'Contents/Frameworks/Sparkle.framework/Versions/B/Sparkle').is_file(), 'Missing updater framework'
PYCODE
codesign --force --sign - "dist/$app_name.app"
codesign --verify --deep --strict "dist/$app_name.app"
printf 'Built %s/dist/%s.app\n' "$PWD" "$app_name"
