# MyFinance

A native, offline personal finance tracker for iPhone, built with SwiftUI, SwiftData, Swift Charts, App Intents and LocalAuthentication. Minimum iOS 17. Currency: LKR. No login, backend, paid service or runtime third-party dependency.

The source implementation and Xcode project are present. The app has **compiled successfully on a GitHub-hosted Mac with Xcode 16.4**, and all **22 simulator tests passed**. Local Xcode is not installed. The corrected cloud workflow also produced an unsigned arm64 IPA, downloaded and checksum-verified locally. Physical iPhone behavior remains untested. See [verification](docs/VERIFICATION.md) for evidence and remaining checks.

## Implemented source

- Five tabs with adaptive forest-green light/dark styling, reusable cards, SF Symbols, native forms, empty states, Dynamic Type and accessibility labels.
- Dashboard: database-derived total balance, hide-values preference, monthly income/spending/savings, prior-month comparison, daily chart, category breakdown and recent activity.
- Accounts: create/edit/archive/reactivate, institutions as labels, masked identifiers, credit-card liability accounting, linked debit cards, transaction history/search, opening balances, reconciliation and adjustments.
- Transactions: all seven types; create/edit/detail/delete, atomic paired transfers and card repayments, notes, category corrections, merchant-rule learning, search/date/account/category/type/source/status/amount filters and sorting.
- Local generic SMS parser; high/medium/low confidence, security and promotional rejection, account matching, duplicate detection, review/edit/discard queue, manual paste and user-selected text-file import.
- Import Bank SMS App Intent with text/sender/timestamp and automatic upstream-input connection, optional high-confidence saving, and troubleshooting. A native Open in Shortcuts button opens MyFinance’s ready-made action; a guided setup screen replaces the old text-only guide. No SMS inbox access.
- Categories and merchant rules: create/edit, icons/colors, archive categories, priorities, enable/disable/delete rules.
- Monthly total/category budgets, custom warning thresholds, previous-month spending, remaining/over-budget display and real transaction calculations.
- Analytics: period/custom date selection, daily/category/monthly charts, merchant/account/income-source breakdown, budget vs actual, savings rate and CSV exports.
- System device authentication, background privacy cover, relocking, hide-values preference.
- Passphrase-encrypted versioned backup, validated restoration preview and explicit replacement confirmation. CSV and encrypted files use native ShareLink.
- Optional WidgetKit extension source with private placeholders and dashboard/add/budget deep links. **No live shared financial widget data** or App Group entitlement required by the app.
- Fictional previews and parser fixtures; no demo transactions inserted in the production database.

## Repository

```
MyFinance.xcodeproj/         Actual generated Xcode project and shared scheme
project.yml                 Optional equivalent XcodeGen specification
Package.swift               Independently buildable core package + XCTest suite
MyFinance/
  App/                      Entry point, tabs, startup failure handling
  Core/
    Finance/                Domain, math, parser, CSV, encrypted backup
    Models/                 SwiftData versioned V1 models
    Persistence/            Validated, rollback-safe store
    Security/               LocalAuthentication lock
    DesignSystem/           Colors and reusable components
  Features/                 Native screens and forms
  Integrations/             App Intent and App Shortcuts
  Resources/                Info.plist and privacy manifest
  PreviewSupport/           In-memory fictional preview data
MyFinanceWidgets/           Independent optional widget target
MyFinanceTests/Core/        Finance, parser, encryption and CSV tests
MyFinanceTests/iOS/         SwiftData persistence tests (requires Xcode)
.github/workflows/          Hosted macOS tests and unsigned IPA build
scripts/                    Project generation, checks and IPA packaging
docs/                       Architecture, fixtures and validation report
```

The seven models are Account, Transaction, Category, Budget, SMSImport, MerchantRule and AppSettings. Finance uses signed integer cents and stable UUID foreign keys. See [architecture and financial contracts](docs/ARCHITECTURE.md) for transfer signs, credit cards, debit-card links, refunds, schema migrations, duplicate matching and security boundaries.

## Local checks without Xcode

Python 3 and the Apple Swift command-line tools are sufficient:

```sh
python3 scripts/run-core-tests.py
python3 scripts/static-checks.py
```

The standalone runner compiles the real core and reuses the XCTest suite's assertion bodies with a small local assertion adapter. It does not simulate iOS or SwiftData. Generated executables and test adaptation stay in ignored `.build/`.

The project is already generated. To regenerate it after adding source files:

```sh
python3 scripts/generate-project.py
```

No dependency download is required. Alternatively use XcodeGen with `xcodegen generate`; `project.yml` supplies all four targets. The app target has no widget dependency. Run the static checks after regeneration.

## Future Xcode validation

