import SwiftUI

// MARK: - Mobility View
struct MobilityView: View {
    @State private var selectedZone: BodyZone = .shoulders
    @Namespace private var animation
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerSection
                    
                    // Body Map
                    BodyMapView(selectedZone: $selectedZone)
                        .frame(height: 350)
                    
                    // Zone selector pills
                    zoneSelectorPills
                    
                    // Exercises for selected zone
                    exercisesSection
                }
                .padding()
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Image("Logo")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 40)
                }
            }
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 8) {
            Text("Movilidad")
                .font(.largeTitle.bold())
            
            Text("Selecciona una zona del cuerpo")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
    
    // MARK: - Zone Selector Pills
    private var zoneSelectorPills: some View {
        HStack(spacing: 12) {
            ForEach(BodyZone.allCases) { zone in
                Button {
                    withAnimation(.spring(duration: 0.3)) {
                        selectedZone = zone
                    }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: zone.icon)
                        Text(zone.rawValue)
                    }
                    .font(.subheadline.bold())
                    .foregroundStyle(selectedZone == zone ? .white : .primary)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(
                        selectedZone == zone
                        ? AnyShapeStyle(LinearGradient(colors: [.orange, .red], startPoint: .leading, endPoint: .trailing))
                        : AnyShapeStyle(Color(uiColor: .secondarySystemGroupedBackground))
                    )
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    // MARK: - Exercises Section
    private var exercisesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Ejercicios de \(selectedZone.rawValue)")
                    .font(.headline)
                
                Spacer()
                
                Text("\(MobilityExercise.exercises(for: selectedZone).count) ejercicios")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                ForEach(MobilityExercise.exercises(for: selectedZone)) { exercise in
                    MobilityExerciseCard(exercise: exercise)
                }
            }
        }
        .animation(.spring(duration: 0.3), value: selectedZone)
    }
}

// MARK: - Mobility Exercise Card
struct MobilityExerciseCard: View {
    let exercise: MobilityExercise
    @State private var isExpanded = false
    
    var body: some View {
        Button {
            isExpanded = true
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        } label: {
            VStack(spacing: 12) {
                // Video thumbnail or fallback
                ZStack {
                    // Try video thumbnail first
                    VideoThumbnail(videoName: exercise.gifName)
                        .frame(height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    
                    // Play icon overlay
                    Image(systemName: "play.circle.fill")
                        .font(.title)
                        .foregroundStyle(.white.opacity(0.8))
                        .shadow(radius: 4)
                }
                .frame(height: 100)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                VStack(spacing: 4) {
                    Text(exercise.name)
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                        Text("\(exercise.duration)s")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
            .padding()
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $isExpanded) {
            MobilityExerciseDetailView(exercise: exercise)
        }
    }
}

// MARK: - Mobility Exercise Detail View
struct MobilityExerciseDetailView: View {
    let exercise: MobilityExercise
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Video player (loops automatically)
                    LoopingVideoPlayer(videoName: exercise.gifName)
                        .frame(height: 250)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                    
                    // Info
                    VStack(alignment: .leading, spacing: 16) {
                        // Duration badge
                        HStack {
                            Label("\(exercise.duration) segundos", systemImage: "clock.fill")
                                .font(.subheadline.bold())
                                .foregroundStyle(.orange)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.orange.opacity(0.1))
                                .clipShape(Capsule())
                            
                            Label(exercise.bodyZone.rawValue, systemImage: exercise.bodyZone.icon)
                                .font(.subheadline.bold())
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color(uiColor: .tertiarySystemFill))
                                .clipShape(Capsule())
                        }
                        
                        // Description
                        Text("Instrucciones")
                            .font(.headline)
                        
                        Text(exercise.description)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Spacer()
                    
                    // Start button
                    Button {
                        dismiss()
                    } label: {
                        Label("Comenzar Ejercicio", systemImage: "play.fill")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                LinearGradient(colors: [.orange, .red], startPoint: .leading, endPoint: .trailing),
                                in: Capsule()
                            )
                    }
                }
                .padding()
            }
            .navigationTitle(exercise.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.large])
    }
}

#Preview {
    MobilityView()
}

