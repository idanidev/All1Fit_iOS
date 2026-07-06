import SwiftUI

// MARK: - Gym Hub
/// Pantalla principal de la sección Gym: sesión activa, inicio rápido,
/// resumen semanal y acceso a Ejercicios, Rutinas, Progreso y Medidas.
struct GymHubView: View {
    /// Compartido con MainTabView (mini player y logger a pantalla completa)
    @ObservedObject var sessionService: GymSessionService
    @StateObject private var routineService = GymRoutineService()
    @StateObject private var measurementService = BodyMeasurementService()
    @AppStorage("weightUnit") private var weightUnit: WeightUnit = .kg
    @State private var showingPlanWizard = false

    // MARK: - Resumen semanal

    private var thisWeekSessions: [GymSession] {
        let calendar = Calendar.current
        guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: Date())?.start else { return [] }
        return sessionService.sessions.filter { $0.startDate >= weekStart }
    }

    private var weekVolume: Double {
        thisWeekSessions.reduce(0) { $0 + $1.totalVolume }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if sessionService.activeSession != nil {
                    activeSessionBanner
                }

                quickStartSection
                weekSummary
                modulesGrid
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Gym")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showingPlanWizard) {
            GymPlanWizardView(routineService: routineService)
        }
        .task {
            await sessionService.fetchSessions()
            await routineService.fetchRoutines()
            await measurementService.fetchMeasurements()
        }
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
                    Text(sessionService.activeSession?.routineName ?? "")
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

    // MARK: - Inicio rápido

    private var quickStartSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("Entrenar")

            HStack(spacing: 10) {
                Button {
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    sessionService.startSession(from: nil)
                    // MainTabView abre el logger al detectar la sesión nueva
                } label: {
                    VStack(spacing: 10) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundStyle(.white)
                        Text("Entreno libre")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white.opacity(0.9))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 22)
                    .background {
                        RoundedRectangle(cornerRadius: 18)
                            .fill(
                                LinearGradient(colors: [.all1FitBlue, .all1FitCyan], startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                            .overlay {
                                RoundedRectangle(cornerRadius: 18)
                                    .strokeBorder(.white.opacity(0.15), lineWidth: 1)
                            }
                    }
                }
                .buttonStyle(.plain)
                .disabled(sessionService.activeSession != nil)
                .opacity(sessionService.activeSession != nil ? 0.5 : 1)

                NavigationLink {
                    RoutineListView(routineService: routineService, sessionService: sessionService)
                } label: {
                    VStack(spacing: 10) {
                        Image(systemName: "list.clipboard.fill")
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundStyle(Color.all1FitBlue)
                        Text("Desde rutina")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.primary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 22)
                    .background {
                        RoundedRectangle(cornerRadius: 18)
                            .fill(Color(uiColor: .secondarySystemGroupedBackground))
                            .overlay {
                                RoundedRectangle(cornerRadius: 18)
                                    .strokeBorder(.white.opacity(0.1), lineWidth: 1)
                            }
                    }
                }
                .buttonStyle(.plain)
            }

            // Asistente de plan a medida
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                showingPlanWizard = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "wand.and.stars")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(
                            LinearGradient(colors: [.all1FitBlue, .all1FitCyan], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .frame(width: 40, height: 40)
                        .background(Color.all1FitBlue.opacity(0.12), in: RoundedRectangle(cornerRadius: 11))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Plan a medida")
                            .font(.system(.subheadline, design: .rounded, weight: .bold))
                            .foregroundStyle(.primary)
                        Text("4 preguntas y te montamos el programa")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(14)
                .background {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(uiColor: .secondarySystemGroupedBackground))
                        .overlay {
                            RoundedRectangle(cornerRadius: 16)
                                .strokeBorder(
                                    LinearGradient(colors: [.all1FitBlue.opacity(0.5), .all1FitCyan.opacity(0.3)], startPoint: .leading, endPoint: .trailing),
                                    lineWidth: 1
                                )
                        }
                }
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Resumen semanal

    private var weekSummary: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("Esta semana")

            HStack(spacing: 10) {
                summaryPill(
                    value: "\(thisWeekSessions.count)",
                    label: "sesiones",
                    icon: "figure.strengthtraining.traditional"
                )
                summaryPill(
                    value: formatVolume(weekVolume),
                    label: "volumen",
                    icon: "scalemass.fill"
                )
                summaryPill(
                    value: "\(thisWeekSessions.reduce(0) { $0 + $1.totalCompletedSets })",
                    label: "series",
                    icon: "checkmark.circle.fill"
                )
            }
        }
    }

    private func summaryPill(value: String, label: String, icon: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.all1FitBlue)

            Text(value)
                .font(.system(size: 26, weight: .black, design: .rounded))
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
        .padding(.vertical, 16)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                .overlay {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.all1FitBlue.opacity(0.07))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(.white.opacity(0.07), lineWidth: 1)
                }
        }
    }

    // MARK: - Módulos

    private var modulesGrid: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("Explorar")

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                NavigationLink {
                    ExerciseLibraryView(sessionService: sessionService)
                } label: {
                    moduleCard(icon: "books.vertical.fill", title: "Ejercicios", subtitle: "\(GymExerciseCatalog.all.count) en catálogo")
                }
                .buttonStyle(.plain)

                NavigationLink {
                    RoutineListView(routineService: routineService, sessionService: sessionService)
                } label: {
                    moduleCard(icon: "list.clipboard.fill", title: "Rutinas", subtitle: routineService.routines.isEmpty ? "Crea la primera" : "\(routineService.routines.count) guardadas")
                }
                .buttonStyle(.plain)

                NavigationLink {
                    GymStatsView(sessionService: sessionService, measurementService: measurementService, initialTab: .progreso)
                } label: {
                    moduleCard(icon: "chart.bar.fill", title: "Progreso", subtitle: sessionService.sessions.isEmpty ? "Sin datos aún" : "\(sessionService.sessions.count) entrenos")
                }
                .buttonStyle(.plain)

                NavigationLink {
                    GymStatsView(sessionService: sessionService, measurementService: measurementService, initialTab: .medidas)
                } label: {
                    moduleCard(icon: "figure.arms.open", title: "Medidas", subtitle: measurementService.latestWeight.map { String(format: "%.1f kg", $0) } ?? "Registra tu peso")
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func moduleCard(icon: String, title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(colors: [.all1FitBlue, .all1FitCyan], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .frame(width: 44, height: 44)
                .background(Color.all1FitBlue.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(.body, design: .rounded, weight: .bold))
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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

    // MARK: - Helpers

    private func sectionTitle(_ text: String) -> some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2)
                .fill(LinearGradient(colors: [.all1FitBlue, .all1FitCyan.opacity(0.5)], startPoint: .top, endPoint: .bottom))
                .frame(width: 3, height: 18)
            Text(text)
                .font(.system(size: 18, weight: .bold, design: .rounded))
        }
    }

    private func formatVolume(_ volume: Double) -> String {
        let converted = weightUnit.convert(volume)
        if converted >= 1000 {
            return String(format: "%.1fk", converted / 1000)
        }
        return "\(Int(converted))"
    }
}

#Preview {
    NavigationStack {
        GymHubView(sessionService: GymSessionService())
    }
    .preferredColorScheme(.dark)
}
