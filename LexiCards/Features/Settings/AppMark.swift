import SwiftUI

/// The LexiCards mark, drawn from the icon artwork rather than from
/// `NSApp.applicationIconImage`.
///
/// The application icon macOS hands back is the *composed* one: the system adds
/// a bezel and a bright specular rim behind the artwork. LexiCards' mark is a
/// glyph on a transparent ground, so at About size that bezel is all one sees
/// around it — a pale rounded square that belongs to no part of the design.
/// Using the artwork directly keeps the mark itself, crisp in either appearance.
struct AppMark: View {
    var body: some View {
        Image("AppMark")
            .resizable()
            .interpolation(.high)
            .aspectRatio(1, contentMode: .fit)
    }
}
