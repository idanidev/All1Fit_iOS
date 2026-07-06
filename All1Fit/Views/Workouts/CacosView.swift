import SwiftUI
import AudioToolbox

// MARK: - Cacos View
struct CacosView: View {
    @State private var timerActive = false
    @State private var countingDown = false
    @State private var countdownValue = 3

    // Config
    @State private var runSeconds: Int = 120
    @State private var walkSeconds: Int = 60
    @State private var totalMinutes: Int = 30

    // Custom picker sheets
    @State private var showRunPicker = false
    @State private var showWalkPicker = false
    @State private var showTotalPicker = false

    // Custom picker temps
    @State private var customRunMin = 2
    @State private var customRunSec = 0
    @State private var customWalkMin = 1
    @State private var customWalkSec = 0
    @State private var customTotalMin = 30

    var body: some View {
        Group {
            if timerActive {
                CacosTimerView(
                    runSeconds: runSeconds,
                    walkSeconds: walkSeconds,
                    totalSeconds: totalMinutes * 60,
                    onReset: { timerActive = false }
                )
            } else {
                ZStack {
                    CacosSetupView(
                        runSeconds: $runSeconds,
                        walkSeconds: $walkSeconds,
                        totalMinutes: $totalMinutes,
                        showRunPicker: $showRunPicker,
                        showWalkPicker: $showWalkPicker,
                        showTotalPicker: $showTotalPicker,
                        onStart: startCountdown
                    )

                    if countingDown {
                        countdownOverlay
                    }
                }
            }
        }
        .navigationTitle("Cacos")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showRunPicker) {
            TimePickerSheet(title: "Tiempo corriendo", color: .orange, minutes: $customRunMin, seconds: $customRunSec) {
                runSeconds = customRunMin * 60 + customRunSec
            }
        }
        .sheet(isPresented: $showWalkPicker) {
            TimePickerSheet(title: "Tiempo caminando", color: .blue, minutes: $customWalkMin, seconds: $customWalkSec) {
                walkSeconds = customWalkMin * 60 + customWalkSec
            }
        }
        .sheet(isPresented: $showTotalPicker) {
            TotalTimePickerSheet(minutes: $customTotalMin) {
                totalMinutes = customTotalMin
            }
        }
    }

    private var countdownOverlay: some View {
        ZStack {
            Color(uiColor: .systemBackground).opacity(0.95).ignoresSafeArea()
            VStack(spacing: 16) {
                if countdownValue > 0 {
                    Text("\(countdownValue)")
                        .font(.system(size: 120, weight: .black, design: .rounded))
                        .foregroundStyle(LinearGradient(colors: [.orange, .red], startPoint: .top, endPoint: .bottom))
                        .id(countdownValue)
                        .transition(.scale(scale: 1.4).combined(with: .opacity))
                } else {
                    Text("¡Ya!")
                        .font(.system(size: 80, weight: .black, design: .rounded))
                        .foregroundStyle(LinearGradient(colors: [.green, .teal], startPoint: .top, endPoint: .bottom))
                        .transition(.scale(scale: 0.6).combined(with: .opacity))
                }
                Text(countdownValue > 0 ? "Prepárate..." : "¡Empieza a correr!")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
        }
        .animation(.spring(duration: 0.4), value: countdownValue)
    }

    private func startCountdown() {
        countdownValue = 3
        countingDown = true
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        scheduleCountdownTick()
    }

    private func scheduleCountdownTick() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            withAnimation {
                if countdownValue > 1 {
                    countdownValue -= 1
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    scheduleCountdownTick()
                } else if countdownValue == 1 {
                    countdownValue = 0
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                        countingDown = false
                        timerActive = true
                    }
                }
            }
        }
    }
}

// MARK: - Setup View
struct CacosSetupView: View {
    @Binding var runSeconds: Int
    @Binding var walkSeconds: Int
    @Binding var totalMinutes: Int
    @Binding var showRunPicker: Bool
    @Binding var showWalkPicker: Bool
    @Binding var showTotalPicker: Bool
    let onStart: () -> Void

