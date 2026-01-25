import Foundation
import UserNotifications
import WatchKit

// MARK: - Workout Notification Service
/// Manages local notifications for workout achievements
class WorkoutNotificationService {
    static let shared = WorkoutNotificationService()
    
    private init() {}
    
    // MARK: - Request Authorization
    
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .sound, .badge]
            )
            print(granted ? "✅ Notifications authorized" : "⚠️ Notifications denied")
            return granted
        } catch {
            print("❌ Error requesting notification auth: \(error)")
            return false
        }
    }
    
    // MARK: - Workout Completed Notification
    
    func notifyWorkoutCompleted(name: String, duration: TimeInterval, calories: Double?) {
        let content = UNMutableNotificationContent()
        content.title = "💪 ¡Entrenamiento Completado!"
        
        let durationMinutes = Int(duration / 60)
        if let calories = calories {
            content.body = "\(name) - \(durationMinutes) min - \(Int(calories)) kcal"
        } else {
            content.body = "\(name) - \(durationMinutes) minutos"
        }
        
        content.sound = .default
        content.categoryIdentifier = "WORKOUT_COMPLETED"
        
        scheduleNotification(content, id: "workout_completed_\(Date().timeIntervalSince1970)")
    }
    
    // MARK: - New Personal Record Notification
    
    func notifyNewPR(exerciseName: String, weight: Double, unit: String) {
        let content = UNMutableNotificationContent()
        content.title = "🏆 ¡Nuevo Récord Personal!"
        content.body = "\(exerciseName): \(formatWeight(weight)) \(unit)"
        content.sound = UNNotificationSound.default
        content.categoryIdentifier = "NEW_PR"
        
        // Add user info for handling
        content.userInfo = [
            "type": "pr",
            "exercise": exerciseName,
            "weight": weight
        ]
        
        scheduleNotification(content, id: "pr_\(exerciseName)_\(Date().timeIntervalSince1970)")
        
        // Haptic celebration
        WKInterfaceDevice.current().play(.success)
    }
    
    // MARK: - Weekly Summary Notification
    
    func notifyWeeklySummary(workouts: Int, totalMinutes: Int, prsCount: Int) {
        let content = UNMutableNotificationContent()
        content.title = "📊 Resumen Semanal"
        
        var bodyParts: [String] = []
        if workouts > 0 {
            bodyParts.append("\(workouts) entrenamientos")
        }
        if totalMinutes > 0 {
            bodyParts.append("\(totalMinutes) minutos")
        }
        if prsCount > 0 {
            bodyParts.append("\(prsCount) PRs nuevos 🎉")
        }
        
        content.body = bodyParts.joined(separator: " • ")
        content.sound = .default
        
        scheduleNotification(content, id: "weekly_summary")
    }
    
    // MARK: - Motivation Reminder
    
    func scheduleMotivationReminder(daysInactive: Int = 3) {
        let content = UNMutableNotificationContent()
        content.title = "💪 ¡Es hora de entrenar!"
        content.body = "Llevas \(daysInactive) días sin entrenar. ¡Vamos!"
        content.sound = .default
        content.categoryIdentifier = "MOTIVATION"
        
        // Schedule for tomorrow at 10 AM
        var dateComponents = DateComponents()
        dateComponents.hour = 10
        dateComponents.minute = 0
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: "motivation_reminder",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Error scheduling motivation: \(error)")
            } else {
                print("✅ Motivation reminder scheduled")
            }
        }
    }
    
    // MARK: - Cancel Motivation (user trained)
    
    func cancelMotivationReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: ["motivation_reminder"]
        )
    }
    
    // MARK: - Helpers
    
    private func scheduleNotification(_ content: UNMutableNotificationContent, id: String) {
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Error scheduling notification: \(error)")
            }
        }
    }
    
    private func formatWeight(_ weight: Double) -> String {
        if weight.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(weight))"
        }
        return String(format: "%.1f", weight)
    }
}

// MARK: - Haptic Patterns
enum WorkoutHaptic {
    case phaseChange       // Work → Rest
    case roundComplete     // Completed a round
    case workoutComplete   // Full workout done
    case newPR             // Personal record
    case countdown         // 3, 2, 1
    case warning           // Almost done with phase
    
    func play() {
        let device = WKInterfaceDevice.current()
        
        switch self {
        case .phaseChange:
            device.play(.notification)
            
        case .roundComplete:
            device.play(.success)
            
        case .workoutComplete:
            // Triple success
            device.play(.success)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                device.play(.success)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                device.play(.success)
            }
            
        case .newPR:
            // Long celebratory pattern
            device.play(.success)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                device.play(.directionUp)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                device.play(.success)
            }
            
        case .countdown:
            device.play(.click)
            
        case .warning:
            device.play(.retry)
        }
    }
}
