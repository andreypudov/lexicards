import CoreGraphics
import Foundation

/// How the card moves between the learning face and a recall session.
///
/// The window's width and height change over `duration`. The face stays on the
/// edges that are not moving, so the card grows out of the corner it already
/// occupies instead of sliding to the new frame.
enum CardMotion {
    static let duration: TimeInterval = 0.35

    /// The frame at `progress` (0 at the start, 1 at the end) between two
    /// window frames. Progress is eased so the resize starts and settles softly.
    static func frame(from start: CGRect, to end: CGRect, at progress: Double) -> CGRect {
        let t = easeInOut(progress)
        return CGRect(
            x: start.origin.x + (end.origin.x - start.origin.x) * t,
            y: start.origin.y + (end.origin.y - start.origin.y) * t,
            width: start.width + (end.width - start.width) * t,
            height: start.height + (end.height - start.height) * t
        )
    }

    private static func easeInOut(_ progress: Double) -> Double {
        let t = min(1, max(0, progress))
        if t < 0.5 {
            return 2 * t * t
        }
        return 1 - pow(-2 * t + 2, 2) / 2
    }
}
