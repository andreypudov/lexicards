import AppKit
import ServiceManagement
import UniformTypeIdentifiers
import os

final class AppCoordinator {
    private let vocabularyController = VocabularyController()
    private let vocabularyLibrary = VocabularyLibrary()
    private let vocabularySpeaker = VocabularySpeaker()
    private let vocabularyCardPanel = VocabularyCardPanel()
    private let menuBarController = MenuBarController()
    private let settingsModel = SettingsModel()
    private lazy var settingsWindowController = SettingsWindowController(model: settingsModel)
    private var timer: Timer?
    private var recallTimer: Timer?
    private var screenObserver: NSObjectProtocol?
    private var isPronunciationEnabled = AppSettings.shared.pronunciationEnabled
    private var isCardVisible = AppSettings.shared.cardVisible
    /// Recall Now on a hidden card shows it for that one session only. The
    /// saved visibility and the menu checkmark keep saying "hidden".
    private var isCardShownForRecall = false
    /// What the card is playing. Not always the saved selection: see
    /// `restoreSelectedVocabulary`.
    private var activeSourceID: String?

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
        observeScreenChanges()
    }

    func stop() {
        if let screenObserver {
            NotificationCenter.default.removeObserver(screenObserver)
        }
        screenObserver = nil
        timer?.invalidate()
        timer = nil
        recallTimer?.invalidate()
        recallTimer = nil
    }

    private func observeScreenChanges() {
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.vocabularyCardPanel.moveBackOnScreenIfNeeded()
            }
        }
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
        menuBarController.onEndRecall = { [weak self] in
            self?.vocabularyCardPanel.cancelRecall()
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
        settingsModel.onCardFadeChanged = { [weak self] in
            self?.vocabularyCardPanel.fadesOnHover = AppSettings.shared.cardFadesOnHover
        }
        settingsModel.onPronunciationChanged = { [weak self] in
            self?.pronunciationSettingsDidChange()
        }
        vocabularyCardPanel.onRecallFinished = { [weak self] in
            self?.recallDidFinish()
        }
        vocabularyCardPanel.onRecallTextShown = { [weak self] text, isOriginal in
            self?.speakRecallText(text, isOriginal: isOriginal)
        }
        vocabularyCardPanel.onReplay = { [weak self] text, isOriginal in
            self?.vocabularySpeaker.speak(text, isOriginal: isOriginal)
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
        settingsModel.selectedSourceID = activeSourceID
        settingsModel.entries = VocabularyEntryRow.rows(from: vocabularyController.allEntries)
        settingsModel.wordInterval = AppSettings.shared.wordInterval
        settingsModel.recallInterval = AppSettings.shared.recallInterval
        settingsModel.recallTimerEnabled = AppSettings.shared.recallTimerEnabled
        settingsModel.launchAtLogin = isLaunchAtLoginEnabled()
    }

    // MARK: - Vocabulary

    /// Opens the vocabulary chosen in settings, or the first built-in one.
    ///
    /// A choice waiting on an earlier file that cannot be reached yet stays saved,
    /// so it comes back with the file instead of being replaced for good.
    private func restoreSelectedVocabulary() -> Bool {
        vocabularyLibrary.importLegacyBookmarks()

        if let identifier = AppSettings.shared.selectedVocabularyIdentifier,
            let source = vocabularyLibrary.source(withIdentifier: identifier),
            vocabularyController.load(from: source.url)
        {
            activeSourceID = source.id
            return true
        }

        // First run: the app ships with vocabularies, so start on one instead of
        // showing the empty-state text until the user goes looking for settings.
        guard let firstBuiltIn = vocabularyLibrary.builtInSources().first,
            vocabularyController.load(from: firstBuiltIn.url)
        else {
            AppLog.vocabulary.error("No built-in vocabulary could be loaded on first run")
            return false
        }

        activeSourceID = firstBuiltIn.id
        if !vocabularyLibrary.hasPendingLegacyBookmarks {
            AppSettings.shared.selectedVocabularyIdentifier = firstBuiltIn.id
        }
        return true
    }

    @discardableResult
    private func selectVocabulary(_ source: VocabularySource) -> Bool {
        guard vocabularyController.load(from: source.url) else {
            AppLog.vocabulary.error(
                "Could not open vocabulary: \(source.name, privacy: .public)"
            )
            NSSound.beep()
            // The picker already shows the new choice. Put it back on the
            // vocabulary the card is still playing.
            refreshSettingsModel()
            return false
        }

        AppSettings.shared.selectedVocabularyIdentifier = source.id
        activeSourceID = source.id
        if vocabularyCardPanel.isRecalling {
            vocabularyCardPanel.cancelRecall()
        }
        configureLoadedVocabulary()
        refreshSettingsModel()
        return true
    }

    /// Removing the vocabulary that is playing moves the card to another one,
    /// rather than leaving the removed words rotating.
    private func removeVocabulary(_ source: VocabularySource) {
        guard vocabularyLibrary.removeUserSource(source) else {
            NSSound.beep()
            return
        }

        guard activeSourceID == source.id else {
            refreshSettingsModel()
            return
        }

        AppSettings.shared.selectedVocabularyIdentifier = nil
        activeSourceID = nil
        let replacement = vocabularyLibrary.sources().first { selectVocabulary($0) }
        if replacement == nil {
            if vocabularyCardPanel.isRecalling {
                vocabularyCardPanel.cancelRecall()
            }
            vocabularyController.clear()
            configureLoadedVocabulary()
            refreshSettingsModel()
        }
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

        // A file of the same name replaces the list, so an updated file can be
        // added over the old one as well as after removing it.
        guard let source = vocabularyLibrary.addUserSource(at: url) else {
            AppLog.vocabulary.error(
                "Could not add the selected vocabulary: \(url.lastPathComponent, privacy: .public)"
            )
            NSSound.beep()
            return
        }

        selectVocabulary(source)
    }

    /// The first word of a new vocabulary appears now, and gets a full interval
    /// before the rotation moves on.
    private func configureLoadedVocabulary() {
        vocabularySpeaker.configureLanguages(entries: vocabularyController.allEntries)
        showNextWord(inPlace: false)
        startWordTimer()
    }

    // MARK: - Card and rotation

    /// The reading rotation. It stays paused for a whole recall session: a
    /// word changing, or being spoken, under the exam would give answers away.
    private func startWordTimer() {
        timer?.invalidate()
        timer = nil
        guard !vocabularyCardPanel.isRecalling else {
            return
        }

        let interval = AppSettings.shared.wordInterval
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.rotationTimerDidFire()
            }
        }
        timer.tolerance = interval * 0.1
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    /// The recall interval counts from the end of the last session, not from
    /// when it began, so a long session does not bring the next one forward.
    private func startRecallTimer() {
        recallTimer?.invalidate()
        recallTimer = nil
        guard !vocabularyCardPanel.isRecalling, AppSettings.shared.recallTimerEnabled else {
            return
        }

        let interval = AppSettings.shared.recallInterval
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.beginRecall(showingCard: false)
            }
        }
        timer.tolerance = min(60, interval * 0.1)
        RunLoop.main.add(timer, forMode: .common)
        recallTimer = timer
    }

    /// Pauses the reading rotation and turns the same card into a recall session.
    /// The timer leaves a hidden card alone. Recall Now shows a hidden card for
    /// the length of the session.
    private func beginRecall(showingCard: Bool) {
        guard !vocabularyCardPanel.isRecalling else {
            return
        }

        let showsForSession = !isCardVisible
        if showsForSession {
            guard showingCard else {
                return
            }
            vocabularyCardPanel.orderFrontRegardless()
        }

        // Stopped before the session starts: the first prompt may speak.
        vocabularySpeaker.stop()
        guard vocabularyCardPanel.beginRecall(entries: vocabularyController.allEntries) else {
            if showsForSession {
                vocabularyCardPanel.orderOut(nil)
            }
            if showingCard {
                AppLog.vocabulary.error("Recall has no entries to ask about")
                NSSound.beep()
            }
            return
        }

        isCardShownForRecall = showsForSession
        menuBarController.setRecalling(true)
        timer?.invalidate()
        timer = nil
        recallTimer?.invalidate()
        recallTimer = nil
    }

    private func recallDidFinish() {
        menuBarController.setRecalling(false)
        vocabularySpeaker.stop()
        if isCardShownForRecall {
            isCardShownForRecall = false
            vocabularyCardPanel.orderOut(nil)
        }

        startWordTimer()
        startRecallTimer()
    }

    /// A hidden card rests. It comes back on the word it left, and nothing is
    /// rebuilt and measured for a card nobody can see.
    private func rotationTimerDidFire() {
        guard isCardVisible else {
            return
        }

        showNextWord()
    }

    private func showNextWord(inPlace: Bool = true) {
        vocabularyController.nextRandom()
        let entry = vocabularyController.currentEntry

        vocabularyCardPanel.update(entry: entry, inPlace: inPlace)
        speakRotationCard()
    }

    private func toggleCard() {
        // Choosing Show Card during a session the card was only borrowed for
        // keeps it on screen afterwards.
        if isCardShownForRecall {
            isCardShownForRecall = false
            setCardVisible(true)
            return
        }

        setCardVisible(!isCardVisible)
    }

    private func setCardVisible(_ isVisible: Bool) {
        isCardVisible = isVisible
        AppSettings.shared.cardVisible = isVisible
        menuBarController.setCardVisible(isVisible)

        if isVisible {
            vocabularyCardPanel.orderFrontRegardless()
            return
        }

        vocabularySpeaker.stop()
        vocabularyCardPanel.orderOut(nil)
        // A session nobody can see would hold the rotation paused until the
        // card came back. Hidden first, so it ends without the shrink.
        vocabularyCardPanel.cancelRecall()
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

        speakRotationCard()
    }

    /// The reading card speaks the word, and the translation when asked to.
    private func speakRotationCard() {
        let settings = AppSettings.shared
        guard isPronunciationEnabled, settings.pronounceDuringRotation, isCardVisible,
            !vocabularyCardPanel.isRecalling,
            let entry = vocabularyController.currentEntry
        else {
            return
        }

        vocabularySpeaker.speak(entry: entry, includingTranslation: settings.pronounceTranslation)
    }

    /// A recall card speaks each side as it comes into view — the prompt when
    /// the card appears, the answer on Reveal — so nothing hidden is read out.
    /// In word-only mode the translation side stays silent.
    private func speakRecallText(_ text: String, isOriginal: Bool) {
        let settings = AppSettings.shared
        guard isPronunciationEnabled, settings.pronounceDuringRecall,
            isOriginal || settings.pronounceTranslation
        else {
            return
        }

        vocabularySpeaker.speak(text, isOriginal: isOriginal)
    }

    /// A mode switched off mid-sentence stops speaking now rather than after
    /// the word.
    private func pronunciationSettingsDidChange() {
        let settings = AppSettings.shared
        let isAllowedNow =
            vocabularyCardPanel.isRecalling
            ? settings.pronounceDuringRecall : settings.pronounceDuringRotation
        if !isAllowedNow {
            vocabularySpeaker.stop()
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
                // Registered, but off until the user approves it. Otherwise the
                // switch just flips back with no explanation.
                if SMAppService.mainApp.status == .requiresApproval {
                    SMAppService.openSystemSettingsLoginItems()
                }
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
