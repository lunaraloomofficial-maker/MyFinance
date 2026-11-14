import SwiftUI
import UniformTypeIdentifiers

struct SMSImportView: View {
    @Environment(FinanceStore.self) private var store
    @State private var text = ""
    @State private var importSource: EntrySource = .sms
    @State private var sender = ""
    @State private var received = Date()
    @State private var message: String?
    @State private var parsing = false
    @State private var reviewing: ImportValue?
    @State private var fileImport = false
    @State private var discarding: ImportValue?
    var body: some View {
        List {
            Section { ShortcutConnectionCard() }
            Section {
                Text("Import an individual bank notification. MyFinance cannot read your SMS inbox. Message text is parsed on your device and is not retained; only extracted fields are saved.").font(.footnote).foregroundStyle(.secondary)
                TextEditor(text: $text).frame(minHeight: 130).accessibilityLabel("Bank SMS text")
                TextField("Sender (optional)", text: $sender)
                DatePicker("Received", selection: $received, in: ...Date())
                Button { Task { await parse() } } label: { if parsing { ProgressView() } else { Label("Parse & import", systemImage: "text.badge.checkmark") } }.disabled(text.isEmpty || parsing)
                Button("Import shared text file") { fileImport = true }
                if let message { Text(message).font(.footnote) }
            } header: { Text("Paste bank SMS") }
            Section("Needs your review") {
                let pending = store.data.imports.filter { $0.linkedTransactionID == nil }.sorted { $0.receivedAt > $1.receivedAt }
                if pending.isEmpty { Text("All caught up.").foregroundStyle(.secondary) }
                ForEach(pending) { item in
                    Button { reviewing = item } label: { VStack(alignment: .leading, spacing: 7) { HStack { Text(item.parsed.merchant ?? item.parsed.bank ?? "Bank transaction").bold(); Spacer(); if let amount = item.parsed.amount { AmountLabel(amount: amount) } }; Text("\(item.parsed.confidence.rawValue.capitalized) confidence · \(item.parsed.reason)").font(.caption).foregroundStyle(.secondary); Text(item.receivedAt, style: .date).font(.caption2) } }.buttonStyle(.plain)
                        .swipeActions { Button("Discard", role: .destructive) { discarding = item } }
                }
            }
            Section { NavigationLink("Set up Apple Shortcuts") { ShortcutsGuide() }; NavigationLink("Import troubleshooting") { ImportTroubleshooting() } }
        }.navigationTitle("SMS import").navigationBarTitleDisplayMode(.inline).sheet(item: $reviewing) { TransactionEditor(importItem: $0) }
            .fileImporter(isPresented: $fileImport, allowedContentTypes: [.plainText]) { result in
                do { let url = try result.get(); let granted = url.startAccessingSecurityScopedResource(); defer { if granted { url.stopAccessingSecurityScopedResource() } }; let data = try Data(contentsOf: url); guard data.count <= 16_384 else { throw FinanceError.invalidMessage }; text = String(decoding: data, as: UTF8.self); importSource = .shared } catch { message = error.localizedDescription }
            }.confirmationDialog("Discard this pending import?", isPresented: Binding(get: { discarding != nil }, set: { if !$0 { discarding = nil } }), titleVisibility: .visible) { Button("Discard", role: .destructive) { if let discarding { store.perform { var next = store.data; next.imports.removeAll { $0.id == discarding.id }; try store.commit(next) } }; discarding = nil } }
    }
    private func parse() async {
        parsing = true; defer { parsing = false; importSource = .sms }
        do { message = try await store.importText(text, sender: sender, date: received, source: importSource); text = "" } catch { message = error.localizedDescription; if (error as? FinanceError) != nil { text = "" } }
    }
}
struct ImportTroubleshooting: View {
    var body: some View { List {
        Section("Shortcut action missing?") { Text("Open MyFinance after installing an update, then use Open in Shortcuts from the SMS import screen. The button refreshes MyFinance’s action and opens its own page. Apple Shortcuts must be installed. With a sideloaded app, action discovery still needs checking on the actual phone.") }
        Section("Nothing imported?") { Text("Verify that your automation passes the message body, not only the sender. Run it manually first. iOS does not provide unrestricted background SMS access.") }
        Section("Needs review?") { Text("Unknown senders, missing dates, unmatched accounts, transfers and ambiguous amounts require confirmation. Add the last four account digits and correct institution to help account matching.") }
        Section("Rejected message?") { Text("OTP/security text, marketing, balance-only alerts, unsupported currencies and messages without a transaction amount are rejected. Create a manual transaction when a format is unsupported.") }
        Section("Possible duplicate?") { Text("Exact message fingerprints, account-scoped references and matching amount/direction/time/merchant are checked. Review the existing entries. You may explicitly save a reviewed import despite a duplicate warning.") }
        Section("Linked debit card") { Text("Record an event once against the bank account or its linked debit card. References and account-scoped matching help detect overlapping card and bank alerts; ambiguous messages need manual review.") }
    }.navigationTitle("Import help") }
}
