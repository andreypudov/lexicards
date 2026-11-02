import AppKit
import Foundation
import Testing

@testable import LexiCards

@MainActor
@Suite(.serialized)
struct RecallTests {
    @Test
    func anEmptyVocabularyDoesNotStartASession() {
        #expect(RecallSession.start(entries: []) == nil)
    }

    @Test
    func aShortVocabularyUsesEveryEntryOnce() {
        let entries = words(4)
        let session = RecallSession.start(entries: entries, showsOriginalFirst: { _ in true })

        #expect(session?.prompts.count == 4)
        #expect(Set(session?.prompts.map(\.entry.original) ?? []).count == 4)
    }

    @Test
    func aLongVocabularyIsCutToTenDistinctEntries() {
        let entries = words(25)
        let session = RecallSession.start(entries: entries, showsOriginalFirst: { _ in false })

        let originals = session?.prompts.map(\.entry.original) ?? []
        #expect(originals.count == RecallSession.length)
        #expect(Set(originals).count == RecallSession.length)
        #expect(originals.allSatisfy { name in entries.contains { $0.original == name } })
    }

    @Test
    func eachCardChoosesWhichSideIsThePrompt() {
        let session = RecallSession.start(
            entries: words(4),
            showsOriginalFirst: { $0.isMultiple(of: 2) }
        )

        #expect(session?.prompts.map(\.showsOriginalFirst) == [true, false, true, false])
        let hiddenOriginal = session?.prompts[1]
        #expect(hiddenOriginal?.prompt == hiddenOriginal?.entry.translation)
        #expect(hiddenOriginal?.answer == hiddenOriginal?.entry.original)
    }

    @Test
    func revealingThenAdvancingWalksTheSession() {
        var session = RecallSession.start(entries: words(2), showsOriginalFirst: { _ in true })!

        #expect(session.current?.entry.original != nil)
        #expect(session.isRevealed == false)

        session.reveal()
        #expect(session.isRevealed)

        session.advance()
        #expect(session.index == 1)
        #expect(session.isRevealed == false)

        session.advance()
        #expect(session.current == nil)
    }

    @Test
    func theLastCardFinishesTheSession() {
        let model = CardModel(
            entry: nil,
            emptyText: "",
            wordFont: CardFont(familyName: nil, size: 21, weight: .semibold),
            translationFont: CardFont(familyName: nil, size: 16, weight: .regular)
        )
        model.recall = RecallSession.start(entries: words(2), showsOriginalFirst: { _ in true })
        var finished = false
        model.onFinished = { finished = true }

        model.reveal()
        model.advance()
        #expect(finished == false)
        #expect(model.isRecalling)

        model.reveal()
        model.advance()
        #expect(finished)
        #expect(model.recall == nil)
    }

    /// Speech follows what is on screen: each prompt when its card appears,
    /// each answer only on Reveal.
    @Test
    func eachSideIsAnnouncedOnlyOnceItIsVisible() {
        let model = CardModel(
            entry: nil,
            emptyText: "",
            wordFont: CardFont(familyName: nil, size: 21, weight: .semibold),
            translationFont: CardFont(familyName: nil, size: 16, weight: .regular)
        )
        model.recall = RecallSession.start(
            entries: words(2),
            showsOriginalFirst: { $0 == 0 }
        )
        var shown: [String] = []
        var sides: [Bool] = []
        model.onRecallTextShown = { text, isOriginal in
            shown.append(text)
            sides.append(isOriginal)
        }
        let first = model.recall?.prompts[0]
        let second = model.recall?.prompts[1]

        model.announcePrompt()
        #expect(shown == [first?.entry.original])

        model.reveal()
        model.reveal()
        #expect(shown == [first?.entry.original, first?.entry.translation])

        model.advance()
        #expect(shown.last == second?.entry.translation)
        #expect(shown.contains(second?.entry.original ?? "") == false)

        model.reveal()
        #expect(shown.last == second?.entry.original)
        #expect(sides == [true, false, false, true])

        var replayed: String?
        model.onReplay = { text, _ in replayed = text }
        model.replay()
        #expect(replayed == second?.entry.original)
    }

