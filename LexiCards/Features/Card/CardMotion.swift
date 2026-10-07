import Foundation

/// How long the card takes to change size.
///
/// Entering and leaving a recall session animates the window's width and
/// height. During a session the card keeps that size.
enum CardMotion {
    static let duration: TimeInterval = 0.35
}
