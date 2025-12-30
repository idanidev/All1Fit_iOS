import Foundation
import Network
import SwiftUI

// MARK: - Network Monitor
@MainActor
@Observable
class NetworkMonitor {
    static let shared = NetworkMonitor()
    
    var isConnected = true
    var connectionType: ConnectionType = .unknown
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    enum ConnectionType {
        case wifi
        case cellular
        case ethernet
        case unknown
    }
    
    private init() {
        startMonitoring()
    }
    
    func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.isConnected = path.status == .satisfied
                self?.connectionType = self?.getConnectionType(path) ?? .unknown
            }
        }
        monitor.start(queue: queue)
    }
    
    func stopMonitoring() {
        monitor.cancel()
    }
    
    private func getConnectionType(_ path: NWPath) -> ConnectionType {
        if path.usesInterfaceType(.wifi) {
            return .wifi
        } else if path.usesInterfaceType(.cellular) {
            return .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            return .ethernet
        }
        return .unknown
    }
}

// MARK: - Offline Banner View
struct OfflineBanner: View {
    @State private var networkMonitor = NetworkMonitor.shared
    
    var body: some View {
        if !networkMonitor.isConnected {
            HStack(spacing: 8) {
                Image(systemName: "wifi.slash")
                    .font(.caption)
                
                Text("Sin conexión - Los cambios se guardarán localmente")
                    .font(.caption)
                
                Spacer()
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.orange.gradient)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}

// MARK: - Network Status Indicator
struct NetworkStatusIndicator: View {
    @State private var networkMonitor = NetworkMonitor.shared
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(networkMonitor.isConnected ? Color.green : Color.orange)
                .frame(width: 8, height: 8)
            
            Text(networkMonitor.isConnected ? "Online" : "Offline")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}
