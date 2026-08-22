import Foundation

/// A vocabulary entry paired with a stable identity for the settings table.
///
/// `VocabularyEntry` is deliberately a plain value — two identical pairs in one
/// file are equal and should stay that way — so the identity a `Table` needs
/// lives here, in the position the entry was loaded from.
struct VocabularyEntryRow: Identifiable {
    let id: Int
    let entry: VocabularyEntry

    var original: String { entry.original }
    var translation: String { entry.translation }

    static func rows(from entries: [VocabularyEntry]) -> [VocabularyEntryRow] {
        entries.enumerated().map { VocabularyEntryRow(id: $0.offset, entry: $0.element) }
    }
}
