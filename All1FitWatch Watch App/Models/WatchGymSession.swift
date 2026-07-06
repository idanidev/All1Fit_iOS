import Foundation

// MARK: - Sesión de gym espejada desde el iPhone
// Decodifica el mismo JSON que el snapshot de GymSession (fechas ISO-8601).
// Tolerante a claves extra/ausentes: el iPhone es la fuente de verdad.

struct WatchGymSet: Codable, Identifiable, Hashable {
    let id: String
    var reps: Int
    var weight: Double
    var completed: Bool
    var type: String

    enum CodingKeys: String, CodingKey {
        case id, reps, weight, completed, type
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        reps = try c.decodeIfPresent(Int.self, forKey: .reps) ?? 0
        weight = try c.decodeIfPresent(Double.self, forKey: .weight) ?? 0
        completed = try c.decodeIfPresent(Bool.self, forKey: .completed) ?? false
        type = try c.decodeIfPresent(String.self, forKey: .type) ?? "normal"
    }

    /// Marca corta para calentamiento/fallo/drop
    var badge: String? {
        switch type {
        case "warmup":  return "C"
        case "failure": return "F"
        case "drop":    return "D"
        default:        return nil
        }
    }
}

struct WatchGymExercise: Codable, Identifiable, Hashable {
    let id: String
    let exerciseName: String
    var sets: [WatchGymSet]

    enum CodingKeys: String, CodingKey {
        case id, exerciseName, sets
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        exerciseName = try c.decodeIfPresent(String.self, forKey: .exerciseName) ?? "Ejercicio"
        sets = try c.decodeIfPresent([WatchGymSet].self, forKey: .sets) ?? []
    }

    var completedCount: Int { sets.filter(\.completed).count }
}

struct WatchGymSession: Codable, Hashable {
    let routineName: String
    let startDate: Date
    var exercises: [WatchGymExercise]

    enum CodingKeys: String, CodingKey {
        case routineName, startDate, exercises
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        routineName = try c.decodeIfPresent(String.self, forKey: .routineName) ?? "Entreno"
        startDate = try c.decodeIfPresent(Date.self, forKey: .startDate) ?? Date()
        exercises = try c.decodeIfPresent([WatchGymExercise].self, forKey: .exercises) ?? []
    }

    var totalCompletedSets: Int {
        exercises.reduce(0) { $0 + $1.completedCount }
    }
}
