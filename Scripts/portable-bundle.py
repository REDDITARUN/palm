#!/usr/bin/env python3
"""Remove development-only library search paths from a copied app before signing."""
from pathlib import Path
import subprocess
import sys

app = Path(sys.argv[1]).resolve()
executable = app / 'Contents/MacOS/Plam'
if len(sys.argv) > 2 and sys.argv[2] == 'Release':
    subprocess.run(['/usr/bin/strip', '-S', str(executable)], check=True)
commands = subprocess.check_output(['/usr/bin/otool', '-l', str(executable)], text=True).splitlines()
remove = []
for index, line in enumerate(commands):
    if line.strip() == 'cmd LC_RPATH':
        path_line = next((value.strip() for value in commands[index+1:index+4] if value.strip().startswith('path ')), '')
        value = path_line.removeprefix('path ').split(' (offset ')[0]
        if value.startswith('/') and '/.build/' in value:
            remove.append(value)
for value in remove:
    subprocess.run(['/usr/bin/install_name_tool', '-delete_rpath', value, str(executable)], check=True)
# This bundle must come from the current asset-free compatibility module.
obsolete = list(app.rglob('CodeEditSymbols_CodeEditSymbols.bundle'))
if obsolete:
    raise SystemExit('Obsolete symbol assets found. Clean the native app build output and rebuild before publishing.')
print(f'Prepared portable executable; removed {len(remove)} development search paths.')
