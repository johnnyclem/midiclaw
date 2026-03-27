import Foundation
#if canImport(os)
import os

/// Thin wrapper around os_log for MidiClaw subsystem logging.
public enum Log {
    private static let subsystem = "com.midiclaw"

    public static let midi = os.Logger(subsystem: subsystem, category: "midi")
    public static let tokenizer = os.Logger(subsystem: subsystem, category: "tokenizer")
    public static let session = os.Logger(subsystem: subsystem, category: "session")
    public static let agent = os.Logger(subsystem: subsystem, category: "agent")
    public static let app = os.Logger(subsystem: subsystem, category: "app")
}
#else
/// Fallback logger for non-Apple platforms.
public enum Log {
    public static let midi = PrintLogger(category: "midi")
    public static let tokenizer = PrintLogger(category: "tokenizer")
    public static let session = PrintLogger(category: "session")
    public static let agent = PrintLogger(category: "agent")
    public static let app = PrintLogger(category: "app")
}

public struct PrintLogger {
    let category: String

    public func debug(_ message: String) {
        print("[DEBUG][\(category)] \(message)")
    }

    public func info(_ message: String) {
        print("[INFO][\(category)] \(message)")
    }

    public func error(_ message: String) {
        print("[ERROR][\(category)] \(message)")
    }

    public func warning(_ message: String) {
        print("[WARNING][\(category)] \(message)")
    }
}
#endif
