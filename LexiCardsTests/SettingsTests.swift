import AppKit
import Foundation
import SwiftUI
import Testing

@testable import LexiCards

/// The settings window is built from SwiftUI containers whose misuse only shows
/// up when a view is actually realised — a `Table` needs identifiable rows, a
/// `Picker` needs its tag type to match its selection. Laying the hierarchy out
/// here turns those from a crash on first open into a failing test.
@MainActor
struct SettingsTests {
    @Test
    func settingsViewBuildsAndLaysOut() {
        let model = SettingsModel()
        model.sources = [
            VocabularySource(
                id: "builtin:Sample",
                name: "Sample",
                url: URL(fileURLWithPath: "/tmp/sample.csv"),
                kind: .builtIn
            ),
            VocabularySource(
                id: "/tmp/mine.csv",
                name: "mine",
                url: URL(fileURLWithPath: "/tmp/mine.csv"),
                kind: .user
            ),
        ]
        model.selectedSourceID = "builtin:Sample"
        model.entries = VocabularyEntryRow.rows(from: [
            VocabularyEntry(original: "猫", translation: "cat"),
            VocabularyEntry(original: "犬", translation: "dog"),
        ])

        let controller = NSHostingController(rootView: SettingsView(model: model))
        controller.view.frame = NSRect(x: 0, y: 0, width: 620, height: 460)
        controller.view.layoutSubtreeIfNeeded()

        #expect(controller.view.subviews.isEmpty == false)
    }

    @Test
    func rowsCarryStableDistinctIdentitiesForDuplicateEntries() {
        let duplicate = VocabularyEntry(original: "猫", translation: "cat")
        let rows = VocabularyEntryRow.rows(from: [duplicate, duplicate])

        #expect(rows.count == 2)
        #expect(rows[0].id != rows[1].id)
        #expect(rows[0].original == "猫")
    }

    /// The dropdown is only useful if the app actually ships vocabularies, which
    /// depends on the CSVs reaching `Contents/Resources` at build time.
    @Test
    func builtInVocabulariesAreBundled() {
        let sources = VocabularyLibrary().builtInSources()

        #expect(sources.isEmpty == false)
        #expect(sources.allSatisfy { $0.kind == .builtIn })
        #expect(sources.allSatisfy { $0.id.hasPrefix("builtin:") })

        for source in sources {
            let entries = VocabularyLoader.load(from: source.url)
            #expect(entries.isEmpty == false, "\(source.name) should parse into entries")
        }
    }

    @Test
    func builtInVocabulariesAreSortedByName() {
        let names = VocabularyLibrary().builtInSources().map(\.name)

        #expect(names == names.sorted { $0.localizedStandardCompare($1) == .orderedAscending })
    }

    /// A fresh install must open on a real vocabulary. If this breaks, the card
    /// falls back to the empty-state placeholder and the app looks broken until
    /// the user finds settings on their own.
    @Test
    func aFreshInstallHasABuiltInVocabularyToOpen() {
        let library = VocabularyLibrary()

        guard let first = library.builtInSources().first else {
            Issue.record("no built-in vocabulary ships with the app")
            return
        }

        #expect(first.kind == .builtIn)
        #expect(first.name == "Genki I - 01 New Friends")

        // The startup path only counts it as loaded when it parses to entries.
        let controller = VocabularyController()
        #expect(controller.load(from: first.url))
        #expect(controller.allEntries.count > 1)
        #expect(controller.nextRandom() != nil)
    }

    /// The card's default type sizes are a product decision, not an accident of
    /// whatever the view happened to hardcode.
    /// Both menu commands open the same window, so the tab is the only thing
    /// that distinguishes them; it has to survive into a realised view.
    @Test
    func everyTabRealisesAndHoldsItsSelection() {
        withIsolatedSettings {
            let model = SettingsModel()
            #expect(model.selectedTab == .vocabulary)

            for tab in SettingsTab.allCases {
                model.selectedTab = tab

                let controller = NSHostingController(rootView: SettingsView(model: model))
                controller.view.frame = NSRect(x: 0, y: 0, width: 620, height: 460)
                controller.view.layoutSubtreeIfNeeded()

                #expect(model.selectedTab == tab)
                #expect(controller.view.subviews.isEmpty == false)
            }
        }
    }

    @Test
    func aboutTabRealisesAndReportsTheBuiltVersion() {
        let controller = NSHostingController(rootView: AboutSettingsView())
        controller.view.frame = NSRect(x: 0, y: 0, width: 620, height: 460)
        controller.view.layoutSubtreeIfNeeded()

        #expect(controller.view.subviews.isEmpty == false)

        // Read from the bundle, so About cannot disagree with what was built.
        #expect(AppInfo.name == "LexiCards")
        #expect(AppInfo.versionLine == "Version \(marketingVersion)")
        #expect(AppInfo.versionLine.contains("—") == false)
        #expect(AppInfo.copyright.isEmpty == false)
        #expect(AppInfo.repository != nil)
        #expect(AppInfo.releases != nil)
    }

    /// The mark is drawn from the artwork, not the composed application icon;
    /// if the asset goes missing this renders an empty image silently.
    @Test
    func appMarkArtworkIsBundled() {
        #expect(NSImage(named: "AppMark") != nil)
    }

    private var marketingVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
    }

    @Test
    func tabsCarryDistinctTitlesAndSymbols() {
        let titles = SettingsTab.allCases.map(\.title)
        let symbols = SettingsTab.allCases.map(\.symbolName)

        #expect(titles == ["Vocabulary", "Application", "About"])
        #expect(Set(symbols).count == symbols.count)
    }

    @Test
    func cardUsesTheDefaultTypeSizesWhenNothingIsStored() {
        withIsolatedSettings {
            #expect(AppSettings.shared.wordFontSize == 21)
            #expect(AppSettings.shared.translationFontSize == 16)
            #expect(CardFont.word(from: AppSettings.shared).size == 21)
            #expect(CardFont.translation(from: AppSettings.shared).size == 16)
        }
    }

    @Test
    func cardFontFallsBackToTheSystemFontWhenNoFamilyIsChosen() {
        let system = CardFont(familyName: nil, size: 26, weight: .semibold)
        let named = CardFont(familyName: "Helvetica", size: 18, weight: .regular)

        #expect(system.resolved == Font.system(size: 26, weight: .semibold, design: .rounded))
        #expect(named.resolved == Font.custom("Helvetica", size: 18))
    }
}
