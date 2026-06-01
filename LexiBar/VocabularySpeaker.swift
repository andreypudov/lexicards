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

    init() {
        originalLanguageCode = defaultLanguageCode
        translationLanguageCode = defaultLanguageCode
        originalVoice = AVSpeechSynthesisVoice(language: defaultLanguageCode)
        translationVoice = AVSpeechSynthesisVoice(language: defaultLanguageCode)
    }

    func stop() {
        speechSynthesizer.stopSpeaking(at: .immediate)
    }

    func configureLanguages(entries: [VocabularyEntry]) {
        let originalText = entries
            .map(\.original)
            .joined(separator: "\n")
        let translationText = entries
            .map(\.translation)
            .joined(separator: "\n")

        originalLanguageCode = detectLanguageCode(for: originalText)
        translationLanguageCode = detectLanguageCode(for: translationText)
        originalVoice = preferredVoice(for: originalLanguageCode)
        translationVoice = preferredVoice(for: translationLanguageCode)
    }

    func speak(entry: VocabularyEntry) {
        speechSynthesizer.stopSpeaking(at: .immediate)

        let originalUtterance = AVSpeechUtterance(string: entry.original)
        originalUtterance.voice = originalVoice
        speechSynthesizer.speak(originalUtterance)

        let translationUtterance = AVSpeechUtterance(string: entry.translation)
        translationUtterance.preUtteranceDelay = 0.25
        translationUtterance.voice = translationVoice
        speechSynthesizer.speak(translationUtterance)
    }

    private func detectLanguageCode(for text: String) -> String {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        return recognizer.dominantLanguage?.rawValue ?? defaultLanguageCode
    }

    private func preferredVoice(for languageCode: String) -> AVSpeechSynthesisVoice? {
        if let exactVoice = AVSpeechSynthesisVoice(language: languageCode) {
            return exactVoice
        }

        let normalized = Locale(identifier: languageCode)
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
