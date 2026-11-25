
import SwiftUI
import FirebaseAuth

// MARK: - Workouts View
struct WorkoutsView: View {
    @StateObject private var workoutService = WorkoutService()
    @EnvironmentObject var userWorkoutService: UserWorkoutService
    @State private var selectedCategory: WorkoutCategory = .crossfit
    @State private var searchText = ""
    @State private var showingAddWorkout = false
    @State private var workoutToCustomize: Workout?
    @State private var userWorkoutToEdit: UserWorkout?
    @State private var workoutToDelete: UserWorkout?
    @State private var workoutToHide: Workout?
    @State private var selectedWorkout: Workout?
    @State private var errorMessage: String?
    @AppStorage("hiddenWorkoutIds") private var hiddenWorkoutIdsData: Data = Data()

    // Hidden workout IDs
    private var hiddenWorkoutIds: Set<String> {
        (try? JSONDecoder().decode(Set<String>.self, from: hiddenWorkoutIdsData)) ?? []
    }

    private func hideWorkout(_ id: String) {
        var hidden = hiddenWorkoutIds
        hidden.insert(id)
        hiddenWorkoutIdsData = (try? JSONEncoder().encode(hidden)) ?? Data()
    }

    // Merge hardcoded + user workouts (excluding hidden)
    private var allWorkouts: [Workout] {
        let hardcoded = Workout.workouts(for: selectedCategory)
            .filter { !hiddenWorkoutIds.contains($0.id) }
        let userConverted = userWorkoutService.userWorkouts
            .filter { $0.workoutCategory == selectedCategory }
            .map { $0.toWorkout() }
        return hardcoded + userConverted
    }

    private var filteredWorkouts: [Workout] {
        if searchText.isEmpty { return allWorkouts }
        return allWorkouts.filter { workout in
            workout.name.localizedCaseInsensitiveContains(searchText) ||
            workout.description.localizedCaseInsensitiveContains(searchText) ||
            workout.exercises.contains { $0.name.localizedCaseInsensitiveContains(searchText) } ||
            workout.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
        }
    }

    private var categoryGradient: [Color] {
        switch selectedCategory {
        case .crossfit:    return [.red, .orange]
        case .running:     return [.orange, .yellow]
        case .competition: return [.purple, .pink]
        }
    }

