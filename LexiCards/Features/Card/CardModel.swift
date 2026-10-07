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
    @Published var recall: RecallSession?

    var onFinished: (() -> Void)?
    var onMoveBegan: (() -> Void)?
    var onMoveChanged: ((CGSize) -> Void)?
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
