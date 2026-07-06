import SwiftUI

extension Notification.Name {
    /// Abre la sección Tabatas dentro de la tab Entreno (desde Home o deep links)
    static let openTabatasSection = Notification.Name("openTabatasSection")
}

// MARK: - Training Hub (tab Entreno)
/// Landing de entrenamiento: dos tarjetas hero (WODs y Tabatas) que navegan
/// a sus listas completas. Sin selectores — cada sección es un destino propio.
struct TrainingHubView: View {
    @State private var showingWods = false
    @State private var showingTabatas = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    heroCard(
                        title: "WODs",
                        subtitle: "CrossFit, Hyrox y entrenos por tiempo",
                        detail: "Registra tus marcas y compite contra ti mismo",
                        icon: "figure.run",
                        gradient: [.all1FitPurple, .all1FitPink]
                    ) {
                        showingWods = true
                    }

                    heroCard(
                        title: "Tabatas",
                        subtitle: "Intervalos de alta intensidad",
                        detail: "Cronómetro por fases con avisos y Apple Watch",
                        icon: "timer",
                        gradient: [.all1FitBlue, .all1FitCyan]
                    ) {
                        showingTabatas = true
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Entreno")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(isPresented: $showingWods) {
                WorkoutsView()
            }
            .navigationDestination(isPresented: $showingTabatas) {
                TabataListView()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openTabatasSection)) { _ in
            showingTabatas = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .openActiveTabata)) { _ in
            showingTabatas = true
        }
    }

    // MARK: - Tarjeta hero

    private func heroCard(title: String, subtitle: String, detail: String, icon: String, gradient: [Color], action: @escaping () -> Void) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            action()
        } label: {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.2))
                        .frame(width: 58, height: 58)
                    Image(systemName: icon)
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.9))
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(2)
                }

                Spacer(minLength: 4)

                Image(systemName: "chevron.right")
                    .font(.body.weight(.bold))
                    .foregroundStyle(.white.opacity(0.8))
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 22)
                    .fill(LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing))
                    .overlay {
                        RoundedRectangle(cornerRadius: 22)
                            .strokeBorder(.white.opacity(0.15), lineWidth: 1)
                    }
            }
            .shadow(color: gradient[0].opacity(0.3), radius: 12, y: 6)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title). \(subtitle)")
    }
}

#Preview {
    TrainingHubView()
        .environmentObject(UserWorkoutService())
        .preferredColorScheme(.dark)
}
