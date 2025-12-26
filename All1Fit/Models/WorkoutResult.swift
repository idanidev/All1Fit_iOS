import Foundation
import FirebaseFirestore

// MARK: - Workout Result
struct WorkoutResult: Identifiable, Codable, Hashable {
    @DocumentID var id: String?
    let workoutId: String
    let userId: String
    let date: Date
    let timeSeconds: Int // Total time in seconds
    let rounds: Int? // For AMRAP workouts
    let notes: String?
    
    // Computed property for formatted time
    var formattedTime: String {
        let hours = timeSeconds / 3600
        let minutes = (timeSeconds % 3600) / 60
        let seconds = timeSeconds % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
    
    var formattedDate: String {
        date.formatted(date: .abbreviated, time: .omitted)
    }
    
    // Check if this is a PR (Personal Record)
    func isPR(comparedTo others: [WorkoutResult]) -> Bool {
        guard let workout = Workout.workout(withId: workoutId) else { return false }
        
        if workout.isForTime {
            // For timed workouts, lower is better
            return others.allSatisfy { self.timeSeconds <= $0.timeSeconds }
        } else {
            // For AMRAP, more rounds is better
            guard let myRounds = rounds else { return false }
            return others.allSatisfy { myRounds >= ($0.rounds ?? 0) }
        }
    }
}
