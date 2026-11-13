import XCTest
import SwiftData
@testable import MyFinance

@MainActor final class PersistenceTests: XCTestCase {
    func store() throws -> FinanceStore { try FinanceStore(container: FinanceStore.makeContainer(memory: true)) }
    func testCreateEditDeleteAndReload() throws {
        let store = try store(), account = AccountValue(name: "Fictional wallet", kind: .cash, openingBalance: 10000)
        try store.saveAccount(account)
        var entry = Entry(accountID: account.id, amount: -1000, kind: .expense, merchant: "Fictional cafe")
        try store.saveEntry(entry); try store.reload()
        XCTAssertEqual(store.data.entries.count, 1)
        entry.amount = -1500; try store.saveEntry(entry); try store.reload()
        XCTAssertEqual(store.data.entries.first?.amount, -1500)
        XCTAssertEqual(try Finance.balance(account, entries: store.data.entries), 8500)
        try store.deleteEntry(entry); try store.reload(); XCTAssertTrue(store.data.entries.isEmpty)
    }
    func testTransferEditAndDeleteAreAtomic() throws {
        let store = try store(), a = AccountValue(name: "Bank", openingBalance: 10000), b = AccountValue(name: "Cash", kind: .cash)
        try store.saveAccount(a); try store.saveAccount(b)
        try store.saveEntry(Entry(accountID: a.id, amount: 2500, kind: .transfer), destination: b.id)
        try store.reload(); XCTAssertEqual(store.data.entries.count, 2); XCTAssertEqual(try Finance.totalBalance(accounts: store.data.accounts, entries: store.data.entries), 10000)
        var outgoing = store.data.entries.first { $0.amount < 0 }!; outgoing.amount = 1000
        try store.saveEntry(outgoing, destination: b.id); XCTAssertEqual(store.data.entries.count, 2)
        try store.deleteEntry(store.data.entries[0]); XCTAssertTrue(store.data.entries.isEmpty)
    }
    func testFailedMutationPreservesSavedData() throws {
        let store = try store(), account = AccountValue(name: "Cash")
        try store.saveAccount(account)
        XCTAssertThrowsError(try store.saveEntry(Entry(accountID: UUID(), amount: -100, kind: .expense)))
        try store.reload(); XCTAssertEqual(store.data.accounts.count, 1); XCTAssertTrue(store.data.entries.isEmpty)
    }
    func testRestorePreservesIDsAndDoesNotDuplicate() throws {
        let store = try store(); try store.saveAccount(AccountValue(name: "Cash", kind: .cash))
        let snapshot = store.data
        try store.restore(snapshot); try store.restore(snapshot); try store.reload()
        XCTAssertEqual(store.data.accounts.map(\.id), snapshot.accounts.map(\.id))
        XCTAssertEqual(store.data.categories.count, snapshot.categories.count)
    }
    func testImportDuplicateQueueAndConfirmation() async throws {
        let store = try store(), a = AccountValue(name: "Fictional HNB", institution: "HNB", maskedIdentifier: "••••1234")
        try store.saveAccount(a)
        let text = "HNB XX1234 debited LKR 100.00 at Fictional Cafe on 2026-11-01 09:30 ref TEST123"
        _ = try await store.importText(text, sender: "HNB", date: Date(), source: .shortcut)
        XCTAssertEqual(store.data.imports.count, 1); XCTAssertTrue(store.data.entries.isEmpty)
        do { _ = try await store.importText(text, sender: "HNB", date: Date(), source: .shortcut); XCTFail("Expected duplicate") } catch {}
        let item = store.data.imports[0]
        try store.confirmImport(item, entry: Entry(accountID: a.id, amount: -10000, kind: .expense, date: item.parsed.date, source: .sms), destination: nil, allowDuplicate: false)
        try store.reload(); XCTAssertEqual(store.data.entries.count, 1); XCTAssertNotNil(store.data.imports[0].linkedTransactionID)
    }
    func testBiometricLockForcesImportReview() async throws {
        let store = try store(); try store.saveAccount(AccountValue(name: "HNB", institution: "HNB", maskedIdentifier: "••••1234"))
        try store.updateSettings { $0.autoImportPreference = true; $0.biometricLockEnabled = true }
        _ = try await store.importText("HNB XX1234 credited LKR 100 on 2026-11-01 09:30 ref LOCK123", sender: "HNB", date: Date(), source: .shortcut)
        XCTAssertTrue(store.data.entries.isEmpty); XCTAssertEqual(store.data.imports.count, 1)
    }
}
