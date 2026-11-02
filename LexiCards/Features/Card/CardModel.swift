import Combine
import SwiftUI

/// What the floating card is showing.
///
/// The learning card and a recall session share one view tree. Buttons talk to
/// this model; the panel watches `onFinished` and animates the window between
/// the two sizes.
final class CardModel: ObservableObject {
    @Published var entry: VocabularyEntry?
    @Published var emptyText: String
    @Published var wordFont: CardFont
    @Published var translationFont: CardFont
    @Published var recall: RecallSession? {
        didSet {
            // Keep the last face after the session ends. Dropping it here would
            // collapse the window before the shrink back to the learning card.
            if let recall, recall.current != nil {
                displayedRecall = recall
            }
        }
    }

    /// The face still drawn while the window animates back to the learning card.
    @Published var displayedRecall: RecallSession?
    /// Drives the crossfade. Turns off before `displayedRecall` is cleared.
    @Published var recallFaceVisible = false
    /// Edges that stay put while the window animates between faces.
    @Published var heightAnchor: CardHeightAnchor = .bottom
    @Published var widthAnchor: CardWidthAnchor = .trailing

    var onFinished: (() -> Void)?
    var onMoveBegan: (() -> Void)?
    var onMoveChanged: (() -> Void)?
    var onMoveEnded: (() -> Void)?

    var isRecalling: Bool {
        recall?.current != nil
    }

    init(
        entry: VocabularyEntry?,
        emptyText: String,
        wordFont: CardFont,
        translationFont: CardFont
    ) {
        self.entry = entry
        self.emptyText = emptyText
        self.wordFont = wordFont
        self.translationFont = translationFont
    }

    /// Drops the face kept up for the return animation, once the window is
    /// back at the learning size.
    func dismissDisplayedRecall() {
        guard recall == nil else {
            return
        }
        displayedRecall = nil
    }

    func reveal() {
        guard var session = recall, session.current != nil, !session.isRevealed else {
            return
        }

        session.reveal()
        recall = session
    }

    func advance() {
        guard var session = recall, session.current != nil else {
            return
        }

        session.advance()
        if session.current == nil {
            recall = nil
            onFinished?()
        } else {
            recall = session
        }
    }
}
