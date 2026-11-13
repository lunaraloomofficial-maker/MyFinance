import AppIntents
import Foundation

struct ImportBankSMSIntent: AppIntent {
    static var title: LocalizedStringResource = "Import Bank SMS"
    static var description = IntentDescription("Parse a bank notification locally and import it or add it to your review queue.")
    static var openAppWhenRun = false
    @Parameter(title: "SMS text") var smsText: String
    @Parameter(title: "Sender") var sender: String?
    @Parameter(title: "Received timestamp") var receivedTimestamp: Date?
    static var parameterSummary: some ParameterSummary { Summary("Import \(\.$smsText)") { \.$sender; \.$receivedTimestamp } }
    @MainActor func perform() async throws -> some IntentResult & ProvidesDialog {
        let store = try FinanceStore(container: FinanceStore.makeContainer())
        let result = try await store.importText(smsText, sender: sender ?? "", date: receivedTimestamp ?? Date(), source: .shortcut)
        return .result(dialog: IntentDialog(stringLiteral: result))
    }
}
struct FinanceShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: ImportBankSMSIntent(), phrases: ["Import bank SMS with \(.applicationName)"], shortTitle: "Import Bank SMS", systemImageName: "text.bubble")
    }
}
