import SwiftUI
import WatchKit

// MARK: - Debug Connection View
struct DebugConnectionView: View {
    @ObservedObject var connectivity = WatchConnectivityService.shared
    
    var body: some View {
        List {
            Section("Estado WCSession") {
                HStack {
                    Image(systemName: connectivity.isConnected ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(connectivity.isConnected ? .green : .red)
                    Text(connectivity.isConnected ? "Conectado" : "Desconectado")
                }
                
                HStack {
                    Image(systemName: connectivity.isPhoneReachable ? "iphone" : "iphone.slash")
                        .foregroundColor(connectivity.isPhoneReachable ? .green : .orange)
                    Text(connectivity.isPhoneReachable ? "iPhone alcanzable" : "iPhone NO alcanzable")
                }
            }
            
            Section("Datos Sincronizados") {
                HStack {
                    Text("Ejercicios")
                    Spacer()
                    Text("\(connectivity.ejercicios.count)")
                        .foregroundColor(connectivity.ejercicios.isEmpty ? .red : .green)
                        .bold()
                }
                
                HStack {
                    Text("Tabatas")
                    Spacer()
                    Text("\(connectivity.tabatas.count)")
                        .foregroundColor(.secondary)
                        .bold()
                }
                
                if let date = connectivity.lastSyncDate {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Último sync")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(date.formatted(.relative(presentation: .named)))
                            .font(.caption2)
                    }
                } else {
                    Text("Sin sincronización")
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }
            
            Section("Sync Status") {
                HStack {
                    switch connectivity.syncStatus {
                    case .idle:
                        Image(systemName: "pause.circle.fill")
                            .foregroundColor(.blue)
                        Text("Idle")
                    case .syncing:
                        ProgressView()
                        Text("Sincronizando...")
                    case .success:
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Éxito")
                    case .error(let msg):
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        VStack(alignment: .leading) {
                            Text("Error")
                                .bold()
                            Text(msg)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            Section("Acciones") {
                Button {
                    WKInterfaceDevice.current().play(.click)
                    connectivity.requestDataFromPhone()
                } label: {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Forzar Sync")
                    }
                }
                
                Button(role: .destructive) {
                    WKInterfaceDevice.current().play(.click)
                    connectivity.clearCache()
                } label: {
                    HStack {
                        Image(systemName: "trash")
                        Text("Limpiar Cache")
                    }
                }
            }
            
            // Debug info extra
            if !connectivity.ejercicios.isEmpty {
                Section("Ejercicios") {
                    ForEach(connectivity.ejercicios.prefix(5), id: \.name) { ejercicio in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(ejercicio.name)
                                .font(.caption)
                            Text("\(ejercicio.rmHistory.count) RMs")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    if connectivity.ejercicios.count > 5 {
                        Text("+ \(connectivity.ejercicios.count - 5) más...")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .navigationTitle("🔍 Debug")
    }
}

#Preview {
    NavigationStack {
        DebugConnectionView()
    }
}
