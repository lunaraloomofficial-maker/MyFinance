import SwiftUI
import UIKit

enum Brand {
    static let green = adaptive(light: 0x176342, dark: 0x68D69C)
    static let background = adaptive(light: 0xF5F7F5, dark: 0x101B17)
    static let surface = adaptive(light: 0xFFFFFF, dark: 0x1C2C24)
    static let income = adaptive(light: 0x22864D, dark: 0x86E0A6)
    static let expense = adaptive(light: 0xC45449, dark: 0xFFAAA1)
    static func adaptive(light: UInt, dark: UInt) -> Color { Color(uiColor: UIColor { traits in let hex = traits.userInterfaceStyle == .dark ? dark : light; return UIColor(red: CGFloat((hex >> 16) & 255) / 255, green: CGFloat((hex >> 8) & 255) / 255, blue: CGFloat(hex & 255) / 255, alpha: 1) }) }
    static func color(_ name: String) -> Color { switch name { case "blue": return .blue; case "orange": return .orange; case "purple": return .purple; case "coral": return expense; default: return green } }
}
struct Card<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View { VStack(alignment: .leading, spacing: 16) { content }.padding(20).frame(maxWidth: .infinity, alignment: .leading).background(Brand.surface, in: RoundedRectangle(cornerRadius: 24)).overlay(RoundedRectangle(cornerRadius: 24).stroke(.primary.opacity(0.04))).padding(.horizontal) }
}
struct AmountLabel: View {
    @Environment(FinanceStore.self) private var store
    let amount: Int64
    var body: some View { Text(store.data.settings.balanceVisibility ? Money.format(amount) : "••••••").monospacedDigit().privacySensitive().accessibilityLabel(store.data.settings.balanceVisibility ? Money.format(amount) : "Amount hidden") }
}
struct Metric: View {
    var title: String; var value: Int64; var icon: String; var color: Color
    var body: some View { VStack(alignment: .leading, spacing: 8) { Label(title, systemImage: icon).font(.caption).foregroundStyle(color); AmountLabel(amount: value).font(.headline).minimumScaleFactor(0.65) }.frame(maxWidth: .infinity, alignment: .leading) }
}
struct TransactionRow: View {
    @Environment(FinanceStore.self) private var store
    let entry: Entry
    private var category: CategoryValue? { store.data.categories.first { $0.id == entry.categoryID } }
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: category?.icon ?? (entry.transferID == nil ? "creditcard.fill" : "arrow.left.arrow.right")).font(.headline).foregroundStyle(Brand.color(category?.color ?? "green")).frame(width: 44, height: 44).background(Brand.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 15))
            VStack(alignment: .leading, spacing: 4) { Text(entry.merchant.isEmpty ? entry.kind.title : entry.merchant).font(.subheadline.weight(.semibold)); Text([category?.name ?? entry.kind.title, store.data.accounts.first { $0.id == entry.accountID }?.name ?? "Account"].joined(separator: " · ")).font(.caption).foregroundStyle(.secondary) }
            Spacer(minLength: 4)
            VStack(alignment: .trailing, spacing: 4) { AmountLabel(amount: entry.amount).font(.subheadline.weight(.semibold)).foregroundStyle(entry.amount < 0 ? Brand.expense : Brand.income); Text(entry.date, format: .dateTime.month(.abbreviated).day()).font(.caption2).foregroundStyle(.secondary) }
        }.padding(.vertical, 5).accessibilityElement(children: .combine)
    }
}
struct EmptyFinance: View {
    var title: String; var detail: String; var symbol: String = "leaf"
    var body: some View { ContentUnavailableView(title, systemImage: symbol, description: Text(detail)).padding(.vertical, 20) }
}
struct InlineError: View { var message: String?; var body: some View { if let message { Label(message, systemImage: "exclamationmark.circle").font(.footnote).foregroundStyle(Brand.expense) } } }
