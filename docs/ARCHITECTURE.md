# Architecture and data contract

MyFinance is an offline iOS 17 SwiftUI app. There are no package dependencies in the app target, network calls, cloud database integrations, bank APIs or analytics SDKs.

## Layers

- `Core/Finance`: portable Foundation/CryptoKit domain values, integer money arithmetic, report calculations, SMS parsing, duplicate matching, CSV, authenticated backups. Built independently by Swift Package Manager or the standalone test runner.
- `Core/Models`: seven SwiftData entities under immutable `FinanceSchemaV1`, with stable UUIDs. `FinanceMigrations` establishes the migration boundary. Never modify released V1 schema; add V2 and a migration stage instead.
- `Core/Persistence`: main-actor observable store. Every mutation makes a value snapshot, validates it, upserts models, and explicitly saves. A failed save rolls back the context. Paired transfer changes and import confirmation each have one save boundary. Main app and in-process App Intents share a cached container and its main context; autosave is disabled. No financial changes occur after an asynchronous suspension without reloading the store.
- `Features`: SwiftUI forms, dashboard, Swift Charts, local searching/filtering, account management, budgeting, import queue, category/rule editors, settings, exports and restore preview.
- `Core/Security`: real LocalAuthentication with device-owner authentication (biometry or device passcode). Background cover and relocking. No application-specific PIN or pretend biometrics.
- `Integrations`: App Intent and App Shortcuts provider. No inbox access.
- `MyFinanceWidgets`: independent WidgetKit extension, excluded from the app dependencies and embedding. It displays hidden values and deep links only.

## Financial contract

All monetary storage and arithmetic use signed Int64 minor units (100 cents = LKR 1). Inputs are strict decimal strings; scientific notation, malformed grouping, excessive precision and unsupported magnitudes are rejected. Decimal is used for ratios and formatting. Conversion to Double is restricted to chart coordinates and progress rendering after financial aggregation.

- Income/refund: positive account effect.
- Expense/fee: negative account effect.
- Adjustment: signed account effect; excluded from normal reports.
- Transfer/card payment: two entries with opposite amounts, distinct canonical accounts, matching kinds and a shared UUID. Not income or spending. Editing/deleting either side updates the pair atomically.
- Credit cards use signed asset balances. Purchases produce negative balances (liabilities); repayments increase that balance toward zero. Combined balance includes these liabilities. Card overpayment becomes a positive balance.
- A linked debit-card label has a zero opening balance and a direct link to a canonical bank account. Reads include the bank opening balance; writes resolve to the bank UUID. Linked labels are excluded from combined balance. Import duplicate checks use the canonical bank UUID. When overlapping card and bank SMS differ enough to evade matching, manual review is still needed; the system does not promise perfect deduplication.
- Opening balances are not income. Editing an opening balance changes historical account totals; reconciliation records a dated adjustment instead.
- Archived accounts retain history. Their balances are excluded from the active combined balance; historical reports still include their transactions. Archive linked cards before their bank account. Account type/link changes are blocked when that account already owns entries.
- Reports use half-open intervals: inclusive start, exclusive next-day/month end, with the device calendar. SMS dates use Asia/Colombo. Refunds reduce spending in the refund's period and category; recategorize a refund to match the original purchase.
- Empty/zero income has a savings rate of zero. Budget refunds can make spending negative and remaining budget larger than its limit.
- The supported monetary limit is 10^15 minor units. Snapshot validation bounds gross lifetime entry movement as well as balances to keep every filtered report safely within that range.

UUID foreign keys are deliberately explicit instead of automatic cascading relationships: no account/category deletion can cascade away financial history. Accounts and categories archive; transaction and rule deletion are explicit. SwiftData V1 uses unique UUID constraints; newer `#Index` features are not used because the minimum OS is iOS 17.

## Imports

The generic parser is not an official bank integration. Bank names are labels inferred from sender/text. No bank-specific templates are claimed verified. High confidence requires one amount, unambiguous direction, recognized bank, masked identifier, date and reference. Transfers, card repayment language, ambiguous directions or multiple amounts require review. Missing details yield medium confidence. OTP/security/promotions, unsupported currency and balance-only text are rejected. Original message bodies are never persisted.

Automatic saving is off by default. It requires high confidence, exactly one active account match, no duplicate, and app lock disabled. Otherwise the extracted fields enter the review queue. Pending imports are not transactions and do not affect balances. Review allows classification corrections, selecting both transfer accounts, and an explicit duplicate override.

Fingerprint matches are supplemented by account-scoped reference matches and amount/direction/time/merchant matches when an explicit timestamp exists. Equal amounts on different events are not sufficient to reject a transaction. No-ref identical message bodies remain inherently ambiguous and need manual recording/review.

## Backup and export

Backups contain a versioned Codable snapshot sealed with AES-256-GCM and authenticated format metadata. A random 16-byte salt and PBKDF2-HMAC-SHA256 with 120,000 iterations derive the 256-bit key. CryptoKit generates the GCM nonce. The envelope contains version, KDF iteration count, salt and authenticated ciphertext. No passwords or derived keys are persisted. Round-trip, wrong-password, tampering and independent PBKDF2 known-vector assertions run locally.

Restore rejects files over 50 MB, invalid formats, duplicates, broken identifiers, unpaired transfers and malformed monetary data. A preview describes counts and replacement behavior, followed by a destructive confirmation. Restore replaces rather than merges data, preserving IDs so repeat restores cannot duplicate records. Make a backup first; restoration is not a cloud sync or merge facility. A temporary encrypted file remains until leaving the backup screen. CSV is plaintext, explicitly shared by the user, and neutralizes formula prefixes on text fields. Temporary export files use complete file protection and are cleaned at launch and on leaving backup.

The database is protected by the operating system's data protection; no separate database encryption is claimed. App lock protects UI access and queues Shortcuts imports. A provisioned shared extension context or simultaneous execution in a separate process has not been validated; there is no share extension and no App Group persistence. The app reads explicitly selected shared plain-text files as a supported text-import alternative.

## Performance and limits

Upserts use UUID dictionaries. SwiftUI lists are lazy; temporary exports and cryptographic work use controlled files/background tasks, and parsing runs off the main actor. This first version loads a value snapshot of all entities; chart aggregation is still performed synchronously during rendering. Thousands-of-record UI latency has not been benchmarked. Before large-scale use, profile on device and add cached period aggregates/paged predicates if needed. The core handles overflow with errors; no balance is seeded with production demo money.
