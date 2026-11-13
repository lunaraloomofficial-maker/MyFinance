import SwiftUI

struct AccountsView: View {
    @Environment(FinanceStore.self) private var store
    @State private var add = false
    @State private var showArchived = false
    var body: some View {
        List {
            if store.data.accounts.isEmpty { EmptyFinance(title: "Your money, together", detail: "Add a bank account, cash wallet or credit card.", symbol: "wallet.bifold") }
            ForEach(store.data.accounts.filter { showArchived || !$0.archived }) { account in
                NavigationLink { AccountDetail(accountID: account.id) } label: {
                    HStack { Image(systemName: account.icon).foregroundStyle(Brand.color(account.color)).frame(width: 40); VStack(alignment: .leading) { Text(account.name).font(.headline); Text([account.institution, account.maskedIdentifier, account.archived ? "Archived" : account.kind.title].filter { !$0.isEmpty }.joined(separator: " · ")).font(.caption).foregroundStyle(.secondary) }; Spacer(); AmountLabel(amount: balance(account)).font(.subheadline.bold()) }
                }
            }
            Toggle("Show archived accounts", isOn: $showArchived)
        }.navigationTitle("Accounts").toolbar { Button { add = true } label: { Image(systemName: "plus").accessibilityLabel("Add account") } }.sheet(isPresented: $add) { NavigationStack { AccountEditor() } }
    }
    private func balance(_ account: AccountValue) -> Int64 { (try? Finance.balance(account, entries: store.data.entries, accounts: store.data.accounts)) ?? 0 }
}
struct AccountDetail: View {
    @Environment(FinanceStore.self) private var store
    let accountID: UUID
    @State private var edit = false
    @State private var reconcile = false
    @State private var target = ""
    @State private var archiving = false
    var body: some View {
        if let account = store.data.accounts.first(where: { $0.id == accountID }) {
            List {
                Section {
                    AmountLabel(amount: (try? Finance.balance(account, entries: store.data.entries, accounts: store.data.accounts)) ?? 0).font(.largeTitle.bold())
                    Text(account.kind == .creditCard ? "Negative balance represents outstanding credit card debt." : account.linkedAccountID == nil ? "Opening balance plus confirmed account entries." : "Linked debit card. Shares its bank account balance; excluded from combined totals.").font(.footnote).foregroundStyle(.secondary)
                    LabeledContent("Institution", value: account.institution); LabeledContent("Identifier", value: account.maskedIdentifier); LabeledContent("Type", value: account.kind.title)
                }
                NavigationLink("Search transaction history") { TransactionsView(accountID: account.linkedAccountID ?? account.id) }
                Button("Edit account") { edit = true }
                if !account.archived && account.linkedAccountID == nil { Button("Reconcile balance") { target = Money.input((try? Finance.balance(account, entries: store.data.entries, accounts: store.data.accounts)) ?? 0); reconcile = true } }
                Button(account.archived ? "Reactivate account" : "Archive account", role: account.archived ? nil : .destructive) { archiving = true }
            }.navigationTitle(account.name).sheet(isPresented: $edit) { NavigationStack { AccountEditor(existing: account) } }
                .alert("Reconcile balance", isPresented: $reconcile) { TextField("Actual signed balance", text: $target); Button("Record adjustment") { store.perform { try store.reconcile(account: account, target: Money.parse(target, allowNegative: true)) } }; Button("Cancel", role: .cancel) {} } message: { Text("Records a balance adjustment, excluded from spending and income. For credit cards, use a negative amount for debt.") }
                .confirmationDialog(account.archived ? "Reactivate account?" : "Archive account? Existing history is preserved.", isPresented: $archiving, titleVisibility: .visible) { Button(account.archived ? "Reactivate" : "Archive") { var edited = account; edited.archived.toggle(); edited.updatedAt = Date(); store.perform { try store.saveAccount(edited) } } }
        }
    }
}
struct AccountEditor: View {
    @Environment(FinanceStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var existing: AccountValue?
    @State private var name = ""
    @State private var institution = "Other/custom bank"
    @State private var customBank = ""
    @State private var kind: AccountKind = .savings
    @State private var identifier = ""
    @State private var opening = "0"
    @State private var linked: UUID?
    @State private var icon = "building.columns.fill"
    @State private var color = "green"
    @State private var message: String?
    var body: some View {
        Form {
            Section("Account") {
                TextField("Name", text: $name)
                Picker("Type", selection: $kind) { ForEach(AccountKind.allCases) { Text($0.title).tag($0) } }
                Picker("Institution", selection: $institution) { ForEach(SMSParser.banks + ["Other/custom bank"], id: \.self) { Text($0).tag($0) } }
                if institution == "Other/custom bank" { TextField("Institution (optional)", text: $customBank) }
                TextField("Last four digits only", text: $identifier).keyboardType(.numberPad)
                if kind == .debitCard { Picker("Linked bank account", selection: $linked) { Text("Standalone").tag(nil as UUID?); ForEach(store.data.accounts.filter { $0.id != existing?.id && $0.linkedAccountID == nil && $0.kind != .creditCard && !$0.archived }) { Text($0.name).tag(Optional($0.id)) } }; Text("Link a debit card to avoid counting the same account twice. Record a transaction once, using either label.").font(.caption) }
                if linked == nil || kind != .debitCard { TextField("Opening balance (LKR)", text: $opening).keyboardType(.numbersAndPunctuation); if kind == .creditCard { Text("Enter debt as a negative opening balance.").font(.caption) } }
                Picker("Icon", selection: $icon) { ForEach(["building.columns.fill", "creditcard.fill", "banknote.fill", "wallet.bifold.fill", "leaf.fill"], id: \.self) { Label($0.replacingOccurrences(of: ".fill", with: ""), systemImage: $0).tag($0) } }
                Picker("Color", selection: $color) { ForEach(["green", "blue", "orange", "purple", "coral"], id: \.self) { Text($0.capitalized).tag($0) } }
            }
            InlineError(message: message)
        }.navigationTitle(existing == nil ? "New account" : "Edit account").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("Save") { save() } } }
            .onAppear { if let v = existing { name = v.name; institution = SMSParser.banks.contains(v.institution) ? v.institution : "Other/custom bank"; customBank = v.institution; kind = v.kind; identifier = String(v.maskedIdentifier.suffix(4)); opening = Money.input(v.openingBalance); linked = v.linkedAccountID; icon = v.icon; color = v.color } }
    }
    private func save() {
        do {
            guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { message = "Give this account a name."; return }
            guard identifier.isEmpty || (identifier.count == 4 && identifier.allSatisfy(\.isNumber)) else { message = "Use only the last four digits, or leave this blank."; return }
            let link = kind == .debitCard ? linked : nil
            let value = AccountValue(id: existing?.id ?? UUID(), name: name.trimmingCharacters(in: .whitespacesAndNewlines), institution: institution == "Other/custom bank" ? customBank : institution, kind: kind, maskedIdentifier: identifier.isEmpty ? "" : "••••" + identifier, openingBalance: link == nil ? try Money.parse(opening, allowNegative: true) : 0, createdAt: existing?.createdAt ?? Date(), archived: existing?.archived ?? false, icon: icon, color: color, linkedAccountID: link)
            try store.saveAccount(value); dismiss()
        } catch { message = error.localizedDescription }
    }
}
