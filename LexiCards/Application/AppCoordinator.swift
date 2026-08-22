import AppKit
import ServiceManagement
import os

final class AppCoordinator {
    private let vocabularyController = VocabularyController()
    private let vocabularyFileAccess = VocabularyFileAccess()
    private let vocabularySpeaker = VocabularySpeaker()
    private let vocabularyCardPanel = VocabularyCardPanel()
    private let menuBarController = MenuBarController()
    private var timer: Timer?
    private var timerInterval: TimeInterval = 0
    private var isPronunciationEnabled = AppSettings.shared.pronunciationEnabled
    private var isCardVisible = AppSettings.shared.cardVisible

    func start() {
        configureMenuBar()
        vocabularyCardPanel.restorePositionOrMoveToLowerRightCorner()

        if vocabularyFileAccess.restoreLast(into: vocabularyController) {
            configureLoadedVocabulary()
        } else {
            showNextWord()
        }

        if isCardVisible {
            vocabularyCardPanel.orderFrontRegardless()
        }

        startWordTimer()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        vocabularyFileAccess.stopAccessing()
    }

    private func configureMenuBar() {
        menuBarController.onOpenVocabulary = { [weak self] in
            self?.openVocabulary()
        }
        menuBarController.onOpenVocabularyWebpage = { [weak self] in
            self?.openVocabularyWebpage()
        }
        menuBarController.onToggleCard = { [weak self] in
            self?.toggleCard()
        }
        menuBarController.onTogglePronunciation = { [weak self] in
            self?.togglePronunciation()
        }
        menuBarController.onToggleLaunchAtLogin = { [weak self] in
            self?.toggleLaunchAtLogin()
        }
        menuBarController.onQuit = {
            NSApp.terminate(nil)
        }
        menuBarController.update(
            isCardVisible: isCardVisible,
            isPronunciationEnabled: isPronunciationEnabled,
            isLaunchAtLoginEnabled: isLaunchAtLoginEnabled()
        )
    }

    private func startWordTimer() {
        let interval = AppSettings.shared.wordInterval
        timerInterval = interval

        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.handleTimerFired()
            }
        }
    }

    /// There is no settings window, so `wordInterval` can only change underneath
    /// a running app (`defaults write`). Re-reading it each tick lets a new value
    /// take effect at the next rotation instead of at the next launch.
    private func handleTimerFired() {
        showNextWord()

        if AppSettings.shared.wordInterval != timerInterval {
            startWordTimer()
        }
    }

    private func openVocabulary() {
        let panel = NSOpenPanel()
        panel.title = "Open Vocabulary"
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true

        if panel.runModal() == .OK, let url = panel.url {
            guard vocabularyFileAccess.load(from: url, into: vocabularyController) else {
                AppLog.vocabulary.error(
                    "Could not open the selected vocabulary: \(url.lastPathComponent, privacy: .public)"
                )
                NSSound.beep()
                return
            }

            configureLoadedVocabulary()
        }
    }

    private func configureLoadedVocabulary() {
        vocabularySpeaker.configureLanguages(entries: vocabularyController.allEntries)
        showNextWord()
    }

    private func openVocabularyWebpage() {
        guard let url = URL(string: AppConstants.vocabularyWebpageURL) else {
            AppLog.application.error(
                "Malformed vocabulary webpage URL: \(AppConstants.vocabularyWebpageURL, privacy: .public)"
            )
            NSSound.beep()
            return
        }

        NSWorkspace.shared.open(url)
    }

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

    private func toggleLaunchAtLogin() {
        do {
            if isLaunchAtLoginEnabled() {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
            menuBarController.setLaunchAtLoginEnabled(isLaunchAtLoginEnabled())
        } catch {
            AppLog.application.error(
                "Could not change the launch-at-login registration: \(error.localizedDescription, privacy: .public)"
            )
            NSSound.beep()
        }
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

    private func isLaunchAtLoginEnabled() -> Bool {
        SMAppService.mainApp.status == .enabled
    }
}
