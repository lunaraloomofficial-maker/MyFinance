import SwiftUI
import Charts

enum ReportPeriod: String, CaseIterable, Identifiable {
    case today = "Today", week = "This week", sevenDays = "Last 7 days", month = "This month", lastMonth = "Last month", quarter = "Last 3 months", year = "This year", custom = "Custom"
    var id: String { rawValue }
    func interval(now: Date = Date(), customStart: Date = Date(), customEnd: Date = Date()) -> DateInterval {
        let c = Calendar.current
        switch self {
        case .today: return c.dateInterval(of: .day, for: now)!
        case .week: return c.dateInterval(of: .weekOfYear, for: now)!
        case .sevenDays: return DateInterval(start: c.date(byAdding: .day, value: -6, to: c.startOfDay(for: now))!, end: c.date(byAdding: .day, value: 1, to: c.startOfDay(for: now))!)
        case .month: return Finance.month(now)
        case .lastMonth: return Finance.month(c.date(byAdding: .month, value: -1, to: now)!)
        case .quarter: return DateInterval(start: Finance.month(c.date(byAdding: .month, value: -2, to: now)!).start, end: Finance.month(now).end)
        case .year: return c.dateInterval(of: .year, for: now)!
        case .custom: let start = c.startOfDay(for: min(customStart, customEnd)); let end = c.date(byAdding: .day, value: 1, to: c.startOfDay(for: max(customStart, customEnd)))!; return DateInterval(start: start, end: end)
        }
    }
}
struct DashboardView: View {
    @Environment(FinanceStore.self) private var store
    @State private var add: EntryKind?
    @State private var showImport = false
    @State private var period: ReportPeriod = .month
    @State private var selectedDay: Date?
    private var monthly: [Entry] { Finance.inPeriod(store.data.entries, Finance.month(Date())) }
    private var income: Int64 { (try? Finance.income(monthly)) ?? 0 }
    private var expense: Int64 { (try? Finance.spending(monthly)) ?? 0 }
    private var previousExpense: Int64 { (try? Finance.spending(Finance.inPeriod(store.data.entries, ReportPeriod.lastMonth.interval()))) ?? 0 }
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                HStack { VStack(alignment: .leading, spacing: 5) { Text(Date(), format: .dateTime.weekday(.wide).month(.abbreviated).day()).font(.caption).foregroundStyle(.secondary); Text("Make room for more.").font(.title2.bold()) }; Spacer(); Image(systemName: "leaf.fill").font(.title).foregroundStyle(Brand.green) }.padding(.horizontal)
                balanceCard
                Card {
                    Text("This month").font(.headline)
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 20) { Metric(title: "Income", value: income, icon: "arrow.down.left", color: Brand.income); Metric(title: "Spent", value: expense, icon: "arrow.up.right", color: Brand.expense) }
                        VStack(spacing: 16) { Metric(title: "Income", value: income, icon: "arrow.down.left", color: Brand.income); Metric(title: "Spent", value: expense, icon: "arrow.up.right", color: Brand.expense) }
                    }
                    Divider()
                    HStack { Text("Net savings").font(.subheadline); Spacer(); AmountLabel(amount: income - expense).font(.headline) }
                    Text("Savings rate \(NSDecimalNumber(decimal: Finance.savingsRate(income: income, spending: expense)).intValue)% · Spending \(Money.format(expense - previousExpense)) vs last month").font(.caption).foregroundStyle(.secondary).privacySensitive()
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        quickAction("Expense", icon: "minus", kind: .expense); quickAction("Income", icon: "plus", kind: .income); quickAction("Transfer", icon: "arrow.left.arrow.right", kind: .transfer)
                        Button { showImport = true } label: { actionLabel("SMS import", icon: "text.bubble") }
                    }.padding(.horizontal)
                }
                Card {
                    HStack { Text("Spending rhythm").font(.headline); Spacer(); Picker("Period", selection: $period) { ForEach([ReportPeriod.sevenDays, .month, .lastMonth, .quarter, .year]) { Text($0.rawValue).tag($0) } }.labelsHidden() }
                    SpendingChart(entries: Finance.inPeriod(store.data.entries, period.interval()), selectedDay: $selectedDay)
                }
                Card {
                    HStack { Text("Where it went").font(.headline); Spacer(); NavigationLink("Reports") { AnalyticsView() }.font(.caption.bold()) }
                    CategoryBreakdown(entries: monthly)
                }
                Card {
                    HStack { Text("Recent activity").font(.headline); Spacer(); NavigationLink("See all") { TransactionsView() }.font(.caption.bold()) }
                    if store.data.entries.isEmpty { EmptyFinance(title: "A fresh start", detail: "Add an account, then record your first transaction.") }
                    ForEach(Array(store.data.entries.prefix(5))) { entry in NavigationLink { TransactionDetail(entryID: entry.id) } label: { TransactionRow(entry: entry) }.buttonStyle(.plain) }
                }
            }.padding(.vertical)
        }.background(Brand.background).navigationTitle("MyFinance").navigationBarTitleDisplayMode(.inline)
            .toolbar { NavigationLink { AccountsView() } label: { Image(systemName: "wallet.bifold").accessibilityLabel("Accounts") } }
            .sheet(item: $add) { TransactionEditor(initialKind: $0) }.sheet(isPresented: $showImport) { NavigationStack { SMSImportView() } }
            .refreshable { store.perform { try store.reload() } }
    }
    private var balanceCard: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack { Label("TOTAL BALANCE", systemImage: "wallet.bifold.fill").font(.caption.weight(.semibold)); Spacer(); Button { store.perform { try store.updateSettings { $0.balanceVisibility.toggle() } } } label: { Image(systemName: store.data.settings.balanceVisibility ? "eye" : "eye.slash") }.accessibilityLabel("Toggle balance visibility") }
            AmountLabel(amount: (try? Finance.totalBalance(accounts: store.data.accounts, entries: store.data.entries)) ?? 0).font(.system(.largeTitle, design: .rounded).bold()).minimumScaleFactor(0.5)
            HStack { Text("\(store.data.accounts.filter { !$0.archived }.count) active accounts").font(.caption); Spacer(); NavigationLink { AccountsView() } label: { Label("Accounts", systemImage: "arrow.up.right").font(.caption.bold()) } }
        }.padding(24).foregroundStyle(.white).background(LinearGradient(colors: [Color(red: 0.07, green: 0.32, blue: 0.21), Color(red: 0.12, green: 0.46, blue: 0.30)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 28)).padding(.horizontal)
    }
    private func quickAction(_ title: String, icon: String, kind: EntryKind) -> some View { Button { add = kind } label: { actionLabel(title, icon: icon) } }
    private func actionLabel(_ title: String, icon: String) -> some View { VStack(spacing: 9) { Image(systemName: icon).font(.headline).frame(width: 52, height: 48).background(Brand.surface, in: RoundedRectangle(cornerRadius: 17)); Text(title).font(.caption.weight(.medium)) }.frame(minWidth: 70).foregroundStyle(Brand.green) }
}
struct DaySpend: Identifiable { var date: Date; var amount: Int64; var id: Date { date } }
struct SpendingChart: View {
    @Environment(FinanceStore.self) private var store
    var entries: [Entry]
    @Binding var selectedDay: Date?
    private var days: [DaySpend] { Dictionary(grouping: entries.filter { [.expense, .fee, .refund].contains($0.kind) }, by: { Calendar.current.startOfDay(for: $0.date) }).map { DaySpend(date: $0.key, amount: (try? Finance.spending($0.value)) ?? 0) }.sorted { $0.date < $1.date } }
    var body: some View {
        if !store.data.settings.balanceVisibility { EmptyFinance(title: "Values hidden", detail: "Show balances to display charts.", symbol: "eye.slash") }
        else if days.isEmpty { EmptyFinance(title: "No spending yet", detail: "Your daily activity will appear here.", symbol: "chart.bar") }
        else {
            Chart(days) { day in BarMark(x: .value("Date", day.date, unit: .day), y: .value("LKR", NSDecimalNumber(decimal: Decimal(day.amount) / 100).doubleValue)).foregroundStyle(Brand.green.gradient).cornerRadius(4) }.frame(height: 170).chartXSelection(value: $selectedDay).accessibilityLabel("Daily spending in Sri Lankan rupees")
            if let selectedDay, let day = days.first(where: { Calendar.current.isDate($0.date, inSameDayAs: selectedDay) }) { HStack { Text(day.date, style: .date); Spacer(); AmountLabel(amount: day.amount) }.font(.caption) }
        }
    }
}
struct CategoryBreakdown: View {
    @Environment(FinanceStore.self) private var store
    var entries: [Entry]
    var body: some View {
        let values = store.data.categories.filter { !$0.income }.map { category in (category, (try? Finance.spending(entries.filter { $0.categoryID == category.id })) ?? 0) }.filter { $0.1 > 0 }.sorted { $0.1 > $1.1 }
        let total = values.reduce(Int64(0)) { $0 + $1.1 }
        if values.isEmpty { Text("Your categories will appear after your first expense.").font(.subheadline).foregroundStyle(.secondary) }
        ForEach(Array(values.prefix(6)), id: \.0.id) { category, amount in
            VStack(spacing: 7) { HStack { Label(category.name, systemImage: category.icon).font(.subheadline); Spacer(); AmountLabel(amount: amount).font(.caption.bold()); Text("\(total > 0 ? NSDecimalNumber(decimal: Decimal(amount) / Decimal(total) * 100).intValue : 0)%").font(.caption).foregroundStyle(.secondary) }; ProgressView(value: total > 0 ? NSDecimalNumber(decimal: Decimal(amount) / Decimal(total)).doubleValue : 0).tint(Brand.color(category.color)) }
        }
    }
}
