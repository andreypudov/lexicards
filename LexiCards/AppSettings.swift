import Foundation

class AppSettings {
    static let shared = AppSettings()

    private enum Keys {
        static let wordInterval = "wordInterval"
        static let emptyVocabularyText = "emptyVocabularyText"
        static let defaultLanguageCode = "defaultLanguageCode"
        static let lastVocabularyBookmark = "lastVocabularyBookmark"
        static let cardWindowOriginX = "cardWindowOriginX"
        static let cardWindowOriginY = "cardWindowOriginY"
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

    var lastVocabularyBookmark: Data? {
        get {
            UserDefaults.standard.data(forKey: Keys.lastVocabularyBookmark)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.lastVocabularyBookmark)
        }
    }

    var cardWindowOrigin: CGPoint? {
        get {
            guard
                let x = UserDefaults.standard.object(forKey: Keys.cardWindowOriginX) as? NSNumber,
                let y = UserDefaults.standard.object(forKey: Keys.cardWindowOriginY) as? NSNumber
            else {
                return nil
            }

            return CGPoint(x: x.doubleValue, y: y.doubleValue)
        }
        set {
            UserDefaults.standard.set(newValue?.x, forKey: Keys.cardWindowOriginX)
            UserDefaults.standard.set(newValue?.y, forKey: Keys.cardWindowOriginY)
        }
    }
}
