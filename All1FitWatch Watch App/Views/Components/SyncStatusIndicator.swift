import SwiftUI

// MARK: - Sync Status Indicator
/// Indicador visual elegante del estado de sincronización con iPhone
struct SyncStatusIndicator: View {
    @ObservedObject var connectivity: WatchConnectivityService

    private var statusColor: Color {
        if connectivity.isPhoneReachable && connectivity.isConnected {
            return .green
        } else if connectivity.isConnected {
            return .orange
        } else {
            return .red
        }
    }

    private var statusIcon: String {
        if connectivity.isPhoneReachable && connectivity.isConnected {
            return "checkmark.iphone"
        } else if connectivity.isConnected {
            return "iphone.slash"
        } else {
            return "exclamationmark.iphone"
        }
    }

    private var statusText: String {
        if connectivity.isPhoneReachable && connectivity.isConnected {
            return "Sincronizado"
        } else if connectivity.isConnected {
            return "Sin conexión"
        } else {
            return "Desconectado"
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            // Animated status indicator
            Image(systemName: statusIcon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(statusColor)
                .symbolEffect(
                    .pulse,
                    options: .repeating,
                    isActive: connectivity.syncStatus == .syncing
                )

            if connectivity.syncStatus == .syncing {
                Text("Sincronizando...")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(statusColor.opacity(0.15))
        )
    }
}

// MARK: - Compact Sync Status (for toolbar)
struct CompactSyncStatus: View {
    @ObservedObject var connectivity: WatchConnectivityService

    private var statusColor: Color {
        if connectivity.isPhoneReachable && connectivity.isConnected {
            return .green
        } else if connectivity.isConnected {
            return .orange
        } else {
            return .red
        }
    }

    var body: some View {
        Circle()
            .fill(statusColor.gradient)
            .frame(width: 8, height: 8)
            .overlay(
                Circle()
                    .stroke(statusColor.opacity(0.3), lineWidth: 2)
                    .scaleEffect(connectivity.syncStatus == .syncing ? 1.5 : 1.0)
                    .opacity(connectivity.syncStatus == .syncing ? 0 : 1)
                    .animation(
                        connectivity.syncStatus == .syncing
                            ? .easeOut(duration: 1).repeatForever(autoreverses: false)
                            : .default,
                        value: connectivity.syncStatus
                    )
            )
    }
}

// MARK: - Sync Status Row (for settings/debug)
struct SyncStatusRow: View {
    @ObservedObject var connectivity: WatchConnectivityService

    private var statusColor: Color {
        if connectivity.isPhoneReachable && connectivity.isConnected {
            return .green
        } else if connectivity.isConnected {
            return .orange
        } else {
            return .red
        }
    }

    private var statusText: String {
        if connectivity.isPhoneReachable && connectivity.isConnected {
            return "Conectado"
        } else if connectivity.isConnected {
            return "Sin conexión"
        } else {
            return "Desconectado"
        }
    }

    var body: some View {
        HStack {
            Label {
                VStack(alignment: .leading, spacing: 4) {
                    Text("iPhone")
                        .font(.system(size: 14, weight: .semibold))

                    Text(statusText)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: "iphone")
                    .foregroundStyle(statusColor)
            }

            Spacer()

            Circle()
                .fill(statusColor)
                .frame(width: 10, height: 10)
        }
    }
}

#Preview("Sync Status Indicator") {
    VStack(spacing: 20) {
        SyncStatusIndicator(connectivity: WatchConnectivityService.shared)
        CompactSyncStatus(connectivity: WatchConnectivityService.shared)
        SyncStatusRow(connectivity: WatchConnectivityService.shared)
    }
    .padding()
}
