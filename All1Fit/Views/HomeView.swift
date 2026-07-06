import SwiftUI

// MARK: - Home / Dashboard View
struct HomeView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var ejercicioService = EjercicioService()
    @Binding var selectedTab: Int
    @AppStorage("weightUnit") private var weightUnit: WeightUnit = .kg

    // MARK: - Computed

    private var firstName: String {
        authService.user?.displayName?.components(separatedBy: " ").first ?? "Atleta"
    }

    private var totalEjercicios: Int { ejercicioService.ejercicios.count }

    private var totalRegistros: Int {
        ejercicioService.ejercicios.reduce(0) { $0 + $1.rmHistory.count }
    }

    private var topEjercicios: [Ejercicio] {
        ejercicioService.ejercicios
            .filter { $0.ultimoRM != nil }
            .sorted { ($0.ultimoRM?.valor ?? 0) > ($1.ultimoRM?.valor ?? 0) }
            .prefix(4)
            .map { $0 }
    }

    private var ultimaFecha: String {
        let all = ejercicioService.ejercicios.compactMap { $0.ultimoRM?.fecha }
        guard let last = all.max() else { return "—" }
        let days = Calendar.current.dateComponents([.day], from: last, to: Date()).day ?? 0
        if days == 0 { return "Hoy" }
        if days == 1 { return "Ayer" }
        return "Hace \(days)d"
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    headerSection

                    if ejercicioService.isLoading && ejercicioService.ejercicios.isEmpty {
                        loadingSection
                    } else if ejercicioService.ejercicios.isEmpty {
                        emptySection
                    } else {
                        statsRow
                        if !topEjercicios.isEmpty {
                            topRMsSection
                        }
                    }

                    quickActionsSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
        }
        .task { await ejercicioService.fetchEjercicios() }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(alignment: .center, spacing: 14) {
            avatarView
                .frame(width: 54, height: 54)
                .clipShape(Circle())
                .overlay(
                    Circle().stroke(
                        LinearGradient(colors: [.orange, .red], startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: 2
                    )
                )

            VStack(alignment: .leading, spacing: 2) {
                Text("Hola, \(firstName)")
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundStyle(.primary)
                Text(Date(), format: .dateTime.weekday(.wide).day().month())
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.top, 4)
    }

    @ViewBuilder
    private var avatarView: some View {
        if let photoURL = authService.user?.photoURL {
            CachedAsyncImage(url: photoURL) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                appLogoPlaceholder
            }
        } else {
            appLogoPlaceholder
        }
    }

    private var appLogoPlaceholder: some View {
        Image("AppIcon")
            .resizable()
            .scaledToFill()
            .background(
                LinearGradient(colors: [.orange, .red], startPoint: .topLeading, endPoint: .bottomTrailing)
            )
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: 10) {
            StatPillView(
                value: "\(totalEjercicios)",
                label: "ejercicios",
                icon: "dumbbell.fill",
                gradient: [.orange, .red]
            )
            StatPillView(
                value: "\(totalRegistros)",
                label: "registros",
                icon: "list.bullet.clipboard.fill",
                gradient: [.purple, .pink]
            )
            StatPillView(
                value: ultimaFecha,
                label: "último",
                icon: "clock.fill",
                gradient: [.blue, .cyan]
            )
        }
    }

    // MARK: - Top RMs

    private var topRMsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                sectionTitle("Mejores RMs", color: .orange)
                Spacer()
                Button { selectedTab = 1 } label: {
                    HStack(spacing: 4) {
                        Text("Ver todos")
                            .font(.subheadline.weight(.semibold))
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                    }
                    .foregroundStyle(.orange)
                }
            }

            VStack(spacing: 10) {
                ForEach(topEjercicios) { ejercicio in
                    TopRMCard(ejercicio: ejercicio, weightUnit: weightUnit)
                }
            }
        }
    }

    // MARK: - Quick Actions

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("Accesos rápidos", color: .secondary)

            HStack(spacing: 10) {
                QuickActionButton(
                    icon: "dumbbell.fill",
                    label: "Gym",
                    gradient: [.blue, .cyan]
                ) { selectedTab = 3 }

                QuickActionButton(
                    icon: "figure.strengthtraining.traditional",
                    label: "RMs",
                    gradient: [.orange, .red]
                ) { selectedTab = 1 }

                QuickActionButton(
                    icon: "figure.run",
                    label: "Entrenos",
                    gradient: [.purple, .pink]
                ) { selectedTab = 2 }

                QuickActionButton(
                    icon: "timer",
                    label: "Tabata",
                    gradient: [.blue, .cyan]
                ) {
                    selectedTab = 2
                    NotificationCenter.default.post(name: .openTabatasSection, object: nil)
                }
            }
        }
    }

    // MARK: - Section Title Helper

    private func sectionTitle(_ text: String, color: Color) -> some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2)
                .fill(LinearGradient(colors: [color, color.opacity(0.5)], startPoint: .top, endPoint: .bottom))
                .frame(width: 3, height: 18)
            Text(text)
                .font(.system(size: 18, weight: .bold, design: .rounded))
        }
    }

    // MARK: - Loading / Empty

    private var loadingSection: some View {
        VStack(spacing: 12) {
            ForEach(0..<3, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
                    .frame(height: 72)
                    .shimmer()
            }
        }
    }

    private var emptySection: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [.orange.opacity(0.25), .clear], center: .center, startRadius: 0, endRadius: 70))
                    .frame(width: 140, height: 140)
                Image(systemName: "dumbbell.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(LinearGradient(colors: [.orange, .red], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .symbolEffect(.pulse.wholeSymbol, options: .repeating)
            }

            VStack(spacing: 6) {
                Text("Sin ejercicios aún")
                    .font(.title3.bold())
                Text("Añade tu primer RM para empezar")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Button { selectedTab = 1 } label: {
                Text("Añadir primer RM")
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(colors: [.orange, .red], startPoint: .leading, endPoint: .trailing),
                        in: Capsule()
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 32)
    }
}

