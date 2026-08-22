import AppKit
import Foundation
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

    @Test
    func widthIsLeftAloneWhenTheHeightIsDerived() {
        withIsolatedSettings {
            let panel = VocabularyCardPanel()
            let width = panel.frame.width

            panel.update(entry: VocabularyEntry(original: "猫", translation: "cat"))

            #expect(panel.frame.width == width)
        }
    }
}
