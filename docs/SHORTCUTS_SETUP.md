# One-tap entry into Apple Shortcuts (MyFinance 1.1)

Open **SMS Import → Open in Shortcuts**, or use the same native button in Settings. The button uses Apple's `ShortcutsLink`, which opens the current installed app's App Shortcuts page, including after legitimate re-signing. It is not a made-up iCloud template URL or a blank shortcut editor.

MyFinance provides **Import Bank SMS** as a ready-made App Shortcut, registers it at launch and refreshes the registration before opening Shortcuts. The action accepts an incoming text result by default; optional sender and timestamp parameters do not automatically consume the preceding result. If launched manually without input, Shortcuts may still ask for the message. The one-time Message automation passes the message instead of asking you to type each one.

The **Connect Shortcuts** screen provides working controls:

- Open MyFinance's Shortcuts page with the native Apple button.
- Add an account, or review existing account identifiers for matching.
- Choose the actual persisted auto-save preference.
- Open the import review queue and troubleshooting.

It does not claim that opening the page proves an automation exists. iOS does not expose a supported API here for creating or checking a user's personal Message automation on the app's behalf.

## One-time iPhone approval

In Apple Shortcuts, create a Message automation for your bank sender or condition. Select MyFinance's **Import Bank SMS** action. For **SMS text**, select **Shortcut Input** or incoming message content, as offered by that iOS version. Choose **Run Immediately** if available, then confirm. These selections cannot be silently installed by MyFinance. No message body needs to be retyped for each triggered import.

Auto-saving remains opt-in. Only high-confidence alerts that match exactly one active account may be saved automatically. App lock forces review. Low/medium-confidence messages and unmatched accounts enter the review queue. This update does not change balances, data schema, accounts or existing transactions.

## Verification boundaries

The native button uses the installed app's identity; there is no hardcoded `com.example` Shortcuts deep link or hosted template to break when Sideloadly re-signs it. Apple's actual Shortcuts app, action discovery after sideloading and Message triggers must be verified on the physical phone. Simulator screenshots verify the setup UI, not background SMS capture.

The cloud workflow requests a screenshot of `myfinance://shortcuts` after native tests and before the Release build, and uploads it with diagnostics. Capture is best-effort and is not reported as a successful test if it fails.

References: [ShortcutsLink](https://developer.apple.com/documentation/appintents/shortcutslink), [App Shortcuts](https://developer.apple.com/documentation/appintents/app-shortcuts), [input connection behavior](https://developer.apple.com/documentation/appintents/inputconnectionbehavior), [Apple's personal automation guide](https://support.apple.com/guide/shortcuts/apdfbdbd7123/ios).
