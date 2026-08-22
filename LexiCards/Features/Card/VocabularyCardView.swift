import SwiftUI

struct VocabularyCardView: View {
    let entry: VocabularyEntry?
    let emptyText: String
    let wordFont: CardFont
    let translationFont: CardFont

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            content
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(.white.opacity(0.2))
        }
    }

    @ViewBuilder
    private var content: some View {
        if let entry {
            VStack(alignment: .leading, spacing: 8) {
                Text(entry.original)
                    .font(wordFont.resolved)
                    .lineLimit(2)
                    .truncationMode(.tail)

                Text(entry.translation)
                    .font(translationFont.resolved)
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
}
