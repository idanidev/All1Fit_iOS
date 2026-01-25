import SwiftUI
import AudioToolbox
import ActivityKit

// MARK: - Tabata Session Manager
/// Singleton class to manage the active Tabata session (Timer, State, Audio)
/// Uses date-based timing to remain accurate even when app is backgrounded.
@MainActor
class TabataSessionManager: ObservableObject {
    
    static let shared = TabataSessionManager()
    
    // MARK: - Published State (UI Source of Truth)
    
    @Published private(set) var activeTabata: Tabata?
    @Published private(set) var isActive = false
    @Published private(set) var isPaused = false
    @Published private(set) var isComplete = false
    
    // Timer State
    @Published private(set) var phase: TabataPhase = .countdown
    @Published private(set) var currentRound = 1
    @Published private(set) var currentSet = 1
    @Published private(set) var currentPhaseIndex = 0
    @Published private(set) var secondsRemaining = 3
    @Published private(set) var totalElapsed = 0
    
    // Date-based timing (background resilient)
    private var phaseStartTime: Date?
    private var phaseDuration: Int = 0
    private var pausedAtSeconds: Int?
    private var sessionStartTime: Date?
    
    // Computed Progress
    var progress: Double {
        guard let tabata = activeTabata else { return 0 }
        let total = tabata.totalDuration
        guard total > 0 else { return 0 }
        return min(1.0, Double(totalElapsed) / Double(total))
    }
    
    // Dependencies
    private let activityManager = TabataActivityManager.shared
    private let tabataService = TabataService()
    
    // Internal Timer (only for UI refresh, not time source)
    private var timer: Timer?
    
