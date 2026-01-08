import Foundation
#if canImport(ActivityKit)
import ActivityKit

// MARK: - Tabata Activity Attributes
/// Shared between main app and widget extension for Live Activity
struct TabataActivityAttributes: ActivityAttributes {
    
    // MARK: - Static Data (doesn't change during activity)
    let tabataName: String
    let tabataId: String
    let totalRounds: Int
    let workSeconds: Int
    let restSeconds: Int
    let isIntervalType: Bool  // true = intervals, false = treadmill
    
    // MARK: - Dynamic Content State
    struct ContentState: Codable, Hashable {
        let currentPhase: String        // "countdown", "work", "rest", "setRest", "complete"
        let currentRound: Int
        let totalRounds: Int
        let secondsRemaining: Int
        let endTime: Date               // For native countdown in widget
        let isPaused: Bool
        let phaseDisplayName: String    // "💪 TRABAJO", "😮‍💨 DESCANSO", etc.
        
        // For treadmill mode
        let treadmillPhaseName: String?
        let treadmillIncline: Double?
        let treadmillSpeed: Double?
        
        // Progress
        var progress: Double {
            guard totalRounds > 0 else { return 0 }
            let completedRounds = Double(currentRound - 1)
            return min(1.0, completedRounds / Double(totalRounds))
        }
        
        // Formatted time remaining
        var formattedTime: String {
            let mins = secondsRemaining / 60
            let secs = secondsRemaining % 60
            return String(format: "%d:%02d", mins, secs)
        }
    }
}

// MARK: - Helper Extensions
extension TabataActivityAttributes.ContentState {
    
    static func countdown(seconds: Int) -> TabataActivityAttributes.ContentState {
        Self(
            currentPhase: "countdown",
            currentRound: 0,
            totalRounds: 0,
            secondsRemaining: seconds,
            endTime: Date().addingTimeInterval(TimeInterval(seconds)),
            isPaused: false,
            phaseDisplayName: "¡Prepárate!",
            treadmillPhaseName: nil,
            treadmillIncline: nil,
            treadmillSpeed: nil
        )
    }
    
    static func work(round: Int, totalRounds: Int, seconds: Int) -> TabataActivityAttributes.ContentState {
        Self(
            currentPhase: "work",
            currentRound: round,
            totalRounds: totalRounds,
            secondsRemaining: seconds,
            endTime: Date().addingTimeInterval(TimeInterval(seconds)),
            isPaused: false,
            phaseDisplayName: "💪 TRABAJO",
            treadmillPhaseName: nil,
            treadmillIncline: nil,
            treadmillSpeed: nil
        )
    }
    
    static func rest(round: Int, totalRounds: Int, seconds: Int) -> TabataActivityAttributes.ContentState {
        Self(
            currentPhase: "rest",
            currentRound: round,
            totalRounds: totalRounds,
            secondsRemaining: seconds,
            endTime: Date().addingTimeInterval(TimeInterval(seconds)),
            isPaused: false,
            phaseDisplayName: "😮‍💨 DESCANSO",
            treadmillPhaseName: nil,
            treadmillIncline: nil,
            treadmillSpeed: nil
        )
    }
    
    static func treadmill(phaseName: String, phaseIndex: Int, totalPhases: Int, seconds: Int, incline: Double, speed: Double) -> TabataActivityAttributes.ContentState {
        Self(
            currentPhase: "work",
            currentRound: phaseIndex + 1,
            totalRounds: totalPhases,
            secondsRemaining: seconds,
            endTime: Date().addingTimeInterval(TimeInterval(seconds)),
            isPaused: false,
            phaseDisplayName: phaseName,
            treadmillPhaseName: phaseName,
            treadmillIncline: incline,
            treadmillSpeed: speed
        )
    }
    
    static func complete() -> TabataActivityAttributes.ContentState {
        Self(
            currentPhase: "complete",
            currentRound: 0,
            totalRounds: 0,
            secondsRemaining: 0,
            endTime: Date(),
            isPaused: false,
            phaseDisplayName: "🎉 ¡COMPLETADO!",
            treadmillPhaseName: nil,
            treadmillIncline: nil,
            treadmillSpeed: nil
        )
    }
}
#endif
