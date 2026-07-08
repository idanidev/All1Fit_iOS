import SwiftUI

// MARK: - Home / Dashboard
/// Panel principal: racha y semana de entrenamiento, sesión activa,
/// próximo entreno sugerido, actividad reciente, mejores RMs y accesos rápidos.
struct HomeView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var ejercicioService = EjercicioService()
    @StateObject private var routineService = GymRoutineService()
    /// Compartido con MainTabView (sesión activa, historial, racha)
    @ObservedObject var gymSessionService: GymSessionService
    @Binding var selectedTab: Int
    @AppStorage("weightUnit") private var weightUnit: WeightUnit = .kg

    // MARK: - Computed (usuario)

    private var firstName: String {
        authService.user?.displayName?.components(separatedBy: " ").first ?? "Atleta"
    }

    private var topEjercicios: [Ejercicio] {
        ejercicioService.ejercicios
            .filter { $0.ultimoRM != nil }
            .sorted { ($0.ultimoRM?.valor ?? 0) > ($1.ultimoRM?.valor ?? 0) }
            .prefix(3)
            .map { $0 }
    }

    // MARK: - Computed (gym)

    private var weekCalendar: Calendar {
        var c = Calendar.current
        c.firstWeekday = 2 // lunes
        return c
    }

    private var thisWeekSessions: [GymSession] {
        guard let weekStart = weekCalendar.dateInterval(of: .weekOfYear, for: Date())?.start else { return [] }
        return gymSessionService.sessions.filter { $0.startDate >= weekStart }
    }

    private var weekVolume: Double {
        thisWeekSessions.reduce(0) { $0 + $1.totalVolume }
    }

    private var weekSets: Int {
        thisWeekSessions.reduce(0) { $0 + $1.totalCompletedSets }
    }

    /// Índices 0=lunes … 6=domingo de los días entrenados esta semana
    private var trainedWeekdayIndexes: Set<Int> {
        Set(thisWeekSessions.map { mondayIndex(of: $0.startDate) })
    }

    private var todayIndex: Int { mondayIndex(of: Date()) }

    private func mondayIndex(of date: Date) -> Int {
        (Calendar.current.component(.weekday, from: date) + 5) % 7
    }

    private var recentSessions: [GymSession] {
        Array(gymSessionService.sessions.prefix(3))
    }

    /// Rutina sugerida: la que lleva más tiempo sin entrenarse (nunca entrenada primero)
    private var nextRoutine: GymRoutine? {
        guard !routineService.routines.isEmpty else { return nil }
        var lastTrained: [String: Date] = [:]
        for session in gymSessionService.sessions where lastTrained[session.routineName] == nil {
            lastTrained[session.routineName] = session.startDate   // sessions viene descendente
        }
        return routineService.routines.min { a, b in
            (lastTrained[a.name] ?? .distantPast) < (lastTrained[b.name] ?? .distantPast)
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    headerSection

                    if gymSessionService.activeSession != nil {
                        activeSessionBanner
                    }

                    weekHeroCard
                    nextWorkoutSection

                    if !recentSessions.isEmpty {
                        recentActivitySection
                    }

                    if !topEjercicios.isEmpty {
                        topRMsSection
                    } else if ejercicioService.isLoading && ejercicioService.ejercicios.isEmpty {
                        loadingSection
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
        .task {
            await ejercicioService.fetchEjercicios()
            await gymSessionService.fetchSessions()
            await routineService.fetchRoutines()
        }
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

            if gymSessionService.weekStreak > 0 {
                streakChip
            }
        }
        .padding(.top, 4)
    }

    private var streakChip: some View {
        HStack(spacing: 4) {
            Image(systemName: "flame.fill")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(
                    LinearGradient(colors: [.all1FitOrange, .yellow], startPoint: .top, endPoint: .bottom)
                )
            Text("\(gymSessionService.weekStreak)")
                .font(.system(size: 17, weight: .black, design: .rounded))
                .foregroundStyle(.primary)
                .contentTransition(.numericText())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background {
            Capsule()
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                .overlay {
                    Capsule().strokeBorder(Color.all1FitOrange.opacity(0.4), lineWidth: 1)
                }
        }
        .accessibilityLabel("Racha de \(gymSessionService.weekStreak) semanas entrenando")
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

    // MARK: - Sesión activa

    private var activeSessionBanner: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            NotificationCenter.default.post(name: .openActiveGymSession, object: nil)
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.2))
                        .frame(width: 44, height: 44)
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Sesión en curso")
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .foregroundStyle(.white)
                    Text(gymSessionService.activeSession?.routineName ?? "")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(1)
                }

                Spacer()

                Text("Continuar")
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.white.opacity(0.2), in: Capsule())
            }
            .padding()
            .background(
                LinearGradient(colors: [.all1FitBlue, .all1FitCyan], startPoint: .topLeading, endPoint: .bottomTrailing),
                in: RoundedRectangle(cornerRadius: 18)
            )
            .shadow(color: .all1FitBlue.opacity(0.3), radius: 12, y: 6)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Tu semana

    private let weekdaySymbols = ["L", "M", "X", "J", "V", "S", "D"]

    private var weekHeroCard: some View {
        VStack(spacing: 16) {
            HStack {
                sectionTitle("Tu semana", color: .all1FitBlue)
                Spacer()
                Button {
                    selectedTab = 3
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    HStack(spacing: 4) {
                        Text("Progreso")
                            .font(.subheadline.weight(.semibold))
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                    }
                    .foregroundStyle(Color.all1FitBlue)
                }
                .buttonStyle(.plain)
            }

            // Días de la semana con marca de entrenado
            HStack(spacing: 8) {
                ForEach(0..<7, id: \.self) { index in
                    dayDot(index: index)
                }
            }

            // Mini stats
            HStack(spacing: 10) {
                weekStat(value: "\(thisWeekSessions.count)", label: "sesiones")
                weekStat(value: formatVolume(weekVolume), label: "volumen")
                weekStat(value: "\(weekSets)", label: "series")
            }
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                .overlay {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.all1FitBlue.opacity(0.06))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(
                            LinearGradient(colors: [.all1FitBlue.opacity(0.4), .all1FitCyan.opacity(0.15)], startPoint: .topLeading, endPoint: .bottomTrailing),
                            lineWidth: 1
                        )
                }
        }
    }

    private func dayDot(index: Int) -> some View {
        let trained = trainedWeekdayIndexes.contains(index)
        let isToday = index == todayIndex

        return VStack(spacing: 6) {
            Text(weekdaySymbols[index])
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(isToday ? Color.all1FitCyan : .secondary)

            ZStack {
                Circle()
                    .fill(trained
                          ? AnyShapeStyle(LinearGradient(colors: [.all1FitBlue, .all1FitCyan], startPoint: .top, endPoint: .bottom))
                          : AnyShapeStyle(Color(uiColor: .tertiarySystemGroupedBackground)))
                    .frame(width: 30, height: 30)

                if trained {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .black))
                        .foregroundStyle(.white)
                }
            }
            .overlay {
                if isToday {
                    Circle().strokeBorder(Color.all1FitCyan, lineWidth: 1.5)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityLabel("\(weekdaySymbols[index]): \(trained ? "entrenado" : "sin entrenar")")
    }

    private func weekStat(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(
                    LinearGradient(colors: [.all1FitBlue, .all1FitCyan], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .contentTransition(.numericText())
            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Próximo entreno

    @ViewBuilder
    private var nextWorkoutSection: some View {
        if let routine = nextRoutine {
            VStack(alignment: .leading, spacing: 14) {
                sectionTitle("Próximo entreno", color: .all1FitCyan)

                HStack(spacing: 14) {
                    Image(systemName: "dumbbell.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(colors: [.all1FitBlue, .all1FitCyan], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .frame(width: 46, height: 46)
                        .background(Color.all1FitBlue.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))

                    VStack(alignment: .leading, spacing: 3) {
                        Text(routine.name)
                            .font(.system(.body, design: .rounded, weight: .bold))
                            .lineLimit(1)
                        HStack(spacing: 6) {
                            if let folder = routine.folder {
                                Text(folder)
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(Color.all1FitBlue)
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 2)
                                    .background(Color.all1FitBlue.opacity(0.12), in: Capsule())
                            }
                            Text("\(routine.exercises.count) ejercicios · \(routine.totalSets) series")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer(minLength: 8)

                    Button {
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                        gymSessionService.startSession(from: routine)
                    } label: {
                        Image(systemName: "play.fill")
                            .font(.body.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(
                                LinearGradient(colors: [.all1FitBlue, .all1FitCyan], startPoint: .topLeading, endPoint: .bottomTrailing),
                                in: Circle()
                            )
                            .shadow(color: .all1FitBlue.opacity(0.4), radius: 8, y: 4)
                    }
                    .buttonStyle(.plain)
                    .disabled(gymSessionService.activeSession != nil)
                    .opacity(gymSessionService.activeSession != nil ? 0.4 : 1)
                    .accessibilityLabel("Empezar \(routine.name)")
                }
                .padding()
                .background {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(uiColor: .secondarySystemGroupedBackground))
                        .overlay {
                            RoundedRectangle(cornerRadius: 16)
                                .strokeBorder(.white.opacity(0.07), lineWidth: 1)
                        }
                }
            }
        } else {
            Button {
                selectedTab = 3
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "wand.and.stars")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(.white.opacity(0.2), in: Circle())

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Crea tu plan a medida")
                            .font(.system(.subheadline, design: .rounded, weight: .bold))
                            .foregroundStyle(.white)
                        Text("4 preguntas y entrenas con base científica")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.85))
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.body.weight(.bold))
                        .foregroundStyle(.white.opacity(0.8))
                }
                .padding()
                .background(
                    LinearGradient(colors: [.all1FitBlue, .all1FitCyan], startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: 18)
                )
                .shadow(color: .all1FitBlue.opacity(0.3), radius: 12, y: 6)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Actividad reciente

    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                sectionTitle("Actividad reciente", color: .all1FitSuccess)
                Spacer()
                Button {
                    selectedTab = 3
                } label: {
                    HStack(spacing: 4) {
                        Text("Ver todo")
                            .font(.subheadline.weight(.semibold))
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                    }
                    .foregroundStyle(Color.all1FitSuccess)
                }
                .buttonStyle(.plain)
            }

            VStack(spacing: 10) {
                ForEach(recentSessions) { session in
                    recentSessionRow(session)
                }
            }
        }
    }

    private func recentSessionRow(_ session: GymSession) -> some View {
        HStack(spacing: 14) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(colors: [.all1FitSuccess, .teal], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .frame(width: 40, height: 40)
                .background(Color.all1FitSuccess.opacity(0.1), in: RoundedRectangle(cornerRadius: 11))

            VStack(alignment: .leading, spacing: 3) {
                Text(session.routineName)
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .lineLimit(1)
                Text("\(relativeDate(session.startDate)) · \(session.durationFormatted) · \(session.totalCompletedSets) series")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(formatVolume(session.totalVolume))
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(Color.all1FitCyan)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background {
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
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
                .buttonStyle(.plain)
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

    // MARK: - Helpers

    private func sectionTitle(_ text: String, color: Color) -> some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2)
                .fill(LinearGradient(colors: [color, color.opacity(0.5)], startPoint: .top, endPoint: .bottom))
                .frame(width: 3, height: 18)
            Text(text)
                .font(.system(size: 18, weight: .bold, design: .rounded))
        }
    }

    private func relativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func formatVolume(_ volume: Double) -> String {
        let converted = weightUnit.convert(volume)
        if converted >= 1000 {
            return String(format: "%.1fk", converted / 1000)
        }
        return "\(Int(converted))"
    }

    private var loadingSection: some View {
        VStack(spacing: 12) {
            ForEach(0..<2, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
                    .frame(height: 72)
                    .shimmer()
            }
        }
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
    HomeView(gymSessionService: GymSessionService(), selectedTab: .constant(0))
        .environmentObject(AuthService())
}
