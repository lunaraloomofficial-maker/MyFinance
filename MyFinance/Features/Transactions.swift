import SwiftUI

struct TransactionsView: View {
    @Environment(FinanceStore.self) private var store
    var accountID: UUID?
    @State private var search = ""
    @State private var showAdd = false
    @State private var showFilters = false
    @State private var deleting: Entry?
    @State private var account: UUID?
    @State private var category: UUID?
    @State private var kind: EntryKind?
    @State private var source: EntrySource?
    @State private var status: ReviewStatus?
    @State private var period: ReportPeriod = .year
    @State private var filterDate = false
    @State private var start = Date()
    @State private var end = Date()
    @State private var minimum = ""
    @State private var maximum = ""
    @State private var oldestFirst = false
    @State private var exportURL: URL?
    private var entries: [Entry] {
        store.data.entries.filter { entry in
            (accountID == nil || entry.accountID == accountID) && (account == nil || entry.accountID == account) && (category == nil || entry.categoryID == category) && (kind == nil || entry.kind == kind) && (source == nil || entry.source == source) && (status == nil || entry.status == status) && (search.isEmpty || (entry.merchant + " " + entry.notes + " " + (entry.reference ?? "")).localizedCaseInsensitiveContains(search)) && (!filterDate || (entry.date >= period.interval(customStart: start, customEnd: end).start && entry.date < period.interval(customStart: start, customEnd: end).end)) && (minimum.isEmpty || abs(entry.amount) >= ((try? Money.parse(minimum)) ?? Int64.max)) && (maximum.isEmpty || abs(entry.amount) <= ((try? Money.parse(maximum)) ?? -1))
        }.sorted { oldestFirst ? $0.date < $1.date : $0.date > $1.date }
    }
    var body: some View {
        List {
            if entries.isEmpty { EmptyFinance(title: "No transactions", detail: "Add a transaction or adjust your filters.", symbol: "arrow.left.arrow.right") }
            ForEach(entries) { entry in NavigationLink { TransactionDetail(entryID: entry.id) } label: { TransactionRow(entry: entry) }.contextMenu { Button("Delete linked transaction", role: .destructive) { deleting = entry } } }
        }.scrollContentBackground(.hidden).background(Brand.background).navigationTitle("Transactions").searchable(text: $search, prompt: "Merchant, note or reference")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) { Button { showFilters = true } label: { Image(systemName: "line.3.horizontal.decrease.circle").accessibilityLabel("Filters") }; Button { showAdd = true } label: { Image(systemName: "plus.circle.fill").accessibilityLabel("Add transaction") } }
                ToolbarItem(placement: .bottomBar) { if let exportURL { ShareLink(item: exportURL, label: { Label("Share CSV", systemImage: "square.and.arrow.up") }) } else { Button("Prepare CSV of results") { store.perform { exportURL = try ExportFiles.write(Data(CSV.transactions(entries, accounts: store.data.accounts, categories: store.data.categories).utf8), name: "transactions.csv") } } } }
            }.sheet(isPresented: $showAdd) { TransactionEditor() }.sheet(isPresented: $showFilters) { filterSheet }.refreshable { store.perform { try store.reload() } }
            .confirmationDialog("Delete this transaction and its linked transfer?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }), titleVisibility: .visible) { Button("Delete", role: .destructive) { if let deleting { store.perform { try store.deleteEntry(deleting) } }; deleting = nil } }
            .onChange(of: store.data.entries) { _, _ in exportURL = nil }
            .onChange(of: search) { _, _ in exportURL = nil }.onChange(of: showFilters) { _, _ in exportURL = nil }
    }
    private var filterSheet: some View {
        NavigationStack { Form {
            Picker("Account", selection: $account) { Text("All").tag(nil as UUID?); ForEach(store.data.accounts) { Text($0.name).tag(Optional($0.id)) } }
            Picker("Category", selection: $category) { Text("All").tag(nil as UUID?); ForEach(store.data.categories) { Text($0.name).tag(Optional($0.id)) } }
            Picker("Type", selection: $kind) { Text("All").tag(nil as EntryKind?); ForEach(EntryKind.allCases) { Text($0.title).tag(Optional($0)) } }
            Picker("Source", selection: $source) { Text("All").tag(nil as EntrySource?); ForEach(EntrySource.allCases, id: \.self) { Text($0.rawValue.capitalized).tag(Optional($0)) } }
            Picker("Review", selection: $status) { Text("All").tag(nil as ReviewStatus?); ForEach(ReviewStatus.allCases, id: \.self) { Text($0.rawValue.capitalized).tag(Optional($0)) } }
            Toggle("Filter dates", isOn: $filterDate)
            if filterDate { Picker("Period", selection: $period) { ForEach(ReportPeriod.allCases) { Text($0.rawValue).tag($0) } }; if period == .custom { DatePicker("From", selection: $start, displayedComponents: .date); DatePicker("Through", selection: $end, displayedComponents: .date) } }
            TextField("Minimum amount (LKR)", text: $minimum).keyboardType(.decimalPad); TextField("Maximum amount (LKR)", text: $maximum).keyboardType(.decimalPad)
            if (!minimum.isEmpty && (try? Money.parse(minimum)) == nil) || (!maximum.isEmpty && (try? Money.parse(maximum)) == nil) { InlineError(message: "Amounts must contain up to two decimal places.") }
            Toggle("Oldest first", isOn: $oldestFirst)
            Button("Reset filters") { account = nil; category = nil; kind = nil; source = nil; status = nil; filterDate = false; minimum = ""; maximum = ""; oldestFirst = false }
        }.navigationTitle("Filters").toolbar { Button("Done") { showFilters = false } } }
    }
}
struct TransactionDetail: View {
    @Environment(FinanceStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let entryID: UUID
    @State private var edit = false
    @State private var deleting = false
    var body: some View {
        Group {
            if let entry = store.data.entries.first(where: { $0.id == entryID }) {
                List {
                    Section { AmountLabel(amount: entry.amount).font(.largeTitle.bold()).foregroundStyle(entry.amount < 0 ? Brand.expense : Brand.income); Text(entry.merchant.isEmpty ? entry.kind.title : entry.merchant).font(.title3) }
                    Section("Details") {
                        LabeledContent("Type", value: entry.kind.title); LabeledContent("Account", value: store.data.accounts.first { $0.id == entry.accountID }?.name ?? "Unknown"); LabeledContent("Category", value: store.data.categories.first { $0.id == entry.categoryID }?.name ?? "Uncategorized"); LabeledContent("Date", value: entry.date.formatted()); LabeledContent("Source", value: entry.source.rawValue.capitalized); LabeledContent("Status", value: entry.status.rawValue.capitalized)
                        if let reference = entry.reference { LabeledContent("Reference", value: reference) }; if let balance = entry.reportedBalance { HStack { Text("Reported balance"); Spacer(); AmountLabel(amount: balance) } }; if !entry.notes.isEmpty { Text(entry.notes) }
                        if entry.transferID != nil { Text("This entry is linked to its matching transfer. Editing or deleting updates both sides.").font(.footnote).foregroundStyle(.secondary) }
                    }
                    Button("Edit transaction") { edit = true }.disabled(store.data.accounts.first { $0.id == entry.accountID }?.archived == true)
                    Button("Delete transaction", role: .destructive) { deleting = true }
                }.sheet(isPresented: $edit) { TransactionEditor(existing: entry) }.confirmationDialog("Delete this transaction and any linked transfer?", isPresented: $deleting, titleVisibility: .visible) { Button("Delete", role: .destructive) { store.perform { try store.deleteEntry(entry); dismiss() } } }
            } else { EmptyFinance(title: "Transaction removed", detail: "This entry no longer exists.") }
        }.navigationTitle("Transaction").navigationBarTitleDisplayMode(.inline)
    }
}
struct TransactionEditor: View {
    @Environment(FinanceStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var existing: Entry?
    var initialKind: EntryKind = .expense
    var importItem: ImportValue?
    @State private var kind: EntryKind = .expense
    @State private var accountID: UUID?
    @State private var destination: UUID?
    @State private var amount = ""
    @State private var merchant = ""
    @State private var notes = ""
    @State private var date = Date()
    @State private var categoryID: UUID?
    @State private var saveRule = false
    @State private var allowDuplicate = false
    @State private var message: String?
    private var paired: Bool { [.transfer, .cardPayment].contains(kind) }
    var body: some View {
        NavigationStack {
            Form {
                if store.data.accounts.filter({ !$0.archived }).isEmpty { Section { Text("Create an account before adding transactions."); NavigationLink("Create account") { AccountEditor() } } }
                Section("Transaction") {
                    Picker("Type", selection: $kind) { ForEach(EntryKind.allCases) { Text($0.title).tag($0) } }
                    TextField(kind == .adjustment ? "Signed amount (LKR)" : "Amount (LKR)", text: $amount).keyboardType(kind == .adjustment ? .numbersAndPunctuation : .decimalPad)
                    if kind == .adjustment { Text("Positive adds to the account; negative reduces it.").font(.caption) }
                    Picker(paired ? "From" : "Account", selection: $accountID) { Text("Select").tag(nil as UUID?); ForEach(store.data.accounts.filter { !$0.archived }) { Text($0.name).tag(Optional($0.id)) } }
                    if paired { Picker("To", selection: $destination) { Text("Select").tag(nil as UUID?); ForEach(store.data.accounts.filter { !$0.archived && $0.id != accountID }) { Text($0.name).tag(Optional($0.id)) } } }
                    else { TextField("Merchant / payee", text: $merchant); Picker("Category", selection: $categoryID) { Text("Uncategorized").tag(nil as UUID?); ForEach(store.data.categories.filter { !$0.archived && $0.income == (kind == .income) }) { Text($0.name).tag(Optional($0.id)) } } }
                    DatePicker("Date & time", selection: $date, in: ...Date().addingTimeInterval(86400))
                    TextField("Note", text: $notes, axis: .vertical)
                }
                if !paired { Section { Toggle("Remember merchant category", isOn: $saveRule); Text("Adds a local keyword rule for this merchant.").font(.caption).foregroundStyle(.secondary) } }
                if let item = importItem { Section("Import review") { Text(item.parsed.reason); Text("Verify the direction, amount, date and account. Transfers and repayments must be linked to a destination.").font(.footnote); Toggle("Save despite possible duplicate", isOn: $allowDuplicate) } }
                InlineError(message: message)
            }.navigationTitle(importItem != nil ? "Review import" : existing == nil ? "New transaction" : "Edit transaction").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("Save") { save() }.bold() } }
                .onAppear { populate() }
                .onChange(of: kind) { _, value in if let categoryID, store.data.categories.first(where: { $0.id == categoryID })?.income != (value == .income) { self.categoryID = nil } }
        }
    }
    private func populate() {
        if let existing {
            kind = existing.kind; accountID = existing.accountID; amount = Money.input(kind == .adjustment ? existing.amount : abs(existing.amount)); merchant = existing.merchant; notes = existing.notes; date = existing.date; categoryID = existing.categoryID
            if let link = existing.transferID, let outgoing = store.data.entries.first(where: { $0.transferID == link && $0.amount < 0 }), let incoming = store.data.entries.first(where: { $0.transferID == link && $0.amount > 0 }) { accountID = outgoing.accountID; destination = incoming.accountID }
        } else if let item = importItem {
            kind = item.parsed.kind ?? .expense; amount = item.parsed.amount.map(Money.input) ?? ""; merchant = item.parsed.merchant ?? ""; date = item.parsed.date
            let matches = store.matchingAccounts(item.parsed); if matches.count == 1 { accountID = matches[0].id }
            categoryID = Finance.category(for: merchant, income: kind == .income, categories: store.data.categories, rules: store.data.rules).0
        } else { kind = initialKind; accountID = store.data.accounts.first { !$0.archived }?.id }
    }
    private func save() {
        do {
            guard let accountID else { throw FinanceError.invalidAccount }
            let minor = try Money.parse(amount, allowNegative: kind == .adjustment)
            guard minor != 0 else { throw FinanceError.invalidAmount }
            let signed = [.expense, .fee].contains(kind) ? -minor : minor
            var entry = Entry(id: existing?.id ?? UUID(), accountID: accountID, amount: signed, kind: kind, categoryID: paired ? nil : categoryID, merchant: merchant, notes: notes, date: date, createdAt: existing?.createdAt ?? Date(), source: importItem?.source ?? existing?.source ?? .manual, fingerprint: existing?.fingerprint ?? "", reference: existing?.reference, reportedBalance: existing?.reportedBalance)
            if entry.categoryID == nil && !paired && kind != .adjustment { entry.categoryID = Finance.category(for: merchant + " " + notes, income: kind == .income, categories: store.data.categories, rules: store.data.rules).0 }
            if let importItem { try store.confirmImport(importItem, entry: entry, destination: destination, allowDuplicate: allowDuplicate) } else { try store.saveEntry(entry, destination: destination, saveRule: saveRule) }
            UINotificationFeedbackGenerator().notificationOccurred(.success); dismiss()
        } catch { message = error.localizedDescription }
    }
}
enum ExportFiles {
    static func write(_ data: Data, name: String) throws -> URL {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("MyFinanceExports", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent(UUID().uuidString + "-" + name)
        try data.write(to: url, options: [.atomic, .completeFileProtection]); return url
    }
    static func cleanup() { try? FileManager.default.removeItem(at: FileManager.default.temporaryDirectory.appendingPathComponent("MyFinanceExports")) }
}
