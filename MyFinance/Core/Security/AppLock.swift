import SwiftUI
import LocalAuthentication
import Observation

@MainActor @Observable final class AppLock {
    var unlocked = false
    var authenticating = false
    var message: String?
    func authenticate() async -> Bool {
        guard !authenticating else { return false }
        authenticating = true; defer { authenticating = false }
        let context = LAContext(); var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else { message = "Device authentication is unavailable. Set a device passcode in iPhone Settings, then retry. Your data stays locked."; return false }
        do { let success = try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Unlock your personal finances"); unlocked = success; message = nil; return success } catch { message = error.localizedDescription; return false }
    }
}
struct LockScreen: View {
    @Environment(AppLock.self) private var lock
    var body: some View { VStack(spacing: 24) { Image(systemName: "lock.shield.fill").font(.system(size: 58)).foregroundStyle(Brand.green); Text("Your money. Your privacy.").font(.title2.bold()); Button("Unlock MyFinance") { Task { _ = await lock.authenticate() } }.buttonStyle(.borderedProminent).disabled(lock.authenticating); InlineError(message: lock.message) }.padding(32).frame(maxWidth: .infinity, maxHeight: .infinity).background(Brand.background).task { _ = await lock.authenticate() } }
}
