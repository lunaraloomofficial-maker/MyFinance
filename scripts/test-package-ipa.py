#!/usr/bin/env python3
"""Check device-package validation without pretending a fixture is an iOS build."""
import importlib.util
import pathlib
import plistlib
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

    def test_non_app_input_is_rejected(self):
        with self.assertRaises(ValueError):
            module.validate_app(self.app.parent)


if __name__ == '__main__':
    unittest.main()
