
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
    @AppStorage("hiddenWorkoutIds") private var hiddenWorkoutIdsData: Data = Data()
    
    // Hidden workout IDs
    private var hiddenWorkoutIds: Set<String> {
        get {
            (try? JSONDecoder().decode(Set<String>.self, from: hiddenWorkoutIdsData)) ?? []
        }
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
        if searchText.isEmpty {
            return allWorkouts
        }
        return allWorkouts.filter { workout in
            // Search in name, description, and exercises
            workout.name.localizedCaseInsensitiveContains(searchText) ||
            workout.description.localizedCaseInsensitiveContains(searchText) ||
            workout.exercises.contains { exercise in
                exercise.name.localizedCaseInsensitiveContains(searchText)
            } ||
            workout.tags.contains { tag in
                tag.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    // Colores dinámicos según categoría (coincidir con etiquetas)
    private var categoryColors: [Color] {
        switch selectedCategory {
        case .crossfit: return [.red, .red.opacity(0.8)]
        case .running: return [.orange, .orange.opacity(0.8)]
        case .competition: return [.purple, .purple.opacity(0.8)]
        }
    }
    
    private var categoryShadowColor: Color {
        switch selectedCategory {
        case .crossfit: return .red
        case .running: return .orange
        case .competition: return .purple
        }
    }
    
    var body: some View {
        NavigationStack {
            List {
                    // Category selector as header
                    Section {
                        categorySelector
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    
                    // Stats Header
                    if !searchText.isEmpty {
                        Section {
                            VStack(spacing: 4) {
                                Text("RESULTADOS")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .textCase(.uppercase)
                                
                                HStack(alignment: .firstTextBaseline, spacing: 4) {
                                    Text("\(filteredWorkouts.count)")
                                        .font(.system(size: 32, weight: .bold, design: .rounded))
                                        .foregroundStyle(categoryShadowColor)
                                    
                                    Text(filteredWorkouts.count == 1 ? "entrenamiento" : "entrenamientos")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(.ultraThinMaterial)
                            )
                            .padding(.horizontal)
                        }
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
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
                                workoutService: workoutService
                            )
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(Color(uiColor: .systemGroupedBackground))
                .overlay {
                    if userWorkoutService.isLoading {
                        VStack {
                            ProgressView()
                                .scaleEffect(1.2)
                            Text("Cargando...")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(.ultraThinMaterial)
                    }
                }
            .navigationTitle("Entrenamientos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddWorkout = true
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: categoryColors,
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .symbolRenderingMode(.hierarchical)
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
            .searchable(text: $searchText, prompt: "Buscar entrenamiento...")
            .task {
                await userWorkoutService.fetchWorkouts()
                // Fetch results for all workouts to show indicators
                for workout in Workout.all {
                    await workoutService.fetchResults(for: workout.id)
                }
                // Fetch results for user workouts
                for workout in userWorkoutService.userWorkouts {
                    if let id = workout.id {
                        await workoutService.fetchResults(for: id)
                    }
                }
            }
            .refreshable {
                await userWorkoutService.fetchWorkouts()
                for workout in userWorkoutService.userWorkouts {
                     if let id = workout.id {
                         await workoutService.fetchResults(for: id)
                     }
                }
            }
            .confirmationDialog(
                "¿Eliminar entrenamiento?",
                isPresented: Binding(
                    get: { workoutToDelete != nil },
                    set: { if !$0 { workoutToDelete = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Eliminar \(workoutToDelete?.name ?? "")", role: .destructive) {
                    if let workout = workoutToDelete {
                        Task {
                            try? await userWorkoutService.deleteWorkout(workout)
                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                        }
                    }
                }
                Button("Cancelar", role: .cancel) {
                    workoutToDelete = nil
                }
            } message: {
                Text("Los resultados guardados no se eliminarán.")
            }
            .confirmationDialog(
                "¿Ocultar entrenamiento?",
                isPresented: Binding(
                    get: { workoutToHide != nil },
                    set: { if !$0 { workoutToHide = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Ocultar \(workoutToHide?.name ?? "")", role: .destructive) {
                    if let workout = workoutToHide {
                        hideWorkout(workout.id)
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                    }
                    workoutToHide = nil
                }
                Button("Cancelar", role: .cancel) {
                    workoutToHide = nil
                }
            } message: {
                Text("Puedes restaurar los entrenamientos ocultos desde Ajustes.")
            }

        }
        .environmentObject(workoutService)
        .environmentObject(userWorkoutService)
    }
    
    // MARK: - Category Selector
    private var categorySelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(WorkoutCategory.allCases) { category in
                    CategoryPill(
                        category: category,
                        isSelected: selectedCategory == category
                    ) {
                        withAnimation(.spring(duration: 0.3)) {
                            selectedCategory = category
                        }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                }
            }
            .padding(.horizontal, 16)
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

    var body: some View {
        let userWorkout = userWorkoutService.userWorkouts.first(where: { $0.id == workout.id })
        let categoryColors: [Color] = {
            switch workout.category {
            case .running: return [.orange, .yellow]
            case .crossfit: return [.red, .pink]
            case .competition: return [.purple, .blue]
            }
        }()

        NavigationLink {
            WorkoutDetailView(workout: workout)
                .environmentObject(workoutService)
        } label: {
            All1FitProCard(
                gradient: LinearGradient(
                    colors: categoryColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            ) {
                WorkoutCard(
                    workout: workout,
                    recordCount: workoutService.results[workout.id]?.count ?? 0,
                    lastResult: workoutService.results[workout.id]?.first
                )
            }
        }
        .buttonStyle(.plain)
        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            if let userWorkout = userWorkout {
                // User workout: delete from Firebase
                Button(role: .destructive) {
                    workoutToDelete = userWorkout
                    UINotificationFeedbackGenerator().notificationOccurred(.warning)
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "trash.fill")
                            .font(.system(size: 20, weight: .semibold))
                        Text("Eliminar")
                            .font(.system(size: 11, weight: .medium))
                    }
                }
                .tint(.red)
            } else {
                // System workout: hide locally
                Button(role: .destructive) {
                    workoutToHide = workout
                    UINotificationFeedbackGenerator().notificationOccurred(.warning)
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "eye.slash.fill")
                            .font(.system(size: 20, weight: .semibold))
                        Text("Ocultar")
                            .font(.system(size: 11, weight: .medium))
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
                        Image(systemName: "pencil.circle.fill")
                            .font(.system(size: 20, weight: .semibold))
                        Text("Editar")
                            .font(.system(size: 11, weight: .medium))
                    }
                }
                .tint(.blue)
            } else {
                Button {
                    workoutToCustomize = workout
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 20, weight: .semibold))
                        Text("Personalizar")
                            .font(.system(size: 11, weight: .medium))
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
    
    private var categoryColor: Color {
        switch category {
        case .running: return .orange
        case .crossfit: return .red
        case .competition: return .purple
        }
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: category.icon)
                Text(category.rawValue)
            }
            .font(.subheadline.bold())
            .foregroundStyle(isSelected ? .white : .primary)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                isSelected
                ? AnyShapeStyle(categoryColor)
                : AnyShapeStyle(Color(uiColor: .secondarySystemGroupedBackground))
            )
            .clipShape(Capsule())
        }
    }
}

// MARK: - Workout Card
struct WorkoutCard: View {
    let workout: Workout
    let recordCount: Int
    let lastResult: WorkoutResult?
    
    private var categoryColor: Color {
        switch workout.category {
        case .running: return .orange
        case .crossfit: return .red
        case .competition: return .purple
        }
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon with badge
            ZStack(alignment: .topTrailing) {
                ZStack {
                    Circle()
                        .fill(categoryColor.opacity(0.15))
                        .frame(width: 56, height: 56)
                    
                    Image(systemName: workout.category.icon)
                        .font(.title2)
                        .foregroundStyle(categoryColor)
                }
                
                // Record badge
                if recordCount > 0 {
                    Text("\(recordCount)")
                        .font(.caption2.bold())
                        .foregroundStyle(.white)
                        .frame(minWidth: 18, minHeight: 18)
                        .background(Color.green)
                        .clipShape(Circle())
                        .offset(x: 4, y: -4)
                }
            }
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(workout.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    
                    if recordCount > 0 {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }
                
                // Last result display
                if let lastResult = lastResult {
                    HStack(spacing: 4) {
                        Image(systemName: "clock.fill")
                            .font(.caption2)
                        if workout.isForTime {
                            Text(lastResult.formattedTime)
                                .font(.caption.bold())
                        } else if let rounds = lastResult.rounds {
                            Text("\(rounds) rondas")
                                .font(.caption.bold())
                        }
                    }
                    .foregroundStyle(.orange)
                }
                
                Text(workout.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                
                // Tags
                HStack(spacing: 8) {
                    if workout.isForTime {
                        Label("For Time", systemImage: "timer")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    } else {
                        Label("AMRAP", systemImage: "repeat")
                            .font(.caption2)
                            .foregroundStyle(.blue)
                    }
                    
                    if let timeCap = workout.timeCapMinutes {
                        Label("\(timeCap) min", systemImage: "clock")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    
                    if recordCount > 0 {
                        Label("\(recordCount) registro\(recordCount == 1 ? "" : "s")", systemImage: "chart.bar.fill")
                            .font(.caption2)
                            .foregroundStyle(.green)
                    } else {
                        Label("\(workout.exercises.count) ejercicios", systemImage: "list.bullet")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: 130)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    WorkoutsView()
}