    @Test
    func pronunciationDefaultsToTheWordInBothModes() {
        withIsolatedSettings {
            #expect(AppSettings.shared.pronounceDuringRotation)
            #expect(AppSettings.shared.pronounceDuringRecall)
            #expect(AppSettings.shared.pronounceTranslation == false)

            let model = SettingsModel()
            var notified = false
            model.onPronunciationChanged = { notified = true }
            model.pronounceDuringRotation = false
            model.pronounceTranslation = true
            model.commitPronunciation()
            RunLoop.current.run(mode: .eventTracking, before: Date().addingTimeInterval(0.5))

            #expect(notified)
            #expect(AppSettings.shared.pronounceDuringRotation == false)
            #expect(AppSettings.shared.pronounceDuringRecall)
            #expect(AppSettings.shared.pronounceTranslation)
        }
    }

    @Test
    func growingDownHoldsTheTopEdge() {
        let current = CGRect(x: 40, y: 500, width: 320, height: 100)
        let visible = CGRect(x: 0, y: 0, width: 1_440, height: 900)
        let next = CardGeometry.frame(
            bySettingHeight: 300,
            of: current,
            pinning: .top,
            within: visible
        )

        #expect(next.maxY == current.maxY)
        #expect(next.height == 300)
        #expect(next.minY == 300)
    }

    @Test
    func growingUpHoldsTheBottomEdge() {
        let current = CGRect(x: 40, y: 80, width: 320, height: 100)
        let visible = CGRect(x: 0, y: 0, width: 1_440, height: 900)
        let next = CardGeometry.frame(
            bySettingHeight: 300,
            of: current,
            pinning: .bottom,
            within: visible
        )

        #expect(next.minY == current.minY)
        #expect(next.height == 300)
    }

    @Test
    func growthStaysInsideTheScreen() {
        let current = CGRect(x: 10, y: 20, width: 320, height: 80)
        let visible = CGRect(x: 0, y: 0, width: 800, height: 200)
        let next = CardGeometry.frame(
            bySettingHeight: 400,
            of: current,
            pinning: .bottom,
            within: visible
        )

        #expect(visible.contains(next))
        #expect(next.height == visible.height)
    }

    @Test
    func wideningPinsTheTrailingEdge() {
        let current = CGRect(x: 900, y: 80, width: 320, height: 100)
        let visible = CGRect(x: 0, y: 0, width: 1_440, height: 900)
        let next = CardGeometry.frame(
            bySettingSize: CGSize(width: 480, height: 220),
            of: current,
            pinningHeight: .bottom,
            pinningWidth: .trailing,
            within: visible
        )

        #expect(next.maxX == current.maxX)
        #expect(next.minY == current.minY)
        #expect(next.width == 480)
        #expect(next.height == 220)
    }

    @Test
    func returningToTheLearningCardShrinksInsteadOfJumping() async {
        let suiteName = "LexiCardsTests-\(UUID().uuidString)"
        let suite = UserDefaults(suiteName: suiteName)
        let original = AppSettings.shared.defaults
        if let suite {
            AppSettings.shared.defaults = suite
        }
        defer {
            AppSettings.shared.defaults = original
            suite?.removePersistentDomain(forName: suiteName)
        }

        let panel = VocabularyCardPanel()
        panel.alphaValue = 0
        panel.update(entry: VocabularyEntry(original: "猫", translation: "cat"))
        let learning = panel.frame
        #expect(panel.beginRecall(entries: words(4)))
        let recall = panel.frame
        let span = recall.height - learning.height
        #expect(span > 40)

        panel.orderFrontRegardless()
        panel.cancelRecall()
        // The call itself must not snap. Where the card is a moment later is
        // not predictable: a busy run loop delivers the whole animation in one
        // late tick, which is what this test used to mistake for a jump.
        #expect(abs(panel.frame.height - recall.height) < 1)

        await waitUntil { abs(panel.frame.height - learning.height) < 1 }
        #expect(abs(panel.frame.height - learning.height) < 1)
        panel.orderOut(nil)
    }

