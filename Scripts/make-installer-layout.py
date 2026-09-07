#!/usr/bin/env python3
"""Optional regeneration: uv run --no-project --with ds-store==1.3.3 python Scripts/make-installer-layout.py"""
from pathlib import Path
from ds_store import DSStore
root = Path(__file__).resolve().parent.parent
with DSStore.open(str(root / 'Assets/InstallerLayout.store'), 'w+') as layout:
    layout['.']['bwsp'] = {'ShowStatusBar': False, 'ShowToolbar': False, 'ShowSidebar': False, 'ShowTabView': False, 'ContainerShowSidebar': False, 'WindowBounds': '{{200, 180}, {620, 370}}'}
    layout['.']['icvp'] = {'viewOptionsVersion': 1, 'backgroundType': 1, 'backgroundColorRed': 0.97, 'backgroundColorGreen': 0.98, 'backgroundColorBlue': 0.95, 'iconSize': 96.0, 'gridSpacing': 100.0, 'gridOffsetX': 0.0, 'gridOffsetY': 0.0, 'arrangeBy': 'none', 'showIconPreview': True, 'showItemInfo': False, 'labelOnBottom': True, 'textSize': 13.0}
    layout['.']['vstl'] = ('type', b'icnv')
    layout['Palm.app']['Iloc'] = (165, 135)
    layout['Applications']['Iloc'] = (455, 135)
    layout['Read me first.txt']['Iloc'] = (310, 285)
print('Wrote deterministic installer layout (no personal Finder state).')
