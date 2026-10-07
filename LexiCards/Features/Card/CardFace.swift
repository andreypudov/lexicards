import SwiftUI

/// The shared outline of a floating card.
enum CardFace {
    /// Inset of a card face. Width measurement adds it on both sides so a line
    /// that fits the text also fits inside the padding.
    static let inset: CGFloat = 18
    static let cornerRadius: CGFloat = 18
}

extension View {
    func cardFace() -> some View {
        background(
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: CardFace.cornerRadius)
        )
        .overlay {
            RoundedRectangle(cornerRadius: CardFace.cornerRadius)
                .strokeBorder(.white.opacity(0.2))
        }
    }
}
