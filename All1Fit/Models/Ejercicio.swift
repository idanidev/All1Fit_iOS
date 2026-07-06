import Foundation
import SwiftUI
import FirebaseFirestore

// MARK: - Ejercicio Style
enum EjercicioStyle: String, Codable, CaseIterable {
    case barbell    // Halterofilia / barra
    case dumbbell   // Gym / mancuerna
    case gymnastic  // Gimnástico / calistenia

    var icon: String {
        switch self {
        case .barbell:   return "figure.strengthtraining.traditional"
        case .dumbbell:  return "dumbbell.fill"
        case .gymnastic: return "figure.gymnastics"
        }
    }

    var label: String {
        switch self {
        case .barbell:   return "Haltero"
        case .dumbbell:  return "Gym"
        case .gymnastic: return "Gimnástico"
        }
    }

    var color: Color {
        switch self {
        case .barbell:   return .orange
        case .dumbbell:  return .blue
        case .gymnastic: return .green
        }
    }

    var gradient: [Color] {
        switch self {
        case .barbell:   return [.orange, .red]
        case .dumbbell:  return [.blue, .cyan]
        case .gymnastic: return [.green, .teal]
        }
    }

    /// Auto-detecta el estilo desde el nombre del ejercicio
    static func detect(from name: String) -> EjercicioStyle {
        let n = name.lowercased()

        let gymnastic = ["pull-up", "pull up", "dominada", "muscle-up", "muscle up",
                         "dip", "fondo", "push-up", "flexion", "flexión", "handstand",
                         "pino", "ring", "anilla", "gymnastic", "gimnástic",
                         "toes to bar", "knees to", "pistol", "burpee"]
        if gymnastic.contains(where: n.contains) { return .gymnastic }

        let dumbbell = ["curl", "mancuerna", "dumbbell", "lateral", "kettlebell",
                        "tricep", "bicep", "bíceps", "tríceps", "extension",
                        "extensión", "fly", "apertura", "elevación", "elevacion"]
        if dumbbell.contains(where: n.contains) { return .dumbbell }

        return .barbell
    }
}

// MARK: - RM Entry
struct RMEntry: Codable, Identifiable, Hashable {
    var id: String { "\(valor)-\(fecha.timeIntervalSince1970)" }
    let valor: Double
    let fecha: Date
    let reps: Int? // nil = 1RM (barbell/gymnastic), non-nil = gym reps tracking

    init(valor: Double, fecha: Date = Date(), reps: Int? = nil) {
        self.valor = valor
        self.fecha = fecha
        self.reps = reps
    }

    // Custom decode: Firestore may return Int64 for integer fields
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        valor = try c.decode(Double.self, forKey: .valor)
        fecha = (try? c.decode(Date.self, forKey: .fecha)) ?? Date()
        // Firestore stores integers as Int64 — handle both
        if let v = try? c.decodeIfPresent(Int.self, forKey: .reps) {
            reps = v
        } else if let v = try? c.decodeIfPresent(Int64.self, forKey: .reps) {
            reps = Int(v)
        } else {
            reps = nil
        }
    }
}

// MARK: - Ejercicio
struct Ejercicio: Codable, Identifiable {
    @DocumentID var id: String?
    var name: String
    var descripcion: String?
    var rmHistory: [RMEntry]
    var createdAt: Date
    var style: EjercicioStyle

    init(name: String, descripcion: String? = nil, rmHistory: [RMEntry] = [], createdAt: Date = Date(), style: EjercicioStyle? = nil) {
        self.name = name
        self.descripcion = descripcion
        self.rmHistory = rmHistory
        self.createdAt = createdAt
        self.style = style ?? EjercicioStyle.detect(from: name)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        _id = try container.decode(DocumentID<String>.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        descripcion = try container.decodeIfPresent(String.self, forKey: .descripcion)
        rmHistory = try container.decodeIfPresent([RMEntry].self, forKey: .rmHistory) ?? []
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        style = try container.decodeIfPresent(EjercicioStyle.self, forKey: .style) ?? EjercicioStyle.detect(from: name)
    }
    
    /// Último RM registrado (el más reciente por fecha)
    var ultimoRM: RMEntry? {
        rmHistory.max(by: { $0.fecha < $1.fecha })
    }
    
    /// Mejor RM histórico
    var mejorRM: RMEntry? {
        rmHistory.max(by: { $0.valor < $1.valor })
    }
    
    /// Fecha formateada del último RM
    var ultimaFechaFormateada: String {
        guard let fecha = ultimoRM?.fecha else { return "Sin registros" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.locale = Locale(identifier: "es_ES")
        return formatter.string(from: fecha)
    }
    
    /// Icon based on exercise style
    var icon: String { style.icon }
    
    /// Tabla de porcentajes calculados (30% - 100%)
    var porcentajes: [(porcentaje: Int, peso: Double)] {
        guard let rm = ultimoRM else { return [] }
        return [100, 90, 80, 70, 60, 50, 40, 30].map { p in
            (porcentaje: p, peso: round((rm.valor * Double(p)) / 100.0 * 10) / 10)
        }
    }
}

// MARK: - Sample Data
extension Ejercicio {
    static let sample = Ejercicio(
        name: "Back Squat",
        rmHistory: [
            RMEntry(valor: 100, fecha: Date().addingTimeInterval(-86400 * 60)),
            RMEntry(valor: 105, fecha: Date().addingTimeInterval(-86400 * 45)),
            RMEntry(valor: 110, fecha: Date().addingTimeInterval(-86400 * 30)),
            RMEntry(valor: 112.5, fecha: Date().addingTimeInterval(-86400 * 15)),
            RMEntry(valor: 115, fecha: Date())
        ]
    )
    
    static let samples: [Ejercicio] = [
        Ejercicio(name: "Back Squat", rmHistory: [RMEntry(valor: 115)], style: .barbell),
        Ejercicio(name: "Deadlift", rmHistory: [RMEntry(valor: 140)], style: .barbell),
        Ejercicio(name: "Bench Press", rmHistory: [RMEntry(valor: 85)], style: .barbell),
        Ejercicio(name: "Clean & Jerk", rmHistory: [RMEntry(valor: 80)], style: .barbell),
        Ejercicio(name: "Curl Mancuerna", rmHistory: [RMEntry(valor: 65)], style: .dumbbell)
    ]
}