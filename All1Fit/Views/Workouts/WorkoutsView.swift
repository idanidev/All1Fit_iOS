
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
    
    // Merge hardcoded + user workouts
    private var allWorkouts: [Workout] {
        let hardcoded = Workout.workouts(for: selectedCategory)
        let userConverted = userWorkoutService.userWorkouts
            .filter { $0.workoutCategory == selectedCategory }
            .map { $0.toWorkout() }
        return hardcoded + userConverted
    }
    
    private var filteredWorkouts: [Workout] {
        if searchText.isEmpty {
            return allWorkouts
        }
        return allWorkouts.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    // Colores dinámicos según categoría
    private var categoryColors: [Color] {
        switch selectedCategory {
        case .crossfit: return [.red, .orange]
        case .running: return [.blue, .cyan]
        case .competition: return [.purple, .pink]
        }
    }
    
    private var categoryShadowColor: Color {
        switch selectedCategory {
        case .crossfit: return .red
        case .running: return .blue
        case .competition: return .purple
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                List {
                    // Category selector as header
                    Section {
                        categorySelector
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    
                    // Workouts
                    Section {
                        ForEach(filteredWorkouts) { workout in
                            NavigationLink {
                                WorkoutDetailView(workout: workout)
                                    .environmentObject(workoutService)
                            } label: {
                                WorkoutCard(
                                    workout: workout,
                                    recordCount: workoutService.results[workout.id]?.count ?? 0,
                                    lastResult: workoutService.results[workout.id]?.first
                                )
                            }
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                if let userWorkout = userWorkoutService.userWorkouts.first(where: { $0.id == workout.id }) {
                                    Button(role: .destructive) {
                                        workoutToDelete = userWorkout
                                    } label: {
                                        Label("Eliminar", systemImage: "trash")
                                    }
                                }
                            }
                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                if let userWorkout = userWorkoutService.userWorkouts.first(where: { $0.id == workout.id }) {
                                    Button {
                                        userWorkoutToEdit = userWorkout
                                    } label: {
                                        Label("Editar", systemImage: "pencil")
                                    }
                                    .tint(.orange)
                                } else {
                                    Button {
                                        workoutToCustomize = workout
                                    } label: {
                                        Label("Personalizar", systemImage: "slider.horizontal.3")
                                    }
                                    .tint(.blue)
                                }
                            }
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
                
                // Floating Add Button - Color dinámico según categoría
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button {
                            showingAddWorkout = true
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "plus")
                                    .font(.title3.bold())
                                Text("Añadir")
                                    .font(.headline)
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 14)
                            .background(
                                LinearGradient(
                                    colors: categoryColors,
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .clipShape(Capsule())
                            .shadow(color: categoryShadowColor.opacity(0.4), radius: 8, y: 4)
                        }
                        .padding(.trailing, 20)
                        .padding(.bottom, 30)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Image("Logo")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 80) // Reduced to fit Dynamic Island
                        .shadow(color: .white.opacity(0.5), radius: 10)
                }
            }
            .sheet(isPresented: $showingAddWorkout) {
                WorkoutFormView()
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
                    .lineLimit(2)
                
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
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    WorkoutsView()
}