// MARK: - Stat Pill

struct StatPillView: View {
    let value: String
    let label: String
    let icon: String
    let gradient: [Color]

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(gradient[0])

            Text(value)
                .font(.system(size: 26, weight: .black, design: .rounded))
                .foregroundStyle(
                    LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                .overlay {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(gradient[0].opacity(0.07))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(.white.opacity(0.07), lineWidth: 1)
                }
        }
    }
}

// MARK: - Top RM Card

struct TopRMCard: View {
    let ejercicio: Ejercicio
    let weightUnit: WeightUnit

    private var rm: Double { ejercicio.ultimoRM?.valor ?? 0 }

    private var trend: String? {
        guard ejercicio.rmHistory.count >= 2 else { return nil }
        let sorted = ejercicio.rmHistory.sorted { $0.fecha < $1.fecha }
        let prev = sorted.dropLast().last?.valor ?? 0
        return rm > prev ? "arrow.up.right" : rm < prev ? "arrow.down.right" : nil
    }

    private var isUp: Bool {
        guard ejercicio.rmHistory.count >= 2 else { return false }
        let sorted = ejercicio.rmHistory.sorted { $0.fecha < $1.fecha }
        return rm > (sorted.dropLast().last?.valor ?? rm)
    }

    private func fmt(_ v: Double) -> String {
        v.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(v))" : String(format: "%.1f", v)
    }

    var body: some View {
        HStack(spacing: 14) {
            // Exercise icon with style gradient
            Image(systemName: ejercicio.icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(colors: ejercicio.style.gradient, startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .frame(width: 42, height: 42)
                .background(ejercicio.style.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 11))

            VStack(alignment: .leading, spacing: 3) {
                Text(ejercicio.name)
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .lineLimit(1)
                    .foregroundStyle(.primary)
                Text("\(ejercicio.rmHistory.count) registros")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 4)

            if let t = trend {
                Image(systemName: t)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(isUp ? .green : .red)
            }

            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(fmt(weightUnit.convert(rm)))
                    .font(.system(size: 32, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(colors: ejercicio.style.gradient, startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .contentTransition(.numericText())
                Text(weightUnit.symbol)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                .overlay {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(ejercicio.style.color.opacity(0.06))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(.white.opacity(0.07), lineWidth: 1)
                }
        }
    }
}

// MARK: - Quick Action Button

struct QuickActionButton: View {
    let icon: String
    let label: String
    let gradient: [Color]
    let action: () -> Void

    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            action()
        }) {
            VStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(.white)

                Text(label)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.9))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 22)
            .background {
                RoundedRectangle(cornerRadius: 18)
                    .fill(
                        LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 18)
                            .strokeBorder(.white.opacity(0.15), lineWidth: 1)
                    }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Shimmer modifier

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = -1

    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: phase - 0.3),
                        .init(color: .white.opacity(0.15), location: phase),
                        .init(color: .clear, location: phase + 0.3)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .onAppear {
                withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                    phase = 1.5
                }
            }
    }
}

extension View {
    func shimmer() -> some View { modifier(ShimmerModifier()) }
}

#Preview {
    HomeView(selectedTab: .constant(0))
        .environmentObject(AuthService())
}
