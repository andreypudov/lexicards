import SwiftUI

struct VocabularyCardView: View {
    let entry: VocabularyEntry?
    let emptyText: String

    init(entry: VocabularyEntry?, emptyText: String) {
        self.entry = entry
        self.emptyText = emptyText
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            content
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
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
                    .font(.system(size: 26, weight: .semibold, design: .rounded))
                    .lineLimit(2)
                    .truncationMode(.tail)

                Text(entry.translation)
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
}
