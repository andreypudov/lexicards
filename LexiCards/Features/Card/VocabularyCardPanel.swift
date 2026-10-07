import AppKit
import SwiftUI

final class MovableHostingView: NSHostingView<FloatingCardView> {
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

        // The panel does not stay key — a recall click borrows key status and
        // gives it back — so cursor rects never take effect while another app
        // is in front. A tracking area still reports movement.
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

    override func acceptsFirstMouse(for _: NSEvent?) -> Bool {
        true
    }

    override func mouseDown(with event: NSEvent) {
        guard let window else {
            return
        }

        let location = convert(event.locationInWindow, from: nil)
        let edge = horizontalEdge(at: location)

        // Recall buttons have to see the real click. The learning card has
        // nothing to press, so a press there drags the window immediately.
        if edge == nil, (window as? VocabularyCardPanel)?.isRecalling == true {
            super.mouseDown(with: event)
            return
        }

        resizeEdge = edge
        dragStart = screenPoint(of: event, in: window)
        windowStartOrigin = window.frame.origin
        windowStartFrame = window.frame
        updateCursor(at: location)
    }

    private func screenPoint(of event: NSEvent, in window: NSWindow) -> NSPoint {
        window.convertToScreen(NSRect(origin: event.locationInWindow, size: .zero)).origin
    }

