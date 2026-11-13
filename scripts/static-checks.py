#!/usr/bin/env python3
import pathlib, plistlib, subprocess, xml.etree.ElementTree as ET
root = pathlib.Path(__file__).resolve().parent.parent
swift = sorted(root.glob('MyFinance/**/*.swift')) + sorted(root.glob('MyFinanceWidgets/**/*.swift')) + sorted(root.glob('MyFinanceTests/**/*.swift'))
subprocess.run(['swiftc', '-frontend', '-parse', *map(str, swift)], check=True)
for path in [*root.glob('**/Info.plist'), *root.glob('**/*.xcprivacy')]:
    if '.build' not in path.parts:
        with path.open('rb') as file: plistlib.load(file)
subprocess.run(['plutil', '-lint', str(root/'MyFinance.xcodeproj/project.pbxproj')], check=True)
ET.parse(root/'MyFinance.xcodeproj/xcshareddata/xcschemes/MyFinance.xcscheme')
project = subprocess.run(['plutil', '-convert', 'json', '-o', '-', str(root/'MyFinance.xcodeproj/project.pbxproj')], check=True, capture_output=True, text=True)
import json
objects = json.loads(project.stdout)['objects']
refs = [obj for obj in objects.values() if obj['isa'] == 'PBXFileReference' and obj.get('sourceTree') == 'SOURCE_ROOT']
for ref in refs: assert (root/ref['path']).exists(), ref['path']
for path in swift: assert str(path.relative_to(root)) in [r['path'] for r in refs], path
print(f'PASS: syntax parsed {len(swift)} Swift files; plists, shared scheme, project references validated.')
print('This is syntax/configuration validation, not an iOS typecheck or build.')
