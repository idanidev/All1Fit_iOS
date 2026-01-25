import SwiftUI
import WatchKit

// MARK: - Tabata Timer Watch View (Intervals)
struct TabataTimerWatchView: View {
    let tabata: Tabata
    
    @Environment(\.dismiss) private var dismiss
    
    // Timer state
    @State private var phase: TabataPhase = .countdown
    @State private var currentRound = 1
    @State private var secondsRemaining = 3
    @State private var totalElapsed = 0
    @State private var isPaused = false
    @State private var isComplete = false
    @State private var timer: Timer?
    
    // HealthKit
    @StateObject private var healthKit = HealthKitService.shared
    @State private var workoutStartDate: Date?
    
    private var phaseColor: Color {
        switch phase {
        case .countdown: return .orange
        case .work: return .green
        case .rest: return .red
        case .setRest: return .blue
        case .complete: return .purple
        }
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // Phase indicator
            Text(phase.displayName)
                .font(.caption)
                .foregroundStyle(phaseColor)
            
            // Big timer
            Text(formattedTime(secondsRemaining))
                .font(.system(size: 60, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(phaseColor)
            
            // Round info
            if phase != .countdown && phase != .complete {
                HStack(spacing: 12) {
                    Text("R\(currentRound)/\(tabata.rounds)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    
                    // Heart rate if available
                    if healthKit.currentHeartRate > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "heart.fill")
                                .foregroundStyle(.red)
                            Text("\(Int(healthKit.currentHeartRate))")
                        }
                        .font(.caption2)
                    }
                }
            }
            
            // Completion stats
            if isComplete {
                VStack(spacing: 4) {
                    if healthKit.activeCalories > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "flame.fill")
                                .foregroundStyle(.orange)
                            Text("\(Int(healthKit.activeCalories)) kcal")
                        }
                        .font(.caption)
                    }
                    Text("\(formattedTime(totalElapsed))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            
            // Controls
            HStack(spacing: 20) {
                if isComplete {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "checkmark")
                            .font(.title2)
                    }
                    .tint(.green)
                } else {
                    Button {
                        togglePause()
                    } label: {
                        Image(systemName: isPaused ? "play.fill" : "pause.fill")
                            .font(.title3)
                    }
                    .tint(isPaused ? .green : .orange)
                    
                    Button {
                        stopTimer()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.title3)
                    }
                    .tint(.red)
                }
            }
            .padding(.top, 8)
        }
        .navigationBarBackButtonHidden(true)
        .onAppear {
            startCountdown()
        }
        .onDisappear {
            stopTimer()
        }
    }
    
    // MARK: - Timer Logic
    
    private func startCountdown() {
        phase = .countdown
        secondsRemaining = 3
        workoutStartDate = Date()
        playHaptic(.start)
        
        // Start HealthKit workout
        Task {
            try? await healthKit.startWorkout()
        }
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            tick()
        }
    }
    
    private func tick() {
        guard !isPaused else { return }
        
        // 3 second warning
        if secondsRemaining == 4 {
            playHaptic(.click)
        }
        
        secondsRemaining -= 1
        
        if phase != .countdown {
            totalElapsed += 1
        }
        
        if secondsRemaining <= 0 {
            advancePhase()
        } else if secondsRemaining <= 3 && phase == .countdown {
            playHaptic(.click)
        }
    }
    
    private func advancePhase() {
        switch phase {
        case .countdown:
            phase = .work
            secondsRemaining = tabata.workSeconds
            playHaptic(.start)
            
        case .work:
            if currentRound >= tabata.rounds {
                if tabata.sets > 1 {
                   // Handle sets logic if needed, simplify for watch for now to just complete
                   // Or implement set rest. For now completing.
                   completeTabata()
                } else {
                   completeTabata()
                }
            } else {
                phase = .rest
                secondsRemaining = tabata.restSeconds
                playHaptic(.stop)
            }
            
        case .rest:
            currentRound += 1
            phase = .work
            secondsRemaining = tabata.workSeconds
            playHaptic(.start)
            
        case .setRest:
            // Not implemented fully yet on watch
            phase = .work
            
        case .complete:
            break
        }
    }
    
    private func completeTabata() {
        stopTimer()
        phase = .complete
        isComplete = true
        playHaptic(.success)
        
        // End HealthKit workout and save to Health
        Task {
            let _ = try? await healthKit.endWorkout()
        }
        
        // Triple haptic celebration
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            playHaptic(.success)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            playHaptic(.success)
        }
    }
    
    private func togglePause() {
        isPaused.toggle()
        playHaptic(.click)
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func formattedTime(_ seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", mins, secs)
    }
    
    private func playHaptic(_ type: WKHapticType) {
        WKInterfaceDevice.current().play(type)
    }
}

