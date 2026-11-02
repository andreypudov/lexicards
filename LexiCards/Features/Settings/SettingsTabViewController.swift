import AppKit
import Combine
import SwiftUI

/// The settings tabs, as toolbar items in the standard macOS arrangement.
///
/// SwiftUI's `TabView` is not used: on macOS it is an `NSTabView`, which centres
/// its segmented control on half points. On a 1x display that lands between
/// pixels and blurs the tab labels.
final class SettingsTabViewController: NSTabViewController {
    private let model: SettingsModel
    private var selectionObservation: AnyCancellable?

    init(model: SettingsModel) {
        self.model = model
        super.init(nibName: nil, bundle: nil)

        tabStyle = .toolbar

        // Adding the first item selects it, which must not overwrite the tab the
        // model asked for, so the two are connected only once all items exist.
        tabViewItems = SettingsTab.allCases.map(makeTabViewItem)
        select(model.selectedTab)

        selectionObservation = model.$selectedTab.sink { [weak self] tab in
            self?.select(tab)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func tabView(_ tabView: NSTabView, didSelect tabViewItem: NSTabViewItem?) {
        super.tabView(tabView, didSelect: tabViewItem)

        guard selectionObservation != nil else { return }
        let tab = SettingsTab.allCases[selectedTabViewItemIndex]
        if model.selectedTab != tab {
            model.selectedTab = tab
        }
    }

    private func select(_ tab: SettingsTab) {
        guard let index = SettingsTab.allCases.firstIndex(of: tab),
            selectedTabViewItemIndex != index
        else { return }
        selectedTabViewItemIndex = index
    }

    private func makeTabViewItem(for tab: SettingsTab) -> NSTabViewItem {
        let content = makeContentController(for: tab)
        content.title = tab.title

        let item = NSTabViewItem(viewController: content)
        item.label = tab.title
        item.image = NSImage(systemSymbolName: tab.symbolName, accessibilityDescription: tab.title)
        return item
    }

    private func makeContentController(for tab: SettingsTab) -> NSViewController {
        switch tab {
        case .vocabulary: makeHostingController(VocabularySettingsView(model: model))
        case .application: makeHostingController(ApplicationSettingsView(model: model))
        case .about: makeHostingController(AboutSettingsView())
        }
    }

    /// With sizing options left on, each tab's content would resize the window
    /// whenever it is selected. The window's size belongs to the user.
    private func makeHostingController<Content: View>(_ content: Content) -> NSViewController {
        let controller = NSHostingController(rootView: content)
        controller.sizingOptions = []
        return controller
    }
}
