#!/usr/bin/env python3
"""Audit publishable Git files without printing secret values. Not a full secret scanner."""
from pathlib import Path
import re
import subprocess
import sys

root = Path(__file__).resolve().parent.parent
paths = subprocess.check_output(['git', 'ls-files', '-z', '--cached', '--others', '--exclude-standard'], cwd=root).decode().split('\0')
patterns = {
    'provider credential': re.compile(r'\bsk-(?:or-v1-|proj-)?[A-Za-z0-9_-]{24,}'),
    'GitHub credential': re.compile(r'\b(?:gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{30,})'),
    'private key': re.compile(r'-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----'),
    'personal absolute path': re.compile(r'/Users/(?!runner/|builder/|example/)[A-Za-z0-9_.-]+/'),
}
blocked = {'.review', '.runtime', '.test-data', '.build', 'node_modules', 'xcuserdata'}
issues = []
for name in sorted(set(filter(None, paths))):
    path = root / name
    if not path.is_file():
        continue
    if blocked.intersection(path.relative_to(root).parts) or path.suffix in {'.sqlite', '.db', '.p12', '.p8', '.pem', '.dmg'}:
        issues.append((name, 0, 'private or generated artifact'))
    if path.stat().st_size > 50 * 1024 * 1024:
        issues.append((name, 0, 'file exceeds 50 MiB; use release assets'))
    try:
        source = path.read_text()
    except (UnicodeError, OSError):
        continue
    for label, pattern in patterns.items():
        for match in pattern.finditer(source):
            issues.append((name, source.count('\n', 0, match.start()) + 1, label))
for name, line, label in issues:
    print(f'{name}:{line}: {label}')
print(f'Checked {len(set(filter(None, paths)))} publishable files; {len(issues)} findings. No matched values printed.')
sys.exit(bool(issues))
