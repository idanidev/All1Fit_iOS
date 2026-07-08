import SwiftUI

// MARK: - Resumen Final de Entrenamiento
/// Se muestra al terminar la sesión: totales, mejores series y PRs conseguidos.
struct WorkoutSummaryView: View {
    let session: GymSession
    /// Nombres de ejercicios donde se ha batido el récord de peso
    let prExercises: [String]
    /// Ejercicios cuyo RM de la sección RMs se actualizó con el 1RM estimado de hoy
    var rmUpdates: [String] = []
    let weightUnit: WeightUnit
    let onClose: () -> Void

    @State private var appeared = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    heroCheck

                    summaryGrid

                    if !prExercises.isEmpty {
                        prSection
                    }

                    if !rmUpdates.isEmpty {
                        rmUpdatesSection
                    }

                    exercisesSection

                    closeButton
                }
                .padding(20)
            }
            .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("¡Entreno completado!")
            .navigationBarTitleDisplayMode(.inline)
        }
        .interactiveDismissDisabled()
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.2)) {
                appeared = true
            }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }

    // MARK: - Hero

    private var heroCheck: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [.all1FitSuccess.opacity(0.35), .clear], center: .center, startRadius: 0, endRadius: 80))
                .frame(width: 160, height: 160)
                .blur(radius: 30)

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(
                    LinearGradient(colors: [.all1FitSuccess, .teal], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .scaleEffect(appeared ? 1 : 0.3)
                .opacity(appeared ? 1 : 0)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    // MARK: - Totales

    private var summaryGrid: some View {
        HStack(spacing: 10) {
            summaryPill(value: session.durationFormatted, label: "duración", icon: "clock.fill")
            summaryPill(value: formatVolume(session.totalVolume), label: "volumen", icon: "scalemass.fill")
            summaryPill(value: "\(session.totalCompletedSets)", label: "series", icon: "checkmark.circle.fill")
        }
    }

    private func summaryPill(value: String, label: String, icon: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.all1FitBlue)
            Text(value)
                .font(.system(size: 24, weight: .black, design: .rounded))
                .foregroundStyle(
                    LinearGradient(colors: [.all1FitBlue, .all1FitCyan], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - PRs

    private var prSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Nuevos récords", systemImage: "trophy.fill")
                .font(.headline)
                .foregroundStyle(.yellow)

            VStack(spacing: 8) {
                ForEach(prExercises, id: \.self) { name in
                    HStack(spacing: 12) {
                        Image(systemName: "trophy.fill")
                            .font(.subheadline)
                            .foregroundStyle(.yellow)
                        Text(name)
                            .font(.system(.subheadline, design: .rounded, weight: .bold))
                        Spacer()
                        Text("PR")
                            .font(.system(.caption2, design: .rounded, weight: .black))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(.yellow, in: Capsule())
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.yellow.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - RMs actualizados

    private var rmUpdatesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("RMs actualizados", systemImage: "arrow.up.circle.fill")
                .font(.headline)
                .foregroundStyle(Color.all1FitOrange)

            VStack(spacing: 8) {
                ForEach(rmUpdates, id: \.self) { name in
                    HStack(spacing: 12) {
                        Image(systemName: "figure.strengthtraining.traditional")
                            .font(.subheadline)
                            .foregroundStyle(Color.all1FitOrange)
                        Text(name)
                            .font(.system(.subheadline, design: .rounded, weight: .bold))
                        Spacer()
                        Text("Nuevo RM")
                            .font(.system(.caption2, design: .rounded, weight: .black))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(
                                LinearGradient(colors: [.all1FitOrange, .all1FitRed], startPoint: .leading, endPoint: .trailing),
                                in: Capsule()
                            )
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.all1FitOrange.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                }
            }

            Text("Tu sección de RMs se ha actualizado con el 1RM estimado de hoy")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Ejercicios

    private var exercisesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Ejercicios", systemImage: "list.bullet")
                .font(.headline)

            VStack(spacing: 8) {
                ForEach(session.exercises) { log in
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(log.exerciseName)
                                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                                .lineLimit(1)
                            Text("\(log.workingSets.count) series efectivas")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if let best = log.bestSet {
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("\(formatWeight(best.weight))×\(best.reps)")
                                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                                    .foregroundStyle(Color.all1FitCyan)
                                if let rm = log.bestEstimated1RM {
                                    Text("1RM est. \(formatWeight(rm)) \(weightUnit.symbol)")
                                        .font(.system(size: 9))
                                        .foregroundStyle(.tertiary)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var closeButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            onClose()
        } label: {
            Text("Hecho")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(
                    LinearGradient(colors: [.all1FitBlue, .all1FitCyan], startPoint: .leading, endPoint: .trailing),
                    in: RoundedRectangle(cornerRadius: 14)
                )
                .shadow(color: .all1FitBlue.opacity(0.3), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private func formatWeight(_ value: Double) -> String {
        let converted = weightUnit.convert(value)
        return converted.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(converted))" : String(format: "%.1f", converted)
    }

    private func formatVolume(_ volume: Double) -> String {
        let converted = weightUnit.convert(volume)
        if converted >= 1000 {
            return String(format: "%.1fk", converted / 1000)
        }
        return "\(Int(converted))"
    }
}
