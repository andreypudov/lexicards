import AppKit
import ServiceManagement
import UniformTypeIdentifiers
import os

final class AppCoordinator {
    private let vocabularyController = VocabularyController()
    private let vocabularyFileAccess = VocabularyFileAccess()
    private let vocabularyLibrary = VocabularyLibrary()
    private let vocabularySpeaker = VocabularySpeaker()
    private let vocabularyCardPanel = VocabularyCardPanel()
    private let menuBarController = MenuBarController()
    private let settingsModel = SettingsModel()
    private lazy var settingsWindowController = SettingsWindowController(model: settingsModel)
    private var timer: Timer?
    private var recallTimer: Timer?
    private var isPronunciationEnabled = AppSettings.shared.pronunciationEnabled
    private var isCardVisible = AppSettings.shared.cardVisible

    func start() {
        configureMenuBar()
        configureSettings()
        vocabularyCardPanel.restorePositionOrMoveToLowerRightCorner()

        if restoreSelectedVocabulary() {
            configureLoadedVocabulary()
        } else {
            showNextWord()
        }

        if isCardVisible {
            vocabularyCardPanel.orderFrontRegardless()
        }

        startWordTimer()
        startRecallTimer()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        recallTimer?.invalidate()
        recallTimer = nil
        vocabularyFileAccess.stopAccessing()
    }

    private func configureMenuBar() {
        menuBarController.onOpenVocabulary = { [weak self] in
            self?.openSettings(on: .vocabulary)
        }
        menuBarController.onOpenSettings = { [weak self] in
            self?.openSettings(on: .application)
        }
        menuBarController.onToggleCard = { [weak self] in
            self?.toggleCard()
        }
        menuBarController.onStartRecall = { [weak self] in
            self?.beginRecall(showingCard: true)
        }
        menuBarController.onTogglePronunciation = { [weak self] in
            self?.togglePronunciation()
        }
        menuBarController.onQuit = {
            NSApp.terminate(nil)
        }
        menuBarController.update(
            isCardVisible: isCardVisible,
            isPronunciationEnabled: isPronunciationEnabled
        )
    }

    private func configureSettings() {
        settingsModel.onSelectSource = { [weak self] source in
            self?.selectVocabulary(source)
        }
        settingsModel.onAddUserVocabulary = { [weak self] in
            self?.openVocabulary()
        }
        settingsModel.onRemoveSource = { [weak self] source in
            self?.removeVocabulary(source)
        }
        settingsModel.onFontsChanged = { [weak self] in
            self?.applyCardFonts()
        }
        settingsModel.onVoiceChanged = { [weak self] in
            self?.vocabularySpeaker.applyVoicePreference()
        }
        settingsModel.onIntervalChanged = { [weak self] in
            self?.startWordTimer()
        }
        settingsModel.onRecallIntervalChanged = { [weak self] in
            self?.startRecallTimer()
        }
        vocabularyCardPanel.onRecallFinished = { [weak self] in
            self?.startWordTimer()
        }
        settingsModel.onPreviewVoice = { [weak self] in
            self?.previewVoice()
        }
        settingsModel.onSetLaunchAtLogin = { [weak self] isEnabled in
            self?.setLaunchAtLogin(isEnabled)
        }
    }

    private func applyCardFonts() {
        vocabularyCardPanel.apply(
            wordFont: .word(from: AppSettings.shared),
            translationFont: .translation(from: AppSettings.shared)
        )
    }

    private func openSettings(on tab: SettingsTab) {
        refreshSettingsModel()
        settingsModel.selectedTab = tab
        settingsWindowController.show()
    }

    private func refreshSettingsModel() {
        settingsModel.sources = vocabularyLibrary.sources()
        settingsModel.selectedSourceID = AppSettings.shared.selectedVocabularyIdentifier
        settingsModel.entries = VocabularyEntryRow.rows(from: vocabularyController.allEntries)
        settingsModel.wordInterval = AppSettings.shared.wordInterval
        settingsModel.recallInterval = AppSettings.shared.recallInterval
        settingsModel.launchAtLogin = isLaunchAtLoginEnabled()
    }

    // MARK: - Vocabulary

    /// Restores the vocabulary chosen in settings, falling back to whatever file
    /// was open last so an install that predates the library still reopens it.
    private func restoreSelectedVocabulary() -> Bool {
        if let identifier = AppSettings.shared.selectedVocabularyIdentifier,
            let source = vocabularyLibrary.source(withIdentifier: identifier),
            vocabularyFileAccess.load(from: source.url, into: vocabularyController)
        {
            return true
        }

        // An install predating the library, or a selection whose file has since
        // moved. Adopt whatever was open last into the library so the settings
        // dropdown names what is actually playing rather than a stale choice.
        if vocabularyFileAccess.restoreLast(into: vocabularyController) {
            if let path = AppSettings.shared.lastVocabularyPath {
                let restored = URL(fileURLWithPath: path)
                let adopted = vocabularyLibrary.addUserSource(at: restored)
                AppSettings.shared.selectedVocabularyIdentifier = adopted?.id ?? path
            }

            return true
        }

        // First run: the app ships with vocabularies, so start on one instead of
        // showing the empty-state text until the user goes looking for settings.
        guard let firstBuiltIn = vocabularyLibrary.builtInSources().first,
            vocabularyFileAccess.load(from: firstBuiltIn.url, into: vocabularyController)
        else {
            AppLog.vocabulary.error("No built-in vocabulary could be loaded on first run")
            return false
        }

        AppSettings.shared.selectedVocabularyIdentifier = firstBuiltIn.id
        return true
    }

