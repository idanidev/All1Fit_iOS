import Foundation
import FirebaseFirestore

// MARK: - RM Entry
struct RMEntry: Codable, Identifiable, Hashable {
    var id: String { "\(valor)-\(fecha.timeIntervalSince1970)" }
    let valor: Double
    let fecha: Date
    
    init(valor: Double, fecha: Date = Date()) {
        self.valor = valor
        self.fecha = fecha
    }
}

// MARK: - Ejercicio
struct Ejercicio: Codable, Identifiable {
    @DocumentID var id: String?
    var name: String
    var descripcion: String?
    var rmHistory: [RMEntry]
    var createdAt: Date
    
    init(name: String, descripcion: String? = nil, rmHistory: [RMEntry] = [], createdAt: Date = Date()) {
        self.name = name
        self.descripcion = descripcion
        self.rmHistory = rmHistory
        self.createdAt = createdAt
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
    
    /// Tabla de porcentajes calculados (40% - 100%)
    var porcentajes: [(porcentaje: Int, peso: Double)] {
        guard let rm = ultimoRM else { return [] }
        return [100, 95, 90, 85, 80, 75, 70, 65, 60, 55, 50, 45, 40].map { p in
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
        Ejercicio(name: "Back Squat", rmHistory: [RMEntry(valor: 115)]),
        Ejercicio(name: "Deadlift", rmHistory: [RMEntry(valor: 140)]),
        Ejercicio(name: "Bench Press", rmHistory: [RMEntry(valor: 85)]),
        Ejercicio(name: "Clean & Jerk", rmHistory: [RMEntry(valor: 80)]),
        Ejercicio(name: "Snatch", rmHistory: [RMEntry(valor: 65)])
    ]
}