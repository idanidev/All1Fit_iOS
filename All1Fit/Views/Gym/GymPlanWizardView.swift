import SwiftUI

// MARK: - Asistente de Plan a Medida
/// Cuestionario de 4 pasos (objetivo, experiencia, días, equipamiento)
/// que genera un programa de rutinas personalizado.
struct GymPlanWizardView: View {
    @ObservedObject var routineService: GymRoutineService
    @Environment(\.dismiss) private var dismiss

    @State private var step = 0
    @State private var prefs = GymPlanPreferences()
    @State private var isSaving = false
    @State private var errorMessage: String?

    private let totalSteps = 5   // 4 preguntas + resumen

    private var generatedPlan: [GymRoutine] {
        GymPlanGenerator.makePlan(from: prefs)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                progressDots

                TabView(selection: $step) {
                    goalStep.tag(0)
                    experienceStep.tag(1)
                    daysStep.tag(2)
                    equipmentStep.tag(3)
                    summaryStep.tag(4)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: step)

                bottomButton
            }
            .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Plan a medida")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                if step > 0 {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button {
                            withAnimation { step -= 1 }
                        } label: {
                            Image(systemName: "chevron.left")
                        }
                        .accessibilityLabel("Paso anterior")
                    }
                }
            }
            .alert("Error", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(24)
    }

    // MARK: - Progreso

    private var progressDots: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalSteps, id: \.self) { index in
                Capsule()
                    .fill(index <= step ? Color.all1FitBlue : Color(uiColor: .tertiarySystemGroupedBackground))
                    .frame(width: index == step ? 24 : 8, height: 8)
            }
        }
        .padding(.top, 16)
        .padding(.bottom, 8)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: step)
    }

    // MARK: - Pasos

    private var goalStep: some View {
        questionPage(title: "¿Cuál es tu objetivo?", subtitle: "Define series, repeticiones y descansos") {
            ForEach(GymGoal.allCases) { goal in
                optionCard(
                    label: goal.label,
                    detail: schemeDescription(goal),
                    icon: goal.icon,
                    isSelected: prefs.goal == goal
                ) {
                    prefs.goal = goal
                }
            }
        }
    }

    private var experienceStep: some View {
        questionPage(title: "¿Tu experiencia?", subtitle: "Ajusta la selección de ejercicios") {
            ForEach(GymExperience.allCases) { level in
                optionCard(
                    label: level.label,
                    detail: level.detail,
                    icon: "chart.bar.fill",
                    isSelected: prefs.experience == level
                ) {
                    prefs.experience = level
                }
            }
        }
    }

    private var daysStep: some View {
        questionPage(title: "¿Cuántos días por semana?", subtitle: "Define la estructura del programa") {
            ForEach([2, 3, 4, 5], id: \.self) { days in
                optionCard(
                    label: days == 5 ? "5 o más días" : "\(days) días",
                    detail: splitDescription(days),
                    icon: "calendar",
                    isSelected: prefs.daysPerWeek == days
                ) {
                    prefs.daysPerWeek = days
                }
            }
        }
    }

    private var equipmentStep: some View {
        questionPage(title: "¿Con qué equipamiento cuentas?", subtitle: "Filtra los ejercicios disponibles") {
            ForEach(GymEquipmentAccess.allCases) { access in
                optionCard(
                    label: access.label,
                    detail: equipmentDescription(access),
                    icon: access.icon,
                    isSelected: prefs.equipment == access
                ) {
                    prefs.equipment = access
                }
            }
        }
    }

    private var summaryStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(spacing: 6) {
                    Text("Tu plan está listo")
                        .font(.system(size: 24, weight: .black, design: .rounded))
                    Text("\(prefs.goal.label) · \(prefs.experience.label) · \(prefs.daysPerWeek)+ días · \(prefs.equipment.label)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 8)

                // Pauta de ejecución basada en los metaanálisis 2024-2026
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "text.book.closed.fill")
                        .font(.subheadline)
                        .foregroundStyle(Color.all1FitCyan)
                    Text(prefs.goal.executionNote)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.all1FitBlue.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))

                ForEach(Array(generatedPlan.enumerated()), id: \.offset) { index, routine in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Día \(index + 1)")
                                .font(.system(.caption, design: .rounded, weight: .black))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(
                                    LinearGradient(colors: [.all1FitBlue, .all1FitCyan], startPoint: .leading, endPoint: .trailing),
                                    in: Capsule()
                                )
                            Text(routine.name)
                                .font(.system(.headline, design: .rounded, weight: .bold))
                            Spacer()
                        }

                        VStack(spacing: 6) {
                            ForEach(routine.exercises) { exercise in
                                HStack {
                                    Text(exercise.exerciseName)
                                        .font(.subheadline)
                                        .lineLimit(1)
                                    Spacer()
                                    Text("\(exercise.sets)×\(exercise.reps)")
                                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                                        .foregroundStyle(Color.all1FitCyan)
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
    }

    // MARK: - Botón inferior

    private var bottomButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            if step < totalSteps - 1 {
                withAnimation { step += 1 }
            } else {
                createPlan()
            }
        } label: {
            HStack {
                if isSaving {
                    ProgressView().tint(.white)
                } else {
                    Text(step < totalSteps - 1 ? "Siguiente" : "Crear plan (\(generatedPlan.count) rutinas)")
                        .font(.headline)
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(
                LinearGradient(colors: [.all1FitBlue, .all1FitCyan], startPoint: .leading, endPoint: .trailing),
                in: RoundedRectangle(cornerRadius: 14)
            )
            .shadow(color: .all1FitBlue.opacity(0.3), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
        .disabled(isSaving)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    // MARK: - Componentes

    private func questionPage<Content: View>(title: String, subtitle: String, @ViewBuilder options: () -> Content) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack(spacing: 6) {
                    Text(title)
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .multilineTextAlignment(.center)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 16)

                options()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
    }

    private func optionCard(label: String, detail: String, icon: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { action() }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(isSelected ? .white : Color.all1FitBlue)
                    .frame(width: 42, height: 42)
                    .background(
                        isSelected
                            ? AnyShapeStyle(LinearGradient(colors: [.all1FitBlue, .all1FitCyan], startPoint: .topLeading, endPoint: .bottomTrailing))
                            : AnyShapeStyle(Color.all1FitBlue.opacity(0.12)),
                        in: RoundedRectangle(cornerRadius: 11)
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text(label)
                        .font(.system(.body, design: .rounded, weight: .bold))
                        .foregroundStyle(.primary)
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.all1FitBlue : Color.secondary.opacity(0.4))
            }
            .padding()
            .background {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(isSelected ? Color.all1FitBlue : .white.opacity(0.07), lineWidth: isSelected ? 1.5 : 1)
                    }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Descripciones

    private func schemeDescription(_ goal: GymGoal) -> String {
        let compound = goal.compoundScheme
        let isolation = goal.isolationScheme
        var text = "Básicos \(compound.sets)×\(compound.reps) · aislamiento \(isolation.sets)×\(isolation.reps)"
        if goal.usesSupersets { text += " · superseries" }
        return text
    }

    private func splitDescription(_ days: Int) -> String {
        switch days {
        case 2: return "Full Body ×2"
        case 3: return prefs.experience == .principiante ? "Full Body ×3" : "Push · Pull · Legs"
        case 4: return "Torso / Pierna ×2"
        default: return "Push Pull Legs + Torso + Pierna"
        }
    }

    private func equipmentDescription(_ access: GymEquipmentAccess) -> String {
        switch access {
        case .gimnasioCompleto: return "Barras, máquinas, poleas y mancuernas"
        case .mancuernas:       return "Mancuernas, kettlebell y peso corporal"
        case .pesoCorporal:     return "Entrena en cualquier parte sin material"
        }
    }

    // MARK: - Crear

    private func createPlan() {
        isSaving = true
        let plan = generatedPlan
        Task {
            do {
                for routine in plan {
                    try await routineService.createRoutine(routine)
                }
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                isSaving = false
            }
        }
    }
}

#Preview {
    GymPlanWizardView(routineService: GymRoutineService())
        .preferredColorScheme(.dark)
}
