import AppKit
import Foundation

final class VocabularyFileAccess {
    private var securityScopedURL: URL?

    func load(from url: URL, into controller: VocabularyController) -> Bool {
        guard url.startAccessingSecurityScopedResource() else {
            return false
        }

        guard controller.load(from: url) else {
            url.stopAccessingSecurityScopedResource()
            return false
        }

        securityScopedURL?.stopAccessingSecurityScopedResource()
        securityScopedURL = url
        saveBookmark(for: url)
        return true
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

                if loadRestoredVocabulary(from: url, into: controller) {
                    if isStale {
                        saveBookmark(for: url)
                    }
                    return true
                }
            } catch {
                // Fall back to the stored path when bookmark resolution fails.
            }
        }

        guard
            let path = AppSettings.shared.lastVocabularyPath,
            loadRestoredVocabulary(
                from: URL(fileURLWithPath: path),
                into: controller
            )
        else {
            return false
        }

        return true
    }

    func stopAccessing() {
        securityScopedURL?.stopAccessingSecurityScopedResource()
        securityScopedURL = nil
    }

    private func loadRestoredVocabulary(
        from url: URL,
        into controller: VocabularyController
    ) -> Bool {
        let startedSecurityScope = url.startAccessingSecurityScopedResource()

        guard controller.load(from: url) else {
            if startedSecurityScope {
                url.stopAccessingSecurityScopedResource()
            }
            return false
        }

        if startedSecurityScope {
            securityScopedURL = url
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
            NSSound.beep()
        }
    }
}
