import Foundation
import Testing

@testable import LexiCards

@MainActor
struct VocabularyTests {
    @Test
    func loaderReadsValidRowsAndSkipsBlankOrMalformedRows() throws {
        let url = try makeTemporaryVocabularyFile(
            contents: """
                猫,cat

                malformed
                犬, dog
                """
        )
        defer { try? FileManager.default.removeItem(at: url) }

        let entries = VocabularyLoader.load(from: url)

        #expect(
            entries == [
                VocabularyEntry(original: "猫", translation: "cat"),
                VocabularyEntry(original: "犬", translation: "dog"),
            ])
    }

    @Test
    func loaderTreatsHeaderAsDataUntilHeaderSupportIsAdded() throws {
        let url = try makeTemporaryVocabularyFile(
            contents: """
                Original,Translation
                猫,cat
                """
        )
        defer { try? FileManager.default.removeItem(at: url) }

        let entries = VocabularyLoader.load(from: url)

        #expect(entries.count == 2)
        #expect(entries[0] == VocabularyEntry(original: "Original", translation: "Translation"))
    }

    @Test
    func loaderReturnsNoEntriesForUnreadableFile() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("lexicards-missing-\(UUID().uuidString).csv")

        #expect(VocabularyLoader.load(from: url).isEmpty)
    }

    @Test
    func controllerHasNoCurrentEntryBeforeSelection() throws {
        let url = try makeTemporaryVocabularyFile(contents: "one,un\ntwo,deux\n")
        defer { try? FileManager.default.removeItem(at: url) }
        let controller = VocabularyController()

        #expect(controller.load(from: url))
        #expect(controller.currentEntry == nil)
    }

    @Test
    func controllerReportsNothingWhenEmpty() {
        let controller = VocabularyController()

        #expect(controller.nextRandom() == nil)
        #expect(controller.currentEntry == nil)
        #expect(controller.allEntries.isEmpty)
    }

    @Test
    func controllerRejectsAFileWithNoUsableRows() throws {
        let url = try makeTemporaryVocabularyFile(contents: "\nmalformed\n")
        defer { try? FileManager.default.removeItem(at: url) }
        let controller = VocabularyController()

        #expect(controller.load(from: url) == false)
        #expect(controller.currentEntry == nil)
    }

    @Test
    func controllerKeepsSingleEntryStableWhenChoosingRandomly() throws {
        let url = try makeTemporaryVocabularyFile(contents: "猫,cat\n")
        defer { try? FileManager.default.removeItem(at: url) }
        let controller = VocabularyController()

        #expect(controller.load(from: url))
        #expect(controller.nextRandom() == VocabularyEntry(original: "猫", translation: "cat"))
        #expect(controller.nextRandom() == VocabularyEntry(original: "猫", translation: "cat"))
        #expect(controller.currentEntry?.original == "猫")
    }

    /// The rotation must never pick the entry already on screen, which is the one
    /// behaviour of `nextRandom()` that is not self-evident from its name.
    @Test
    func controllerNeverRepeatsTheCurrentEntryConsecutively() throws {
        let url = try makeTemporaryVocabularyFile(contents: "one,un\ntwo,deux\nthree,trois\n")
        defer { try? FileManager.default.removeItem(at: url) }
        let controller = VocabularyController()
        #expect(controller.load(from: url))

        var previous = controller.nextRandom()
        for _ in 0..<200 {
            let next = controller.nextRandom()
            #expect(next != nil)
            #expect(next != previous)
            #expect(next == controller.currentEntry)
            previous = next
        }
    }

    @Test
    func controllerSelectsEveryEntryEventually() throws {
        let url = try makeTemporaryVocabularyFile(contents: "one,un\ntwo,deux\nthree,trois\n")
        defer { try? FileManager.default.removeItem(at: url) }
        let controller = VocabularyController()
        #expect(controller.load(from: url))

        var seen: Set<String> = []
        for _ in 0..<200 {
            if let entry = controller.nextRandom() {
                seen.insert(entry.original)
            }
        }

        #expect(seen == ["one", "two", "three"])
    }

    @Test
    func controllerReplacesEntriesWhenLoadingAnotherFile() throws {
        let first = try makeTemporaryVocabularyFile(contents: "one,un\n")
        let second = try makeTemporaryVocabularyFile(contents: "two,deux\n")
        defer {
            try? FileManager.default.removeItem(at: first)
            try? FileManager.default.removeItem(at: second)
        }
        let controller = VocabularyController()

        #expect(controller.load(from: first))
        controller.nextRandom()
        #expect(controller.load(from: second))

        #expect(controller.allEntries == [VocabularyEntry(original: "two", translation: "deux")])
        #expect(controller.currentEntry == nil)
    }

    private func makeTemporaryVocabularyFile(contents: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("lexicards-\(UUID().uuidString)")
            .appendingPathExtension("csv")
        try contents.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}
