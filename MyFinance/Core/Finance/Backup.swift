import Foundation
import CryptoKit

public struct FinanceSnapshot: Codable, Equatable {
    public var version: Int = 1
    public var createdAt: Date = Date()
    public var accounts: [AccountValue]
    public var entries: [Entry]
    public var categories: [CategoryValue]
    public var budgets: [BudgetValue]
    public var imports: [ImportValue]
    public var rules: [MerchantRuleValue]
    public var settings: SettingsValue
    public init(accounts: [AccountValue], entries: [Entry], categories: [CategoryValue], budgets: [BudgetValue], imports: [ImportValue], rules: [MerchantRuleValue], settings: SettingsValue) { self.accounts = accounts; self.entries = entries; self.categories = categories; self.budgets = budgets; self.imports = imports; self.rules = rules; self.settings = settings }
    public func validate() throws {
        guard ["system", "light", "dark"].contains(settings.theme), settings.preferredCurrency == "LKR" else { throw FinanceError.invalidBackup("unsupported settings") }
        guard version == 1 else { throw FinanceError.invalidBackup("unsupported version") }
        let accountIDs = Set(accounts.map(\.id)); let categoryIDs = Set(categories.map(\.id))
        guard accountIDs.count == accounts.count, categoryIDs.count == categories.count, Set(entries.map(\.id)).count == entries.count, Set(budgets.map(\.id)).count == budgets.count, Set(imports.map(\.id)).count == imports.count, Set(rules.map(\.id)).count == rules.count else { throw FinanceError.invalidBackup("duplicate identifiers") }
        for account in accounts {
            guard !account.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, account.currency == "LKR", account.openingBalance >= -Money.maximum, account.openingBalance <= Money.maximum else { throw FinanceError.invalidBackup("invalid account") }
            if let linked = account.linkedAccountID {
                guard account.kind == .debitCard, account.openingBalance == 0, let target = accounts.first(where: { $0.id == linked }), target.id != account.id, target.linkedAccountID == nil, target.kind != .creditCard, account.archived || !target.archived else { throw FinanceError.invalidBackup("invalid debit card link") }
            }
        }
        var grossActivity: Int64 = 0
        for entry in entries {
            guard accountIDs.contains(entry.accountID), accounts.first(where: { $0.id == entry.accountID })?.linkedAccountID == nil, entry.amount >= -Money.maximum, entry.amount <= Money.maximum, entry.categoryID.map({ categoryIDs.contains($0) }) ?? true, entry.date.timeIntervalSince1970.isFinite else { throw FinanceError.invalidBackup("orphan or invalid transaction") }
            grossActivity = try Money.add(grossActivity, abs(entry.amount))
            switch entry.kind {
            case .income, .refund: guard entry.amount > 0 else { throw FinanceError.invalidBackup("invalid credit") }
            case .expense, .fee: guard entry.amount < 0 else { throw FinanceError.invalidBackup("invalid debit") }
            case .transfer, .cardPayment: guard entry.transferID != nil, entry.amount != 0 else { throw FinanceError.invalidBackup("unpaired transfer") }
            case .adjustment: break
            }
            if entry.transferID != nil && ![.transfer, .cardPayment].contains(entry.kind) { throw FinanceError.invalidBackup("unexpected transfer link") }
        }
        for group in Dictionary(grouping: entries.filter { $0.transferID != nil }, by: { $0.transferID! }).values {
            guard group.count == 2, group[0].accountID != group[1].accountID, group[0].kind == group[1].kind, group[0].amount == -group[1].amount, group[0].status == group[1].status else { throw FinanceError.invalidBackup("inconsistent transfer") }
        }
        var budgetKeys = Set<String>()
        for budget in budgets {
            guard budget.limit > 0, budget.limit <= Money.maximum, (1...12).contains(budget.month), (1900...9999).contains(budget.year), (1...100).contains(budget.warningThreshold), budget.categoryID.map({ categoryIDs.contains($0) }) ?? true else { throw FinanceError.invalidBackup("invalid budget") }
            guard budgetKeys.insert("\(budget.year)-\(budget.month)-\(budget.categoryID?.uuidString ?? "total")").inserted else { throw FinanceError.invalidBackup("duplicate budget") }
        }
        for rule in rules { guard categoryIDs.contains(rule.categoryID), !rule.pattern.isEmpty else { throw FinanceError.invalidBackup("invalid category rule") } }
        for item in imports {
            guard item.parsed.confidence != .invalid,
                  item.parsed.amount.map({ $0 > 0 && $0 <= Money.maximum }) == true,
                  item.parsed.kind != nil,
                  item.fingerprint == item.parsed.fingerprint,
                  ["pending", "saved"].contains(item.parseStatus),
                  (item.parseStatus == "saved") == (item.linkedTransactionID != nil),
                  item.linkedTransactionID.map({ id in entries.contains(where: { $0.id == id }) }) ?? true else { throw FinanceError.invalidBackup("invalid SMS import") }
        }
        for account in accounts { _ = try Finance.balance(account, entries: entries, accounts: accounts) }
        _ = try Finance.totalBalance(accounts: accounts, entries: entries)
    }
}
public enum Backup {
    private struct Envelope: Codable { var version: Int; var iterations: Int; var salt: Data; var sealed: Data }
    private static let iterations = 120_000
    /// PBKDF2-HMAC-SHA256, 256-bit key. AES-GCM provides authentication and integrity.
    static func key(password: String, salt: Data, iterations: Int) -> SymmetricKey {
        let passwordKey = SymmetricKey(data: Data(password.utf8))
        var block = salt; block.append(contentsOf: [0, 0, 0, 1])
        var u = Data(HMAC<SHA256>.authenticationCode(for: block, using: passwordKey)); var derived = u
        for _ in 1..<iterations { u = Data(HMAC<SHA256>.authenticationCode(for: u, using: passwordKey)); for i in derived.indices { derived[i] ^= u[i] } }
        return SymmetricKey(data: derived)
    }
    public static func encrypt(_ snapshot: FinanceSnapshot, password: String) throws -> Data {
        guard password.count >= 12 else { throw FinanceError.invalidBackup("use a passphrase of at least 12 characters") }
        try snapshot.validate()
        let salt = Data((0..<16).map { _ in UInt8.random(in: 0...255) })
        let data = try JSONEncoder().encode(snapshot)
        let box = try AES.GCM.seal(data, using: key(password: password, salt: salt, iterations: iterations), authenticating: Data("MyFinanceBackup-v1".utf8))
        return try JSONEncoder().encode(Envelope(version: 1, iterations: iterations, salt: salt, sealed: box.combined!))
    }
    public static func decrypt(_ data: Data, password: String) throws -> FinanceSnapshot {
        guard data.count <= 50_000_000 else { throw FinanceError.invalidBackup("file exceeds 50 MB") }
        do {
            let envelope = try JSONDecoder().decode(Envelope.self, from: data)
            guard envelope.version == 1, envelope.iterations == iterations, envelope.salt.count == 16 else { throw FinanceError.invalidBackup("unsupported encryption format") }
            let plain = try AES.GCM.open(AES.GCM.SealedBox(combined: envelope.sealed), using: key(password: password, salt: envelope.salt, iterations: envelope.iterations), authenticating: Data("MyFinanceBackup-v1".utf8))
            let snapshot = try JSONDecoder().decode(FinanceSnapshot.self, from: plain); try snapshot.validate(); return snapshot
        } catch { throw FinanceError.invalidBackup("wrong passphrase, damaged file, or invalid data") }
    }
}
public enum CSV {
    private static func escape(_ value: String) -> String {
        // Prevent spreadsheet formula execution on user-controlled text.
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let safe = ["=", "+", "-", "@"].contains(where: { trimmed.hasPrefix($0) }) ? "'" + value : value
        return "\"" + safe.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
    public static func transactions(_ entries: [Entry], accounts: [AccountValue], categories: [CategoryValue]) -> String {
        let date = ISO8601DateFormatter()
        return "ID,Date,Account,Type,Amount LKR,Category,Merchant,Notes,Source,Status\r\n" + entries.map { entry in
            [entry.id.uuidString, date.string(from: entry.date), accounts.first(where: { $0.id == entry.accountID })?.name ?? "Unknown", entry.kind.title, Money.input(entry.amount), categories.first(where: { $0.id == entry.categoryID })?.name ?? "Uncategorized", entry.merchant, entry.notes, entry.source.rawValue, entry.status.rawValue].map(escape).joined(separator: ",")
        }.joined(separator: "\r\n")
    }
    public static func categories(_ entries: [Entry], categories: [CategoryValue]) throws -> String {
        "Category,Spending LKR\r\n" + (try categories.filter { !$0.income }.map { category in escape(category.name) + "," + escape(Money.input(try Finance.spending(entries.filter { $0.categoryID == category.id }))) }).joined(separator: "\r\n")
    }
}