    @Test
    func showingRecallDoesNotJumpTheWindowToItsFinalSize() {
        withIsolatedSettings {
            let panel = VocabularyCardPanel()
            panel.alphaValue = 0
            panel.update(entry: VocabularyEntry(original: "猫", translation: "cat"))
            panel.orderFrontRegardless()
            defer {
                panel.orderOut(nil)
                panel.cancelRecall()
            }

            let before = panel.frame
            #expect(panel.beginRecall(entries: words(4)))
            #expect(abs(panel.frame.height - before.height) < 1)
            #expect(abs(panel.frame.width - before.width) < 1)
        }
    }

    @Test
    func aResizeHoldsThePinnedCornerThroughout() {
        let start = CGRect(x: 100, y: 40, width: 320, height: 88)
        let end = CGRect(x: 180, y: 40, width: 240, height: 200)

        let mid = CardMotion.frame(from: start, to: end, at: 0.5)

        #expect(abs(mid.maxX - start.maxX) < 0.01)
        #expect(abs(mid.minY - start.minY) < 0.01)
        #expect(mid.width > end.width)
        #expect(mid.width < start.width)
        #expect(mid.height > start.height)
        #expect(mid.height < end.height)
        #expect(CardMotion.frame(from: start, to: end, at: 1) == end)
    }

    @Test
    func aRecallDragKeepsTheGrabbedPointUnderThePointer() {
        let startOrigin = CGPoint(x: 200, y: 300)
        let grabbed = CGPoint(x: 240, y: 340)

        let moved = CardGeometry.origin(
            moving: startOrigin,
            followingPointerFrom: grabbed,
            to: CGPoint(x: 390, y: 260)
        )

        #expect(moved == CGPoint(x: 350, y: 220))
    }

    @Test
    func repeatingARecallDragSampleDoesNotWalkTheCard() {
        withIsolatedSettings {
            let panel = VocabularyCardPanel()
            panel.setFrameOrigin(NSPoint(x: 200, y: 300))
            panel.rememberRecallPress(at: NSPoint(x: 240, y: 340))

            panel.followRecallPointer(NSPoint(x: 300, y: 280))
            let once = panel.frame.origin
            panel.followRecallPointer(NSPoint(x: 300, y: 280))

            #expect(once == NSPoint(x: 260, y: 240))
            #expect(panel.frame.origin == once)

            panel.followRecallPointer(NSPoint(x: 310, y: 290))
            #expect(panel.frame.origin == NSPoint(x: 270, y: 250))

            panel.finishRecallPress()
            panel.followRecallPointer(NSPoint(x: 500, y: 500))
            #expect(panel.frame.origin == NSPoint(x: 270, y: 250))
        }
    }

    @Test
    func wideningPinsTheLeadingEdge() {
        let current = CGRect(x: 40, y: 500, width: 320, height: 100)
        let visible = CGRect(x: 0, y: 0, width: 1_440, height: 900)
        let next = CardGeometry.frame(
            bySettingSize: CGSize(width: 240, height: 180),
            of: current,
            pinningHeight: .top,
            pinningWidth: .leading,
            within: visible
        )

        #expect(next.minX == current.minX)
        #expect(next.maxY == current.maxY)
        #expect(next.width == 240)
        #expect(next.height == 180)
    }

