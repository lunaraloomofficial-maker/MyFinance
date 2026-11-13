import Foundation
import SwiftData

// V1 is immutable once released. Add a new VersionedSchema for structural migrations.
enum FinanceSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] { [Account.self, Transaction.self, Category.self, Budget.self, SMSImport.self, MerchantRule.self, AppSettings.self] }
    @Model final class Account {
        @Attribute(.unique) var id: UUID
        var name: String; var institution: String; var type: String; var currency: String; var maskedIdentifier: String
        var openingBalanceMinorUnits: Int64; var createdAt: Date; var updatedAt: Date; var isArchived: Bool; var icon: String; var color: String; var linkedAccountId: UUID?
        init(_ v: AccountValue) { id = v.id; name = v.name; institution = v.institution; type = v.kind.rawValue; currency = v.currency; maskedIdentifier = v.maskedIdentifier; openingBalanceMinorUnits = v.openingBalance; createdAt = v.createdAt; updatedAt = v.updatedAt; isArchived = v.archived; icon = v.icon; color = v.color; linkedAccountId = v.linkedAccountID }
        var value: AccountValue { AccountValue(id: id, name: name, institution: institution, kind: AccountKind(rawValue: type) ?? .other, currency: currency, maskedIdentifier: maskedIdentifier, openingBalance: openingBalanceMinorUnits, createdAt: createdAt, updatedAt: updatedAt, archived: isArchived, icon: icon, color: color, linkedAccountID: linkedAccountId) }
    }
    @Model final class Transaction {
        @Attribute(.unique) var id: UUID
        var accountId: UUID; var amountMinorUnits: Int64; var type: String; var categoryId: UUID?; var merchant: String; var notes: String; var transactionDate: Date; var createdAt: Date; var updatedAt: Date; var source: String; var importStatus: String; var fingerprint: String; var externalReference: String?; var linkedTransferId: UUID?; var reportedBalanceMinorUnits: Int64?
        init(_ v: Entry) { id = v.id; accountId = v.accountID; amountMinorUnits = v.amount; type = v.kind.rawValue; categoryId = v.categoryID; merchant = v.merchant; notes = v.notes; transactionDate = v.date; createdAt = v.createdAt; updatedAt = v.updatedAt; source = v.source.rawValue; importStatus = v.status.rawValue; fingerprint = v.fingerprint; externalReference = v.reference; linkedTransferId = v.transferID; reportedBalanceMinorUnits = v.reportedBalance }
        var value: Entry { Entry(id: id, accountID: accountId, amount: amountMinorUnits, kind: EntryKind(rawValue: type) ?? .adjustment, categoryID: categoryId, merchant: merchant, notes: notes, date: transactionDate, createdAt: createdAt, updatedAt: updatedAt, source: EntrySource(rawValue: source) ?? .manual, status: ReviewStatus(rawValue: importStatus) ?? .pending, fingerprint: fingerprint, reference: externalReference, transferID: linkedTransferId, reportedBalance: reportedBalanceMinorUnits) }
    }
    @Model final class Category {
        @Attribute(.unique) var id: UUID
        var name: String; var type: String; var icon: String; var color: String; var isDefault: Bool; var isArchived: Bool
        init(_ v: CategoryValue) { id = v.id; name = v.name; type = v.income ? "income" : "expense"; icon = v.icon; color = v.color; isDefault = v.isDefault; isArchived = v.archived }
        var value: CategoryValue { CategoryValue(id: id, name: name, income: type == "income", icon: icon, color: color, isDefault: isDefault, archived: isArchived) }
    }
    @Model final class Budget {
        @Attribute(.unique) var id: UUID
        var categoryId: UUID?; var limitMinorUnits: Int64; var month: Int; var year: Int; var warningThreshold: Int
        init(_ v: BudgetValue) { id = v.id; categoryId = v.categoryID; limitMinorUnits = v.limit; month = v.month; year = v.year; warningThreshold = v.warningThreshold }
        var value: BudgetValue { BudgetValue(id: id, categoryID: categoryId, limit: limitMinorUnits, month: month, year: year, warningThreshold: warningThreshold) }
    }
    @Model final class SMSImport {
        @Attribute(.unique) var id: UUID
        var sender: String; var source: String; var receivedAt: Date; var fingerprint: String; var parseStatus: String; var confidence: String; var linkedTransactionId: UUID?; var parsedData: Data
        init(_ v: ImportValue) throws { id = v.id; sender = v.sender; source = v.source.rawValue; receivedAt = v.receivedAt; fingerprint = v.fingerprint; parseStatus = v.parseStatus; confidence = v.parsed.confidence.rawValue; linkedTransactionId = v.linkedTransactionID; parsedData = try JSONEncoder().encode(v.parsed) }
        func value() throws -> ImportValue { ImportValue(id: id, sender: sender, source: EntrySource(rawValue: source) ?? .sms, receivedAt: receivedAt, fingerprint: fingerprint, parseStatus: parseStatus, parsed: try JSONDecoder().decode(ParsedSMS.self, from: parsedData), linkedTransactionID: linkedTransactionId) }
    }
    @Model final class MerchantRule {
        @Attribute(.unique) var id: UUID
        var pattern: String; var normalizedMerchant: String; var categoryId: UUID; var priority: Int; var isEnabled: Bool
        init(_ v: MerchantRuleValue) { id = v.id; pattern = v.pattern; normalizedMerchant = v.merchant; categoryId = v.categoryID; priority = v.priority; isEnabled = v.enabled }
        var value: MerchantRuleValue { MerchantRuleValue(id: id, pattern: pattern, merchant: normalizedMerchant, categoryID: categoryId, priority: priority, enabled: isEnabled) }
    }
    @Model final class AppSettings {
        @Attribute(.unique) var id: String
        var theme: String; var preferredCurrency: String; var biometricLockEnabled: Bool; var balanceVisibility: Bool; var widgetPrivacyEnabled: Bool; var autoImportPreference: Bool; var lockImmediately: Bool
        init(_ v: SettingsValue) { id = "settings"; theme = v.theme; preferredCurrency = v.preferredCurrency; biometricLockEnabled = v.biometricLockEnabled; balanceVisibility = v.balanceVisibility; widgetPrivacyEnabled = v.widgetPrivacyEnabled; autoImportPreference = v.autoImportPreference; lockImmediately = v.lockImmediately }
        var value: SettingsValue { var v = SettingsValue(); v.theme = theme; v.preferredCurrency = preferredCurrency; v.biometricLockEnabled = biometricLockEnabled; v.balanceVisibility = balanceVisibility; v.widgetPrivacyEnabled = widgetPrivacyEnabled; v.autoImportPreference = autoImportPreference; v.lockImmediately = lockImmediately; return v }
    }
}
typealias Account = FinanceSchemaV1.Account
typealias Transaction = FinanceSchemaV1.Transaction
typealias Category = FinanceSchemaV1.Category
typealias Budget = FinanceSchemaV1.Budget
typealias SMSImport = FinanceSchemaV1.SMSImport
typealias MerchantRule = FinanceSchemaV1.MerchantRule
typealias AppSettings = FinanceSchemaV1.AppSettings
enum FinanceMigrations: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [FinanceSchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}

