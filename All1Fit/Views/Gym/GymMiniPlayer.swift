import SwiftUI

extension Notification.Name {
    /// Reabre el logger de la sesión de gym activa
    static let openActiveGymSession = Notification.Name("openActiveGymSession")
}

// MARK: - Mini Player de sesión de gym
/// Cápsula flotante sobre la tab bar mientras hay entreno activo minimizado,
/// al estilo del TabataMiniPlayer: cronómetro, series completadas y tap para reabrir.
struct GymMiniPlayer: View {
    @ObservedObject var sessionService: GymSessionService

    var body: some View {
        if let session = sessionService.activeSession {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Image(systemName: "dumbbell.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 26, height: 26)
                        .background(
                            LinearGradient(colors: [.all1FitBlue, .all1FitCyan], startPoint: .topLeading, endPoint: .bottomTrailing),
                            in: Circle()
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(session.routineName)
                            .font(.subheadline.bold())
                            .lineLimit(1)

                        TimelineView(.periodic(from: .now, by: 1)) { context in
                            Text("\(formattedElapsed(since: session.startDate, now: context.date)) • \(session.totalCompletedSets) series")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                    }

                    Spacer()

                    Image(systemName: "chevron.up")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.all1FitBlue)
                        .frame(width: 32, height: 32)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.1), radius: 5)
                .contentShape(Rectangle())
                .onTapGesture {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    NotificationCenter.default.post(name: .openActiveGymSession, object: nil)
                }
            }
            .padding(.horizontal)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Entreno de gym en curso: \(session.routineName). Tocar para abrir.")
        }
    }

    private func formattedElapsed(since start: Date, now: Date) -> String {
        let total = Int(max(now.timeIntervalSince(start), 0))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%02d:%02d", m, s)
    }
}
