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
        // The press is remembered in screen coordinates before SwiftUI tracks
        // it, so a drag that follows keeps the grabbed point under the pointer.
        if edge == nil, let panel = window as? VocabularyCardPanel, panel.isRecalling {
            panel.rememberRecallPress(at: screenPoint(of: event, in: window))
            super.mouseDown(with: event)
            panel.finishRecallPress()
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

    /// A card that starts ignoring the mouse never sees the pointer leave, so
    /// the resize cursor it pushed has to be dropped by hand.
    func resetResizeCursor() {
        hideResizeCursor()
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
    private var cardDragPointer: NSPoint?
    private var frameAnimation: FrameAnimation?
    private var frameAnimationID = 0
    private var hoverFade = CardHoverFade()
    private var hoverTimer: Timer?
    /// The opacity to return to, held only while the card is faded or still
    /// coming back from it.
    private var solidAlpha: CGFloat?

    /// Fade the card and let clicks through while the pointer rests on it.
    var fadesOnHover = AppSettings.shared.cardFadesOnHover {
        didSet {
            updateHoverFade()
        }
    }

    private struct FrameAnimation {
        let timer: Timer
        let target: NSRect
        let persisting: Bool
        let completion: (() -> Void)?
    }

    /// The coordinator restarts the schedule when a session ends. It runs after
    /// the session is cleared but before the card shrinks back, so a card
    /// shown only for this session can be hidden without animating first.
    var onRecallFinished: (() -> Void)?
    /// A side of a recall card came into view; see `CardModel.onRecallTextShown`.
    var onRecallTextShown: ((_ text: String, _ isOriginal: Bool) -> Void)?
    /// The replay button on the recall card was pressed.
    var onReplay: ((_ text: String, _ isOriginal: Bool) -> Void)?

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
            styleMask: [.titled, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        // A titled window takes its corners and shadow from the system. All
        // that shows of the title bar is the shape it gives the window.
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        isMovable = false
        isExcludedFromWindowsMenu = true
        // Hiding the bar itself rather than its buttons: left in place, even
        // invisible, it takes every click on the top of the card.
        standardWindowButton(.closeButton)?.superview?.superview?.isHidden = true

        contentView = hostingView
        // The init above sized the frame around a title bar on top of `size`.
        setFrame(NSRect(origin: .zero, size: size), display: false)
        hostingView.safeAreaRegions = []
        // The recall face is taller. Letting the hosting view's maximum size
        // follow that face makes the window snap down the moment the learning
        // card returns. The panel animates the frame itself.
        hostingView.sizingOptions = [.intrinsicContentSize]
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
            self?.endRecall()
        }
        model.onRecallTextShown = { [weak self] text, isOriginal in
            self?.onRecallTextShown?(text, isOriginal)
        }
        model.onReplay = { [weak self] text, isOriginal in
            self?.onReplay?(text, isOriginal)
        }
        model.onMoveBegan = { [weak self] in
            self?.beginCardDrag()
        }
        model.onMoveChanged = { [weak self] in
            self?.updateCardDrag()
        }
        model.onMoveEnded = { [weak self] in
            self?.endCardDrag()
        }
    }

    /// `inPlace: false` rebuilds the card instead of publishing the word into
    /// the live view. A vocabulary switch made from a menu needs that: an
    /// in-place change waits for a default-mode turn to repaint.
    func update(entry: VocabularyEntry?, inPlace: Bool = true) {
        currentEntry = entry
        refresh(allowingInPlaceUpdate: inPlace)
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

    func refresh(allowingInPlaceUpdate: Bool = true) {
        let entryChanged = model.entry != currentEntry
        let appearanceChanged =
            model.emptyText != AppSettings.shared.emptyVocabularyText
            || model.wordFont != wordFont
            || model.translationFont != translationFont
        // A visible card keeps its view when only the word changes, so the text
        // updates in place. Fonts still replace it: publishing into the
        // existing view waits a turn, and a change made while a menu is
        // tracking would miss its repaint until the next rotation.
        let updateInPlace =
            allowingInPlaceUpdate && isVisible && !isRecalling && entryChanged
            && !appearanceChanged

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

        // The previous session may still be shrinking back. Its target is the
        // reading frame this session has to remember, not wherever it got to.
        settleFrameAnimation()
        if let visible = screenVisibleFrame() {
            adopt(
                height: CardHeightAnchor.forCard(midY: frame.midY, screenMidY: visible.midY),
                width: CardWidthAnchor.forCard(midX: frame.midX, screenMidX: visible.midX)
            )
        } else {
            adopt(height: .bottom, width: .trailing)
        }

        learningFrame = frame
        saveLearningGeometry = true
        let width = fittedRecallWidth(prompts: session.prompts)
        model.recall = session
        model.recallFaceVisible = true
        model.announcePrompt()

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

        endRecall()
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
        let measured = measuredHeight ?? measuredLearningHeight()
        guard let fittingHeight = usableHeight(measured),
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

    /// Records the window and the pointer where a recall press began.
    ///
    /// A click that never becomes a drag leaves these set until tracking
    /// returns. A drag uses them as the fixed baseline, including the distance
    /// traveled before the gesture recognized the movement.
    func rememberRecallPress(at screenPoint: NSPoint) {
        // A press during the grow would otherwise freeze the card part-way.
        settleFrameAnimation()
        cardDragOrigin = frame.origin
        cardDragPointer = screenPoint
    }

    func finishRecallPress() {
        cardDragOrigin = nil
        cardDragPointer = nil
    }

    /// Moves the recall card so the pressed point stays under `pointer`.
    ///
    /// `pointer` is a screen point. Repeating a call with the same point does
    /// not move the card again: the baseline is the press, not the last frame.
    func followRecallPointer(_ pointer: NSPoint) {
        guard let cardDragOrigin, let cardDragPointer else {
            return
        }

        setFrameOrigin(
            CardGeometry.origin(
                moving: cardDragOrigin,
                followingPointerFrom: cardDragPointer,
                to: pointer
            )
        )
    }

    private func endCardDrag() {
        // Leave the press baseline in place. This gesture can end when the
        // window moves and a new one can begin before the mouse comes up;
        // clearing here would abandon the point the user grabbed. Tracking
        // returns to `finishRecallPress` when the press is actually over.
    }

    private func beginCardDrag() {
        guard cardDragPointer == nil else {
            return
        }

        rememberRecallPress(at: NSEvent.mouseLocation)
    }

    private func updateCardDrag() {
        followRecallPointer(NSEvent.mouseLocation)
    }

    private func endRecall() {
        let saved = learningFrame
        saveLearningGeometry = false
        learningFrame = nil
        // The session is over, but the face stays in the tree until the window
        // has shrunk. Removing it now collapses the card and the window jumps.
        model.recall = nil
        model.recallFaceVisible = false
        onRecallFinished?()

        let savedRect = saved ?? frame
        let measured = measuredLearningHeight(at: savedRect.width)
        let height = usableHeight(measured) ?? savedRect.height
        let size = CGSize(width: savedRect.width, height: height)
        // Keep the edges this session grew away from. Measuring the height
        // again picks up a font change made during the session; the pinned
        // edges stay where the learning card left them.
        let restored = CardGeometry.frame(
            bySettingSize: size,
            of: savedRect,
            pinningHeight: heightAnchor,
            pinningWidth: widthAnchor,
            within: screenVisibleFrame()
        )
        // A newer session may have started before this shrink finished; its
        // face and anchors must survive this completion.
        setCardFrame(restored, animated: true) { [weak self] in
            guard let self, !self.isRecalling else {
                return
            }
            self.model.dismissDisplayedRecall()
            self.adopt(height: .bottom, width: .trailing)
        }
    }

    private func adopt(height: CardHeightAnchor, width: CardWidthAnchor) {
        heightAnchor = height
        widthAnchor = width
        if model.heightAnchor != height {
            model.heightAnchor = height
        }
        if model.widthAnchor != width {
            model.widthAnchor = width
        }
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

    private func setCardFrame(
        _ next: NSRect,
        animated: Bool,
        completion: (() -> Void)? = nil
    ) {
        // A running animation is heading somewhere else; it stops where it is
        // and this one starts from there.
        stopFrameAnimation()
        let originDelta = hypot(next.origin.x - frame.origin.x, next.origin.y - frame.origin.y)
        let sizeDelta = hypot(next.width - frame.width, next.height - frame.height)
        guard originDelta > 0.5 || sizeDelta > 0.5 else {
            completion?()
            return
        }

        let shouldPersistResult = !saveLearningGeometry
        // A menu-bar app is usually not the active app, and a recall often
        // starts from the status menu. AppKit's window animator drops those
        // frames and the card snaps. Stepping the frame ourselves keeps the
        // resize moving while another app is in front.
        guard animated, isVisible else {
            applySettledFrame(next, persisting: shouldPersistResult)
            completion?()
            return
        }

        let start = frame
        let began = Date()
        frameAnimationID += 1
        let animationID = frameAnimationID
        ignoreGeometryPersistence = true
        // Added to the main run loop below, so the block always runs on the
        // main thread.
        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] timer in
            guard let self else {
                timer.invalidate()
                return
            }

            MainActor.assumeIsolated {
                self.stepFrameAnimation(animationID, from: start, to: next, began: began)
            }
        }
        frameAnimation = FrameAnimation(
            timer: timer,
            target: next,
            persisting: shouldPersistResult,
            completion: completion
        )
        RunLoop.main.add(timer, forMode: .common)
    }

    private func stepFrameAnimation(
        _ animationID: Int, from start: NSRect, to next: NSRect, began: Date
    ) {
        guard animationID == frameAnimationID, frameAnimation != nil else {
            return
        }

        let raw = min(1, Date().timeIntervalSince(began) / CardMotion.duration)
        guard raw >= 1 else {
            setFrame(CardMotion.frame(from: start, to: next, at: raw), display: true)
            return
        }

        settleFrameAnimation()
    }

    /// Ends a running animation on its target frame, as if it had played out.
    private func settleFrameAnimation() {
        guard let animation = frameAnimation else {
            return
        }

        animation.timer.invalidate()
        frameAnimation = nil
        frameAnimationID += 1
        applySettledFrame(animation.target, persisting: animation.persisting)
        animation.completion?()
    }

    private func applySettledFrame(_ next: NSRect, persisting: Bool) {
        if persisting {
            ignoreGeometryPersistence = false
            setFrame(next, display: true)
        } else {
            withoutPersistingGeometry {
                setFrame(next, display: true)
            }
        }
        lastFrame = frame
    }

    /// Stops a running animation where it is. Its completion still runs: the
    /// end of a session relies on it to drop the recall face.
    private func stopFrameAnimation() {
        let animation = frameAnimation
        animation?.timer.invalidate()
        frameAnimation = nil
        frameAnimationID += 1
        ignoreGeometryPersistence = false
        lastFrame = frame
        animation?.completion?()
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

    // MARK: - Fading under the pointer

    override func orderFrontRegardless() {
        super.orderFrontRegardless()
        startHoverTracking()
    }

    override func orderOut(_ sender: Any?) {
        stopHoverTracking()
        super.orderOut(sender)
    }

    /// A window that ignores the mouse gets no tracking events either, so the
    /// pointer and the Option key are sampled instead. Neither needs
    /// Accessibility permission. The timer only runs while the card is shown.
    private func startHoverTracking() {
        guard hoverTimer == nil else {
            return
        }

        let timer = Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak self] timer in
            guard let self else {
                timer.invalidate()
                return
            }

            MainActor.assumeIsolated {
                self.updateHoverFade()
            }
        }
        timer.tolerance = 1.0 / 120.0
        RunLoop.main.add(timer, forMode: .common)
        hoverTimer = timer
    }

    private func stopHoverTracking() {
        hoverTimer?.invalidate()
        hoverTimer = nil
        hoverFade.reset()
        ignoresMouseEvents = false
        if let solidAlpha {
            alphaValue = solidAlpha
        }
        solidAlpha = nil
    }

    private func updateHoverFade() {
        guard isVisible else {
            return
        }

        let pointerArea =
            hoverFade.isFaded
            ? frame.insetBy(dx: -CardHoverFade.exitMargin, dy: -CardHoverFade.exitMargin)
            : frame
        let wasFaded = hoverFade.isFaded
        let faded = hoverFade.update(
            pointerInside: pointerArea.contains(NSEvent.mouseLocation),
            optionHeld: NSEvent.modifierFlags.contains(.option),
            buttonPressed: NSEvent.pressedMouseButtons != 0,
            isEnabled: fadesOnHover,
            isRecalling: isRecalling,
            now: Date()
        )

        if faded, !wasFaded {
            solidAlpha = solidAlpha ?? alphaValue
            hostingView.resetResizeCursor()
        }
        if ignoresMouseEvents != faded {
            ignoresMouseEvents = faded
        }
        stepAlpha(towardFaded: faded)
    }

    /// Eases the opacity a step per sample. AppKit's window animator drops
    /// frames while another app is active, which is when this runs.
    private func stepAlpha(towardFaded faded: Bool) {
        guard let solid = solidAlpha else {
            return
        }

        let target = faded ? solid * CardHoverFade.fadedOpacity : solid
        let step = max(solid, 0.01) / 5
        let next =
            alphaValue < target
            ? min(target, alphaValue + step)
            : max(target, alphaValue - step)
        if abs(next - alphaValue) > 0.0001 {
            alphaValue = next
        }
        if !faded, abs(next - solid) < 0.0001 {
            solidAlpha = nil
        }
    }

    /// A titled window is kept below the menu bar. The card goes where it is
    /// placed, and `CardGeometry` already keeps a growing card on screen.
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        frameRect
    }

    override var canBecomeKey: Bool {
        isRecalling
    }

    override var canBecomeMain: Bool {
        false
    }
}
