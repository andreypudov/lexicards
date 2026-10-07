import AppKit
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

    /// The AppKit font used to measure a line before the card is resized.
    ///
    /// A missing family is the rounded system font, matching `resolved`.
    var nsFont: NSFont {
        if let familyName, !familyName.isEmpty, let font = NSFont(name: familyName, size: size) {
            return font
        }

        let system = NSFont.systemFont(ofSize: size, weight: nsWeight)
        guard let rounded = system.fontDescriptor.withDesign(.rounded) else {
            return system
        }
        return NSFont(descriptor: rounded, size: size) ?? system
    }

    /// Height of one line, used so both recall lines occupy the same box.
    var lineHeight: CGFloat {
        let font = nsFont
        return ceil(font.ascender - font.descender + font.leading)
    }

    private var nsWeight: NSFont.Weight {
        switch weight {
        case .ultraLight: .ultraLight
        case .thin: .thin
        case .light: .light
        case .regular: .regular
        case .medium: .medium
        case .semibold: .semibold
        case .bold: .bold
        case .heavy: .heavy
        case .black: .black
        default: .regular
        }
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
