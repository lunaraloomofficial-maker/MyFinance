import Foundation
import SwiftData
import Observation

@MainActor @Observable final class FinanceStore {
    let container: ModelContainer
    private let context: ModelContext
    private(set) var data: FinanceSnapshot
    var error: String?
    var busy = false
    private static var sharedContainer: ModelContainer?
    static func makeContainer(memory: Bool = false) throws -> ModelContainer {
        if !memory, let sharedContainer { return sharedContainer }
        if !memory {
            _ = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        }
        let schema = Schema(versionedSchema: FinanceSchemaV1.self)
        let configuration = ModelConfiguration("MyFinance", schema: schema, isStoredInMemoryOnly: memory, cloudKitDatabase: .none)
        let result = try ModelContainer(for: schema, migrationPlan: FinanceMigrations.self, configurations: [configuration])
        if !memory { sharedContainer = result }
        return result
    }
    init(container: ModelContainer) throws {
        self.container = container; context = container.mainContext; context.autosaveEnabled = false
        data = FinanceSnapshot(accounts: [], entries: [], categories: [], budgets: [], imports: [], rules: [], settings: SettingsValue())
        try reload()
        if data.categories.isEmpty { var initial = data; initial.categories = CategoryValue.defaults; try commit(initial) }
    }
    func reload() throws {
        data = FinanceSnapshot(accounts: try context.fetch(FetchDescriptor<Account>()).map(\.value), entries: try context.fetch(FetchDescriptor<Transaction>()).map(\.value).sorted { $0.date > $1.date }, categories: try context.fetch(FetchDescriptor<Category>()).map(\.value).sorted { $0.name < $1.name }, budgets: try context.fetch(FetchDescriptor<Budget>()).map(\.value), imports: try context.fetch(FetchDescriptor<SMSImport>()).map { try $0.value() }, rules: try context.fetch(FetchDescriptor<MerchantRule>()).map(\.value), settings: try context.fetch(FetchDescriptor<AppSettings>()).first?.value ?? SettingsValue())
        try data.validate()
    }
    func perform(_ work: () throws -> Void) { do { try work() } catch { self.error = error.localizedDescription } }
    func commit(_ next: FinanceSnapshot) throws {
        try next.validate()
        do {
            try syncAccounts(next.accounts); try syncEntries(next.entries); try syncCategories(next.categories); try syncBudgets(next.budgets); try syncImports(next.imports); try syncRules(next.rules)
            let settings = try context.fetch(FetchDescriptor<AppSettings>())
            if let current = settings.first { current.apply(next.settings) } else { context.insert(AppSettings(next.settings)) }
            try context.save(); data = next; data.entries.sort { $0.date > $1.date }
        } catch { context.rollback(); throw error }
    }
    func updateSettings(_ update: (inout SettingsValue) -> Void) throws { var next = data; update(&next.settings); try commit(next) }
    func saveAccount(_ account: AccountValue) throws {
        var next = data
        if let old = next.accounts.first(where: { $0.id == account.id }), old.linkedAccountID != account.linkedAccountID || old.kind != account.kind {
            guard !next.entries.contains(where: { $0.accountID == account.id }) else { throw FinanceError.invalidBackup("account type/link cannot change while transactions exist; archive and create a new account") }
        }
        if account.archived && next.accounts.contains(where: { $0.linkedAccountID == account.id && !$0.archived }) { throw FinanceError.invalidBackup("archive linked debit cards first") }
        if let index = next.accounts.firstIndex(where: { $0.id == account.id }) { next.accounts[index] = account } else { next.accounts.append(account) }
        try commit(next)
    }
    func saveEntry(_ entry: Entry, destination: UUID? = nil, saveRule: Bool = false) throws {
        guard let account = data.accounts.first(where: { $0.id == entry.accountID && !$0.archived }) else { throw FinanceError.invalidAccount }
        var next = data
        if let old = next.entries.first(where: { $0.id == entry.id }), let link = old.transferID { next.entries.removeAll { $0.transferID == link } } else { next.entries.removeAll { $0.id == entry.id } }
        if [.transfer, .cardPayment].contains(entry.kind) {
            guard let target = next.accounts.first(where: { $0.id == destination }) else { throw FinanceError.invalidTransfer }
            var pair = try Finance.transfer(from: account, to: target, amount: abs(entry.amount), date: entry.date, cardPayment: entry.kind == .cardPayment)
            for i in pair.indices { pair[i].notes = entry.notes; pair[i].source = entry.source }
            next.entries += pair
        } else {
            var saved = entry; saved.accountID = account.linkedAccountID ?? account.id; saved.updatedAt = Date(); next.entries.append(saved)
            if saveRule, let categoryID = saved.categoryID, !saved.merchant.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { next.rules.append(MerchantRuleValue(pattern: saved.merchant.lowercased(), merchant: saved.merchant, categoryID: categoryID, priority: 100)) }
        }
        try commit(next)
    }
    func deleteEntry(_ entry: Entry) throws {
        var next = data
        let ids = Set(next.entries.filter { $0.id == entry.id || (entry.transferID != nil && $0.transferID == entry.transferID) }.map(\.id))
        next.entries.removeAll { ids.contains($0.id) }; next.imports.removeAll { $0.linkedTransactionID.map { ids.contains($0) } ?? false }; try commit(next)
    }
    func reconcile(account: AccountValue, target: Int64) throws {
        guard account.linkedAccountID == nil else { throw FinanceError.invalidAccount }
        let current = try Finance.balance(account, entries: data.entries, accounts: data.accounts)
        let adjustment = try Money.add(target, -current)
        guard adjustment != 0 else { return }
        try saveEntry(Entry(accountID: account.id, amount: adjustment, kind: .adjustment, merchant: "Balance reconciliation"))
    }
    func matchingAccounts(_ parsed: ParsedSMS) -> [AccountValue] {
        guard let identifier = parsed.maskedIdentifier else { return [] }
        let suffix = String(identifier.suffix(4))
        return data.accounts.filter { !$0.archived && !$0.maskedIdentifier.isEmpty && $0.maskedIdentifier.hasSuffix(suffix) && (parsed.bank == nil || $0.institution.localizedCaseInsensitiveContains(parsed.bank!)) }
    }
    func importText(_ text: String, sender: String, date: Date, source: EntrySource) async throws -> String {
        let parsed = await Task.detached(priority: .userInitiated) { SMSParser().parse(text, sender: sender, receivedAt: date) }.value
        guard parsed.confidence != .invalid else { throw FinanceError.invalidMessage }
        try reload() // Intent and foreground UI use the same on-device store.
        if data.imports.contains(where: { $0.fingerprint == parsed.fingerprint }) { throw FinanceError.duplicate }
        var item = ImportValue(sender: sender, source: source, receivedAt: date, fingerprint: parsed.fingerprint, parsed: parsed)
        let matches = matchingAccounts(parsed)
        var next = data
        if parsed.confidence == .high, data.settings.autoImportPreference, !data.settings.biometricLockEnabled, matches.count == 1, let account = matches.first, let amount = parsed.amount, let kind = parsed.kind {
            let accountID = account.linkedAccountID ?? account.id
            guard Duplicates.matches(parsed, accountID: accountID, entries: data.entries).isEmpty else { throw FinanceError.duplicate }
            let category = Finance.category(for: parsed.merchant ?? "", income: kind == .income, categories: data.categories, rules: data.rules)
            let entry = Entry(accountID: accountID, amount: [.income, .refund].contains(kind) ? amount : -amount, kind: kind, categoryID: category.0, merchant: category.1 ?? parsed.merchant ?? "SMS transaction", date: parsed.date, source: source, fingerprint: parsed.fingerprint, reference: parsed.reference, reportedBalance: parsed.reportedBalance)
            next.entries.append(entry); item.parseStatus = "saved"; item.linkedTransactionID = entry.id
        }
        next.imports.append(item); try commit(next)
        return item.linkedTransactionID == nil ? "Added to review queue. Open MyFinance to confirm." : "Transaction imported."
    }
    func confirmImport(_ item: ImportValue, entry: Entry, destination: UUID?, allowDuplicate: Bool) throws {
        guard let account = data.accounts.first(where: { $0.id == entry.accountID && !$0.archived }) else { throw FinanceError.invalidAccount }
        let accountID = account.linkedAccountID ?? entry.accountID
        if !allowDuplicate && !Duplicates.matches(item.parsed, accountID: accountID, entries: data.entries).isEmpty { throw FinanceError.duplicate }
        // Transaction and queue status must commit together.
        var next = data
        guard let index = next.imports.firstIndex(where: { $0.id == item.id && $0.linkedTransactionID == nil }) else { throw FinanceError.duplicate }
        if [.transfer, .cardPayment].contains(entry.kind) {
            guard let from = next.accounts.first(where: { $0.id == entry.accountID }), let to = next.accounts.first(where: { $0.id == destination }) else { throw FinanceError.invalidTransfer }
            let pair = try Finance.transfer(from: from, to: to, amount: abs(entry.amount), date: entry.date, cardPayment: entry.kind == .cardPayment)
            next.entries += pair; next.imports[index].linkedTransactionID = pair[0].id
        } else {
            var saved = entry; saved.accountID = accountID; saved.fingerprint = item.fingerprint; saved.reference = item.parsed.reference; saved.reportedBalance = item.parsed.reportedBalance
            next.entries.append(saved); next.imports[index].linkedTransactionID = saved.id
        }
        next.imports[index].parseStatus = "saved"; try commit(next)
    }
    func restore(_ snapshot: FinanceSnapshot) throws {
        // Replacement is explicit and previewed. IDs are preserved, so repeated restore cannot duplicate entries.
        try commit(snapshot)
    }
}

