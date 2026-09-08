#!/bin/bash
# Build a distributable Apple silicon disk image with drag-to-Applications install.
set -euo pipefail
cd "$(dirname "$0")/.."
version=$(cat VERSION)
case "$version" in *[!0-9.]*|'') echo 'VERSION must contain a numeric release version.' >&2; exit 1;; esac
skip_build=false
local_only=false
community=false
for option in "$@"; do
    case "$option" in
        --skip-build) skip_build=true ;;
        --local-only) local_only=true ;;
        --community) community=true ;;
        *) echo "Usage: $0 [--skip-build] [--local-only | --community]" >&2; exit 2 ;;
    esac
done
if [ "$local_only" = true ] && [ "$community" = true ]; then echo "Choose local-only or community, not both." >&2; exit 2; fi
if [ "$skip_build" = false ]; then bash Scripts/build-native.sh --release; fi
app=dist/Palm.app
[ -d "$app" ] || { echo 'Build dist/Palm.app first.' >&2; exit 1; }
actual=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$app/Contents/Info.plist")
[ "$actual" = "$version" ] || { echo 'App version does not match VERSION.' >&2; exit 1; }
codesign --verify --deep --strict "$app"
if [ "$community" = true ]; then
    echo "COMMUNITY BUILD: ad-hoc signed, not Apple-notarized. Keep this status visible on the release and download page." >&2
elif [ "$local_only" = false ]; then
    bash Scripts/verify-distribution.sh "$app"
else
    echo 'LOCAL TEST IMAGE ONLY: not approved for public distribution.' >&2
fi
stage=$(mktemp -d "${TMPDIR:-/tmp}/palm-dmg.XXXXXX")
trap 'rm -rf "$stage"' EXIT
ditto "$app" "$stage/Palm.app"
ln -s /Applications "$stage/Applications"
cp Assets/InstallerLayout.store "$stage/.DS_Store"
cat > "$stage/Read me first.txt" <<'TEXT'
Palm — learn something deeply.

1. Drag Palm.app into Applications.
2. Open Palm from Applications.
3. Save a model connection: OpenRouter, OpenAI API, ChatGPT, or a
   compatible provider. Choose Save & use, then pick a topic.

Requires an Apple silicon Mac running macOS 15 or later.
If macOS reports that Palm will damage your computer, do not open it
or bypass the warning. Report the exact warning, macOS version, app
version, and download source using the project's security guidance.

Palm is free and open source. Your AI provider's pricing and limits apply.
Inkling free logs prompts and outputs for model improvement; use
non-confidential learning material. Other models have their own policies.

Guide: https://github.com/REDDITARUN/palm/blob/main/docs/GETTING_STARTED.md
Source and licenses: https://github.com/REDDITARUN/palm
TEXT
if [ "$community" = true ]; then
    cat >> "$stage/Read me first.txt" <<'NOTICE'

UNNOTARIZED COMMUNITY BUILD
Apple has not notarized this app. If macOS says Apple could not verify
Palm, and you trust your copy from this repository, attempt to open it
once, then use System Settings > Privacy & Security > Open Anyway > Open.
This applies only to the verification warning, not a malware-detection alert.
Apple's instructions: https://support.apple.com/en-us/102445
NOTICE
fi
suffix="macOS-arm64"
if [ "$local_only" = true ]; then
    suffix="LOCAL-TEST-macOS-arm64"
    printf '\nLOCAL TEST BUILD — do not redistribute this installer.\n' >> "$stage/Read me first.txt"
fi
image="dist/Palm-$version-$suffix.dmg"
hdiutil create -volname Palm -srcfolder "$stage" -ov -format UDZO "$image"
hdiutil verify "$image"
(cd dist && shasum -a 256 "Palm-$version-$suffix.dmg" > SHA256SUMS.txt)
printf 'Installer: %s/%s\n' "$PWD" "$image"
