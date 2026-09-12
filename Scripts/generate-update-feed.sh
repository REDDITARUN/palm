#!/bin/bash
# Run after packaging a NEW release; never modifies an existing published asset.
set -euo pipefail
cd "$(dirname "$0")/.."
version=$(cat VERSION)
image="dist/Palm-$version-macOS-arm64.dmg"
[ -f "$image" ] || { echo "Package the release first." >&2; exit 1; }
tool=.build/artifacts/sparkle/Sparkle/bin/generate_appcast
[ -x "$tool" ] || { echo "Run swift package resolve first." >&2; exit 1; }
work=$(mktemp -d "${TMPDIR:-/tmp}/palm-appcast.XXXXXX")
trap 'rm -rf "$work"' EXIT
cp "$image" "$work/"
if [ -f site/appcast.xml ]; then cp site/appcast.xml "$work/appcast.xml"; fi
"$tool" --account app.plam.learning.updates --download-url-prefix "https://github.com/REDDITARUN/palm/releases/download/v$version/" --maximum-deltas 0 "$work"
cp "$work/appcast.xml" site/appcast.xml
python3 - "$image" <<'PY'
from pathlib import Path
import sys,xml.etree.ElementTree as ET
ns='{http://www.andymatuschak.org/xml-namespaces/sparkle}'
items=ET.parse('site/appcast.xml').findall('./channel/item')
image=Path(sys.argv[1]);version=Path('VERSION').read_text().strip()
item=next(x for x in items if x.findtext(ns+'version')==version)
asset=item.find('enclosure')
assert asset.get(ns+'edSignature') and int(asset.get('length'))==image.stat().st_size
assert asset.get('url')==f'https://github.com/REDDITARUN/palm/releases/download/v{version}/{image.name}'
print('Verified signed feed metadata for Palm '+version)
PY
