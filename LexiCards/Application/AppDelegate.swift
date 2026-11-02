import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let coordinator = AppCoordinator()

    /// The test target's host is this app, launched on the user's real settings
    /// and container. Starting it there would rewrite their selection and move
    /// their vocabularies on every test run, so tests build what they need.
    static var isHostingTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    func applicationDidFinishLaunching(_: Notification) {
        guard !Self.isHostingTests else {
            return
        }

        coordinator.start()
    }

    func applicationWillTerminate(_: Notification) {
        coordinator.stop()
    }
}
