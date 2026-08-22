import Foundation

/// Identity and version, read from the bundle rather than duplicated in source
/// so a release cannot ship an About that disagrees with itself.
enum AppInfo {
    static let name = "LexiCards"
    static let summary = "Keeps vocabulary in view while you work, without interrupting it."

    static let repository = URL(string: "https://github.com/andreypudov/lexicards")

    /// The release list rather than this version's tag: a tag exists only once
    /// the release is cut, so a build made between releases would link to a 404.
    static let releases = URL(string: "https://github.com/andreypudov/lexicards/releases")

    static var versionLine: String {
        "Version \(string(forKey: "CFBundleShortVersionString") ?? "—")"
    }

    static var copyright: String {
        string(forKey: "NSHumanReadableCopyright") ?? ""
    }

    private static func string(forKey key: String) -> String? {
        Bundle.main.object(forInfoDictionaryKey: key) as? String
    }
}
