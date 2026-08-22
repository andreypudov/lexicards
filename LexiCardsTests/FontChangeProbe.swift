import AVFoundation
import AppKit
import Foundation
import SwiftUI
import Testing

@testable import LexiCards

/// Regression cover for the settings window crashing when a font is changed.
///
/// The trigger was a `Divider()` sitting between tagged rows inside a `Picker`:
/// picker content is matched against the selection row by row, and an untaggable
/// child is not survivable. These tests realise the view and push selection
/// through every option so the matching actually runs.
@MainActor
@Suite(.serialized)
struct FontChangeProbe {
    @Test
    func changingFontRelayoutsWithoutCrashing() {
        withIsolatedSettings {
            let model = SettingsModel()
            let controller = NSHostingController(rootView: SettingsView(model: model))
            controller.view.frame = NSRect(x: 0, y: 0, width: 620, height: 460)
            controller.view.layoutSubtreeIfNeeded()

            let family = NSFontManager.shared.availableFontFamilies.first
            model.wordFontName = family
            model.commitFonts()
            controller.view.layoutSubtreeIfNeeded()

            model.wordFontSize = 40
            model.commitFonts()
            controller.view.layoutSubtreeIfNeeded()

            #expect(AppSettings.shared.wordFontName == family)
            #expect(AppSettings.shared.wordFontSize == 40)
        }
    }

    /// Walks a realised picker across many font families, then back to the
    /// system default, laying out after each change.
    @Test
    func cyclingThroughFontFamiliesKeepsTheWindowAlive() {
        withIsolatedSettings {
            let model = SettingsModel()
            let controller = NSHostingController(rootView: SettingsView(model: model))
            controller.view.frame = NSRect(x: 0, y: 0, width: 620, height: 460)
            controller.view.layoutSubtreeIfNeeded()

            for family in NSFontManager.shared.availableFontFamilies.prefix(25) {
                model.wordFontName = family
                model.translationFontName = family
                model.commitFonts()
                controller.view.layoutSubtreeIfNeeded()
            }

            model.wordFontName = nil
            model.translationFontName = nil
            model.commitFonts()
            controller.view.layoutSubtreeIfNeeded()

            #expect(AppSettings.shared.wordFontName == nil)
        }
    }

    @Test
    func selectingEachVoiceKeepsTheWindowAlive() {
        withIsolatedSettings {
            let model = SettingsModel()
            let controller = NSHostingController(rootView: SettingsView(model: model))
            controller.view.frame = NSRect(x: 0, y: 0, width: 620, height: 460)
            controller.view.layoutSubtreeIfNeeded()

            for voice in AVSpeechSynthesisVoice.speechVoices().prefix(15) {
                model.voiceIdentifier = voice.identifier
                model.commitVoice()
                controller.view.layoutSubtreeIfNeeded()
            }

            model.voiceIdentifier = nil
            model.commitVoice()
            controller.view.layoutSubtreeIfNeeded()

            #expect(AppSettings.shared.voiceIdentifier == nil)
        }
    }

    @Test
    func cardPanelRefreshesWithACustomFont() {
        withIsolatedSettings {
            let panel = VocabularyCardPanel()
            panel.update(entry: VocabularyEntry(original: "猫", translation: "cat"))

            AppSettings.shared.wordFontName = NSFontManager.shared.availableFontFamilies.first
            panel.refresh()

            #expect(panel.contentView != nil)
        }
    }
}
