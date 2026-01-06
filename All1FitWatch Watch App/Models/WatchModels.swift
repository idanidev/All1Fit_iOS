import Foundation

// MARK: - RM Entry (Watch)
struct WatchRMEntry: Codable, Identifiable, Hashable {
    var id: String { "\(valor)-\(fecha.timeIntervalSince1970)" }
    let valor: Double
    let fecha: Date
    
    init(valor: Double, fecha: Date = Date()) {
        self.valor = valor
        self.fecha = fecha
    }
}

// MARK: - Ejercicio (Watch)
struct WatchEjercicio: Codable, Identifiable, Hashable {
    var id: String?
    var name: String
    var rmHistory: [WatchRMEntry]
    
    var ultimoRM: WatchRMEntry? {
        rmHistory.max(by: { $0.fecha < $1.fecha })
    }
    
    var icon: String {
        let lowercaseName = name.lowercased()
        if lowercaseName.contains("clean") || lowercaseName.contains("jerk") ||
           lowercaseName.contains("snatch") || lowercaseName.contains("thruster") ||
           lowercaseName.contains("overhead") || lowercaseName.contains("push press") {
            return "figure.strengthtraining.traditional"
        }
        if lowercaseName.contains("curl") || lowercaseName.contains("bench") ||
           lowercaseName.contains("row") || lowercaseName.contains("fly") ||
           lowercaseName.contains("tricep") || lowercaseName.contains("bicep") {
            return "dumbbell.fill"
        }
        return "figure.strengthtraining.traditional"
    }
    
    /// Tabla de porcentajes calculados
    var porcentajes: [(porcentaje: Int, peso: Double)] {
        guard let rm = ultimoRM else { return [] }
        return [100, 95, 90, 85, 80, 75, 70, 65, 60, 55, 50, 45, 40, 35, 30].map { p in
            (porcentaje: p, peso: round((rm.valor * Double(p)) / 100.0 * 10) / 10)
        }
    }
}

// MARK: - Workout Category (Watch)
enum WatchWorkoutCategory: String, CaseIterable, Identifiable, Codable {
    case running = "Running"
    case crossfit = "CrossFit"
    case competition = "Competiciones"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .running: return "figure.run"
        case .crossfit: return "dumbbell.fill"
        case .competition: return "trophy.fill"
        }
    }
    
    var color: String {
        switch self {
        case .running: return "orange"
        case .crossfit: return "red"
        case .competition: return "purple"
        }
    }
}

// MARK: - Workout (Watch)
struct WatchWorkout: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let category: WatchWorkoutCategory
    let description: String
    let isForTime: Bool
    let timeCapMinutes: Int?
    
    // Predefined workouts for watch
    static let all: [WatchWorkout] = [
        // Running
        WatchWorkout(id: "5k", name: "5K", category: .running, description: "5 kilómetros", isForTime: true, timeCapMinutes: nil),
        WatchWorkout(id: "10k", name: "10K", category: .running, description: "10 kilómetros", isForTime: true, timeCapMinutes: nil),
        WatchWorkout(id: "media-maraton", name: "Media Maratón", category: .running, description: "21.1 km", isForTime: true, timeCapMinutes: nil),
        
        // CrossFit
        WatchWorkout(id: "murph", name: "Murph", category: .crossfit, description: "1mi-100PU-200Push-300Sq-1mi", isForTime: true, timeCapMinutes: nil),
        WatchWorkout(id: "cindy", name: "Cindy", category: .crossfit, description: "5PU-10Push-15Sq AMRAP 20", isForTime: false, timeCapMinutes: 20),
        WatchWorkout(id: "fran", name: "Fran", category: .crossfit, description: "21-15-9 Thr+PU", isForTime: true, timeCapMinutes: nil),
        WatchWorkout(id: "helen", name: "Helen", category: .crossfit, description: "3 rds: 400m-21KB-12PU", isForTime: true, timeCapMinutes: nil),
        
        // Competitions
        WatchWorkout(id: "hyrox", name: "HYROX", category: .competition, description: "8x(1km+estación)", isForTime: true, timeCapMinutes: nil),
        WatchWorkout(id: "dekka", name: "DEKKA", category: .competition, description: "10 zonas funcionales", isForTime: true, timeCapMinutes: nil)
    ]
    
    static func workouts(for category: WatchWorkoutCategory) -> [WatchWorkout] {
        all.filter { $0.category == category }
    }
}

// MARK: - Weight Unit
enum WatchWeightUnit: String, CaseIterable, Codable {
    case kg, lbs
    
    var symbol: String { rawValue }
    
    func convert(_ kg: Double) -> Double {
        switch self {
        case .kg: return kg
        case .lbs: return kg * 2.20462
        }
    }
}
