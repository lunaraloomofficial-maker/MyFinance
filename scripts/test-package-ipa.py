#!/usr/bin/env python3
"""Check device-package validation without pretending a fixture is an iOS build."""
import importlib.util
import pathlib
import plistlib
import shutil
import subprocess
import sys
import zipfile
import tempfile
import unittest

spec = importlib.util.spec_from_file_location('package_ipa', pathlib.Path(__file__).with_name('package-ipa.py'))
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class DevicePackageValidationTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.app = pathlib.Path(self.temporary.name) / 'MyFinance.app'
        self.app.mkdir()
        self.info = dict(DTPlatformName='iphoneos', CFBundleSupportedPlatforms=['iPhoneOS'], CFBundleExecutable='MyFinance')
        (self.app / 'MyFinance').write_bytes(b'VALIDATION FIXTURE ONLY; NOT A REAL EXECUTABLE')
        (self.app / 'MyFinance').chmod(0o755)
        self.write_plist()

    def write_plist(self):
        with (self.app / 'Info.plist').open('wb') as file:
            plistlib.dump(self.info, file)

    def test_device_metadata_is_accepted_by_metadata_validation(self):
        self.assertEqual(module.validate_app(self.app)[0], self.app.resolve())

    def test_simulator_build_is_rejected(self):
        self.info.update(DTPlatformName='iphonesimulator', CFBundleSupportedPlatforms=['iPhoneSimulator'])
        self.write_plist()
        with self.assertRaisesRegex(ValueError, 'Simulator'):
            module.validate_app(self.app)

    def test_missing_or_nonexecutable_binary_is_rejected(self):
        (self.app / 'MyFinance').chmod(0o644)
        with self.assertRaisesRegex(ValueError, 'permissions'):
            module.validate_app(self.app)
        (self.app / 'MyFinance').unlink()
        with self.assertRaises(ValueError):
            module.validate_app(self.app)

    def test_executable_path_traversal_is_rejected(self):
        self.info['CFBundleExecutable'] = '../outside'
        self.write_plist()
        with self.assertRaisesRegex(ValueError, 'invalid'):
            module.validate_app(self.app)

    def test_signed_payload_is_rejected(self):
        (self.app / 'embedded.mobileprovision').write_text('fixture')
        with self.assertRaisesRegex(ValueError, 'unsigned'):
            module.validate_app(self.app)

    @unittest.skipUnless(sys.platform == 'darwin' and shutil.which('xcrun'), 'Apple tools required')
    def test_real_lipo_and_ditto_archive_pipeline(self):
        # This is a macOS Mach-O fixture, NOT a compiled iOS application.
        # It exercises the actual Apple CLI syntax, ZIP layout and permission preservation.
        subprocess.run(['xcrun', 'clang', '-arch', 'arm64', '-x', 'c', '-', '-o',
                        str(self.app / 'MyFinance')], input='int main(void) { return 0; }',
                       text=True, check=True)
        output = self.app.parent / 'fixture.ipa'
        module.package(self.app, output)
        with zipfile.ZipFile(output) as archive:
            self.assertIsNone(archive.testzip())
            binary = archive.getinfo('Payload/MyFinance.app/MyFinance')
            self.assertTrue((binary.external_attr >> 16) & 0o111)
            self.assertIn('Payload/MyFinance.app/Info.plist', archive.namelist())
        self.assertFalse(any(path.name.startswith('myfinance-ipa-') for path in output.parent.iterdir()))

    def test_non_app_input_is_rejected(self):
        with self.assertRaises(ValueError):
            module.validate_app(self.app.parent)


if __name__ == '__main__':
    unittest.main()
