import AppKit
import SwiftUI

/// Owns the settings window.
///
/// SwiftUI's `Settings` scene is not used: this is an `LSUIElement` app, so it
/// has no menu bar of its own to carry the standard Settings command, and the
/// scene's window cannot be summoned reliably from a status-item menu. An
/// ordinary window managed here behaves predictably instead.
final class SettingsWindowController: NSObject, NSWindowDelegate {
    /// AppKit persists the frame under this name, so the window comes back where
    /// it was left — across openings and across launches.
    private static let frameAutosaveName = NSWindow.FrameAutosaveName("LexiCardsSettingsWindow")

    private let model: SettingsModel
    private(set) var window: NSWindow?

    init(model: SettingsModel) {
        self.model = model
        super.init()
    }

    func show() {
        let window = window ?? makeWindow()
        self.window = window

        // An accessory app is not activated by ordering a window front, so the
        // window would otherwise appear behind whatever the user was working in.
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    /// The window is kept after closing rather than rebuilt. Its position, size,
    /// and selected tab are all state the user set, and throwing it away is what
    /// made settings reopen somewhere else every time.
    func windowWillClose(_: Notification) {
        window?.saveFrame(usingName: Self.frameAutosaveName)
    }

    private static let defaultContentSize = NSSize(width: 620, height: 460)

    private func makeWindow() -> NSWindow {
        let hostingController = NSHostingController(rootView: SettingsView(model: model))

        // A hosting controller has no size until SwiftUI lays out, so a window
        // built straight from it starts at 1x32. Centring something that small
        // puts it near the top of the screen, and it then grows downward from
        // that top edge — which is why settings always opened at the very top.
        hostingController.view.setFrameSize(Self.defaultContentSize)

        let window = NSWindow(contentViewController: hostingController)
        window.title = "LexiCards Settings"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.setContentSize(Self.defaultContentSize)

        // Centre only when there is nothing remembered; otherwise restore.
        if !window.setFrameUsingName(Self.frameAutosaveName) {
            window.center()
        }
        window.setFrameAutosaveName(Self.frameAutosaveName)

        return window
    }
}
