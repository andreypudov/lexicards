import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var timer: Timer?
    private let vocabularyController = VocabularyController()
    private let vocabularySpeaker = VocabularySpeaker()
    private var pronounceCardsMenuItem: NSMenuItem?
    private var isPronunciationEnabled = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        setupMenu()
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

    private func showNextWord() {
        statusItem.button?.title = vocabularyController.nextRandom()

        if isPronunciationEnabled, let entry = vocabularyController.currentEntry {
            vocabularySpeaker.speak(entry: entry)
        }
    }
}

