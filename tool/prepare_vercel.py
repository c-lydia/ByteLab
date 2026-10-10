#!/usr/bin/env python3
"""Package the Flutter web release for `vercel deploy --prebuilt --prod`."""
import json
from pathlib import Path
import shutil

root = Path(__file__).resolve().parent.parent
source = root / 'build' / 'web'
if not (source / 'index.html').is_file() or not (source / 'main.dart.js').is_file():
    raise SystemExit('Run flutter build web successfully before preparing a deployment.')
output = root / '.vercel' / 'output'
static = output / 'static'
# Replace generated deployment assets only, preserving .vercel/project.json.
if static.exists():
    shutil.rmtree(static)
shutil.copytree(source, static)
config = {
    'version': 3,
    'routes': [
        {'src': '/(.*)', 'headers': {
            'Permissions-Policy': 'serial=(self)',
            'X-Content-Type-Options': 'nosniff',
            'Referrer-Policy': 'strict-origin-when-cross-origin',
            'Cache-Control': 'public, max-age=0, must-revalidate',
        }, 'continue': True},
        {'handle': 'filesystem'},
    ],
}
(output / 'config.json').write_text(json.dumps(config, indent=2) + '\n')
print(f'Prepared {static}')