Install Xcode later, select its developer directory, open `MyFinance.xcodeproj`, select **MyFinance**, and choose an iPhone simulator. The core suite can also run using `swift test` when XCTest is available. In Xcode, Product → Test runs both the core and SwiftData suites.

For a future simulator command-line test, replace the destination with an installed simulator:

```sh
xcodebuild -project MyFinance.xcodeproj -scheme MyFinance \
  -destination 'platform=iOS Simulator,name=iPhone 16' test CODE_SIGNING_ALLOWED=NO
```

Bundle IDs use `com.example.MyFinance`; change them before a future device release. The core app needs no App Groups, iCloud or paid capabilities. Personal-team provisioning and optional extension capabilities must be checked later.

## Build online without local Xcode

The included [GitHub Actions workflow](.github/workflows/build-ios.yml) runs tests on a hosted Mac and builds an **unsigned native iPhone IPA** without Apple credentials. After publishing this repository, open **Actions → Build unsigned iPhone IPA → Run workflow**. On success, download the IPA artifact and extract its ZIP. The package still needs signing before installation. See the [cloud build guide](docs/CLOUD_BUILD.md) for publishing, artifact downloads, limits and troubleshooting. The [corrected cloud run](https://github.com/lunaraloomofficial-maker/MyFinance/actions/runs/43533704610) passed tests, built the device app and uploaded the unsigned IPA. For installation, see the [iPhone guide](docs/INSTALL_IPHONE.md).

## First use

1. Open Accounts and create a bank account/cash wallet. For a credit card, enter existing debt as a **negative** opening balance.
2. Link a debit-card label to its bank account if they represent the same money. Record the event once.
3. Add income/expenses, transfers, refunds or repayments. Use reconciliation when the actual balance differs from recorded history.
4. Set a monthly total or category budget. Use Analytics to inspect actual records.
5. Paste a fictional SMS from [fixtures](docs/FICTIONAL_SMS_FIXTURES.json); verify the parsed amount, date, direction, account and category in the review queue.
6. Enable app lock after confirming device authentication works. Keep a device passcode configured.
7. Make an encrypted backup with a strong unique passphrase before storing important records. Keep that passphrase separately: there is no recovery service.

## Shortcuts and privacy

In version 1.1, SMS Import and Settings include Apple’s native **Open in Shortcuts** button. The app registers its ready-made Import Bank SMS action at launch and refreshes it when you open the Shortcuts page. The setup screen shows account readiness and lets you choose auto-saving directly. See [Shortcuts setup](docs/SHORTCUTS_SETUP.md). In Apple Shortcuts, create a Message personal automation for your bank sender/condition; pass the message body into **MyFinance → Import Bank SMS**. Sender and received timestamp are optional inputs. Test the automation manually first. Trigger fields and automatic execution vary by iOS version; some configurations require confirmation. Manual paste and plain-text import remain supported.

Only high-confidence LKR messages matching exactly one account may auto-save when explicitly enabled. App lock forces all imports into review. OTP and verification messages are rejected; message bodies are never persisted or uploaded. Bank-specific official templates are not invented: fixtures are fictional generic examples.

All records stay in the local app container by default. System backups may follow your iPhone backup settings. Explicitly sharing CSV sends plaintext financial data to the destination you choose. Encrypted backups use actual authenticated encryption; see the architecture document for the algorithm, KDF and tests. The app lock is not separate database encryption.

## Known limitations and next validation

- Native compilation, SwiftData macro expansion and 22 automated simulator tests passed in Xcode 16.4. Visual UI checks, Face ID/passcode behavior, background cover timing and App Intent registration/execution still require device verification.
- Widgets are a separate optional target, not embedded. They always hide values. Live financial snapshots require future App Group provisioning and privacy-aware shared persistence; no such capability is promised here.
- Text sharing is through user-selected text files/paste, not an iOS share extension. Arbitrary access to Messages is unsupported.
- Restore replaces all records, after preview/confirmation; it does not merge backups. Backup validation preserves IDs and rejects duplicates/broken transfers.
- Generic SMS heuristics can misclassify messages. Review unfamiliar formats. Add verified redacted examples and tests before introducing a bank-specific strategy. Duplicate matching is intentionally conservative; identical no-reference alerts cannot always be distinguished.
- Reports load the local dataset into a value snapshot and aggregate on the UI actor; large-history performance, small-screen layouts, Dynamic Type, VoiceOver, dark mode and contrast need simulator/device testing.
- No balance-notification reconciliation is automatic: reported SMS balances are informational. Use account reconciliation deliberately.
- The privacy manifest should be reviewed against the final archive and current Apple requirements before distribution.
- An original forest-green leaf app icon is included. Final asset-catalog compilation and launch appearance require an iOS build.

Do not use unverified builds as the sole financial record. Keep your bank statements and independent backups while completing native validation.
