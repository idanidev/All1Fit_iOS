import SwiftUI

enum BodyPart: String, CaseIterable, Codable {
    case chest = "Pecho"
    case back = "Espalda"
    case shoulders = "Hombros"
    case biceps = "Bíceps"
    case triceps = "Tríceps"
    case abs = "Abdominales"
    case quads = "Cuádriceps"
    case hamstrings = "Isquiotibiales"
    case glutes = "Glúteos"
    case calves = "Gemelos"
    case none = "General"

    var color: Color {
        switch self {
        case .chest, .triceps, .shoulders: return .all1FitOrange
        case .back, .biceps: return .all1FitBlue
        case .quads, .hamstrings, .glutes, .calves: return .all1FitPurple
        case .abs: return .all1FitCyan
        case .none: return .gray
        }
    }
    
    var gradient: (primary: (Double, Double, Double), secondary: (Double, Double, Double)) {
        switch self {
        case .chest, .triceps, .shoulders:
            return ((1.0, 0.6, 0.0), (1.0, 0.2, 0.2)) // Orange/Red
        case .back, .biceps:
            return ((0.0, 0.5, 1.0), (0.2, 0.8, 1.0)) // Blue/Cyan
        case .quads, .hamstrings, .glutes, .calves:
            return ((0.7, 0.3, 0.9), (1.0, 0.2, 0.6)) // Purple/Pink
        case .abs:
            return ((0.0, 0.8, 0.4), (0.2, 1.0, 0.6)) // Green/Mint
        case .none:
            return ((0.5, 0.5, 0.5), (0.3, 0.3, 0.3)) // Gray
        }
    }
}
