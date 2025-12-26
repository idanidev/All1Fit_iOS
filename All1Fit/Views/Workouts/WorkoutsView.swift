
import SwiftUI

// MARK: - Workouts View
struct WorkoutsView: View {
    @StateObject private var workoutService = WorkoutService()
    @EnvironmentObject var userWorkoutService: UserWorkoutService
    @State private var selectedCategory: WorkoutCategory = .crossfit
    @State private var searchText = ""
    @State private var showingAddWorkout = false
    // showingAddWorkout removed as it's handled globally now
    
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
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                ScrollView {
                    VStack(spacing: 20) {
                        // DEBUG INFO (Temporary)
                        if userWorkoutService.isLoading {
                            ProgressView("Cargando...")
                        } else {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("DEBUG: \(userWorkoutService.userWorkouts.count) entrenos encontrados")
                                    .font(.caption.bold())
                                    .foregroundStyle(.orange)
                                if let error = userWorkoutService.errorMessage {
                                    Text("Error: \(error)").foregroundStyle(.red)
                                }
                                Text("Cats: \(userWorkoutService.userWorkouts.map { $0.category }.joined(separator: ", "))")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                            .padding(8)
                            .background(Color.black.opacity(0.1))
                            .cornerRadius(8)
                        }
                        // Category selector
                        categorySelector
                        
                        // Workouts grid
                        workoutsGrid
                    }
                    .padding()
                }
                .background(Color(uiColor: .systemGroupedBackground))
                
                // Floating Add Button
                Button {
                    showingAddWorkout = true
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                } label: {
                    Image(systemName: "plus")
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                        .frame(width: 56, height: 56)
                        .background(
                            LinearGradient(
                                colors: [.red, .orange],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(Circle())
                        .shadow(color: .red.opacity(0.4), radius: 8, y: 4)
                }
                .padding(.trailing, 20)
                .padding(.bottom, 20)
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
        }
    }
    
    // MARK: - Workouts Grid
    private var workoutsGrid: some View {
        LazyVStack(spacing: 16) {
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
                .buttonStyle(.plain)
            }
        }
        .animation(.spring(duration: 0.3), value: selectedCategory)
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
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    WorkoutsView()
}
