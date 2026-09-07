#!/bin/bash
# Build a distributable Apple silicon disk image with drag-to-Applications install.
set -euo pipefail
cd "$(dirname "$0")/.."
version=$(cat VERSION)
case "$version" in *[!0-9.]*|'') echo 'VERSION must contain a numeric release version.' >&2; exit 1;; esac
if [ "${1:-}" != "--skip-build" ]; then bash Scripts/build-native.sh --release; fi
app=dist/Plam.app
[ -d "$app" ] || { echo 'Build dist/Plam.app first.' >&2; exit 1; }
actual=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$app/Contents/Info.plist")
[ "$actual" = "$version" ] || { echo 'App version does not match VERSION.' >&2; exit 1; }
codesign --verify --deep --strict "$app"
stage=$(mktemp -d "${TMPDIR:-/tmp}/plam-dmg.XXXXXX")
trap 'rm -rf "$stage"' EXIT
ditto "$app" "$stage/Plam.app"
ln -s /Applications "$stage/Applications"
cp Assets/InstallerLayout.store "$stage/.DS_Store"
cat > "$stage/Read me first.txt" <<'TEXT'
Plam — learn something deeply.

1. Drag Plam.app into Applications.
2. Open Plam from Applications.
3. Add your own OpenRouter or OpenAI API key, then choose a topic.

Requires an Apple silicon Mac running macOS 15 or later.
This community build is ad-hoc signed, not Apple-notarized.
If macOS blocks the first launch, first try opening the app, then go to
System Settings > Privacy & Security > Open Anyway. Approve only a
copy you downloaded from https://github.com/REDDITARUN/palm/releases.
Do not disable Gatekeeper globally.

Plam is free and open source. Your AI provider's pricing and limits apply.
Inkling free logs prompts and outputs for model improvement; use
non-confidential learning material. Other models have their own policies.

Guide: https://github.com/REDDITARUN/palm/blob/main/docs/GETTING_STARTED.md
Source and licenses: https://github.com/REDDITARUN/palm
TEXT
image="dist/Plam-$version-macOS-arm64.dmg"
hdiutil create -volname Plam -srcfolder "$stage" -ov -format UDZO "$image"
hdiutil verify "$image"
(cd dist && shasum -a 256 "Plam-$version-macOS-arm64.dmg" > SHA256SUMS.txt)
printf 'Installer: %s/%s\n' "$PWD" "$image"
