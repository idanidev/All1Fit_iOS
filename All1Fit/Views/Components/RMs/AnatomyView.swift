import SwiftUI

/// Vista de anatomía minimalista - versión simple sin Canvas
struct AnatomyView: View {
    let muscleGroup: MuscleGroup

    var body: some View {
        ZStack {
            // Estructura base
            StructureShape()
                .stroke(Color.white.opacity(0.4), lineWidth: 2)

            // Músculo iluminado
            MuscleShape(muscleGroup: muscleGroup)
                .fill(muscleGroup.color.opacity(0.7))
        }
    }
}

// MARK: - Estructura Base
struct StructureShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let scale = min(rect.width / 200, rect.height / 400)

        // Cabeza
        path.addEllipse(in: CGRect(x: 75 * scale, y: 15 * scale, width: 50 * scale, height: 50 * scale))

        // Cuello
        path.addRect(CGRect(x: 90 * scale, y: 65 * scale, width: 20 * scale, height: 15 * scale))

        // Torso
        path.addRect(CGRect(x: 70 * scale, y: 80 * scale, width: 60 * scale, height: 80 * scale))

        // Brazos
        path.move(to: CGPoint(x: 70 * scale, y: 95 * scale))
        path.addLine(to: CGPoint(x: 50 * scale, y: 160 * scale))

        path.move(to: CGPoint(x: 130 * scale, y: 95 * scale))
        path.addLine(to: CGPoint(x: 150 * scale, y: 160 * scale))

        // Piernas
        path.move(to: CGPoint(x: 85 * scale, y: 160 * scale))
        path.addLine(to: CGPoint(x: 85 * scale, y: 250 * scale))

        path.move(to: CGPoint(x: 115 * scale, y: 160 * scale))
        path.addLine(to: CGPoint(x: 115 * scale, y: 250 * scale))

        return path
    }
}

// MARK: - Capa de Músculos
struct MuscleShape: Shape {
    let muscleGroup: MuscleGroup

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let scale = min(rect.width / 200, rect.height / 400)

        switch muscleGroup {
        case .chest:
            // Pectorales
            path.move(to: CGPoint(x: 75 * scale, y: 85 * scale))
            path.addLine(to: CGPoint(x: 125 * scale, y: 85 * scale))
            path.addLine(to: CGPoint(x: 115 * scale, y: 125 * scale))
            path.addLine(to: CGPoint(x: 85 * scale, y: 125 * scale))
            path.closeSubpath()

        case .back:
            // Espalda
            path.addRect(CGRect(x: 75 * scale, y: 85 * scale, width: 50 * scale, height: 70 * scale))

        case .shoulders:
            // Hombros
            path.addEllipse(in: CGRect(x: 52 * scale, y: 77 * scale, width: 36 * scale, height: 36 * scale))
            path.addEllipse(in: CGRect(x: 112 * scale, y: 77 * scale, width: 36 * scale, height: 36 * scale))

        case .arms:
            // Bíceps
            path.addEllipse(in: CGRect(x: 48 * scale, y: 100 * scale, width: 20 * scale, height: 40 * scale))
            path.addEllipse(in: CGRect(x: 132 * scale, y: 100 * scale, width: 20 * scale, height: 40 * scale))

        case .abs:
            // Abdominales
            let abdRects = [
                CGRect(x: 86 * scale, y: 125 * scale, width: 13 * scale, height: 15 * scale),
                CGRect(x: 101 * scale, y: 125 * scale, width: 13 * scale, height: 15 * scale),
                CGRect(x: 86 * scale, y: 142 * scale, width: 13 * scale, height: 15 * scale),
                CGRect(x: 101 * scale, y: 142 * scale, width: 13 * scale, height: 15 * scale),
            ]

            for rect in abdRects {
                path.addRoundedRect(in: rect, cornerSize: CGSize(width: 2 * scale, height: 2 * scale))
            }

        case .legs:
            // Cuádriceps
            path.addRoundedRect(
                in: CGRect(x: 75 * scale, y: 165 * scale, width: 20 * scale, height: 70 * scale),
                cornerSize: CGSize(width: 4 * scale, height: 4 * scale)
            )
            path.addRoundedRect(
                in: CGRect(x: 105 * scale, y: 165 * scale, width: 20 * scale, height: 70 * scale),
                cornerSize: CGSize(width: 4 * scale, height: 4 * scale)
            )

        case .none:
            break
        }

        return path
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()

        VStack(spacing: 20) {
            HStack(spacing: 20) {
                VStack {
                    Text("Pecho").foregroundStyle(.white).font(.caption)
                    AnatomyView(muscleGroup: .chest)
                        .frame(width: 80, height: 160)
                }

                VStack {
                    Text("Piernas").foregroundStyle(.white).font(.caption)
                    AnatomyView(muscleGroup: .legs)
                        .frame(width: 80, height: 160)
                }

                VStack {
                    Text("Brazos").foregroundStyle(.white).font(.caption)
                    AnatomyView(muscleGroup: .arms)
                        .frame(width: 80, height: 160)
                }
            }
        }
    }
}