// MARK: - Treadmill Timer Watch View
struct TreadmillTimerWatchView: View {
    let tabata: Tabata
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var currentPhaseIndex = 0
    @State private var secondsRemaining = 3
    @State private var isPaused = false
    @State private var isComplete = false
    @State private var isCountdown = true
    @State private var timer: Timer?
    
    private var currentPhase: TreadmillPhase? {
        guard let phases = tabata.treadmillPhases,
              currentPhaseIndex < phases.count else { return nil }
        return phases[currentPhaseIndex]
    }
    
    var body: some View {
        VStack(spacing: 6) {
            if isCountdown {
                Text("¡Prepárate!")
                    .font(.caption)
                    .foregroundStyle(.orange)
                
                Text("\(secondsRemaining)")
                    .font(.system(size: 60, weight: .bold, design: .rounded))
                    .foregroundStyle(.orange)
            } else if let phase = currentPhase {
                // Phase name
                Text(phase.name)
                    .font(.caption.bold())
                    .foregroundStyle(.green)
                
                // Timer
                Text(formattedTime(secondsRemaining))
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.green)
                
                // Instructions
                HStack(spacing: 12) {
                    VStack {
                        Text("\(Int(phase.inclinePercent))%")
                            .font(.title3.bold())
                        Text("Incl.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    
                    VStack {
                        Text("\(String(format: "%.1f", phase.speedKmh))")
                            .font(.title3.bold())
                        Text("km/h")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                
                // Phase indicator
                Text("\(currentPhaseIndex + 1)/\(tabata.treadmillPhases?.count ?? 0)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else if isComplete {
                VStack {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.largeTitle)
                        .foregroundStyle(.green)
                    Text("¡Completado!")
                        .font(.headline)
                }
            }
            
            // Controls
            HStack(spacing: 16) {
                if isComplete {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "checkmark")
                    }
                    .tint(.green)
                } else {
                    Button {
                        isPaused.toggle()
                        WKInterfaceDevice.current().play(.click)
                    } label: {
                        Image(systemName: isPaused ? "play.fill" : "pause.fill")
                    }
                    .tint(isPaused ? .green : .orange)
                    
                    Button {
                        timer?.invalidate()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .tint(.red)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .onAppear {
            startCountdown()
        }
        .onDisappear {
            timer?.invalidate()
        }
    }
    
    private func startCountdown() {
        isCountdown = true
        secondsRemaining = 3
        WKInterfaceDevice.current().play(.start)
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            guard !isPaused else { return }
            
            if secondsRemaining == 4 {
                WKInterfaceDevice.current().play(.click)
            }
            
            secondsRemaining -= 1
            
            if secondsRemaining <= 0 {
                advancePhase()
            } else if isCountdown && secondsRemaining <= 3 {
                WKInterfaceDevice.current().play(.click)
            }
        }
    }
    
    private func advancePhase() {
        if isCountdown {
            isCountdown = false
            currentPhaseIndex = 0
            if let phase = tabata.treadmillPhases?.first {
                secondsRemaining = phase.durationMinutes * 60
                WKInterfaceDevice.current().play(.start)
            }
        } else {
            currentPhaseIndex += 1
            if let phases = tabata.treadmillPhases,
               currentPhaseIndex < phases.count {
                secondsRemaining = phases[currentPhaseIndex].durationMinutes * 60
                WKInterfaceDevice.current().play(.start)
            } else {
                // Complete
                timer?.invalidate()
                isComplete = true
                WKInterfaceDevice.current().play(.success)
            }
        }
    }
    
    private func formattedTime(_ seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

// MARK: - Preview helpers
extension Tabata {
    static let previewInterval = Tabata(id: "prev", name: "Preview", workSeconds: 20, restSeconds: 10, rounds: 4)
}

#Preview {
    TabataTimerWatchView(tabata: Tabata.previewInterval)
}
