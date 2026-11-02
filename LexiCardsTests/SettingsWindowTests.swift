import AppKit
import Foundation
import Testing

@testable import LexiCards

/// The settings window has to reopen where it was left, not jump back to the
/// centre of the screen on every open.
@MainActor
@Suite(.serialized)
struct SettingsWindowTests {
    @Test
    func reopeningKeepsThePositionTheUserMovedItTo() {
        withIsolatedSettings {
            let controller = SettingsWindowController(model: SettingsModel())
            controller.show()

            guard let window = controller.window else {
                Issue.record("show() did not create a window")
                return
            }

            let moved = NSRect(x: 220, y: 180, width: 620, height: 548)
            window.setFrame(moved, display: false)
            window.close()

            controller.show()

            #expect(controller.window === window, "the window was rebuilt instead of reused")
            #expect(controller.window?.frame == moved)
            window.close()
        }
    }

    /// A fresh controller stands in for the next launch: the frame has to come
    /// back from disk, not just from the live window being kept around. Every
    /// display is tried, because AppKit's own autosave moved a frame saved on
    /// one display onto another.
    @Test
    func aLaterLaunchRestoresTheSavedFrameOnEveryDisplay() {
        withIsolatedSettings {
            for screen in NSScreen.screens {
                let visible = screen.visibleFrame
                let moved = NSRect(
                    x: visible.minX + 40, y: visible.minY + 40, width: 620, height: 548)

                let first = SettingsWindowController(model: SettingsModel())
                first.show()
                first.window?.setFrame(moved, display: false)
                first.window?.close()

                #expect(AppSettings.shared.settingsWindowFrame == moved)

                let next = SettingsWindowController(model: SettingsModel())
                next.show()

                #expect(next.window?.frame == moved)
                next.window?.close()
            }
        }
    }

    @Test
    func theWindowIsCentredWhenNothingIsRemembered() {
        withIsolatedSettings {
            expectCentredOnOpening()
        }
    }

    /// The display it was left on has been unplugged.
    @Test
    func theWindowIsCentredWhenItsPlaceIsNoLongerOnAnyScreen() {
        withIsolatedSettings {
            AppSettings.shared.settingsWindowFrame = NSRect(
                x: 90_000, y: 90_000, width: 620, height: 548)

            expectCentredOnOpening()
        }
    }

    private func expectCentredOnOpening() {
        let controller = SettingsWindowController(model: SettingsModel())
        controller.show()

        guard let window = controller.window, let screen = window.screen ?? NSScreen.main else {
            Issue.record("no window or screen available")
            return
        }

        #expect(abs(window.frame.midX - screen.visibleFrame.midX) < 1)
        window.close()
    }

    /// Both menu commands reuse the open window, so a tab named by the model has
    /// to reach it, and a tab the user picks has to reach the model.
    @Test
    func theModelAndTheWindowAgreeOnTheSelectedTab() {
        withIsolatedSettings {
            let model = SettingsModel()
            model.selectedTab = .application
            let controller = SettingsWindowController(model: model)
            controller.show()
            defer { controller.window?.close() }

            guard let tabs = controller.window?.contentViewController as? NSTabViewController else {
                Issue.record("the window does not show the settings tabs")
                return
            }

            #expect(tabs.selectedTabViewItemIndex == 1)
            #expect(controller.window?.title == "Application")

            model.selectedTab = .about
            #expect(tabs.selectedTabViewItemIndex == 2)
            #expect(controller.window?.title == "About")

            tabs.selectedTabViewItemIndex = 0
            #expect(model.selectedTab == .vocabulary)
        }
    }

    /// The window's size belongs to the user: a tab with little in it must not
    /// shrink the window, nor one with a lot grow it.
    @Test
    func switchingTabsLeavesTheWindowWhereTheUserPutIt() {
        withIsolatedSettings {
            let model = SettingsModel()
            let controller = SettingsWindowController(model: model)
            controller.show()
            defer { controller.window?.close() }

            guard let window = controller.window else {
                Issue.record("show() did not create a window")
                return
            }

            let chosen = NSRect(x: 240, y: 160, width: 720, height: 560)
            window.setFrame(chosen, display: false)

            for tab in SettingsTab.allCases {
                model.selectedTab = tab
                RunLoop.main.run(until: Date().addingTimeInterval(0.4))
                #expect(window.frame == chosen, "selecting \(tab) changed the window frame")
            }
        }
    }

}