    private func selectVocabulary(_ source: VocabularySource) {
        guard vocabularyFileAccess.load(from: source.url, into: vocabularyController) else {
            AppLog.vocabulary.error(
                "Could not open vocabulary: \(source.name, privacy: .public)"
            )
            NSSound.beep()
            return
        }

        AppSettings.shared.selectedVocabularyIdentifier = source.id
        if vocabularyCardPanel.isRecalling {
            vocabularyCardPanel.cancelRecall()
        }
        configureLoadedVocabulary()
        refreshSettingsModel()
    }

    private func removeVocabulary(_ source: VocabularySource) {
        guard source.kind == .user else { return }

        vocabularyLibrary.removeUserSource(source)
        if AppSettings.shared.selectedVocabularyIdentifier == source.id {
            AppSettings.shared.selectedVocabularyIdentifier = nil
        }

        refreshSettingsModel()
    }

    private func openVocabulary() {
        let panel = NSOpenPanel()
        panel.title = "Open Vocabulary"
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.commaSeparatedText, .plainText]

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        guard let source = vocabularyLibrary.addUserSource(at: url) else {
            AppLog.vocabulary.error(
                "Could not add the selected vocabulary: \(url.lastPathComponent, privacy: .public)"
            )
            NSSound.beep()
            return
        }

        selectVocabulary(source)
    }

    private func configureLoadedVocabulary() {
        vocabularySpeaker.configureLanguages(entries: vocabularyController.allEntries)
        showNextWord()
    }

    // MARK: - Card and rotation

    private func startWordTimer() {
        let interval = AppSettings.shared.wordInterval

        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.showNextWord()
            }
        }
    }

    private func startRecallTimer() {
        recallTimer?.invalidate()
        let interval = AppSettings.shared.recallInterval
        recallTimer = Timer.scheduledTimer(
            withTimeInterval: interval,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor in
                self?.beginRecall(showingCard: false)
            }
        }
    }

    /// Pauses the reading rotation and turns the same card into a recall session.
    /// The timer leaves a hidden card alone. Recall Now shows the card first.
    private func beginRecall(showingCard: Bool) {
        guard !vocabularyCardPanel.isRecalling else {
            return
        }

        if !isCardVisible {
            guard showingCard else {
                return
            }
            isCardVisible = true
            AppSettings.shared.cardVisible = true
            menuBarController.setCardVisible(true)
            vocabularyCardPanel.orderFrontRegardless()
        }

        guard vocabularyCardPanel.beginRecall(entries: vocabularyController.allEntries) else {
            return
        }

        vocabularySpeaker.stop()
        timer?.invalidate()
        timer = nil
    }

    private func showNextWord() {
        vocabularyController.nextRandom()
        let entry = vocabularyController.currentEntry

        vocabularyCardPanel.update(entry: entry)

        guard isPronunciationEnabled, let entry else {
            return
        }
        vocabularySpeaker.speak(entry: entry)
    }

    private func toggleCard() {
        isCardVisible.toggle()
        AppSettings.shared.cardVisible = isCardVisible
        menuBarController.setCardVisible(isCardVisible)

        if isCardVisible {
            vocabularyCardPanel.orderFrontRegardless()
        } else {
            vocabularyCardPanel.orderOut(nil)
        }
    }

    // MARK: - Pronunciation

    private func togglePronunciation() {
        isPronunciationEnabled.toggle()
        AppSettings.shared.pronunciationEnabled = isPronunciationEnabled
        menuBarController.setPronunciationEnabled(isPronunciationEnabled)

        guard isPronunciationEnabled else {
            vocabularySpeaker.stop()
            return
        }

        if let entry = vocabularyController.currentEntry {
            vocabularySpeaker.speak(entry: entry)
        }
    }

    /// Auditions the voice on the card that is showing, so the sample is in the
    /// language being learned rather than a canned phrase.
    private func previewVoice() {
        let sample = vocabularyController.currentEntry?.original ?? "LexiCards"
        vocabularySpeaker.preview(
            voiceIdentifier: AppSettings.shared.voiceIdentifier,
            text: sample
        )
    }

    // MARK: - Launch at login

    private func setLaunchAtLogin(_ isEnabled: Bool) {
        do {
            if isEnabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            AppLog.application.error(
                "Could not change the launch-at-login registration: \(error.localizedDescription, privacy: .public)"
            )
            NSSound.beep()
        }

        settingsModel.launchAtLogin = isLaunchAtLoginEnabled()
    }

    private func isLaunchAtLoginEnabled() -> Bool {
        SMAppService.mainApp.status == .enabled
    }
}