    @Test
    func aCardInTheTopHalfGrowsDownwardAndRemembersTheReadingSize() {
        withIsolatedSettings {
            let panel = VocabularyCardPanel()
            panel.update(entry: VocabularyEntry(original: "猫", translation: "cat"))
            guard let visible = NSScreen.main?.visibleFrame else {
                Issue.record("no screen")
                return
            }

            panel.setFrameOrigin(
                NSPoint(x: visible.minX + 40, y: visible.maxY - panel.frame.height - 8)
            )
            let before = panel.frame
            let remembered = AppSettings.shared.cardWindowSize

            #expect(panel.beginRecall(entries: words(3)))
            panel.contentView?.layoutSubtreeIfNeeded()

            #expect(panel.frame.height > before.height)
            #expect(abs(panel.frame.maxY - before.maxY) < 1)
            #expect(abs(panel.frame.minX - before.minX) < 1)
            #expect(panel.frame.width >= VocabularyCardPanel.minimumWidth)
            #expect(panel.frame.width <= VocabularyCardPanel.maximumWidth)
            #expect(AppSettings.shared.cardWindowSize?.height == remembered?.height)
            #expect(AppSettings.shared.cardWindowSize?.width == remembered?.width)
            #expect(panel.isRecalling)

            panel.cancelRecall()

            #expect(panel.isRecalling == false)
            #expect(abs(panel.frame.height - before.height) < 1)
            #expect(abs(panel.frame.maxY - before.maxY) < 1)
        }
    }

    @Test
    func aCardInTheBottomHalfGrowsUpward() {
        withIsolatedSettings {
            let panel = VocabularyCardPanel()
            panel.update(entry: VocabularyEntry(original: "猫", translation: "cat"))
            guard let visible = NSScreen.main?.visibleFrame else {
                Issue.record("no screen")
                return
            }

            panel.setFrameOrigin(NSPoint(x: visible.minX + 40, y: visible.minY + 8))
            let before = panel.frame

            #expect(panel.beginRecall(entries: words(1)))

            #expect(abs(panel.frame.minY - before.minY) < 1)
            #expect(panel.frame.height > before.height)

            panel.cancelRecall()

            #expect(abs(panel.frame.minY - before.minY) < 1)
            #expect(abs(panel.frame.height - before.height) < 1)
        }
    }

    @Test
    func aLongPromptWidensTheCardAndPinsTheRightEdge() {
        withIsolatedSettings {
            let panel = VocabularyCardPanel()
            panel.update(entry: VocabularyEntry(original: "猫", translation: "cat"))
            guard let visible = NSScreen.main?.visibleFrame else {
                Issue.record("no screen")
                return
            }

            panel.setFrameOrigin(
                NSPoint(x: visible.maxX - panel.frame.width - 8, y: visible.minY + 8)
            )
            let before = panel.frame
            let entry = VocabularyEntry(
                original:
                    "a considerably longer prompt that needs more width than the reading card",
                translation:
                    "a considerably longer answer that needs more width than the reading card"
            )

            #expect(panel.beginRecall(entries: [entry]))

            #expect(panel.frame.width > before.width)
            #expect(panel.frame.width <= VocabularyCardPanel.maximumWidth)
            #expect(abs(panel.frame.maxX - before.maxX) < 1)
            #expect(panel.frame.height > before.height)
            #expect(abs(panel.frame.minY - before.minY) < 1)

            panel.cancelRecall()

            #expect(abs(panel.frame.width - before.width) < 1)
            #expect(abs(panel.frame.height - before.height) < 1)
            #expect(abs(panel.frame.maxX - before.maxX) < 1)
            #expect(abs(panel.frame.minY - before.minY) < 1)
        }
    }

    /// Changing vocabulary ends the session and shows a new word in one turn.
    /// Refitting that word must not stop the shrink on the recall card's width
    /// and remember it as the reading card's own.
    @Test
    func aNewWordDuringTheShrinkStillReturnsToTheReadingFrame() {
        withIsolatedSettings {
            let panel = VocabularyCardPanel()
            panel.alphaValue = 0
            panel.update(entry: VocabularyEntry(original: "猫", translation: "cat"))
            panel.orderFrontRegardless()
            defer { panel.orderOut(nil) }
            let learning = panel.frame
            let entry = VocabularyEntry(
                original:
                    "a considerably longer prompt that needs more width than the reading card",
                translation:
                    "a considerably longer answer that needs more width than the reading card"
            )
            #expect(panel.beginRecall(entries: [entry]))
            settle(panel)
            #expect(panel.frame.width > learning.width)

            panel.cancelRecall()
            panel.update(entry: VocabularyEntry(original: "犬", translation: "dog"), inPlace: false)
            settle(panel)

            #expect(abs(panel.frame.width - learning.width) < 1)
            #expect(abs(panel.frame.maxX - learning.maxX) < 1)
            #expect(abs((AppSettings.shared.cardWindowSize?.width ?? 0) - learning.width) < 1)
        }
    }

