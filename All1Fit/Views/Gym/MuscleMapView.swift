import SwiftUI

// MARK: - Mapa Muscular Anatómico
/// Dos siluetas reales (frontal y espalda) generadas a partir de trazados
/// vectoriales de anatomía humana (ver MuscleBodyData.swift, MIT license).
/// Cada grupo muscular es su propia forma: el primario se resalta con el
/// gradiente de la sección Gym y los secundarios en azul suave.
struct MuscleMapView: View {
    let primary: BodyPart
    let secondary: [BodyPart]

    var body: some View {
        HStack(spacing: 18) {
            AnatomyFigureView(front: true, primary: primary, secondary: secondary)
            AnatomyFigureView(front: false, primary: primary, secondary: secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Músculo principal: \(primary.rawValue)\(secondary.isEmpty ? "" : ". Secundarios: \(secondary.map(\.rawValue).joined(separator: ", "))")")
    }
}

// MARK: - Figura (frontal o espalda)
private struct AnatomyFigureView: View {
    let front: Bool
    let primary: BodyPart
    let secondary: [BodyPart]

    /// Datos de la vista: viewBox frontal 0-724, espalda desplazada +724 en X
    private var slugPaths: [String: [String]] { front ? MuscleBodyData.front : MuscleBodyData.back }
    private var xOffset: CGFloat { front ? 0 : 724 }

    private var highlightedPrimarySlugs: Set<String> { Set(front ? primary.frontSlugs : primary.backSlugs) }
    private var highlightedSecondarySlugs: Set<String> {
        Set(secondary.flatMap { front ? $0.frontSlugs : $0.backSlugs })
    }

    var body: some View {
        ZStack {
            ForEach(slugPaths.keys.sorted(), id: \.self) { slug in
                MusclePartShape(dStrings: slugPaths[slug] ?? [], xOffset: xOffset)
                    .fill(fill(for: slug))
            }
        }
        .frame(width: 112, height: 224)
    }

    private func fill(for slug: String) -> AnyShapeStyle {
        if highlightedPrimarySlugs.contains(slug) {
            return AnyShapeStyle(LinearGradient(colors: [.all1FitBlue, .all1FitCyan], startPoint: .top, endPoint: .bottom))
        }
        if highlightedSecondarySlugs.contains(slug) {
            return AnyShapeStyle(Color.all1FitBlue.opacity(0.4))
        }
        return AnyShapeStyle(Color(uiColor: .tertiarySystemGroupedBackground))
    }
}

// MARK: - Shape de un grupo muscular (puede tener varios subtrazados)
private struct MusclePartShape: Shape {
    let dStrings: [String]
    let xOffset: CGFloat

    func path(in rect: CGRect) -> Path {
        var combined = Path()
        for d in dStrings {
            var subpath = SVGPathParser.path(from: d)
            if xOffset != 0 {
                subpath = subpath.applying(CGAffineTransform(translationX: -xOffset, y: 0))
            }
            combined.addPath(subpath)
        }
        // Canvas fuente: 724×1448 (por lado) → escala al rect asignado por SwiftUI
        let transform = CGAffineTransform(scaleX: rect.width / 724.0, y: rect.height / 1448.0)
        return combined.applying(transform)
    }
}

// MARK: - Mapeo BodyPart → slugs de MuscleBodyData
private extension BodyPart {
    /// Slugs visibles en la vista frontal para este músculo
    var frontSlugs: [String] {
        switch self {
        case .chest: return ["chest"]
        case .biceps: return ["biceps"]
        case .abs: return ["abs"]
        case .quads: return ["quadriceps"]
        case .shoulders: return ["deltoids"]
        case .triceps: return ["triceps"]
        case .calves: return ["calves"]
        case .back, .hamstrings, .glutes, .none: return []
        }
    }

    /// Slugs visibles en la vista de espalda para este músculo
    var backSlugs: [String] {
        switch self {
        case .back: return ["upper-back", "lower-back", "trapezius"]
        case .shoulders: return ["deltoids"]
        case .triceps: return ["triceps"]
        case .glutes: return ["gluteal"]
        case .hamstrings: return ["hamstring"]
        case .calves: return ["calves"]
        case .chest, .biceps, .abs, .quads, .none: return []
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

#Preview("Espalda") {
    MuscleMapView(primary: .back, secondary: [.biceps])
        .padding()
        .background(Color.black)
}
