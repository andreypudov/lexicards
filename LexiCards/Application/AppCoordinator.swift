import AppKit
import ServiceManagement

final class AppCoordinator {
    private let vocabularyController = VocabularyController()
    private let vocabularyFileAccess = VocabularyFileAccess()
    private let vocabularySpeaker = VocabularySpeaker()
    private let vocabularyCardPanel = VocabularyCardPanel()
    private let menuBarController = MenuBarController()
    private var timer: Timer?
    private var isPronunciationEnabled = AppSettings.shared.pronunciationEnabled

    func start() {
        configureMenuBar()
        vocabularyCardPanel.restorePositionOrMoveToLowerRightCorner()

        if vocabularyFileAccess.restoreLast(into: vocabularyController) {
            configureLoadedVocabulary()
        } else {
            showNextWord()
        }

        vocabularyCardPanel.orderFrontRegardless()
        startWordTimer()
    }

    func stop() {
        timer?.invalidate()
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
            isCardVisible: true,
            isPronunciationEnabled: isPronunciationEnabled,
            isLaunchAtLoginEnabled: isLaunchAtLoginEnabled()
        )
    }

    private func startWordTimer() {
        timer = Timer.scheduledTimer(
            withTimeInterval: AppSettings.shared.wordInterval,
            repeats: true
        ) { [weak self] _ in
            self?.showNextWord()
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
        let shouldShow = !vocabularyCardPanel.isVisible
        menuBarController.setCardVisible(shouldShow)

        if shouldShow {
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
            NSSound.beep()
        }
    }

    private func showNextWord() {
        _ = vocabularyController.nextRandom()
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
