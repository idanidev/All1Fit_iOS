import SwiftUI

// MARK: - Biblioteca de Ejercicios
/// Catálogo completo (base + personalizados) con búsqueda, filtros por músculo
/// y equipamiento, favoritos y creación de ejercicios propios.
/// Si `onSelect` != nil actúa como selector (para rutinas y sesión activa).
struct ExerciseLibraryView: View {
    var sessionService: GymSessionService?
    var onSelect: ((GymExercise) -> Void)?

    @StateObject private var customService = CustomExerciseService()
    @State private var searchText = ""
    @State private var selectedMuscle: BodyPart?
    @State private var selectedEquipment: GymEquipment?
    @State private var favoritesOnly = false
    @State private var favorites: Set<String> = ExerciseFavorites.all()
    @State private var showingCustomForm = false
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss

    private var isPicker: Bool { onSelect != nil }

    private var filteredExercises: [GymExercise] {
        customService.allExercises.filter { exercise in
            exercise.matches(searchText)
            && (selectedMuscle == nil || exercise.primaryMuscle == selectedMuscle)
            && (selectedEquipment == nil || exercise.equipment == selectedEquipment)
            && (!favoritesOnly || favorites.contains(exercise.name))
        }
    }

    private var muscles: [BodyPart] {
        BodyPart.allCases.filter { $0 != .none }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                muscleFilterRow
                equipmentFilterRow
                exerciseList
            }
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .navigationTitle(isPicker ? "Elegir ejercicio" : "Ejercicios")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Buscar ejercicio")
        .toolbar {
            if isPicker {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    showingCustomForm = true
                } label: {
                    Image(systemName: "plus")
                        .font(.title3)
                }
                .accessibilityLabel("Crear ejercicio propio")
            }
        }
        .sheet(isPresented: $showingCustomForm) {
            CustomExerciseFormView(customService: customService)
        }
        .alert("Error", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .task { await customService.fetchCustomExercises() }
    }

    // MARK: - Filtros

    private var muscleFilterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterChip(label: "Favoritos", isSelected: favoritesOnly, color: .yellow, icon: "star.fill") {
                    favoritesOnly.toggle()
                }
                filterChip(label: "Todos", isSelected: selectedMuscle == nil && !favoritesOnly, color: .all1FitBlue) {
                    selectedMuscle = nil
                    favoritesOnly = false
                }
                ForEach(muscles, id: \.self) { muscle in
                    filterChip(label: muscle.rawValue, isSelected: selectedMuscle == muscle, color: muscle.color) {
                        selectedMuscle = selectedMuscle == muscle ? nil : muscle
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private var equipmentFilterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(GymEquipment.allCases) { equipment in
                    filterChip(
                        label: equipment.rawValue,
                        isSelected: selectedEquipment == equipment,
                        color: .all1FitCyan,
                        icon: equipment.icon
                    ) {
                        selectedEquipment = selectedEquipment == equipment ? nil : equipment
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private func filterChip(label: String, isSelected: Bool, color: Color, icon: String? = nil, action: @escaping () -> Void) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { action() }
        } label: {
            HStack(spacing: 5) {
                if let icon {
                    Image(systemName: icon)
                        .font(.caption2.weight(.semibold))
                }
                Text(label)
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
            }
            .foregroundStyle(isSelected ? .white : .primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(isSelected ? AnyShapeStyle(color) : AnyShapeStyle(Color(uiColor: .secondarySystemGroupedBackground)))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Lista

    private var exerciseList: some View {
        LazyVStack(spacing: 10) {
            if filteredExercises.isEmpty {
                emptyState
            } else {
                ForEach(filteredExercises) { exercise in
                    Group {
                        if let onSelect {
                            Button {
                                UINotificationFeedbackGenerator().notificationOccurred(.success)
                                onSelect(exercise)
                                dismiss()
                            } label: {
                                ExerciseRowCard(exercise: exercise, showsPlus: true, isFavorite: favorites.contains(exercise.name))
                            }
                            .buttonStyle(.plain)
                        } else {
                            NavigationLink {
                                ExerciseDetailView(exercise: exercise, sessionService: sessionService)
                            } label: {
                                ExerciseRowCard(exercise: exercise, showsPlus: false, isFavorite: favorites.contains(exercise.name))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .contextMenu {
                        Button {
                            ExerciseFavorites.toggle(exercise.name)
                            favorites = ExerciseFavorites.all()
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        } label: {
                            Label(favorites.contains(exercise.name) ? "Quitar de favoritos" : "Añadir a favoritos",
                                  systemImage: favorites.contains(exercise.name) ? "star.slash" : "star")
                        }
                        if exercise.isCustom {
                            Button(role: .destructive) {
                                Task {
                                    do {
                                        try await customService.deleteExercise(named: exercise.name)
                                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                                    } catch {
                                        errorMessage = error.localizedDescription
                                        UINotificationFeedbackGenerator().notificationOccurred(.error)
                                    }
                                }
                            } label: {
                                Label("Eliminar ejercicio", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 20)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text("Sin resultados")
                .font(.headline)
            Text("Prueba con otro nombre o quita filtros")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 48)
    }
}

// MARK: - Fila de ejercicio
struct ExerciseRowCard: View {
    let exercise: GymExercise
    var showsPlus: Bool = false
    var isFavorite: Bool = false

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: exercise.equipment.icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(colors: [exercise.primaryMuscle.color, exercise.primaryMuscle.color.opacity(0.7)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .frame(width: 42, height: 42)
                .background(exercise.primaryMuscle.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 11))

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Text(exercise.name)
                        .font(.system(.body, design: .rounded, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    if exercise.isCustom {
                        Text("PROPIO")
                            .font(.system(size: 8, weight: .black))
                            .foregroundStyle(Color.all1FitCyan)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.all1FitCyan.opacity(0.12), in: Capsule())
                    }
                }
                HStack(spacing: 6) {
                    Text(exercise.primaryMuscle.rawValue)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(exercise.primaryMuscle.color)
                    Text("·")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(exercise.equipment.rawValue)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 4)

            if isFavorite {
                Image(systemName: "star.fill")
                    .font(.caption)
                    .foregroundStyle(.yellow)
                    .accessibilityLabel("Favorito")
            }

            Image(systemName: showsPlus ? "plus.circle.fill" : "chevron.right")
                .font(showsPlus ? .title3 : .caption.weight(.semibold))
                .foregroundStyle(showsPlus ? AnyShapeStyle(Color.all1FitBlue) : AnyShapeStyle(.tertiary))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                .overlay {
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(.white.opacity(0.07), lineWidth: 1)
                }
        }
    }
}

#Preview {
    NavigationStack {
        ExerciseLibraryView()
    }
    .preferredColorScheme(.dark)
}
