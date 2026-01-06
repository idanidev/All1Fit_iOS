import SwiftUI

// MARK: - Workout Timer View
struct WorkoutTimerView: View {
    let workout: WatchWorkout
    @EnvironmentObject var connectivityService: WatchConnectivityService
    @Environment(\.dismiss) private var dismiss
    
    @State private var timerState: TimerState = .ready
    @State private var elapsedSeconds: Int = 0
    @State private var rounds: Int = 0
    @State private var timer: Timer?
    @State private var showingSaveConfirmation = false
    
    enum TimerState {
        case ready, running, paused, finished
    }
    
    private var categoryColor: Color {
        switch workout.category {
        case .running: return .orange
        case .crossfit: return .red
        case .competition: return .purple
        }
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // Workout name
            Text(workout.name)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            // Timer display
            timerDisplay
            
            // AMRAP rounds counter
            if !workout.isForTime {
                roundsCounter
            }
            
            Spacer()
            
            // Controls
            controlButtons
        }
        .padding()
        .navigationBarBackButtonHidden(timerState == .running)
        .confirmationDialog("¿Guardar resultado?", isPresented: $showingSaveConfirmation) {
            Button("Guardar") {
                saveResult()
            }
            Button("Descartar", role: .destructive) {
                dismiss()
            }
            Button("Cancelar", role: .cancel) {
                timerState = .paused
            }
        }
        .onDisappear {
            timer?.invalidate()
        }
    }
    
    // MARK: - Timer Display
    private var timerDisplay: some View {
        let hours = elapsedSeconds / 3600
        let minutes = (elapsedSeconds % 3600) / 60
        let seconds = elapsedSeconds % 60
        
        return VStack(spacing: 0) {
            if hours > 0 {
                Text(String(format: "%d:%02d:%02d", hours, minutes, seconds))
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .monospacedDigit()
            } else {
                Text(String(format: "%02d:%02d", minutes, seconds))
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .monospacedDigit()
            }
        }
        .foregroundStyle(timerState == .running ? categoryColor : .primary)
        .contentTransition(.numericText())
        .animation(.linear(duration: 0.1), value: elapsedSeconds)
    }
    
    // MARK: - Rounds Counter (AMRAP)
    private var roundsCounter: some View {
        HStack(spacing: 16) {
            Button {
                if rounds > 0 {
                    rounds -= 1
                    WKInterfaceDevice.current().play(.click)
                }
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            
            VStack(spacing: 0) {
                Text("\(rounds)")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(categoryColor)
                
                Text("rondas")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            
            Button {
                rounds += 1
                WKInterfaceDevice.current().play(.click)
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundStyle(categoryColor)
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - Control Buttons
    private var controlButtons: some View {
        HStack(spacing: 12) {
            switch timerState {
            case .ready:
                Button {
                    startTimer()
                } label: {
                    Label("Iniciar", systemImage: "play.fill")
                        .font(.headline)
                }
                .buttonStyle(.borderedProminent)
                .tint(categoryColor)
                
            case .running:
                Button {
                    pauseTimer()
                } label: {
                    Image(systemName: "pause.fill")
                        .font(.title2)
                }
                .buttonStyle(.bordered)
                
                Button {
                    finishWorkout()
                } label: {
                    Image(systemName: "stop.fill")
                        .font(.title2)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                
            case .paused:
                Button {
                    resumeTimer()
                } label: {
                    Image(systemName: "play.fill")
                        .font(.title2)
                }
                .buttonStyle(.borderedProminent)
                .tint(categoryColor)
                
                Button {
                    finishWorkout()
                } label: {
                    Image(systemName: "stop.fill")
                        .font(.title2)
                }
                .buttonStyle(.bordered)
                .tint(.red)
                
            case .finished:
                Button {
                    saveResult()
                } label: {
                    Label("Guardar", systemImage: "checkmark")
                        .font(.headline)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            }
        }
    }
    
    // MARK: - Timer Controls
    private func startTimer() {
        timerState = .running
        WKInterfaceDevice.current().play(.start)
        
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            elapsedSeconds += 1
            
            // Check AMRAP time cap
            if let timeCap = workout.timeCapMinutes, !workout.isForTime {
                if elapsedSeconds >= timeCap * 60 {
                    finishWorkout()
                }
            }
        }
    }
    
    private func pauseTimer() {
        timerState = .paused
        timer?.invalidate()
        WKInterfaceDevice.current().play(.stop)
    }
    
    private func resumeTimer() {
        timerState = .running
        WKInterfaceDevice.current().play(.start)
        
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            elapsedSeconds += 1
        }
    }
    
    private func finishWorkout() {
        timer?.invalidate()
        timerState = .finished
        WKInterfaceDevice.current().play(.success)
    }
    
    private func saveResult() {
        connectivityService.sendWorkoutResult(
            workoutId: workout.id,
            timeSeconds: elapsedSeconds,
            rounds: workout.isForTime ? nil : rounds,
            notes: nil
        )
        
        WKInterfaceDevice.current().play(.success)
        dismiss()
    }
}

#Preview {
    NavigationStack {
        WorkoutTimerView(workout: WatchWorkout.all[3]) // Cindy AMRAP
    }
    .environmentObject(WatchConnectivityService.shared)
}