    var body: some View {
        // Sin NavigationStack propio: se presenta pushed desde TrainingHubView
        Group {
            List {
                // Category selector
                Section {
                    categorySelector
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

                // Search results header
                if !searchText.isEmpty {
                    Section {
                        VStack(spacing: 4) {
                            Text("RESULTADOS")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text("\(filteredWorkouts.count)")
                                    .font(.system(size: 32, weight: .bold, design: .rounded))
                                    .foregroundStyle(
                                        LinearGradient(colors: categoryGradient, startPoint: .topLeading, endPoint: .bottomTrailing)
                                    )
                                Text(filteredWorkouts.count == 1 ? "entrenamiento" : "entrenamientos")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(.white.opacity(0.07), lineWidth: 1)
                        )
                        .padding(.horizontal)
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }

                // Cacos (solo en Running)
                if selectedCategory == .running && searchText.isEmpty {
                    Section {
                        NavigationLink { CacosView() } label: { CacosCard() }
                            .buttonStyle(.plain)
                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }
                }

                // Workouts
                Section {
                    ForEach(filteredWorkouts) { workout in
                        WorkoutListRow(
                            workout: workout,
                            workoutToCustomize: $workoutToCustomize,
                            userWorkoutToEdit: $userWorkoutToEdit,
                            workoutToDelete: $workoutToDelete,
                            workoutToHide: $workoutToHide,
                            userWorkoutService: userWorkoutService,
                            workoutService: workoutService,
                            onTap: { selectedWorkout = workout }
                        )
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
            .overlay {
                if userWorkoutService.isLoading {
                    VStack(spacing: 8) {
                        ProgressView().scaleEffect(1.2)
                        Text("Cargando...").font(.caption).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.ultraThinMaterial)
                }
            }
            .navigationTitle("Entrenos")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddWorkout = true
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(
                                LinearGradient(colors: categoryGradient, startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                    }
                }
            }
            .sheet(isPresented: $showingAddWorkout) {
                WorkoutFormView(initialCategory: selectedCategory)
                    .environmentObject(userWorkoutService)
            }
            .sheet(item: $workoutToCustomize) { workout in
                WorkoutFormView(basedOnWorkout: workout)
                    .environmentObject(userWorkoutService)
            }
            .sheet(item: $userWorkoutToEdit) { workout in
                WorkoutFormView(workoutToEdit: workout)
                    .environmentObject(userWorkoutService)
            }
            .navigationDestination(item: $selectedWorkout) { workout in
                WorkoutDetailView(workout: workout)
                    .environmentObject(workoutService)
            }
            .searchable(text: $searchText, prompt: "Buscar entrenamiento...")
            .task {
                Track.event("wod_biblioteca_abierto")
                await userWorkoutService.fetchWorkouts()
                await workoutService.fetchAllResults()
            }
            .refreshable {
                await userWorkoutService.fetchWorkouts()
                await workoutService.fetchAllResults(forceRefresh: true)
            }
            .all1FitConfirmation(Binding(
                get: { workoutToDelete.map(deleteConfirmation) },
                set: { if $0 == nil { workoutToDelete = nil } }
            ))
            .alert("Error", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
            .all1FitConfirmation(Binding(
                get: { workoutToHide.map(hideConfirmation) },
                set: { if $0 == nil { workoutToHide = nil } }
            ))
        }
        .environmentObject(workoutService)
        .environmentObject(userWorkoutService)
    }

    // MARK: - Confirmaciones

    private func deleteConfirmation(for workout: UserWorkout) -> All1FitConfirmation {
        All1FitConfirmation(
            title: "¿Eliminar entrenamiento?",
            message: "\"\(workout.name)\" se eliminará. Los resultados guardados no se eliminarán.",
            icon: "trash.fill",
            confirmTitle: "Eliminar"
        ) {
            Task {
                do {
                    try await userWorkoutService.deleteWorkout(workout)
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                } catch {
                    errorMessage = error.localizedDescription
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                }
            }
        }
    }

    private func hideConfirmation(for workout: Workout) -> All1FitConfirmation {
        All1FitConfirmation(
            title: "¿Ocultar entrenamiento?",
            message: "\"\(workout.name)\" dejará de aparecer en la lista. Puedes restaurar los ocultos desde Ajustes.",
            icon: "eye.slash.fill",
            tint: .all1FitWarning,
            confirmTitle: "Ocultar"
        ) {
            hideWorkout(workout.id)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }

    // MARK: - Category Selector
    private var categorySelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(WorkoutCategory.allCases) { category in
                    CategoryPill(category: category, isSelected: selectedCategory == category) {
                        withAnimation(.spring(duration: 0.3)) { selectedCategory = category }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
        }
    }
}

// MARK: - Workout List Row
struct WorkoutListRow: View {
    let workout: Workout
    @Binding var workoutToCustomize: Workout?
    @Binding var userWorkoutToEdit: UserWorkout?
    @Binding var workoutToDelete: UserWorkout?
    @Binding var workoutToHide: Workout?
    @ObservedObject var userWorkoutService: UserWorkoutService
    @ObservedObject var workoutService: WorkoutService
    let onTap: () -> Void

    var body: some View {
        let userWorkout = userWorkoutService.userWorkouts.first(where: { $0.id == workout.id })
        Button(action: onTap) {
            WorkoutCard(
                workout: workout,
                recordCount: workoutService.results[workout.id]?.count ?? 0,
                lastResult: workoutService.results[workout.id]?.first
            )
        }
        .buttonStyle(.plain)
        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            if let userWorkout = userWorkout {
                Button(role: .destructive) {
                    workoutToDelete = userWorkout
                    UINotificationFeedbackGenerator().notificationOccurred(.warning)
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "trash.fill").font(.system(size: 20, weight: .semibold))
                        Text("Eliminar").font(.system(size: 11, weight: .medium))
                    }
                }
                .tint(.red)
            } else {
                Button(role: .destructive) {
                    workoutToHide = workout
                    UINotificationFeedbackGenerator().notificationOccurred(.warning)
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "eye.slash.fill").font(.system(size: 20, weight: .semibold))
                        Text("Ocultar").font(.system(size: 11, weight: .medium))
                    }
                }
                .tint(.orange)
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            if let userWorkout = userWorkout {
                Button {
                    userWorkoutToEdit = userWorkout
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "pencil.circle.fill").font(.system(size: 20, weight: .semibold))
                        Text("Editar").font(.system(size: 11, weight: .medium))
                    }
                }
                .tint(.blue)
            } else {
                Button {
                    workoutToCustomize = workout
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "slider.horizontal.3").font(.system(size: 20, weight: .semibold))
                        Text("Personalizar").font(.system(size: 11, weight: .medium))
                    }
                }
                .tint(.purple)
            }
        }
    }
}

