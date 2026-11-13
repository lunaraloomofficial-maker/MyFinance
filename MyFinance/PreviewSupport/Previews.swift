#if DEBUG
import SwiftUI

enum PreviewData {
    @MainActor static func makeStore() throws -> FinanceStore {
        let store = try FinanceStore(container: FinanceStore.makeContainer(memory: true))
        let bank = AccountValue(name: "Everyday", institution: "Fictional bank", openingBalance: 12500000), wallet = AccountValue(name: "Pocket cash", kind: .cash, openingBalance: 500000)
        try store.saveAccount(bank); try store.saveAccount(wallet)
        let groceries = store.data.categories.first { $0.name == "Groceries" }?.id
        try store.saveEntry(Entry(accountID: bank.id, amount: 15000000, kind: .income, merchant: "Fictional salary"))
        for offset in 0..<7 { try store.saveEntry(Entry(accountID: bank.id, amount: -Int64((offset + 1) * 32500), kind: .expense, categoryID: groceries, merchant: "Fictional market", date: Calendar.current.date(byAdding: .day, value: -offset, to: Date())!)) }
        return store
    }
}
struct DashboardPreview: PreviewProvider {
    static var previews: some View {
        Group { preview.preferredColorScheme(.light); preview.preferredColorScheme(.dark).environment(\.sizeCategory, .accessibilityExtraLarge) }
    }
    @MainActor @ViewBuilder static var preview: some View { if let store = try? PreviewData.makeStore() { NavigationStack { DashboardView() }.environment(store) } }
}
#endif
