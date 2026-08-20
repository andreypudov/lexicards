struct VocabularyEntry {
    let original: String
    let translation: String

    var displayText: String {
        "\(original) — \(translation)"
    }
}

