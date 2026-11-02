import Foundation

/// Decides when the floating card steps aside for whatever is underneath it.
///
/// Resting the pointer on the card fades it and lets clicks through. Holding
/// Option brings it back so it can be moved, resized, or clicked. A press that
/// is already under way keeps the state it started in, so a drag that began
/// with Option held survives letting go of the key.
///
/// A recall session never starts fading: the card is being used. A card that
/// was already faded when a session began stays faded until the pointer
/// leaves, so a click meant for the app underneath cannot land on Reveal.
struct CardHoverFade {
    /// How long the pointer has to rest on the card. Passing over it on the way
    /// somewhere else should not make it flicker.
    static let delay: TimeInterval = 0.15
    /// Opacity of a faded card, relative to its normal opacity.
    static let fadedOpacity: CGFloat = 0.15
    /// How far outside the card the pointer has to go before a faded card
    /// returns, so resting on the edge does not flicker either.
    static let exitMargin: CGFloat = 4

    private(set) var isFaded = false
    private var hoverBegan: Date?

    /// Takes one sample of the pointer and returns whether the card should now
    /// be faded.
    mutating func update(
        pointerInside: Bool,
        optionHeld: Bool,
        buttonPressed: Bool,
        isEnabled: Bool,
        isRecalling: Bool,
        now: Date
    ) -> Bool {
        guard isEnabled, !optionHeld else {
            reset()
            return false
        }

        if buttonPressed {
            return isFaded
        }

        guard pointerInside else {
            reset()
            return false
        }

        if isFaded {
            return true
        }

        guard !isRecalling else {
            hoverBegan = nil
            return false
        }

        let began = hoverBegan ?? now
        hoverBegan = began
        isFaded = now.timeIntervalSince(began) >= Self.delay
        return isFaded
    }

    mutating func reset() {
        isFaded = false
        hoverBegan = nil
    }
}
