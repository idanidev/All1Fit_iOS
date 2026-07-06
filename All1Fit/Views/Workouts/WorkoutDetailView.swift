import SwiftUI

// MARK: - Workout Detail View
struct WorkoutDetailView: View {
    let workout: Workout
    @EnvironmentObject var workoutService: WorkoutService
    @State private var showingAddResult = false
    @State private var resultToEdit: WorkoutResult?
    @State private var resultToDelete: WorkoutResult?
    @State private var showDeleteConfirmation = false
    @State private var errorMessage: String?
    
    private var results: [WorkoutResult] {
        workoutService.results[workout.id] ?? []
    }
    
    private var personalRecord: WorkoutResult? {
        workoutService.getPersonalRecord(for: workout.id)
    }
    
    private var categoryColor: Color {
        switch workout.category {
        case .running: return .orange
        case .crossfit: return .red
        case .competition: return .purple
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header card
                headerCard
                
                // Personal Record
                if let pr = personalRecord {
                    prCard(pr)
                }
                
                // Progress Chart
                if results.count >= 2 {
                    WorkoutHistoryChartView(results: results, isForTime: workout.isForTime)
                }
                
                // Exercises
                exercisesSection
                
                // Results history
                if !results.isEmpty {
                    resultsSection
                }
            }
            .padding()
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle(workout.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddResult = true
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(categoryColor)
                }
            }
        }
        .sheet(isPresented: $showingAddResult) {
            WorkoutResultSheet(workout: workout)
        }
        .sheet(item: $resultToEdit) { result in
            WorkoutResultSheet(workout: workout, editingResult: result)
        }
        .all1FitConfirmation(Binding(
            get: {
                guard showDeleteConfirmation else { return nil }
                return All1FitConfirmation(
                    title: "¿Eliminar resultado?",
                    message: "El resultado se eliminará de tu historial. Esta acción no se puede deshacer.",
                    icon: "trash.fill",
                    confirmTitle: "Eliminar"
                ) {
                    if let result = resultToDelete {
                        Task {
                            do {
                                try await workoutService.deleteResult(result)
                                UINotificationFeedbackGenerator().notificationOccurred(.success)
                            } catch {
                                errorMessage = error.localizedDescription
                                UINotificationFeedbackGenerator().notificationOccurred(.error)
                            }
                        }
                    }
                }
            },
            set: { if $0 == nil { showDeleteConfirmation = false } }
        ))
        .alert("Error", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .overlay {
            if workoutService.isLoading && results.isEmpty {
                ProgressView()
                    .scaleEffect(1.5)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(uiColor: .systemGroupedBackground).opacity(0.8))
            }
        }
        .task {
            await workoutService.fetchResults(for: workout.id)
        }
    }
    
    // MARK: - Header Card
    private var headerCard: some View {
        VStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [categoryColor.opacity(0.3), categoryColor.opacity(0.1)],
                            center: .center,
                            startRadius: 0,
                            endRadius: 60
                        )
                    )
                    .frame(width: 80, height: 80)
                
                Image(systemName: workout.category.icon)
                    .font(.system(size: 36))
                    .foregroundStyle(categoryColor)
            }
            
            // Description
            Text(workout.description)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            // Tags
            HStack(spacing: 16) {
                if workout.isForTime {
                    TagBadge(text: "For Time", icon: "timer", color: .orange)
                } else {
                    TagBadge(text: "AMRAP", icon: "repeat", color: .blue)
                }
                
                if let timeCap = workout.timeCapMinutes {
                    TagBadge(text: "\(timeCap) min", icon: "clock", color: .green)
                }
                
                TagBadge(text: workout.category.rawValue, icon: workout.category.icon, color: categoryColor)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
    
    // MARK: - PR Card
    private func prCard(_ pr: WorkoutResult) -> some View {
        HStack(spacing: 16) {
            Image(systemName: "trophy.fill")
                .font(.title)
                .foregroundStyle(.yellow)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Personal Record")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                if workout.isForTime {
                    Text(pr.formattedTime)
                        .font(.title2.bold())
                } else if let rounds = pr.rounds {
                    Text("\(rounds) rondas")
                        .font(.title2.bold())
                }
            }
            
            Spacer()
            
            Text(pr.formattedDate)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(
            LinearGradient(
                colors: [.yellow.opacity(0.15), .orange.opacity(0.1)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Exercises Section
    private var exercisesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Ejercicios")
                .font(.headline)
            
            ForEach(Array(workout.exercises.enumerated()), id: \.element.id) { index, exercise in
                ExerciseRow(index: index + 1, exercise: exercise, color: categoryColor)
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Results Section
    private var resultsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Historial")
                    .font(.headline)
                
                Spacer()
                
                Text("\(results.count) registros")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            .padding(.top)
            
            // Results with context menu for edit/delete
            ForEach(results) { result in
                HStack {
                    ResultRow(result: result, isPR: result.id == personalRecord?.id, workout: workout)
                    
                    // Visual hint for actions
                    Image(systemName: "ellipsis.circle")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
                .contextMenu {
                    Button {
                        resultToEdit = result
                    } label: {
                        Label("Editar", systemImage: "pencil")
                    }
                    
                    Button(role: .destructive) {
                        resultToDelete = result
                        showDeleteConfirmation = true
                    } label: {
                        Label("Eliminar", systemImage: "trash")
                    }
                }
                .padding(.horizontal)
                
                if result.id != results.last?.id {
                    Divider()
                        .padding(.leading)
                }
            }
            .padding(.bottom)
        }
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Tag Badge
struct TagBadge: View {
    let text: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
            Text(text)
        }
        .font(.caption.bold())
        .foregroundStyle(color)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(color.opacity(0.1))
        .clipShape(Capsule())
    }
}

// MARK: - Exercise Row
struct ExerciseRow: View {
    let index: Int
    let exercise: WorkoutExercise
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Text("\(index)")
                .font(.caption.bold())
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(color)
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.name)
                    .font(.subheadline.bold())
                
                if let notes = exercise.notes {
                    Text(notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            Text(exercise.reps)
                .font(.subheadline.bold())
                .foregroundStyle(color)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Result Row
struct ResultRow: View {
    let result: WorkoutResult
    let isPR: Bool
    let workout: Workout
    
    var body: some View {
        HStack(spacing: 12) {
            if isPR {
                Image(systemName: "trophy.fill")
                    .foregroundStyle(.yellow)
            } else {
                Image(systemName: "clock")
                    .foregroundStyle(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                if workout.isForTime {
                    Text(result.formattedTime)
                        .font(.subheadline.bold())
                } else if let rounds = result.rounds {
                    Text("\(rounds) rondas")
                        .font(.subheadline.bold())
                }
                
                if let notes = result.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            Text(result.formattedDate)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    NavigationStack {
        WorkoutDetailView(workout: Workout.all.first!)
            .environmentObject(WorkoutService())
    }
}