    private let runOptions: [(label: String, value: Int)] = [
        ("30s", 30), ("1m", 60), ("2m", 120), ("3m", 180), ("5m", 300), ("8m", 480)
    ]
    private let walkOptions: [(label: String, value: Int)] = [
        ("20s", 20), ("30s", 30), ("1m", 60), ("2m", 120), ("3m", 180)
    ]
    private let totalOptions: [Int] = [15, 20, 30, 40, 45, 60]

    private var estimatedCycles: Int {
        let c = runSeconds + walkSeconds
        return c > 0 ? (totalMinutes * 60) / c : 0
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                heroHeader
                healthStatsCard

                IntervalConfigCard(
                    title: "Tiempo corriendo",
                    icon: "figure.run",
                    color: .orange,
                    currentValue: runSeconds,
                    options: runOptions,
                    onSelect: { runSeconds = $0 },
                    onCustom: { showRunPicker = true }
                )

                IntervalConfigCard(
                    title: "Tiempo caminando",
                    icon: "figure.walk",
                    color: .blue,
                    currentValue: walkSeconds,
                    options: walkOptions,
                    onSelect: { walkSeconds = $0 },
                    onCustom: { showWalkPicker = true }
                )

                totalDurationCard

                HStack(spacing: 10) {
                    SummaryPill(value: "\(estimatedCycles)", label: "ciclos")
                    SummaryPill(value: formatTime(runSeconds), label: "corres")
                    SummaryPill(value: formatTime(walkSeconds), label: "caminas")
                }

                Button(action: onStart) {
                    Label("Empezar", systemImage: "play.fill")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(LinearGradient(colors: [.orange, .red], startPoint: .leading, endPoint: .trailing))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
            }
            .padding(20)
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
    }

    private var heroHeader: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(LinearGradient(colors: [.orange.opacity(0.12), .blue.opacity(0.12)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(height: 90)
            HStack(spacing: 20) {
                VStack(spacing: 4) {
                    Image(systemName: "figure.run")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(.orange)
                    Text("CORRE")
                        .font(.caption.bold())
                        .foregroundStyle(.orange)
                }
                Image(systemName: "arrow.left.arrow.right")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                VStack(spacing: 4) {
                    Image(systemName: "figure.walk")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(.blue)
                    Text("CAMINA")
                        .font(.caption.bold())
                        .foregroundStyle(.blue)
                }
            }
        }
    }

    private var healthStatsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Tu actividad · Últimos 7 días", systemImage: "heart.fill")
                    .font(.caption.bold())
                    .foregroundStyle(.pink)
                Spacer()
                Text("próximamente HealthKit")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            HStack(spacing: 0) {
                HealthStatMini(value: "3", label: "sesiones", color: .orange)
                Divider().frame(height: 30)
                HealthStatMini(value: "1h 25m", label: "total", color: .blue)
                Divider().frame(height: 30)
                HealthStatMini(value: "~420", label: "kcal", color: .pink)
            }

            HStack {
                Image(systemName: "clock")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("Última sesión hace 2 días · media 28 min")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var totalDurationCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Duración total", systemImage: "clock")
                    .font(.subheadline.bold())
                Spacer()
                Button("Personalizar") { showTotalPicker = true }
                    .font(.caption.bold())
                    .foregroundStyle(.purple)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(totalOptions, id: \.self) { min in
                        Button {
                            totalMinutes = min
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        } label: {
                            Text("\(min) min")
                                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                                .foregroundStyle(totalMinutes == min ? .white : .primary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    totalMinutes == min
                                    ? AnyShapeStyle(LinearGradient(colors: [.purple, .pink], startPoint: .leading, endPoint: .trailing))
                                    : AnyShapeStyle(Color(uiColor: .tertiarySystemGroupedBackground))
                                )
                                .clipShape(Capsule())
                        }
                    }
                    if !totalOptions.contains(totalMinutes) {
                        Text("\(totalMinutes) min")
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(LinearGradient(colors: [.purple, .pink], startPoint: .leading, endPoint: .trailing), in: Capsule())
                    }
                }
                .padding(.horizontal, 2)
            }
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func formatTime(_ s: Int) -> String {
        s >= 60 ? "\(s/60)m \(s % 60 > 0 ? "\(s % 60)s" : "")" : "\(s)s"
    }
}

