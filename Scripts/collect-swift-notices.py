#!/usr/bin/env python3
"""Collect notices from resolved Swift checkouts before packaging a release."""
from pathlib import Path
import json
import shutil
root = Path(__file__).resolve().parent.parent
checkouts = root / '.build/checkouts'
if not checkouts.is_dir():
    raise SystemExit('Resolve Swift packages first: swift package resolve')
out = root / 'Sources/PlamCore/Resources/ThirdParty'
out.mkdir(parents=True, exist_ok=True)
pins = json.loads((root / 'Package.resolved').read_text())['pins']
lines = ['Plam native dependencies — retain their original licenses.\n']
for pin in pins:
    identity = pin['identity']
    folder = next((p for p in checkouts.iterdir() if p.name.lower() == identity.lower()), None)
    lines.append(f"{identity}: {pin['location']} @ {pin['state']['revision']}")
    if folder:
        for source in sorted(folder.rglob('*')):
            if source.is_file() and source.name.lower().split('.')[0] in {'license', 'licence', 'copying', 'notice', 'ofl'} and '.git' not in source.parts:
                target = out / identity / source.relative_to(folder)
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(source, target)
lines.append('\nCodeEditSymbols uses an original Plam compatibility module; no upstream source or assets are bundled. See Vendor/CodeEditSymbols/PLAM_PATCH.md.')
(out / 'NOTICE.txt').write_text('\n'.join(lines) + '\n')
print('Collected pinned Swift dependency notices.')
