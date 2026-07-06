import Foundation
import SwiftUI
import FirebaseFirestore

// MARK: - Tipo de serie
enum GymSetType: String, Codable, CaseIterable {
    case normal
    case warmup
    case failure
    case drop

    var label: String {
        switch self {
        case .normal:  return "Normal"
        case .warmup:  return "Calentamiento"
        case .failure: return "Al fallo"
        case .drop:    return "Drop set"
        }
    }

    /// Marca corta mostrada en la columna de serie
    var badge: String? {
        switch self {
        case .normal:  return nil
        case .warmup:  return "C"
        case .failure: return "F"
        case .drop:    return "D"
        }
    }

    var color: Color {
        switch self {
        case .normal:  return .secondary
        case .warmup:  return .all1FitWarning
        case .failure: return .all1FitError
        case .drop:    return .all1FitPurple
        }
    }
}

// MARK: - Gym Set (serie registrada)
struct GymSet: Codable, Identifiable, Hashable {
    var id: String
    var reps: Int
    var weight: Double
    var completed: Bool
    var type: GymSetType
    var rpe: Int?

    init(id: String = UUID().uuidString, reps: Int = 10, weight: Double = 0, completed: Bool = false, type: GymSetType = .normal, rpe: Int? = nil) {
        self.id = id
        self.reps = reps
        self.weight = weight
        self.completed = completed
        self.type = type
        self.rpe = rpe
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        reps = try c.decodeIfPresent(Int.self, forKey: .reps) ?? 0
        weight = try c.decodeIfPresent(Double.self, forKey: .weight) ?? 0
        completed = try c.decodeIfPresent(Bool.self, forKey: .completed) ?? false
        type = try c.decodeIfPresent(GymSetType.self, forKey: .type) ?? .normal
        rpe = try c.decodeIfPresent(Int.self, forKey: .rpe)
    }

    /// 1RM estimado (fórmula de Epley). Solo con peso y reps válidos.
    var estimated1RM: Double? {
        guard weight > 0, reps > 0 else { return nil }
        guard reps > 1 else { return weight }
        return weight * (1 + Double(reps) / 30)
    }
}

// MARK: - Exercise Log (ejercicio dentro de una sesión)
struct GymExerciseLog: Codable, Identifiable, Hashable {
    var id: String
    var exerciseName: String
    var restSeconds: Int
    var sets: [GymSet]
    /// Ejercicios con el mismo número forman una superserie
    var supersetGroup: Int?
    /// true si el prefill aplicó doble progresión (subida de peso automática)
    var progressionApplied: Bool

    init(id: String = UUID().uuidString, exerciseName: String, restSeconds: Int = 90, sets: [GymSet] = [], supersetGroup: Int? = nil, progressionApplied: Bool = false) {
        self.id = id
        self.exerciseName = exerciseName
        self.restSeconds = restSeconds
        self.sets = sets
        self.supersetGroup = supersetGroup
        self.progressionApplied = progressionApplied
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        exerciseName = try c.decode(String.self, forKey: .exerciseName)
        restSeconds = try c.decodeIfPresent(Int.self, forKey: .restSeconds) ?? 90
        sets = try c.decodeIfPresent([GymSet].self, forKey: .sets) ?? []
        supersetGroup = try c.decodeIfPresent(Int.self, forKey: .supersetGroup)
        progressionApplied = try c.decodeIfPresent(Bool.self, forKey: .progressionApplied) ?? false
    }

    var completedSets: [GymSet] { sets.filter(\.completed) }

    /// Series efectivas: completadas y que no son de calentamiento
    var workingSets: [GymSet] { completedSets.filter { $0.type != .warmup } }

    /// Volumen = suma de peso × reps de las series efectivas
    var volume: Double {
        workingSets.reduce(0) { $0 + $1.weight * Double($1.reps) }
    }

    /// Mejor serie por peso (efectivas)
    var bestSet: GymSet? {
        workingSets.max { $0.weight < $1.weight }
    }

    /// Mejor 1RM estimado de la sesión para este ejercicio
    var bestEstimated1RM: Double? {
        workingSets.compactMap(\.estimated1RM).max()
    }

    var catalogExercise: GymExercise? {
        GymExerciseCatalog.exercise(named: exerciseName)
    }
}

// MARK: - Gym Session (sesión de entrenamiento registrada)
struct GymSession: Codable, Identifiable {
    @DocumentID var id: String?
    var routineName: String
    var startDate: Date
    var endDate: Date?
    var exercises: [GymExerciseLog]
    var notes: String?
    /// Fin del descanso en curso (persiste en el snapshot: sobrevive a cierres de app)
    var restEndDate: Date?

    enum CodingKeys: String, CodingKey {
        case id, routineName, startDate, endDate, exercises, notes, restEndDate
    }

    init(routineName: String, startDate: Date = Date(), endDate: Date? = nil, exercises: [GymExerciseLog] = [], notes: String? = nil) {
        self.routineName = routineName
        self.startDate = startDate
        self.endDate = endDate
        self.exercises = exercises
        self.notes = notes
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // Tolerante: DocumentID solo decodifica dentro de Firestore; el snapshot JSON local no lo trae
        _id = (try? c.decode(DocumentID<String>.self, forKey: .id)) ?? DocumentID(wrappedValue: nil)
        routineName = try c.decodeIfPresent(String.self, forKey: .routineName) ?? "Entreno libre"
        startDate = try c.decodeIfPresent(Date.self, forKey: .startDate) ?? Date()
        endDate = try c.decodeIfPresent(Date.self, forKey: .endDate)
        exercises = try c.decodeIfPresent([GymExerciseLog].self, forKey: .exercises) ?? []
        notes = try c.decodeIfPresent(String.self, forKey: .notes)
        restEndDate = try c.decodeIfPresent(Date.self, forKey: .restEndDate)
    }

    // El id nunca se serializa: Firestore lo gestiona y el snapshot local no lo necesita
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(routineName, forKey: .routineName)
        try c.encode(startDate, forKey: .startDate)
        try c.encodeIfPresent(endDate, forKey: .endDate)
        try c.encode(exercises, forKey: .exercises)
        try c.encodeIfPresent(notes, forKey: .notes)
        try c.encodeIfPresent(restEndDate, forKey: .restEndDate)
    }

    var totalVolume: Double {
        exercises.reduce(0) { $0 + $1.volume }
    }

    var totalCompletedSets: Int {
        exercises.reduce(0) { $0 + $1.completedSets.count }
    }

    var duration: TimeInterval {
        (endDate ?? Date()).timeIntervalSince(startDate)
    }

    var durationFormatted: String {
        let minutes = Int(duration) / 60
        if minutes >= 60 {
            return "\(minutes / 60)h \(minutes % 60)m"
        }
        return "\(minutes)m"
    }

    var dateFormatted: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.locale = Locale(identifier: "es_ES")
        return formatter.string(from: startDate)
    }
}
