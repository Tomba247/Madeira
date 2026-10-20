#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Add one build to the SideStore / AltStore source (source.json).

    altstore-source.py SOURCE.json IPA VERSION BUILD DOWNLOAD_URL NOTES

SOURCE.json is created when it does not exist. The new version goes first;
the 15 newest are kept. The app entry is rewritten every time, so its
description and permissions follow this script. The permissions are the ones
app/Madeira/Madeira.entitlements and Info.plist declare (AltStore 2 refuses an
app whose source does not list them).
"""
import datetime
import json
import os
import sys

KEEP = 15
REPO = 'https://github.com/Tomba247/Madeira'
ICON = ('https://raw.githubusercontent.com/Tomba247/Madeira/bo3-build/'
        'app/Madeira/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png')


def main():
    path, ipa, version, build, url, notes = sys.argv[1:7]
    try:
        with open(path) as f:
            source = json.load(f)
    except (OSError, ValueError):
        source = {}
    old = source.get('apps') or [{}]
    versions = [v for v in old[0].get('versions', []) if v.get('downloadURL') != url]
    versions.insert(0, {
        'version': version,
        'buildVersion': build,
        'date': datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'),
        'localizedDescription': notes,
        'downloadURL': url,
        'size': os.path.getsize(ipa),
        'minOSVersion': '17.0',
    })
    source.update({
        'name': 'Madeira test builds (unofficial)',
        'identifier': 'io.github.tomba247.madeira',
        'subtitle': 'Unofficial Madeira builds from github.com/Tomba247/Madeira',
        'description': 'Unofficial test builds of Madeira. They are not made or supported by the '
                       'Madeira developers; report problems on the repository, not to them.',
        'website': REPO,
        'apps': [{
            'name': 'Madeira',
            'bundleIdentifier': 'com.willfaust.madeora',
            'developerName': 'Madeira contributors (unofficial build)',
            'subtitle': 'Windows games on iPhone (test builds)',
            'localizedDescription': 'Unofficial test builds of Madeira: Wine, FEX and a Direct3D '
                                    'to Metal runtime. Source: ' + REPO,
            'iconURL': ICON,
            'tintColor': '#7A5CFA',
            'category': 'games',
            'versions': versions[:KEEP],
            'appPermissions': {
                'entitlements': [
                    'com.apple.developer.kernel.increased-memory-limit',
                    'com.apple.security.cs.allow-jit',
                    'get-task-allow',
                ],
                'privacy': {
                    'NSLocalNetworkUsageDescription':
                        'Madeira uses the local network to pair with this device for JIT, '
                        'without a computer.',
                },
            },
        }],
        'news': source.get('news', []),
    })
    with open(path, 'w') as f:
        json.dump(source, f, indent=2)
        f.write('\n')
    print('source: %d version(s), newest %s (%s)' % (len(versions[:KEEP]), version, build))


if __name__ == '__main__':
    main()
