import Foundation

/// One prompt in a recall session.
///
/// The side shown first is chosen per card, so a session mixes "what is the
/// translation?" with "what was the original?".
struct RecallPrompt: Equatable, Identifiable {
    let id: Int
    let entry: VocabularyEntry
    let showsOriginalFirst: Bool

    var prompt: String {
        showsOriginalFirst ? entry.original : entry.translation
    }

    var answer: String {
        showsOriginalFirst ? entry.translation : entry.original
    }
}

/// A short run of prompts. The sample is random on purpose: scheduling what is
/// due belongs to a later learning engine, and this is the seam it replaces.
struct RecallSession: Equatable {
    static let length = 10

    var prompts: [RecallPrompt]
    var index: Int
    var isRevealed: Bool

    var current: RecallPrompt? {
        prompts.indices.contains(index) ? prompts[index] : nil
    }

    /// Draws up to `length` entries without repeating a row. Fewer entries than
    /// that produce a shorter session rather than repeated cards.
    static func start(
        entries: [VocabularyEntry],
        length: Int = RecallSession.length,
        showsOriginalFirst: (Int) -> Bool = { _ in Bool.random() }
    ) -> RecallSession? {
        guard !entries.isEmpty, length > 0 else {
            return nil
        }

        let chosen = entries.indices.shuffled().prefix(min(length, entries.count))
        let prompts = chosen.enumerated().map { offset, entryIndex in
            RecallPrompt(
                id: offset,
                entry: entries[entryIndex],
                showsOriginalFirst: showsOriginalFirst(offset)
            )
        }

        return RecallSession(prompts: prompts, index: 0, isRevealed: false)
    }

    mutating func reveal() {
        guard current != nil else {
            return
        }

        isRevealed = true
    }

    mutating func advance() {
        guard current != nil else {
            return
        }

        index += 1
        isRevealed = false
    }
}
