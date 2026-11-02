import AppKit
import SwiftUI

/// The shared outline of a floating card.
enum CardFace {
    /// Inset of a card face. Width measurement adds it on both sides so a line
    /// that fits the text also fits inside the padding.
    static let inset: CGFloat = 18
    /// macOS gives every titled window the same corner and offers no API that
    /// reports it. This is the continuous radius that matched one on macOS 27,
    /// measured against a real window.
    static let cornerRadius: CGFloat = 16
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
        maskImage = Self.cornerMask
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    /// A resizable rounded rectangle: only the middle of the image stretches, so
    /// the corners keep their shape at any card size. A continuous curve starts
    /// further along the edge than its radius, so the fixed part has to be larger.
    private static var cornerMask: NSImage {
        let radius = CardFace.cornerRadius
        let corner = (radius * 1.6).rounded(.up)
        let side = corner * 2 + 1
        let image = NSImage(size: NSSize(width: side, height: side), flipped: false) { rect in
            guard let context = NSGraphicsContext.current?.cgContext else {
                return false
            }
            let shape = Path(roundedRect: rect, cornerRadius: radius, style: .continuous)
            context.addPath(shape.cgPath)
            context.setFillColor(NSColor.black.cgColor)
            context.fillPath()
            return true
        }
        image.capInsets = NSEdgeInsets(top: corner, left: corner, bottom: corner, right: corner)
        image.resizingMode = .stretch
        return image
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
