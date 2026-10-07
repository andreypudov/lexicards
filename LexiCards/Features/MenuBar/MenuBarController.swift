import AppKit

final class MenuBarController: NSObject {
    var onOpenVocabulary: (() -> Void)?
    var onOpenSettings: (() -> Void)?
    var onToggleCard: (() -> Void)?
    var onStartRecall: (() -> Void)?
    var onTogglePronunciation: (() -> Void)?
    var onQuit: (() -> Void)?

    private let statusItem: NSStatusItem
    private let pronounceCardsMenuItem: NSMenuItem
    private let showCardMenuItem: NSMenuItem

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
        super.init()

        configureStatusItem()
        configureMenu()
    }

    func update(isCardVisible: Bool, isPronunciationEnabled: Bool) {
        setCardVisible(isCardVisible)
        setPronunciationEnabled(isPronunciationEnabled)
    }

    func setCardVisible(_ isVisible: Bool) {
        showCardMenuItem.state = isVisible ? .on : .off
    }

    func setPronunciationEnabled(_ isEnabled: Bool) {
        pronounceCardsMenuItem.state = isEnabled ? .on : .off
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
        menu.addItem(
            makeItem(
                title: "Vocabulary",
                action: #selector(openVocabulary),
                keyEquivalent: "v"
            ))

        showCardMenuItem.target = self
        menu.addItem(showCardMenuItem)
        menu.addItem(
            makeItem(
                title: "Recall Now",
                action: #selector(startRecall),
                keyEquivalent: "r"
            ))
        pronounceCardsMenuItem.target = self
        menu.addItem(pronounceCardsMenuItem)

        menu.addItem(.separator())
        menu.addItem(
            makeItem(
                title: "Settings…",
                action: #selector(openSettings),
                keyEquivalent: ","
            ))

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

    @objc private func openSettings() {
        onOpenSettings?()
    }

    @objc private func toggleCard() {
        onToggleCard?()
    }

    @objc private func startRecall() {
        onStartRecall?()
    }

    @objc private func togglePronunciation() {
        onTogglePronunciation?()
    }

    @objc private func quitApplication() {
        onQuit?()
    }
}
