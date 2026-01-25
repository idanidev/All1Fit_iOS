import Foundation

// MARK: - Tabata Phase
enum TabataPhase: String, Codable {
    case countdown = "countdown"
    case work = "work"
    case rest = "rest"
    case setRest = "setRest"
    case complete = "complete"
    
    var displayName: String {
        switch self {
        case .countdown: return "¡Prepárate!"
        case .work: return "💪 TRABAJO"
        case .rest: return "😮‍💨 DESCANSO"
        case .setRest: return "⏸️ DESCANSO LARGO"
        case .complete: return "🎉 ¡COMPLETADO!"
        }
    }
    
    var color: String {
        switch self {
        case .countdown: return "orange"
        case .work: return "green"
        case .rest: return "red"
        case .setRest: return "blue"
        case .complete: return "purple"
        }
    }
}

// MARK: - Tabata Event (for haptics)
enum TabataEvent {
    case countdown
    case workStart
    case restStart
    case almostDone  // 3 seconds warning
    case complete
}

// MARK: - Treadmill Phase (for Cinta Quemagrasa)
struct TreadmillPhase: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let durationMinutes: Int
    let inclinePercent: Double
    let speedKmh: Double
    let description: String
    
    init(id: String = UUID().uuidString, name: String, durationMinutes: Int, inclinePercent: Double, speedKmh: Double, description: String) {
        self.id = id
        self.name = name
        self.durationMinutes = durationMinutes
        self.inclinePercent = inclinePercent
        self.speedKmh = speedKmh
        self.description = description
    }
}

// MARK: - Tabata Type
enum TabataType: String, Codable, CaseIterable {
    case intervals = "intervals"      // Traditional tabata
    case treadmill = "treadmill"      // Cinta quemagrasa style
    
    var displayName: String {
        switch self {
        case .intervals: return "Intervalos"
        case .treadmill: return "Cinta"
        }
    }
    
    var icon: String {
        switch self {
        case .intervals: return "timer"
        case .treadmill: return "figure.walk"
        }
    }
}

