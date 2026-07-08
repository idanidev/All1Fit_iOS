import SwiftUI

// MARK: - Mapa Muscular Vectorial
/// Dos siluetas (frontal y espalda) con cada músculo como forma propia.
/// Resalta el primario con el gradiente de la sección Gym y los secundarios
/// en azul suave. Sustituye a las fotos con marco: preciso, transparente y escalable.
struct MuscleMapView: View {
    let primary: BodyPart
    let secondary: [BodyPart]

    var body: some View {
        HStack(spacing: 24) {
            figure(front: true)
            figure(front: false)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Músculo principal: \(primary.rawValue)\(secondary.isEmpty ? "" : ". Secundarios: \(secondary.map(\.rawValue).joined(separator: ", "))")")
    }

    // MARK: - Estilos

    private var baseColor: Color {
        Color(uiColor: .tertiarySystemGroupedBackground)
    }

    private func fill(for muscle: BodyPart) -> AnyShapeStyle {
        if muscle == primary {
            return AnyShapeStyle(
                LinearGradient(colors: [.all1FitBlue, .all1FitCyan], startPoint: .top, endPoint: .bottom)
            )
        }
        if secondary.contains(muscle) {
            return AnyShapeStyle(Color.all1FitBlue.opacity(0.35))
        }
        return AnyShapeStyle(baseColor.opacity(0.9))
    }

    private func isHighlighted(_ muscle: BodyPart) -> Bool {
        muscle == primary || secondary.contains(muscle)
    }

    // MARK: - Figura (canvas fijo 150×300)

    private func figure(front: Bool) -> some View {
        ZStack {
            skeleton
            muscles(front: front)
        }
        .frame(width: 150, height: 300)
    }

    /// Cuerpo base: cabeza, torso, brazos y piernas en gris neutro
    private var skeleton: some View {
        ZStack {
            // Cabeza y cuello
            Circle().fill(baseColor).frame(width: 34, height: 34).position(x: 75, y: 26)
            Rectangle().fill(baseColor).frame(width: 14, height: 14).position(x: 75, y: 47)
            // Torso y pelvis
            RoundedRectangle(cornerRadius: 18).fill(baseColor).frame(width: 66, height: 96).position(x: 75, y: 105)
            RoundedRectangle(cornerRadius: 12).fill(baseColor).frame(width: 56, height: 30).position(x: 75, y: 155)
            // Brazos
            ForEach([-1.0, 1.0], id: \.self) { side in
                Capsule().fill(baseColor).frame(width: 16, height: 54)
                    .rotationEffect(.degrees(12 * side)).position(x: 75 + 47 * side, y: 93)
                Capsule().fill(baseColor).frame(width: 13, height: 50)
                    .rotationEffect(.degrees(8 * side)).position(x: 75 + 57 * side, y: 141)
            }
            // Piernas
            ForEach([-1.0, 1.0], id: \.self) { side in
                Capsule().fill(baseColor).frame(width: 24, height: 124).position(x: 75 + 16 * side, y: 230)
            }
        }
    }

    /// Formas musculares superpuestas según la vista
    @ViewBuilder
    private func muscles(front: Bool) -> some View {
        if front {
            // Hombros (deltoides frontal)
            muscleShape(.shoulders) { pair { side in
                Circle().frame(width: 22, height: 22).position(x: 75 + 37 * side, y: 70)
            } }
            // Pecho
            muscleShape(.chest) { pair { side in
                Ellipse().frame(width: 28, height: 22).position(x: 75 + 15 * side, y: 84)
            } }
            // Bíceps
            muscleShape(.biceps) { pair { side in
                Capsule().frame(width: 11, height: 30)
                    .rotationEffect(.degrees(12 * side)).position(x: 75 + 46 * side, y: 97)
            } }
            // Abdominales (2×3)
            muscleShape(.abs) {
                ForEach(0..<3, id: \.self) { row in
                    ForEach([-1.0, 1.0], id: \.self) { side in
                        RoundedRectangle(cornerRadius: 3)
                            .frame(width: 11, height: 12)
                            .position(x: 75 + 7 * side, y: 105 + CGFloat(row) * 15)
                    }
                }
            }
            // Cuádriceps
            muscleShape(.quads) { pair { side in
                Capsule().frame(width: 15, height: 54).position(x: 75 + 16 * side, y: 205)
            } }
        } else {
            // Trapecio
            muscleShape(.back) {
                Ellipse().frame(width: 32, height: 24).position(x: 75, y: 66)
            }
            // Dorsales / espalda media
            muscleShape(.back) {
                UnevenRoundedRectangle(topLeadingRadius: 6, bottomLeadingRadius: 20, bottomTrailingRadius: 20, topTrailingRadius: 6)
                    .frame(width: 54, height: 52)
                    .position(x: 75, y: 104)
            }
            // Hombros (deltoides posterior)
            muscleShape(.shoulders) { pair { side in
                Circle().frame(width: 22, height: 22).position(x: 75 + 37 * side, y: 70)
            } }
            // Tríceps
            muscleShape(.triceps) { pair { side in
                Capsule().frame(width: 11, height: 30)
                    .rotationEffect(.degrees(12 * side)).position(x: 75 + 46 * side, y: 97)
            } }
            // Glúteos
            muscleShape(.glutes) { pair { side in
                Ellipse().frame(width: 22, height: 24).position(x: 75 + 12 * side, y: 158)
            } }
            // Isquiotibiales
            muscleShape(.hamstrings) { pair { side in
                Capsule().frame(width: 15, height: 50).position(x: 75 + 16 * side, y: 207)
            } }
            // Gemelos
            muscleShape(.calves) { pair { side in
                Capsule().frame(width: 13, height: 36).position(x: 75 + 16 * side, y: 265)
            } }
        }
    }

    /// Aplica relleno según primario/secundario y un glow sutil al resaltado
    private func muscleShape<Content: View>(_ muscle: BodyPart, @ViewBuilder content: () -> Content) -> some View {
        content()
            .foregroundStyle(fill(for: muscle))
            .shadow(color: isHighlighted(muscle) ? .all1FitCyan.opacity(0.55) : .clear, radius: 5)
    }

    /// Par simétrico izquierda/derecha
    private func pair<Content: View>(@ViewBuilder _ content: @escaping (Double) -> Content) -> some View {
        ForEach([-1.0, 1.0], id: \.self) { side in
            content(side)
        }
    }
}

#Preview("Pecho") {
    MuscleMapView(primary: .chest, secondary: [.triceps, .shoulders])
        .padding()
        .background(Color.black)
}

#Preview("Femoral") {
    MuscleMapView(primary: .hamstrings, secondary: [.glutes])
        .padding()
        .background(Color.black)
}
