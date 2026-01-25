import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var connectivity: WatchConnectivityService
    
    var body: some View {
        List {
            Section("Estado de Conexión") {
                HStack {
                    connectionIcon
                    Text(connectionStatusText)
                        .font(.headline)
                    Spacer()
                }
                .listRowBackground(Color.clear)
                
                
                Button {
                    Task {
                        // Trigger manual sync or check reachability
                        print("User requested manual sync/check")
                    }
                } label: {
                    Label("Comprobar conexión", systemImage: "arrow.clockwise")
                }
                .disabled(connectivity.syncStatus == .syncing)
            }
            
            Section("Información") {
                HStack {
                    Text("Versión")
                    Spacer()
                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Ajustes")
    }
    
    private var connectionIcon: some View {
        Group {
            switch connectivity.syncStatus {
            case .syncing:
                Image(systemName: "arrow.triangle.2.circlepath")
                    .foregroundStyle(.blue)
            case .error:
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            default:
                if connectivity.isPhoneReachable {
                    Image(systemName: "applewatch.and.arrow.forward")
                        .foregroundStyle(.green)
                } else {
                    Image(systemName: "iphone.slash")
                        .foregroundStyle(.gray)
                }
            }
        }
    }
    
    private var connectionStatusText: String {
        switch connectivity.syncStatus {
        case .syncing:
            return "Sincronizando..."
        case .error:
            return "Error de conexión"
        default:
            return connectivity.isPhoneReachable ? "Conectado" : "Desconectado"
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(WatchConnectivityService.shared)
}
