#!/bin/bash
# Fail closed before packaging an app for public macOS distribution.
set -euo pipefail
app=${1:?Usage: verify-distribution.sh /path/to/Palm.app}
codesign --verify --deep --strict "$app"
signature=$(codesign --display --verbose=4 "$app" 2>&1)
if ! /usr/bin/grep -q '^Authority=Developer ID Application:' <<< "$signature"; then
    echo 'Public packaging requires a Developer ID Application signature. Apple Development and ad-hoc signatures are insufficient.' >&2
    exit 1
fi
if ! /usr/bin/grep -q 'flags=.*runtime' <<< "$signature"; then
    echo 'Public packaging requires the hardened runtime.' >&2
    exit 1
fi
xcrun stapler validate "$app"
spctl --assess --type execute --verbose=4 "$app"
echo 'Signature, stapled notarization ticket, and local Gatekeeper assessment passed.'
echo 'Also verify the downloaded installer on a separate Mac before restoring public downloads.'
