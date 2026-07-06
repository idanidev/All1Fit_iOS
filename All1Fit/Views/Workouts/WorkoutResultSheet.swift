import SwiftUI
import HealthKit
import os

// MARK: - Workout Result Sheet
struct WorkoutResultSheet: View {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.all1fit", category: "WorkoutResult")
    let workout: Workout
    var editingResult: WorkoutResult? = nil
    @EnvironmentObject var workoutService: WorkoutService
    @Environment(\.dismiss) private var dismiss
    
    @State private var hours = 0
    @State private var minutes = 0
    @State private var seconds = 0
    @State private var rounds = 0
    @State private var notes = ""
    @State private var isSaving = false
    @State private var showSuccess = false
    
    private var isEditing: Bool {
        editingResult != nil
    }
    
    private var categoryColor: Color {
        switch workout.category {
        case .running: return .orange
        case .crossfit: return .red
        case .competition: return .purple
        }
    }
    
    private var totalSeconds: Int {
        hours * 3600 + minutes * 60 + seconds
    }
    
    private var canSave: Bool {
        if workout.isForTime {
            return totalSeconds > 0
        } else {
            return rounds > 0
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Workout name
                    Text(workout.name)
                        .font(.title2.bold())
                        .padding(.top)
                    
                    // Personal Record Section
                    personalRecordSection
                    
                    // Time/Rounds picker
                    if workout.isForTime {
                        timePickerSection
                    } else {
                        roundsPickerSection
                    }
                    
                    // Notes
                    notesSection
                    
                    // Save button
                    saveButton
                }
                .padding()
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle(isEditing ? "Editar Resultado" : "Registrar Resultado")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                if let result = editingResult {
                    // Load existing values
                    hours = result.timeSeconds / 3600
                    minutes = (result.timeSeconds % 3600) / 60
                    seconds = result.timeSeconds % 60
                    rounds = result.rounds ?? 0
                    notes = result.notes ?? ""
                }
            }
            .overlay {
                if showSuccess {
                    successOverlay
                }
            }
        }
    }
    
    // MARK: - Time Picker
    private var timePickerSection: some View {
        VStack(spacing: 12) {
            Text("Tiempo")
                .font(.headline)
            
            HStack(spacing: 8) {
                // Hours
                VStack(spacing: 4) {
                    Picker("Horas", selection: $hours) {
                        ForEach(0..<24, id: \.self) { h in
                            Text("\(h)").tag(h)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(width: 80, height: 120)
                    .clipped()
                    
                    Text("h")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Text(":")
                    .font(.title2.bold())
                
                // Minutes
                VStack(spacing: 4) {
                    Picker("Minutos", selection: $minutes) {
                        ForEach(0..<60, id: \.self) { m in
                            Text(String(format: "%02d", m)).tag(m)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(width: 80, height: 120)
                    .clipped()
                    
                    Text("min")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Text(":")
                    .font(.title2.bold())
                
                // Seconds
                VStack(spacing: 4) {
                    Picker("Segundos", selection: $seconds) {
                        ForEach(0..<60, id: \.self) { s in
                            Text(String(format: "%02d", s)).tag(s)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(width: 80, height: 120)
                    .clipped()
                    
                    Text("seg")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Rounds Picker (for AMRAP)
    private var roundsPickerSection: some View {
        VStack(spacing: 12) {
            Text("Rondas completadas")
                .font(.headline)
            
            HStack(spacing: 20) {
                Button {
                    if rounds > 0 { rounds -= 1 }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.title)
                        .foregroundStyle(.secondary)
                }
                
                Text("\(rounds)")
                    .font(.system(size: 60, weight: .bold, design: .rounded))
                    .frame(width: 120)
                
                Button {
                    rounds += 1
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title)
                        .foregroundStyle(categoryColor)
                }
            }
            
            if let timeCap = workout.timeCapMinutes {
                Text("Time Cap: \(timeCap) minutos")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Personal Record Section
    private var personalRecordSection: some View {
        Group {
            if let pr = workoutService.getPersonalRecord(for: workout.id) {
                // Show current PR
                HStack(spacing: 16) {
                    Image(systemName: "trophy.fill")
                        .font(.title2)
                        .foregroundStyle(.yellow)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Mi Marca")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        if workout.isForTime {
                            Text(pr.formattedTime)
                                .font(.title3.bold())
                        } else if let rounds = pr.rounds {
                            Text("\(rounds) rondas")
                                .font(.title3.bold())
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
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                // No previous records
                HStack(spacing: 12) {
                    Image(systemName: "star.fill")
                        .font(.title2)
                        .foregroundStyle(categoryColor)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Sin registros previos")
                            .font(.subheadline.bold())
                        
                        Text("¡Este será tu primer resultado!")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                }
                .padding()
                .background(categoryColor.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }
    
    // MARK: - Notes Section
    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Notas (opcional)")
                .font(.headline)
            
            TextField("¿Cómo te sentiste? ¿Con chaleco?...", text: $notes, axis: .vertical)
                .lineLimit(3...6)
                .padding()
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    
    // MARK: - Save Button
    private var saveButton: some View {
        Button {
            saveResult()
        } label: {
            if isSaving {
                ProgressView()
                    .tint(.white)
            } else {
                Label("Guardar Resultado", systemImage: "checkmark.circle.fill")
                    .font(.headline)
            }
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .frame(height: 56)
        .background(
            canSave
            ? AnyShapeStyle(LinearGradient(colors: [categoryColor, categoryColor.opacity(0.8)], startPoint: .leading, endPoint: .trailing))
            : AnyShapeStyle(Color.gray.opacity(0.3))
        )
        .clipShape(Capsule())
        .disabled(!canSave || isSaving)
    }
    
    // MARK: - Success Overlay
    private var successOverlay: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 80))
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
    
    // MARK: - Save Result
    private func saveResult() {
        isSaving = true
        
        Task {
            do {
                if let result = editingResult {
                    // Update existing result
                    try await workoutService.updateResult(
                        result,
                        timeSeconds: totalSeconds,
                        rounds: workout.isForTime ? nil : rounds,
                        notes: notes.isEmpty ? nil : notes
                    )
                } else {
                    // Create new result
                    try await workoutService.saveResult(
                        workoutId: workout.id,
                        timeSeconds: totalSeconds,
                        rounds: workout.isForTime ? nil : rounds,
                        notes: notes.isEmpty ? nil : notes
                    )
                    // Save to HealthKit
                    let activityType: HKWorkoutActivityType = workout.category == .running ? .running : .highIntensityIntervalTraining
                    let duration = TimeInterval(totalSeconds > 0 ? totalSeconds : 1800)
                    await HealthKitService.shared.saveWorkout(
                        activityType: activityType,
                        startDate: Date().addingTimeInterval(-duration),
                        duration: duration
                    )
                }

                showSuccess = true
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                dismiss()
            } catch {
                isSaving = false
                logger.error("❌ Error saving workout result: \(error.localizedDescription)")
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            }
        }
    }
}

#Preview {
    WorkoutResultSheet(workout: Workout.all.first!)
        .environmentObject(WorkoutService())
}
