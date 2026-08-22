import AppKit
import Foundation
import os

final class VocabularyFileAccess {
    private var securityScopedURL: URL?

    func load(from url: URL, into controller: VocabularyController) -> Bool {
        load(from: url, into: controller, rememberingBookmark: true)
    }

    func restoreLast(into controller: VocabularyController) -> Bool {
        if let bookmarkData = AppSettings.shared.lastVocabularyBookmark {
            var isStale = false
            do {
                let url = try URL(
                    resolvingBookmarkData: bookmarkData,
                    options: [.withSecurityScope],
                    relativeTo: nil,
                    bookmarkDataIsStale: &isStale
                )

                // A stale bookmark still resolves; it just needs rewriting once
                // the file behind it has been reached successfully.
                if load(from: url, into: controller, rememberingBookmark: isStale) {
                    return true
                }
            } catch {
                AppLog.vocabulary.error(
                    "Bookmark resolution failed, falling back to the stored path: \(error.localizedDescription, privacy: .public)"
                )
            }
        }

        guard let path = AppSettings.shared.lastVocabularyPath else {
            return false
        }

        return load(
            from: URL(fileURLWithPath: path),
            into: controller,
            rememberingBookmark: false
        )
    }

    func stopAccessing() {
        securityScopedURL?.stopAccessingSecurityScopedResource()
        securityScopedURL = nil
    }

    /// The single security-scope policy for every way a vocabulary is opened.
    ///
    /// `startAccessingSecurityScopedResource()` returning `false` means the URL
    /// carries no scope to start — which is the normal case for a URL handed
    /// over by `NSOpenPanel` — not that access was denied. Treating it as a
    /// failure would refuse perfectly readable files, so the result is only used
    /// to decide whether a matching stop is owed later.
    private func load(
        from url: URL,
        into controller: VocabularyController,
        rememberingBookmark shouldRememberBookmark: Bool
    ) -> Bool {
        let startedSecurityScope = url.startAccessingSecurityScopedResource()

        guard controller.load(from: url) else {
            if startedSecurityScope {
                url.stopAccessingSecurityScopedResource()
            }

            AppLog.vocabulary.error(
                "No usable entries in vocabulary file: \(url.lastPathComponent, privacy: .public)"
            )
            return false
        }

        // Release the previously held scope only after the new one has been
        // taken, so reopening the same file cannot leave an unbalanced start.
        securityScopedURL?.stopAccessingSecurityScopedResource()
        securityScopedURL = startedSecurityScope ? url : nil

        if shouldRememberBookmark {
            saveBookmark(for: url)
        }

        return true
    }

    private func saveBookmark(for url: URL) {
        AppSettings.shared.lastVocabularyPath = url.path

        do {
            let bookmarkData = try url.bookmarkData(
                options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess]
            )
            AppSettings.shared.lastVocabularyBookmark = bookmarkData
        } catch {
            // The file is open and usable; only reopening it automatically on the
            // next launch is lost, so this is logged rather than surfaced.
            AppLog.vocabulary.error(
                "Could not store a security-scoped bookmark: \(error.localizedDescription, privacy: .public)"
            )
        }
    }
}