// MARK: - Interval Config Card
struct IntervalConfigCard: View {
    let title: String
    let icon: String
    let color: Color
    let currentValue: Int
    let options: [(label: String, value: Int)]
    let onSelect: (Int) -> Void
    let onCustom: () -> Void

    private var isCustom: Bool {
        !options.contains(where: { $0.value == currentValue })
    }

    private func formatTime(_ s: Int) -> String {
        let m = s / 60; let sec = s % 60
        if m > 0 && sec > 0 { return "\(m)m \(sec)s" }
        if m > 0 { return "\(m)m" }
        return "\(sec)s"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(title, systemImage: icon)
                    .font(.subheadline.bold())
                    .foregroundStyle(color)
                Spacer()
                Button("Personalizar") { onCustom() }
                    .font(.caption.bold())
                    .foregroundStyle(color)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(options, id: \.value) { opt in
                        Button {
                            onSelect(opt.value)
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        } label: {
                            Text(opt.label)
                                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                                .foregroundStyle(currentValue == opt.value && !isCustom ? .white : .primary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    currentValue == opt.value && !isCustom
                                    ? AnyShapeStyle(color)
                                    : AnyShapeStyle(Color(uiColor: .tertiarySystemGroupedBackground))
                                )
                                .clipShape(Capsule())
                        }
                    }
                    if isCustom {
                        Text(formatTime(currentValue))
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(color, in: Capsule())
                    }
                }
                .padding(.horizontal, 2)
            }
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Health Stat Mini
struct HealthStatMini: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Time Picker Sheet
struct TimePickerSheet: View {
    let title: String
    let color: Color
    @Binding var minutes: Int
    @Binding var seconds: Int
    let onConfirm: () -> Void
    @Environment(\.dismiss) private var dismiss