// MARK: - Category Pill
struct CategoryPill: View {
    let category: WorkoutCategory
    let isSelected: Bool
    let action: () -> Void

    private var gradient: [Color] {
        switch category {
        case .crossfit:    return [.red, .orange]
        case .running:     return [.orange, .yellow]
        case .competition: return [.purple, .pink]
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: category.icon)
                Text(category.rawValue)
            }
            .font(.system(.subheadline, design: .rounded, weight: .semibold))
            .foregroundStyle(isSelected ? .white : .primary)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background {
                if isSelected {
                    Capsule()
                        .fill(LinearGradient(colors: gradient, startPoint: .leading, endPoint: .trailing))
                } else {
                    Capsule()
                        .fill(Color(uiColor: .secondarySystemGroupedBackground))
                        .overlay(Capsule().strokeBorder(.white.opacity(0.1), lineWidth: 1))
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Workout Card
struct WorkoutCard: View {
    let workout: Workout
    let recordCount: Int
    let lastResult: WorkoutResult?

    private var gradient: [Color] {
        switch workout.category {
        case .crossfit:    return [.red, .orange]
        case .running:     return [.orange, .yellow]
        case .competition: return [.purple, .pink]
        }
    }

    private var accentColor: Color {
        switch workout.category {
        case .crossfit:    return .red
        case .running:     return .orange
        case .competition: return .purple
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            // Left accent bar
            RoundedRectangle(cornerRadius: 3)
                .fill(LinearGradient(colors: gradient, startPoint: .top, endPoint: .bottom))
                .frame(width: 4)
                .padding(.vertical, 10)
                .padding(.trailing, 12)

            HStack(spacing: 14) {
                // Icon
                Image(systemName: workout.category.icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .frame(width: 44, height: 44)
                    .background(accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(accentColor.opacity(0.2), lineWidth: 1)
                    )

                // Info
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(workout.name)
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                            .lineLimit(1)
                            .foregroundStyle(.primary)

                        if recordCount > 0 {
                            Text("\(recordCount)")
                                .font(.caption2.bold())
                                .foregroundStyle(.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(.green, in: Capsule())
                        }
                    }

                    Text(workout.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)

                    HStack(spacing: 8) {
                        if workout.isForTime {
                            Label("For Time", systemImage: "timer")
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(accentColor)
                        } else {
                            Label("AMRAP", systemImage: "repeat")
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.blue)
                        }

                        if let timeCap = workout.timeCapMinutes {
                            Label("\(timeCap)'", systemImage: "clock")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        Label("\(workout.exercises.count) ej.", systemImage: "list.bullet")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 4)

                if let lastResult = lastResult {
                    VStack(alignment: .trailing, spacing: 2) {
                        if workout.isForTime {
                            Text(lastResult.formattedTime)
                                .font(.system(.subheadline, design: .rounded, weight: .bold))
                                .foregroundStyle(
                                    LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing)
                                )
                        } else if let rounds = lastResult.rounds {
                            Text("\(rounds) rds")
                                .font(.system(.subheadline, design: .rounded, weight: .bold))
                                .foregroundStyle(
                                    LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing)
                                )
                        }
                        Text("PR")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                .overlay {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(accentColor.opacity(0.05))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(.white.opacity(0.07), lineWidth: 1)
                }
        }
    }
}

// MARK: - Cacos Card
struct CacosCard: View {
    var body: some View {
        HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 3)
                .fill(LinearGradient(colors: [.orange, .blue], startPoint: .top, endPoint: .bottom))
                .frame(width: 4)
                .padding(.vertical, 10)
                .padding(.trailing, 12)

            HStack(spacing: 14) {
                HStack(spacing: -8) {
                    Image(systemName: "figure.run")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(LinearGradient(colors: [.orange, .yellow], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 44, height: 44)
                        .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.orange.opacity(0.2), lineWidth: 1))
                    Image(systemName: "figure.walk")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(LinearGradient(colors: [.blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 44, height: 44)
                        .background(.blue.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.blue.opacity(0.2), lineWidth: 1))
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text("Cacos")
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        Text("NUEVO")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(.orange, in: Capsule())
                    }
                    Text("Intervalos caminar / correr configurables")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Label("Personalizable", systemImage: "slider.horizontal.3")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.orange)
                }

                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                .overlay {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.orange.opacity(0.05))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(.white.opacity(0.07), lineWidth: 1)
                }
        }
    }
}

#Preview {
    WorkoutsView()
}
