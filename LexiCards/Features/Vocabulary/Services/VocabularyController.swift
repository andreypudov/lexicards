import Foundation

class VocabularyController {
    private var entries: [VocabularyEntry] = []
    private var index = -1

    var allEntries: [VocabularyEntry] {
        entries
    }

    var currentEntry: VocabularyEntry? {
        guard index >= 0, index < entries.count else { return nil }
        return entries[index]
    }

    func next() -> String {
        guard !entries.isEmpty else { return AppSettings.shared.emptyVocabularyText }
        index = (index + 1) % entries.count
        return entries[index].displayText
    }

    func nextRandom() -> String {
        guard !entries.isEmpty else { return AppSettings.shared.emptyVocabularyText }

        if entries.count == 1 {
            index = 0
            return entries[0].displayText
        }

        var nextIndex: Int
        repeat {
            nextIndex = Int.random(in: 0 ..< entries.count)
        } while nextIndex == index

        index = nextIndex
        return entries[index].displayText
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
