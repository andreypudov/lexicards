import SwiftUI

/// The exam face of the floating card.
///
/// The question stays on top. A question mark holds the line under it until
/// Reveal replaces that mark with the answer. Both lines use the same fonts as
/// the reading card. Next moves on, and the close button leaves the session.
struct RecallCardView: View {
    let prompt: RecallPrompt
    let isRevealed: Bool
    let index: Int
    let count: Int
    let wordFont: CardFont
    let translationFont: CardFont
    var onReveal: () -> Void = {}
    var onNext: () -> Void = {}
    var onReplay: () -> Void = {}
    var onCancel: () -> Void = {}
    var onMoveBegan: () -> Void = {}
    var onMoveChanged: () -> Void = {}
    var onMoveEnded: () -> Void = {}

    @State private var moveStarted = false
    /// Survives the view update that starts a drag. A press that moved the card
    /// must not also activate Reveal or Next: the card follows the pointer, so
    /// the button is still under it when the mouse comes up.
    @State private var clickGate = ClickGate()

    var body: some View {
        VStack(spacing: 16) {
            Text("\(index + 1) of \(count)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .frame(maxWidth: .infinity)
                // Overlays, so the buttons never change the measured size.
                .overlay(alignment: .leading) {
                    cancelButton
                }
                .overlay(alignment: .trailing) {
                    replayButton
                }

            VStack(spacing: 8) {
                textLine(prompt.prompt, font: font(forOriginal: prompt.showsOriginalFirst))

                textLine(
                    isRevealed ? prompt.answer : "?",
                    font: font(forOriginal: !prompt.showsOriginalFirst)
                )
                .foregroundStyle(.secondary)
            }

            Button(isRevealed ? "Next" : "Reveal") {
                guard !clickGate.dragged else {
                    return
                }

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
    ///
    /// The gesture only decides that a drag has started. How far the pointer
    /// has moved is read from the screen, because this view's own translation
    /// shrinks once the window begins to follow it.
    private var moveGesture: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { _ in
                if !moveStarted {
                    moveStarted = true
                    clickGate.dragged = true
                    onMoveBegan()
                }
                onMoveChanged()
            }
            .onEnded { _ in
                moveStarted = false
                onMoveEnded()
                let gate = clickGate
                DispatchQueue.main.async {
                    gate.dragged = false
                }
            }
    }

    private var replayButton: some View {
        Button {
            guard !clickGate.dragged else {
                return
            }
            onReplay()
        } label: {
            Image(systemName: "speaker.wave.2")
                .font(.caption)
        }
        .buttonStyle(.borderless)
        .foregroundStyle(.secondary)
        .help("Pronounce \(prompt.wordToPronounce(isRevealed: isRevealed).text)")
        .accessibilityLabel("Pronounce")
    }

    private var cancelButton: some View {
        Button {
            guard !clickGate.dragged else {
                return
            }
            onCancel()
        } label: {
            Image(systemName: "xmark")
                .font(.caption)
        }
        .buttonStyle(.borderless)
        .foregroundStyle(.secondary)
        .help("End Recall")
        .accessibilityLabel("End Recall")
    }

    /// Holds the "this press became a drag" bit without publishing a view update.
    private final class ClickGate {
        var dragged = false
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
