import Foundation
import Testing
@testable import LexiCards

struct VocabularyTests {
    @Test
    func entryBuildsDisplayText() {
        let entry = VocabularyEntry(original: "猫", translation: "cat")

        #expect(entry.displayText == "猫 — cat")
    }

    @Test
    func loaderReadsValidRowsAndSkipsBlankOrMalformedRows() throws {
        let url = try makeTemporaryVocabularyFile(contents: """
        猫,cat

        malformed
        犬, dog
        """)
        defer { try? FileManager.default.removeItem(at: url) }

        let entries = VocabularyLoader.load(from: url)

        #expect(entries.count == 2)
        #expect(entries[0].original == "猫")
        #expect(entries[0].translation == "cat")
        #expect(entries[1].original == "犬")
        #expect(entries[1].translation == "dog")
    }

    @Test
    func loaderTreatsHeaderAsDataUntilHeaderSupportIsAdded() throws {
        let url = try makeTemporaryVocabularyFile(contents: """
        Original,Translation
        猫,cat
        """)
        defer { try? FileManager.default.removeItem(at: url) }

        let entries = VocabularyLoader.load(from: url)

        #expect(entries.count == 2)
        #expect(entries[0].original == "Original")
        #expect(entries[0].translation == "Translation")
    }

    @Test
    func loaderReturnsNoEntriesForUnreadableFile() {
        let url = URL(fileURLWithPath: "/tmp/lexicards-missing-vocabulary.csv")

        #expect(VocabularyLoader.load(from: url).isEmpty)
    }

    @Test
    func controllerCyclesThroughEntries() throws {
        let url = try makeTemporaryVocabularyFile(contents: "one,un\ntwo,deux\n")
        defer { try? FileManager.default.removeItem(at: url) }
        let controller = VocabularyController()

        #expect(controller.load(from: url))
        #expect(controller.next() == "one — un")
        #expect(controller.next() == "two — deux")
        #expect(controller.next() == "one — un")
    }

    @Test
    func controllerReturnsConfiguredTextWhenEmpty() {
        let originalText = AppSettings.shared.emptyVocabularyText
        AppSettings.shared.emptyVocabularyText = "No vocabulary"
        defer { AppSettings.shared.emptyVocabularyText = originalText }

        let controller = VocabularyController()

        #expect(controller.next() == "No vocabulary")
        #expect(controller.nextRandom() == "No vocabulary")
        #expect(controller.currentEntry == nil)
    }

    @Test
    func controllerKeepsSingleEntryStableWhenChoosingRandomly() throws {
        let url = try makeTemporaryVocabularyFile(contents: "猫,cat\n")
        defer { try? FileManager.default.removeItem(at: url) }
        let controller = VocabularyController()

        #expect(controller.load(from: url))
        #expect(controller.nextRandom() == "猫 — cat")
        #expect(controller.nextRandom() == "猫 — cat")
        #expect(controller.currentEntry?.original == "猫")
    }

    private func makeTemporaryVocabularyFile(contents: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("lexicards-\(UUID().uuidString)")
            .appendingPathExtension("csv")
        try contents.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}