    /// A press during the shrink would otherwise fight the animation for the
    /// window and measure its drag from a frame on the way somewhere else.
    @Test
    func pressingTheReadingCardDuringTheShrinkFinishesIt() {
        withIsolatedSettings {
            let panel = VocabularyCardPanel()
            panel.alphaValue = 0
            panel.update(entry: VocabularyEntry(original: "猫", translation: "cat"))
            panel.orderFrontRegardless()
            defer { panel.orderOut(nil) }
            let learning = panel.frame
            #expect(panel.beginRecall(entries: words(4)))
            settle(panel)
            panel.cancelRecall()
            #expect(abs(panel.frame.height - learning.height) > 1)

            panel.contentView?.mouseDown(
                with: mouse(.leftMouseDown, at: NSPoint(x: 100, y: 20), in: panel))

            #expect(abs(panel.frame.height - learning.height) < 1)
            #expect(abs(panel.frame.width - learning.width) < 1)
        }
    }

    /// The card keeps its size through a session, except when a font makes that
    /// size too small: the button would be clipped out of reach.
    @Test
    func aLargerFontDuringASessionMakesRoomForIt() {
        withIsolatedSettings {
            let panel = VocabularyCardPanel()
            panel.update(entry: VocabularyEntry(original: "猫", translation: "cat"))
            let learning = panel.frame
            #expect(panel.beginRecall(entries: words(2)))
            let before = panel.frame

            panel.apply(
                wordFont: CardFont(familyName: nil, size: 60, weight: .semibold),
                translationFont: CardFont(familyName: nil, size: 60, weight: .regular)
            )

            #expect(panel.frame.height > before.height)
            #expect(abs((AppSettings.shared.cardWindowSize?.width ?? 0) - learning.width) < 1)
        }
    }

    @Test
    func aCardHiddenWhenTheSessionEndsSkipsTheShrink() {
        withIsolatedSettings {
            let panel = VocabularyCardPanel()
            panel.alphaValue = 0
            panel.update(entry: VocabularyEntry(original: "猫", translation: "cat"))
            panel.orderFrontRegardless()
            let learning = panel.frame
            #expect(panel.beginRecall(entries: words(2)))

            var wasRecallingWhenNotified: Bool?
            panel.onRecallFinished = { [weak panel] in
                wasRecallingWhenNotified = panel?.isRecalling
                panel?.orderOut(nil)
            }
            panel.cancelRecall()

            #expect(wasRecallingWhenNotified == false)
            #expect(panel.isVisible == false)
            #expect(abs(panel.frame.height - learning.height) < 1)
            #expect(abs(panel.frame.width - learning.width) < 1)
        }
    }

    @Test
    func aSessionStartedDuringTheShrinkRemembersTheReadingFrame() async {
        let suiteName = "LexiCardsTests-\(UUID().uuidString)"
        let suite = UserDefaults(suiteName: suiteName)
        let original = AppSettings.shared.defaults
        if let suite {
            AppSettings.shared.defaults = suite
        }
        defer {
            AppSettings.shared.defaults = original
            suite?.removePersistentDomain(forName: suiteName)
        }

        let panel = VocabularyCardPanel()
        panel.alphaValue = 0
        panel.update(entry: VocabularyEntry(original: "猫", translation: "cat"))
        let learning = panel.frame
        #expect(panel.beginRecall(entries: words(4)))
        panel.orderFrontRegardless()
        panel.cancelRecall()
        // Still on the way back, so the new session starts during the shrink.
        #expect(abs(panel.frame.height - learning.height) > 1)
        #expect(panel.beginRecall(entries: words(4)))
        panel.cancelRecall()
        await waitUntil {
            abs(panel.frame.height - learning.height) < 1
                && abs(panel.frame.width - learning.width) < 1
        }

        #expect(abs(panel.frame.height - learning.height) < 1)
        #expect(abs(panel.frame.width - learning.width) < 1)
        panel.orderOut(nil)
    }

