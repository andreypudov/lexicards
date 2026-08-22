import Foundation

final class VocabularyController {
    private var entries: [VocabularyEntry] = []
    private var index = -1

    var allEntries: [VocabularyEntry] {
        entries
    }

    var currentEntry: VocabularyEntry? {
        guard index >= 0, index < entries.count else { return nil }
        return entries[index]
    }

    /// Selects a new entry at random and returns it.
    ///
    /// The entry currently on screen is excluded, so a rotation never appears to
    /// stall; with a single entry there is nothing else to choose and it stays.
    @discardableResult
    func nextRandom() -> VocabularyEntry? {
        guard !entries.isEmpty else { return nil }

        if entries.count == 1 {
            index = 0
            return entries[0]
        }

        var nextIndex: Int
        repeat {
            nextIndex = Int.random(in: 0..<entries.count)
        } while nextIndex == index

        index = nextIndex
        return entries[index]
    }

    @discardableResult
    func load(from url: URL) -> Bool {
        let loaded = VocabularyLoader.load(from: url)
        guard !loaded.isEmpty else { return false }
        entries = loaded
        index = -1
        return true
    }
}
