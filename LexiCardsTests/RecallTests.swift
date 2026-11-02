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

        var replayed: VocabularyEntry?
        model.onReplay = { replayed = $0 }
        model.replay()
        #expect(replayed == second?.entry)
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
        #expect(abs(panel.frame.height - recall.height) < 1)

        try? await Task.sleep(for: .milliseconds(80))
        let early = panel.frame.height
        #expect(early < recall.height - 1)
        #expect(early > learning.height + span * 0.5)

        try? await Task.sleep(for: .milliseconds(400))
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

        try? await Task.sleep(for: .milliseconds(80))
        #expect(panel.beginRecall(entries: words(4)))
        try? await Task.sleep(for: .milliseconds(500))
        panel.cancelRecall()
        try? await Task.sleep(for: .milliseconds(500))

        #expect(abs(panel.frame.height - learning.height) < 1)
        #expect(abs(panel.frame.width - learning.width) < 1)
        panel.orderOut(nil)
    }

    @Test
    func pressingTheCardWhileItGrowsFinishesTheGrowth() async {
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
        try? await Task.sleep(for: .milliseconds(80))
        #expect(panel.frame.height < recall.height - 1)

        panel.rememberRecallPress(at: NSEvent.mouseLocation)
        panel.finishRecallPress()
        #expect(abs(panel.frame.height - recall.height) < 1)
        #expect(panel.frame.height > learning.height)

        panel.orderOut(nil)
        panel.cancelRecall()
    }

    private func words(_ count: Int) -> [VocabularyEntry] {
        (0..<count).map { index in
            VocabularyEntry(original: "word \(index)", translation: "translation \(index)")
        }
    }
}
