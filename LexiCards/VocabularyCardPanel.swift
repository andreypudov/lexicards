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

final class VocabularyCardPanel: NSPanel {
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
    }

    func update(entry: VocabularyEntry?) {
        hostingView.rootView = VocabularyCardView(
            entry: entry,
            emptyText: AppSettings.shared.emptyVocabularyText
        )
    }

    func moveToLowerRightCorner() {
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

    override var canBecomeKey: Bool {
        false
    }

    override var canBecomeMain: Bool {
        false
    }
}
