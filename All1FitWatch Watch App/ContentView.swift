import SwiftUI

struct ContentView: View {
    @EnvironmentObject var connectivityService: WatchConnectivityService
    
    var body: some View {
        NavigationStack {
            List {
                // RMs Section
                NavigationLink {
                    RMListWatchView()
                } label: {
                    HStack {
                        Image(systemName: "dumbbell.fill")
                            .foregroundStyle(.orange)
                            .frame(width: 30)
                        
                        VStack(alignment: .leading) {
                            Text("Mis RMs")
                                .font(.headline)
                            Text("\(connectivityService.ejercicios.count) ejercicios")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                // Workouts Section
                NavigationLink {
                    WorkoutsWatchView()
                } label: {
                    HStack {
                        Image(systemName: "figure.run")
                            .foregroundStyle(.red)
                            .frame(width: 30)
                        
                        VStack(alignment: .leading) {
                            Text("Entrenos")
                                .font(.headline)
                            Text("WODs y Running")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                // Quick Timer
                NavigationLink {
                    QuickTimerView()
                } label: {
                    HStack {
                        Image(systemName: "timer")
                            .foregroundStyle(.green)
                            .frame(width: 30)
                        
                        VStack(alignment: .leading) {
                            Text("Cronómetro")
                                .font(.headline)
                            Text("Timer rápido")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("All1Fit")
        }
        .onAppear {
            connectivityService.requestDataFromPhone()
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(WatchConnectivityService.shared)
}
