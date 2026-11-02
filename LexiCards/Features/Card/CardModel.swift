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
    /// A side of the current recall card came into view: the prompt when the
    /// card appears, the answer on Reveal. `isOriginal` says which side it is.
    var onRecallTextShown: ((_ text: String, _ isOriginal: Bool) -> Void)?
    /// The replay button on the recall card was pressed.
    var onReplay: ((VocabularyEntry) -> Void)?
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
        if let prompt = session.current {
            onRecallTextShown?(prompt.answer, !prompt.showsOriginalFirst)
        }
    }

    /// Reports the prompt of the current card, which has just come into view.
    func announcePrompt() {
        guard let prompt = recall?.current else {
            return
        }

        onRecallTextShown?(prompt.prompt, prompt.showsOriginalFirst)
    }

    func replay() {
        guard let prompt = recall?.current else {
            return
        }

        onReplay?(prompt.entry)
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
            announcePrompt()
        }
    }
}
