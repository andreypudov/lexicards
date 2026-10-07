import AppKit
import SwiftUI

final class MovableHostingView: NSHostingView<VocabularyCardView> {
    /// Wide enough to grab, narrow enough that dragging the card still moves it.
    private static let resizeMargin: CGFloat = 10

    private var dragStart: NSPoint?
    private var windowStartOrigin: NSPoint?
    private var windowStartFrame: NSRect?
    private var resizeEdge: VocabularyCardPanel.HorizontalEdge?
    private var trackingArea: NSTrackingArea?
    private var isShowingResizeCursor = false

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        if let trackingArea {
            removeTrackingArea(trackingArea)
        }

        // The panel can never become key, so cursor rects never take effect.
        // A tracking area still reports movement while another app is active.
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseMoved, .mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseMoved(with event: NSEvent) {
        updateCursor(at: convert(event.locationInWindow, from: nil))
    }

    override func mouseEntered(with event: NSEvent) {
        updateCursor(at: convert(event.locationInWindow, from: nil))
    }

    override func mouseExited(with _: NSEvent) {
        guard resizeEdge == nil else {
            return
        }

        hideResizeCursor()
    }

    override func mouseDown(with event: NSEvent) {
        guard let window else {
            return
        }

        let location = convert(event.locationInWindow, from: nil)
        resizeEdge = horizontalEdge(at: location)
        dragStart =
            window.convertToScreen(
                NSRect(origin: event.locationInWindow, size: .zero)
            ).origin
        windowStartOrigin = window.frame.origin
        windowStartFrame = window.frame
        updateCursor(at: location)
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

        if let resizeEdge, let panel = window as? VocabularyCardPanel, let windowStartFrame {
            panel.resizeWidth(by: deltaX, from: windowStartFrame, pinning: resizeEdge)
            return
        }

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

    override func mouseUp(with event: NSEvent) {
        dragStart = nil
        windowStartOrigin = nil
        windowStartFrame = nil
        resizeEdge = nil
        updateCursor(at: convert(event.locationInWindow, from: nil))
    }

    /// The sides change the width. Everywhere else still drags the card around,
    /// because the height is derived from the text and is not itself a handle.
    func horizontalEdge(at point: NSPoint) -> VocabularyCardPanel.HorizontalEdge? {
        if point.x <= Self.resizeMargin {
            return .leading
        }

        if point.x >= bounds.width - Self.resizeMargin {
            return .trailing
        }

        return nil
    }

    private func updateCursor(at point: NSPoint) {
        let onEdge = resizeEdge != nil || horizontalEdge(at: point) != nil
        if onEdge {
            showResizeCursor()
        } else {
            hideResizeCursor()
        }
    }

    private func showResizeCursor() {
        guard !isShowingResizeCursor else {
            return
        }

        NSCursor.resizeLeftRight.push()
        isShowingResizeCursor = true
    }

    private func hideResizeCursor() {
        guard isShowingResizeCursor else {
            return
        }

        NSCursor.pop()
        isShowingResizeCursor = false
    }
}

final class VocabularyCardPanel: NSPanel, NSWindowDelegate {
    enum HorizontalEdge {
        case leading
        case trailing
    }

    static let minimumWidth: CGFloat = 240
    static let maximumWidth: CGFloat = 800

    private var hostingView: MovableHostingView
    private var currentEntry: VocabularyEntry?
    private var wordFont: CardFont
    private var translationFont: CardFont

    init() {
        let savedSize = AppSettings.shared.cardWindowSize ?? CGSize(width: 320, height: 112)
        let width = min(Self.maximumWidth, max(Self.minimumWidth, savedSize.width))
        let size = CGSize(width: width, height: savedSize.height)
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

    /// Changes the width while holding the opposite edge still, then refits the
    /// height. `deltaX` is measured from the frame the drag started on, so the
    /// width does not drift as the pointer moves.
    ///
    /// The bottom edge stays put for the same reason a content change does:
    /// the card sits in a corner, and growing it should not shove it off that
    /// corner. A taller wrap grows upward.
    func resizeWidth(by deltaX: CGFloat, from startFrame: NSRect, pinning edge: HorizontalEdge) {
        let proposed =
            switch edge {
            case .trailing: startFrame.width + deltaX
            case .leading: startFrame.width - deltaX
            }
        let width = min(Self.maximumWidth, max(Self.minimumWidth, proposed))
        let originX =
            switch edge {
            case .trailing: startFrame.origin.x
            case .leading: startFrame.origin.x + startFrame.width - width
            }

        setFrame(
            NSRect(x: originX, y: startFrame.origin.y, width: width, height: frame.height),
            display: true
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
