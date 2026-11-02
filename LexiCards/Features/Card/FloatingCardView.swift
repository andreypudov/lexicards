import SwiftUI

/// The learning card and the recall card share one window.
///
/// The two faces crossfade while the window changes size. The face sits on the
/// edges the window is holding still: a card on the bottom of the screen keeps
/// its bottom edge and grows upward, instead of the whole card sliding away.
struct FloatingCardView: View {
    @ObservedObject var model: CardModel

    var body: some View {
        ZStack(alignment: contentAlignment) {
            learningCard
                .opacity(model.recallFaceVisible ? 0 : 1)

            if let session = model.displayedRecall, let prompt = session.current {
                recallCard(session, prompt: prompt)
                    .opacity(model.recallFaceVisible ? 1 : 0)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: contentAlignment)
        .animation(nil, value: contentAlignment)
        .animation(.easeInOut(duration: CardMotion.duration), value: model.recallFaceVisible)
        // The hidden title bar still reserves its height as a safe area.
        .ignoresSafeArea()
    }

    private var learningCard: some View {
        VocabularyCardView(
            entry: model.entry,
            emptyText: model.emptyText,
            wordFont: model.wordFont,
            translationFont: model.translationFont
        )
    }

    private func recallCard(_ session: RecallSession, prompt: RecallPrompt) -> some View {
        RecallCardView(
            prompt: prompt,
            isRevealed: session.isRevealed,
            index: session.index,
            count: session.prompts.count,
            wordFont: model.wordFont,
            translationFont: model.translationFont,
            onReveal: { model.reveal() },
            onNext: { model.advance() },
            onReplay: { model.replay() },
            onCancel: { model.cancel() },
            onMoveBegan: { model.onMoveBegan?() },
            onMoveChanged: { model.onMoveChanged?() },
            onMoveEnded: { model.onMoveEnded?() }
        )
    }

    private var contentAlignment: Alignment {
        Alignment(
            horizontal: model.widthAnchor == .leading ? .leading : .trailing,
            vertical: model.heightAnchor == .top ? .top : .bottom
        )
    }
}
