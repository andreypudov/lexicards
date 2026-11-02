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

            // The hidden title bar still counts its safe area in the fitting size,
            // though the card ignores it.
            let fitting = hosting.fittingSize.height - hosting.safeAreaInsets.top
            #expect(abs(panel.frame.height - fitting) < 1)
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

    /// Text that wraps needs the room for its second line, which is cut off if
    /// the card is measured as though the text ran on in one long line.
    @Test
    func aNarrowerCardIsTallerWhenItsTextWraps() {
        withIsolatedSettings {
            let panel = VocabularyCardPanel()
            let entry = VocabularyEntry(
                original: "a considerably longer word that has to wrap onto two lines of the card",
                translation: "a considerably longer translation that has to wrap onto two lines too"
            )
            panel.update(entry: entry)
            let narrow = panel.frame
            #expect(narrow.width == 320)

            panel.resizeWidth(by: 480, from: narrow, pinning: .trailing)

            #expect(panel.frame.width == 800)
            #expect(panel.frame.height < narrow.height)
        }
    }

    /// The bottom edge normally stays put, but not at the cost of pushing the
    /// top of the card off the screen.
    @Test
    func aTallerEntryAtTheTopOfTheScreenGrowsDownward() {
        withIsolatedSettings {
            guard let visible = NSScreen.main?.visibleFrame else {
                Issue.record("no screen")
                return
            }

            let panel = VocabularyCardPanel()
            panel.update(entry: VocabularyEntry(original: "猫", translation: "cat"))
            panel.setFrameOrigin(
                NSPoint(x: visible.minX + 40, y: visible.maxY - panel.frame.height - 2)
            )
            let short = panel.frame

            panel.update(
                entry: VocabularyEntry(
                    original: "とてもながいことばがここにありますとてもながいことばがここにあります",
                    translation: "a considerably longer translation that should wrap onto two lines"
                )
            )

            #expect(panel.frame.height > short.height)
            #expect(panel.frame.maxY <= visible.maxY)
        }
    }

    /// Unplugging a display can strand the card, whose position AppKit does not
    /// constrain. Bringing it back must not forget where the user had put it:
    /// the display may well come back.
    @Test
    func aCardLeftOffEveryScreenComesBackWithoutForgettingItsPlace() {
        withIsolatedSettings {
            let panel = VocabularyCardPanel()
            let stranded = NSPoint(x: 90_000, y: 90_000)
            panel.setFrameOrigin(stranded)
            #expect(AppSettings.shared.cardWindowOrigin == stranded)

            panel.moveBackOnScreenIfNeeded()

            #expect(NSScreen.screens.contains { $0.visibleFrame.intersects(panel.frame) })
            #expect(AppSettings.shared.cardWindowOrigin == stranded)
        }
    }

    @Test
    func aCardOnScreenStaysWhereItIsWhenDisplaysChange() {
        withIsolatedSettings {
            guard let visible = NSScreen.main?.visibleFrame else {
                Issue.record("no screen")
                return
            }

            let panel = VocabularyCardPanel()
            let origin = NSPoint(x: visible.minX + 40, y: visible.minY + 40)
            panel.setFrameOrigin(origin)

            panel.moveBackOnScreenIfNeeded()

            #expect(panel.frame.origin == origin)
        }
    }

    /// A chosen family has to keep the line's weight. Taken by name alone,
    /// Hiragino Sans is its thinnest face, W0, for the word as well.
    @Test
    func aChosenFontFamilyKeepsTheWeightOfItsLine() throws {
        let family = "Hiragino Sans"
        try #require(NSFontManager.shared.availableFontFamilies.contains(family))

        let word = CardFont(familyName: family, size: 21, weight: .semibold).nsFont
        let translation = CardFont(familyName: family, size: 16, weight: .regular).nsFont

        #expect(word.familyName == family)
        #expect(translation.familyName == family)
        #expect(word.fontName != "HiraginoSans-W0")
        #expect(translation.fontName != "HiraginoSans-W0")
        #expect(word.fontName != translation.fontName)
    }

    @Test
    func aFontFamilyThatIsNoLongerInstalledFallsBackToTheSystemFont() {
        let font = CardFont(familyName: "No Such Family", size: 21, weight: .semibold).nsFont

        #expect(font.pointSize == 21)
        #expect(font.familyName != "No Such Family")
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

    /// The height the card takes has to be the height its text needs at the
    /// card's width. Text layout is the reference rather than a SwiftUI view:
    /// `fittingSize` measures text as one long line whatever the width, so
    /// comparing against it would agree with a card that cuts the text off.
    @Test
    func theCardIsAsTallAsItsWrappedTextNeeds() {
        withIsolatedSettings {
            let panel = VocabularyCardPanel()
            let entry = VocabularyEntry(
                original: "a longer word that has to wrap onto two lines of it",
                translation: "a considerably longer translation that should wrap onto two lines"
            )
            panel.update(entry: entry)

            let textWidth = panel.frame.width - CardFace.inset * 2
            let word = height(of: entry.original, font: .word(from: AppSettings.shared), textWidth)
            let translation = height(
                of: entry.translation, font: .translation(from: AppSettings.shared), textWidth)
            let lineSpacing: CGFloat = 8
            // SwiftUI's line boxes run a little taller than text layout's. A card that
            // cuts off the second lines is some 40 points short.

            #expect(word > CardFont.word(from: AppSettings.shared).lineHeight)
            #expect(
                abs(panel.frame.height - (CardFace.inset * 2 + lineSpacing + word + translation))
                    < 6
            )
        }
    }

    private func height(of text: String, font: CardFont, _ width: CGFloat) -> CGFloat {
        ceil(
            (text as NSString).boundingRect(
                with: CGSize(width: width, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: [.font: font.nsFont]
            ).height
        )
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
