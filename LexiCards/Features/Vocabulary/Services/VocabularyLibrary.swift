import Foundation
import os

/// The list of vocabularies the settings window offers: the ones shipped in the
/// bundle, plus every CSV the user has added.
///
/// The library only knows what is *available*. Opening a vocabulary, and the
/// security-scoped access that needs, stays in `VocabularyFileAccess`.
final class VocabularyLibrary {
    private static let builtInIdentifierPrefix = "builtin:"

    func sources() -> [VocabularySource] {
        builtInSources() + userSources()
    }

    func source(withIdentifier identifier: String) -> VocabularySource? {
        sources().first { $0.id == identifier }
    }

    /// Resource names double as identifiers, so a built-in vocabulary keeps its
    /// place in the list across launches and app updates.
    func builtInSources() -> [VocabularySource] {
        let urls = Bundle.main.urls(forResourcesWithExtension: "csv", subdirectory: nil) ?? []

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
        AppSettings.shared.userVocabularyBookmarks.compactMap(source(fromBookmark:))
    }

    /// Adds a user CSV to the library, replacing any existing entry for the same
    /// file so re-adding one cannot duplicate it.
    @discardableResult
    func addUserSource(at url: URL) -> VocabularySource? {
        guard let bookmark = bookmarkData(for: url) else {
            return nil
        }

        guard let added = source(fromBookmark: bookmark) else {
            return nil
        }

        var bookmarks = AppSettings.shared.userVocabularyBookmarks
            .filter { source(fromBookmark: $0)?.id != added.id }
        bookmarks.append(bookmark)
        AppSettings.shared.userVocabularyBookmarks = bookmarks

        return added
    }

    func removeUserSource(_ source: VocabularySource) {
        AppSettings.shared.userVocabularyBookmarks =
            AppSettings.shared.userVocabularyBookmarks
            .filter { self.source(fromBookmark: $0)?.id != source.id }
    }

    private func source(fromBookmark bookmark: Data) -> VocabularySource? {
        var isStale = false
        do {
            let url = try URL(
                resolvingBookmarkData: bookmark,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )

            return VocabularySource(
                id: url.path,
                name: url.deletingPathExtension().lastPathComponent,
                url: url,
                kind: .user,
                bookmark: bookmark
            )
        } catch {
            AppLog.vocabulary.error(
                "Dropping an unresolvable user vocabulary bookmark: \(error.localizedDescription, privacy: .public)"
            )
            return nil
        }
    }

    private func bookmarkData(for url: URL) -> Data? {
        let startedSecurityScope = url.startAccessingSecurityScopedResource()
        defer {
            if startedSecurityScope {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            return try url.bookmarkData(
                options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess]
            )
        } catch {
            AppLog.vocabulary.error(
                "Could not bookmark the added vocabulary: \(error.localizedDescription, privacy: .public)"
            )
            return nil
        }
    }
}
