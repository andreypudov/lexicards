import Foundation

class AppSettings {
    static let shared = AppSettings()

    private enum Keys {
        static let wordInterval = "wordInterval"
        static let emptyVocabularyText = "emptyVocabularyText"
        static let defaultLanguageCode = "defaultLanguageCode"
    }

    private enum Defaults {
        static let wordInterval: TimeInterval = 8
        static let emptyVocabularyText = "LexiCards: Hello!"
        static let defaultLanguageCode = "en-US"
    }

    var wordInterval: TimeInterval {
        get {
            let stored = UserDefaults.standard.double(forKey: Keys.wordInterval)
            return stored > 0 ? stored : Defaults.wordInterval
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.wordInterval)
        }
    }

    var emptyVocabularyText: String {
        get {
            let stored = UserDefaults.standard.string(forKey: Keys.emptyVocabularyText)
            if let stored, !stored.isEmpty {
                return stored
            }

            return Defaults.emptyVocabularyText
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.emptyVocabularyText)
        }
    }

    var defaultLanguageCode: String {
        get {
            let stored = UserDefaults.standard.string(forKey: Keys.defaultLanguageCode)
            if let stored, !stored.isEmpty {
                return stored
            }

            return Defaults.defaultLanguageCode
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.defaultLanguageCode)
        }
    }
}
