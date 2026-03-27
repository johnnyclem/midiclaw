import Foundation
#if os(macOS)
import Darwin

/// Utilities for converting mach_absolute_time to nanoseconds and back.
/// CoreMIDI timestamps use mach_absolute_time, which is CPU-tick-based.
public enum MachTime {
    private static let timebaseInfo: mach_timebase_info_data_t = {
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        return info
    }()

    /// Current time in nanoseconds from mach_absolute_time.
    public static var nowNanoseconds: UInt64 {
        let machTime = mach_absolute_time()
        return toNanoseconds(machTime)
    }

    /// Convert mach_absolute_time ticks to nanoseconds.
    public static func toNanoseconds(_ machAbsoluteTime: UInt64) -> UInt64 {
        return machAbsoluteTime * UInt64(timebaseInfo.numer) / UInt64(timebaseInfo.denom)
    }

    /// Convert nanoseconds to mach_absolute_time ticks.
    public static func fromNanoseconds(_ nanoseconds: UInt64) -> UInt64 {
        return nanoseconds * UInt64(timebaseInfo.denom) / UInt64(timebaseInfo.numer)
    }

    /// Convert nanoseconds to milliseconds.
    public static func nanosecondsToMilliseconds(_ ns: UInt64) -> Double {
        return Double(ns) / 1_000_000.0
    }

    /// Convert milliseconds to nanoseconds.
    public static func millisecondsToNanoseconds(_ ms: Double) -> UInt64 {
        return UInt64(ms * 1_000_000.0)
    }
}
#else
/// Stub for non-macOS platforms — uses ProcessInfo uptime.
public enum MachTime {
    public static var nowNanoseconds: UInt64 {
        return UInt64(ProcessInfo.processInfo.systemUptime * 1_000_000_000)
    }

    public static func toNanoseconds(_ machAbsoluteTime: UInt64) -> UInt64 {
        return machAbsoluteTime
    }

    public static func fromNanoseconds(_ nanoseconds: UInt64) -> UInt64 {
        return nanoseconds
    }

    public static func nanosecondsToMilliseconds(_ ns: UInt64) -> Double {
        return Double(ns) / 1_000_000.0
    }

    public static func millisecondsToNanoseconds(_ ms: Double) -> UInt64 {
        return UInt64(ms * 1_000_000.0)
    }
}
#endif
