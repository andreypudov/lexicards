import AppKit
import SwiftUI

final class MovableHostingView<Content: View>: NSHostingView<Content> {
    private var dragStart: NSPoint?
    private var windowStartOrigin: NSPoint?

    override func mouseDown(with event: NSEvent) {
        guard let window else {
            return
        }

        dragStart = window.convertToScreen(
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

    override func mouseUp(with event: NSEvent) {
        dragStart = nil
        windowStartOrigin = nil
    }
}

final class VocabularyCardPanel: NSPanel, NSWindowDelegate {
    private var hostingView: MovableHostingView<VocabularyCardView>

    init() {
        let savedSize = AppSettings.shared.cardWindowSize ?? CGSize(width: 320, height: 112)
        let size = CGSize(width: max(240, savedSize.width), height: savedSize.height)
        let initialView = VocabularyCardView(
            entry: nil,
            emptyText: AppSettings.shared.emptyVocabularyText,
            animateChanges: false
        )
        hostingView = MovableHostingView(rootView: initialView)

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

    func update(entry: VocabularyEntry?, animated: Bool = true) {
        let view = VocabularyCardView(
            entry: entry,
            emptyText: AppSettings.shared.emptyVocabularyText,
            animateChanges: animated
        )

        if animated {
            hostingView.rootView = view
        } else {
            hostingView = MovableHostingView(rootView: view)
            contentView = hostingView
        }
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

    func windowDidMove(_ notification: Notification) {
        AppSettings.shared.cardWindowOrigin = frame.origin
    }

    func windowDidResize(_ notification: Notification) {
        AppSettings.shared.cardWindowSize = frame.size
    }

    override var canBecomeKey: Bool {
        false
    }

    override var canBecomeMain: Bool {
        false
    }
}
