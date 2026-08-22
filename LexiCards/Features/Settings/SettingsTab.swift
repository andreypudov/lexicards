import Foundation

/// The tabs of the settings window, addressable so the menu can open the window
/// straight to the one the command names.
enum SettingsTab: Hashable, CaseIterable {
    case vocabulary
    case application
    case about

    var title: String {
        switch self {
        case .vocabulary: "Vocabulary"
        case .application: "Application"
        case .about: "About"
        }
    }

    var symbolName: String {
        switch self {
        case .vocabulary: "text.book.closed"
        case .application: "gearshape"
        case .about: "info.circle"
        }
    }
}
