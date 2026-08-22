import SwiftUI

struct VocabularySettingsView: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                // The stock Picker: its Section headers are labels rather than
                // rows, so "Built-in" and "Added" cannot be selected. It sizes
                // to its content and sits next to the label; the buttons keep
                // the trailing edge.
                Picker("Vocabulary", selection: selectionBinding) {
                    if model.sources.isEmpty {
                        Text("No vocabularies").tag(String?.none)
                    }

                    let builtIn = model.sources.filter { $0.kind == .builtIn }
                    if !builtIn.isEmpty {
                        Section("Built-in") {
                            ForEach(builtIn) { source in
                                Text(source.name).tag(String?.some(source.id))
                            }
                        }
                    }

                    let userSources = model.sources.filter { $0.kind == .user }
                    if !userSources.isEmpty {
                        Section("Added") {
                            ForEach(userSources) { source in
                                Text(source.name).tag(String?.some(source.id))
                            }
                        }
                    }
                }
                .fixedSize()
                .disabled(model.sources.isEmpty)

                Spacer(minLength: 12)

                Button("Add CSV…") {
                    model.onAddUserVocabulary?()
                }

                Button("Remove") {
                    if let source = model.selectedSource {
                        model.onRemoveSource?(source)
                    }
                }
                .disabled(model.selectedSource?.kind != .user)
            }

            entryTable

            Text(model.entries.count == 1 ? "1 entry" : "\(model.entries.count) entries")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(minWidth: 520, minHeight: 360)
    }

    private var selectionBinding: Binding<String?> {
        Binding(
            get: { model.selectedSourceID },
            set: { newValue in
                guard let newValue else { return }
                model.selectSource(id: newValue)
            }
        )
    }

    /// Read-only for now: editing a vocabulary in place is a documented
    /// limitation, so the table shows what was loaded rather than pretending to
    /// be a source of truth.
    private var entryTable: some View {
        Table(model.entries) {
            TableColumn("Original") { entry in
                Text(entry.original)
            }
            TableColumn("Translation") { entry in
                Text(entry.translation)
            }
        }
        .frame(minHeight: 240)
    }

}
