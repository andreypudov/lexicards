import SwiftUI

struct VocabularyCardView: View {
    let entry: VocabularyEntry?
    let emptyText: String
    let animateChanges: Bool

    @State private var displayedEntry: VocabularyEntry?
    @State private var contentOpacity = 1.0

    init(entry: VocabularyEntry?, emptyText: String, animateChanges: Bool = true) {
        self.entry = entry
        self.emptyText = emptyText
        self.animateChanges = animateChanges
        _displayedEntry = State(initialValue: entry)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            content
                .opacity(contentOpacity)
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(.white.opacity(0.2))
        }
        .onChange(of: entry?.displayText) { _ in
            if animateChanges {
                fadeToNewEntry()
            } else {
                displayedEntry = entry
                contentOpacity = 1
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if let displayedEntry {
            VStack(alignment: .leading, spacing: 8) {
                Text(displayedEntry.original)
                    .font(.system(size: 26, weight: .semibold, design: .rounded))
                    .lineLimit(2)
                    .truncationMode(.tail)

                Text(displayedEntry.translation)
                    .font(.system(size: 17, weight: .regular, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .truncationMode(.tail)
            }
        } else {
            Text(emptyText)
                .font(.system(size: 20, weight: .medium, design: .rounded))
                .lineLimit(3)
                .truncationMode(.tail)
        }
    }

    private func fadeToNewEntry() {
        withAnimation(.easeOut(duration: 0.4)) {
            contentOpacity = 0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            displayedEntry = entry

            withAnimation(.easeIn(duration: 0.4)) {
                contentOpacity = 1
            }
        }
    }
}
