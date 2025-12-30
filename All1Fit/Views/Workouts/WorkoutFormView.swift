import SwiftUI

// MARK: - Workout Form View
struct WorkoutFormView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var userWorkoutService: UserWorkoutService
    
    // Edit mode: pass existing workout
    var workoutToEdit: UserWorkout?
    
    // For duplicating/customizing a hardcoded workout
    var basedOnWorkout: Workout?

    // Initial category when creating new (optional)
    var initialCategory: WorkoutCategory?
    
    @State private var name = ""
    @State private var description = ""
    @State private var category: WorkoutCategory = .crossfit
    @State private var isForTime = true
    @State private var timeCapMinutes: Int?
    @State private var exercises: [UserWorkoutExercise] = []
    @State private var isSaving = false
    @State private var showSuccess = false
    @State private var showAddExercise = false
    
    // For adding exercise
    @State private var newExerciseName = ""
    @State private var newExerciseReps = ""
    @State private var newExerciseNotes = ""
    
    private var isEditing: Bool {
        workoutToEdit != nil
    }
    
    private var isDuplicating: Bool {
        basedOnWorkout != nil && workoutToEdit == nil
    }
    
    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && !exercises.isEmpty
    }
    
    private var navigationTitle: String {
        if isEditing {
            return "Editar Entreno"
        } else if isDuplicating {
            return "Personalizar Entreno"
        } else {
            return "Nuevo Entreno"
        }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // Basic Info
                Section("Información") {
                    TextField("Nombre del entreno", text: $name)
                    
                    TextField("Descripción", text: $description, axis: .vertical)
                        .lineLimit(2...4)
                    
                    Picker("Categoría", selection: $category) {
                        ForEach(WorkoutCategory.allCases, id: \.self) { cat in
                            Label(cat.rawValue, systemImage: cat.icon).tag(cat)
                        }
                    }
                }
                
                // Type
                Section("Tipo") {
                    Picker("Modalidad", selection: $isForTime) {
                        Text("For Time").tag(true)
                        Text("AMRAP").tag(false)
                    }
                    .pickerStyle(.segmented)
                    
                    if !isForTime {
                        Stepper(value: Binding(
                            get: { timeCapMinutes ?? 20 },
                            set: { timeCapMinutes = $0 }
                        ), in: 1...60) {
                            Text("Time Cap: \(timeCapMinutes ?? 20) min")
                        }
                    }
                }
                
                // Exercises
                Section {
                    ForEach(exercises.indices, id: \.self) { index in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(exercises[index].name)
                                    .font(.headline)
                                Text(exercises[index].reps)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                    }
                    .onDelete { indexSet in
                        exercises.remove(atOffsets: indexSet)
                    }
                    .onMove { from, to in
                        exercises.move(fromOffsets: from, toOffset: to)
                    }
                    
                    Button {
                        showAddExercise = true
                    } label: {
                        Label("Añadir ejercicio", systemImage: "plus.circle.fill")
                    }
                } header: {
                    Text("Ejercicios")
                } footer: {
                    if exercises.isEmpty {
                        Text("Añade al menos un ejercicio")
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        saveWorkout()
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Guardar").fontWeight(.semibold)
                        }
                    }
                    .disabled(!isValid || isSaving)
                }
                

            }
            .onAppear {
                if let workout = workoutToEdit {
                    // Editing existing user workout
                    name = workout.name
                    description = workout.description
                    category = workout.workoutCategory
                    isForTime = workout.isForTime
                    timeCapMinutes = workout.timeCapMinutes
                    exercises = workout.exercises
                } else if let workout = basedOnWorkout {
                    // Duplicating/customizing hardcoded workout
                    name = workout.name + " (Mi versión)"
                    description = workout.description
                    category = workout.category
                    isForTime = workout.isForTime
                    timeCapMinutes = workout.timeCapMinutes
                    // Convert WorkoutExercise to UserWorkoutExercise
                        UserWorkoutExercise(name: ex.name, reps: ex.reps, notes: ex.notes)
                    }
                } else if let initialCategory = initialCategory {
                    category = initialCategory
                }
            }
            .sheet(isPresented: $showAddExercise) {
                addExerciseSheet
            }
            .overlay {
                if showSuccess {
                    successOverlay
                }
            }
        }
    }
    
    // MARK: - Add Exercise Sheet
    private var addExerciseSheet: some View {
        NavigationStack {
            Form {
                TextField("Nombre del ejercicio", text: $newExerciseName)
                TextField("Repeticiones (ej: 21-15-9, 100, 400m)", text: $newExerciseReps)
                TextField("Notas (opcional)", text: $newExerciseNotes)
            }
            .navigationTitle("Añadir Ejercicio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        clearExerciseFields()
                        showAddExercise = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Añadir") {
                        let exercise = UserWorkoutExercise(
                            name: newExerciseName,
                            reps: newExerciseReps,
                            notes: newExerciseNotes.isEmpty ? nil : newExerciseNotes
                        )
                        exercises.append(exercise)
                        clearExerciseFields()
                        showAddExercise = false
                    }
                    .disabled(newExerciseName.isEmpty || newExerciseReps.isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
    
    // MARK: - Success Overlay
    private var successOverlay: some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.green)
                Text("¡Guardado!")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
            }
            .padding(40)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 24))
        }
    }
    
    // MARK: - Helpers
    private func clearExerciseFields() {
        newExerciseName = ""
        newExerciseReps = ""
        newExerciseNotes = ""
    }
    
    private func saveWorkout() {
        isSaving = true
        
        let workout = UserWorkout(
            id: workoutToEdit?.id,
            userId: nil, // Will be set in service
            name: name,
            description: description,
            category: category.rawValue.lowercased(),
            exercises: exercises,
            timeCapMinutes: isForTime ? nil : timeCapMinutes,
            isForTime: isForTime,
            createdAt: nil // Will be set in service
        )
        
        Task {
            do {
                try await userWorkoutService.saveWorkout(workout)
                showSuccess = true
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                try? await Task.sleep(nanoseconds: 800_000_000)
                dismiss()
            } catch {
                isSaving = false
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            }
        }
    }
}

#Preview {
    WorkoutFormView()
        .environmentObject(UserWorkoutService())
}
