import SwiftUI

// MARK: - Tabata Timer View
struct TabataTimerView: View {
    let tabata: Tabata? // Now optional because it comes from Manager
    let syncWithWatch: Bool
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var tabataService: TabataService
    @StateObject private var sessionManager = TabataSessionManager.shared
    
    // Alert state
    @State private var showingExitConfirmation = false
    
    // Colors
    private var phaseColor: Color {
        switch sessionManager.phase {
        case .countdown: return .orange
        case .work: return .green
        case .rest: return .red
        case .setRest: return .blue
        case .complete: return .purple
        }
    }
    
    // If view is init directly (from list), we might need to start session.
    // If coming from MiniPlayer, session is already active.
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [phaseColor.opacity(0.3), Color(uiColor: .systemBackground)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            if let activeTabata = sessionManager.activeTabata {
                VStack(spacing: 30) {
                    // Header
                    header(tabata: activeTabata)
                    
                    Spacer()
                    
                    // Main display
                    if activeTabata.type == .intervals {
                        intervalsDisplay(tabata: activeTabata)
                    } else {
                        treadmillDisplay(tabata: activeTabata)
                    }
                    
                    Spacer()
                    
                    // Progress
                    progressView(tabata: activeTabata)
                    
                    // Controls
                    controlButtons
                }
                .padding()
            } else {
                // Should not happen if logic is correct, but safe fallback
                Text("Cargando...")
            }
        }
        .onAppear {
            // Only start if not already active or if it's a different tabata
            if let tabata = tabata {
                if sessionManager.activeTabata?.id != tabata.id || !sessionManager.isActive {
                    sessionManager.startSession(for: tabata)
                }
            }
        }
        // NOTE: We DO NOT stop the timer on disappear anymore
        
        .confirmationDialog(
            "¿Salir del tabata?",
            isPresented: $showingExitConfirmation,
            titleVisibility: .visible
        ) {
            Button("Terminar entrenamiento", role: .destructive) {
                sessionManager.stopSession()
                dismiss()
            }
            Button("Continuar en segundo plano", role: .cancel) {
                // Just dismiss, session keeps running
                dismiss()
            }
        } message: {
            Text("Si sales, el cronómetro seguirá funcionando en segundo plano.")
        }
    }
    
    // MARK: - Header
    private func header(tabata: Tabata) -> some View {
        HStack {
            Button {
                if sessionManager.isComplete {
                    sessionManager.stopSession()
                    dismiss()
                } else {
                    // Direct dismiss supports background execution
                    dismiss() 
                }
            } label: {
                Image(systemName: "chevron.down.circle.fill")
                    .font(.title)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing) {
                Text(tabata.name)
                    .font(.headline)
                
                if syncWithWatch {
                    Label("Watch", systemImage: "applewatch")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }
        }
    }
    
    // MARK: - Intervals Display
    private func intervalsDisplay(tabata: Tabata) -> some View {
        VStack(spacing: 20) {
            // Phase label
            Text(sessionManager.phase.displayName)
                .font(.title2.bold())
                .foregroundStyle(phaseColor)
                .animation(.easeInOut, value: sessionManager.phase)
            
            // Big timer
            Text(formattedTime(sessionManager.secondsRemaining))
                .font(.system(size: 120, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(phaseColor)
                .contentTransition(.numericText())
                .animation(.linear(duration: 0.1), value: sessionManager.secondsRemaining)
            
            // Round indicator
            if sessionManager.phase != .countdown && sessionManager.phase != .complete {
                Text("Ronda \(sessionManager.currentRound) de \(tabata.rounds)")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                
                if tabata.sets > 1 {
                    Text("Set \(sessionManager.currentSet) de \(tabata.sets)")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }
    
    // MARK: - Treadmill Display
    private func treadmillDisplay(tabata: Tabata) -> some View {
        VStack(spacing: 20) {
            if let phases = tabata.treadmillPhases,
               sessionManager.currentPhaseIndex < phases.count {
                let currentPhase = phases[sessionManager.currentPhaseIndex]
                
                // Phase name
                Text(currentPhase.name)
                    .font(.title.bold())
                    .foregroundStyle(phaseColor)
                
                // Timer
                Text(formattedTime(sessionManager.secondsRemaining))
                    .font(.system(size: 100, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(phaseColor)
                    .contentTransition(.numericText())
                
                // Instructions
                VStack(spacing: 12) {
                    HStack(spacing: 30) {
                        VStack {
                            Image(systemName: "arrow.up.right")
                                .font(.title)
                            Text("\(Int(currentPhase.inclinePercent))%")
                                .font(.title2.bold())
                            Text("Inclinación")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        VStack {
                            Image(systemName: "speedometer")
                                .font(.title)
                            Text("\(String(format: "%.1f", currentPhase.speedKmh))")
                                .font(.title2.bold())
                            Text("km/h")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Text(currentPhase.description)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                
                // Phase indicator
                Text("Fase \(sessionManager.currentPhaseIndex + 1) de \(phases.count)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    // MARK: - Progress View
    private func progressView(tabata: Tabata) -> some View {
        VStack(spacing: 8) {
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.2))
                        .frame(height: 8)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(phaseColor)
                        .frame(width: geometry.size.width * sessionManager.progress, height: 8)
                        .animation(.linear(duration: 0.1), value: sessionManager.progress)
                }
            }
            .frame(height: 8)
            
            // Time elapsed
            HStack {
                Text("Tiempo total:")
                Text(formattedTime(sessionManager.totalElapsed))
                    .fontWeight(.medium)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }
    
    // MARK: - Control Buttons
    private var controlButtons: some View {
        HStack(spacing: 20) {
            if sessionManager.isComplete {
                Button {
                    sessionManager.stopSession()
                    dismiss()
                } label: {
                    Label("Terminar", systemImage: "checkmark.circle.fill")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            } else {
                // Pause/Resume
                Button {
                    sessionManager.togglePause()
                } label: {
                    Image(systemName: sessionManager.isPaused ? "play.fill" : "pause.fill")
                        .font(.title)
                        .foregroundStyle(.white)
                        .frame(width: 70, height: 70)
                        .background(sessionManager.isPaused ? Color.green : Color.orange)
                        .clipShape(Circle())
                }
                
                // Stop
                Button {
                    showingExitConfirmation = true
                } label: {
                    Image(systemName: "stop.fill")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .frame(width: 60, height: 60)
                        .background(Color.red)
                        .clipShape(Circle())
                }
            }
        }
        .padding(.bottom, 20)
    }
    
    // MARK: - Helpers
    
    private func formattedTime(_ seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
