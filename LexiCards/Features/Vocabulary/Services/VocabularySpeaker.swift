import AVFoundation
import Foundation
import NaturalLanguage

final class VocabularySpeaker {
    private let speechSynthesizer = AVSpeechSynthesizer()
    private let defaultLanguageCode = AppSettings.shared.defaultLanguageCode
    private var originalLanguageCode: String
    private var translationLanguageCode: String
    private var originalVoice: AVSpeechSynthesisVoice?
    private var translationVoice: AVSpeechSynthesisVoice?

    /// A voice chosen explicitly in settings. While it is set it speaks both
    /// halves of a card; clearing it restores the per-language voices picked
    /// from the vocabulary's own detected languages.
    private var preferredVoice: AVSpeechSynthesisVoice?

    init() {
        originalLanguageCode = defaultLanguageCode
        translationLanguageCode = defaultLanguageCode
        originalVoice = AVSpeechSynthesisVoice(language: defaultLanguageCode)
        translationVoice = AVSpeechSynthesisVoice(language: defaultLanguageCode)
        applyVoicePreference()
    }

    func stop() {
        speechSynthesizer.stopSpeaking(at: .immediate)
    }

    /// Re-reads the configured voice. Called after settings change so a new
    /// choice takes effect on the next card rather than the next launch.
    func applyVoicePreference() {
        guard let identifier = AppSettings.shared.voiceIdentifier else {
            preferredVoice = nil
            return
        }

        preferredVoice = AVSpeechSynthesisVoice(identifier: identifier)
    }

    func configureLanguages(entries: [VocabularyEntry]) {
        let originalText =
            entries
            .map(\.original)
            .joined(separator: "\n")
        let translationText =
            entries
            .map(\.translation)
            .joined(separator: "\n")

        originalLanguageCode = detectLanguageCode(for: originalText)
        translationLanguageCode = detectLanguageCode(for: translationText)
        originalVoice = voice(for: originalLanguageCode)
        translationVoice = voice(for: translationLanguageCode)
    }

    func speak(entry: VocabularyEntry) {
        speechSynthesizer.stopSpeaking(at: .immediate)

        let originalUtterance = AVSpeechUtterance(string: entry.original)
        originalUtterance.voice = preferredVoice ?? originalVoice
        speechSynthesizer.speak(originalUtterance)

        let translationUtterance = AVSpeechUtterance(string: entry.translation)
        translationUtterance.preUtteranceDelay = 0.25
        translationUtterance.voice = preferredVoice ?? translationVoice
        speechSynthesizer.speak(translationUtterance)
    }

    /// Speaks a sample so a voice can be auditioned from settings before it is
    /// committed to, without waiting for the next card.
    func preview(voiceIdentifier: String?, text: String) {
        speechSynthesizer.stopSpeaking(at: .immediate)

        let utterance = AVSpeechUtterance(string: text)
        if let voiceIdentifier {
            utterance.voice = AVSpeechSynthesisVoice(identifier: voiceIdentifier)
        } else {
            utterance.voice = originalVoice
        }

        speechSynthesizer.speak(utterance)
    }

    private func detectLanguageCode(for text: String) -> String {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        return recognizer.dominantLanguage?.rawValue ?? defaultLanguageCode
    }

    private func voice(for languageCode: String) -> AVSpeechSynthesisVoice? {
        if let exactVoice = AVSpeechSynthesisVoice(language: languageCode) {
            return exactVoice
        }

        let normalized =
            Locale(identifier: languageCode)
            .language
            .languageCode?
            .identifier

        guard let normalized else {
            return AVSpeechSynthesisVoice(language: defaultLanguageCode)
        }

        let fallbackVoice = AVSpeechSynthesisVoice.speechVoices().first {
            Locale(identifier: $0.language)
                .language
                .languageCode?
                .identifier == normalized
        }

        return fallbackVoice ?? AVSpeechSynthesisVoice(language: defaultLanguageCode)
    }
}
