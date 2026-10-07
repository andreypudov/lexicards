import AppKit
import Foundation
import SwiftUI
import Testing

@testable import LexiCards

/// The card's inset has to read the same on every side.
///
/// It always was 18pt on all four sides, but the window kept a fixed height and
/// centred the text in it, so the leftover space was spent above and below and
/// the card looked vertically roomier than it was. The height now follows the
/// content, which makes the padding the only vertical space there is.
@MainActor
@Suite(.serialized)
struct CardLayoutTests {
    @Test
    func heightFollowsTheContentRatherThanAFixedSize() {
        withIsolatedSettings {
            let panel = VocabularyCardPanel()
            panel.update(entry: VocabularyEntry(original: "猫", translation: "cat"))

            guard let hosting = panel.contentView as? MovableHostingView else {
                Issue.record("card has no hosting view")
                return
            }

            #expect(abs(panel.frame.height - hosting.fittingSize.height) < 1)
        }
    }

    /// The card rests in a corner, so resizing must hold the bottom-left and
    /// grow upward. `setContentSize` pins the top-left instead, which walked the
    /// card up the screen every time it shrank.
    @Test
    func resizingHoldsTheBottomLeftCorner() {
        withIsolatedSettings {
            let panel = VocabularyCardPanel()
            panel.setFrameOrigin(NSPoint(x: 400, y: 120))

            panel.update(entry: VocabularyEntry(original: "猫", translation: "cat"))
            let afterShort = panel.frame

            panel.update(
                entry: VocabularyEntry(
                    original: "とてもながいことばがここにあります",
                    translation: "a considerably longer translation that should wrap onto two lines"
                )
            )
            let afterLong = panel.frame

            #expect(afterShort.origin.x == 400)
            #expect(afterShort.origin.y == 120)
            #expect(afterLong.origin.x == 400)
            #expect(afterLong.origin.y == 120)
        }
    }

    @Test
    func aTallerEntryMakesATallerCard() {
        withIsolatedSettings {
            let panel = VocabularyCardPanel()

            panel.update(entry: VocabularyEntry(original: "猫", translation: "cat"))
            let shortHeight = panel.frame.height

            panel.apply(
                wordFont: CardFont(familyName: nil, size: 48, weight: .semibold),
                translationFont: CardFont(familyName: nil, size: 32, weight: .regular)
            )
            let tallHeight = panel.frame.height

            #expect(tallHeight > shortHeight)
        }
    }

    /// Recall measures the next reading card beside the live one, so the window
    /// can take the new height without waiting on the view that is still on
    /// screen. That measurement has to agree with the height the card itself
    /// settles on.
    @Test
    func anOffscreenMeasurementMatchesTheLaidOutCard() {
        withIsolatedSettings {
            let panel = VocabularyCardPanel()
            let entry = VocabularyEntry(
                original: "とてもながいことばがここにあります",
                translation: "a considerably longer translation that should wrap onto two lines"
            )
            panel.update(entry: entry)

            let probe = NSHostingView(
                rootView: VocabularyCardView(
                    entry: entry,
                    emptyText: AppSettings.shared.emptyVocabularyText,
                    wordFont: .word(from: AppSettings.shared),
                    translationFont: .translation(from: AppSettings.shared)
                )
            )
            let window = NSWindow(
                contentRect: NSRect(
                    x: -10_000, y: -10_000, width: panel.frame.width, height: 2_000),
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            window.contentView = probe
            probe.layoutSubtreeIfNeeded()

            #expect(abs(probe.fittingSize.height - panel.frame.height) < 1)
        }
    }

    @Test
    func widthIsLeftAloneWhenTheHeightIsDerived() {
        withIsolatedSettings {
            let panel = VocabularyCardPanel()
            let width = panel.frame.width

            panel.update(entry: VocabularyEntry(original: "猫", translation: "cat"))

            #expect(panel.frame.width == width)
        }
    }

    /// Dragging a side changes the width and leaves the opposite side where it
    /// was. The bottom stays put too, so a reflow that changes the height grows
    /// upward, the same way a longer entry does.
    @Test
    func draggingTheTrailingEdgeWidensWithoutMovingTheLeadingEdge() {
        withIsolatedSettings {
            let panel = VocabularyCardPanel()
            panel.setFrameOrigin(NSPoint(x: 400, y: 120))
            panel.update(entry: VocabularyEntry(original: "猫", translation: "cat"))
            let start = panel.frame

            panel.resizeWidth(by: 80, from: start, pinning: .trailing)

            #expect(panel.frame.width == start.width + 80)
            #expect(panel.frame.origin.x == start.origin.x)
            #expect(panel.frame.origin.y == start.origin.y)
            #expect(AppSettings.shared.cardWindowSize?.width == panel.frame.width)
        }
    }

    @Test
    func draggingTheLeadingEdgeHoldsTheTrailingEdgeStill() {
        withIsolatedSettings {
            let panel = VocabularyCardPanel()
            panel.setFrameOrigin(NSPoint(x: 400, y: 120))
            let start = panel.frame

            panel.resizeWidth(by: -60, from: start, pinning: .leading)

            #expect(panel.frame.width == start.width + 60)
            #expect(panel.frame.maxX == start.maxX)
            #expect(panel.frame.origin.y == start.origin.y)
        }
    }

    @Test
    func widthStaysInsideTheAllowedRange() {
        withIsolatedSettings {
            let panel = VocabularyCardPanel()
            let start = panel.frame

            panel.resizeWidth(by: -10_000, from: start, pinning: .trailing)
            #expect(panel.frame.width == VocabularyCardPanel.minimumWidth)

            panel.resizeWidth(by: 10_000, from: start, pinning: .trailing)
            #expect(panel.frame.width == VocabularyCardPanel.maximumWidth)
        }
    }

    @Test
    func theSideMarginsResizeAndTheMiddleMoves() {
        let model = CardModel(
            entry: nil,
            emptyText: "LexiCards",
            wordFont: CardFont(familyName: nil, size: 21, weight: .semibold),
            translationFont: CardFont(familyName: nil, size: 16, weight: .regular)
        )
        let view = MovableHostingView(rootView: FloatingCardView(model: model))
        view.frame = NSRect(x: 0, y: 0, width: 320, height: 112)

        #expect(view.horizontalEdge(at: NSPoint(x: 4, y: 40)) == .leading)
        #expect(view.horizontalEdge(at: NSPoint(x: 316, y: 40)) == .trailing)
        #expect(view.horizontalEdge(at: NSPoint(x: 160, y: 40)) == nil)
    }
}
