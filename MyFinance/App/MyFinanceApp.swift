import SwiftUI
import SwiftData
import AppIntents

@main struct MyFinanceApp: App {
    @State private var store: FinanceStore?
    @State private var startupError: String?
    @State private var lock = AppLock()
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedTab = 0
    @State private var addFromLink = false
    @State private var shortcutsFromLink = false
    init() { FinanceShortcuts.updateAppShortcutParameters() }
    var body: some Scene {
        WindowGroup {
            Group {
                if let store {
                    ZStack {
                        if store.data.settings.biometricLockEnabled && !lock.unlocked { LockScreen() }
                        else { MainTabs(selectedTab: $selectedTab)
                            .sheet(isPresented: $addFromLink) { TransactionEditor() }
                            .sheet(isPresented: $shortcutsFromLink) { NavigationStack { ShortcutsGuide() } } }
                        if scenePhase != .active { Brand.background.ignoresSafeArea().overlay { Label("MyFinance", systemImage: "leaf.fill").font(.title.bold()).foregroundStyle(Brand.green) } }
                    }
                    .environment(store).environment(lock).tint(Brand.green)
                    .preferredColorScheme(store.data.settings.theme == "system" ? nil : store.data.settings.theme == "dark" ? .dark : .light)
                    .alert("Something needs attention", isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) { Button("OK") { store.error = nil } } message: { Text(store.error ?? "") }
                    .onOpenURL { url in guard url.scheme == "myfinance" else { return }; if url.host == "shortcuts" { shortcutsFromLink = true }; if url.host == "dashboard" { selectedTab = 0 }; if url.host == "add" { addFromLink = true }; if url.host == "budgets" { selectedTab = 2 } }
                    .onChange(of: scenePhase) { _, phase in
                        if phase == .background && store.data.settings.biometricLockEnabled { lock.unlocked = false }
                        if phase == .inactive && store.data.settings.lockImmediately && store.data.settings.biometricLockEnabled && !lock.authenticating { lock.unlocked = false }
                        if phase == .active { store.perform { try store.reload() } }
                    }
                } else if let startupError {
                    ContentUnavailableView { Label("Your data could not be opened", systemImage: "externaldrive.badge.exclamationmark") } description: { Text(startupError + "\nNo data has been deleted. Close and reopen the app to retry.") }
                } else { ProgressView("Opening MyFinance…") }
            }.task { guard store == nil, startupError == nil else { return }; do { ExportFiles.cleanup(); store = try FinanceStore(container: FinanceStore.makeContainer()) } catch { startupError = error.localizedDescription } }
        }
    }
}
struct MainTabs: View {
    @Binding var selectedTab: Int
    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack { DashboardView() }.tabItem { Label("Home", systemImage: "square.grid.2x2.fill") }.tag(0)
            NavigationStack { TransactionsView() }.tabItem { Label("Transactions", systemImage: "arrow.left.arrow.right") }.tag(1)
            NavigationStack { BudgetsView() }.tabItem { Label("Budgets", systemImage: "chart.pie.fill") }.tag(2)
            NavigationStack { AnalyticsView() }.tabItem { Label("Analytics", systemImage: "chart.bar.xaxis") }.tag(3)
            NavigationStack { SettingsView() }.tabItem { Label("Settings", systemImage: "gearshape.fill") }.tag(4)
        }
    }
}
