import SwiftUI

// MARK: - Constructor de Rutinas
/// Crear o editar rutina: nombre, ejercicios (desde biblioteca), series/reps/descanso y orden.
struct RoutineBuilderView: View {
    @ObservedObject var routineService: GymRoutineService
    let routine: GymRoutine?

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var notes: String
    @State private var folder: String
    @State private var exercises: [RoutineExercise]
    @State private var showingLibrary = false
    @State private var editingExercise: RoutineExercise?
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(routineService: GymRoutineService, routine: GymRoutine?) {
        self.routineService = routineService
        self.routine = routine
        _name = State(initialValue: routine?.name ?? "")
        _notes = State(initialValue: routine?.notes ?? "")
        _folder = State(initialValue: routine?.folder ?? "")
        _exercises = State(initialValue: routine?.exercises ?? [])
    }

    // MARK: - Superseries

    private func toggleSuperset(at index: Int) {
        guard index > 0 else { return }
        if exercises[index].supersetGroup != nil {
            exercises[index].supersetGroup = nil
        } else {
            // Une con el ejercicio anterior: usa su grupo o crea uno nuevo
            let group = exercises[index - 1].supersetGroup ?? ((exercises.compactMap(\.supersetGroup).max() ?? 0) + 1)
            exercises[index - 1].supersetGroup = group
            exercises[index].supersetGroup = group
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private var isEditing: Bool { routine != nil }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && !exercises.isEmpty && !isSaving
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Nombre") {
                    TextField("Ej: Push, Pierna, Full Body...", text: $name)
                        .font(.system(.body, design: .rounded, weight: .semibold))
                }

                Section("Programa (opcional)") {
                    TextField("Ej: Push Pull Legs", text: $folder)
                        .autocorrectionDisabled()
                }

                Section("Notas (opcional)") {
                    TextField("Notas de la rutina", text: $notes, axis: .vertical)
                        .lineLimit(1...3)
                }

                Section {
                    ForEach(Array(exercises.enumerated()), id: \.element.id) { index, exercise in
                        Button {
                            editingExercise = exercise
                        } label: {
                            exerciseRow(exercise)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            if index > 0 {
                                Button {
                                    toggleSuperset(at: index)
                                } label: {
                                    Label(
                                        exercise.supersetGroup != nil ? "Quitar de superserie" : "Superserie con anterior",
                                        systemImage: exercise.supersetGroup != nil ? "link.badge.plus" : "link"
                                    )
                                }
                            }
                            Button(role: .destructive) {
                                exercises.removeAll { $0.id == exercise.id }
                            } label: {
                                Label("Eliminar", systemImage: "trash")
                            }
                        }
                    }
                    .onDelete { indexSet in
                        exercises.remove(atOffsets: indexSet)
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                    .onMove { source, destination in
                        exercises.move(fromOffsets: source, toOffset: destination)
                    }

                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        showingLibrary = true
                    } label: {
                        Label("Añadir ejercicio", systemImage: "plus.circle.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.all1FitBlue)
                    }
                } header: {
                    HStack {
                        Text("Ejercicios")
                        Spacer()
                        if !exercises.isEmpty {
                            Text("\(exercises.count)")
                                .foregroundStyle(Color.all1FitBlue)
                        }
                    }
                } footer: {
                    if !exercises.isEmpty {
                        Text("Toca un ejercicio para ajustar series, reps y descanso. Mantén pulsado para superseries o reordenar arrastrando.")
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(isEditing ? "Editar Rutina" : "Nueva Rutina")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        save()
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Guardar").bold()
                        }
                    }
                    .disabled(!canSave)
                }
            }
            .sheet(isPresented: $showingLibrary) {
                NavigationStack {
                    ExerciseLibraryView(onSelect: { exercise in
                        exercises.append(RoutineExercise(exerciseName: exercise.name))
                    })
                }
            }
            .sheet(item: $editingExercise) { exercise in
                SetConfigSheet(exercise: exercise) { updated in
                    if let index = exercises.firstIndex(where: { $0.id == updated.id }) {
                        exercises[index] = updated
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

    // MARK: - Fila

    private func exerciseRow(_ exercise: RoutineExercise) -> some View {
        HStack(spacing: 12) {
            let muscle = exercise.catalogExercise?.primaryMuscle ?? .none
            Image(systemName: exercise.catalogExercise?.equipment.icon ?? "dumbbell.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(muscle.color)
                .frame(width: 34, height: 34)
                .background(muscle.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 9))

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(exercise.exerciseName)
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    if let group = exercise.supersetGroup {
                        Text("SS\(group)")
                            .font(.system(size: 8, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.all1FitPurple, in: Capsule())
                    }
                }
                Text("\(exercise.sets)×\(exercise.reps) · \(exercise.restSeconds)s descanso")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "slider.horizontal.3")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Save

    private func save() {
        isSaving = true
        Task {
            do {
                let trimmedName = name.trimmingCharacters(in: .whitespaces)
                let trimmedNotes = notes.trimmingCharacters(in: .whitespaces)
                let trimmedFolder = folder.trimmingCharacters(in: .whitespaces)
                if var existing = routine {
                    existing.name = trimmedName
                    existing.notes = trimmedNotes.isEmpty ? nil : trimmedNotes
                    existing.folder = trimmedFolder.isEmpty ? nil : trimmedFolder
                    existing.exercises = exercises
                    try await routineService.updateRoutine(existing)
                } else {
                    let newRoutine = GymRoutine(
                        name: trimmedName,
                        notes: trimmedNotes.isEmpty ? nil : trimmedNotes,
                        folder: trimmedFolder.isEmpty ? nil : trimmedFolder,
                        exercises: exercises
                    )
                    try await routineService.createRoutine(newRoutine)
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

// MARK: - Configuración de series/reps/descanso
struct SetConfigSheet: View {
    let exercise: RoutineExercise
    let onSave: (RoutineExercise) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var sets: Int
    @State private var reps: Int
    @State private var restSeconds: Int

    private let restPresets = [30, 60, 90, 120, 180]

    init(exercise: RoutineExercise, onSave: @escaping (RoutineExercise) -> Void) {
        self.exercise = exercise
        self.onSave = onSave
        _sets = State(initialValue: exercise.sets)
        _reps = State(initialValue: exercise.reps)
        _restSeconds = State(initialValue: exercise.restSeconds)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    stepperCard(title: "Series", value: $sets, range: 1...10)
                    stepperCard(title: "Reps", value: $reps, range: 1...50)
                    restCard
                }
                .padding(20)
            }
            .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
            .navigationTitle(exercise.exerciseName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Hecho") {
                        var updated = exercise
                        updated.sets = sets
                        updated.reps = reps
                        updated.restSeconds = restSeconds
                        onSave(updated)
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                        dismiss()
                    }
                    .bold()
                }
            }
        }
        .presentationDetents([.fraction(0.7), .large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(24)
    }

    // MARK: - Stepper visual (según design system)

    private func stepperCard(title: String, value: Binding<Int>, range: ClosedRange<Int>) -> some View {
        VStack(spacing: 10) {
            Text(title)
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 24) {
                Button {
                    if value.wrappedValue > range.lowerBound {
                        value.wrappedValue -= 1
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 38))
                        .foregroundStyle(Color.all1FitBlue)
                }
                .buttonStyle(.plain)

                Text("\(value.wrappedValue)")
                    .font(.system(size: 52, weight: .black, design: .rounded))
                    .foregroundStyle(Color.all1FitBlue)
                    .frame(minWidth: 90)
                    .contentTransition(.numericText())

                Button {
                    if value.wrappedValue < range.upperBound {
                        value.wrappedValue += 1
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 38))
                        .foregroundStyle(Color.all1FitBlue)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var restCard: some View {
        VStack(spacing: 12) {
            Text("Descanso entre series")
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                ForEach(restPresets, id: \.self) { preset in
                    Button {
                        restSeconds = preset
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        Text(preset >= 60 ? "\(preset / 60)m\(preset % 60 == 0 ? "" : " \(preset % 60)s")" : "\(preset)s")
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                            .foregroundStyle(restSeconds == preset ? .white : .primary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(restSeconds == preset ? AnyShapeStyle(Color.all1FitBlue) : AnyShapeStyle(Color(uiColor: .tertiarySystemGroupedBackground)))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    RoutineBuilderView(routineService: GymRoutineService(), routine: GymRoutine.sample)
}
