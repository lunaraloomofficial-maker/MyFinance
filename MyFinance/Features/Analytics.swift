import SwiftUI
import Charts

struct ReportBucket: Identifiable { var label: String; var amount: Int64; var id: String { label } }
struct AnalyticsView: View {
    @Environment(FinanceStore.self) private var store
    @State private var period: ReportPeriod = .month
    @State private var start = Date()
    @State private var end = Date()
    @State private var selectedDay: Date?
    @State private var summaryURL: URL?
    private var entries: [Entry] { Finance.inPeriod(store.data.entries, period.interval(customStart: start, customEnd: end)) }
    private var income: Int64 { (try? Finance.income(entries)) ?? 0 }
    private var spent: Int64 { (try? Finance.spending(entries)) ?? 0 }
    var body: some View {
        ScrollView { VStack(spacing: 20) {
            Picker("Period", selection: $period) { ForEach(ReportPeriod.allCases) { Text($0.rawValue).tag($0) } }.pickerStyle(.menu).padding(.horizontal)
            if period == .custom { DatePicker("From", selection: $start, displayedComponents: .date).padding(.horizontal); DatePicker("Through", selection: $end, displayedComponents: .date).padding(.horizontal) }
            Card {
                Text("Your financial picture").font(.headline)
                HStack { Metric(title: "Income", value: income, icon: "arrow.down.left", color: Brand.income); Metric(title: "Expenses", value: spent, icon: "arrow.up.right", color: Brand.expense) }
                Divider(); HStack { Text("Net savings"); Spacer(); AmountLabel(amount: income - spent).bold() }
                Text("Savings rate: \(NSDecimalNumber(decimal: Finance.savingsRate(income: income, spending: spent)).intValue)%").font(.caption).foregroundStyle(.secondary).privacySensitive()
            }
            Card { Text("Daily spending").font(.headline); SpendingChart(entries: entries, selectedDay: $selectedDay) }
            if store.data.settings.balanceVisibility {
                Card {
                    Text("Spending mix").font(.headline)
                    let buckets = categoryBuckets
                    if buckets.isEmpty { Text("No spending for this period.").foregroundStyle(.secondary) }
                    else { Chart(buckets) { bucket in SectorMark(angle: .value("LKR", bucket.amount), innerRadius: .ratio(0.68), angularInset: 2).foregroundStyle(by: .value("Category", bucket.label)) }.frame(height: 220) }
                    CategoryBreakdown(entries: entries)
                }
                Card {
                    Text("Six-month trend").font(.headline)
                    Chart(monthBuckets) { bucket in LineMark(x: .value("Month", bucket.label), y: .value("LKR", NSDecimalNumber(decimal: Decimal(bucket.amount) / 100).doubleValue)).foregroundStyle(Brand.green).symbol(.circle) }.frame(height: 180)
                    let previous = (try? Finance.spending(Finance.inPeriod(store.data.entries, ReportPeriod.lastMonth.interval()))) ?? 0
                    let current = (try? Finance.spending(Finance.inPeriod(store.data.entries, ReportPeriod.month.interval()))) ?? 0
                    Text("This month vs last month: \(Money.format(current - previous))").font(.caption).foregroundStyle(.secondary)
                }
            }
            reportCard("Top merchants", buckets: grouped(by: { $0.merchant.isEmpty ? "Unknown merchant" : $0.merchant }))
            reportCard("Expenses by account", buckets: grouped(by: { entry in store.data.accounts.first { $0.id == entry.accountID }?.name ?? "Unknown" }))
            Card { Text("Income by source").font(.headline); ForEach(incomeBuckets) { bucket in HStack { Text(bucket.label); Spacer(); AmountLabel(amount: bucket.amount) }.font(.subheadline) }; if incomeBuckets.isEmpty { Text("No income recorded.").foregroundStyle(.secondary) } }
            Card { Text("Budget vs actual").font(.headline); NavigationLink("Open monthly budgets") { BudgetsView() }; ForEach(store.data.budgets.filter { $0.month == Calendar.current.component(.month, from: Date()) && $0.year == Calendar.current.component(.year, from: Date()) }) { budget in VStack(alignment: .leading, spacing: 6) { Text(store.data.categories.first { $0.id == budget.categoryID }?.name ?? "Total").font(.subheadline); HStack { AmountLabel(amount: (try? Finance.budgetSpent(budget, entries: store.data.entries)) ?? 0); Text("/"); AmountLabel(amount: budget.limit) }.font(.caption) } } }
            Card {
                Text("Export").font(.headline)
                Button("Prepare category summary CSV") { store.perform { summaryURL = try ExportFiles.write(Data(CSV.categories(entries, categories: store.data.categories).utf8), name: "categories.csv") } }
                if let summaryURL { ShareLink("Share category summary", item: summaryURL) }
                NavigationLink("Filter and export transactions") { TransactionsView() }
            }
        }.padding(.vertical) }.background(Brand.background).navigationTitle("Analytics").onChange(of: period) { _, _ in summaryURL = nil }.onChange(of: start) { _, _ in summaryURL = nil }.onChange(of: end) { _, _ in summaryURL = nil }
    }
    private var categoryBuckets: [ReportBucket] { store.data.categories.filter { !$0.income }.map { category in ReportBucket(label: category.name, amount: (try? Finance.spending(entries.filter { $0.categoryID == category.id })) ?? 0) }.filter { $0.amount > 0 } }
    private var monthBuckets: [ReportBucket] { (-5...0).map { offset in let date = Calendar.current.date(byAdding: .month, value: offset, to: Date())!; return ReportBucket(label: date.formatted(.dateTime.month(.abbreviated)), amount: (try? Finance.spending(Finance.inPeriod(store.data.entries, Finance.month(date)))) ?? 0) } }
    private var incomeBuckets: [ReportBucket] { Dictionary(grouping: entries.filter { $0.kind == .income }, by: { entry in store.data.categories.first { $0.id == entry.categoryID }?.name ?? "Uncategorized" }).map { ReportBucket(label: $0.key, amount: (try? Finance.income($0.value)) ?? 0) }.sorted { $0.amount > $1.amount } }
    private func grouped(by key: (Entry) -> String) -> [ReportBucket] { Dictionary(grouping: entries.filter { [.expense, .fee, .refund].contains($0.kind) }, by: key).map { ReportBucket(label: $0.key, amount: (try? Finance.spending($0.value)) ?? 0) }.filter { $0.amount > 0 }.sorted { $0.amount > $1.amount } }
    private func reportCard(_ title: String, buckets: [ReportBucket]) -> some View { Card { Text(title).font(.headline); if buckets.isEmpty { Text("No activity for this period.").foregroundStyle(.secondary) }; ForEach(Array(buckets.prefix(8))) { bucket in HStack { Text(bucket.label).font(.subheadline); Spacer(); AmountLabel(amount: bucket.amount).font(.subheadline.bold()) } } } }
}
