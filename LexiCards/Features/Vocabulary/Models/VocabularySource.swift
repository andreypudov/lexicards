import Foundation

/// One selectable vocabulary: either shipped inside the app bundle or the app's
/// own copy of a CSV the user added.
struct VocabularySource: Identifiable, Hashable {
    enum Kind: Hashable {
        case builtIn
        case user
    }

    let id: String
    let name: String
    let url: URL
    let kind: Kind
}
