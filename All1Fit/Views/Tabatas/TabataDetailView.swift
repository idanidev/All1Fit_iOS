import SwiftUI

// MARK: - Tabata Detail View
struct TabataDetailView: View {
    let tabata: Tabata
    @EnvironmentObject var tabataService: TabataService
    @State private var showingTimer = false
    @State private var syncWithWatch = false
    
    private var cardColor: Color {
        tabata.type == .intervals ? .orange : .blue
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header Card
                headerCard
                
                // Details
                if tabata.type == .intervals {
                    intervalsDetails
                } else {
                    treadmillDetails
                }
                
                // History
                historySection
                
                Spacer(minLength: 100)
            }
            .padding()
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle(tabata.name)
        .navigationBarTitleDisplayMode(.inline)
        .overlay(alignment: .bottom) {
            startButton
        }
        .fullScreenCover(isPresented: $showingTimer) {
            TabataTimerView(tabata: tabata, syncWithWatch: syncWithWatch)
                .environmentObject(tabataService)
        }
        .task {
            await tabataService.fetchResults(for: tabata.id)
        }
    }
    
    // MARK: - Header Card
    private var headerCard: some View {
        VStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [cardColor, cardColor.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                
                Image(systemName: tabata.type.icon)
                    .font(.system(size: 36))
                    .foregroundStyle(.white)
            }
            
            // Name & Duration
            VStack(spacing: 4) {
                Text(tabata.name)
                    .font(.title2.bold())
                
                Text(tabata.formattedDuration)
                    .font(.headline)
                    .foregroundStyle(cardColor)
                
                Text(tabata.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            // Watch sync toggle
            Toggle(isOn: $syncWithWatch) {
                Label("Sincronizar con Apple Watch", systemImage: "applewatch")
            }
            .toggleStyle(.switch)
            .tint(cardColor)
            .padding(.horizontal)
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
    
    // MARK: - Intervals Details
    private var intervalsDetails: some View {
        VStack(spacing: 12) {
            Text("Estructura")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack(spacing: 16) {
                DetailBox(
                    title: "Trabajo",
                    value: "\(tabata.workSeconds)s",
                    color: .green,
                    icon: "flame.fill"
                )
                
                DetailBox(
                    title: "Descanso",
                    value: "\(tabata.restSeconds)s",
                    color: .red,
                    icon: "pause.fill"
                )
            }
            
            HStack(spacing: 16) {
                DetailBox(
                    title: "Rondas",
                    value: "\(tabata.rounds)",
                    color: .orange,
                    icon: "repeat"
                )
                
                if tabata.sets > 1 {
                    DetailBox(
                        title: "Sets",
                        value: "\(tabata.sets)",
                        color: .purple,
                        icon: "square.stack.3d.up"
                    )
                }
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Treadmill Details
    private var treadmillDetails: some View {
        VStack(spacing: 12) {
            Text("Fases")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            if let phases = tabata.treadmillPhases {
                ForEach(Array(phases.enumerated()), id: \.element.id) { index, phase in
                    HStack {
                        // Phase number
                        ZStack {
                            Circle()
                                .fill(cardColor)
                                .frame(width: 32, height: 32)
                            Text("\(index + 1)")
                                .font(.headline)
                                .foregroundStyle(.white)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(phase.name)
                                .font(.subheadline.bold())
                            
                            HStack(spacing: 12) {
                                Label("\(phase.durationMinutes) min", systemImage: "clock")
                                Label("\(Int(phase.inclinePercent))%", systemImage: "arrow.up.right")
                                Label("\(String(format: "%.1f", phase.speedKmh)) km/h", systemImage: "speedometer")
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding(.vertical, 8)
                    
                    if index < phases.count - 1 {
                        Divider()
                    }
                }
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - History Section
    private var historySection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Historial")
                    .font(.headline)
                Spacer()
                if tabataService.resultCount(for: tabata.id) > 0 {
                    Text("\(tabataService.resultCount(for: tabata.id)) sesiones")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            if let results = tabataService.tabataResults[tabata.id], !results.isEmpty {
                ForEach(results.prefix(5)) { result in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(result.completedAt, style: .date)
                                .font(.subheadline)
                            Text(result.completedAt, style: .time)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        Text(result.formattedTime)
                            .font(.headline)
                            .foregroundStyle(.orange)
                    }
                    .padding(.vertical, 4)
                }
            } else {
                Text("Sin sesiones completadas")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Start Button
    private var startButton: some View {
        Button {
            showingTimer = true
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "play.fill")
                    .font(.title2)
                Text("INICIAR")
                    .font(.title3.bold())
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                LinearGradient(
                    colors: [cardColor, cardColor.opacity(0.8)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: cardColor.opacity(0.4), radius: 10, y: 5)
        }
        .padding()
        .background(.ultraThinMaterial)
    }
}

// MARK: - Detail Box Component
struct DetailBox: View {
    let title: String
    let value: String
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            
            Text(value)
                .font(.title.bold())
            
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    NavigationStack {
        TabataDetailView(tabata: Tabata.defaultTabata)
            .environmentObject(TabataService())
    }
}
