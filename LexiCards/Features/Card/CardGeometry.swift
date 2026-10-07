import CoreGraphics

/// Which horizontal edge stays put when the card changes height.
///
/// A card near the top of the screen grows downward, so the growth moves into
/// the empty space below it. A card near the bottom grows upward.
enum CardHeightAnchor: Equatable {
    case top
    case bottom

    static func forCard(midY: CGFloat, screenMidY: CGFloat) -> CardHeightAnchor {
        midY >= screenMidY ? .top : .bottom
    }
}

/// Which vertical edge stays put when the card changes width.
///
/// A card near the left of the screen grows rightward. A card near the right
/// grows leftward.
enum CardWidthAnchor: Equatable {
    case leading
    case trailing

    static func forCard(midX: CGFloat, screenMidX: CGFloat) -> CardWidthAnchor {
        midX >= screenMidX ? .trailing : .leading
    }
}

enum CardGeometry {
    /// Returns `current` with a new height, pinning `anchor`, then shifted back
    /// inside `visible` when the growth would otherwise leave the screen.
    static func frame(
        bySettingHeight height: CGFloat,
        of current: CGRect,
        pinning anchor: CardHeightAnchor,
        within visible: CGRect?
    ) -> CGRect {
        frame(
            bySettingSize: CGSize(width: current.width, height: height),
            of: current,
            pinningHeight: anchor,
            pinningWidth: .leading,
            within: visible
        )
    }

    /// Returns `current` with a new size. The pinned edges stay where they are,
    /// and the result is shifted back inside `visible` when it would otherwise
    /// leave the screen.
    static func frame(
        bySettingSize size: CGSize,
        of current: CGRect,
        pinningHeight heightAnchor: CardHeightAnchor,
        pinningWidth widthAnchor: CardWidthAnchor,
        within visible: CGRect?
    ) -> CGRect {
        let width = max(size.width, 1)
        let height = max(size.height, 1)
        let originX: CGFloat =
            switch widthAnchor {
            case .leading: current.origin.x
            case .trailing: current.maxX - width
            }
        let originY: CGFloat =
            switch heightAnchor {
            case .bottom: current.origin.y
            case .top: current.maxY - height
            }
        guard let visible else {
            return CGRect(x: originX, y: originY, width: width, height: height)
        }

        let horizontal = clamped(
            origin: originX,
            length: width,
            visibleOrigin: visible.minX,
            visibleLength: visible.width
        )
        let vertical = clamped(
            origin: originY,
            length: height,
            visibleOrigin: visible.minY,
            visibleLength: visible.height
        )
        return CGRect(
            x: horizontal.origin,
            y: vertical.origin,
            width: horizontal.length,
            height: vertical.length
        )
    }

    /// Shifts one axis back inside the visible range, shrinking it when it
    /// cannot fit.
    private static func clamped(
        origin: CGFloat,
        length: CGFloat,
        visibleOrigin: CGFloat,
        visibleLength: CGFloat
    ) -> (origin: CGFloat, length: CGFloat) {
        if length > visibleLength {
            return (visibleOrigin, visibleLength)
        }

        var origin = origin
        let visibleEnd = visibleOrigin + visibleLength
        if origin + length > visibleEnd {
            origin -= origin + length - visibleEnd
        }
        if origin < visibleOrigin {
            origin += visibleOrigin - origin
        }
        return (origin, length)
    }
}
