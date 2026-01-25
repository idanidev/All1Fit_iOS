import SwiftUI

// Note: SyncStatus enum is defined in WatchConnectivityService

// MARK: - Sync Status View
struct SyncStatusView: View {
    let status: WatchConnectivityService.SyncStatus
    let lastSyncDate: Date?
    let progress: Double?
    let onRefresh: () -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            // Status Icon & Text
            HStack(spacing: 8) {
                statusIcon
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(statusText)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(statusColor)
                    
                    if let lastSync = lastSyncDate {
                        Text("Última: \(lastSync, style: .relative)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                // Refresh button
                Button {
                    onRefresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption)
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            
            // Progress bar (only during sync)
            if case .syncing = status, let progress = progress {
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 4)
            }
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
    
    // MARK: - Helpers
    
    @ViewBuilder
    private var statusIcon: some View {
        switch status {
        case .idle, .success:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .syncing:
            ProgressView()
                .scaleEffect(0.8)
        case .error:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
        }
    }
    
    private var statusText: String {
        switch status {
        case .idle:
            return "Sincronizado"
        case .success:
            return "✓ Sincronizado"
        case .syncing:
            return "Sincronizando..."
        case .error(let message):
            return message
        }
    }
    
    private var statusColor: Color {
        switch status {
        case .idle, .success:
            return .green
        case .syncing:
            return .blue
        case .error:
            return .orange
        }
    }
}

// MARK: - Skeleton Loader for Watch
struct WatchSkeletonLoader: View {
    let count: Int
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 12) {
            ForEach(0..<count, id: \.self) { _ in
                HStack(spacing: 12) {
                    // Icon placeholder
                    Circle()
                        .fill(.secondary.opacity(0.2))
                        .frame(width: 40, height: 40)
                    
                    // Text placeholders
                    VStack(alignment: .leading, spacing: 6) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(.secondary.opacity(0.2))
                            .frame(width: 120, height: 12)
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(.secondary.opacity(0.15))
                            .frame(width: 80, height: 10)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal)
                .opacity(isAnimating ? 0.5 : 1.0)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
    }
}

// MARK: - Empty State for Watch
struct WatchEmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    let actionTitle: String?
    let action: (() -> Void)?
    
    init(icon: String, title: String, message: String, actionTitle: String? = nil, action: (() -> Void)? = nil) {
        self.icon = icon
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            
            Text(title)
                .font(.headline)
            
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            
            if let actionTitle = actionTitle, let action = action {
                Button(actionTitle) {
                    action()
                }
                .font(.caption)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }
}

// MARK: - Preview
#Preview {
    ScrollView {
        VStack(spacing: 16) {
            SyncStatusView(
                status: .idle,
                lastSyncDate: Date(),
                progress: nil,
                onRefresh: {}
            )
            
            SyncStatusView(
                status: .syncing,
                lastSyncDate: Date().addingTimeInterval(-60),
                progress: 0.6,
                onRefresh: {}
            )
            
            SyncStatusView(
                status: .error("Sin conexión"),
                lastSyncDate: Date().addingTimeInterval(-3600),
                progress: nil,
                onRefresh: {}
            )
            
            Divider()
            
            WatchSkeletonLoader(count: 3)
            
            Divider()
            
            WatchEmptyStateView(
                icon: "dumbbell",
                title: "Sin ejercicios",
                message: "Añade ejercicios desde tu iPhone para empezar",
                actionTitle: "Sincronizar",
                action: {}
            )
        }
        .padding()
    }
}
