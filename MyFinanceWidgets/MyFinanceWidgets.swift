import WidgetKit
import SwiftUI
struct PrivateEntry: TimelineEntry { let date: Date }
struct PrivateProvider: TimelineProvider {
    func placeholder(in context: Context) -> PrivateEntry { PrivateEntry(date: Date()) }
    func getSnapshot(in context: Context, completion: @escaping (PrivateEntry) -> Void) { completion(placeholder(in: context)) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<PrivateEntry>) -> Void) { completion(Timeline(entries: [PrivateEntry(date: Date())], policy: .never)) }
}
struct FinanceWidgetView: View {
    @Environment(\.widgetFamily) var family
    var body: some View { VStack(alignment: .leading, spacing: 12) {
        Label("MyFinance", systemImage: "leaf.fill").font(.headline).foregroundStyle(.green)
        if family == .systemMedium { HStack { metric("Balance"); metric("Income"); metric("Spent") } } else { metric("Balance"); Text("Monthly spending · ••••").font(.caption) }
        Text("Open app to view securely").font(.caption2).foregroundStyle(.secondary)
    }.containerBackground(.fill.tertiary, for: .widget).widgetURL(URL(string: "myfinance://dashboard")) }
    private func metric(_ title: String) -> some View { VStack(alignment: .leading) { Text(title).font(.caption); Text("••••").font(.title2.bold()).privacySensitive() }.frame(maxWidth: .infinity, alignment: .leading) }
}
struct BalanceWidget: Widget {
    var body: some WidgetConfiguration { StaticConfiguration(kind: "MyFinancePrivateBalance", provider: PrivateProvider()) { _ in FinanceWidgetView() }.configurationDisplayName("Private finance overview").description("Keep financial values private. Open MyFinance to view your balance.").supportedFamilies([.systemSmall, .systemMedium]) }
}
struct QuickFinanceWidget: Widget {
    var body: some WidgetConfiguration { StaticConfiguration(kind: "MyFinanceQuickActions", provider: PrivateProvider()) { _ in HStack { Link(destination: URL(string: "myfinance://add")!) { Label("Add", systemImage: "plus.circle.fill") }; Link(destination: URL(string: "myfinance://dashboard")!) { Label("Home", systemImage: "leaf.fill") }; Link(destination: URL(string: "myfinance://budgets")!) { Label("Budgets", systemImage: "chart.pie") } }.font(.caption).containerBackground(.fill.tertiary, for: .widget) }.configurationDisplayName("Money shortcuts").description("Open transactions, your dashboard, or budgets.").supportedFamilies([.systemMedium]) }
}
@main struct FinanceWidgetBundle: WidgetBundle { var body: some Widget { BalanceWidget(); QuickFinanceWidget() } }
