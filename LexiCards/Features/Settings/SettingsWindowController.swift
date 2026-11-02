import AppKit
import SwiftUI

/// Owns the settings window.
///
/// SwiftUI's `Settings` scene is not used: this is an `LSUIElement` app, so it
/// has no menu bar of its own to carry the standard Settings command, and the
/// scene's window cannot be summoned reliably from a status-item menu. An
/// ordinary window managed here behaves predictably instead.
final class SettingsWindowController: NSObject, NSWindowDelegate {
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
        saveFrame()
    }

    func windowDidMove(_: Notification) {
        saveFrame()
    }

    func windowDidResize(_: Notification) {
        saveFrame()
    }

    private func saveFrame() {
        if let window {
            AppSettings.shared.settingsWindowFrame = window.frame
        }
    }

    private static let defaultContentSize = NSSize(width: 620, height: 460)

    private func makeWindow() -> NSWindow {
        let tabViewController = SettingsTabViewController(model: model)

        // A view controller's view has no useful size until it lays out, so a
        // window built straight from it starts at 1x32. Centring something that
        // small puts it near the top of the screen, and it then grows downward
        // from that top edge — which is why settings always opened at the very
        // top.
        tabViewController.view.setFrameSize(Self.defaultContentSize)

        // The title comes from the selected tab, as in the system's own settings.
        let window = NSWindow(contentViewController: tabViewController)
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.toolbarStyle = .preference
        window.contentMinSize = Self.defaultContentSize
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.setContentSize(Self.defaultContentSize)

        restoreFrame(of: window)

        return window
    }

    /// Puts the window back where it was left, across openings and launches, or
    /// centres it when that place is gone.
    ///
    /// AppKit's frame autosave is not used: with several displays,
    /// `setFrameUsingName` moves a frame saved on one display onto another.
    private func restoreFrame(of window: NSWindow) {
        guard let saved = AppSettings.shared.settingsWindowFrame,
            NSScreen.screens.contains(where: { $0.visibleFrame.intersects(saved) })
        else {
            window.center()
            return
        }

        window.setFrame(saved, display: false)
    }
}
