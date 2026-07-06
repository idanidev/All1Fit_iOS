import SwiftUI

// MARK: - Formulario de Ejercicio Personalizado
struct CustomExerciseFormView: View {
    @ObservedObject var customService: CustomExerciseService
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var primaryMuscle: BodyPart = .chest
    @State private var secondaryMuscles: Set<BodyPart> = []
    @State private var equipment: GymEquipment = .machine
    @State private var isSaving = false
    @State private var errorMessage: String?

    private var muscles: [BodyPart] {
        BodyPart.allCases.filter { $0 != .none }
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespaces)
    }

    private var nameTaken: Bool {
        customService.allExercises.contains { $0.name.caseInsensitiveCompare(trimmedName) == .orderedSame }
    }

    private var canSave: Bool {
        !trimmedName.isEmpty && !nameTaken && !isSaving
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Nombre") {
                    TextField("Ej: Press banca agarre cerrado", text: $name)
                        .font(.system(.body, design: .rounded, weight: .semibold))
                    if nameTaken {
                        Label("Ya existe un ejercicio con ese nombre", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(Color.all1FitWarning)
                    }
                }

                Section("Músculo principal") {
                    Picker("Músculo", selection: $primaryMuscle) {
                        ForEach(muscles, id: \.self) { muscle in
                            Text(muscle.rawValue).tag(muscle)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section("Músculos secundarios") {
                    ForEach(muscles.filter { $0 != primaryMuscle }, id: \.self) { muscle in
                        Button {
                            if secondaryMuscles.contains(muscle) {
                                secondaryMuscles.remove(muscle)
                            } else {
                                secondaryMuscles.insert(muscle)
                            }
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        } label: {
                            HStack {
                                Text(muscle.rawValue)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if secondaryMuscles.contains(muscle) {
                                    Image(systemName: "checkmark")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(Color.all1FitBlue)
                                }
                            }
                        }
                    }
                }

                Section("Equipamiento") {
                    Picker("Equipamiento", selection: $equipment) {
                        ForEach(GymEquipment.allCases) { eq in
                            Label(eq.rawValue, systemImage: eq.icon).tag(eq)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Nuevo Ejercicio")
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

    private func save() {
        isSaving = true
        let exercise = GymExercise(
            name: trimmedName,
            primaryMuscle: primaryMuscle,
            secondaryMuscles: Array(secondaryMuscles),
            equipment: equipment,
            instructions: [],
            isCustom: true
        )
        Task {
            do {
                try await customService.createExercise(exercise)
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
    CustomExerciseFormView(customService: CustomExerciseService())
        .preferredColorScheme(.dark)
}
