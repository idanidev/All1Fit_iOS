import SwiftUI
import WatchKit

// MARK: - Sesión de Gym en el Watch
/// Espejo del logger del iPhone: marca series desde la muñeca.
/// El iPhone es la fuente de verdad; cada toggle se envía y vuelve confirmado.
struct GymSessionWatchView: View {
    @EnvironmentObject var connectivityService: WatchConnectivityService

    var body: some View {
        Group {
            if let session = connectivityService.activeGymSession {
                List {
                    // Cabecera: cronómetro + series
                    Section {
                        HStack {
                            TimelineView(.periodic(from: .now, by: 1)) { context in
                                Text(elapsed(since: session.startDate, now: context.date))
                                    .font(.system(.title3, design: .rounded, weight: .black))
                                    .foregroundStyle(.cyan)
                                    .monospacedDigit()
                            }
                            Spacer()
                            Text("\(session.totalCompletedSets) series")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .listRowBackground(Color.clear)

                        // Descanso en curso (espejado desde el iPhone)
                        if let restEnd = session.restEndDate, restEnd > Date() {
                            TimelineView(.periodic(from: .now, by: 0.5)) { context in
                                let remaining = max(0, restEnd.timeIntervalSince(context.date))
                                HStack(spacing: 6) {
                                    Image(systemName: "timer")
                                        .font(.caption.weight(.bold))
                                    Text("Descanso")
                                        .font(.caption2.weight(.semibold))
                                    Spacer()
                                    Text(String(format: "%d:%02d", Int(remaining) / 60, Int(remaining) % 60))
                                        .font(.system(.body, design: .rounded, weight: .black))
                                        .monospacedDigit()
                                        .contentTransition(.numericText())
                                }
                                .foregroundStyle(.black)
                                .onChange(of: remaining <= 0) { _, expired in
                                    if expired { WKInterfaceDevice.current().play(.notification) }
                                }
                            }
                            .listRowBackground(
                                LinearGradient(colors: [.blue, .cyan], startPoint: .leading, endPoint: .trailing)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            )
                            .accessibilityLabel("Descanso en curso")
                        }
                    }

                    // Ejercicios con sus series
                    ForEach(session.exercises) { exercise in
                        Section {
                            ForEach(Array(exercise.sets.enumerated()), id: \.element.id) { index, set in
                                Button {
                                    connectivityService.toggleGymSet(
                                        exerciseId: exercise.id,
                                        setId: set.id,
                                        completed: !set.completed
                                    )
                                } label: {
                                    HStack(spacing: 8) {
                                        Text(set.badge ?? "\(index + 1)")
                                            .font(.system(.caption, design: .rounded, weight: .bold))
                                            .foregroundStyle(set.badge != nil ? .yellow : .secondary)
                                            .frame(width: 18)

                                        Text(setLabel(set))
                                            .font(.system(.body, design: .rounded, weight: .semibold))

                                        Spacer()

                                        Image(systemName: set.completed ? "checkmark.circle.fill" : "circle")
                                            .foregroundStyle(set.completed ? .green : .secondary)
                                    }
                                }
                                .accessibilityLabel("\(exercise.exerciseName), serie \(index + 1), \(set.completed ? "completada" : "pendiente")")
                            }
                        } header: {
                            Text(exercise.exerciseName)
                                .font(.caption2.bold())
                                .foregroundStyle(.cyan)
                        }
                    }
                }
                .navigationTitle(session.routineName)
            } else {
                // La sesión terminó o se descartó desde el iPhone
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.largeTitle)
                        .foregroundStyle(.green)
                    Text("Sin entreno activo")
                        .font(.headline)
                    Text("Empieza una sesión de gym en el iPhone")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
        }
    }

    private func elapsed(since start: Date, now: Date) -> String {
        let total = Int(max(now.timeIntervalSince(start), 0))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%02d:%02d", m, s)
    }

    private func setLabel(_ set: WatchGymSet) -> String {
        let unit = connectivityService.weightUnit
        let converted = unit.convert(set.weight)
        let weightText = converted.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(converted))"
            : String(format: "%.1f", converted)
        return set.weight > 0 ? "\(weightText) \(unit.symbol) × \(set.reps)" : "× \(set.reps)"
    }
}

#Preview {
    NavigationStack {
        GymSessionWatchView()
            .environmentObject(WatchConnectivityService.shared)
    }
}
