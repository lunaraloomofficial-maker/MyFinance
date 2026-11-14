# Install MyFinance on your iPhone

The native arm64 IPA was built successfully by [GitHub Actions run 43533704610](https://github.com/lunaraloomofficial-maker/MyFinance/actions/runs/43533704610). The app requires **iOS 17 or later**. Your Mac does not need Xcode or a paid Apple Developer membership for the Sideloadly route; a regular Apple Account is still needed for signing.

On this Mac, the verified IPA is at `artifacts/MyFinance-unsigned.ipa`, and Sideloadly is installed in `/Applications/Sideloadly.app`. The IPA is unsigned, so opening it directly on the phone will not install it.

1. Connect the iPhone to the Mac by USB, unlock it, and tap **Trust** if prompted.
2. Open Sideloadly. Select your **iPhone**, rather than the Mac, from the device list.
3. Drag `MyFinance-unsigned.ipa` onto Sideloadly if it is not already loaded.
4. Enter your Apple Account in Sideloadly, click **Start**, and complete any password/two-factor prompts there.
5. Follow the iPhone prompts. If asked to trust the developer, open **Settings → General → VPN & Device Management**, select your account and trust it. If Developer Mode is required, enable it in **Settings → Privacy & Security → Developer Mode**, then follow the restart/confirmation prompts. If that option is initially absent, attempt the install first and check again.
6. Open **MyFinance** from the Home Screen. Create an account, add a small fictional transaction, close/reopen the app and confirm it persists before entering important records. Test biometrics and Shortcuts on the actual phone separately.

Free-account signing normally lasts **seven days**. Sideloadly offers refreshing while the Mac and phone are connected by USB or configured Wi-Fi. Keep the same Apple Account and bundle identifier for updates/refreshes so they overwrite the existing app rather than creating another copy. Make encrypted backups from the app before updates.

Official instructions and requirements: [Sideloadly](https://sideloadly.io/), [Sideloadly FAQ](https://sideloadly.io/faq).

## Download again

Open the successful GitHub run, download **MyFinance-unsigned-IPA-5** from Artifacts and extract the ZIP on the Mac. Workflow artifacts have seven-day retention; the local copy is retained independently. Downloading the ZIP to the phone alone does not sign or install the app.

The SHA-256 of this build's IPA is:

```
fa9fbbf6060aa400749a218ac9499c0f78955d3fd693e4bd8204ffaebb6efe8b
```

The repository contains source and fictional test data; the IPA, installer and personal financial data are not committed.
