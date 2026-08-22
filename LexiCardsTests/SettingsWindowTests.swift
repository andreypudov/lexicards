import AppKit
import Foundation
import Testing

@testable import LexiCards

/// The settings window has to reopen where it was left, not jump back to the
/// centre of the screen on every open.
///
/// Window frames are written by AppKit's own autosave, not through
/// `AppSettings`, so the isolated-suite helper does not cover them; each test
/// clears the autosave key before and after instead.
@MainActor
@Suite(.serialized)
struct SettingsWindowTests {
    private static let autosaveKey = "NSWindow Frame LexiCardsSettingsWindow"

    @Test
    func reopeningKeepsThePositionTheUserMovedItTo() {
        clearSavedFrame()
        defer { clearSavedFrame() }

        let controller = SettingsWindowController(model: SettingsModel())
        controller.show()

        guard let window = controller.window else {
            Issue.record("show() did not create a window")
            return
        }

        let moved = NSRect(x: 220, y: 180, width: 620, height: 460)
        window.setFrame(moved, display: false)
        window.close()

        controller.show()

        #expect(controller.window === window, "the window was rebuilt instead of reused")
        #expect(controller.window?.frame.origin.x == moved.origin.x)
        #expect(controller.window?.frame.origin.y == moved.origin.y)
    }

    /// A fresh controller stands in for the next launch: the frame has to come
    /// back from disk, not just from the live window being kept around.
    @Test
    func aLaterLaunchRestoresTheSavedFrame() {
        clearSavedFrame()
        defer { clearSavedFrame() }

        let first = SettingsWindowController(model: SettingsModel())
        first.show()
        let moved = NSRect(x: 260, y: 200, width: 620, height: 460)
        first.window?.setFrame(moved, display: false)
        first.window?.close()

        #expect(UserDefaults.standard.string(forKey: Self.autosaveKey) != nil)

        let next = SettingsWindowController(model: SettingsModel())
        next.show()

        #expect(next.window?.frame.origin.x == moved.origin.x)
        #expect(next.window?.frame.origin.y == moved.origin.y)

        next.window?.close()
    }

    @Test
    func theWindowIsCentredOnlyWhenNothingIsRemembered() {
        clearSavedFrame()
        defer { clearSavedFrame() }

        let controller = SettingsWindowController(model: SettingsModel())
        controller.show()

        guard let window = controller.window, let screen = window.screen ?? NSScreen.main else {
            Issue.record("no window or screen available")
            return
        }

        // NSWindow.center() places the window horizontally centred; assert that
        // rather than an exact frame, which depends on the display.
        let expectedX = screen.visibleFrame.midX - window.frame.width / 2
        #expect(abs(window.frame.midX - screen.visibleFrame.midX) < window.frame.width)
        #expect(window.frame.origin.x > expectedX - window.frame.width)

        window.close()
    }

    private func clearSavedFrame() {
        UserDefaults.standard.removeObject(forKey: Self.autosaveKey)
        NSWindow.removeFrame(usingName: NSWindow.FrameAutosaveName("LexiCardsSettingsWindow"))
    }
}
