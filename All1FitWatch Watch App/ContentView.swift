import SwiftUI

struct ContentView: View {
    @EnvironmentObject var connectivityService: WatchConnectivityService

    var body: some View {
        NavigationStack {
            List {
                // Sesión de gym activa (espejo del iPhone)
                if let gymSession = connectivityService.activeGymSession {
                    NavigationLink {
                        GymSessionWatchView()
                    } label: {
                        Label {
                            VStack(alignment: .leading) {
                                Text("Entreno en curso")
                                    .font(.headline)
                                Text("\(gymSession.routineName) · \(gymSession.totalCompletedSets) series")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "dumbbell.fill")
                                .foregroundStyle(.cyan)
                        }
                    }
                    .listItemTint(.cyan.opacity(0.2))
                }

                // RMs Section
                NavigationLink {
                    RMListWatchView()
                } label: {
                    Label {
                        VStack(alignment: .leading) {
                            Text("Mis RMs")
                                .font(.headline)
                            Text("\(connectivityService.ejercicios.count) ejercicios")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "dumbbell.fill")
                            .foregroundStyle(.orange)
                    }
                }
                
                // Workouts Section
                NavigationLink {
                    WorkoutsWatchView()
                } label: {
                    Label("Entrenos", systemImage: "figure.run")
                        .foregroundStyle(.red)
                }
                
                // Tabatas Section
                NavigationLink {
                    TabataWatchView()
                } label: {
                    Label {
                        VStack(alignment: .leading) {
                            Text("Tabatas")
                                .font(.headline)
                            Text("\(connectivityService.tabatas.count) disponibles")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "timer")
                            .foregroundStyle(.green)
                    }
                }
                
                // Quick Timer
                NavigationLink {
                    QuickTimerView()
                } label: {
                    Label("Cronómetro", systemImage: "stopwatch")
                        .foregroundStyle(.cyan)
                }

                // Cacos Section
                NavigationLink {
                    CacosWatchView()
                } label: {
                    Label("Cacos", systemImage: "figure.run.circle")
                        .foregroundStyle(.orange)
                }
            }
            .navigationTitle("All1Fit")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .foregroundStyle(.gray)
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    CompactSyncStatus(connectivity: connectivityService)
                }
            }
            .safeAreaInset(edge: .bottom) {
                if connectivityService.syncStatus == .syncing {
                    SyncStatusIndicator(connectivity: connectivityService)
                        .padding(.bottom, 8)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(WatchConnectivityService.shared)
}
