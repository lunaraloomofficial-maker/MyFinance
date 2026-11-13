import SwiftUI

struct BudgetsView: View {
    @Environment(FinanceStore.self) private var store
    @State private var month = Date()
    @State private var add = false
    @State private var editing: BudgetValue?
    @State private var deleting: BudgetValue?
    private var budgets: [BudgetValue] { let c = Calendar.current.dateComponents([.year, .month], from: month); return store.data.budgets.filter { $0.year == c.year && $0.month == c.month } }
    var body: some View {
        ScrollView { VStack(spacing: 18) {
            HStack { Button { shift(-1) } label: { Image(systemName: "chevron.left") }.accessibilityLabel("Previous month"); Spacer(); Text(month, format: .dateTime.month(.wide).year()).font(.title3.bold()); Spacer(); Button { shift(1) } label: { Image(systemName: "chevron.right") }.accessibilityLabel("Next month") }.padding()
            if budgets.isEmpty { EmptyFinance(title: "Give your money a plan", detail: "Set a monthly total or a category budget.", symbol: "chart.pie") }
            ForEach(budgets) { budget in
                let spent = (try? Finance.budgetSpent(budget, entries: store.data.entries)) ?? 0
                let ratio = NSDecimalNumber(decimal: Decimal(max(0, spent)) / Decimal(budget.limit)).doubleValue
                let color: Color = ratio > 1 ? Brand.expense : ratio >= 0.9 ? .orange : ratio >= Double(budget.warningThreshold) / 100 ? .yellow : Brand.income
                Card {
                    HStack { Label(store.data.categories.first { $0.id == budget.categoryID }?.name ?? "Total monthly spending", systemImage: "chart.pie.fill").font(.headline); Spacer(); Menu { Button("Edit") { editing = budget }; Button("Delete", role: .destructive) { deleting = budget } } label: { Image(systemName: "ellipsis") }.accessibilityLabel("Budget actions") }
                    HStack(alignment: .firstTextBaseline) { AmountLabel(amount: spent).font(.title2.bold()); Text("of \(store.data.settings.balanceVisibility ? Money.format(budget.limit) : "••••")").font(.caption).foregroundStyle(.secondary) }
                    ProgressView(value: min(1, ratio)).tint(color)
                    HStack { Text(ratio > 1 ? "Over budget" : "Remaining"); Spacer(); AmountLabel(amount: abs(budget.limit - spent)) }.font(.subheadline).foregroundStyle(color)
                    Text("\(Int(ratio * 100))% used").font(.caption).foregroundStyle(.secondary).privacySensitive()
                    let previous = Calendar.current.date(byAdding: .month, value: -1, to: month)!
                    let priorEntries = Finance.inPeriod(store.data.entries, Finance.month(previous)).filter { budget.categoryID == nil || $0.categoryID == budget.categoryID }
                    Text("Previous month: \(store.data.settings.balanceVisibility ? Money.format((try? Finance.spending(priorEntries)) ?? 0) : "••••")").font(.caption).foregroundStyle(.secondary)
                }
            }
        }.padding(.bottom) }.background(Brand.background).navigationTitle("Budgets").toolbar { Button { add = true } label: { Image(systemName: "plus.circle.fill").accessibilityLabel("Add budget") } }
            .sheet(isPresented: $add) { BudgetEditor(month: month) }.sheet(item: $editing) { BudgetEditor(month: month, existing: $0) }
            .confirmationDialog("Delete budget?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }), titleVisibility: .visible) { Button("Delete", role: .destructive) { if let deleting { store.perform { var next = store.data; next.budgets.removeAll { $0.id == deleting.id }; try store.commit(next) } }; deleting = nil } }
    }
    private func shift(_ amount: Int) { month = Calendar.current.date(byAdding: .month, value: amount, to: month)! }
}
struct BudgetEditor: View {
    @Environment(FinanceStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var month: Date
    var existing: BudgetValue?
    @State private var category: UUID?
    @State private var limit = ""
    @State private var warning = 70
    @State private var message: String?
    var body: some View {
        NavigationStack { Form {
            Picker("Category", selection: $category) { Text("Total spending").tag(nil as UUID?); ForEach(store.data.categories.filter { !$0.income && !$0.archived }) { Text($0.name).tag(Optional($0.id)) } }
            TextField("Monthly limit (LKR)", text: $limit).keyboardType(.decimalPad)
            Stepper("Approaching limit at \(warning)%", value: $warning, in: 10...89, step: 5)
            Text("Warning at 90%; exceeded above 100%. Refunds reduce spending; transfers, repayments and adjustments are excluded.").font(.footnote)
            InlineError(message: message)
        }.navigationTitle(existing == nil ? "New budget" : "Edit budget").toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("Save") {
            do { let amount = try Money.parse(limit); guard amount > 0 else { throw FinanceError.invalidAmount }; let c = Calendar.current.dateComponents([.year, .month], from: month); var next = store.data; next.budgets.removeAll { $0.id == existing?.id }; guard !next.budgets.contains(where: { $0.categoryID == category && $0.year == c.year && $0.month == c.month }) else { message = "A budget for this category and month already exists."; return }; next.budgets.append(BudgetValue(id: existing?.id ?? UUID(), categoryID: category, limit: amount, month: c.month!, year: c.year!, warningThreshold: warning)); try store.commit(next); dismiss() } catch { message = error.localizedDescription }
        } } }.onAppear { if let existing { category = existing.categoryID; limit = Money.input(existing.limit); warning = existing.warningThreshold } } }
    }
}
