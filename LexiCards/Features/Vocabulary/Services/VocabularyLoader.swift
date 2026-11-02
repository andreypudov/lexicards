import Foundation

enum VocabularyLoader {
    static func load(from url: URL) -> [VocabularyEntry] {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else {
            return []
        }

        return
            content
            .components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .compactMap { parse(line: $0) }
    }

    private static func parse(line: String) -> VocabularyEntry? {
        let columns = line.components(separatedBy: ",")
        guard columns.count >= 2 else { return nil }

        let original = columns[0].trimmingCharacters(in: .whitespaces)
        let translation = columns[1].trimmingCharacters(in: .whitespaces)
        // One side missing would be a blank card, or a recall with nothing to
        // ask or to reveal.
        guard !original.isEmpty, !translation.isEmpty else { return nil }

        return VocabularyEntry(original: original, translation: translation)
    }
}