extension FinanceStore {
    private func syncAccounts(_ values: [AccountValue]) throws {
        let existing = try context.fetch(FetchDescriptor<Account>())
        let byID = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })
        let ids = Set(values.map(\.id))
        for item in existing where !ids.contains(item.id) { context.delete(item) }
        for value in values { if let item = byID[value.id] { item.apply(value) } else { context.insert(Account(value)) } }
    }
}

extension FinanceStore {
    private func syncEntries(_ values: [Entry]) throws {
        let existing = try context.fetch(FetchDescriptor<Transaction>())
        let byID = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })
        let ids = Set(values.map(\.id))
        for item in existing where !ids.contains(item.id) { context.delete(item) }
        for value in values { if let item = byID[value.id] { item.apply(value) } else { context.insert(Transaction(value)) } }
    }
}

extension FinanceStore {
    private func syncCategories(_ values: [CategoryValue]) throws {
        let existing = try context.fetch(FetchDescriptor<Category>())
        let byID = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })
        let ids = Set(values.map(\.id))
        for item in existing where !ids.contains(item.id) { context.delete(item) }
        for value in values { if let item = byID[value.id] { item.apply(value) } else { context.insert(Category(value)) } }
    }
}

extension FinanceStore {
    private func syncBudgets(_ values: [BudgetValue]) throws {
        let existing = try context.fetch(FetchDescriptor<Budget>())
        let byID = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })
        let ids = Set(values.map(\.id))
        for item in existing where !ids.contains(item.id) { context.delete(item) }
        for value in values { if let item = byID[value.id] { item.apply(value) } else { context.insert(Budget(value)) } }
    }
}

extension FinanceStore {
    private func syncImports(_ values: [ImportValue]) throws {
        let existing = try context.fetch(FetchDescriptor<SMSImport>())
        let byID = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })
        let ids = Set(values.map(\.id))
        for item in existing where !ids.contains(item.id) { context.delete(item) }
        for value in values { if let item = byID[value.id] { try item.apply(value) } else { context.insert(try SMSImport(value)) } }
    }
}

extension FinanceStore {
    private func syncRules(_ values: [MerchantRuleValue]) throws {
        let existing = try context.fetch(FetchDescriptor<MerchantRule>())
        let byID = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })
        let ids = Set(values.map(\.id))
        for item in existing where !ids.contains(item.id) { context.delete(item) }
        for value in values { if let item = byID[value.id] { item.apply(value) } else { context.insert(MerchantRule(value)) } }
    }
}
