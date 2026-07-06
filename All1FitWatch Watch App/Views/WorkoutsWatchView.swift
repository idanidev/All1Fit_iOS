import SwiftUI

// MARK: - Workouts Watch View
struct WorkoutsWatchView: View {
    @EnvironmentObject var connectivity: WatchConnectivityService
    @State private var selectedCategory: WatchWorkoutCategory = .crossfit

    private var allWorkouts: [WatchWorkout] {
        let predefined = WatchWorkout.workouts(for: selectedCategory)
        let userSynced = connectivity.userWorkouts
            .filter { $0.watchCategory == selectedCategory }
            .map { $0.toWatchWorkout() }
        return predefined + userSynced
    }

    var body: some View {
        List {
            // Category Picker
            Picker("Categoría", selection: $selectedCategory) {
                ForEach(WatchWorkoutCategory.allCases) { category in
                    Label(category.rawValue, systemImage: category.icon)
                        .tag(category)
                }
            }
            .listRowBackground(Color.clear)

            // Workouts
            ForEach(allWorkouts) { workout in
                NavigationLink {
                    WorkoutTimerView(workout: workout)
                } label: {
                    WorkoutRowWatch(workout: workout)
                }
            }

            if allWorkouts.isEmpty {
                Text("No hay entrenos en esta categoría")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .listRowBackground(Color.clear)
            }
        }
        .navigationTitle("Entrenos")
    }
}

// MARK: - Workout Row Watch
struct WorkoutRowWatch: View {
    let workout: WatchWorkout
    
    private var categoryColor: Color {
        switch workout.category {
        case .running: return .orange
        case .crossfit: return .red
        case .competition: return .purple
        }
    }
    
    var body: some View {
        HStack {
            // Icon
            Image(systemName: workout.category.icon)
                .foregroundStyle(categoryColor)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(workout.name)
                    .font(.headline)
                
                Text(workout.description)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Type indicator
            if workout.isForTime {
                Image(systemName: "timer")
                    .font(.caption)
                    .foregroundStyle(.orange)
            } else {
                Text("AMRAP")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.blue)
            }
        }
    }
}

#Preview {
    NavigationStack {
        WorkoutsWatchView()
    }
}
