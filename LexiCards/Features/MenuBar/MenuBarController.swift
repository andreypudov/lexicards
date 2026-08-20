import AppKit

final class MenuBarController: NSObject {
    var onOpenVocabulary: (() -> Void)?
    var onOpenVocabularyWebpage: (() -> Void)?
    var onToggleCard: (() -> Void)?
    var onTogglePronunciation: (() -> Void)?
    var onToggleLaunchAtLogin: (() -> Void)?
    var onQuit: (() -> Void)?

    private let statusItem: NSStatusItem
    private let pronounceCardsMenuItem: NSMenuItem
    private let showCardMenuItem: NSMenuItem
    private let launchAtLoginMenuItem: NSMenuItem

    override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        pronounceCardsMenuItem = NSMenuItem(
            title: "Pronounce Cards",
            action: #selector(togglePronunciation),
            keyEquivalent: "p"
        )
        showCardMenuItem = NSMenuItem(
            title: "Show Card",
            action: #selector(toggleCard),
            keyEquivalent: "c"
        )
        launchAtLoginMenuItem = NSMenuItem(
            title: "Launch At Login",
            action: #selector(toggleLaunchAtLogin),
            keyEquivalent: ""
        )
        super.init()

        configureStatusItem()
        configureMenu()
    }

    func update(
        isCardVisible: Bool,
        isPronunciationEnabled: Bool,
        isLaunchAtLoginEnabled: Bool
    ) {
        setCardVisible(isCardVisible)
        setPronunciationEnabled(isPronunciationEnabled)
        setLaunchAtLoginEnabled(isLaunchAtLoginEnabled)
    }

    func setCardVisible(_ isVisible: Bool) {
        showCardMenuItem.state = isVisible ? .on : .off
    }

    func setPronunciationEnabled(_ isEnabled: Bool) {
        pronounceCardsMenuItem.state = isEnabled ? .on : .off
    }

    func setLaunchAtLoginEnabled(_ isEnabled: Bool) {
        launchAtLoginMenuItem.state = isEnabled ? .on : .off
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

    private func configureMenu() {
        let menu = NSMenu()
        menu.addItem(makeItem(
            title: "Open Vocabulary",
            action: #selector(openVocabulary),
            keyEquivalent: "o"
        ))
        menu.addItem(makeItem(
            title: "Download Vocabulary",
            action: #selector(openVocabularyWebpage),
            keyEquivalent: ""
        ))

        showCardMenuItem.target = self
        menu.addItem(showCardMenuItem)
        pronounceCardsMenuItem.target = self
        menu.addItem(pronounceCardsMenuItem)

        menu.addItem(.separator())
        launchAtLoginMenuItem.target = self
        menu.addItem(launchAtLoginMenuItem)

        menu.addItem(.separator())
        let quitItem = makeItem(
            title: "Quit LexiCards",
            action: #selector(quitApplication),
            keyEquivalent: ""
        )
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    private func makeItem(
        title: String,
        action: Selector,
        keyEquivalent: String
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        item.target = self
        return item
    }

    @objc private func openVocabulary() {
        onOpenVocabulary?()
    }

    @objc private func openVocabularyWebpage() {
        onOpenVocabularyWebpage?()
    }

    @objc private func toggleCard() {
        onToggleCard?()
    }

    @objc private func togglePronunciation() {
        onTogglePronunciation?()
    }

    @objc private func toggleLaunchAtLogin() {
        onToggleLaunchAtLogin?()
    }

    @objc private func quitApplication() {
        onQuit?()
    }
}
