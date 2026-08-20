import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let coordinator = AppCoordinator()

    func applicationDidFinishLaunching(_: Notification) {
        coordinator.start()
    }

    func applicationWillTerminate(_: Notification) {
        coordinator.stop()
    }
}
