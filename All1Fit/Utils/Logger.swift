import Foundation
import os.log

/// Unified logging for All1Fit
enum Log {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.all1fit"
    
    static let connectivity = Logger(subsystem: subsystem, category: "Connectivity")
    static let tabata = Logger(subsystem: subsystem, category: "Tabata")
    static let sync = Logger(subsystem: subsystem, category: "Sync")
    static let healthKit = Logger(subsystem: subsystem, category: "HealthKit")
    static let general = Logger(subsystem: subsystem, category: "General")
}

// MARK: - Debug-only print wrapper
/// Use this instead of print() for debug output that should not appear in release
@inline(__always)
func debugLog(_ message: @autoclosure @escaping () -> String, category: Logger = Log.general) {
    #if DEBUG
    category.debug("\(message())")
    #endif
}