// MARK: - Tabata Model
struct Tabata: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let type: TabataType
    
    // For interval tabatas
    let workSeconds: Int
    let restSeconds: Int
    let rounds: Int
    let sets: Int
    let setRestSeconds: Int
    
    // For treadmill tabatas
    let treadmillPhases: [TreadmillPhase]?
    
    // Common
    let exercises: [String]?
    let isCustom: Bool
    let createdAt: Date?
    
    // MARK: - Computed Properties
    
    var totalDuration: Int {
        switch type {
        case .intervals:
            let roundDuration = workSeconds + restSeconds
            let setDuration = roundDuration * rounds
            let totalSetRest = max(0, sets - 1) * setRestSeconds
            return (setDuration * sets) + totalSetRest
            
        case .treadmill:
            return (treadmillPhases ?? []).reduce(0) { $0 + ($1.durationMinutes * 60) }
        }
    }
    
    var formattedDuration: String {
        let minutes = totalDuration / 60
        let seconds = totalDuration % 60
        if seconds == 0 {
            return "\(minutes) min"
        }
        return "\(minutes):\(String(format: "%02d", seconds))"
    }
    
    var subtitle: String {
        switch type {
        case .intervals:
            return "\(workSeconds)/\(restSeconds) × \(rounds) rondas"
        case .treadmill:
            return "\(treadmillPhases?.count ?? 0) fases"
        }
    }
    
    // MARK: - Initializers
    
    init(
        id: String = UUID().uuidString,
        name: String,
        type: TabataType = .intervals,
        workSeconds: Int = 20,
        restSeconds: Int = 10,
        rounds: Int = 8,
        sets: Int = 1,
        setRestSeconds: Int = 60,
        treadmillPhases: [TreadmillPhase]? = nil,
        exercises: [String]? = nil,
        isCustom: Bool = false,
        createdAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.workSeconds = workSeconds
        self.restSeconds = restSeconds
        self.rounds = rounds
        self.sets = sets
        self.setRestSeconds = setRestSeconds
        self.treadmillPhases = treadmillPhases
        self.exercises = exercises
        self.isCustom = isCustom
        self.createdAt = createdAt
    }
    
    // MARK: - Predefined Tabatas
    
    static let all: [Tabata] = {
        var tabatas: [Tabata] = []
        
        #if DEBUG
        // 🧪 Debug Test - Quick test with short times (only in DEBUG)
        tabatas.append(
            Tabata(
                id: "debug-test",
                name: "🧪 DEBUG Test (3s)",
                workSeconds: 3,
                restSeconds: 2,
                rounds: 3,
                sets: 1,
                setRestSeconds: 0
            )
        )
        #endif
        
        tabatas.append(contentsOf: [
            // 🔥 Infierno - Default (most intense)
            Tabata(
                id: "infierno",
                name: "🔥 Infierno",
                workSeconds: 30,
                restSeconds: 10,
                rounds: 10,
                sets: 1,
                setRestSeconds: 0
            ),
        
        // Clásico - Original Dr. Izumi Tabata
        Tabata(
            id: "clasico",
            name: "Clásico",
            workSeconds: 20,
            restSeconds: 10,
            rounds: 8,
            sets: 1,
            setRestSeconds: 0
        ),
        
        // HIIT Largo
        Tabata(
            id: "hiit-largo",
            name: "HIIT Largo",
            workSeconds: 45,
            restSeconds: 15,
            rounds: 6,
            sets: 1,
            setRestSeconds: 0
        ),
        
        // Sprint - 1:1 ratio
        Tabata(
            id: "sprint",
            name: "Sprint",
            workSeconds: 30,
            restSeconds: 30,
            rounds: 8,
            sets: 1,
            setRestSeconds: 0
        ),
        
        // EMOM Light
        Tabata(
            id: "emom-light",
            name: "EMOM Light",
            workSeconds: 40,
            restSeconds: 20,
            rounds: 10,
            sets: 1,
            setRestSeconds: 0
        ),
        
        // Cinta Quemagrasa - @serge_sitbon method
        Tabata(
            id: "cinta-quemagrasa",
            name: "🏃 Cinta Quemagrasa",
            type: .treadmill,
            workSeconds: 0,
            restSeconds: 0,
            rounds: 0,
            sets: 0,
            setRestSeconds: 0,
            treadmillPhases: [
                TreadmillPhase(
                    id: "fase1",
                    name: "Calentamiento",
                    durationMinutes: 5,
                    inclinePercent: 5,
                    speedKmh: 3.0,
                    description: "Activamos el cuerpo y subimos pulsaciones"
                ),
                TreadmillPhase(
                    id: "fase2",
                    name: "Trabajo Real",
                    durationMinutes: 5,
                    inclinePercent: 8,
                    speedKmh: 3.8,
                    description: "Empieza el trabajo real"
                ),
                TreadmillPhase(
                    id: "fase3",
                    name: "Máxima Quema",
                    durationMinutes: 5,
                    inclinePercent: 11,
                    speedKmh: 4.0,
                    description: "🔥 Zona de máxima quema"
                ),
                TreadmillPhase(
                    id: "fase4",
                    name: "Recuperación",
                    durationMinutes: 5,
                    inclinePercent: 9,
                    speedKmh: 3.0,
                    description: "Recupera... pero no pares"
                ),
                TreadmillPhase(
                    id: "fase5",
                    name: "Final Intenso",
                    durationMinutes: 5,
                    inclinePercent: 12,
                    speedKmh: 4.0,
                    description: "💪 El tramo que marca la diferencia"
                )
            ]
        ),
        
        // 🔥 Cinta Infierno - Hardcore version (50 min total)
        Tabata(
            id: "cinta-infierno",
            name: "🔥 Cinta Infierno",
            type: .treadmill,
            workSeconds: 0,
            restSeconds: 0,
            rounds: 0,
            sets: 0,
            setRestSeconds: 0,
            treadmillPhases: [
                TreadmillPhase(
                    id: "inferno1",
                    name: "Calentamiento",
                    durationMinutes: 5,
                    inclinePercent: 8,
                    speedKmh: 4.0,
                    description: "Calentamiento intenso desde el inicio"
                ),
                TreadmillPhase(
                    id: "inferno2",
                    name: "Primera Subida",
                    durationMinutes: 8,
                    inclinePercent: 12,
                    speedKmh: 4.5,
                    description: "🔥 Empezamos fuerte"
                ),
                TreadmillPhase(
                    id: "inferno3",
                    name: "Infierno 1",
                    durationMinutes: 8,
                    inclinePercent: 15,
                    speedKmh: 4.5,
                    description: "💀 Máxima inclinación - AGUANTA"
                ),
                TreadmillPhase(
                    id: "inferno4",
                    name: "Recuperación Activa",
                    durationMinutes: 5,
                    inclinePercent: 10,
                    speedKmh: 3.5,
                    description: "Baja pero no pares"
                ),
                TreadmillPhase(
                    id: "inferno5",
                    name: "Segunda Subida",
                    durationMinutes: 8,
                    inclinePercent: 13,
                    speedKmh: 4.8,
                    description: "🔥 Volvemos a subir"
                ),
                TreadmillPhase(
                    id: "inferno6",
                    name: "Infierno 2",
                    durationMinutes: 8,
                    inclinePercent: 15,
                    speedKmh: 5.0,
                    description: "🚀 TODO - Velocidad máxima"
                ),
                TreadmillPhase(
                    id: "inferno7",
                    name: "Sprint Final",
                    durationMinutes: 5,
                    inclinePercent: 12,
                    speedKmh: 5.5,
                    description: "💪 Último empujón al máximo"
                ),
                TreadmillPhase(
                    id: "inferno8",
                    name: "Cooldown",
                    durationMinutes: 3,
                    inclinePercent: 5,
                    speedKmh: 3.0,
                    description: "Enfriamiento gradual"
                )
            ]
        )
        ])
        
        return tabatas
    }()
    
    static func tabata(withId id: String) -> Tabata? {
        all.first { $0.id == id }
    }
    
    static var defaultTabata: Tabata {
        all.first { $0.id == "infierno" } ?? all[0]
    }
}

// MARK: - Tabata Result (for history)
struct TabataResult: Identifiable, Codable {
    let id: String
    let tabataId: String
    let tabataName: String
    let completedAt: Date
    let totalTimeSeconds: Int
    let completedRounds: Int
    let notes: String?
    
    init(
        id: String = UUID().uuidString,
        tabataId: String,
        tabataName: String,
        completedAt: Date = Date(),
        totalTimeSeconds: Int,
        completedRounds: Int,
        notes: String? = nil
    ) {
        self.id = id
        self.tabataId = tabataId
        self.tabataName = tabataName
        self.completedAt = completedAt
        self.totalTimeSeconds = totalTimeSeconds
        self.completedRounds = completedRounds
        self.notes = notes
    }
    
    var formattedTime: String {
        let minutes = totalTimeSeconds / 60
        let seconds = totalTimeSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