    private let secondOptions = [0, 15, 30, 45]

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(minutes > 0 ? "\(minutes)m" : "")
                        .font(.system(size: 44, weight: .black, design: .rounded))
                        .foregroundStyle(color)
                    Text(seconds > 0 ? "\(seconds)s" : (minutes == 0 ? "0s" : ""))
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(color.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
                .padding(.top)

                Divider()

                HStack(spacing: 0) {
                    VStack {
                        Text("Minutos")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                        Picker("Minutos", selection: $minutes) {
                            ForEach(0..<60, id: \.self) { m in
                                Text("\(m) min").tag(m)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(maxWidth: .infinity)
                    }
                    VStack {
                        Text("Segundos")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                        Picker("Segundos", selection: $seconds) {
                            ForEach(secondOptions, id: \.self) { s in
                                Text("\(s) seg").tag(s)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(maxWidth: .infinity)
                    }
                }

                Spacer()
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Aplicar") {
                        onConfirm()
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        dismiss()
                    }
                    .font(.headline)
                    .disabled(minutes == 0 && seconds == 0)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Total Time Picker Sheet
struct TotalTimePickerSheet: View {
    @Binding var minutes: Int
    let onConfirm: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("\(minutes) min")
                    .font(.system(size: 52, weight: .black, design: .rounded))
                    .foregroundStyle(LinearGradient(colors: [.purple, .pink], startPoint: .leading, endPoint: .trailing))
                    .padding(.top)

                Picker("Minutos", selection: $minutes) {
                    ForEach(Array(stride(from: 5, through: 120, by: 5)), id: \.self) { m in
                        Text("\(m) minutos").tag(m)
                    }
                }
                .pickerStyle(.wheel)

                Spacer()
            }
            .navigationTitle("Duración total")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Aplicar") {
                        onConfirm()
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        dismiss()
                    }
                    .font(.headline)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Summary Pill
struct SummaryPill: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 18, weight: .black, design: .rounded))
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Timer View
struct CacosTimerView: View {
    let runSeconds: Int
    let walkSeconds: Int
    let totalSeconds: Int
    let onReset: () -> Void

    @State private var phase: Phase = .run
    @State private var phaseRemaining: Int = 0
    @State private var totalRemaining: Int = 0
    @State private var cycle: Int = 1
    @State private var isRunning = false
    @State private var isFinished = false
    @State private var timer: Timer?
    @State private var startDate: Date = Date()
    @AppStorage("weightUnit") private var weightUnit: WeightUnit = .kg

    enum Phase { case run, walk }

    private var phaseColor: Color { phase == .run ? .orange : .blue }
    private var phaseGradient: [Color] { phase == .run ? [.orange, .red] : [.blue, .cyan] }
    private var phaseIcon: String { phase == .run ? "figure.run" : "figure.walk" }
    private var phaseLabel: String { phase == .run ? "CORRE" : "CAMINA" }
    private var nextLabel: String { phase == .run ? "Caminar \(formatTime(walkSeconds))" : "Correr \(formatTime(runSeconds))" }

    private var progress: Double {
        guard totalSeconds > 0 else { return 0 }
        return Double(totalSeconds - totalRemaining) / Double(totalSeconds)
    }

    private var phaseProgress: Double {
        let total = phase == .run ? runSeconds : walkSeconds
        guard total > 0 else { return 0 }
        return Double(total - phaseRemaining) / Double(total)
    }

    var body: some View {
        ZStack {
            Color(uiColor: .systemGroupedBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Phase indicator
                VStack(spacing: 8) {
                    Image(systemName: phaseIcon)
                        .font(.system(size: 52, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(colors: phaseGradient, startPoint: .top, endPoint: .bottom)
                        )
                        .contentTransition(.symbolEffect(.replace))

                    Text(phaseLabel)
                        .font(.system(size: 42, weight: .black, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(colors: phaseGradient, startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .contentTransition(.identity)
                        .id(phaseLabel)
                }

                Spacer().frame(height: 32)

                // Phase countdown ring
                ZStack {
                    Circle()
                        .stroke(phaseColor.opacity(0.15), lineWidth: 10)
                        .frame(width: 180, height: 180)

                    Circle()
                        .trim(from: 0, to: phaseProgress)
                        .stroke(
                            LinearGradient(colors: phaseGradient, startPoint: .topLeading, endPoint: .bottomTrailing),
                            style: StrokeStyle(lineWidth: 10, lineCap: .round)
                        )
                        .frame(width: 180, height: 180)
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 1), value: phaseProgress)

                    VStack(spacing: 2) {
                        Text(formatCountdown(phaseRemaining))
                            .font(.system(size: 52, weight: .black, design: .rounded))
                            .monospacedDigit()
                            .contentTransition(.numericText(countsDown: true))
                        Text("seg")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer().frame(height: 24)

                // Session info row
                HStack(spacing: 24) {
                    VStack(spacing: 2) {
                        Text(formatCountdown(totalRemaining))
                            .font(.system(.title3, design: .rounded, weight: .bold))
                            .monospacedDigit()
                        Text("restante")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    VStack(spacing: 2) {
                        Text("Ciclo \(cycle)")
                            .font(.system(.title3, design: .rounded, weight: .bold))
                        Text("de \(estimatedCycles)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    VStack(spacing: 2) {
                        Text(nextLabel)
                            .font(.system(.caption, design: .rounded, weight: .semibold))
                            .foregroundStyle(.secondary)
                        Text("siguiente")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(.horizontal, 24)

                Spacer().frame(height: 16)

                // Total progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(uiColor: .systemFill))
                            .frame(height: 6)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(LinearGradient(colors: [.orange, .blue], startPoint: .leading, endPoint: .trailing))
                            .frame(width: geo.size.width * progress, height: 6)
                            .animation(.linear(duration: 1), value: progress)
                    }
                }
                .frame(height: 6)
                .padding(.horizontal, 32)

                Spacer().frame(height: 32)

                // Controls
                if isFinished {
                    VStack(spacing: 12) {
                        Text("¡Sesión completada!")
                            .font(.headline)
                            .foregroundStyle(.green)
                        Button(action: onReset) {
                            Label("Nueva sesión", systemImage: "arrow.counterclockwise")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(.orange, in: RoundedRectangle(cornerRadius: 14))
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 32)
                    }
                } else {
                    HStack(spacing: 16) {
                        Button(action: onReset) {
                            Image(systemName: "stop.fill")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                                .frame(width: 56, height: 56)
                                .background(Color(uiColor: .secondarySystemGroupedBackground), in: Circle())
                        }
                        .buttonStyle(.plain)

                        Button(action: toggleTimer) {
                            Image(systemName: isRunning ? "pause.fill" : "play.fill")
                                .font(.title2)
                                .foregroundStyle(.white)
                                .frame(width: 72, height: 72)
                                .background(
                                    LinearGradient(colors: phaseGradient, startPoint: .topLeading, endPoint: .bottomTrailing),
                                    in: Circle()
                                )
                        }
                        .buttonStyle(.plain)

                        Button { skipPhase() } label: {
                            Image(systemName: "forward.fill")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                                .frame(width: 56, height: 56)
                                .background(Color(uiColor: .secondarySystemGroupedBackground), in: Circle())
                        }
                        .buttonStyle(.plain)
                    }
                }

                Spacer()
            }
        }
        .onAppear { setupTimer() }
        .onDisappear { timer?.invalidate() }
    }

    // MARK: - Helpers

    private var estimatedCycles: Int {
        let c = (runSeconds + walkSeconds)
        guard c > 0 else { return 0 }
        return totalSeconds / c
    }

    private func setupTimer() {
        phase = .run
        phaseRemaining = runSeconds
        totalRemaining = totalSeconds
        cycle = 1
        isRunning = true
        startDate = Date()
        startTick()
    }

    private func toggleTimer() {
        isRunning.toggle()
        if isRunning { startTick() } else { timer?.invalidate() }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    private func startTick() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            tick()
        }
    }

    private func tick() {
        guard isRunning else { return }

        if totalRemaining <= 0 {
            finish(); return
        }

        totalRemaining -= 1
        phaseRemaining -= 1

        if phaseRemaining <= 0 {
            switchPhase()
        }
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
        hapticSwitch()
    }

    private func skipPhase() {
        switchPhase()
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    }

    private func finish() {
        timer?.invalidate()
        isRunning = false
        isFinished = true
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        AudioServicesPlaySystemSound(1005)
        let elapsed = TimeInterval(totalSeconds - totalRemaining)
        Task {
            await HealthKitService.shared.saveWorkout(
                activityType: .running,
                startDate: startDate,
                duration: elapsed
            )
        }
    }

    private func hapticSwitch() {
        let gen = UINotificationFeedbackGenerator()
        gen.notificationOccurred(.warning)
        AudioServicesPlaySystemSound(1057)
    }

    private func formatCountdown(_ s: Int) -> String {
        let m = s / 60
        let sec = s % 60
        if m > 0 { return String(format: "%d:%02d", m, sec) }
        return "\(sec)"
    }

    private func formatTime(_ s: Int) -> String {
        s >= 60 ? "\(s/60)m" : "\(s)s"
    }
}

#Preview {
    NavigationStack {
        CacosView()
    }
}
