import SwiftUI

/// Vista de anatomía basada en el SVG minimalista
struct SVGAnatomyView: View {
    let muscleGroup: MuscleGroup

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let scale = min(size.width / 200, size.height / 400)

            Canvas { context, canvasSize in
                context.scaleBy(x: scale, y: scale)

                // Estructura base (siempre visible)
                drawBaseStructure(context: &context)

                // Músculos iluminados según el grupo
                drawMuscles(context: &context, highlighted: muscleGroup)
            }
        }
    }

    private func drawBaseStructure(context: inout GraphicsContext) {
        let baseColor = Color.white.opacity(0.2)

        // Head
        let head = Path(ellipseIn: CGRect(x: 75, y: 15, width: 50, height: 50))
        context.stroke(head, with: .color(baseColor), lineWidth: 1)

        // Neck
        let neck = Path(CGRect(x: 90, y: 65, width: 20, height: 15))
        context.stroke(neck, with: .color(baseColor), lineWidth: 1)

        // Hips
        var hipsPath = Path()
        hipsPath.move(to: CGPoint(x: 80, y: 205))
        hipsPath.addLine(to: CGPoint(x: 120, y: 205))
        hipsPath.addLine(to: CGPoint(x: 130, y: 230))
        hipsPath.addLine(to: CGPoint(x: 70, y: 230))
        hipsPath.closeSubpath()
        context.stroke(hipsPath, with: .color(baseColor), lineWidth: 1)
    }

    private func drawMuscles(context: inout GraphicsContext, highlighted: MuscleGroup) {
        let inactiveColor = Color.white.opacity(0.1)

        // Shoulders
        let leftShoulder = Path(ellipseIn: CGRect(x: 42, y: 77, width: 36, height: 36))
        let rightShoulder = Path(ellipseIn: CGRect(x: 122, y: 77, width: 36, height: 36))

        if highlighted == .shoulders {
            context.fill(leftShoulder, with: .color(highlighted.color.opacity(0.6)))
            context.fill(rightShoulder, with: .color(highlighted.color.opacity(0.6)))
        } else {
            context.fill(leftShoulder, with: .color(inactiveColor))
            context.fill(rightShoulder, with: .color(inactiveColor))
        }

        // Chest
        var chestPath = Path()
        chestPath.move(to: CGPoint(x: 75, y: 85))
        chestPath.addLine(to: CGPoint(x: 125, y: 85))
        chestPath.addLine(to: CGPoint(x: 115, y: 135))
        chestPath.addLine(to: CGPoint(x: 85, y: 135))
        chestPath.closeSubpath()

        if highlighted == .chest {
            context.fill(chestPath, with: .color(highlighted.color.opacity(0.6)))
        } else {
            context.fill(chestPath, with: .color(inactiveColor))
        }

        // Arms (Biceps)
        let leftBicep = Path(ellipseIn: CGRect(x: 48, y: 118, width: 24, height: 44))
        let rightBicep = Path(ellipseIn: CGRect(x: 128, y: 118, width: 24, height: 44))

        if highlighted == .arms {
            context.fill(leftBicep, with: .color(highlighted.color.opacity(0.6)))
            context.fill(rightBicep, with: .color(highlighted.color.opacity(0.6)))
        } else {
            context.fill(leftBicep, with: .color(inactiveColor))
            context.fill(rightBicep, with: .color(inactiveColor))
        }

        // Abs (6-pack)
        let absRects = [
            CGRect(x: 86, y: 140, width: 13, height: 18),
            CGRect(x: 101, y: 140, width: 13, height: 18),
            CGRect(x: 86, y: 160, width: 13, height: 18),
            CGRect(x: 101, y: 160, width: 13, height: 18),
            CGRect(x: 86, y: 180, width: 13, height: 18),
            CGRect(x: 101, y: 180, width: 13, height: 18),
        ]

        for rect in absRects {
            let absPath = Path(roundedRect: rect, cornerRadius: 2)
            if highlighted == .abs {
                context.fill(absPath, with: .color(highlighted.color.opacity(0.6)))
            } else {
                context.fill(absPath, with: .color(inactiveColor))
            }
        }

        // Legs (Quads)
        let leftQuad = Path(roundedRect: CGRect(x: 70, y: 235, width: 28, height: 85), cornerRadius: 6)
        let rightQuad = Path(roundedRect: CGRect(x: 102, y: 235, width: 28, height: 85), cornerRadius: 6)

        if highlighted == .legs {
            context.fill(leftQuad, with: .color(highlighted.color.opacity(0.6)))
            context.fill(rightQuad, with: .color(highlighted.color.opacity(0.6)))

            // Calves
            let leftCalf = Path(ellipseIn: CGRect(x: 72, y: 332, width: 24, height: 56))
            let rightCalf = Path(ellipseIn: CGRect(x: 104, y: 332, width: 24, height: 56))
            context.fill(leftCalf, with: .color(highlighted.color.opacity(0.6)))
            context.fill(rightCalf, with: .color(highlighted.color.opacity(0.6)))
        } else {
            context.fill(leftQuad, with: .color(inactiveColor))
            context.fill(rightQuad, with: .color(inactiveColor))

            let leftCalf = Path(ellipseIn: CGRect(x: 72, y: 332, width: 24, height: 56))
            let rightCalf = Path(ellipseIn: CGRect(x: 104, y: 332, width: 24, height: 56))
            context.fill(leftCalf, with: .color(inactiveColor))
            context.fill(rightCalf, with: .color(inactiveColor))
        }

        // Back (lines on the back)
        if highlighted == .back {
            var backPath = Path()
            backPath.move(to: CGPoint(x: 60, y: 95))
            backPath.addLine(to: CGPoint(x: 75, y: 200))
            backPath.move(to: CGPoint(x: 140, y: 95))
            backPath.addLine(to: CGPoint(x: 125, y: 200))
            context.stroke(backPath, with: .color(highlighted.color.opacity(0.8)), lineWidth: 3)
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()

        HStack(spacing: 20) {
            VStack {
                Text("Chest").foregroundStyle(.white).font(.caption)
                SVGAnatomyView(muscleGroup: .chest)
                    .frame(width: 60, height: 120)
            }

            VStack {
                Text("Legs").foregroundStyle(.white).font(.caption)
                SVGAnatomyView(muscleGroup: .legs)
                    .frame(width: 60, height: 120)
            }

            VStack {
                Text("Arms").foregroundStyle(.white).font(.caption)
                SVGAnatomyView(muscleGroup: .arms)
                    .frame(width: 60, height: 120)
            }
        }
    }
}
