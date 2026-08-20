import SwiftUI

struct VocabularyCardView: View {
    let entry: VocabularyEntry?
    let emptyText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let entry {
                Text(entry.original)
                    .font(.system(size: 26, weight: .semibold, design: .rounded))
                    .lineLimit(2)

                Text(entry.translation)
                    .font(.system(size: 17, weight: .regular, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            } else {
                Text(emptyText)
                    .font(.system(size: 20, weight: .medium, design: .rounded))
                    .lineLimit(3)
            }
        }
        .padding(18)
        .frame(width: 320, height: 112, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(.white.opacity(0.2))
        }
    }
}
