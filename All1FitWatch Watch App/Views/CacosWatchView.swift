import SwiftUI
import WatchKit

// MARK: - Cacos Watch View
struct CacosWatchView: View {
    @State private var phase: WatchCacosPhase = .setup
    @State private var runSeconds = 120
    @State private var walkSeconds = 60
    @State private var totalMinutes = 30

    enum WatchCacosPhase {
        case setup
        case countdown(Int)
        case running
    }

    var body: some View {
        switch phase {
        case .setup:
            CacosWatchSetup(
                runSeconds: $runSeconds,
                walkSeconds: $walkSeconds,
                totalMinutes: $totalMinutes,
                onStart: {
                    phase = .countdown(3)
                    startCountdown()
                }
            )
        case .countdown(let n):
            CacosWatchCountdown(value: n)
        case .running:
            CacosWatchTimer(
                runSeconds: runSeconds,
                walkSeconds: walkSeconds,
                totalSeconds: totalMinutes * 60,
                onReset: { phase = .setup }
            )
        }
    }

    private func startCountdown() {
        WKInterfaceDevice.current().play(.start)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { tick(from: 3) }
    }

    private func tick(from n: Int) {
        if n > 1 {
            phase = .countdown(n - 1)
            WKInterfaceDevice.current().play(.click)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { tick(from: n - 1) }
        } else {
            phase = .running
            WKInterfaceDevice.current().play(.success)
        }
    }
}

// MARK: - Watch Setup
struct CacosWatchSetup: View {
    @Binding var runSeconds: Int
    @Binding var walkSeconds: Int
    @Binding var totalMinutes: Int
    let onStart: () -> Void

    private let runOpts = [30, 60, 120, 180, 300]
    private let walkOpts = [20, 30, 60, 120]
    private let totalOpts = [15, 20, 30, 45, 60]

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                Text("Cacos")
                    .font(.headline)

                Picker("Correr", selection: $runSeconds) {
                    ForEach(runOpts, id: \.self) { s in
                        Text(s >= 60 ? "\(s / 60)m" : "\(s)s").tag(s)
                    }
                }
                .pickerStyle(.navigationLink)

                Picker("Caminar", selection: $walkSeconds) {
                    ForEach(walkOpts, id: \.self) { s in
                        Text(s >= 60 ? "\(s / 60)m" : "\(s)s").tag(s)
                    }
                }
                .pickerStyle(.navigationLink)

                Picker("Total", selection: $totalMinutes) {
                    ForEach(totalOpts, id: \.self) { m in
                        Text("\(m)m").tag(m)
                    }
                }
                .pickerStyle(.navigationLink)

                Button(action: onStart) {
                    Label("Empezar", systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
            }
        }
        .navigationTitle("Cacos")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Watch Countdown
struct CacosWatchCountdown: View {
    let value: Int

    var body: some View {
        VStack(spacing: 8) {
            Text("\(value)")
                .font(.system(size: 64, weight: .black, design: .rounded))
                .foregroundStyle(.orange)
            Text("Prepárate...")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Watch Timer
struct CacosWatchTimer: View {
    let runSeconds: Int
    let walkSeconds: Int
    let totalSeconds: Int
    let onReset: () -> Void

    @State private var phase: WatchPhase = .run
    @State private var phaseRemaining: Int = 0
    @State private var totalRemaining: Int = 0
    @State private var isRunning = true
    @State private var isFinished = false
    @State private var timer: Timer?
    @State private var cycle = 1

    enum WatchPhase { case run, walk }

    private var phaseLabel: String { phase == .run ? "CORRE" : "CAMINA" }
    private var phaseColor: Color { phase == .run ? .orange : .blue }
    private var phaseIcon: String { phase == .run ? "figure.run" : "figure.walk" }

    var body: some View {
        VStack(spacing: 6) {
            if isFinished {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(.green)
                    Text("¡Completado!")
                        .font(.headline)
                    Button("Nuevo", action: onReset)
                        .buttonStyle(.bordered)
                }
            } else {
                HStack(spacing: 6) {
                    Image(systemName: phaseIcon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(phaseColor)
                    Text(phaseLabel)
                        .font(.system(.headline, design: .rounded, weight: .black))
                        .foregroundStyle(phaseColor)
                }

                Text(formatTime(phaseRemaining))
                    .font(.system(size: 44, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(phaseColor)
                    .contentTransition(.numericText(countsDown: true))

                Text(formatTime(totalRemaining))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    Button(action: onReset) {
                        Image(systemName: "stop.fill")
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)

                    Button {
                        isRunning.toggle()
                        if isRunning { startTick() } else { timer?.invalidate() }
                    } label: {
                        Image(systemName: isRunning ? "pause.fill" : "play.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(phaseColor)
                }
            }
        }
        .onAppear { setup() }
        .onDisappear { timer?.invalidate() }
    }

    private func setup() {
        phase = .run
        phaseRemaining = runSeconds
        totalRemaining = totalSeconds
        startTick()
    }

    private func startTick() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            Task { @MainActor in self.tick() }
        }
    }

    private func tick() {
        guard isRunning, !isFinished else { return }
        if totalRemaining <= 0 { finish(); return }
        totalRemaining -= 1
        phaseRemaining -= 1
        if phaseRemaining <= 0 { switchPhase() }
    }

    private func switchPhase() {
        if phase == .run {
            phase = .walk
            phaseRemaining = walkSeconds
        } else {
            phase = .run
            phaseRemaining = runSeconds
            cycle += 1
        }
        WKInterfaceDevice.current().play(.notification)
    }

    private func finish() {
        timer?.invalidate()
        isFinished = true
        WKInterfaceDevice.current().play(.success)
    }

    private func formatTime(_ s: Int) -> String {
        String(format: "%d:%02d", s / 60, s % 60)
    }
}

#Preview {
    NavigationStack {
        CacosWatchView()
    }
}
