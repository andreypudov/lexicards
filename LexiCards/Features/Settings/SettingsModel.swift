import Combine
import Foundation

/// State behind the settings window, and the seam between it and the rest of the
/// app.
///
/// The window never reaches into the vocabulary or speech services directly: it
/// changes values here, and the coordinator supplies the closures that act on
/// them — the same arrangement `MenuBarController` uses for the menu.
final class SettingsModel: ObservableObject {
    @Published var selectedTab: SettingsTab = .vocabulary
    @Published var sources: [VocabularySource] = []
    @Published var selectedSourceID: String?
    @Published var entries: [VocabularyEntryRow] = []

    @Published var wordFontName: String?
    @Published var wordFontSize: Double
    @Published var translationFontName: String?
    @Published var translationFontSize: Double

    @Published var voiceIdentifier: String?
    @Published var wordInterval: TimeInterval
    @Published var recallInterval: TimeInterval
    @Published var launchAtLogin: Bool

    var onSelectSource: ((VocabularySource) -> Void)?
    var onAddUserVocabulary: (() -> Void)?
    var onRemoveSource: ((VocabularySource) -> Void)?
    var onFontsChanged: (() -> Void)?
    var onVoiceChanged: (() -> Void)?
    var onIntervalChanged: (() -> Void)?
    var onRecallIntervalChanged: (() -> Void)?
    var onPreviewVoice: (() -> Void)?
    var onSetLaunchAtLogin: ((Bool) -> Void)?

    init() {
        let settings = AppSettings.shared
        wordFontName = settings.wordFontName
        wordFontSize = settings.wordFontSize
        translationFontName = settings.translationFontName
        translationFontSize = settings.translationFontSize
        voiceIdentifier = settings.voiceIdentifier
        wordInterval = settings.wordInterval
        recallInterval = settings.recallInterval
        launchAtLogin = false
    }

    var selectedSource: VocabularySource? {
        sources.first { $0.id == selectedSourceID }
    }

    func selectSource(id: String) {
        selectedSourceID = id
        guard let source = sources.first(where: { $0.id == id }) else { return }
        onSelectSource?(source)
    }

    /// Persisting is immediate; telling the rest of the app is deferred by one
    /// runloop turn.
    ///
    /// These run from inside a `Binding` setter, which SwiftUI calls in the
    /// middle of a view update. The card lives in its own hosting view, and
    /// rebuilding it right there mutates one view tree while another is still
    /// updating.
    ///
    /// The turn has to be scheduled in the *common* modes. A `Picker` selection
    /// arrives while its `NSMenu` is tracking, and `DispatchQueue.main.async`
    /// runs only in the default mode — so the card would not repaint until the
    /// next default-mode turn, which is the rotation timer firing. That is the
    /// difference between the font changing now and changing at the next card.
    func commitFonts() {
        let settings = AppSettings.shared
        settings.wordFontName = wordFontName
        settings.wordFontSize = wordFontSize
        settings.translationFontName = translationFontName
        settings.translationFontSize = translationFontSize

        notifySoon(onFontsChanged)
    }

    func commitVoice() {
        AppSettings.shared.voiceIdentifier = voiceIdentifier

        notifySoon(onVoiceChanged)
    }

    func commitInterval() {
        AppSettings.shared.wordInterval = wordInterval
        notifySoon(onIntervalChanged)
    }

    func commitRecallInterval() {
        AppSettings.shared.recallInterval = recallInterval
        notifySoon(onRecallIntervalChanged)
    }

    func setLaunchAtLogin(_ isEnabled: Bool) {
        onSetLaunchAtLogin?(isEnabled)
    }

    private func notifySoon(_ notify: (() -> Void)?) {
        guard let notify else { return }
        RunLoop.main.perform(inModes: [.common]) { notify() }
    }
}
