import AppKit
import SwiftUI

final class MovableHostingView: NSHostingView<VocabularyCardView> {
    private var dragStart: NSPoint?
    private var windowStartOrigin: NSPoint?

    override func mouseDown(with event: NSEvent) {
        guard let window else {
            return
        }

        dragStart =
            window.convertToScreen(
                NSRect(origin: event.locationInWindow, size: .zero)
            ).origin
        windowStartOrigin = window.frame.origin
    }

    override func mouseDragged(with event: NSEvent) {
        guard let window, let dragStart else {
            return
        }

        let currentLocation = window.convertToScreen(
            NSRect(origin: event.locationInWindow, size: .zero)
        ).origin
        let deltaX = currentLocation.x - dragStart.x
        let deltaY = currentLocation.y - dragStart.y

        guard let windowStartOrigin else {
            return
        }

        window.setFrameOrigin(
            NSPoint(
                x: windowStartOrigin.x + deltaX,
                y: windowStartOrigin.y + deltaY
            )
        )
    }

    override func mouseUp(with _: NSEvent) {
        dragStart = nil
        windowStartOrigin = nil
    }
}

final class VocabularyCardPanel: NSPanel, NSWindowDelegate {
    private var hostingView: MovableHostingView
    private var currentEntry: VocabularyEntry?
    private var wordFont: CardFont
    private var translationFont: CardFont

    init() {
        let savedSize = AppSettings.shared.cardWindowSize ?? CGSize(width: 320, height: 112)
        let size = CGSize(width: max(240, savedSize.width), height: savedSize.height)
        let initialView = VocabularyCardView(
            entry: nil,
            emptyText: AppSettings.shared.emptyVocabularyText,
            wordFont: .word(from: AppSettings.shared),
            translationFont: .translation(from: AppSettings.shared)
        )
        hostingView = MovableHostingView(rootView: initialView)
        wordFont = .word(from: AppSettings.shared)
        translationFont = .translation(from: AppSettings.shared)

        super.init(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        contentView = hostingView
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        level = .floating
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        isMovableByWindowBackground = false
        delegate = self
    }

    func update(entry: VocabularyEntry?) {
        currentEntry = entry
        refresh()
    }

    /// Applies new fonts and redraws immediately, so a change made in settings
    /// shows on the card that is already on screen rather than at the next
    /// rotation. The fonts are held here rather than re-read from settings on
    /// every redraw, which keeps what the card is showing explicit.
    func apply(wordFont: CardFont, translationFont: CardFont) {
        self.wordFont = wordFont
        self.translationFont = translationFont
        refresh()
    }

    func refresh() {
        hostingView.rootView = VocabularyCardView(
            entry: currentEntry,
            emptyText: AppSettings.shared.emptyVocabularyText,
            wordFont: wordFont,
            translationFont: translationFont
        )

        sizeToFitContent()
    }

    /// Height follows the content so the card's padding reads evenly.
    ///
    /// The card used to keep a fixed height and centre its text in it, which
    /// spent the leftover space above and below — so the 18pt inset looked
    /// larger vertically than horizontally. Width stays as the user left it;
    /// only the height is derived.
    ///
    /// The frame is set directly rather than through `setContentSize`, which
    /// pins the top-left: that would walk the card up the screen as it shrank.
    /// Holding the origin — the bottom-left — keeps it resting in the corner it
    /// was placed in, and lets a taller entry grow upward.
    private func sizeToFitContent() {
        hostingView.layoutSubtreeIfNeeded()

        let fittingHeight = hostingView.fittingSize.height
        guard fittingHeight > 0, abs(fittingHeight - frame.height) > 0.5 else {
            return
        }

        setFrame(
            NSRect(
                origin: frame.origin,
                size: NSSize(width: frame.width, height: fittingHeight)
            ),
            display: true
        )
    }

    func restorePositionOrMoveToLowerRightCorner() {
        if let origin = AppSettings.shared.cardWindowOrigin, isVisible(on: origin) {
            setFrameOrigin(origin)
            return
        }

        moveToLowerRightCorner()
    }

    private func moveToLowerRightCorner() {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else {
            return
        }

        let visibleFrame = screen.visibleFrame
        let origin = NSPoint(
            x: visibleFrame.maxX - frame.width - 18,
            y: visibleFrame.minY + 18
        )
        setFrameOrigin(origin)
    }

    private func isVisible(on origin: CGPoint) -> Bool {
        let frame = NSRect(origin: origin, size: frame.size)
        return NSScreen.screens.contains { $0.visibleFrame.intersects(frame) }
    }

    func windowDidMove(_: Notification) {
        AppSettings.shared.cardWindowOrigin = frame.origin
    }

    func windowDidResize(_: Notification) {
        AppSettings.shared.cardWindowSize = frame.size
    }

    override var canBecomeKey: Bool {
        false
    }

    override var canBecomeMain: Bool {
        false
    }
}
