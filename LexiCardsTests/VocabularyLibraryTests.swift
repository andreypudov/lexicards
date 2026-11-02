import AppKit
import Foundation
import Testing

@testable import LexiCards

/// Added vocabularies live as the app's own copies, so these run against a
/// throwaway directory: the user's real ones must stay out of reach.
@MainActor
@Suite(.serialized)
struct VocabularyLibraryTests {
    private let scratch: URL
    private let library: VocabularyLibrary

    init() {
        scratch = FileManager.default.temporaryDirectory
            .appending(path: "LexiCardsTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
        library = VocabularyLibrary(directory: scratch.appending(path: "library"))
    }

    private func file(
        _ name: String, _ contents: String, in folder: String = "originals"
    ) throws
        -> URL
    {
        let directory = scratch.appending(path: folder, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appending(path: name)
        try contents.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    // MARK: - Copies

    @Test
    func anAddedFileKeepsWorkingAfterTheOriginalIsGone() throws {
        let original = try file("words.csv", "猫,cat\n")

        let source = try #require(library.addUserSource(at: original))
        try FileManager.default.removeItem(at: original)

        #expect(source.kind == .user)
        #expect(source.name == "words")
        #expect(library.userSources() == [source])
        #expect(
            VocabularyLoader.load(from: source.url) == [
                VocabularyEntry(original: "猫", translation: "cat")
            ])
    }

    @Test
    func aFileWithNoUsableRowsIsNotAdded() throws {
        #expect(library.addUserSource(at: try file("empty.csv", "no comma here\n")) == nil)
        #expect(library.userSources().isEmpty)
    }

    @Test
    func addingAFileOfTheSameNameUpdatesItsCopy() throws {
        let first = try #require(library.addUserSource(at: try file("words.csv", "猫,cat\n")))
        let second = try #require(
            library.addUserSource(at: try file("words.csv", "犬,dog\n", in: "elsewhere")))

        #expect(first.id == second.id)
        #expect(library.userSources().count == 1)
        #expect(VocabularyLoader.load(from: second.url).first?.original == "犬")
    }

    @Test
    func aBadReplacementLeavesTheCopyAsItWas() throws {
        let source = try #require(library.addUserSource(at: try file("words.csv", "猫,cat\n")))

        #expect(library.addUserSource(at: try file("words.csv", "nothing usable\n")) == nil)

        #expect(VocabularyLoader.load(from: source.url).first?.original == "猫")
    }

    @Test
    func removingDeletesTheCopyAndLeavesTheOriginal() throws {
        let original = try file("words.csv", "猫,cat\n")
        let source = try #require(library.addUserSource(at: original))

        #expect(library.removeUserSource(source))

        #expect(library.userSources().isEmpty)
        #expect(FileManager.default.fileExists(atPath: original.path))
    }

    /// How a list is updated: the old one goes, and the new file takes its place
    /// entirely, whatever it is called.
    @Test
    func removingAListThenAddingANewFileReplacesItEntirely() throws {
        let old = try #require(library.addUserSource(at: try file("words.csv", "猫,cat\n犬,dog\n")))

        #expect(library.removeUserSource(old))
        let new = try #require(library.addUserSource(at: try file("words v2.csv", "水,water\n")))

        #expect(library.userSources() == [new])
        #expect(
            VocabularyLoader.load(from: new.url) == [
                VocabularyEntry(original: "水", translation: "water")
            ])
    }

    @Test
    func builtInListsCannotBeRemoved() throws {
        let builtIn = try #require(library.builtInSources().first)

        #expect(library.removeUserSource(builtIn) == false)
        #expect(FileManager.default.fileExists(atPath: builtIn.url.path))
    }

    // MARK: - Files from earlier versions

    private func bookmark(_ url: URL) throws -> Data {
        try url.bookmarkData(options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess])
    }

    @Test
    func earlierBookmarksAreCopiedInAndTheSelectionFollows() throws {
        try withIsolatedSettings {
            let original = try file("words.csv", "猫,cat\n")
            AppSettings.shared.userVocabularyBookmarks = [try bookmark(original)]
            AppSettings.shared.selectedVocabularyIdentifier = original.path

            library.importLegacyBookmarks()

            let source = try #require(library.userSources().first)
            #expect(source.name == "words")
            #expect(AppSettings.shared.selectedVocabularyIdentifier == source.id)
            #expect(AppSettings.shared.userVocabularyBookmarks.isEmpty)
            #expect(library.hasPendingLegacyBookmarks == false)
        }
    }

    @Test
    func aBookmarkThatCannotBeReachedIsKeptForNextTime() {
        withIsolatedSettings {
            let unreadable = Data("not a bookmark".utf8)
            AppSettings.shared.userVocabularyBookmarks = [unreadable]

            library.importLegacyBookmarks()

            #expect(AppSettings.shared.userVocabularyBookmarks == [unreadable])
            #expect(library.hasPendingLegacyBookmarks)
            #expect(library.userSources().isEmpty)
        }
    }

    @Test
    func twoEarlierFilesWithOneNameAreBothKept() throws {
        try withIsolatedSettings {
            AppSettings.shared.userVocabularyBookmarks = [
                try bookmark(try file("words.csv", "猫,cat\n", in: "a")),
                try bookmark(try file("words.csv", "犬,dog\n", in: "b")),
            ]

            library.importLegacyBookmarks()

            #expect(library.userSources().map(\.name) == ["words", "words 2"])
        }
    }

    /// The same file was usually bookmarked twice: in the list and as the last
    /// one opened. Importing again must not make a second copy either.
    @Test
    func theSameEarlierFileIsCopiedOnce() throws {
        try withIsolatedSettings {
            let original = try file("words.csv", "猫,cat\n")
            AppSettings.shared.userVocabularyBookmarks = [try bookmark(original)]
            AppSettings.shared.lastVocabularyBookmark = try bookmark(original)
            AppSettings.shared.lastVocabularyPath = original.path

            library.importLegacyBookmarks()
            AppSettings.shared.userVocabularyBookmarks = [try bookmark(original)]
            library.importLegacyBookmarks()

            #expect(library.userSources().count == 1)
            #expect(AppSettings.shared.lastVocabularyBookmark == nil)
            #expect(AppSettings.shared.lastVocabularyPath == nil)
        }
    }

    /// An install from before the library, or a file that has since moved: the
    /// saved selection names nothing, so the file last open takes its place.
    @Test
    func theFileLastOpenBecomesTheSelectionWhenItNamesNothing() throws {
        try withIsolatedSettings {
            let original = try file("words.csv", "猫,cat\n")
            AppSettings.shared.lastVocabularyBookmark = try bookmark(original)
            AppSettings.shared.selectedVocabularyIdentifier = "/somewhere/it/used/to/be.csv"

            library.importLegacyBookmarks()

            #expect(AppSettings.shared.selectedVocabularyIdentifier == "user:words")
        }
    }

    /// The host app must recognize a test run, or it starts up on the user's real
    /// settings and imports their files before any test has begun.
    @Test
    func theHostAppDoesNotStartDuringTests() {
        #expect(AppDelegate.isHostingTests)
    }
}
