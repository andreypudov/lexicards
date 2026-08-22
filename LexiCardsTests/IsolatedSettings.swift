import Foundation

@testable import LexiCards

/// Runs `body` with `AppSettings.shared` pointed at a throwaway defaults suite.
///
/// The test target's host application is LexiCards itself, so
/// `UserDefaults.standard` is the installed app's real preferences. A test that
/// wrote a font size straight through `AppSettings.shared` changed the font the
/// user saw the next time they opened the app — which is exactly what happened.
/// Anything that mutates settings belongs inside this.
///
/// Synchronous on purpose: the suites are `@MainActor`, so without an `await`
/// inside, no other test can interleave and observe the swapped store.
@MainActor
func withIsolatedSettings(_ body: () throws -> Void) rethrows {
    let suiteName = "LexiCardsTests-\(UUID().uuidString)"
    guard let suite = UserDefaults(suiteName: suiteName) else {
        try body()
        return
    }

    let original = AppSettings.shared.defaults
    AppSettings.shared.defaults = suite
    defer {
        AppSettings.shared.defaults = original
        suite.removePersistentDomain(forName: suiteName)
    }

    try body()
}
