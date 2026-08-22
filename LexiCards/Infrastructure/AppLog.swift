import Foundation
import os

/// Shared loggers for the failures that would otherwise only be audible.
///
/// The app reports problems to the user with `NSSound.beep()`, which says that
/// something went wrong but never what. Every beep is paired with a log entry
/// here so the cause is recoverable from Console.app or `log stream`.
enum AppLog {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.andreypudov.LexiCards"

    static let application = Logger(subsystem: subsystem, category: "application")
    static let vocabulary = Logger(subsystem: subsystem, category: "vocabulary")
}
