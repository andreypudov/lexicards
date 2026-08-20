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
    private var securityScopedVocabularyURL: URL?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        configureStatusItem()
        setupMenu()
        vocabularyCardPanel.restorePositionOrMoveToLowerRightCorner()
        vocabularyCardPanel.orderFrontRegardless()
        if !restoreLastVocabulary() {
            showNextWord()
        }

        timer = Timer.scheduledTimer(withTimeInterval: AppSettings.shared.wordInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.showNextWord()
            }
        }
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else {
            return
        }

        let image = NSImage(named: "StatusBarIcon")
        image?.isTemplate = true
        button.image = image
        button.title = ""
        button.imagePosition = .imageOnly
        button.imageScaling = .scaleProportionallyDown
        button.toolTip = "LexiCards"
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
            guard url.startAccessingSecurityScopedResource() else {
                NSSound.beep()
                return
            }

            guard vocabularyController.load(from: url) else {
                url.stopAccessingSecurityScopedResource()
                NSSound.beep()
                return
            }

            securityScopedVocabularyURL?.stopAccessingSecurityScopedResource()
            securityScopedVocabularyURL = url
            saveBookmark(for: url)
            configureLoadedVocabulary()
        }
    }

    @discardableResult
    private func restoreLastVocabulary() -> Bool {
        guard let bookmarkData = AppSettings.shared.lastVocabularyBookmark else {
            return false
        }

        var isStale = false
        do {
            let url = try URL(
                resolvingBookmarkData: bookmarkData,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )

            guard url.startAccessingSecurityScopedResource() else {
                AppSettings.shared.lastVocabularyBookmark = nil
                return false
            }

            guard vocabularyController.load(from: url) else {
                url.stopAccessingSecurityScopedResource()
                AppSettings.shared.lastVocabularyBookmark = nil
                return false
            }

            securityScopedVocabularyURL = url
            if isStale {
                saveBookmark(for: url)
            }
            configureLoadedVocabulary()
            return true
        } catch {
            AppSettings.shared.lastVocabularyBookmark = nil
            return false
        }
    }

    private func saveBookmark(for url: URL) {
        do {
            let bookmarkData = try url.bookmarkData(
                options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess]
            )
            AppSettings.shared.lastVocabularyBookmark = bookmarkData
        } catch {
            NSSound.beep()
        }
    }

    private func configureLoadedVocabulary() {
        vocabularySpeaker.configureLanguages(entries: vocabularyController.allEntries)
        showNextWord()
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

        if isPronunciationEnabled, let entry = vocabularyController.currentEntry {
            vocabularySpeaker.speak(entry: entry)
        }
    }

    private func isLaunchAtLoginEnabled() -> Bool {
        SMAppService.mainApp.status == .enabled
    }

    private func updateLaunchAtLoginMenuState() {
        launchAtLoginMenuItem?.state = isLaunchAtLoginEnabled() ? .on : .off
    }

    func applicationWillTerminate(_ notification: Notification) {
        securityScopedVocabularyURL?.stopAccessingSecurityScopedResource()
    }
}
