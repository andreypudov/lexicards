import SwiftUI

/// The learning card and the recall card share one window.
///
/// Switching replaces the face immediately. The window animates its width and
/// height around that change, which is the transition between the two.
struct FloatingCardView: View {
    @ObservedObject var model: CardModel

    var body: some View {
        if let session = model.recall, let prompt = session.current {
            RecallCardView(
                prompt: prompt,
                isRevealed: session.isRevealed,
                index: session.index,
                count: session.prompts.count,
                wordFont: model.wordFont,
                translationFont: model.translationFont,
                onReveal: { model.reveal() },
                onNext: { model.advance() },
                onMoveBegan: { model.onMoveBegan?() },
                onMoveChanged: { model.onMoveChanged?($0) },
                onMoveEnded: { model.onMoveEnded?() }
            )
        } else {
            VocabularyCardView(
                entry: model.entry,
                emptyText: model.emptyText,
                wordFont: model.wordFont,
                translationFont: model.translationFont
            )
        }
    }
}
