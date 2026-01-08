import SwiftUI
import WatchKit

// MARK: - Tabata Watch View
struct TabataWatchView: View {
    @EnvironmentObject var connectivityService: WatchConnectivityService
    @State private var selectedTabata: Tabata?
    
    var body: some View {
        NavigationStack {
            List {
                // Intervals
                let intervalTabatas = connectivityService.tabatas.filter { $0.type == .intervals }
                if !intervalTabatas.isEmpty {
                    Section("🔥 Intervalos") {
                        ForEach(intervalTabatas) { tabata in
                            NavigationLink {
                                TabataTimerWatchView(tabata: tabata)
                            } label: {
                                TabataRowWatch(tabata: tabata)
                            }
                        }
                    }
                } else if connectivityService.tabatas.isEmpty {
                    Text("Cargando tabatas...")
                }
                
                // Treadmill
                let treadmillTabatas = connectivityService.tabatas.filter { $0.type == .treadmill }
                if !treadmillTabatas.isEmpty {
                    Section("🏃 Cinta") {
                        ForEach(treadmillTabatas) { tabata in
                            NavigationLink {
                                TreadmillTimerWatchView(tabata: tabata)
                            } label: {
                                TabataRowWatch(tabata: tabata)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Tabatas")
        }
        .onAppear {
            if connectivityService.tabatas.isEmpty {
                connectivityService.requestDataFromPhone()
            }
        }

    }
}

// MARK: - Tabata Row
struct TabataRowWatch: View {
    let tabata: Tabata
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(tabata.name)
                .font(.headline)
            
            HStack(spacing: 8) {
                Text(tabata.subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                
                Text("•")
                    .foregroundStyle(.secondary)
                
                Text(tabata.formattedDuration)
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview
#Preview {
    TabataWatchView()
        .environmentObject(WatchConnectivityService.shared)
}
