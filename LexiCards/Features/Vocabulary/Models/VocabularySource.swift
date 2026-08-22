import Foundation

/// One selectable vocabulary: either shipped inside the app bundle or a CSV the
/// user added themselves.
struct VocabularySource: Identifiable, Hashable {
    enum Kind: Hashable {
        case builtIn
        case user
    }

    let id: String
    let name: String
    let url: URL
    let kind: Kind

    /// Bookmarks are what make a user file reachable again after relaunch; a
    /// built-in vocabulary is inside the bundle and needs none.
    let bookmark: Data?

    init(id: String, name: String, url: URL, kind: Kind, bookmark: Data? = nil) {
        self.id = id
        self.name = name
        self.url = url
        self.kind = kind
        self.bookmark = bookmark
    }
}
