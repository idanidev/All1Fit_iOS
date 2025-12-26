import Foundation

// MARK: - Body Zone
enum BodyZone: String, CaseIterable, Identifiable {
    case shoulders = "Hombros"
    case hips = "Cadera"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .shoulders: return "figure.arms.open"
        case .hips: return "figure.stand"
        }
    }
    
    var description: String {
        switch self {
        case .shoulders: return "Mejora la movilidad de hombros y escápulas"
        case .hips: return "Aumenta la flexibilidad de cadera y glúteos"
        }
    }
}

// MARK: - Mobility Exercise
struct MobilityExercise: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let description: String
    let gifName: String // Asset name or URL
    let duration: Int // seconds
    let bodyZone: BodyZone
    
    // Sample data
    static let samples: [MobilityExercise] = [
        // Shoulders
        MobilityExercise(
            name: "Shoulder Flossing",
            description: "Con una banda de resistencia, pasa los brazos por encima de la cabeza de adelante hacia atrás. Mejora la movilidad de hombros y escápulas.",
            gifName: "shoulder_flossing",
            duration: 45,
            bodyZone: .shoulders
        ),
        MobilityExercise(
            name: "Estiramiento de Deltoides",
            description: "Cruza el brazo por delante del pecho y mantén",
            gifName: "shoulder_stretch_2",
            duration: 45,
            bodyZone: .shoulders
        ),
        
        // Hips
        MobilityExercise(
            name: "90/90 Hip Stretch",
            description: "Posición sentada con ambas piernas a 90 grados",
            gifName: "hip_stretch_1",
            duration: 60,
            bodyZone: .hips
        ),
        MobilityExercise(
            name: "Pigeon Pose",
            description: "Estiramiento profundo de glúteo y cadera",
            gifName: "hip_stretch_2",
            duration: 45,
            bodyZone: .hips
        )
    ]
    
    static func exercises(for zone: BodyZone) -> [MobilityExercise] {
        samples.filter { $0.bodyZone == zone }
    }
}