    @Test
    func pressingTheCardWhileItGrowsFinishesTheGrowth() {
        let suiteName = "LexiCardsTests-\(UUID().uuidString)"
        let suite = UserDefaults(suiteName: suiteName)
        let original = AppSettings.shared.defaults
        if let suite {
            AppSettings.shared.defaults = suite
        }
        defer {
            AppSettings.shared.defaults = original
            suite?.removePersistentDomain(forName: suiteName)
        }

        let panel = VocabularyCardPanel()
        panel.alphaValue = 0
        panel.update(entry: VocabularyEntry(original: "猫", translation: "cat"))
        #expect(panel.beginRecall(entries: words(4)))
        let recall = panel.frame
        panel.cancelRecall()
        let learning = panel.frame

        panel.orderFrontRegardless()
        #expect(panel.beginRecall(entries: words(4)))
        // The growth has been asked for but not drawn yet.
        #expect(panel.frame.height < recall.height - 1)

        panel.rememberRecallPress(at: NSEvent.mouseLocation)
        panel.finishRecallPress()
        #expect(abs(panel.frame.height - recall.height) < 1)
        #expect(panel.frame.height > learning.height)

        panel.orderOut(nil)
        panel.cancelRecall()
    }

    @Test
    func cancellingEndsTheSessionWithoutWalkingTheRemainingCards() {
        let model = CardModel(
            entry: nil,
            emptyText: "",
            wordFont: .word(from: AppSettings.shared),
            translationFont: .translation(from: AppSettings.shared)
        )
        var finished = 0
        var shown = 0
        model.onFinished = { finished += 1 }
        model.onRecallTextShown = { _, _ in shown += 1 }
        model.recall = RecallSession.start(entries: words(3), showsOriginalFirst: { _ in true })

        model.cancel()

        #expect(model.recall == nil)
        #expect(!model.isRecalling)
        #expect(finished == 1)
        #expect(shown == 0)
        // The face is still drawn while the window shrinks back, so its close
        // button can be pressed again. That must not end the session twice.
        #expect(model.displayedRecall != nil)
        model.cancel()
        #expect(finished == 1)
    }

    @Test
    func replayPronouncesTheWordOnTheCard() {
        let model = CardModel(
            entry: nil,
            emptyText: "",
            wordFont: .word(from: AppSettings.shared),
            translationFont: .translation(from: AppSettings.shared)
        )
        var replayed: [String] = []
        var sides: [Bool] = []
        model.onReplay = { text, isOriginal in
            replayed.append(text)
            sides.append(isOriginal)
        }

        // The original is the hidden answer, so the translation is read instead.
        model.recall = RecallSession.start(entries: words(1), showsOriginalFirst: { _ in false })
        let entry = model.recall?.current?.entry
        model.replay()
        #expect(replayed == [entry?.translation])
        #expect(sides == [false])

        model.reveal()
        model.replay()
        #expect(replayed.last == entry?.original)
        #expect(sides.last == true)

        // The original is the question, so it is read straight away.
        model.recall = RecallSession.start(entries: words(1), showsOriginalFirst: { _ in true })
        model.replay()
        #expect(replayed.last == entry?.original)
        #expect(sides.last == true)
    }

    @Test
    func theMenuItemEndsASessionInProgress() {
        let controller = MenuBarController()
        var started = 0
        var ended = 0
        controller.onStartRecall = { started += 1 }
        controller.onEndRecall = { ended += 1 }
        let item = controller.recallMenuItem

        #expect(item.title == "Recall Now")
        NSApp.sendAction(item.action!, to: item.target, from: item)
        #expect(started == 1)

        controller.setRecalling(true)
        #expect(item.title == "End Recall")
        NSApp.sendAction(item.action!, to: item.target, from: item)
        #expect(ended == 1)
        #expect(started == 1)

        controller.setRecalling(false)
        #expect(item.title == "Recall Now")
        NSApp.sendAction(item.action!, to: item.target, from: item)
        #expect(started == 2)
        #expect(ended == 1)
    }