    private init() {
        // Observe app lifecycle for background recovery
        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.recoverFromBackground()
            }
        }
    }
    
    // MARK: - Session Control
    
    func startSession(for tabata: Tabata) {
        stopSession()
        
        self.activeTabata = tabata
        self.isActive = true
        self.isPaused = false
        self.isComplete = false
        self.totalElapsed = 0
        self.sessionStartTime = Date()
        
        // Initial State
        self.phase = .countdown
        self.phaseDuration = 3
        self.secondsRemaining = 3
        self.phaseStartTime = Date()
        self.currentRound = 1
        self.currentSet = 1
        self.currentPhaseIndex = 0
        
        // Start Live Activity
        startLiveActivity(for: tabata)
        
        // Send to Apple Watch
        Task {
            PhoneConnectivityService.shared.sendTabataStartToWatch(tabata)
        }
        
        // Start UI refresh timer
        startTimer()
        playHaptic(for: .countdown)
    }
    
    func stopSession() {
        timer?.invalidate()
        timer = nil
        
        Task {
            await activityManager.endActivity()
        }
        
        // Notify Watch
        PhoneConnectivityService.shared.sendTabataStopToWatch()
        
        withAnimation {
            self.isActive = false
            self.activeTabata = nil
            self.phaseStartTime = nil
        }
    }
    
    func togglePause() {
        if isPaused {
            // Resuming: recalculate phaseStartTime to account for pause duration
            if let pausedSeconds = pausedAtSeconds {
                phaseStartTime = Date().addingTimeInterval(-Double(phaseDuration - pausedSeconds))
                pausedAtSeconds = nil
            }
        } else {
            // Pausing: store current remaining seconds
            pausedAtSeconds = secondsRemaining
        }
        isPaused.toggle()
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
    
    // MARK: - Background Recovery
    
    private func recoverFromBackground() {
        guard isActive, !isPaused, let startTime = phaseStartTime, let tabata = activeTabata else { return }
        
        // Calculate how much time has passed
        let elapsed = Int(Date().timeIntervalSince(startTime))
        let newRemaining = max(0, phaseDuration - elapsed)
        
        if newRemaining <= 0 {
            // Phase should have ended while backgrounded - advance phases
            advanceMultiplePhases(tabata: tabata, elapsedSincePhaseStart: elapsed)
        } else {
            secondsRemaining = newRemaining
        }
        
        // Recalculate total elapsed
        if let sessionStart = sessionStartTime {
            totalElapsed = Int(Date().timeIntervalSince(sessionStart))
        }
    }
    
    private func advanceMultiplePhases(tabata: Tabata, elapsedSincePhaseStart: Int) {
        var remainingTime = elapsedSincePhaseStart - phaseDuration
        
        while remainingTime >= 0 && !isComplete {
            advancePhase(tabata: tabata)
            
            if isComplete { break }
            
            remainingTime -= phaseDuration
        }
        
        if !isComplete {
            // Set correct remaining time for current phase
            secondsRemaining = max(0, phaseDuration + remainingTime)
            phaseStartTime = Date().addingTimeInterval(-Double(phaseDuration - secondsRemaining))
        }
    }
    
    // MARK: - Timer Logic
    
    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
        // Allow timer to run in common modes (scroll, etc)
        RunLoop.current.add(timer!, forMode: .common)
    }
    
    private func tick() {
        guard isActive, !isPaused, let startTime = phaseStartTime, let tabata = activeTabata else { return }
        
        // Date-based calculation
        let elapsed = Int(Date().timeIntervalSince(startTime))
        let newRemaining = max(0, phaseDuration - elapsed)
        
        // Only update if changed (avoid unnecessary refreshes)
        if newRemaining != secondsRemaining {
            secondsRemaining = newRemaining
            
            if phase != .countdown {
                if let sessionStart = sessionStartTime {
                    totalElapsed = Int(Date().timeIntervalSince(sessionStart))
                }
            }
        }
        
        if secondsRemaining <= 0 {
            advancePhase(tabata: tabata)
        }
    }
    
    private func advancePhase(tabata: Tabata) {
        if tabata.type == .intervals {
            advanceIntervalsPhase(tabata: tabata)
        } else {
            advanceTreadmillPhase(tabata: tabata)
        }
        
        // Update Live Activity on phase change only
        if !isComplete {
            updateLiveActivity()
        }
    }
    
    private func advanceIntervalsPhase(tabata: Tabata) {
        switch phase {
        case .countdown:
            phase = .work
            phaseDuration = tabata.workSeconds
            secondsRemaining = tabata.workSeconds
            phaseStartTime = Date()
            playHaptic(for: .workStart)
            
        case .work:
            if currentRound >= tabata.rounds {
                if currentSet >= tabata.sets {
                    completeTabata(tabata: tabata)
                } else {
                    phase = .setRest
                    phaseDuration = tabata.setRestSeconds
                    secondsRemaining = tabata.setRestSeconds
                    phaseStartTime = Date()
                    currentSet += 1
                    currentRound = 1
                    playHaptic(for: .restStart)
                }
            } else {
                phase = .rest
                phaseDuration = tabata.restSeconds
                secondsRemaining = tabata.restSeconds
                phaseStartTime = Date()
                playHaptic(for: .restStart)
            }
            
        case .rest:
            currentRound += 1
            phase = .work
            phaseDuration = tabata.workSeconds
            secondsRemaining = tabata.workSeconds
            phaseStartTime = Date()
            playHaptic(for: .workStart)
            
        case .setRest:
            phase = .work
            phaseDuration = tabata.workSeconds
            secondsRemaining = tabata.workSeconds
            phaseStartTime = Date()
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
            phaseDuration = phases[0].durationMinutes * 60
            secondsRemaining = phaseDuration
            phaseStartTime = Date()
            playHaptic(for: .workStart)
        } else {
            currentPhaseIndex += 1
            
            if currentPhaseIndex >= phases.count {
                completeTabata(tabata: tabata)
            } else {
                phaseDuration = phases[currentPhaseIndex].durationMinutes * 60
                secondsRemaining = phaseDuration
                phaseStartTime = Date()
                playHaptic(for: .workStart)
            }
        }
    }
    
    private func completeTabata(tabata: Tabata) {
        timer?.invalidate()
        phase = .complete
        isComplete = true
        playHaptic(for: .complete)
        
        Task {
            await activityManager.completeActivity()
        }
        
        // Notify Watch
        PhoneConnectivityService.shared.sendTabataStopToWatch()
        
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
                debugLog("Could not start Live Activity: \(error.localizedDescription)", category: Log.tabata)
            }
        }
    }
    
    private func updateLiveActivity() {
        guard let tabata = activeTabata else { return }
        
        Task {
            if tabata.type == .intervals {
                if phase == .work {
                    await activityManager.updateToWork(round: currentRound, totalRounds: tabata.rounds, seconds: phaseDuration)
                } else if phase == .rest || phase == .setRest {
                    await activityManager.updateToRest(round: currentRound, totalRounds: tabata.rounds, seconds: phaseDuration)
                }
            } else {
                if let phases = tabata.treadmillPhases, currentPhaseIndex < phases.count {
                    let p = phases[currentPhaseIndex]
                    await activityManager.updateToTreadmill(
                        phaseName: p.name,
                        phaseIndex: currentPhaseIndex,
                        totalPhases: phases.count,
                        seconds: phaseDuration,
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
