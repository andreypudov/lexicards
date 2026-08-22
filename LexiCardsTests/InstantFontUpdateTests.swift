import AppKit
import Foundation
import SwiftUI
import Testing

@testable import LexiCards

/// A font change has to reach the card immediately, not at the next rotation.
///
/// Serialized, and every case runs against an isolated defaults suite: the test
/// host is the app itself, so writing settings directly would change the fonts
/// the user actually sees.
@MainActor
@Suite(.serialized)
struct InstantFontUpdateTests {
    @Test
    func commitFontsNotifiesListeners() {
        withIsolatedSettings {
            let model = SettingsModel()
            var notified = false
            model.onFontsChanged = { notified = true }

            model.wordFontName = "Helvetica"
            model.commitFonts()
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.2))

            #expect(notified, "onFontsChanged never fired")
        }
    }

    @Test
    func panelAdoptsANewFontWithoutWaitingForTheNextCard() {
        withIsolatedSettings {
            let panel = VocabularyCardPanel()
            panel.update(entry: VocabularyEntry(original: "猫", translation: "cat"))

            panel.apply(
                wordFont: CardFont(familyName: "Helvetica", size: 30, weight: .semibold),
                translationFont: CardFont(familyName: "Menlo", size: 14, weight: .regular)
            )

            let hosting = panel.contentView as? MovableHostingView
            #expect(hosting?.rootView.wordFont.familyName == "Helvetica")
            #expect(hosting?.rootView.wordFont.size == 30)
            #expect(hosting?.rootView.translationFont.familyName == "Menlo")
        }
    }

    /// The regression that made a font change wait for the next card: the
    /// notification was scheduled with `DispatchQueue.main.async`, which runs
    /// only in the default runloop mode, while a `Picker` delivers its selection
    /// during `NSMenu` tracking. Running the runloop *only* in event-tracking
    /// mode reproduces that starvation, so this fails if the deferral ever goes
    /// back to a default-mode-only queue.
    @Test
    func notificationsArriveWhileAMenuIsTracking() {
        withIsolatedSettings {
            let model = SettingsModel()
            var notified = false
            model.onFontsChanged = { notified = true }

            model.wordFontName = "Helvetica"
            model.commitFonts()

            RunLoop.current.run(mode: .eventTracking, before: Date().addingTimeInterval(0.5))

            #expect(notified, "the card would not repaint until the rotation timer fired")
        }
    }

    @Test
    func intervalChangesArePersistedAndAnnounced() {
        withIsolatedSettings {
            let model = SettingsModel()
            var notified = false
            model.onIntervalChanged = { notified = true }

            model.wordInterval = 21
            model.commitInterval()
            RunLoop.current.run(mode: .eventTracking, before: Date().addingTimeInterval(0.5))

            #expect(AppSettings.shared.wordInterval == 21)
            #expect(notified)
        }
    }
}
