import AppKit
import SwiftUI

final class MovableHostingView<Content: View>: NSHostingView<Content> {
    private var dragStart: NSPoint?

    override func mouseDown(with event: NSEvent) {
        dragStart = event.locationInWindow
    }

    override func mouseDragged(with event: NSEvent) {
        guard let window, let dragStart else {
            return
        }

        let currentLocation = event.locationInWindow
        let delta = NSPoint(
            x: currentLocation.x - dragStart.x,
            y: currentLocation.y - dragStart.y
        )
        window.setFrameOrigin(
            NSPoint(
                x: window.frame.minX + delta.x,
                y: window.frame.minY + delta.y
            )
        )
    }

    override func mouseUp(with event: NSEvent) {
        dragStart = nil
    }
}

final class VocabularyCardPanel: NSPanel, NSWindowDelegate {
    private let hostingView: MovableHostingView<VocabularyCardView>

    init() {
        let initialView = VocabularyCardView(
            entry: nil,
            emptyText: AppSettings.shared.emptyVocabularyText
        )
        hostingView = MovableHostingView(rootView: initialView)

        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 112),
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
        isMovableByWindowBackground = true
        delegate = self
    }

    func update(entry: VocabularyEntry?) {
        hostingView.rootView = VocabularyCardView(
            entry: entry,
            emptyText: AppSettings.shared.emptyVocabularyText
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

    func windowDidMove(_ notification: Notification) {
        AppSettings.shared.cardWindowOrigin = frame.origin
    }

    override var canBecomeKey: Bool {
        false
    }

    override var canBecomeMain: Bool {
        false
    }
}
