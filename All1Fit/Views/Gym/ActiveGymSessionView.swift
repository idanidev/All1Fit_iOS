import SwiftUI
import UserNotifications

// MARK: - Sesión de Entrenamiento Activa (logger estilo Strong/Hevy)
/// Registro en vivo: series con peso/reps y tipo (calentamiento/fallo/drop), RPE,
/// valores de la sesión anterior, 1RM estimado, temporizador de descanso con
/// notificación, calculadora de discos, PRs y resumen final.
struct ActiveGymSessionView: View {
    @ObservedObject var sessionService: GymSessionService

    @Environment(\.dismiss) private var dismiss
    @AppStorage("weightUnit") private var weightUnit: WeightUnit = .kg
    @State private var restEndDate: Date?
    @State private var restTotalSeconds: Int = 0
    @State private var showingLibrary = false
    @State private var showingFinishConfirm = false
    @State private var showingDiscardConfirm = false
    @State private var showingEmptyAlert = false
    @State private var showingPlateCalc = false
    @State private var plateCalcWeight: Double = 60
    @State private var summarySession: GymSession?
    @State private var summaryPRs: [String] = []
    @State private var showingSummary = false
    @State private var errorMessage: String?
    @FocusState private var inputFocused: Bool

    var body: some View {
        NavigationStack {
            Group {
                if let sessionBinding = Binding($sessionService.activeSession) {
                    sessionContent(sessionBinding)
                } else {
                    // La sesión terminó o se descartó (si hay resumen pendiente, no cerrar aún)
                    Color(uiColor: .systemGroupedBackground)
                        .ignoresSafeArea()
                        .onAppear { if !showingSummary { dismiss() } }
                }
            }
            .navigationTitle(sessionService.activeSession?.routineName ?? "Entreno")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        dismiss()   // Minimiza: la sesión sigue viva en el mini player
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(.body.weight(.semibold))
                    }
                    .accessibilityLabel("Minimizar entrenamiento")
                }
                ToolbarItem(placement: .principal) {
                    elapsedTimer
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Terminar") {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        if (sessionService.activeSession?.totalCompletedSets ?? 0) == 0 {
                            showingEmptyAlert = true
                        } else {
                            showingFinishConfirm = true
                        }
                    }
                    .bold()
                    .foregroundStyle(Color.all1FitSuccess)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Hecho") { inputFocused = false }
                }
            }
            .all1FitConfirmation(Binding(
                get: {
                    guard showingFinishConfirm else { return nil }
                    let sets = sessionService.activeSession?.totalCompletedSets ?? 0
                    return All1FitConfirmation(
                        title: "¿Terminar entrenamiento?",
                        message: "Se guardarán \(sets) series completadas en tu historial.",
                        icon: "checkmark.circle.fill",
                        tint: .all1FitSuccess,
                        confirmTitle: "Guardar y terminar",
                        confirmIsDestructive: false,
                        cancelTitle: "Seguir entrenando"
                    ) {
                        finishSession()
                    }
                },
                set: { if $0 == nil { showingFinishConfirm = false } }
            ))
            .all1FitConfirmation(Binding(
                get: {
                    guard showingDiscardConfirm else { return nil }
                    return All1FitConfirmation(
                        title: "¿Descartar entrenamiento?",
                        message: "Se perderá todo el registro de esta sesión. Esta acción no se puede deshacer.",
                        icon: "trash.fill",
                        confirmTitle: "Descartar",
                        cancelTitle: "Seguir entrenando"
                    ) {
                        sessionService.discardActiveSession()
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                        dismiss()
                    }
                },
                set: { if $0 == nil { showingDiscardConfirm = false } }
            ))
            .alert("Sin series completadas", isPresented: $showingEmptyAlert) {
                Button("Descartar sesión", role: .destructive) {
                    sessionService.discardActiveSession()
                }
                Button("Seguir entrenando", role: .cancel) {}
            } message: {
                Text("Marca al menos una serie como completada para guardar el entreno")
            }
            .alert("Error", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
            .sheet(isPresented: $showingLibrary) {
                NavigationStack {
                    ExerciseLibraryView(onSelect: { exercise in
                        sessionService.addExerciseToActive(exercise)
                    })
                }
            }
            .sheet(isPresented: $showingPlateCalc) {
                PlateCalculatorView(initialWeight: plateCalcWeight)
            }
            .fullScreenCover(isPresented: $showingSummary) {
                if let summarySession {
                    WorkoutSummaryView(session: summarySession, prExercises: summaryPRs, weightUnit: weightUnit) {
                        showingSummary = false
                        dismiss()
                    }
                }
            }
        }
        .task { GymRestNotifier.requestAuthorizationIfNeeded() }
        .onDisappear {
            sessionService.persistActiveSnapshot()
            GymRestNotifier.cancel()
        }
    }

    // MARK: - Contenido

    private func sessionContent(_ session: Binding<GymSession>) -> some View {
        VStack(spacing: 0) {
            if restEndDate != nil {
                restTimerBar
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(session.exercises) { $log in
                        ExerciseLogCard(
                            log: $log,
                            previousLog: sessionService.lastLog(for: $log.wrappedValue.exerciseName),
                            bestWeight: sessionService.bestWeight(for: $log.wrappedValue.exerciseName),
                            weightUnit: weightUnit,
                            inputFocused: $inputFocused,
                            onSetCompleted: { restSeconds in
                                startRest(seconds: restSeconds, exerciseName: $log.wrappedValue.exerciseName)
                                sessionService.persistActiveSnapshot()
                            },
                            onPlateCalculator: { weight in
                                plateCalcWeight = weight
                                showingPlateCalc = true
                            },
                            onRemoveExercise: {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                    session.wrappedValue.exercises.removeAll { $0.id == $log.wrappedValue.id }
                                }
                                sessionService.persistActiveSnapshot()
                            }
                        )
                    }

                    addExerciseButton

                    if session.wrappedValue.exercises.isEmpty {
                        Text("Añade tu primer ejercicio para empezar a registrar series")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.top, 8)
                    }

                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        showingDiscardConfirm = true
                    } label: {
                        Label("Descartar entrenamiento", systemImage: "trash")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.all1FitError)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 8)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
    }

    // MARK: - Timer transcurrido

    private var elapsedTimer: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            if let start = sessionService.activeSession?.startDate {
                Text(formatElapsed(Date().timeIntervalSince(start)))
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
    }

    private func formatElapsed(_ interval: TimeInterval) -> String {
        let total = Int(max(interval, 0))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%02d:%02d", m, s)
    }

    // MARK: - Barra de descanso

    private var restTimerBar: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { context in
            let remaining = restEndDate.map { max(0, $0.timeIntervalSince(context.date)) } ?? 0

            HStack(spacing: 14) {
                Image(systemName: "timer")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Descanso")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.8))
                    Text(String(format: "%d:%02d", Int(remaining) / 60, Int(remaining) % 60))
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                }

                Spacer()

                Button {
                    restEndDate = restEndDate?.addingTimeInterval(15)
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    Text("+15s")
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.white.opacity(0.2), in: Capsule())
                }
                .buttonStyle(.plain)

                Button {
                    endRest()
                } label: {
                    Text("Saltar")
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.white.opacity(0.2), in: Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                LinearGradient(colors: [.all1FitBlue, .all1FitCyan], startPoint: .leading, endPoint: .trailing)
            )
            .onChange(of: remaining <= 0) { _, expired in
                if expired && restEndDate != nil {
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    endRest()
                }
            }
        }
    }

    private func startRest(seconds: Int, exerciseName: String) {
        guard seconds > 0 else { return }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            restTotalSeconds = seconds
            restEndDate = Date().addingTimeInterval(TimeInterval(seconds))
        }
        GymRestNotifier.schedule(after: TimeInterval(seconds), exerciseName: exerciseName)
    }

    private func endRest() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            restEndDate = nil
        }
        GymRestNotifier.cancel()
    }

    // MARK: - Añadir ejercicio

    private var addExerciseButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            showingLibrary = true
        } label: {
            Label("Añadir ejercicio", systemImage: "plus.circle.fill")
                .font(.subheadline.bold())
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(colors: [.all1FitBlue, .all1FitCyan], startPoint: .leading, endPoint: .trailing),
                    in: RoundedRectangle(cornerRadius: 14)
                )
                .shadow(color: .all1FitBlue.opacity(0.3), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Terminar

    private func finishSession() {
        guard var snapshot = sessionService.activeSession else { return }
        snapshot.endDate = Date()
        snapshot.exercises = snapshot.exercises.filter { !$0.completedSets.isEmpty }

        // PRs: mejor peso de la sesión supera el histórico (antes de guardar)
        let prs = snapshot.exercises.compactMap { log -> String? in
            guard let best = log.bestSet, best.weight > 0 else { return nil }
            return best.weight > sessionService.bestWeight(for: log.exerciseName) ? log.exerciseName : nil
        }

        Task {
            do {
                try await sessionService.finishActiveSession()
                summarySession = snapshot
                summaryPRs = prs
                showingSummary = true
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

// MARK: - Notificación local de fin de descanso
enum GymRestNotifier {
    private static let identifier = "gymRestFinished"

    static func requestAuthorizationIfNeeded() {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .notDetermined else { return }
            center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
        }
    }

    static func schedule(after seconds: TimeInterval, exerciseName: String) {
        cancel()
        let content = UNMutableNotificationContent()
        content.title = "Descanso terminado"
        content.body = "Siguiente serie: \(exerciseName)"
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, seconds), repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    static func cancel() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
    }
}

// MARK: - Tarjeta de ejercicio en sesión
struct ExerciseLogCard: View {
    @Binding var log: GymExerciseLog
    let previousLog: GymExerciseLog?
    let bestWeight: Double
    let weightUnit: WeightUnit
    var inputFocused: FocusState<Bool>.Binding
    let onSetCompleted: (Int) -> Void
    let onPlateCalculator: (Double) -> Void
    let onRemoveExercise: () -> Void

    private var muscle: BodyPart {
        log.catalogExercise?.primaryMuscle ?? .none
    }

    private func fmt(_ value: Double) -> String {
        let converted = weightUnit.convert(value)
        return converted.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(converted))" : String(format: "%.1f", converted)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 8) {
                Text(log.exerciseName)
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundStyle(muscle.color)
                    .lineLimit(1)

                if let group = log.supersetGroup {
                    Text("SS\(group)")
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.all1FitPurple, in: Capsule())
                }

                if log.progressionApplied {
                    HStack(spacing: 2) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 8, weight: .black))
                        Text("+\(fmt(GymSessionService.progressionIncrement(for: log.exerciseName))) \(weightUnit.symbol)")
                            .font(.system(size: 10, weight: .black, design: .rounded))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color.all1FitSuccess, in: Capsule())
                    .accessibilityLabel("Progresión aplicada: peso subido automáticamente")
                }

                Spacer()

                if let rm = log.bestEstimated1RM {
                    VStack(alignment: .trailing, spacing: 0) {
                        Text("1RM est.")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundStyle(.tertiary)
                        Text("\(fmt(rm)) \(weightUnit.symbol)")
                            .font(.system(.caption, design: .rounded, weight: .bold))
                            .foregroundStyle(Color.all1FitCyan)
                            .contentTransition(.numericText())
                    }
                }

                Menu {
                    Button {
                        let weight = log.sets.last(where: { $0.weight > 0 })?.weight ?? bestWeight
                        onPlateCalculator(weight > 0 ? weight : 60)
                    } label: {
                        Label("Calculadora de discos", systemImage: "circle.circle")
                    }
                    Button(role: .destructive) { onRemoveExercise() } label: {
                        Label("Quitar ejercicio", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Opciones de \(log.exerciseName)")
            }

            // Cabecera de columnas
            HStack(spacing: 8) {
                Text("SERIE")
                    .frame(width: 40, alignment: .leading)
                Text("ANTERIOR")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(weightUnit.symbol.uppercased())
                    .frame(width: 64)
                Text("REPS")
                    .frame(width: 52)
                Image(systemName: "checkmark")
                    .frame(width: 36)
            }
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.secondary)

            // Series
            VStack(spacing: 8) {
                ForEach(Array($log.sets.enumerated()), id: \.element.id) { index, $set in
                    SetRow(
                        index: index + 1,
                        set: $set,
                        previousSet: previousSet(at: index),
                        isPR: set.completed && set.type != .warmup && set.weight > 0 && set.weight >= bestWeight && bestWeight > 0,
                        weightUnit: weightUnit,
                        inputFocused: inputFocused,
                        onCompleted: { onSetCompleted(log.restSeconds) }
                    )
                }
            }

            // Añadir serie
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                let last = log.sets.last
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    log.sets.append(GymSet(reps: last?.reps ?? 10, weight: last?.weight ?? 0))
                }
            } label: {
                Label("Añadir serie", systemImage: "plus")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(muscle.color)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(muscle.color.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                .overlay {
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(.white.opacity(0.07), lineWidth: 1)
                }
        }
    }

    private func previousSet(at index: Int) -> GymSet? {
        guard let previousLog else { return nil }
        let completed = previousLog.completedSets
        guard !completed.isEmpty else { return nil }
        return completed.indices.contains(index) ? completed[index] : completed.last
    }
}

