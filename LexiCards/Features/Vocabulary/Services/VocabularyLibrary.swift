import Foundation
import os

/// The vocabularies the app offers: the ones shipped in the bundle, plus its own
/// copies of the CSVs the user has added.
///
/// A copy is what makes an added vocabulary dependable: it stays readable after
/// the original moves or its drive is unplugged. The original is never touched.
final class VocabularyLibrary {
    private static let builtInIdentifierPrefix = "builtin:"
    private static let userIdentifierPrefix = "user:"
    private static let fileExtension = "csv"

    private let directory: URL

    /// `directory` is injectable so tests cannot reach the user's vocabularies.
    init(directory: URL = VocabularyLibrary.defaultDirectory) {
        self.directory = directory
    }

    /// Inside the sandbox, this resolves to the app's own container.
    static var defaultDirectory: URL {
        URL.applicationSupportDirectory
            .appending(path: "LexiCards", directoryHint: .isDirectory)
            .appending(path: "Vocabularies", directoryHint: .isDirectory)
    }

    func sources() -> [VocabularySource] {
        builtInSources() + userSources()
    }

    func source(withIdentifier identifier: String) -> VocabularySource? {
        sources().first { $0.id == identifier }
    }

    /// Resource names double as identifiers, so a built-in vocabulary keeps its
    /// place in the list across launches and app updates.
    func builtInSources() -> [VocabularySource] {
        let urls =
            Bundle.main.urls(forResourcesWithExtension: Self.fileExtension, subdirectory: nil) ?? []

        return
            urls
            .map { url in
                let name = url.deletingPathExtension().lastPathComponent
                return VocabularySource(
                    id: Self.builtInIdentifierPrefix + name,
                    name: name,
                    url: url,
                    kind: .builtIn
                )
            }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    func userSources() -> [VocabularySource] {
        let urls =
            (try? FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: nil
            )) ?? []

        return
            urls
            .filter { $0.pathExtension.lowercased() == Self.fileExtension }
            .map(userSource(at:))
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    /// Copies a file into the library, replacing any copy of the same name. A
    /// file with no usable rows leaves the library exactly as it was.
    func addUserSource(at url: URL) -> VocabularySource? {
        guard let data = usableContents(of: url) else {
            return nil
        }

        return store(data, named: url.deletingPathExtension().lastPathComponent)
    }

    @discardableResult
    func removeUserSource(_ source: VocabularySource) -> Bool {
        guard source.kind == .user else {
            return false
        }

        do {
            try FileManager.default.removeItem(at: source.url)
            return true
        } catch {
            AppLog.vocabulary.error(
                "Could not remove the vocabulary: \(error.localizedDescription, privacy: .public)"
            )
            return false
        }
    }

    // MARK: - Files added by earlier versions

    /// Copies in the files earlier versions only kept bookmarks to.
    ///
    /// A bookmark is dropped once its file is safely copied, or turns out to have
    /// no usable rows. One that cannot be reached right now, perhaps on an
    /// unplugged drive, stays and is tried again at the next launch.
    func importLegacyBookmarks() {
        let settings = AppSettings.shared
        let lastBookmark = settings.lastVocabularyBookmark
        var bookmarks = settings.userVocabularyBookmarks
        if let lastBookmark, !bookmarks.contains(lastBookmark) {
            bookmarks.append(lastBookmark)
        }
        guard !bookmarks.isEmpty else {
            return
        }

        var remaining: [Data] = []
        var lastImported: VocabularySource?
        var selectionWasImported = false
        for bookmark in bookmarks {
            var isStale = false
            guard
                let url = try? URL(
                    resolvingBookmarkData: bookmark,
                    options: [.withSecurityScope],
                    relativeTo: nil,
                    bookmarkDataIsStale: &isStale
                )
            else {
                remaining.append(bookmark)
                continue
            }

            // Earlier versions bookmarked the built-in lists they opened too.
            if url.path.contains(".app/Contents/Resources/") {
                continue
            }

            let started = url.startAccessingSecurityScopedResource()
            defer {
                if started {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            guard (try? Data(contentsOf: url)) != nil else {
                remaining.append(bookmark)
                continue
            }
            guard let data = usableContents(of: url) else {
                continue
            }
            guard let source = storeWithoutOverwriting(original: data, named: url) else {
                remaining.append(bookmark)
                continue
            }

            if settings.selectedVocabularyIdentifier == url.path {
                settings.selectedVocabularyIdentifier = source.id
                selectionWasImported = true
            }
            if bookmark == lastBookmark {
                lastImported = source
            }
        }

        // A selection that names no vocabulary, with the file last open now in
        // the library: it moved, or the install predates the library.
        if !selectionWasImported, let lastImported,
            source(withIdentifier: settings.selectedVocabularyIdentifier ?? "") == nil
        {
            settings.selectedVocabularyIdentifier = lastImported.id
        }

        settings.userVocabularyBookmarks = remaining
        settings.lastVocabularyBookmark = nil
        settings.lastVocabularyPath = nil
    }

    /// Whether some earlier file could not be reached and may still turn up.
    var hasPendingLegacyBookmarks: Bool {
        !AppSettings.shared.userVocabularyBookmarks.isEmpty
    }

    /// Two earlier files can share a name, which a copy cannot. The same content
    /// is the same vocabulary; anything else gets a number.
    private func storeWithoutOverwriting(original data: Data, named url: URL) -> VocabularySource? {
        let name = url.deletingPathExtension().lastPathComponent
        var candidate = name
        var number = 1
        while let existing = userSources().first(where: { $0.name == candidate }) {
            if (try? Data(contentsOf: existing.url)) == data {
                return existing
            }
            number += 1
            candidate = "\(name) \(number)"
        }

        return store(data, named: candidate)
    }

    // MARK: - Files

    /// The file's bytes, if it can be read and has at least one usable row.
    private func usableContents(of url: URL) -> Data? {
        let started = url.startAccessingSecurityScopedResource()
        defer {
            if started {
                url.stopAccessingSecurityScopedResource()
            }
        }

        guard !VocabularyLoader.load(from: url).isEmpty else {
            AppLog.vocabulary.error(
                "No usable entries in vocabulary file: \(url.lastPathComponent, privacy: .public)"
            )
            return nil
        }

        return try? Data(contentsOf: url)
    }

    private func store(_ data: Data, named name: String) -> VocabularySource? {
        let url = directory.appending(path: name, directoryHint: .notDirectory)
            .appendingPathExtension(Self.fileExtension)

        do {
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
            try data.write(to: url, options: .atomic)
            return userSource(at: url)
        } catch {
            AppLog.vocabulary.error(
                "Could not store the vocabulary: \(error.localizedDescription, privacy: .public)"
            )
            return nil
        }
    }

    private func userSource(at url: URL) -> VocabularySource {
        let name = url.deletingPathExtension().lastPathComponent
        return VocabularySource(
            id: Self.userIdentifierPrefix + name,
            name: name,
            url: url,
            kind: .user
        )
    }
}
