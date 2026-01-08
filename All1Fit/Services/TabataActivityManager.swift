import Foundation
import ActivityKit
import UIKit

// MARK: - Tabata Activity Manager
/// Manages Live Activity lifecycle for Tabata timer
@MainActor
class TabataActivityManager: ObservableObject {
    
    static let shared = TabataActivityManager()
    
    @Published private(set) var currentActivity: Activity<TabataActivityAttributes>?
    @Published private(set) var isActivityActive = false
    
    private init() {}
    
    // MARK: - Check if Live Activities are available
    
    var areActivitiesEnabled: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }
    
    // MARK: - Start Activity
    
    func startActivity(for tabata: Tabata) async throws {
        // End any existing activity first
        await endActivity()
        
        guard areActivitiesEnabled else {
            throw TabataActivityError.activitiesNotEnabled
        }
        
        let attributes = TabataActivityAttributes(
            tabataName: tabata.name,
            tabataId: tabata.id,
            totalRounds: tabata.type == .intervals ? tabata.rounds : tabata.treadmillPhases?.count ?? 0,
            workSeconds: tabata.workSeconds,
            restSeconds: tabata.restSeconds,
            isIntervalType: tabata.type == .intervals
        )
        
        let initialState = TabataActivityAttributes.ContentState.countdown(seconds: 3)
        
        let content = ActivityContent(
            state: initialState,
            staleDate: nil,
            relevanceScore: 100
        )
        
        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
            
            currentActivity = activity
            isActivityActive = true
            
            print("✅ Live Activity started: \(activity.id)")
            
            // Trigger haptic
            triggerHaptic(for: .countdown)
            
        } catch {
            print("❌ Failed to start Live Activity: \(error)")
            throw TabataActivityError.failedToStart(error)
        }
    }
    
    // MARK: - Update Activity
    
    func updateActivity(with state: TabataActivityAttributes.ContentState, alertConfig: AlertConfiguration? = nil) async {
        guard let activity = currentActivity else { return }
        
        let content = ActivityContent(
            state: state,
            staleDate: state.currentPhase == "complete" ? Date() : nil,
            relevanceScore: state.currentPhase == "complete" ? 0 : 100
        )
        
        await activity.update(content)
    }
    
    // MARK: - Update for Work Phase
    
    func updateToWork(round: Int, totalRounds: Int, seconds: Int) async {
        let state = TabataActivityAttributes.ContentState.work(
            round: round,
            totalRounds: totalRounds,
            seconds: seconds
        )
        await updateActivity(with: state)
        triggerHaptic(for: .workStart)
    }
    
    // MARK: - Update for Rest Phase
    
    func updateToRest(round: Int, totalRounds: Int, seconds: Int) async {
        let state = TabataActivityAttributes.ContentState.rest(
            round: round,
            totalRounds: totalRounds,
            seconds: seconds
        )
        await updateActivity(with: state)
        triggerHaptic(for: .restStart)
    }
    
    // MARK: - Update for Treadmill Phase
    
    func updateToTreadmill(phaseName: String, phaseIndex: Int, totalPhases: Int, seconds: Int, incline: Double, speed: Double) async {
        let state = TabataActivityAttributes.ContentState.treadmill(
            phaseName: phaseName,
            phaseIndex: phaseIndex,
            totalPhases: totalPhases,
            seconds: seconds,
            incline: incline,
            speed: speed
        )
        await updateActivity(with: state)
        triggerHaptic(for: .workStart)
    }
    
    // MARK: - Update Timer (called every second)
    
    func updateTimer(seconds: Int, forState state: TabataActivityAttributes.ContentState) async {
        // Create new state with updated seconds
        let newState = TabataActivityAttributes.ContentState(
            currentPhase: state.currentPhase,
            currentRound: state.currentRound,
            totalRounds: state.totalRounds,
            secondsRemaining: seconds,
            endTime: Date().addingTimeInterval(TimeInterval(seconds)),
            isPaused: state.isPaused,
            phaseDisplayName: state.phaseDisplayName,
            treadmillPhaseName: state.treadmillPhaseName,
            treadmillIncline: state.treadmillIncline,
            treadmillSpeed: state.treadmillSpeed
        )
        
        await updateActivity(with: newState)
    }
    
    // MARK: - Complete Activity
    
    func completeActivity() async {
        guard let activity = currentActivity else { return }
        
        let finalState = TabataActivityAttributes.ContentState.complete()
        
        let content = ActivityContent(
            state: finalState,
            staleDate: Date(),
            relevanceScore: 0
        )
        
        await activity.end(content, dismissalPolicy: .after(.now + 10))
        
        currentActivity = nil
        isActivityActive = false
        
        triggerHaptic(for: .complete)
        print("✅ Live Activity completed")
    }
    
    // MARK: - End Activity (cancel)
    
    func endActivity() async {
        guard let activity = currentActivity else { return }
        
        await activity.end(nil, dismissalPolicy: .immediate)
        
        currentActivity = nil
        isActivityActive = false
        
        print("🛑 Live Activity ended")
    }
    
    // MARK: - Haptic Feedback
    
    private func triggerHaptic(for event: TabataEvent) {
        // All haptics disabled per user request
    }
}

// MARK: - Errors

enum TabataActivityError: LocalizedError {
    case activitiesNotEnabled
    case failedToStart(Error)
    
    var errorDescription: String? {
        switch self {
        case .activitiesNotEnabled:
            return "Live Activities no están habilitadas. Actívalas en Ajustes > All1Fit."
        case .failedToStart(let error):
            return "No se pudo iniciar Live Activity: \(error.localizedDescription)"
        }
    }
}
