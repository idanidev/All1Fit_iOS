import SwiftUI

// MARK: - Quick Timer View
struct QuickTimerView: View {
    @State private var timerState: QuickTimerState = .ready
    @State private var elapsedSeconds: Int = 0
    @State private var timer: Timer?
    @State private var laps: [Int] = []
    
    enum QuickTimerState {
        case ready, running, paused
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Timer display
            timerDisplay
            
            // Lap display (if any)
            if !laps.isEmpty {
                lapDisplay
            }
            
            Spacer()
            
            // Controls
            controlButtons
        }
        .padding()
        .navigationTitle("Timer")
        .navigationBarBackButtonHidden(timerState == .running)
        .onDisappear {
            timer?.invalidate()
        }
    }
    
    // MARK: - Timer Display
    private var timerDisplay: some View {
        let hours = elapsedSeconds / 3600
        let minutes = (elapsedSeconds % 3600) / 60
        let seconds = elapsedSeconds % 60
        let showHours = hours > 0
        
        return VStack(spacing: 0) {
            if showHours {
                Text(String(format: "%d:%02d:%02d", hours, minutes, seconds))
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .monospacedDigit()
            } else {
                Text(String(format: "%02d:%02d", minutes, seconds))
                    .font(.system(size: 50, weight: .bold, design: .rounded))
                    .monospacedDigit()
            }
        }
        .foregroundStyle(timerState == .running ? .green : .primary)
        .contentTransition(.numericText())
        .animation(.linear(duration: 0.1), value: elapsedSeconds)
    }
    
    // MARK: - Lap Display
    private var lapDisplay: some View {
        ScrollView {
            VStack(spacing: 4) {
                ForEach(Array(laps.enumerated().reversed()), id: \.offset) { index, lapTime in
                    HStack {
                        Text("Lap \(index + 1)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        
                        Spacer()
                        
                        Text(formatTime(lapTime))
                            .font(.caption)
                            .monospacedDigit()
                    }
                }
            }
        }
        .frame(maxHeight: 60)
    }
    
    // MARK: - Control Buttons
    private var controlButtons: some View {
        HStack(spacing: 8) {
            switch timerState {
            case .ready:
                Button {
                    startTimer()
                } label: {
                    Image(systemName: "play.fill")
                        .font(.title2)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                
            case .running:
                // Lap button
                Button {
                    addLap()
                } label: {
                    Image(systemName: "flag.fill")
                        .font(.body)
                }
                .buttonStyle(.bordered)
                
                // Pause button
                Button {
                    pauseTimer()
                } label: {
                    Image(systemName: "pause.fill")
                        .font(.title3)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                
            case .paused:
                // Reset button
                Button {
                    resetTimer()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.body)
                }
                .buttonStyle(.bordered)
                .tint(.red)
                
                // Resume button
                Button {
                    resumeTimer()
                } label: {
                    Image(systemName: "play.fill")
                        .font(.title3)
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
    
    private func resetTimer() {
        timer?.invalidate()
        timerState = .ready
        elapsedSeconds = 0
        laps = []
        WKInterfaceDevice.current().play(.click)
    }
    
    private func addLap() {
        laps.append(elapsedSeconds)
        WKInterfaceDevice.current().play(.click)
    }
    
    // MARK: - Helpers
    private func formatTime(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%02d:%02d", minutes, secs)
    }
}

#Preview {
    NavigationStack {
        QuickTimerView()
    }
}
