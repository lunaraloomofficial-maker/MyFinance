#!/usr/bin/env python3
"""Validate a device .app and package Payload/MyFinance.app without signing it."""
import argparse
import os
import pathlib
import plistlib
import subprocess
import tempfile
import zipfile


def validate_app(app):
    app = pathlib.Path(app).resolve()
    if app.suffix != '.app' or not app.is_dir():
        raise ValueError('Provide the built MyFinance.app directory, not an archive or simulator ZIP.')
    with (app / 'Info.plist').open('rb') as file:
        info = plistlib.load(file)
    if info.get('DTPlatformName') != 'iphoneos' or info.get('CFBundleSupportedPlatforms') != ['iPhoneOS']:
        raise ValueError('Only iPhone device builds can become an IPA. Simulator builds cannot run on iPhone.')
    executable = info.get('CFBundleExecutable', '')
    if not executable or pathlib.Path(executable).name != executable:
        raise ValueError('The app executable is missing or invalid.')
    binary = app / executable
    if not binary.is_file() or not os.access(binary, os.X_OK):
        raise ValueError('The app executable is missing or has lost executable permissions.')
    if (app / 'embedded.mobileprovision').exists() or (app / '_CodeSignature').exists():
        raise ValueError('Expected an unsigned app. Do not upload provisioning profiles or signed builds here.')
    return app, binary


def package(app, output):
    app, binary = validate_app(app)
    output = pathlib.Path(output).resolve()
    if output.suffix != '.ipa':
        raise ValueError('Output must have the .ipa extension.')
    if app == output or app in output.parents:
        raise ValueError('Write the IPA outside the .app directory.')
    subprocess.run(['xcrun', 'lipo', '-verify_arch', 'arm64', str(binary)], check=True)
    output.parent.mkdir(parents=True, exist_ok=True)
    # Stage on the same volume, validate, then replace output atomically.
    with tempfile.TemporaryDirectory(prefix='myfinance-ipa-', dir=output.parent) as temporary:
        stage = pathlib.Path(temporary)
        payload = stage / 'Payload'
        payload.mkdir()
        subprocess.run(['ditto', str(app), str(payload / app.name)], check=True)
        archive = stage / 'MyFinance-unsigned.ipa'
        subprocess.run(['ditto', '-c', '-k', '--norsrc', '--keepParent', str(payload), str(archive)], check=True)
        with zipfile.ZipFile(archive) as ipa:
            names = ipa.namelist()
            if ipa.testzip() is not None:
                raise ValueError('IPA ZIP integrity validation failed.')
            for required in [f'Payload/{app.name}/Info.plist', f'Payload/{app.name}/{binary.name}']:
                if required not in names:
                    raise ValueError('IPA is missing ' + required)
            if any(not name.startswith('Payload/') for name in names):
                raise ValueError('Unexpected file outside Payload in IPA.')
        os.replace(archive, output)
    print('Packaged unsigned device app:', output)
    print('This package still needs signing before it can be installed on iPhone.')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('app', type=pathlib.Path)
    parser.add_argument('output', type=pathlib.Path)
    args = parser.parse_args()
    try:
        package(args.app, args.output)
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        parser.exit(1, f'IPA packaging failed: {error}\n')
