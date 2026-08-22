import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        TabView(selection: $model.selectedTab) {
            VocabularySettingsView(model: model)
                .tabItem { tabLabel(for: .vocabulary) }
                .tag(SettingsTab.vocabulary)

            ApplicationSettingsView(model: model)
                .tabItem { tabLabel(for: .application) }
                .tag(SettingsTab.application)

            AboutSettingsView()
                .tabItem { tabLabel(for: .about) }
                .tag(SettingsTab.about)
        }
        .padding(16)
        .frame(minWidth: 620, minHeight: 460)
    }

    private func tabLabel(for tab: SettingsTab) -> some View {
        Label(tab.title, systemImage: tab.symbolName)
    }
}