extension Account { func apply(_ v: AccountValue) { id = v.id; name = v.name; institution = v.institution; type = v.kind.rawValue; currency = v.currency; maskedIdentifier = v.maskedIdentifier; openingBalanceMinorUnits = v.openingBalance; createdAt = v.createdAt; updatedAt = v.updatedAt; isArchived = v.archived; icon = v.icon; color = v.color; linkedAccountId = v.linkedAccountID } }
extension Transaction { func apply(_ v: Entry) { id = v.id; accountId = v.accountID; amountMinorUnits = v.amount; type = v.kind.rawValue; categoryId = v.categoryID; merchant = v.merchant; notes = v.notes; transactionDate = v.date; createdAt = v.createdAt; updatedAt = v.updatedAt; source = v.source.rawValue; importStatus = v.status.rawValue; fingerprint = v.fingerprint; externalReference = v.reference; linkedTransferId = v.transferID; reportedBalanceMinorUnits = v.reportedBalance } }
extension Category { func apply(_ v: CategoryValue) { id = v.id; name = v.name; type = v.income ? "income" : "expense"; icon = v.icon; color = v.color; isDefault = v.isDefault; isArchived = v.archived } }
extension Budget { func apply(_ v: BudgetValue) { id = v.id; categoryId = v.categoryID; limitMinorUnits = v.limit; month = v.month; year = v.year; warningThreshold = v.warningThreshold } }
extension MerchantRule { func apply(_ v: MerchantRuleValue) { id = v.id; pattern = v.pattern; normalizedMerchant = v.merchant; categoryId = v.categoryID; priority = v.priority; isEnabled = v.enabled } }
extension AppSettings { func apply(_ v: SettingsValue) { id = "settings"; theme = v.theme; preferredCurrency = v.preferredCurrency; biometricLockEnabled = v.biometricLockEnabled; balanceVisibility = v.balanceVisibility; widgetPrivacyEnabled = v.widgetPrivacyEnabled; autoImportPreference = v.autoImportPreference; lockImmediately = v.lockImmediately } }
extension SMSImport { func apply(_ v: ImportValue) throws { sender = v.sender; source = v.source.rawValue; receivedAt = v.receivedAt; fingerprint = v.fingerprint; parseStatus = v.parseStatus; confidence = v.parsed.confidence.rawValue; linkedTransactionId = v.linkedTransactionID; parsedData = try JSONEncoder().encode(v.parsed) } }
