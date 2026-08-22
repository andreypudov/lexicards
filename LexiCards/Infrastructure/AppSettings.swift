import Foundation

final class AppSettings {
    static let shared = AppSettings()

    /// The backing store, injectable so tests can point at a throwaway suite.
    ///
    /// The unit tests run with the app itself as their host, which means
    /// `defaults` is the user's real preferences. Without this seam
    /// a test that changes a font permanently changes the installed app's font.
    var defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    private enum Keys {
        static let wordInterval = "wordInterval"
        static let pronunciationEnabled = "pronunciationEnabled"
        static let emptyVocabularyText = "emptyVocabularyText"
        static let defaultLanguageCode = "defaultLanguageCode"
        static let lastVocabularyBookmark = "lastVocabularyBookmark"
        static let lastVocabularyPath = "lastVocabularyPath"
        static let cardWindowOriginX = "cardWindowOriginX"
        static let cardWindowOriginY = "cardWindowOriginY"
        static let cardWindowWidth = "cardWindowWidth"
        static let cardWindowHeight = "cardWindowHeight"
        static let cardVisible = "cardVisible"
        static let wordFontName = "wordFontName"
        static let wordFontSize = "wordFontSize"
        static let translationFontName = "translationFontName"
        static let translationFontSize = "translationFontSize"
        static let voiceIdentifier = "voiceIdentifier"
        static let userVocabularyBookmarks = "userVocabularyBookmarks"
        static let selectedVocabularyIdentifier = "selectedVocabularyIdentifier"
    }

    private enum Defaults {
        static let wordInterval: TimeInterval = 8
        static let emptyVocabularyText = "LexiCards: Hello!"
        static let defaultLanguageCode = "en-US"
        static let cardVisible = true
        static let wordFontSize: Double = 21
        static let translationFontSize: Double = 16
    }

    var wordInterval: TimeInterval {
        get {
            let stored = defaults.double(forKey: Keys.wordInterval)
            return stored > 0 ? stored : Defaults.wordInterval
        }
        set {
            defaults.set(newValue, forKey: Keys.wordInterval)
        }
    }

    var pronunciationEnabled: Bool {
        get {
            defaults.bool(forKey: Keys.pronunciationEnabled)
        }
        set {
            defaults.set(newValue, forKey: Keys.pronunciationEnabled)
        }
    }

    var emptyVocabularyText: String {
        get {
            let stored = defaults.string(forKey: Keys.emptyVocabularyText)
            if let stored, !stored.isEmpty {
                return stored
            }

            return Defaults.emptyVocabularyText
        }
        set {
            defaults.set(newValue, forKey: Keys.emptyVocabularyText)
        }
    }

    var defaultLanguageCode: String {
        get {
            let stored = defaults.string(forKey: Keys.defaultLanguageCode)
            if let stored, !stored.isEmpty {
                return stored
            }

            return Defaults.defaultLanguageCode
        }
        set {
            defaults.set(newValue, forKey: Keys.defaultLanguageCode)
        }
    }

    var lastVocabularyBookmark: Data? {
        get {
            defaults.data(forKey: Keys.lastVocabularyBookmark)
        }
        set {
            defaults.set(newValue, forKey: Keys.lastVocabularyBookmark)
        }
    }

    var lastVocabularyPath: String? {
        get {
            defaults.string(forKey: Keys.lastVocabularyPath)
        }
        set {
            defaults.set(newValue, forKey: Keys.lastVocabularyPath)
        }
    }

    /// Card visibility is remembered alongside the card's geometry, so hiding it
    /// survives a relaunch the way its position and size already did.
    var cardVisible: Bool {
        get {
            guard defaults.object(forKey: Keys.cardVisible) != nil else {
                return Defaults.cardVisible
            }

            return defaults.bool(forKey: Keys.cardVisible)
        }
        set {
            defaults.set(newValue, forKey: Keys.cardVisible)
        }
    }

    /// `nil` means the system font, which is what the card used before fonts
    /// were configurable; a name selects an installed family.
    var wordFontName: String? {
        get { defaults.string(forKey: Keys.wordFontName) }
        set { defaults.set(newValue, forKey: Keys.wordFontName) }
    }

    var wordFontSize: Double {
        get {
            let stored = defaults.double(forKey: Keys.wordFontSize)
            return stored > 0 ? stored : Defaults.wordFontSize
        }
        set { defaults.set(newValue, forKey: Keys.wordFontSize) }
    }

    var translationFontName: String? {
        get { defaults.string(forKey: Keys.translationFontName) }
        set { defaults.set(newValue, forKey: Keys.translationFontName) }
    }

    var translationFontSize: Double {
        get {
            let stored = defaults.double(forKey: Keys.translationFontSize)
            return stored > 0 ? stored : Defaults.translationFontSize
        }
        set { defaults.set(newValue, forKey: Keys.translationFontSize) }
    }

    /// `nil` keeps the automatic behaviour: a voice chosen from the language
    /// detected in the vocabulary itself.
    var voiceIdentifier: String? {
        get { defaults.string(forKey: Keys.voiceIdentifier) }
        set { defaults.set(newValue, forKey: Keys.voiceIdentifier) }
    }

    /// Security-scoped bookmarks for every CSV the user has added, so the
    /// settings list survives relaunches and sandbox restrictions.
    var userVocabularyBookmarks: [Data] {
        get { defaults.array(forKey: Keys.userVocabularyBookmarks) as? [Data] ?? [] }
        set { defaults.set(newValue, forKey: Keys.userVocabularyBookmarks) }
    }

    var selectedVocabularyIdentifier: String? {
        get { defaults.string(forKey: Keys.selectedVocabularyIdentifier) }
        set { defaults.set(newValue, forKey: Keys.selectedVocabularyIdentifier) }
    }

    var cardWindowOrigin: CGPoint? {
        get {
            guard
                let x = defaults.object(forKey: Keys.cardWindowOriginX) as? NSNumber,
                let y = defaults.object(forKey: Keys.cardWindowOriginY) as? NSNumber
            else {
                return nil
            }

            return CGPoint(x: x.doubleValue, y: y.doubleValue)
        }
        set {
            defaults.set(newValue?.x, forKey: Keys.cardWindowOriginX)
            defaults.set(newValue?.y, forKey: Keys.cardWindowOriginY)
        }
    }

    var cardWindowSize: CGSize? {
        get {
            guard
                let width = defaults.object(forKey: Keys.cardWindowWidth) as? NSNumber,
                let height = defaults.object(forKey: Keys.cardWindowHeight)
                    as? NSNumber
            else {
                return nil
            }

            return CGSize(width: width.doubleValue, height: height.doubleValue)
        }
        set {
            defaults.set(newValue?.width, forKey: Keys.cardWindowWidth)
            defaults.set(newValue?.height, forKey: Keys.cardWindowHeight)
        }
    }
}
