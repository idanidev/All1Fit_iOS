import SwiftUI

// MARK: - Heatmap Mensual de Entrenamientos
/// Calendario de un mes con intensidad por volumen entrenado cada día.
struct GymHeatmapView: View {
    let sessions: [GymSession]

    @State private var monthOffset = 0

    private var calendar: Calendar {
        var c = Calendar.current
        c.firstWeekday = 2 // lunes
        return c
    }

    private var displayedMonth: Date {
        calendar.date(byAdding: .month, value: monthOffset, to: Date()) ?? Date()
    }

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "LLLL yyyy"
        formatter.locale = Locale(identifier: "es_ES")
        return formatter.string(from: displayedMonth).capitalized
    }

    /// Volumen por día del mes mostrado
    private var volumeByDay: [Int: Double] {
        guard let interval = calendar.dateInterval(of: .month, for: displayedMonth) else { return [:] }
        var result: [Int: Double] = [:]
        for session in sessions where interval.contains(session.startDate) {
            let day = calendar.component(.day, from: session.startDate)
            result[day, default: 0] += session.totalVolume
        }
        return result
    }

    private var maxDayVolume: Double {
        volumeByDay.values.max() ?? 1
    }

    /// Celdas: nil = hueco antes del día 1
    private var cells: [Int?] {
        guard let interval = calendar.dateInterval(of: .month, for: displayedMonth),
              let dayCount = calendar.range(of: .day, in: .month, for: displayedMonth)?.count else { return [] }
        let firstWeekday = calendar.component(.weekday, from: interval.start)
        // Índice 0 = lunes
        let leading = (firstWeekday - calendar.firstWeekday + 7) % 7
        return Array(repeating: nil, count: leading) + (1...dayCount).map { $0 }
    }

    private let weekdaySymbols = ["L", "M", "X", "J", "V", "S", "D"]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Calendario", systemImage: "calendar")
                    .font(.headline)

                Spacer()

                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { monthOffset -= 1 }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Color.all1FitBlue)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Mes anterior")

                Text(monthTitle)
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .frame(minWidth: 110)

                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { monthOffset += 1 }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(monthOffset >= 0 ? Color.secondary : Color.all1FitBlue)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(monthOffset >= 0)
                .accessibilityLabel("Mes siguiente")
            }

            // Cabecera de días
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                }

                ForEach(Array(cells.enumerated()), id: \.offset) { _, day in
                    if let day {
                        dayCell(day)
                    } else {
                        Color.clear.frame(height: 34)
                    }
                }
            }

            // Leyenda
            HStack(spacing: 6) {
                Text("Menos")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
                ForEach([0.0, 0.25, 0.5, 0.75, 1.0], id: \.self) { intensity in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(cellColor(intensity: intensity))
                        .frame(width: 14, height: 14)
                }
                Text("Más")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func dayCell(_ day: Int) -> some View {
        let volume = volumeByDay[day] ?? 0
        let intensity = maxDayVolume > 0 ? volume / maxDayVolume : 0
        let isToday = monthOffset == 0 && calendar.component(.day, from: Date()) == day

        return RoundedRectangle(cornerRadius: 8)
            .fill(cellColor(intensity: volume > 0 ? max(0.25, intensity) : 0))
            .frame(height: 34)
            .overlay {
                Text("\(day)")
                    .font(.system(size: 11, weight: volume > 0 ? .bold : .regular, design: .rounded))
                    .foregroundStyle(volume > 0 ? .white : .secondary)
            }
            .overlay {
                if isToday {
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.all1FitCyan, lineWidth: 1.5)
                }
            }
    }

    private func cellColor(intensity: Double) -> Color {
        intensity == 0
            ? Color(uiColor: .tertiarySystemGroupedBackground)
            : Color.all1FitBlue.opacity(0.25 + 0.75 * intensity)
    }
}
