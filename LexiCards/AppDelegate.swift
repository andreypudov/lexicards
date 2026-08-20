import AppKit
import ServiceManagement

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var timer: Timer?
    private let vocabularyController = VocabularyController()
    private let vocabularySpeaker = VocabularySpeaker()
    private let vocabularyCardPanel = VocabularyCardPanel()
    private var pronounceCardsMenuItem: NSMenuItem?
    private var showCardMenuItem: NSMenuItem?
    private var launchAtLoginMenuItem: NSMenuItem?
    private var isPronunciationEnabled = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        setupMenu()
        vocabularyCardPanel.moveToLowerRightCorner()
        vocabularyCardPanel.orderFrontRegardless()
        showNextWord()

        timer = Timer.scheduledTimer(withTimeInterval: AppSettings.shared.wordInterval, repeats: true) { [weak self] _ in
            self?.showNextWord()
        }
    }

    private func setupMenu() {
        let menu = NSMenu()

        let openItem = NSMenuItem(
            title: "Open Vocabulary",
            action: #selector(openVocabulary),
            keyEquivalent: "o"
        )
        openItem.target = self
        menu.addItem(openItem)

        let vocabularyPageItem = NSMenuItem(
            title: "Download Vocabulary",
            action: #selector(openVocabularyWebpage),
            keyEquivalent: ""
        )
        vocabularyPageItem.target = self
        menu.addItem(vocabularyPageItem)

        let showCardItem = NSMenuItem(
            title: "Show Card",
            action: #selector(toggleCard),
            keyEquivalent: "c"
        )
        showCardItem.target = self
        showCardItem.state = .on
        showCardMenuItem = showCardItem
        menu.addItem(showCardItem)

        let speakItem = NSMenuItem(
            title: "Pronounce Cards",
            action: #selector(togglePronounceCards),
            keyEquivalent: "p"
        )
        speakItem.target = self
        speakItem.state = .off
        pronounceCardsMenuItem = speakItem
        menu.addItem(speakItem)

        menu.addItem(.separator())

        let launchAtLoginItem = NSMenuItem(
            title: "Launch At Login",
            action: #selector(toggleLaunchAtLogin),
            keyEquivalent: ""
        )
        launchAtLoginItem.target = self
        launchAtLoginMenuItem = launchAtLoginItem
        updateLaunchAtLoginMenuState()
        menu.addItem(launchAtLoginItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Quit",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    @objc private func openVocabulary() {
        let panel = NSOpenPanel()
        panel.title = "Open Vocabulary"
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true

        if panel.runModal() == .OK, let url = panel.url {
            vocabularyController.load(from: url)
            vocabularySpeaker.configureLanguages(entries: vocabularyController.allEntries)
            showNextWord()
        }
    }

    @objc private func openVocabularyWebpage() {
        guard let url = URL(string: AppConstants.vocabularyWebpageURL) else {
            NSSound.beep()
            return
        }

        NSWorkspace.shared.open(url)
    }

    @objc private func togglePronounceCards() {
        isPronunciationEnabled.toggle()
        pronounceCardsMenuItem?.state = isPronunciationEnabled ? .on : .off

        guard isPronunciationEnabled else {
            vocabularySpeaker.stop()
            return
        }

        if let entry = vocabularyController.currentEntry {
            vocabularySpeaker.speak(entry: entry)
        }
    }

    @objc private func toggleCard() {
        let shouldShow = vocabularyCardPanel.isVisible == false
        showCardMenuItem?.state = shouldShow ? .on : .off

        if shouldShow {
            vocabularyCardPanel.moveToLowerRightCorner()
            vocabularyCardPanel.orderFrontRegardless()
        } else {
            vocabularyCardPanel.orderOut(nil)
        }
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            if isLaunchAtLoginEnabled() {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
            updateLaunchAtLoginMenuState()
        } catch {
            NSSound.beep()
        }
    }

    private func showNextWord() {
        _ = vocabularyController.nextRandom()
        vocabularyCardPanel.update(entry: vocabularyController.currentEntry)
        setStatusTitle("LexiCards")

        if isPronunciationEnabled, let entry = vocabularyController.currentEntry {
            vocabularySpeaker.speak(entry: entry)
        }
    }

    private func setStatusTitle(_ title: String) {
        guard let button = statusItem.button else {
            return
        }

        button.title = title
    }

    private func isLaunchAtLoginEnabled() -> Bool {
        SMAppService.mainApp.status == .enabled
    }

    private func updateLaunchAtLoginMenuState() {
        launchAtLoginMenuItem?.state = isLaunchAtLoginEnabled() ? .on : .off
    }
}
