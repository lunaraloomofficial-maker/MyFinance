import SwiftUI
import AppIntents

/// Apple's supported link resolves this installed app, including when it is re-signed.
/// It opens MyFinance's App Shortcuts page rather than an empty shortcut editor.
struct OpenFinanceShortcutsButton: View {
    var body: some View {
        ShortcutsLink {
            FinanceShortcuts.updateAppShortcutParameters()
        }
        .shortcutsLinkStyle(.dark)
        .accessibilityHint("Opens the ready-made MyFinance import action in Apple Shortcuts.")
    }
}

struct ShortcutConnectionCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Connect Apple Shortcuts", systemImage: "bolt.square.fill")
                .font(.headline).foregroundStyle(Brand.green)
            Text("Your bank SMS import action is included. Open it directly in Shortcuts to finish the one-time setup.")
                .font(.subheadline).foregroundStyle(.secondary)
            OpenFinanceShortcutsButton()
            NavigationLink {
                ShortcutsGuide()
            } label: {
                Label("Set up automatic imports", systemImage: "arrow.right.circle")
                    .font(.subheadline.weight(.semibold))
            }
        }
        .padding(.vertical, 8)
    }
}

struct ShortcutsGuide: View {
    @Environment(FinanceStore.self) private var store

    private var activeAccounts: [AccountValue] { store.data.accounts.filter { !$0.archived } }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 16) {
                    Image(systemName: "bolt.horizontal.circle.fill")
                        .font(.system(size: 44)).foregroundStyle(Brand.green)
                        .accessibilityHidden(true)
                    Text("Less typing. More clarity.")
                        .font(.title2.bold())
                    Text("MyFinance supplies the import action. Connect it to a bank message once, and Shortcuts can pass new alerts straight to your tracker.")
                        .foregroundStyle(.secondary)
                    OpenFinanceShortcutsButton()
                }.padding(.vertical, 10)
            }

            Section("1 · Choose your account") {
                if activeAccounts.isEmpty {
                    Label("Add an account first", systemImage: "wallet.bifold")
                    Text("A bank name and the last four digits help match incoming alerts.")
                        .font(.footnote).foregroundStyle(.secondary)
                    NavigationLink("Add an account") { AccountEditor() }
                } else {
                    Label("\(activeAccounts.count) active accounts available", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(Brand.green)
                    NavigationLink("Review account names & last four digits") { AccountsView() }
                }
            }

            Section("2 · Open your ready-made action") {
                Label("Import Bank SMS", systemImage: "text.bubble.fill")
                    .font(.headline)
                Text("The action already knows how to parse and review a bank alert. You do not need to build that logic or type each SMS again.")
                    .font(.subheadline).foregroundStyle(.secondary)
                OpenFinanceShortcutsButton()
                Text("This opens MyFinance’s page in Apple Shortcuts, rather than a blank editor.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("3 · Connect a Message trigger") {
                setupRow("message.fill", title: "Choose your bank’s messages", detail: "In Shortcuts, create a Message automation and select your bank sender or message condition.")
                setupRow("arrow.down.doc.fill", title: "Use the incoming message", detail: "Choose MyFinance’s Import Bank SMS action. For SMS text, select Shortcut Input or the message content offered by your iOS version.")
                setupRow("bolt.fill", title: "Choose when it runs", detail: "Select Run Immediately if offered, then confirm the automation. Some versions or configurations require confirmation.")
                Text("Apple requires this one-time trigger setup on your iPhone. Opening Shortcuts does not by itself enable automatic SMS capture.")
                    .font(.footnote).foregroundStyle(.secondary)
            }

            Section("4 · Choose how imports are saved") {
                Toggle("Auto-save clear matches", isOn: Binding(
                    get: { store.data.settings.autoImportPreference },
                    set: { value in store.perform { try store.updateSettings { $0.autoImportPreference = value } } }
                ))
                Text("Only high-confidence alerts matching exactly one active account can save automatically. Uncertain alerts go to your review queue.")
                    .font(.footnote).foregroundStyle(.secondary)
                if store.data.settings.biometricLockEnabled {
                    Label("App lock is on: all imports will wait for review.", systemImage: "lock.shield")
                        .font(.footnote).foregroundStyle(Brand.green)
                }
                NavigationLink("Open import review queue") { SMSImportView() }
            }

            Section("Need a hand?") {
                NavigationLink("Shortcuts & import troubleshooting") { ImportTroubleshooting() }
                Text("If Shortcuts is not installed, download Apple’s Shortcuts app from the App Store and return here. After an app update, open MyFinance once before using its action.")
                    .font(.footnote).foregroundStyle(.secondary)
                Text("MyFinance does not retain the original message text or upload it. OTP and verification messages are rejected.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Connect Shortcuts")
        .navigationBarTitleDisplayMode(.inline)
        .task { FinanceShortcuts.updateAppShortcutParameters() }
    }

    private func setupRow(_ symbol: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol).foregroundStyle(Brand.green)
                .frame(width: 26).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(detail).font(.footnote).foregroundStyle(.secondary)
            }
        }.padding(.vertical, 5)
    }
}