// MARK: - Fila de serie
struct SetRow: View {
    let index: Int
    @Binding var set: GymSet
    let previousSet: GymSet?
    let isPR: Bool
    let weightUnit: WeightUnit
    var inputFocused: FocusState<Bool>.Binding
    let onCompleted: () -> Void

    private var previousText: String {
        guard let previousSet else { return "—" }
        let w = weightUnit.convert(previousSet.weight)
        let wText = w.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(w))" : String(format: "%.1f", w)
        return "\(wText)×\(previousSet.reps)"
    }

    /// El peso se almacena siempre en kg; el TextField edita en la unidad del usuario
    private var weightInUserUnit: Binding<Double> {
        Binding(
            get: { (weightUnit.convert(set.weight) * 100).rounded() / 100 },
            set: { set.weight = weightUnit.toKilograms($0) }
        )
    }

    var body: some View {
        HStack(spacing: 8) {
            // Número de serie / tipo / RPE (menú)
            Menu {
                Section("Tipo de serie") {
                    ForEach(GymSetType.allCases, id: \.self) { type in
                        Button {
                            set.type = type
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        } label: {
                            if set.type == type {
                                Label(type.label, systemImage: "checkmark")
                            } else {
                                Text(type.label)
                            }
                        }
                    }
                }
                Section("RPE (esfuerzo)") {
                    ForEach([6, 7, 8, 9, 10], id: \.self) { value in
                        Button {
                            set.rpe = set.rpe == value ? nil : value
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        } label: {
                            if set.rpe == value {
                                Label("RPE \(value)", systemImage: "checkmark")
                            } else {
                                Text("RPE \(value)")
                            }
                        }
                    }
                }
            } label: {
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 3) {
                        if isPR {
                            Image(systemName: "trophy.fill")
                                .font(.caption)
                                .foregroundStyle(.yellow)
                        } else if let badge = set.type.badge {
                            Text(badge)
                                .font(.system(.subheadline, design: .rounded, weight: .black))
                                .foregroundStyle(set.type.color)
                        } else {
                            Text("\(index)")
                                .font(.system(.subheadline, design: .rounded, weight: .bold))
                                .foregroundStyle(.secondary)
                        }
                        Image(systemName: "chevron.down")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundStyle(.tertiary)
                    }
                    if let rpe = set.rpe {
                        Text("RPE \(rpe)")
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundStyle(Color.all1FitWarning)
                    }
                }
            }
            .frame(width: 40, alignment: .leading)
            .accessibilityLabel("Serie \(index): tipo \(set.type.label)\(set.rpe.map { ", RPE \($0)" } ?? "")")

            // Anterior
            Text(previousText)
                .font(.system(.caption, design: .rounded, weight: .medium))
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(1)

            // Peso
            TextField("0", value: weightInUserUnit, format: .number)
                .keyboardType(.decimalPad)
                .focused(inputFocused)
                .multilineTextAlignment(.center)
                .font(.system(.body, design: .rounded, weight: .bold))
                .frame(width: 64, height: 34)
                .background(Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))
                .accessibilityLabel("Peso serie \(index), \(weightUnit.symbol)")

            // Reps
            TextField("0", value: $set.reps, format: .number)
                .keyboardType(.numberPad)
                .focused(inputFocused)
                .multilineTextAlignment(.center)
                .font(.system(.body, design: .rounded, weight: .bold))
                .frame(width: 52, height: 34)
                .background(Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))
                .accessibilityLabel("Repeticiones serie \(index)")

            // Completar
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    set.completed.toggle()
                }
                if set.completed {
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    onCompleted()
                } else {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
            } label: {
                Image(systemName: set.completed ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(set.completed ? Color.all1FitSuccess : Color.secondary)
            }
            .buttonStyle(.plain)
            .frame(width: 36)
            .accessibilityLabel(set.completed ? "Serie \(index) completada" : "Completar serie \(index)")
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 6)
        .background {
            if set.completed {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.all1FitSuccess.opacity(0.08))
            }
        }
    }
}

#Preview {
    ActiveGymSessionView(sessionService: {
        let service = GymSessionService()
        service.startSession(from: GymRoutine.sample)
        return service
    }())
    .preferredColorScheme(.dark)
}