    override func mouseDragged(with event: NSEvent) {
        guard let window, let dragStart else {
            return
        }

        let currentLocation = screenPoint(of: event, in: window)
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

    private let model: CardModel
    private var hostingView: MovableHostingView
    private var currentEntry: VocabularyEntry?
    private var wordFont: CardFont
    private var translationFont: CardFont
    private var heightAnchor: CardHeightAnchor = .bottom
    private var widthAnchor: CardWidthAnchor = .trailing
    /// Reading-card frame to return to. Its size is what gets remembered; the
    /// recall card's size lasts only for the session.
    private var learningFrame: NSRect?
    private var saveLearningGeometry = false
    private var ignoreGeometryPersistence = false
    private var lastFrame: NSRect = .zero
    private var cardDragOrigin: NSPoint?

    /// The coordinator restarts the reading rotation when a session ends.
    var onRecallFinished: (() -> Void)?

    var isRecalling: Bool {
        model.isRecalling
    }

    init() {
        let savedSize = AppSettings.shared.cardWindowSize ?? CGSize(width: 320, height: 112)
        let width = min(Self.maximumWidth, max(Self.minimumWidth, savedSize.width))
        let size = CGSize(width: width, height: savedSize.height)
        wordFont = .word(from: AppSettings.shared)
        translationFont = .translation(from: AppSettings.shared)
        let model = CardModel(
            entry: nil,
            emptyText: AppSettings.shared.emptyVocabularyText,
            wordFont: wordFont,
            translationFont: translationFont
        )
        self.model = model
        hostingView = MovableHostingView(rootView: FloatingCardView(model: model))

        super.init(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        contentView = hostingView
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        level = .floating
        hidesOnDeactivate = false
        // A recall button has to accept the click without pulling the app forward
        // over whatever the user was typing in.
        becomesKeyOnlyIfNeeded = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        isMovableByWindowBackground = false
        delegate = self
        lastFrame = frame

        model.onFinished = { [weak self] in
            self?.endRecall(animated: true)
            self?.onRecallFinished?()
        }
        model.onMoveBegan = { [weak self] in
            self?.beginCardDrag()
        }
        model.onMoveChanged = { [weak self] translation in
            self?.updateCardDrag(translation)
        }
        model.onMoveEnded = { [weak self] in
            self?.endCardDrag()
        }
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
        let entryChanged = model.entry != currentEntry
        let appearanceChanged =
            model.emptyText != AppSettings.shared.emptyVocabularyText
            || model.wordFont != wordFont
            || model.translationFont != translationFont
        // A visible card keeps its view when only the word changes, so the text
        // updates in place. Fonts still replace it: publishing into the
        // existing view waits a turn, and a change made while a menu is
        // tracking would miss its repaint until the next rotation.
        let updateInPlace = isVisible && !isRecalling && entryChanged && !appearanceChanged

        let apply = {
            self.model.entry = self.currentEntry
            self.model.emptyText = AppSettings.shared.emptyVocabularyText
            self.model.wordFont = self.wordFont
            self.model.translationFont = self.translationFont
        }

        if updateInPlace {
            apply()
            if let height = usableHeight(measuredLearningHeight()) {
                sizeToFitContent(fittingHeight: height)
                return
            }
        } else {
            apply()
        }

        // The recall card keeps the size it took at the start of the session.
        guard !isRecalling else {
            return
        }

        hostingView.rootView = FloatingCardView(model: model)
        sizeToFitContent()
    }

    /// Height of the reading card at `width`, or at the current width when
    /// `width` is omitted.
    ///
    /// Built beside the live view. The probe is not ordered on screen.
    private func measuredLearningHeight(at proposedWidth: CGFloat? = nil) -> CGFloat {
        let probe = NSHostingView(
            rootView: VocabularyCardView(
                entry: model.entry,
                emptyText: model.emptyText,
                wordFont: model.wordFont,
                translationFont: model.translationFont
            )
        )
        let width =
            proposedWidth ?? (hostingView.bounds.width > 1 ? hostingView.bounds.width : frame.width)
        return measuredHeight(of: probe, width: width)
    }

    private func measuredRecallHeight(
        prompt: RecallPrompt,
        index: Int,
        count: Int,
        width: CGFloat
    ) -> CGFloat {
        let probe = NSHostingView(
            rootView: RecallCardView(
                prompt: prompt,
                isRevealed: false,
                index: index,
                count: count,
                wordFont: model.wordFont,
                translationFont: model.translationFont
            )
        )
        return measuredHeight(of: probe, width: width)
    }

    /// A laid-out card is a few hundred points tall. Anything outside that is a
    /// probe that has not settled, and must not become the window size.
    private func usableHeight(_ height: CGFloat) -> CGFloat? {
        guard height > 0, height < 10_000 else {
            return nil
        }
        return height
    }

    private func measuredHeight(of probe: NSView, width: CGFloat) -> CGFloat {
        let window = NSWindow(
            contentRect: NSRect(x: -10_000, y: -10_000, width: width, height: 2_000),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentView = probe
        probe.layoutSubtreeIfNeeded()
        return probe.fittingSize.height
    }

    /// Width that fits every prompt, its answer, and the button, clamped to the
    /// card's allowed range. One width for the session, so later cards don't
    /// resize sideways.
    private func fittedRecallWidth(prompts: [RecallPrompt]) -> CGFloat {
        let word = wordFont.nsFont
        let translation = translationFont.nsFont
        var content = max(buttonWidth("Reveal"), buttonWidth("Next"))
        for prompt in prompts {
            let promptFont = prompt.showsOriginalFirst ? word : translation
            let answerFont = prompt.showsOriginalFirst ? translation : word
            content = max(content, lineWidth(prompt.prompt, font: promptFont))
            content = max(content, lineWidth(prompt.answer, font: answerFont))
        }

        let fitted = content + CardFace.inset * 2
        return min(Self.maximumWidth, max(Self.minimumWidth, ceil(fitted)))
    }

    private func lineWidth(_ text: String, font: NSFont) -> CGFloat {
        ceil((text as NSString).size(withAttributes: [.font: font]).width)
    }

    private func buttonWidth(_ title: String) -> CGFloat {
        let button = NSButton(title: title, target: nil, action: nil)
        button.bezelStyle = .rounded
        button.controlSize = .large
        button.sizeToFit()
        return ceil(button.frame.width)
    }

    /// Switches this same window into a recall session. The reading card stays
    /// underneath; `false` means there is nothing to ask.
    @discardableResult
    func beginRecall(entries: [VocabularyEntry]) -> Bool {
        guard !isRecalling, let session = RecallSession.start(entries: entries) else {
            return false
        }

        if let visible = screenVisibleFrame() {
            heightAnchor = CardHeightAnchor.forCard(midY: frame.midY, screenMidY: visible.midY)
            widthAnchor = CardWidthAnchor.forCard(midX: frame.midX, screenMidX: visible.midX)
        } else {
            heightAnchor = .bottom
            widthAnchor = .trailing
        }

        learningFrame = frame
        saveLearningGeometry = true
        let width = fittedRecallWidth(prompts: session.prompts)
        model.recall = session

        guard let prompt = session.current,
            let height = usableHeight(
                measuredRecallHeight(
                    prompt: prompt,
                    index: session.index,
                    count: session.prompts.count,
                    width: width
                )
            )
        else {
            return true
        }

        setCardFrame(
            frameWithSize(CGSize(width: width, height: height)),
            animated: isVisible
        )
        return true
    }

    /// Leaves the session without finishing the remaining cards, and puts the
    /// reading card back on the edge the session grew away from.
    func cancelRecall() {
        guard isRecalling else {
            return
        }

        model.recall = nil
        endRecall(animated: true)
        onRecallFinished?()
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

        let resized = NSRect(
            x: originX,
            y: isRecalling ? frame.origin.y : startFrame.origin.y,
            width: width,
            height: frame.height
        )
        if isRecalling, var learning = learningFrame {
            // The recall frame is temporary. Remember the new width against the
            // reading card, and don't let this resize overwrite that memory
            // with the recall card's height.
            let widthDelta = width - frame.width
            learning.size.width = min(
                Self.maximumWidth,
                max(Self.minimumWidth, learning.width + widthDelta)
            )
            learning.origin.x += originX - frame.origin.x
            learningFrame = learning
            AppSettings.shared.cardWindowSize = learning.size
            AppSettings.shared.cardWindowOrigin = learning.origin
            withoutPersistingGeometry {
                setFrame(resized, display: true)
            }
            return
        }

        setFrame(resized, display: true)
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
    private func sizeToFitContent(fittingHeight measuredHeight: CGFloat? = nil) {
        if measuredHeight == nil {
            hostingView.layoutSubtreeIfNeeded()
        }

        guard let fittingHeight = usableHeight(measuredHeight ?? hostingView.fittingSize.height),
            abs(fittingHeight - frame.height) > 0.5
        else {
            return
        }

        setCardFrame(
            CardGeometry.frame(
                bySettingHeight: fittingHeight,
                of: frame,
                pinning: heightAnchor,
                within: nil
            ),
            animated: false
        )
    }

    private func endCardDrag() {
        cardDragOrigin = nil
    }

    private func beginCardDrag() {
        cardDragOrigin = frame.origin
    }

    private func updateCardDrag(_ translation: CGSize) {
        guard let cardDragOrigin else {
            return
        }

        // SwiftUI's drag axis points down; the screen's points up.
        setFrameOrigin(
            NSPoint(
                x: cardDragOrigin.x + translation.width,
                y: cardDragOrigin.y - translation.height
            )
        )
    }

    private func endRecall(animated: Bool) {
        let saved = learningFrame
        saveLearningGeometry = false
        learningFrame = nil
        heightAnchor = .bottom
        widthAnchor = .trailing

        let savedWidth = saved?.width ?? frame.width
        let savedOrigin = saved?.origin ?? frame.origin
        let measured = measuredLearningHeight(at: savedWidth)
        let height = usableHeight(measured) ?? saved?.height ?? frame.height
        let size = CGSize(width: savedWidth, height: height)
        // The saved origin is the reading card's bottom-left. Measuring the
        // height again picks up a font change made during the session, and
        // pinning the bottom keeps that corner where the user left it.
        let restored = CardGeometry.frame(
            bySettingSize: size,
            of: NSRect(origin: savedOrigin, size: size),
            pinningHeight: .bottom,
            pinningWidth: .leading,
            within: screenVisibleFrame()
        )
        setCardFrame(restored, animated: animated && isVisible)
    }

    private func frameWithSize(_ size: CGSize) -> NSRect {
        CardGeometry.frame(
            bySettingSize: size,
            of: frame,
            pinningHeight: heightAnchor,
            pinningWidth: widthAnchor,
            within: screenVisibleFrame()
        )
    }

    private func screenVisibleFrame() -> NSRect? {
        let card = frame
        let screen = NSScreen.screens.max { lhs, rhs in
            let left = area(of: lhs.visibleFrame.intersection(card))
            let right = area(of: rhs.visibleFrame.intersection(card))
            return left < right
        }
        return (screen ?? NSScreen.main)?.visibleFrame
    }

    private func area(of rect: NSRect) -> CGFloat {
        guard !rect.isNull, !rect.isEmpty else {
            return 0
        }
        return rect.width * rect.height
    }

    private func setCardFrame(_ next: NSRect, animated: Bool) {
        let originDelta = hypot(next.origin.x - frame.origin.x, next.origin.y - frame.origin.y)
        let sizeDelta = hypot(next.width - frame.width, next.height - frame.height)
        guard originDelta > 0.5 || sizeDelta > 0.5 else {
            return
        }

        let shouldPersistResult = !saveLearningGeometry
        if animated && isVisible {
            ignoreGeometryPersistence = true
            NSAnimationContext.runAnimationGroup { context in
                context.duration = CardMotion.duration
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                self.animator().setFrame(next, display: true)
            } completionHandler: { [weak self] in
                Task { @MainActor in
                    guard let self else { return }
                    self.lastFrame = self.frame
                    self.ignoreGeometryPersistence = false
                    guard shouldPersistResult else { return }
                    AppSettings.shared.cardWindowOrigin = self.frame.origin
                    AppSettings.shared.cardWindowSize = self.frame.size
                }
            }
            return
        }

        if saveLearningGeometry {
            withoutPersistingGeometry {
                setFrame(next, display: true)
            }
        } else {
            setFrame(next, display: true)
        }
    }

    private func withoutPersistingGeometry(_ body: () -> Void) {
        ignoreGeometryPersistence = true
        body()
        lastFrame = frame
        ignoreGeometryPersistence = false
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
        guard !ignoreGeometryPersistence else {
            return
        }

        if saveLearningGeometry, var learningFrame {
            learningFrame.origin.x += frame.origin.x - lastFrame.origin.x
            learningFrame.origin.y += frame.origin.y - lastFrame.origin.y
            self.learningFrame = learningFrame
            AppSettings.shared.cardWindowOrigin = learningFrame.origin
        } else {
            AppSettings.shared.cardWindowOrigin = frame.origin
        }

        lastFrame.origin = frame.origin
    }

    func windowDidResize(_: Notification) {
        guard !ignoreGeometryPersistence else {
            return
        }

        if saveLearningGeometry, let learningFrame {
            AppSettings.shared.cardWindowSize = learningFrame.size
        } else {
            AppSettings.shared.cardWindowSize = frame.size
        }

        lastFrame.size = frame.size
    }

    override var canBecomeKey: Bool {
        isRecalling
    }

    override var canBecomeMain: Bool {
        false
    }
}
