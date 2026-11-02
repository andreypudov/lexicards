import AppKit
import SwiftUI

/// The shared layout of a floating card. The window gives it its corners.
enum CardFace {
    /// Inset of a card face. Width measurement adds it on both sides so a line
    /// that fits the text also fits inside the padding.
    static let inset: CGFloat = 18
}

/// The system's HUD material, blurring whatever is behind the window.
///
/// It stays active because the card is rarely in the key window, and an inactive
/// material turns flat. Clicks pass through to the hosting view, which is what
/// drags the card and resizes it.
final class CardMaterialView: NSVisualEffectView {
    override init(frame: NSRect) {
        super.init(frame: frame)
        material = .hudWindow
        blendingMode = .behindWindow
        state = .active
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }
}

private struct CardMaterial: NSViewRepresentable {
    func makeNSView(context: Context) -> CardMaterialView {
        CardMaterialView()
    }

    func updateNSView(_ view: CardMaterialView, context: Context) {}
}

extension View {
    func cardFace() -> some View {
        background(CardMaterial())
    }
}
