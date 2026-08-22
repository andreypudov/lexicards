import SwiftUI

/// A font choice for one line of the card.
///
/// A `nil` family means the system font, which is what the card used before
/// fonts were configurable — so the default stays exactly what it was.
struct CardFont: Equatable {
    var familyName: String?
    var size: Double
    var weight: Font.Weight

    var resolved: Font {
        guard let familyName, !familyName.isEmpty else {
            return .system(size: size, weight: weight, design: .rounded)
        }

        return .custom(familyName, size: size)
    }

    static func word(from settings: AppSettings) -> CardFont {
        CardFont(
            familyName: settings.wordFontName,
            size: settings.wordFontSize,
            weight: .semibold
        )
    }

    static func translation(from settings: AppSettings) -> CardFont {
        CardFont(
            familyName: settings.translationFontName,
            size: settings.translationFontSize,
            weight: .regular
        )
    }
}
