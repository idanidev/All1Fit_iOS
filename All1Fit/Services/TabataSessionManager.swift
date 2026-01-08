import SwiftUI
import AudioToolbox
import ActivityKit

// MARK: - Tabata Session Manager
/// Singleton class to manage the active Tabata session (Timer, State, Audio)
/// independent of the View lifecycle.
@MainActor
class TabataSessionManager: ObservableObject {
    
    static let shared = TabataSessionManager()
    
    // MARK: - Published State (UI Source of Truth)
    
    @Published private(set) var activeTabata: Tabata?
    @Published private(set) var isActive = false // If a session is currently running/paused (mini player visible)
    @Published private(set) var isPaused = false
    @Published private(set) var isComplete = false
    
    // Timer State
    @Published private(set) var phase: TabataPhase = .countdown
    @Published private(set) var currentRound = 1
    @Published private(set) var currentSet = 1
    @Published private(set) var currentPhaseIndex = 0 // For treadmill
    @Published private(set) var secondsRemaining = 3
    @Published private(set) var totalElapsed = 0
    
    // Computed Progress
    var progress: Double {
        guard let tabata = activeTabata else { return 0 }
        let total = tabata.totalDuration
        guard total > 0 else { return 0 }
        return min(1.0, Double(totalElapsed) / Double(total))
    }
    
    // Dependencies
    private let activityManager = TabataActivityManager.shared
    private let tabataService = TabataService() // For saving results
    
    // Internal Timer
    private var timer: Timer?
    
    private init() {}
    
    // MARK: - Session Control
    
    func startSession(for tabata: Tabata) {
        // End any previous session
        stopSession()
        
        self.activeTabata = tabata
        self.isActive = true
        self.isPaused = false
        self.isComplete = false
        self.totalElapsed = 0
        
        // Initial State
        self.phase = .countdown
        self.secondsRemaining = 3
        self.currentRound = 1
        self.currentSet = 1
        self.currentPhaseIndex = 0
        
        // Start Live Activity
        startLiveActivity(for: tabata)
        
        // Send to Apple Watch (auto-launch)
        Task {
            PhoneConnectivityService.shared.sendTabataStartToWatch(tabata)
        }
        
        // Start Timer
        startTimer()
        playHaptic(for: .countdown)
    }
    
    func stopSession() {
        timer?.invalidate()
        timer = nil
        
        // End Live Activity
        Task {
            await activityManager.endActivity()
        }
        
        // Reset State
        withAnimation {
            self.isActive = false
            self.activeTabata = nil
        }
    }
    
    func togglePause() {
        isPaused.toggle()
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
    
    // MARK: - Timer Logic
    
    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
    }
    
    private func tick() {
        guard isActive, !isPaused, let tabata = activeTabata else { return }
        
        secondsRemaining -= 1
        
        if phase != .countdown {
            totalElapsed += 1
        }
        
        if secondsRemaining <= 0 {
            advancePhase(tabata: tabata)
        }
        
        // Sync with Live Activity periodically (every tick for accuracy)
        updateLiveActivity()
    }
    
    private func advancePhase(tabata: Tabata) {
        if tabata.type == .intervals {
            advanceIntervalsPhase(tabata: tabata)
        } else {
            advanceTreadmillPhase(tabata: tabata)
        }
    }
    
    private func advanceIntervalsPhase(tabata: Tabata) {
        switch phase {
        case .countdown:
            phase = .work
            secondsRemaining = tabata.workSeconds
            playHaptic(for: .workStart)
            
        case .work:
            if currentRound >= tabata.rounds {
                if currentSet >= tabata.sets {
                    completeTabata(tabata: tabata)
                } else {
                    // Set rest
                    phase = .setRest
                    secondsRemaining = tabata.setRestSeconds
                    currentSet += 1
                    currentRound = 1
                    playHaptic(for: .restStart)
                }
            } else {
                phase = .rest
                secondsRemaining = tabata.restSeconds
                playHaptic(for: .restStart)
            }
            
        case .rest:
            currentRound += 1
            phase = .work
            secondsRemaining = tabata.workSeconds
            playHaptic(for: .workStart)
            
        case .setRest:
            phase = .work
            secondsRemaining = tabata.workSeconds
            playHaptic(for: .workStart)
            
        case .complete:
            break
        }
    }
    
    private func advanceTreadmillPhase(tabata: Tabata) {
        guard let phases = tabata.treadmillPhases else { return }
        
        if phase == .countdown {
            phase = .work
            currentPhaseIndex = 0
            secondsRemaining = phases[0].durationMinutes * 60
            playHaptic(for: .workStart)
        } else {
            currentPhaseIndex += 1
            
            if currentPhaseIndex >= phases.count {
                completeTabata(tabata: tabata)
            } else {
                secondsRemaining = phases[currentPhaseIndex].durationMinutes * 60
                playHaptic(for: .workStart)
            }
        }
    }
    
    private func completeTabata(tabata: Tabata) {
        timer?.invalidate()
        phase = .complete
        isComplete = true
        playHaptic(for: .complete)
        
        // Complete Live Activity
        Task {
            await activityManager.completeActivity()
        }
        
        // Save result
        let result = TabataResult(
            tabataId: tabata.id,
            tabataName: tabata.name,
            totalTimeSeconds: totalElapsed,
            completedRounds: tabata.type == .intervals ? tabata.rounds * tabata.sets : tabata.treadmillPhases?.count ?? 0
        )
        
        Task {
            try? await tabataService.saveResult(result)
        }
    }
    
    // MARK: - Live Activity Integration
    
    private func startLiveActivity(for tabata: Tabata) {
        Task {
            do {
                try await activityManager.startActivity(for: tabata)
            } catch {
                print("⚠️ Could not start Live Activity: \(error.localizedDescription)")
            }
        }
    }
    
    private func updateLiveActivity() {
        guard let tabata = activeTabata else { return }
        
        Task {
            if tabata.type == .intervals {
                if phase == .work {
                    await activityManager.updateToWork(round: currentRound, totalRounds: tabata.rounds, seconds: secondsRemaining)
                } else if phase == .rest {
                    await activityManager.updateToRest(round: currentRound, totalRounds: tabata.rounds, seconds: secondsRemaining)
                } else {
                     // Generic update
                     await activityManager.updateTimer(seconds: secondsRemaining, forState: .countdown(seconds: secondsRemaining)) // Simplification, ideally precise state
                }
            } else {
                // Treadmill update logic
                if let phases = tabata.treadmillPhases, currentPhaseIndex < phases.count {
                    let p = phases[currentPhaseIndex]
                    await activityManager.updateToTreadmill(
                        phaseName: p.name,
                        phaseIndex: currentPhaseIndex,
                        totalPhases: phases.count,
                        seconds: secondsRemaining,
                        incline: p.inclinePercent,
                        speed: p.speedKmh
                    )
                }
            }
        }
    }
    
    // MARK: - Helpers
    
    private func playHaptic(for event: TabataEvent) {
        switch event {
        case .countdown:
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        case .workStart:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .restStart:
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        case .almostDone:
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case .complete:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
            AudioServicesPlaySystemSound(1407)
        }
    }
}
