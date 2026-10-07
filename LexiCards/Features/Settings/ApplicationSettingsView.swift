import AVFoundation
import AppKit
import SwiftUI

struct ApplicationSettingsView: View {
    @ObservedObject var model: SettingsModel

    // Built once for the process, not per render. A SwiftUI view value is
    // recreated on every published change, and enumerating installed fonts and
    // speech voices on each keystroke of a stepper is far too expensive to do
    // in an initializer.
    private static let fontFamilies = NSFontManager.shared.availableFontFamilies
    private static let voices = AVSpeechSynthesisVoice.speechVoices()
        .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }

    var body: some View {
        Form {
            Section("Card") {
                fontRow(
                    label: "Word",
                    family: $model.wordFontName,
                    size: $model.wordFontSize
                )
                fontRow(
                    label: "Translation",
                    family: $model.translationFontName,
                    size: $model.translationFontSize
                )
            }

            Section("Rotation") {
                HStack {
                    Text("Show each card for")
                    Spacer()
                    Stepper(
                        value: Binding(
                            get: { model.wordInterval },
                            set: {
                                model.wordInterval = $0
                                model.commitInterval()
                            }
                        ),
                        in: 2...300,
                        step: 1
                    ) {
                        Text(intervalLabel(model.wordInterval))
                            .monospacedDigit()
                    }
                }
            }

            Section("Recall") {
                HStack {
                    Text("Recall every")
                    Spacer()
                    Stepper(
                        value: Binding(
                            get: { model.recallInterval / 60 },
                            set: {
                                model.recallInterval = $0 * 60
                                model.commitRecallInterval()
                            }
                        ),
                        in: 1...240,
                        step: 1
                    ) {
                        Text(intervalLabel(model.recallInterval))
                            .monospacedDigit()
                    }
                }

                Text(
                    "Ten words, one at a time. The card pauses, asks for the other side, "
                        + "then returns to the rotation."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Section("Pronunciation") {
                HStack {
                    Picker("Voice", selection: voiceBinding) {
                        Text("Automatic").tag(String?.none)

                        // Every child of a Picker has to be taggable: a bare
                        // Divider between them is matched against the selection
                        // like any other row and brings the picker down.
                        Section {
                            ForEach(Self.voices, id: \.identifier) { voice in
                                Text("\(voice.name) — \(displayLanguage(for: voice))")
                                    .tag(String?.some(voice.identifier))
                            }
                        }
                    }

                    Button("Try") {
                        model.onPreviewVoice?()
                    }
                }

                Text(
                    "Automatic picks a voice from the language detected in the vocabulary itself."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Section("General") {
                Toggle(
                    "Start LexiCards at login",
                    isOn: Binding(
                        get: { model.launchAtLogin },
                        set: { model.setLaunchAtLogin($0) }
                    )
                )
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 520, minHeight: 360)
    }

    private func fontRow(
        label: String,
        family: Binding<String?>,
        size: Binding<Double>
    ) -> some View {
        HStack {
            Picker(
                label,
                selection: Binding(
                    get: { family.wrappedValue },
                    set: {
                        family.wrappedValue = $0
                        model.commitFonts()
                    }
                )
            ) {
                Text("System").tag(String?.none)

                Section {
                    ForEach(Self.fontFamilies, id: \.self) { name in
                        Text(name).tag(String?.some(name))
                    }
                }
            }

            Stepper(
                value: Binding(
                    get: { size.wrappedValue },
                    set: {
                        size.wrappedValue = $0
                        model.commitFonts()
                    }
                ),
                in: 10...72,
                step: 1
            ) {
                Text("\(Int(size.wrappedValue)) pt")
                    .monospacedDigit()
            }
        }
    }

    private var voiceBinding: Binding<String?> {
        Binding(
            get: { model.voiceIdentifier },
            set: {
                model.voiceIdentifier = $0
                model.commitVoice()
            }
        )
    }

    private func intervalLabel(_ interval: TimeInterval) -> String {
        let seconds = Int(interval.rounded())
        guard seconds >= 60 else {
            return "\(seconds) s"
        }

        let minutes = seconds / 60
        let remainder = seconds % 60
        return remainder == 0 ? "\(minutes) min" : "\(minutes) min \(remainder) s"
    }

    private func displayLanguage(for voice: AVSpeechSynthesisVoice) -> String {
        Locale.current.localizedString(forIdentifier: voice.language) ?? voice.language
    }
}
