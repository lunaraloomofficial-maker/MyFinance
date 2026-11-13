import Foundation

public enum AccountKind: String, Codable, CaseIterable, Identifiable {
    case savings, current, debitCard, creditCard, cash, other
    public var id: String { rawValue }
    public var title: String {
        switch self { case .savings: return "Savings"; case .current: return "Current"; case .debitCard: return "Debit card"; case .creditCard: return "Credit card"; case .cash: return "Cash wallet"; case .other: return "Other" }
    }
}
public enum EntryKind: String, Codable, CaseIterable, Identifiable {
    case income, expense, transfer, refund, fee, adjustment, cardPayment
    public var id: String { rawValue }
    public var title: String { switch self { case .cardPayment: return "Credit card payment"; case .adjustment: return "Balance adjustment"; default: return rawValue.capitalized } }
}
public enum EntrySource: String, Codable, CaseIterable { case manual, sms, shortcut, shared, backup }
public enum ReviewStatus: String, Codable, CaseIterable { case confirmed, pending }
public enum FinanceError: LocalizedError {
    case invalidAmount, invalidAccount, invalidTransfer, overflow, invalidBackup(String), duplicate, invalidMessage
    public var errorDescription: String? {
        switch self { case .invalidAmount: return "Enter a valid amount with no more than two decimal places."; case .invalidAccount: return "Select an active account."; case .invalidTransfer: return "Choose two different active accounts for this transfer."; case .overflow: return "This amount exceeds the supported range."; case .invalidBackup(let reason): return "Backup could not be opened: \(reason)"; case .duplicate: return "This transaction may already exist. Review it before importing."; case .invalidMessage: return "No supported financial transaction was found. OTP, promotions and balance-only messages are rejected." }
    }
}
public struct AccountValue: Codable, Identifiable, Equatable {
    public var id: UUID
    public var name: String
    public var institution: String
    public var kind: AccountKind
    public var currency: String
    public var maskedIdentifier: String
    /// Credit card opening balance is a signed asset balance: negative means money owed.
    public var openingBalance: Int64
    public var createdAt: Date
    public var updatedAt: Date
    public var archived: Bool
    public var icon: String
    public var color: String
    /// A debit card can point at its underlying bank account; it never adds a second balance.
    public var linkedAccountID: UUID?
    public init(id: UUID = UUID(), name: String, institution: String = "", kind: AccountKind = .savings, currency: String = "LKR", maskedIdentifier: String = "", openingBalance: Int64 = 0, createdAt: Date = Date(), updatedAt: Date = Date(), archived: Bool = false, icon: String = "building.columns.fill", color: String = "green", linkedAccountID: UUID? = nil) {
        self.id = id; self.name = name; self.institution = institution; self.kind = kind; self.currency = currency; self.maskedIdentifier = maskedIdentifier; self.openingBalance = openingBalance; self.createdAt = createdAt; self.updatedAt = updatedAt; self.archived = archived; self.icon = icon; self.color = color; self.linkedAccountID = linkedAccountID
    }
}
public struct Entry: Codable, Identifiable, Equatable {
    public var id: UUID
    public var accountID: UUID
    /// Signed account effect: positive adds assets/reduces card debt, negative removes assets/increases debt.
    public var amount: Int64
    public var kind: EntryKind
    public var categoryID: UUID?
    public var merchant: String
    public var notes: String
    public var date: Date
    public var createdAt: Date
    public var updatedAt: Date
    public var source: EntrySource
    public var status: ReviewStatus
    public var fingerprint: String
    public var reference: String?
    public var transferID: UUID?
    public var reportedBalance: Int64?
    public init(id: UUID = UUID(), accountID: UUID, amount: Int64, kind: EntryKind, categoryID: UUID? = nil, merchant: String = "", notes: String = "", date: Date = Date(), createdAt: Date = Date(), updatedAt: Date = Date(), source: EntrySource = .manual, status: ReviewStatus = .confirmed, fingerprint: String = "", reference: String? = nil, transferID: UUID? = nil, reportedBalance: Int64? = nil) {
        self.id = id; self.accountID = accountID; self.amount = amount; self.kind = kind; self.categoryID = categoryID; self.merchant = merchant; self.notes = notes; self.date = date; self.createdAt = createdAt; self.updatedAt = updatedAt; self.source = source; self.status = status; self.fingerprint = fingerprint; self.reference = reference; self.transferID = transferID; self.reportedBalance = reportedBalance
    }
}
public struct CategoryValue: Codable, Identifiable, Equatable {
    public var id: UUID = UUID()
    public var name: String
    public var income: Bool = false
    public var icon: String = "tag.fill"
    public var color: String = "green"
    public var isDefault: Bool = false
    public var archived: Bool = false
    public static var defaults: [CategoryValue] {
        let expenses = [("Food", "fork.knife"), ("Groceries", "basket.fill"), ("Shopping", "bag.fill"), ("Transport", "bus.fill"), ("Fuel", "fuelpump.fill"), ("Utilities", "house.fill"), ("Electricity", "bolt.fill"), ("Water", "drop.fill"), ("Internet", "wifi"), ("Mobile recharge", "iphone"), ("Rent", "key.fill"), ("Health", "cross.case.fill"), ("Education", "book.fill"), ("Entertainment", "film.fill"), ("Subscriptions", "repeat"), ("Travel", "airplane"), ("Bank fees", "building.columns"), ("Other", "ellipsis.circle.fill")]
        return expenses.map { CategoryValue(name: $0.0, icon: $0.1, isDefault: true) } + ["Salary", "Freelance", "Business", "Interest", "Investment income", "Gifts", "Other income"].map { CategoryValue(name: $0, income: true, icon: "arrow.down.left", isDefault: true) }
    }
}
public struct BudgetValue: Codable, Identifiable, Equatable {
    public var id: UUID = UUID()
    public var categoryID: UUID?
    public var limit: Int64
    public var month: Int
    public var year: Int
    public var warningThreshold: Int = 70
}
public struct MerchantRuleValue: Codable, Identifiable, Equatable {
    public var id: UUID = UUID()
    public var pattern: String
    public var merchant: String
    public var categoryID: UUID
    public var priority: Int = 0
    public var enabled: Bool = true
}
public struct SettingsValue: Codable, Equatable {
    public var theme: String = "system"
    public var preferredCurrency: String = "LKR"
    public var biometricLockEnabled: Bool = false
    public var balanceVisibility: Bool = true
    public var widgetPrivacyEnabled: Bool = true
    public var autoImportPreference: Bool = false
    public var lockImmediately: Bool = true
    public init() {}
}
public struct ImportValue: Codable, Identifiable, Equatable {
    public var id: UUID = UUID()
    public var sender: String
    public var source: EntrySource = .sms
    public var receivedAt: Date
    public var fingerprint: String
    public var parseStatus: String = "pending"
    public var parsed: ParsedSMS
    public var linkedTransactionID: UUID?
}
public enum Money {
    public static let maximum: Int64 = 1_000_000_000_000_000
    public static func parse(_ text: String, allowNegative: Bool = false) throws -> Int64 {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let pattern = allowNegative ? #"^-?(?:\d+|\d{1,3}(?:,\d{3})+)(?:\.\d{1,2})?$"# : #"^(?:\d+|\d{1,3}(?:,\d{3})+)(?:\.\d{1,2})?$"#
        guard value.range(of: pattern, options: .regularExpression) != nil, let decimal = Decimal(string: value.replacingOccurrences(of: ",", with: ""), locale: Locale(identifier: "en_US_POSIX")) else { throw FinanceError.invalidAmount }
        let scaled = decimal * 100
        guard scaled <= Decimal(maximum), scaled >= Decimal(-maximum) else { throw FinanceError.overflow }
        return NSDecimalNumber(decimal: scaled).int64Value
    }
    public static func format(_ amount: Int64) -> String {
        let formatter = NumberFormatter(); formatter.numberStyle = .currency; formatter.currencyCode = "LKR"; formatter.currencySymbol = "Rs. "; formatter.minimumFractionDigits = 2; formatter.maximumFractionDigits = 2
        return formatter.string(from: NSDecimalNumber(decimal: Decimal(amount) / 100)) ?? "LKR —"
    }
    public static func input(_ amount: Int64) -> String { NSDecimalNumber(decimal: Decimal(amount) / 100).stringValue }
    public static func add(_ a: Int64, _ b: Int64) throws -> Int64 { let (n, overflow) = a.addingReportingOverflow(b); guard !overflow, n <= maximum, n >= -maximum else { throw FinanceError.overflow }; return n }
}
public enum Finance {
    public static func balance(_ account: AccountValue, entries: [Entry], accounts: [AccountValue] = []) throws -> Int64 {
        let owner: AccountValue
        if let linked = account.linkedAccountID { guard let target = accounts.first(where: { $0.id == linked && $0.linkedAccountID == nil }) else { throw FinanceError.invalidAccount }; owner = target } else { owner = account }
        return try entries.filter { $0.accountID == owner.id && $0.status == .confirmed }.reduce(owner.openingBalance) { try Money.add($0, $1.amount) }
    }
    public static func totalBalance(accounts: [AccountValue], entries: [Entry]) throws -> Int64 {
        try accounts.filter { !$0.archived && $0.linkedAccountID == nil }.reduce(0) { try Money.add($0, balance($1, entries: entries)) }
    }
    public static func spending(_ entries: [Entry]) throws -> Int64 {
        try entries.filter { $0.status == .confirmed && [.expense, .fee, .refund].contains($0.kind) }.reduce(0) { try Money.add($0, -$1.amount) }
    }
    public static func income(_ entries: [Entry]) throws -> Int64 {
        try entries.filter { $0.status == .confirmed && $0.kind == .income }.reduce(0) { try Money.add($0, $1.amount) }
    }
    public static func inPeriod(_ entries: [Entry], _ interval: DateInterval) -> [Entry] { entries.filter { $0.date >= interval.start && $0.date < interval.end } }
    public static func month(_ date: Date, calendar: Calendar = .current) -> DateInterval { calendar.dateInterval(of: .month, for: date)! }
    public static func savingsRate(income: Int64, spending: Int64) -> Decimal { income > 0 ? (Decimal(income) - Decimal(spending)) / Decimal(income) * 100 : 0 }
    public static func transfer(from: AccountValue, to: AccountValue, amount: Int64, date: Date = Date(), cardPayment: Bool = false) throws -> [Entry] {
        let source = from.linkedAccountID ?? from.id; let target = to.linkedAccountID ?? to.id
        guard source != target, !from.archived, !to.archived, from.currency == to.currency else { throw FinanceError.invalidTransfer }
        guard amount > 0, amount <= Money.maximum else { throw FinanceError.invalidAmount }
        if cardPayment && to.kind != .creditCard { throw FinanceError.invalidTransfer }
        let link = UUID(); let kind: EntryKind = cardPayment ? .cardPayment : .transfer
        return [Entry(accountID: source, amount: -amount, kind: kind, merchant: "To \(to.name)", date: date, transferID: link), Entry(accountID: target, amount: amount, kind: kind, merchant: "From \(from.name)", date: date, transferID: link)]
    }
    public static func budgetSpent(_ budget: BudgetValue, entries: [Entry], calendar: Calendar = .current) throws -> Int64 {
        guard let date = calendar.date(from: DateComponents(year: budget.year, month: budget.month, day: 1)) else { throw FinanceError.invalidAmount }
        return try spending(inPeriod(entries, month(date, calendar: calendar)).filter { budget.categoryID == nil || $0.categoryID == budget.categoryID })
    }
    public static func category(for text: String, income: Bool, categories: [CategoryValue], rules: [MerchantRuleValue]) -> (UUID?, String?) {
        let normalized = text.lowercased()
        if let rule = rules.filter({ rule in rule.enabled && !rule.pattern.isEmpty && normalized.contains(rule.pattern.lowercased()) && categories.contains(where: { $0.id == rule.categoryID && !$0.archived && $0.income == income }) }).sorted(by: { $0.priority > $1.priority }).first { return (rule.categoryID, rule.merchant.isEmpty ? nil : rule.merchant) }
        let mapping = [("Salary", ["salary", "payroll"]), ("Food", ["restaurant", "cafe", "coffee"]), ("Groceries", ["supermarket", "grocery"]), ("Fuel", ["fuel", "petrol"]), ("Bank fees", ["bank fee", "service charge"]), ("Transport", ["taxi", "bus", "uber", "pickme"])]
        for (name, keywords) in mapping where keywords.contains(where: { normalized.contains($0) }) { if let category = categories.first(where: { $0.name == name && $0.income == income && !$0.archived }) { return (category.id, nil) } }
        return (categories.first(where: { $0.name == (income ? "Other income" : "Other") && !$0.archived })?.id, nil)
    }
}
