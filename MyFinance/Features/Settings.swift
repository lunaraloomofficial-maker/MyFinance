import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(FinanceStore.self) private var store
    @Environment(AppLock.self) private var lock
    @State private var enablingLock = false
    var body: some View {
        Form {
            Section("Your finance space") { NavigationLink("Accounts") { AccountsView() }; NavigationLink("Categories") { CategoriesView() }; NavigationLink("Merchant rules") { RulesView() }; NavigationLink("SMS import & review") { SMSImportView() } }
            Section("Appearance") {
                Picker("Theme", selection: Binding(get: { store.data.settings.theme }, set: { value in store.perform { try store.updateSettings { $0.theme = value } } })) { Text("System").tag("system"); Text("Light").tag("light"); Text("Dark").tag("dark") }
                settingsToggle("Show financial values", keyPath: \.balanceVisibility)
                LabeledContent("Currency", value: "Sri Lankan Rupees · LKR")
            }
            Section("Privacy & security") {
                Toggle("Require device authentication", isOn: Binding(get: { store.data.settings.biometricLockEnabled }, set: { value in Task {
                    enablingLock = true; defer { enablingLock = false }
                    if await lock.authenticate() { store.perform { try store.updateSettings { $0.biometricLockEnabled = value } } }
                    else { store.error = lock.message }
                } })).disabled(enablingLock)
                settingsToggle("Lock immediately on leaving app", keyPath: \.lockImmediately)
                Text("Uses Face ID, Touch ID or your device passcode. If immediate locking is off, the app still locks when it enters the background. Recent app previews are covered.").font(.caption).foregroundStyle(.secondary)
                Text("Offline by default. No accounts, trackers, advertisements or bank credentials. Device data protection protects the local database; app lock controls access through this app.").font(.footnote)
            }
            Section("SMS preferences") { OpenFinanceShortcutsButton(); settingsToggle("Auto-save high-confidence imports", keyPath: \.autoImportPreference); Text("Requires an unambiguous account, date and reference. All imports require review while app lock is enabled.").font(.caption); NavigationLink("Shortcuts setup") { ShortcutsGuide() }; NavigationLink("Troubleshooting") { ImportTroubleshooting() } }
            Section("Your data") { NavigationLink("Encrypted backup & restore") { BackupView() }; NavigationLink("Export transactions") { TransactionsView() }; NavigationLink("Widget privacy & availability") { WidgetHelpView() } }
            Section("MyFinance") { Text("Built for clarity. Designed for privacy.").foregroundStyle(Brand.green); Text("Version 1.1 · Local storage only").font(.caption) }
        }.navigationTitle("Settings")
    }
    private func settingsToggle(_ title: String, keyPath: WritableKeyPath<SettingsValue, Bool>) -> some View { Toggle(title, isOn: Binding(get: { store.data.settings[keyPath: keyPath] }, set: { value in store.perform { try store.updateSettings { $0[keyPath: keyPath] = value } } })) }
}
struct CategoriesView: View {
    @Environment(FinanceStore.self) private var store
    @State private var editing: CategoryValue?
    @State private var add = false
    var body: some View {
        List {
            ForEach([false, true], id: \.self) { income in Section(income ? "Income" : "Expenses") { ForEach(store.data.categories.filter { $0.income == income }) { category in Button { editing = category } label: { Label(category.name + (category.archived ? " (archived)" : ""), systemImage: category.icon).foregroundStyle(Brand.color(category.color)) } } } }
        }.navigationTitle("Categories").toolbar { Button { add = true } label: { Image(systemName: "plus").accessibilityLabel("Add category") } }.sheet(isPresented: $add) { CategoryEditor() }.sheet(item: $editing) { CategoryEditor(existing: $0) }
    }
}
struct CategoryEditor: View {
    @Environment(FinanceStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var existing: CategoryValue?
    @State private var name = ""
    @State private var income = false
    @State private var icon = "tag.fill"
    @State private var color = "green"
    @State private var archived = false
    @State private var message: String?
    var body: some View {
        NavigationStack { Form { TextField("Category name", text: $name); Toggle("Income category", isOn: $income); Picker("Icon", selection: $icon) { ForEach(["tag.fill", "fork.knife", "basket.fill", "bag.fill", "car.fill", "house.fill", "heart.fill", "book.fill", "gift.fill", "banknote.fill"], id: \.self) { Label($0, systemImage: $0).tag($0) } }; if !["tag.fill", "fork.knife", "basket.fill", "bag.fill", "car.fill", "house.fill", "heart.fill", "book.fill", "gift.fill", "banknote.fill"].contains(icon) { Label("Current icon", systemImage: icon) }; TextField("SF Symbol name", text: $icon).autocorrectionDisabled().textInputAutocapitalization(.never); Picker("Color", selection: $color) { ForEach(["green", "blue", "orange", "purple", "coral"], id: \.self) { Text($0.capitalized).tag($0) } }; Toggle("Archive", isOn: $archived); InlineError(message: message) }.navigationTitle(existing == nil ? "New category" : "Edit category").toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("Save") { save() } } }.onAppear { if let v = existing { name = v.name; income = v.income; icon = v.icon; color = v.color; archived = v.archived } } }
    }
    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, UIImage(systemName: icon) != nil else { message = "Enter a name and a valid SF Symbol."; return }
        do { var next = store.data; next.categories.removeAll { $0.id == existing?.id }; guard !next.categories.contains(where: { $0.name.caseInsensitiveCompare(trimmed) == .orderedSame && $0.income == income }) else { message = "This category already exists."; return }; next.categories.append(CategoryValue(id: existing?.id ?? UUID(), name: trimmed, income: income, icon: icon, color: color, isDefault: existing?.isDefault ?? false, archived: archived)); try store.commit(next); dismiss() } catch { message = error.localizedDescription }
    }
}
struct RulesView: View {
    @Environment(FinanceStore.self) private var store
    @State private var add = false
    @State private var editing: MerchantRuleValue?
    var body: some View {
        List {
            if store.data.rules.isEmpty { EmptyFinance(title: "Teach your tracker", detail: "Save a rule while correcting a transaction, or add one here.", symbol: "line.3.horizontal.decrease.circle") }
            ForEach(store.data.rules.sorted { $0.priority > $1.priority }) { rule in Button { editing = rule } label: { VStack(alignment: .leading) { Text(rule.pattern).bold(); Text("\(rule.merchant) · \(store.data.categories.first { $0.id == rule.categoryID }?.name ?? "Category") · \(rule.enabled ? "Enabled" : "Disabled")").font(.caption).foregroundStyle(.secondary) } } }.onDelete { indices in let sorted = store.data.rules.sorted { $0.priority > $1.priority }; let ids = Set(indices.map { sorted[$0].id }); store.perform { var next = store.data; next.rules.removeAll { ids.contains($0.id) }; try store.commit(next) } }
        }.navigationTitle("Merchant rules").toolbar { Button { add = true } label: { Image(systemName: "plus").accessibilityLabel("Add rule") } }.sheet(isPresented: $add) { RuleEditor() }.sheet(item: $editing) { RuleEditor(existing: $0) }
    }
}
struct RuleEditor: View {
    @Environment(FinanceStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var existing: MerchantRuleValue?
    @State private var pattern = ""
    @State private var merchant = ""
    @State private var category: UUID?
    @State private var priority = 0
    @State private var enabled = true
    @State private var message: String?
    var body: some View { NavigationStack { Form { TextField("Keyword to match", text: $pattern); TextField("Merchant name (optional)", text: $merchant); Picker("Category", selection: $category) { Text("Select").tag(nil as UUID?); ForEach(store.data.categories.filter { !$0.archived }) { Text($0.name).tag(Optional($0.id)) } }; Stepper("Priority: \(priority)", value: $priority, in: 0...100); Toggle("Enabled", isOn: $enabled); Text("Case-insensitive keyword matching. Higher priorities win.").font(.caption); InlineError(message: message) }.navigationTitle("Merchant rule").toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("Save") { guard let category, !pattern.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { message = "Enter a keyword and select a category."; return }; do { var next = store.data; next.rules.removeAll { $0.id == existing?.id }; next.rules.append(MerchantRuleValue(id: existing?.id ?? UUID(), pattern: pattern.trimmingCharacters(in: .whitespacesAndNewlines), merchant: merchant, categoryID: category, priority: priority, enabled: enabled)); try store.commit(next); dismiss() } catch { message = error.localizedDescription } } } }.onAppear { if let v = existing { pattern = v.pattern; merchant = v.merchant; category = v.categoryID; priority = v.priority; enabled = v.enabled } } } }
}
struct BackupView: View {
    @Environment(FinanceStore.self) private var store
    @State private var password = ""
    @State private var busy = false
    @State private var message: String?
    @State private var exportURL: URL?
    @State private var importing = false
    @State private var preview: FinanceSnapshot?
    @State private var confirm = false
    var body: some View {
        Form {
            Section("Encrypted local backup") {
                SecureField("Passphrase (12+ characters)", text: $password).textContentType(.newPassword)
                Text("AES-256-GCM encryption with PBKDF2-HMAC-SHA256 (120,000 iterations). Keep the passphrase safe: it is never stored and cannot be recovered.").font(.footnote)
                Button("Create encrypted backup") { Task { await createBackup() } }.disabled(busy || password.count < 12)
                if let exportURL { ShareLink("Save / share encrypted backup", item: exportURL) }
                Button("Open backup for restore") { importing = true }.disabled(busy || password.isEmpty)
                if busy { ProgressView("Processing securely…") }
                InlineError(message: message)
            }
            if let preview {
                Section("Restore preview") {
                    Text("Backup created \(preview.createdAt.formatted())")
                    Text("\(preview.accounts.count) accounts · \(preview.entries.count) transactions · \(preview.budgets.count) budgets · \(preview.imports.count) imports")
                    Text("Restoring REPLACES all current app data, including categories, rules and preferences. IDs are preserved; restoring twice does not duplicate records. Export a current backup first.").font(.footnote).foregroundStyle(Brand.expense)
                    Button("Replace current data", role: .destructive) { confirm = true }
                    Button("Cancel restore") { self.preview = nil; password = "" }
                }
            }
        }.navigationTitle("Backup & restore").fileImporter(isPresented: $importing, allowedContentTypes: [.data, .json]) { result in Task { await openBackup(result) } }
            .confirmationDialog("Replace all current financial data?", isPresented: $confirm, titleVisibility: .visible) { Button("Replace data", role: .destructive) { if let preview { store.perform { try store.restore(preview) }; self.preview = nil; password = "" } } }
            .onDisappear { password = ""; preview = nil; ExportFiles.cleanup() }
    }
    private func createBackup() async {
        busy = true; defer { busy = false; password = "" }
        do { let snapshot = store.data, passphrase = password; let data = try await Task.detached(priority: .userInitiated) { try Backup.encrypt(snapshot, password: passphrase) }.value; exportURL = try ExportFiles.write(data, name: "myfinance.mfbackup"); message = nil } catch { message = error.localizedDescription }
    }
    private func openBackup(_ result: Result<URL, Error>) async {
        busy = true; preview = nil; defer { busy = false }
        do { let url = try result.get(); let granted = url.startAccessingSecurityScopedResource(); defer { if granted { url.stopAccessingSecurityScopedResource() } }; let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0; guard size <= 50_000_000 else { throw FinanceError.invalidBackup("file exceeds 50 MB") }; let data = try Data(contentsOf: url); let passphrase = password; preview = try await Task.detached(priority: .userInitiated) { try Backup.decrypt(data, password: passphrase) }.value; message = nil } catch { message = error.localizedDescription }
    }
}
struct WidgetHelpView: View {
    @Environment(FinanceStore.self) private var store
    var body: some View { Form { Section("Optional widgets") { Text("The optional widget target provides private placeholders and app-opening actions. It is not embedded in the main app by default and does not require App Groups for the main app to run."); Text("Live shared balances are intentionally not enabled. They need App Group provisioning and a separate privacy-aware snapshot writer. No live shared data is claimed.") }; Section("Privacy") { Toggle("Hide widget financial values", isOn: Binding(get: { store.data.settings.widgetPrivacyEnabled }, set: { value in store.perform { try store.updateSettings { $0.widgetPrivacyEnabled = value } } })); Text("Current widgets always hide values, regardless of this preference. This preference is reserved for a future provisioned shared-data integration.").font(.caption) } }.navigationTitle("Widgets") }
}