    /// The hosting view drags the card and resizes it, so the material behind
    /// the text must never be what a click lands on.
    @Test
    func theCardMaterialLeavesClicksToTheHostingView() {
        let view = CardMaterialView(frame: NSRect(x: 0, y: 0, width: 100, height: 100))

        #expect(view.material == .hudWindow)
        #expect(view.state == .active)
        #expect(view.hitTest(NSPoint(x: 50, y: 50)) == nil)
    }

    /// Left in place, even invisible, the title bar takes every click on the top
    /// of a titled window. A hit test stands in for a click: `sendEvent` cannot
    /// press a SwiftUI button, whatever is above it.
    @Test
    func theTitleBarLeavesTheCloseButtonReachable() throws {
        withIsolatedSettings {
            let panel = VocabularyCardPanel()
            panel.alphaValue = 0
            panel.update(entry: VocabularyEntry(original: "猫", translation: "cat"))
            panel.orderFrontRegardless()
            defer {
                panel.orderOut(nil)
                panel.cancelRecall()
            }
            #expect(panel.beginRecall(entries: words(4)))
            settle(panel)

            guard let hosting = panel.contentView, let frame = hosting.superview else {
                Issue.record("card has no content view")
                return
            }
            let closeButton = NSPoint(x: 24, y: panel.frame.height - 24)
            let hit = frame.hitTest(closeButton)

            #expect(hit != nil)
            #expect(hit != hosting)
            #expect(hit?.isDescendant(of: hosting) == true)
        }
    }

    @Test
    func draggingTheTopOfTheReadingCardMovesIt() {
        withIsolatedSettings {
            let panel = VocabularyCardPanel()
            panel.alphaValue = 0
            panel.update(entry: VocabularyEntry(original: "猫", translation: "cat"))
            panel.orderFrontRegardless()
            defer { panel.orderOut(nil) }
            settle(panel)
            let before = panel.frame.origin
            let start = NSPoint(x: panel.frame.width / 2, y: panel.frame.height - 6)

            panel.sendEvent(mouse(.leftMouseDown, at: start, in: panel))
            panel.sendEvent(
                mouse(.leftMouseDragged, at: NSPoint(x: start.x + 40, y: start.y - 30), in: panel))
            panel.sendEvent(
                mouse(.leftMouseUp, at: NSPoint(x: start.x + 40, y: start.y - 30), in: panel))

            #expect(abs(panel.frame.origin.x - (before.x + 40)) < 1)
            #expect(abs(panel.frame.origin.y - (before.y - 30)) < 1)
        }
    }

    @Test
    func theCardKeepsTheSizeItIsGivenAsATitledWindow() {
        withIsolatedSettings {
            let panel = VocabularyCardPanel()
            panel.alphaValue = 0
            panel.update(entry: VocabularyEntry(original: "猫", translation: "cat"))
            // A title bar must not add height, or the content sit below one.
            #expect(panel.contentView?.frame.size == panel.frame.size)
            #expect(panel.styleMask.contains(.titled))
        }
    }

    private func settle(_ panel: NSWindow) {
        panel.contentView?.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.6))
    }

    private func mouse(_ type: NSEvent.EventType, at point: NSPoint, in panel: NSWindow) -> NSEvent
    {
        NSEvent.mouseEvent(
            with: type,
            location: point,
            modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: panel.windowNumber,
            context: nil,
            eventNumber: 0,
            clickCount: 1,
            pressure: 1
        )!
    }

    /// Polls until `condition` holds. A fixed sleep is not usable here: under
    /// load a timer tick arrives late and the whole animation lands at once.
    private func waitUntil(
        _ condition: () -> Bool,
        timeout: TimeInterval = 2
    ) async {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition(), Date() < deadline {
            try? await Task.sleep(for: .milliseconds(20))
        }
    }

    private func words(_ count: Int) -> [VocabularyEntry] {
        (0..<count).map { index in
            VocabularyEntry(original: "word \(index)", translation: "translation \(index)")
        }
    }
}
