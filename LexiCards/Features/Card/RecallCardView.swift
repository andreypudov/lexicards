import SwiftUI

/// The exam face of the floating card.
///
/// The question stays on top. A question mark holds the line under it until
/// Reveal replaces that mark with the answer. Both lines use the same fonts as
/// the reading card. Next moves on.
struct RecallCardView: View {
    let prompt: RecallPrompt
    let isRevealed: Bool
    let index: Int
    let count: Int
    let wordFont: CardFont
    let translationFont: CardFont
    var onReveal: () -> Void = {}
    var onNext: () -> Void = {}
    var onMoveBegan: () -> Void = {}
    var onMoveChanged: (CGSize) -> Void = { _ in }
    var onMoveEnded: () -> Void = {}

    @State private var moveStarted = false

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 6) {
                ProgressView(value: Double(index + 1), total: Double(max(count, 1)))
                    .progressViewStyle(.linear)

                Text("\(index + 1) of \(count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .frame(maxWidth: .infinity)

            VStack(spacing: 8) {
                textLine(prompt.prompt, font: font(forOriginal: prompt.showsOriginalFirst))

                textLine(
                    isRevealed ? prompt.answer : "?",
                    font: font(forOriginal: !prompt.showsOriginalFirst)
                )
                .foregroundStyle(.secondary)
            }

            Button(isRevealed ? "Next" : "Reveal") {
                if isRevealed {
                    onNext()
                } else {
                    onReveal()
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .frame(maxWidth: .infinity)
        }
        .padding(CardFace.inset)
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .gesture(moveGesture)
        .cardFace()
    }

    /// A short press stays a button click. Movement past that drags the card,
    /// the same way the reading card moves when it has nothing to press.
    private var moveGesture: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                if !moveStarted {
                    moveStarted = true
                    onMoveBegan()
                }
                onMoveChanged(value.translation)
            }
            .onEnded { _ in
                moveStarted = false
                onMoveEnded()
            }
    }

    /// One line, as tall as the larger of the two card fonts, so Reveal and the
    /// next word swap text without the card needing a new height.
    private func textLine(_ text: String, font: Font) -> some View {
        Text(text)
            .font(font)
            .lineLimit(1)
            .truncationMode(.tail)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, minHeight: reservedLineHeight)
    }

    private var reservedLineHeight: CGFloat {
        max(wordFont.lineHeight, translationFont.lineHeight)
    }

    private func font(forOriginal isOriginal: Bool) -> Font {
        isOriginal ? wordFont.resolved : translationFont.resolved
    }
}
