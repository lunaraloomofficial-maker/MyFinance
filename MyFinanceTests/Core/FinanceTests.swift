import XCTest
#if !CORE_INTEGRATED_TESTS
@testable import MyFinanceCore
#endif

final class FinanceTests: XCTestCase {
    func testMoneyIsExactAndRejectsMalformedAmounts() throws {
        XCTAssertEqual(try Money.parse("1,250.01"), 125001)
        XCTAssertEqual(try Money.parse("0.29"), 29)
        for text in ["1,2", "1.234", "NaN", "-2", "1e3", "", "9999999999999999"] { XCTAssertThrowsError(try Money.parse(text)) }
    }
    func testOpeningBalancesCreditDebitRefundFeeAndIsolation() throws {
        let a = AccountValue(name: "A", openingBalance: 10000), b = AccountValue(name: "B")
        let entries = [Entry(accountID: a.id, amount: 5000, kind: .income), Entry(accountID: a.id, amount: -2000, kind: .expense), Entry(accountID: a.id, amount: 500, kind: .refund), Entry(accountID: a.id, amount: -100, kind: .fee), Entry(accountID: b.id, amount: -900, kind: .expense)]
        XCTAssertEqual(try Finance.balance(a, entries: entries), 13400)
        XCTAssertEqual(try Finance.spending(entries), 2500)
        XCTAssertEqual(try Finance.income(entries), 5000)
        XCTAssertEqual(Finance.savingsRate(income: 5000, spending: 2500), 50)
    }
    func testTransfersAndCardPaymentsNeverCountAsSpending() throws {
        let bank = AccountValue(name: "Bank", openingBalance: 10000), card = AccountValue(name: "Card", kind: .creditCard)
        var entries = [Entry(accountID: card.id, amount: -2000, kind: .expense)]
        entries += try Finance.transfer(from: bank, to: card, amount: 1500, cardPayment: true)
        XCTAssertEqual(try Finance.balance(card, entries: entries), -500)
        XCTAssertEqual(try Finance.balance(bank, entries: entries), 8500)
        XCTAssertEqual(try Finance.spending(entries), 2000)
        XCTAssertEqual(try Finance.totalBalance(accounts: [bank, card], entries: entries), 8000)
        XCTAssertThrowsError(try Finance.transfer(from: bank, to: bank, amount: 10))
        let debit = AccountValue(name: "Debit", kind: .debitCard, linkedAccountID: bank.id)
        XCTAssertEqual(try Finance.totalBalance(accounts: [bank, card, debit], entries: entries), 8000)
        XCTAssertEqual(try Finance.balance(debit, entries: entries, accounts: [bank, card, debit]), 8500)
        XCTAssertThrowsError(try Finance.balance(debit, entries: entries))
        XCTAssertThrowsError(try Finance.transfer(from: debit, to: bank, amount: 1))
    }
    func testBudgetAndHalfOpenMonthBoundaries() throws {
        let calendar = Calendar(identifier: .gregorian), a = UUID(), category = UUID()
        let start = calendar.date(from: DateComponents(year: 2026, month: 2, day: 1))!, end = calendar.date(from: DateComponents(year: 2026, month: 3, day: 1))!
        let entries = [Entry(accountID: a, amount: -1000, kind: .expense, categoryID: category, date: start), Entry(accountID: a, amount: 200, kind: .refund, categoryID: category, date: start), Entry(accountID: a, amount: -9999, kind: .expense, categoryID: category, date: end)]
        XCTAssertEqual(try Finance.budgetSpent(BudgetValue(categoryID: category, limit: 2000, month: 2, year: 2026), entries: entries, calendar: calendar), 800)
    }
    func testRulesRespectPriorityAndCategory() {
        let categories = CategoryValue.defaults, food = categories.first { $0.name == "Food" }!
        let rule = MerchantRuleValue(pattern: "fictional", merchant: "Cafe", categoryID: food.id)
        XCTAssertEqual(Finance.category(for: "FICTIONAL cafe", income: false, categories: categories, rules: [rule]).0, food.id)
    }
    func testOverflowRejected() { XCTAssertThrowsError(try Money.add(Money.maximum, 1)) }
}
final class ParserTests: XCTestCase {
    let parser = SMSParser()
    func testAmountFormats() {
        for amount in ["LKR 1,250.00", "Rs. 1,250", "LKR1,250.00", "Rs 1250", "1,250.00 LKR"] {
            let p = parser.parse("Your account XX1234 debited \(amount) at Fictional Cafe. Available balance LKR 8,000.00", sender: "HNB", receivedAt: Date())
            XCTAssertEqual(p.amount, 125000); XCTAssertEqual(p.reportedBalance, 800000); XCTAssertEqual(p.kind, .expense); XCTAssertEqual(p.maskedIdentifier, "XX1234")
        }
    }
    func testHighConfidenceFictionalFixture() {
        let p = parser.parse("HNB account ****1234 credited LKR 20,000.00 from Fictional Employer on 2026-11-01 09:30 ref ABC123. Balance LKR 30,000.00", sender: "HNB", receivedAt: Date())
        XCTAssertEqual(p.confidence, .high); XCTAssertEqual(p.merchant, "Fictional Employer"); XCTAssertTrue(p.explicitDate)
    }
    func testDateFormats() {
        for date in ["01/11/2026", "01-11-2026 09:30", "2026-11-01", "2026-11-01T09:30:00"] { XCTAssertTrue(parser.parse("credited LKR 10 on \(date)", sender: "", receivedAt: Date()).explicitDate) }
    }
    func testUnsafeAndNonFinancialMessagesRejected() {
        for message in ["OTP 123456 for purchase LKR 200", "Verification code 123456", "Available balance LKR 400", "Offer! purchase LKR 500 discount", "hello", "debited at cafe", "debited USD 10", "debited LKR 1.234", "debited 1.234 LKR"] { XCTAssertEqual(parser.parse(message, sender: "", receivedAt: Date()).confidence, .invalid, message) }
    }
    func testAmbiguityAndUnknownSenderRequireReview() {
        XCTAssertEqual(parser.parse("Debited LKR 500 and credited LKR 500", sender: "", receivedAt: Date()).confidence, .low)
        XCTAssertEqual(parser.parse("Transfer LKR 500 to Fictional Wallet", sender: "", receivedAt: Date()).confidence, .low)
        XCTAssertEqual(parser.parse("purchase LKR 500 and LKR 200", sender: "", receivedAt: Date()).confidence, .low)
        XCTAssertEqual(parser.parse("withdrawn LKR 500", sender: "Unknown", receivedAt: Date()).confidence, .medium)
    }
    func testDuplicateReferenceAndDistinctIdenticalAmounts() {
        let account = UUID(); let p = parser.parse("HNB XX1234 debited LKR 500 on 2026-11-01 09:30 ref ABC123", sender: "HNB", receivedAt: Date())
        let entry = Entry(accountID: account, amount: -50000, kind: .expense, date: p.date, fingerprint: p.fingerprint, reference: p.reference)
        XCTAssertEqual(Duplicates.matches(p, accountID: account, entries: [entry]).count, 1)
        var distinct = p; distinct.fingerprint = "different"; distinct.reference = "ABC124"; distinct.date = p.date.addingTimeInterval(120)
        XCTAssertTrue(Duplicates.matches(distinct, accountID: account, entries: [entry]).isEmpty)
    }
}
final class BackupTests: XCTestCase {
    func snapshot() -> FinanceSnapshot { FinanceSnapshot(accounts: [AccountValue(name: "Cash", kind: .cash)], entries: [], categories: CategoryValue.defaults, budgets: [], imports: [], rules: [], settings: SettingsValue()) }
    func testEncryptionRoundTripWrongPasswordAndTampering() throws {
        let value = snapshot(), data = try Backup.encrypt(value, password: "fictional-passphrase")
        XCTAssertFalse(String(decoding: data, as: UTF8.self).contains("Cash"))
        XCTAssertEqual(try Backup.decrypt(data, password: "fictional-passphrase"), value)
        XCTAssertThrowsError(try Backup.decrypt(data, password: "incorrect-passphrase"))
        var tampered = data; tampered[tampered.count / 2] ^= 1
        XCTAssertThrowsError(try Backup.decrypt(tampered, password: "fictional-passphrase"))
    }
    func testPBKDF2KnownVectors() {
        let vectors = [(1, "120fb6cffcf8b32c43e7225256c4f837a86548c92ccc35480805987cb70be17b"), (2, "ae4d0c95af6b46d32d0adff928f06dd02a303f8ef3c251dfd6e2d85a95474c43")]
        for (rounds, expected) in vectors {
            let key = Backup.key(password: "password", salt: Data("salt".utf8), iterations: rounds)
            XCTAssertEqual(key.withUnsafeBytes { Data($0).map { String(format: "%02x", $0) }.joined() }, expected)
        }
    }
    func testOrphansAndUnbalancedTransfersRejected() throws {
        var value = snapshot(); value.entries = [Entry(accountID: UUID(), amount: -1, kind: .expense)]
        XCTAssertThrowsError(try value.validate())
        value.entries = [Entry(accountID: value.accounts[0].id, amount: -1, kind: .transfer, transferID: UUID())]
        XCTAssertThrowsError(try value.validate())
    }
    func testCSVFormulaInjectionEscaping() {
        let entry = Entry(accountID: UUID(), amount: -100, kind: .expense, merchant: "=HYPERLINK(\"bad\")", notes: "a,b\nnext")
        let csv = CSV.transactions([entry], accounts: [], categories: [])
        XCTAssertTrue(csv.contains("'=HYPERLINK")); XCTAssertTrue(csv.contains("\"a,b\nnext\""))
    }
}
